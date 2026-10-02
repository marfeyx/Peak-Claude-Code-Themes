"""How many subagents are in flight, and how many of them have finished.

Claude Code does NOT put this in the status line payload -- verified against the
2.1.274 bundle: the builder emits session, model, workspace, cost, context,
rate limits and not one field about tasks or agents. (There is a separate
`subagentStatusLine` hook that does get a `tasks` array, but it paints the agent
panel's own rows, not this one.) So the count has to be read off the transcript
tree, which is on the Linux filesystem and therefore cheap.

TWO MECHANISMS, because there are two ways agents get spawned and they record
themselves completely differently:

  * `Agent` tool spawns write `subagents/agent-<id>.meta.json` once, at spawn.
    Completion is NOT recorded there, nor at the end of the agent's own
    transcript -- it arrives in the ROOT transcript as a `queue-operation`
    carrying a `task-notification` block with the agent's id and a status.
    Counting spawns this way is what makes nested fan-out come out right: an
    agent spawned by another agent never appears as a tool call in the root
    transcript, but it does get a meta file and it does get a notification.

  * `Workflow` runs write `subagents/workflows/wf_*/journal.jsonl`, appended
    live, one line per event: `started`, then `result` or `failed`. The
    completion artefact `workflows/wf_<id>.json` is written only when the run
    ends -- and never at all if the run is killed -- so it is usable as a "this
    one is over" flag but not as a progress feed.

The two never overlap: workflow agents keep their meta files inside the run's
own directory, and they raise no per-agent task-notification.

WAVE SCOPING. Meta files accumulate for the life of the session, so a raw count
would report "59 agents" an hour after the last one finished. What the row
should say is how the CURRENT burst is going. A wave is therefore defined from
the agents still running: take the earliest of those, walk back one gap's worth,
and count everything spawned since -- which picks up the siblings that have
already come back without dragging in an unrelated fan-out from earlier.
"""

import hashlib
import json
import os
import re
import tempfile
import time

# The notification is embedded in a JSON string inside the transcript line, so
# its newlines are the two characters "\" and "n" rather than actual newlines.
# Matching the escaped form directly avoids having to parse the JSON at all.
NOTIFY = re.compile(
    rb'<task-notification>\\n<task-id>(a[0-9a-f]{16})</task-id>'
    rb'.{0,600}?<status>([a-z_]+)</status>',
    re.S)

STARTED = b'{"type":"started"'
RESULT = b'{"type":"result"'
FAILED = b'{"type":"failed"'

WAVE_GAP = 90.0          # seconds of quiet that separate one fan-out from the next
DEAD_AFTER = 900.0       # an "in flight" agent silent this long is presumed lost
JOURNAL_STALE = 900.0    # ditto for a workflow journal with no completion file
OVERLAP = 512            # bytes re-read before the cached offset, for safety


def _cache_path(key):
    digest = hashlib.md5(key.encode("utf-8", "replace")).hexdigest()[:16]
    return os.path.join(tempfile.gettempdir(), "cc-sl-agents-%s.json" % digest)


def _finished_ids(transcript):
    """{agent id: status} for every agent this session has seen finish.

    Incremental: the transcript is append-only, so only the bytes added since
    the last frame are scanned. A 5 MB transcript re-read at 1 Hz would be
    wasteful rather than slow, but the cache also makes the idle frame -- the
    common case, where nothing has been appended -- cost a single stat().
    """
    path = _cache_path(transcript)
    try:
        size = os.path.getsize(transcript)
    except OSError:
        return {}

    offset, ids = 0, {}
    try:
        with open(path) as fh:
            cached = json.load(fh)
        if cached.get("size", 0) <= size:        # not truncated/replaced
            offset = int(cached.get("offset", 0))
            ids = dict(cached.get("ids") or {})
            if cached.get("size") == size:
                return ids
    except (OSError, ValueError, TypeError):
        offset, ids = 0, {}

    start = max(0, offset - OVERLAP)
    try:
        with open(transcript, "rb") as fh:
            fh.seek(start)
            chunk = fh.read()
    except OSError:
        return ids

    for match in NOTIFY.finditer(chunk):
        ids[match.group(1).decode()] = match.group(2).decode()

    # Stop at the last complete line. A notification block never spans a line,
    # so anything after the final newline is a half-written record that would
    # otherwise be skipped for good once the offset moved past it.
    cut = chunk.rfind(b"\n")
    new_offset = start + cut + 1 if cut >= 0 else start

    try:
        tmp = "%s.%d" % (path, os.getpid())
        with open(tmp, "w") as fh:
            json.dump({"size": size, "offset": new_offset, "ids": ids}, fh)
        os.replace(tmp, path)
    except OSError:
        pass

    return ids


