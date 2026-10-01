"""Shared helpers for the status line themes.

Every theme module exposes `render(data) -> list[str]`, one string per row.
"""

import json
import os
import subprocess
import time

RESET = "\033[0m"
DIM = 240


def truecolor():
    return not os.environ.get("STATUSLINE_NO_TRUECOLOR")


def c(code, s):
    """256-colour foreground."""
    return f"\033[38;5;{code}m{s}{RESET}"


def rgb(r, g, b, s):
    """Truecolor foreground."""
    return f"\033[38;2;{r};{g};{b}m{s}{RESET}"


def hsv(h, s, v):
    """h in [0,1) -> (r, g, b) bytes."""
    i = int(h * 6) % 6
    f = h * 6 - int(h * 6)
    p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    r, g, b = ((v, t, p), (q, v, p), (p, v, t),
               (p, q, v), (t, p, v), (v, p, q))[i]
    return int(r * 255), int(g * 255), int(b * 255)


def lerp(a, b, t):
    return a + (b - a) * t


def lerp_rgb(c0, c1, t):
    t = max(0.0, min(1.0, t))
    return (int(lerp(c0[0], c1[0], t)),
            int(lerp(c0[1], c1[1], t)),
            int(lerp(c0[2], c1[2], t)))


def dig(d, *path, default=None):
    for k in path:
        if not isinstance(d, dict):
            return default
        d = d.get(k)
        if d is None:
            return default
    return d


def env_int(name, default):
    try:
        return int(os.environ.get(name) or default)
    except (TypeError, ValueError):
        return default


def term_size():
    """Claude Code exports COLUMNS and LINES before running the status line."""
    return env_int("COLUMNS", 80), env_int("LINES", 24)


def thousands(n):
    return f"{int(n):,}".replace(",", ".")


def money(x):
    return f"${x:,.2f}"


def short_path(p, budget=42):
    home = os.path.expanduser("~")
    if p.startswith(home):
        p = "~" + p[len(home):]
    if len(p) <= budget:
        return p
    parts = [x for x in p.split(os.sep) if x]
    tail = parts[-3:] if len(parts) > 3 else parts
    return "…/" + "/".join(tail)


