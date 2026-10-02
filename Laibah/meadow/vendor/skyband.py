"""Decide which band of the meadow day cycle is on screen.

Three separate things have to agree about this: the grass panel the status line
draws, the sky GIF Windows Terminal shows behind it, and the colour scheme the
text is read against. Upstream's daylight.py answers the two halves of the
question independently -- segment_of() cuts the loop into six, is_dark() crosses
its own two thresholds -- and the two sets of boundaries do not line up, so the
cycle used to change state eight times and twice did it mid-segment, pairing a
light scheme with a night sky and a dark scheme with a daylight one.

This module is the host's, not upstream's. It answers the question once, for
everyone: the segment comes from daylight, and the darkness is read at the
segment's own midpoint, so a band changes exactly when the image changes and the
scheme that goes with it always matches the picture it is read against. Six
segments means six crossings per cycle and never more.

It also owns the clock. daylight.phase() reads the wall clock when it is given
nothing, which left SL_FAKE_NOW reaching the panel and not the sky, so a pinned
render showed a sky from a different part of the day and no pinned test could
tell a wrong one from a right one. Every caller here goes through now().

The period knob is repaired the same way, by patching rather than by editing
upstream: daylight derives its period file from its own location, which was
~/.claude when it lived there and is ~/.claude/statusline/vendor now that it is
vendored a level deeper -- a directory nothing in this port reads or writes. It
is pointed back at the state directory, so a persisted period works again
instead of silently doing nothing.
"""

import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
STATUSLINE_HOME = os.path.dirname(os.path.dirname(HERE))
STATE_DIR = os.path.join(os.path.dirname(STATUSLINE_HOME), "statusline-state")
PERIOD_FILE = os.path.join(STATE_DIR, "meadow-period")


def _daylight():
    if HERE not in sys.path:
        sys.path.insert(0, HERE)
    import daylight
    daylight.PERIOD_FILE = PERIOD_FILE
    return daylight


def _env_float(name):
    try:
        return float((os.environ.get(name) or "").strip())
    except (AttributeError, ValueError):
        return None


def now():
    """Return the timestamp the whole theme is rendering, pins included."""
    for name in ("SL_MEADOW_NOW", "SL_FAKE_NOW"):
        value = _env_float(name)
        if value is not None:
            return value
    return time.time()


def phase(when=None):
    """Return the position in the day cycle, in [0, 1)."""
    return _daylight().phase(now() if when is None else when)


def segments():
    """Return how many segments the day cycle is cut into."""
    return _daylight().segments()


def band(when=None):
    """Return the segment index and darkness the day cycle is asking for.

    Darkness is read at the segment's midpoint rather than at the exact phase,
    which is what keeps the scheme and the image changing on the same boundary.
    """
    daylight = _daylight()
    value = phase(when)
    count = max(1, segments())
    index = daylight.segment_of(value)
    midpoint = (index + 0.5) / float(count)
    return index, bool(daylight.is_dark(midpoint))


def look_name(when=None):
    """Return the nearest keyframe name of the current phase, for reporting."""
    return _daylight().look_name(phase(when))


def transitions():
    """Return every band the cycle passes through, in order, for testing."""
    count = max(1, segments())
    return [band((index + 0.5) / float(count) * _daylight().period())
            for index in range(count)]


_daylight()
