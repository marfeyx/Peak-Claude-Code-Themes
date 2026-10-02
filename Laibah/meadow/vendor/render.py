#!/usr/bin/env python3
"""Bridge Laibah's vendored meadow renderer onto this statusline's contract.

Reads the Claude Code status-line payload on stdin and prints one ready-to-emit
row per line. themes/meadow.sh pipes the payload in and hands every line
straight to sl_emit_raw, because width has already been enforced here.

The vendored modules beside this file are byte-identical copies of upstream.
Everything this system needs that upstream does not provide is done here, by
patching the imported module objects at runtime, so the vendored sources stay
clean and a future refresh is a plain file copy.

What the bridge has to fix, and why:

WIDTH. Upstream reads COLUMNS and renders full bleed, exactly that many cells.
This system budgets against SL_COLUMNS, which is COLUMNS minus a safety margin,
and check.sh fails any row wider than that. The theme passes SL_COLUMNS in as
COLUMNS, and the clip below is a second line of defence measured in terminal
cells rather than code points, so a wide glyph in a path or branch name cannot
push a row over.

NO_COLOR. Upstream honours STATUSLINE_NO_TRUECOLOR but not NO_COLOR, so the
bridge strips every SGR sequence itself when SL_USE_COLOR is 0. It deliberately
does NOT switch upstream to its 256-colour fallback: that fallback carries the
whole field in colour alone, drawing every blade row as one repeated '"' and the
soil as one repeated '_', so stripping the colour leaves a wall of filler. The
truecolour scene draws real glyphs instead -- half blocks for grass, the cat
sprite, flowers -- which survive the strip, the same way the water theme stays
legible without colour. Rows that end up empty get the blank-row treatment
below.

BLANK ROWS. Claude Code drops a status row that is empty once escapes are
stripped, which would silently shorten the panel. Any such row gets a
zero-width space.

TRAILING WHITESPACE. A row that paints a background to the edge legitimately
ends in spaces and check.sh waives it. A row that paints no background must be
right-trimmed or it fails, so the trim is applied only to rows carrying no
background escape.

DETERMINISM. Upstream render() calls time.time() directly, so two renders of
the same frame would differ. The bridge therefore reproduces render() against a
timestamp handed in from SL_NOW, driving both the day-cycle phase and the scene
animation off it. With the clock pinned for testing it also suppresses the
subagent segment, which is a live filesystem probe and cannot be reproducible.
It is suppressed under SL_PREVIEW for a second reason: counting subagents scans
the transcript and caches its offset to disk, and the contract says a preview
render writes no state.

SIDE EFFECTS. The sky this panel stands under is a Windows Terminal background
image on a half-hour cycle, and a frame is the only thing here that runs once a
second, so a frame is the only place a band crossing can be noticed. skydriver.py
beside this file is the host's own, not upstream's: it compares two integers
against the band already on screen and, on the six crossings per cycle where
they differ, hands the write to a detached terminal-background.py and returns.
This frame writes no configuration itself and never waits for the one that
does; the call is made after the rows have been written, so it cannot delay one,
and it refuses unless meadow is both the selected theme and the recorded owner
of the background. Every other frame hands over nothing at all. With the clock
pinned or under SL_PREVIEW it is disabled outright, because a test render must
not move the user's terminal. Upstream's git subprocess is replaced with the
branch the host already resolved, so no frame forks a process for that.

The band it asks for comes from skyband.py, also the host's, which reads the
darkness at the segment's own midpoint so the sky image and the colour scheme
read against it can never disagree, and which takes its clock from the same
SL_MEADOW_NOW this file renders at, so a pinned frame pins the sky too.

Environment, all set by themes/meadow.sh:
  COLUMNS             the width budget, in cells
  SL_USE_COLOR        0 to strip every escape
  SL_MEADOW_NOW       epoch seconds driving phase and animation
  SL_MEADOW_PINNED    1 when that clock came from SL_FAKE_NOW or SL_FAKE_TICK
  SL_MEADOW_PREVIEW   1 under SL_PREVIEW, so no frame writes cached state
  SL_MEADOW_ROWS      panel height in rows, clamped to MIN_ROWS..MAX_ROWS
  SL_MEADOW_BRANCH    git branch, already resolved by the host
"""

import json
import os
import re
import sys
import time
import unicodedata

sys.dont_write_bytecode = True

HERE = os.path.dirname(os.path.abspath(__file__))

SGR = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
ZERO_WIDTH_SPACE = "​"
RESET = "\x1b[0m"
DEFAULT_ROWS = 9
MIN_ROWS = 4
MAX_ROWS = 16
DEFAULT_PERIOD = "1800"
MIN_LINES = 24


