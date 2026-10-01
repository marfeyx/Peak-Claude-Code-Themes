"""Shared helpers for the status line themes.

Every theme module exposes `render(data) -> list[str]`, one string per row.
"""

import hashlib
import json
import os
import subprocess
import tempfile
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


BRANCH_TTL = 5  # seconds


def git_branch(cwd):
    """Current branch, memoised on disk for BRANCH_TTL seconds.

    `git branch --show-current` costs ~45 ms on a /mnt/c drvfs mount -- more
    than the whole rest of the frame -- and the status line re-renders a few
    times a second, so calling it every frame doubles the frame cost. The
    result is cached per-cwd. Failures and "not a repo" are cached too (as an
    empty file), so a non-git directory backs off instead of re-forking git on
    every single frame.
    """
    key = hashlib.md5(cwd.encode("utf-8", "replace")).hexdigest()[:16]
    path = os.path.join(tempfile.gettempdir(), "cc-sl-branch-%s" % key)

    try:
        if time.time() - os.path.getmtime(path) < BRANCH_TTL:
            with open(path) as fh:
                return fh.read().strip() or None
    except OSError:
        pass

    try:
        out = subprocess.run(
            ["git", "-C", cwd, "branch", "--show-current"],
            capture_output=True, text=True, timeout=1.5,
        )
        branch = out.stdout.strip()
    except Exception:
        branch = ""

    try:
        tmp = "%s.%d" % (path, os.getpid())
        with open(tmp, "w") as fh:
            fh.write(branch)
        os.replace(tmp, path)
    except OSError:
        pass

    return branch or None


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


class Pixels:
    """A half-block pixel layer that flushes onto a `Canvas`.

    A terminal cell is about twice as tall as it is wide, so sprites drawn one
    character per pixel come out stretched. This buffer holds two pixel rows per
    text row and emits "▀" / "▄", which makes the pixels roughly square.

    Only the pixels that were actually set are painted: a cell with just its top
    pixel keeps whatever background the canvas already had underneath, so the
    layer stays transparent over water shading or the terminal's own background.
    """

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
