#!/usr/bin/env python3
"""Bridge Livio's vendored renderers onto this statusline's contract.

Reads the Claude Code status-line payload on stdin and prints one ready-to-emit
row per line. The themes/*.sh wrappers pipe the payload in and hand every line
straight to sl_emit_raw, because width has already been enforced here.

The theme modules beside this file are byte-identical copies of Livio's
delivery. Everything this system needs that his framework does not provide is
done here, by patching the imported module objects at runtime, so the vendored
sources stay clean and a future refresh is a plain file copy. The one module
that is not a copy is gifwriter.py, which is an inert stub.

What the bridge has to fix, and why:

CONFIG SAFETY. Three of his renderers reach configuration from inside a frame.
water.sync_band and vice.sync_background spawn sl-water-bg.py, which rewrites
Windows Terminal's settings.json, and vice also touches a cooldown stamp file;
both are gated on a state file his switcher writes, so they are armed the
moment a background is applied. common.weekly_spend forks a shell per frame to
refresh a world-writable cache under /tmp. None of it survives here:
sl-water-bg.py is not vendored at all, every gif_mode() is forced to False so
the branches containing those calls are unreachable, the two sync functions are
replaced with no-ops anyway, and weekly_spend reads the gateway figures this
system already resolved. Nothing below can write anything.

WIDTH. Upstream reads COLUMNS and renders full bleed. This system budgets
against SL_COLUMNS, which is COLUMNS minus a safety margin, and check.sh fails
any row wider than that. The wrapper passes SL_COLUMNS in as COLUMNS and the
padding upstream subtracts is zeroed, so the renderers aim at the budget
exactly. Three of them miss anyway:

  * vice.scene builds its Canvas from the pixel width rather than the text
    width, so at octant resolution every scenery row comes out twice the
    budget. Its own GIF path and kyoto both get this right. Rather than edit
    his source, vice.Canvas is replaced with a factory that clamps the width;
    the pixel layer already flushes in text-cell coordinates, so clamping the
    canvas is all the fix needs.
  * water.info_row joins its segments with no budget and is a fixed 163 cells
    at every terminal width, and rgb does the same on its two text rows.
    Both are shed segment by segment here, splitting on the separator the
    module itself uses, so a narrow terminal loses the tail of the row instead
    of wrapping the prompt.

A cell-accurate clip is still applied to every row afterwards as a second line
of defence, because a wide glyph in a path or a branch name cannot be budgeted
for upstream.

NO_COLOR. Upstream honours STATUSLINE_NO_TRUECOLOR but not NO_COLOR. Under
NO_COLOR the bridge asks for the no-truecolour fallback and then strips every
escape itself, because those fallbacks still emit 256-colour sequences. It does
not keep the truecolour scene in that mode the way the meadow bridge does: an
aquarium's water body is painted background with a space in it, so stripping
the colour leaves blank rows rather than legible art. Rows that come out empty
are dropped instead of padded, since without colour they carry nothing, and the
panel is capped short.

BLANK ROWS. Claude Code drops a status row that is empty once escapes are
stripped, which would silently shorten a panel. Any such row gets a zero-width
space, and the cell it occupies is budgeted for before the clip rather than
appended after it.

TRAILING WHITESPACE. A row that paints a background to the edge legitimately
ends in spaces and check.sh waives it. A row that paints no background must be
right-trimmed or it fails, so the trim is applied only to rows carrying no
background escape.

DETERMINISM. Every one of his renderers calls time.time() in the render path,
and vice also calls time.localtime() for its day-night cycle. The time module
each one imported is replaced with a shim pinned to SL_NOW, so two renders of
the same instant are byte-identical. common.git_branch forks git per frame; it
is replaced with the branch this system already resolved, so no frame forks a
process.

Environment, all set by the themes/*.sh wrappers:
  COLUMNS              the width budget, in cells
  SL_USE_COLOR         0 to ask for the fallback and strip every escape
  SL_LIVIO_THEME       water, water2, kyoto or vice
  SL_LIVIO_NOW         epoch seconds driving every animation
  SL_LIVIO_ROWS        requested panel height in rows
  SL_LIVIO_BRANCH      git branch, already resolved by the host
  SL_LIVIO_SPENT       gateway spend for the period, blank when unknown
  SL_LIVIO_LIMIT       gateway budget for the period, blank when unknown
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

THEMES = ("water", "water2", "kyoto", "vice")
PANEL_THEMES = ("water", "water2", "kyoto", "vice")
HEIGHT_VARIABLE = {"water": "SL_WATER_HEIGHT", "water2": "SL_WATER_HEIGHT",
                   "kyoto": "SL_KYOTO_HEIGHT", "vice": "SL_VICE_HEIGHT"}
MINIMUM_ROWS = 5
MAXIMUM_ROWS = 24
DEFAULT_ROWS = 12
PLAIN_ROWS = 5
ROWS_PER_COLUMN = 3
FALLBACK_COLUMNS = 96


def _env_int(name, default):
    try:
        return int(float(os.environ.get(name) or default))
    except (TypeError, ValueError):
        return default


def _env_float(name):
    try:
        return float(os.environ.get(name) or "")
    except (TypeError, ValueError):
        return None


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


class Clock:
    """Stand-in for the time module, pinned to the timestamp handed in."""

    def __init__(self, now):
        self._now = float(now)

    def time(self):
        """Returns the pinned timestamp instead of the wall clock."""
        return self._now

    def localtime(self, when=None):
        """Returns local time for the pinned timestamp unless one is given."""
        return time.localtime(self._now if when is None else when)

    def strftime(self, fmt, when=None):
        """Formats the pinned timestamp unless a time tuple is given."""
        return time.strftime(fmt, self.localtime() if when is None else when)


def _theme_name():
    name = (os.environ.get("SL_LIVIO_THEME") or "").strip().lower()
    return name if name in THEMES else "water"


def _panel_rows(name, budget, is_color):
    if name not in PANEL_THEMES:
        return 0
    requested = _env_int("SL_LIVIO_ROWS", DEFAULT_ROWS)
    requested = max(MINIMUM_ROWS, min(MAXIMUM_ROWS, requested))
    if not is_color:
        requested = min(requested, PLAIN_ROWS)
    return max(MINIMUM_ROWS, min(requested, max(MINIMUM_ROWS,
                                                budget // ROWS_PER_COLUMN)))


def _prepare_environment(name, budget, rows, is_color):
    os.environ["COLUMNS"] = str(budget)
    os.environ["LINES"] = str(rows + 10)
    os.environ["STATUSLINE_RULE_PAD"] = "0"
    if name in HEIGHT_VARIABLE:
        os.environ[HEIGHT_VARIABLE[name]] = str(rows)
    if is_color:
        os.environ.pop("STATUSLINE_NO_TRUECOLOR", None)
    else:
        os.environ["STATUSLINE_NO_TRUECOLOR"] = "1"


def _gateway():
    spent = _env_float("SL_LIVIO_SPENT")
    limit = _env_float("SL_LIVIO_LIMIT")
    if spent is None or limit is None or limit <= 0:
        return None
    return spent, limit


def _patch_common(common):
    branch = os.environ.get("SL_LIVIO_BRANCH") or ""
    gateway = _gateway()
    common.git_branch = lambda cwd: branch or None
    common.weekly_spend = lambda: gateway


def _patch_theme(module, name, clock, budget):
    module.time = clock
    if name in PANEL_THEMES:
        module.gif_mode = lambda: False
        module.forced_pct = lambda: None
    if name in ("water", "water2"):
        module.sync_band = lambda pct: 0
    if name == "water2":
        _patch_theme(module.water, "water", clock, budget)
    if name == "vice":
        module.sync_background = lambda hour: None
        module.Canvas = _clamped_canvas(module.Canvas, budget)


def _clamped_canvas(base, limit):
    def make(width, height, *args, **kwargs):
        return base(min(width, limit), height, *args, **kwargs)
    return make


def _separator(common, module, name):
    if name in ("water", "water2"):
        return common.c(common.DIM, "  ·  ")
    return ""


def _shed(line, separator, budget):
    if not separator or _cells(SGR.sub("", line)) <= budget:
        return line
    segments = line.split(separator)
    while len(segments) > 1:
        segments.pop()
        candidate = separator.join(segments)
        if _cells(SGR.sub("", candidate)) <= budget:
            return candidate
    return segments[0]


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
    """Render one of Livio's themes for the payload on stdin, one row per line."""
    payload = _read_payload()
    name = _theme_name()
    budget = max(4, _env_int("COLUMNS", FALLBACK_COLUMNS))
    is_color = os.environ.get("SL_USE_COLOR", "1") != "0"
    rows = _panel_rows(name, budget, is_color)
    clock = Clock(_env_int("SL_LIVIO_NOW", int(time.time())))

    _prepare_environment(name, budget, rows, is_color)

    sys.path.insert(0, HERE)
    import common

    _patch_common(common)
    module = __import__(name)
    _patch_theme(module, name, clock, budget)

    separator = _separator(common, module, name)
    lines = []
    for line in module.render(payload):
        shed = _shed(line, separator, budget)
        if not is_color and not SGR.sub("", shed).strip():
            continue
        lines.append(_finish(shed, budget, is_color))
    if not lines:
        lines = [ZERO_WIDTH_SPACE]
    sys.stdout.write("\n".join(lines))


if __name__ == "__main__":
    main()