def _env_int(name, default):
    try:
        value = int(float(os.environ.get(name) or default))
    except (TypeError, ValueError):
        return default
    return value


def _cells(text):
    total = 0
    for character in text:
        if unicodedata.combining(character):
            continue
        total += 2 if unicodedata.east_asian_width(character) in ("W", "F") else 1
    return total


def _read_payload():
    try:
        raw = sys.stdin.read()
    except OSError:
        return {}
    try:
        payload = json.loads(raw)
    except (ValueError, TypeError):
        return {}
    return payload if isinstance(payload, dict) else {}


def _prepare_environment(budget, rows, is_quiet):
    if is_quiet:
        os.environ["SL_MEADOW_DRIVE_SKY"] = "0"
    os.environ["SL_MEADOW_BLEED"] = "1"
    os.environ["COLUMNS"] = str(budget)
    os.environ["LINES"] = str(max(MIN_LINES, rows + 2))
    os.environ["SL_MEADOW_HEIGHT"] = str(rows)
    os.environ.pop("STATUSLINE_NO_TRUECOLOR", None)
    os.environ.setdefault("SL_MEADOW_PERIOD", DEFAULT_PERIOD)


def _patch(meadow, is_quiet, now):
    branch = os.environ.get("SL_MEADOW_BRANCH") or ""
    meadow.git_branch = lambda cwd: branch or None

    if is_quiet:
        meadow.agentcount.label = lambda data, when=None: ""
    else:
        original = meadow.agentcount.label
        meadow.agentcount.label = lambda data, when=None: original(data, now)


def _context_percent(meadow, payload):
    try:
        raw = meadow.dig(payload, "context_window", "used_percentage")
        return max(0.0, min(100.0, float(raw)))
    except (TypeError, ValueError):
        return 0.0


def _rows(meadow, daylight, skyband, payload, budget, now):
    width = max(1, budget)
    percent = _context_percent(meadow, payload)

    phase = skyband.phase(now)
    palette = daylight.palette(phase)
    night = daylight.nightness(phase)
    height = meadow.panel_height(_env_int("LINES", MIN_LINES))

    canvas = meadow.scene(width, height, now, palette, night)
    meadow.draw_info(canvas, payload, percent, palette)
    return canvas.rows()


def _clip(line, budget):
    out = []
    used = 0
    position = 0
    while position < len(line):
        match = SGR.match(line, position)
        if match:
            out.append(match.group(0))
            position = match.end()
            continue
        character = line[position]
        span = _cells(character)
        if used + span > budget:
            break
        out.append(character)
        used += span
        position += 1
    return "".join(out)


def _trim_right(line):
    tokens = []
    position = 0
    while position < len(line):
        match = SGR.match(line, position)
        if match:
            tokens.append((True, match.group(0)))
            position = match.end()
            continue
        tokens.append((False, line[position]))
        position += 1
    while True:
        index = None
        for candidate in range(len(tokens) - 1, -1, -1):
            if not tokens[candidate][0]:
                index = candidate
                break
        if index is None or tokens[index][1] != " ":
            break
        tokens.pop(index)
    return "".join(value for _, value in tokens)


def _finish(line, budget, is_color):
    room = budget
    for attempt in (0, 1):
        if is_color:
            text = _clip(line, room)
            if "48;" not in text and "\x1b[4" not in text:
                text = _trim_right(text)
            if "\x1b" in text and not text.endswith(RESET):
                text += RESET
        else:
            text = _trim_right(_clip(SGR.sub("", line), room))
        if SGR.sub("", text).strip():
            return text
        if attempt == 0:
            room = max(0, budget - 1)
    return text + ZERO_WIDTH_SPACE


def main():
    """Render the meadow panel for the payload on stdin, one row per line."""
    payload = _read_payload()
    budget = _env_int("COLUMNS", 96)
    rows = min(MAX_ROWS, max(MIN_ROWS, _env_int("SL_MEADOW_ROWS", DEFAULT_ROWS)))
    is_color = os.environ.get("SL_USE_COLOR", "1") != "0"
    is_quiet = (os.environ.get("SL_MEADOW_PINNED") == "1"
                or os.environ.get("SL_MEADOW_PREVIEW") == "1")
    now = float(_env_int("SL_MEADOW_NOW", int(time.time())))

    _prepare_environment(budget, rows, is_quiet)

    sys.path.insert(0, HERE)
    import daylight
    import meadow
    import skyband

    _patch(meadow, is_quiet, now)

    lines = [_finish(line, budget, is_color)
             for line in _rows(meadow, daylight, skyband, payload, budget, now)]
    sys.stdout.write("\n".join(lines))

    if not is_quiet:
        try:
            sys.stdout.flush()
            import skydriver
            skydriver.tick(now)
        except Exception:
            pass


if __name__ == "__main__":
    main()