def human_duration(ms):
    total = int(ms // 1000)
    h, m = total // 3600, (total % 3600) // 60
    if h and m:
        return f"{h} hour{'s' * (h != 1)} {m} minute{'s' * (m != 1)}"
    if h:
        return f"{h} hour{'s' * (h != 1)}"
    if m:
        return f"{m} minute{'s' * (m != 1)}"
    return f"{total} second{'s' * (total != 1)}"


def git_branch(cwd):
    try:
        out = subprocess.run(
            ["git", "-C", cwd, "branch", "--show-current"],
            capture_output=True, text=True, timeout=1.5,
        )
        return out.stdout.strip() or None
    except Exception:
        return None


BUILD_CLI = os.path.expanduser("~/.local/bin/build-cli")
USAGE_CACHE = "/tmp/cc-statusline-usage.json"
USAGE_TTL = 180  # seconds


def weekly_spend():
    """Return (spend, budget) or None. Never blocks on the network."""
    fresh = False
    try:
        fresh = (time.time() - os.path.getmtime(USAGE_CACHE)) < USAGE_TTL
    except OSError:
        pass

    if not fresh and os.access(BUILD_CLI, os.X_OK):
        try:
            with open(os.devnull, "wb") as null:
                subprocess.Popen(
                    ["/bin/sh", "-c",
                     f'{BUILD_CLI} usage --format json > {USAGE_CACHE}.tmp 2>/dev/null '
                     f'&& mv {USAGE_CACHE}.tmp {USAGE_CACHE}'],
                    stdout=null, stderr=null, stdin=null, start_new_session=True,
                )
        except Exception:
            pass

    try:
        with open(USAGE_CACHE) as fh:
            data = json.load(fh)
    except Exception:
        return None

    gw = data.get("ai_gateway") or {}
    budget = gw.get("budget")
    spend = None
    for path in (("current", "cost", "total"), ("cost", "total"),
                 ("total", "cost", "total"), ("spend",)):
        spend = dig(gw, *path)
        if spend is not None:
            break
    if spend is None:
        periods = gw.get("all") or []
        spend = dig(periods[0], "cost", "total", default=0) if periods else 0
    if budget is None:
        return None
    return float(spend or 0), float(budget)


class Canvas:
    """Character grid with per-cell foreground and background colours.

    Emits one escape sequence per colour run rather than per cell, which keeps a
    full-width panel to a few kilobytes instead of tens.
    """

    def __init__(self, width, height, bg=None, fg=None, fill=" "):
        self.width = width
        self.height = height
        self.cells = [[[fill, fg, bg] for _ in range(width)]
                      for _ in range(height)]

    def put(self, x, y, ch, fg=None, bg=None):
        if 0 <= x < self.width and 0 <= y < self.height:
            cell = self.cells[y][x]
            cell[0] = ch
            if fg is not None:
                cell[1] = fg
            if bg is not None:
                cell[2] = bg

    def text(self, x, y, s, fg=None, bg=None):
        for i, ch in enumerate(s):
            self.put(x + i, y, ch, fg, bg)

    def fill_row(self, y, bg, fg=None, ch=" "):
        if 0 <= y < self.height:
            for x in range(self.width):
                self.cells[y][x] = [ch, fg, bg]

    def rows(self):
        out = []
        for row in self.cells:
            buf = []
            cur_fg = cur_bg = False  # False = "not yet emitted"
            for ch, fg, bg in row:
                if bg != cur_bg:
                    buf.append("\033[49m" if bg is None
                               else "\033[48;2;%d;%d;%dm" % bg)
                    cur_bg = bg
                if fg != cur_fg:
                    buf.append("\033[39m" if fg is None
                               else "\033[38;2;%d;%d;%dm" % fg)
                    cur_fg = fg
                buf.append(ch)
            buf.append(RESET)
            out.append("".join(buf))
        return out


def _dist2(p, q):
    return (p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 + (p[2] - q[2]) ** 2


def _lum(c):
    return 0.30 * c[0] + 0.59 * c[1] + 0.11 * c[2]


def _error(counts, *picks):
    """Squared error of rendering `counts` with only `picks` available."""
    return sum(min(_dist2(col, p) for p in picks) * w for col, w in counts.items())


def _best_single(counts):
    """The one colour that represents the multiset with the least error."""
    return min(sorted(counts), key=lambda a: _error(counts, a))


def _best_pair(counts):
    """The two colours a cell can be drawn with most faithfully.

    Exhaustive over the distinct colours present, which is at most eight in a
    2x4 cell and so costs nothing, and beats clustering twice over. The two
    representatives are real input colours, so flat pixel art keeps its exact
    palette instead of drifting towards blends of it — a k-means pass on a cyan
    flank with a white eye returns a pale cyan and swallows the eye. And a rare
    but distant colour survives on its own merit, because dropping it is what
    costs the most: one white pixel among seven cyan ones is a far bigger error
    than shading all seven slightly wrong.

    Colours are walked in sorted order so that ties fall the same way whatever
    order the subpixels happened to arrive in. Everything about a cell's output
    then depends on its contents alone, never on where the sprite sits.
    """
    cols = sorted(counts)
    if len(cols) == 1:
        return cols[0], cols[0]
    best = None
    for i, a in enumerate(cols):
        for b in cols[i + 1:]:
            err = _error(counts, a, b)
            if best is None or err < best[0]:
                best = (err, a, b)
    return best[1], best[2]


class Pixels:
    """A half-block pixel layer that flushes onto a `Canvas`.

    A terminal cell is about twice as tall as it is wide, so sprites drawn one
    character per pixel come out stretched. This buffer holds two pixel rows per
    text row and emits "▀" / "▄", which makes the pixels roughly square.

    Only the pixels that were actually set are painted: a cell with just its top
    pixel keeps whatever background the canvas already had underneath, so the
    layer stays transparent over water shading or the terminal's own background.
    """

    ppr = 2          # pixel rows per text row
    ppc = 1          # pixel columns per text column

    def __init__(self, width, rows):
        self.width = width
        self.rows = rows
        self.height = rows * 2
        self.px = {}

    def set(self, x, y, colour):
        if colour is not None and 0 <= x < self.width and 0 <= y < self.height:
            self.px[(int(x), int(y))] = colour

    def blit(self, x0, y0, sprite, palette, flip=False):
        """Draw a sprite: rows of palette keys, "." meaning transparent."""
        span = max(len(line) for line in sprite)
        for dy, line in enumerate(sprite):
            for dx, key in enumerate(line):
                colour = palette.get(key)
                if colour is None:
                    continue
                self.set(x0 + (span - 1 - dx if flip else dx), y0 + dy, colour)

    def flush(self, canvas):
        cells = {}
        for (x, y), colour in self.px.items():
            cells.setdefault((x, y // 2), [None, None])[y % 2] = colour
        for (x, y), (top, bottom) in cells.items():
            if top is not None and bottom is not None:
                canvas.put(x, y, "▀", top, bottom)
            elif top is not None:
                canvas.put(x, y, "▀", top)
            else:
                canvas.put(x, y, "▄", bottom)


class OctantPixels(Pixels):
    """A 2x4 pixel layer: double the linear resolution of `Pixels`, same API.

    Unicode 16's octant glyphs cut a cell into eight subpixels, but a terminal
    cell still carries exactly two colours. The half-block layer gets away with
    this because two subpixels need two colours and no more; here eight subpixels
    have to be squeezed through the same two, so each cell picks one of:

      * one colour plus transparency - the glyph's set bits are painted and the
        rest show whatever is underneath, which is how sprites stay cut out
        against the background GIF, or
      * two colours, edge to edge - every subpixel painted, nothing shows
        through.

    What it cannot do is two colours *and* transparency, which is precisely the
    edge of a sprite: outline, body and open water meeting in one cell. Which
    compromise costs less is decided per cell by squared colour error, with a
    flat penalty for painting over background that should have stayed clear.
    Interiors come out exact; only silhouette cells pay anything.

    When the canvas already has a background colour under the cell - panel mode,
    where the water is painted rather than shown through - that colour joins the
    quantisation instead and the transparency problem disappears.
    """

    ppr = 4
    ppc = 2

    # Painting one subpixel that should have been clear, in squared-RGB units.
    # Roughly the cost of getting a pixel comprehensively wrong, so a cell only
    # goes opaque when the second colour really is worth more than the cutout.
    BG_PENALTY = 18000.0

    def __init__(self, cols, rows):
        self.cols = cols
        self.width = cols * self.ppc
        self.rows = rows
        self.height = rows * self.ppr
        self.px = {}

    def flush(self, canvas):
        cells = {}
        for (x, y), colour in self.px.items():
            slot = (y % 4) * 2 + (x % 2)
            cells.setdefault((x // 2, y // 4), [None] * 8)[slot] = colour
        for (cx, cy), slots in cells.items():
            if 0 <= cx < canvas.width and 0 <= cy < canvas.height:
                self._paint(canvas, cx, cy, slots)

    def _paint(self, canvas, cx, cy, slots):
        from octants import GLYPHS

        counts = {}
        for colour in slots:
            if colour is not None:
                counts[colour] = counts.get(colour, 0) + 1
        if not counts:
            return
        clear = sum(1 for colour in slots if colour is None)

        if len(counts) == 1:
            colour = next(iter(counts))
            if not clear:
                canvas.put(cx, cy, " ", None, colour)
                return
            bits = 0
            for i, col in enumerate(slots):
                if col is not None:
                    bits |= 1 << i
            canvas.put(cx, cy, GLYPHS[bits], colour)
            return

        under = canvas.cells[cy][cx][2]
        if clear and under is not None:
            counts[under] = counts.get(under, 0) + clear
            slots = [col if col is not None else under for col in slots]
            clear = 0

        a, b = _best_pair(counts)

        if clear:
            one = _best_single(counts)
            err_one = _error(counts, one)
            err_two = _error(counts, a, b) + clear * self.BG_PENALTY
            if err_one <= err_two:
                bits = 0
                for i, col in enumerate(slots):
                    if col is not None:
                        bits |= 1 << i
                canvas.put(cx, cy, GLYPHS[bits], one)
                return
            # Going opaque: the cleared subpixels take the darker of the two
            # colours, which on a sprite edge is the outline and reads as one.
            dark = a if _lum(a) <= _lum(b) else b
            slots = [col if col is not None else dark for col in slots]

        bits = 0
        for i, col in enumerate(slots):
            if _dist2(col, a) <= _dist2(col, b):
                bits |= 1 << i
        canvas.put(cx, cy, GLYPHS[bits], a, b)
