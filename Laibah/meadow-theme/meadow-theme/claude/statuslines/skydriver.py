"""Keeps the sky and the text colours in step with `daylight`'s clock.

The status line can paint its own rows and nothing else. The sky is Windows
Terminal's `backgroundImage`, the fallback text colours are its `colorScheme`,
and Claude Code's own UI colours are a third surface again -- all three live in
settings files, and the only way to move them is to write those files and let
the two applications hot-reload.

WHY SEGMENTS AND NOT ONE LONG GIF. Windows Terminal hands the GIF to XAML's
`Image` element and never touches playback: there is no API to read the current
frame, no way to seek, and (read off `TermControl::_SetBackgroundImage`) the
image object is *reused* across settings reloads whenever the URI is unchanged.
So a single loop-long GIF would run on its own clock, and any of the several
things that do reset it -- a new pane, a tab switch, XAML releasing the decoded
frames of a backgrounded tab after a second -- would leave the sky permanently
out of step with the field below it, with no way to detect or correct it.

Changing the URI, on the other hand, is the one thing that reliably restarts
playback from frame 0. Cutting the loop into segments turns that into the
mechanism: each boundary crossing points the profile at the next segment, which
restarts it at exactly the frame the clock says it should be at. The sky cannot
drift by more than one segment, and it re-anchors on its own.

WHAT THIS MODULE DOES, AND WHAT IT REFUSES TO DO. `tick()` is called from inside
a status line frame, which has a ~1 s budget and is on the hot path. It only
compares two small integers against a state file and, when they differ, spawns a
DETACHED process to do the actual work -- parsing and rewriting a settings.json
on a drvfs mount is tens of milliseconds at best and is not going to happen
inline. It also writes nothing itself, so a crash here cannot corrupt either
settings file.
"""

import json
import os
import subprocess
import time

import daylight

CLAUDE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APPLIER = os.path.join(CLAUDE_DIR, "sl-meadow-sky.py")
STATE_FILE = os.path.join(CLAUDE_DIR, "statusline-meadow-applied")
LOCK_FILE = os.path.join(CLAUDE_DIR, "statusline-meadow-apply.lock")

# An apply spawns a process that rewrites two settings files -- and, the first
# time round or after the period changes, renders the whole segment set first,
# which is about half a minute. Anything inside this window is assumed to be
# that process still working, not a missed boundary.
LOCK_TTL = 180.0


def enabled():
    """Only drive the terminal when there is a terminal of ours to drive."""
    if os.environ.get("SL_MEADOW_DRIVE_SKY") == "0":
        return False
    return bool(os.environ.get("WT_SESSION"))


def desired(p=None):
    if p is None:
        p = daylight.phase()
    return daylight.segment_of(p), daylight.is_dark(p)


def applied():
    try:
        with open(STATE_FILE) as fh:
            state = json.load(fh)
        return int(state["segment"]), bool(state["dark"])
    except (OSError, ValueError, KeyError, TypeError):
        return None


def _claim(now):
    """True if this process should be the one to run the apply.

    Not a real mutex -- several Claude Code sessions each render their own
    status line, and all of them cross the same boundary within a second of
    each other. The lock only has to stop them from all spawning: whoever
    replaces the file last owns the attempt, the others see a fresh lock next
    frame and stand down. A duplicate apply would be harmless anyway (the
    writes are idempotent), just wasteful.
    """
    try:
        if now - os.path.getmtime(LOCK_FILE) < LOCK_TTL:
            return False
    except OSError:
        pass
    try:
        tmp = "%s.%d" % (LOCK_FILE, os.getpid())
        with open(tmp, "w") as fh:
            fh.write("%d\n" % os.getpid())
        os.replace(tmp, LOCK_FILE)
        return True
    except OSError:
        return False


def tick(p=None, now=None):
    """Nudge the sky and the schemes toward phase `p`. Never blocks, never raises."""
    try:
        if not enabled() or not os.path.exists(APPLIER):
            return False
        want = desired(p)
        if applied() == want:
            return False
        if now is None:
            now = time.time()
        if not _claim(now):
            return False

        segment, dark = want
        with open(os.devnull, "wb") as null:
            subprocess.Popen(
                ["python3", APPLIER, "apply", str(segment),
                 "dark" if dark else "light"],
                stdout=null, stderr=null, stdin=null, start_new_session=True,
            )
        return True
    except Exception:
        return False