def _direct(side, finished, now):
    """(done, total, failed) for plain `Agent` spawns in the current wave."""
    subagents = os.path.join(side, "subagents")
    try:
        entries = [e for e in os.scandir(subagents)
                   if e.name.endswith(".meta.json")]
    except OSError:
        return 0, 0, 0

    spawns = []
    for entry in entries:
        agent_id = entry.name[len("agent-"):-len(".meta.json")]
        try:
            spawned = entry.stat().st_mtime
        except OSError:
            continue
        spawns.append((spawned, agent_id))
    if not spawns:
        return 0, 0, 0

    # An agent with no notification is either running or was lost with the
    # process that owned it. Its own transcript is appended as it works, so its
    # mtime is the liveness signal; nothing else distinguishes the two.
    live = []
    for spawned, agent_id in spawns:
        if agent_id in finished:
            continue
        try:
            touched = os.path.getmtime(
                os.path.join(subagents, "agent-%s.jsonl" % agent_id))
        except OSError:
            touched = spawned
        if now - touched < DEAD_AFTER:
            live.append(spawned)
    if not live:
        return 0, 0, 0

    wave_start = min(live) - WAVE_GAP
    wave = [agent_id for spawned, agent_id in spawns if spawned >= wave_start]
    done = [a for a in wave if a in finished]
    failed = [a for a in done if finished[a] not in ("completed",)]
    return len(done), len(wave), len(failed)


def _workflows(side, now):
    """(done, total, failed, live_runs) over workflow runs that are still going."""
    root = os.path.join(side, "subagents", "workflows")
    done = total = failed = live = 0
    try:
        runs = list(os.scandir(root))
    except OSError:
        return 0, 0, 0, 0

    for run in runs:
        if not run.name.startswith("wf_"):
            continue
        # The completion artefact is the only reliable "this run is over" flag.
        # Its absence does not mean the run is alive, though -- a killed run
        # never gets one -- so staleness has to be checked as well.
        if os.path.exists(os.path.join(side, "workflows", run.name + ".json")):
            continue
        journal = os.path.join(run.path, "journal.jsonl")
        try:
            if now - os.path.getmtime(journal) > JOURNAL_STALE:
                continue
            with open(journal, "rb") as fh:
                blob = fh.read()
        except OSError:
            continue
        started = blob.count(STARTED)
        results = blob.count(RESULT)
        errors = blob.count(FAILED)
        total += started
        done += results + errors
        failed += errors
        live += 1
    return done, total, failed, live


def progress(data, now=None):
    """(done, total, failed), or None when nothing is in flight.

    Never raises: a status line that cannot count agents should still draw the
    field.
    """
    try:
        if now is None:
            now = time.time()
        transcript = data.get("transcript_path") if isinstance(data, dict) else None
        if not transcript or not transcript.endswith(".jsonl"):
            return None
        side = transcript[:-len(".jsonl")]
        if not os.path.isdir(side):
            return None

        finished = _finished_ids(transcript)
        d1, t1, f1 = _direct(side, finished, now)
        d2, t2, f2, live = _workflows(side, now)

        done, total, failed = d1 + d2, t1 + t2, f1 + f2
        if total <= 0:
            return None
        # A finished wave of plain agents should stop being reported -- nobody
        # wants yesterday's 59/59 on the row. A workflow is different: between
        # two stages every agent started so far has returned and the next batch
        # has not launched yet, so `done == total` is a normal mid-run state and
        # suppressing it makes the count blink out and back every phase.
        if done >= total and not live:
            return None
        return done, total, failed
    except Exception:
        return None


def label(data, now=None):
    """"agents 7/12", or "" when there is nothing to report."""
    got = progress(data, now)
    if not got:
        return ""
    done, total, failed = got
    if failed:
        return "agents %d/%d  %d failed" % (done, total, failed)
    return "agents %d/%d" % (done, total)


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        payload = {"transcript_path": sys.argv[1]}
    else:
        payload = json.load(sys.stdin)
    t0 = time.time()
    got = progress(payload)
    print("progress: %s   (%.2f ms)" % (got, (time.time() - t0) * 1000))
    print("label   : %r" % label(payload))
