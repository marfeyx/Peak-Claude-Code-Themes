"""Renders the animated water GIFs used as the Windows Terminal background.

One GIF per 10% context band. Water fills the bottom (100 - used)% of the image;
everything above the waterline is the transparent palette slot, so the terminal's
own background shows through instead of a painted sky.

The frames are built from horizontal runs rather than per pixel: within a run of
columns that share a waterline row, every pixel in a given row is the same colour,
so a frame costs a few thousand operations instead of width*height. It also makes
the rows long constant stretches, which is exactly what LZW compresses best.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gifwriter

WIDTH = 480
HEIGHT = 270
# One full wave cycle always spans FRAMES frames, so FRAMES * DELAY_CS is the
# loop duration and therefore the wave *speed*, while DELAY_CS alone is the frame
# rate. Keep LOOP_CS fixed and the water moves at the same pace no matter how
# finely it is sampled; change it and the sea speeds up or slows down.
LOOP_CS = 192         # 1.92 s per wave cycle — the original pace
DELAY_CS = 4          # 40 ms per frame -> 25 fps
FRAMES = LOOP_CS // DELAY_CS

RAMP_STEPS = 40
TRANSPARENT = 0
FOAM_BRIGHT = 1
FOAM = 2
RAMP_BASE = 3

SURFACE_RGB = (86, 168, 214)
DEEP_RGB = (6, 20, 46)
FOAM_BRIGHT_RGB = (188, 232, 250)
FOAM_RGB = (120, 196, 226)

WAVE_LEN_A = WIDTH / 6.0
WAVE_LEN_B = WIDTH / 11.0
WAVE_AMP_A = 7.0
WAVE_AMP_B = 2.5
SHIMMER_LEN = 57.0


# --- the submarine ----------------------------------------------------------
# Every band also gets a "sub" variant: the same sea, crossed once by a yellow
# submarine. It is a separate file rather than part of the ordinary loop because
# the ordinary loop is 1.92s long, and a submarine every 1.92s is not a surprise
# — the status line swaps the background over when it decides a pass is due and
# swaps back when it is over. The pass is a whole number of wave cycles long, so
# the sea keeps its pace across the swap.

SUB_BASE = RAMP_BASE + RAMP_STEPS
(SUB_EDGE, SUB_DARK, SUB_BODY, SUB_LIGHT,
 SUB_GLASS, SUB_GLINT, SUB_METAL) = range(SUB_BASE, SUB_BASE + 7)

SUB_RGB = [(22, 20, 12), (170, 106, 8), (250, 204, 21), (254, 240, 138),
           (104, 198, 248), (238, 250, 255), (150, 164, 184)]

SUB_BOX_W = 246          # the whole sprite: propeller, hull, tower, periscope
SUB_BOX_H = 96
HULL_X0, HULL_X1 = 34, 240
HULL_CY, HULL_B = 68, 25          # hull centre line and half height
HULL_N = 2.8                      # superellipse power: flatter flanks than 2
TOWER_X0, TOWER_X1, TOWER_TOP = 120, 170, 24
PERISCOPE_X = 152
PORTHOLES = (86, 122, 158, 196)
TAIL_LEN, TAIL_RISE = 26, 20

SUB_CEILING = 0.26       # preferred top of the sprite, as a fraction of height
SUB_SINK = 16            # keep at least this far below the deepest wave trough
SUB_FLOOR = 0.72         # the panel's scenery starts about here; stay above it

SUB_DELAY_CS = 8                        # 80 ms — half the sea's frame rate
SUB_LOOP_CS = 4 * LOOP_CS               # four wave cycles: 7.68 s
SUB_FRAMES = SUB_LOOP_CS // SUB_DELAY_CS
# Frames it spends crossing, leaving two seconds of empty sea at each end of the
# loop. The status line runs its lottery in slots exactly one loop long, so the
# swap back happens a whole loop after the swap in, give or take the time Windows
# Terminal takes to notice and the second the status line ticks on: those two
# quiet ends are the margin that keeps the sub from blinking out mid-screen.
SUB_ENTER, SUB_LEAVE = 25, 71
SUB_SPINS = 4                           # propeller phases


def palette():
    cols = [(0, 0, 0), FOAM_BRIGHT_RGB, FOAM_RGB]
    for i in range(RAMP_STEPS):
        t = i / (RAMP_STEPS - 1)
        cols.append((
            int(SURFACE_RGB[0] + (DEEP_RGB[0] - SURFACE_RGB[0]) * t),
            int(SURFACE_RGB[1] + (DEEP_RGB[1] - SURFACE_RGB[1]) * t),
            int(SURFACE_RGB[2] + (DEEP_RGB[2] - SURFACE_RGB[2]) * t),
        ))
    return cols + SUB_RGB


def _sub_grid(spin):
    """The submarine as a grid of palette indices, 0 where it is transparent.

    Drawn rather than pixelled out by hand: at this size — a fifth of the screen
    wide — hand-placed pixels would only be a coarser version of the same curves.
    Every part is laid down outline-first and then filled a few pixels inside it,
    which is what gives the whole thing one continuous dark edge.
    """
    g = [[0] * SUB_BOX_W for _ in range(SUB_BOX_H)]

    def put(x, y, idx):
        if 0 <= x < SUB_BOX_W and 0 <= y < SUB_BOX_H:
            g[y][x] = idx

    def column(x, y0, y1, idx):
        for y in range(int(round(y0)), int(round(y1)) + 1):
            put(x, y, idx)

    def disc(cx, cy, r, idx):
        for y in range(int(cy - r), int(cy + r) + 1):
            dy2 = (y - cy) ** 2
            for x in range(int(cx - r), int(cx + r) + 1):
                if (x - cx) ** 2 + dy2 <= r * r:
                    put(x, y, idx)

    cx = (HULL_X0 + HULL_X1) / 2.0
    ax = (HULL_X1 - HULL_X0) / 2.0

    def half(x, pad=0.0):
        """Half height of the hull at column x, or None beyond the ends."""
        u = abs((x - cx) / (ax + pad))
        if u > 1.0:
            return None
        return (HULL_B + pad) * (1.0 - u ** HULL_N) ** (1.0 / HULL_N)

    # Propeller first, so the hull and its shaft cover the root of it.
    hub = HULL_X0 - 10
    reach = 8 + 17 * abs(math.cos(spin * math.pi / SUB_SPINS))
    for x in range(hub - 5, hub + 6):
        u = abs(x - hub) / 5.0
        span = reach * (1.0 - u * u) ** 0.5
        column(x, HULL_CY - span - 1, HULL_CY + span + 1, SUB_EDGE)
    for x in range(hub - 3, hub + 4):
        u = abs(x - hub) / 3.5
        span = (reach - 3) * (1.0 - u * u) ** 0.5
        column(x, HULL_CY - span, HULL_CY + span, SUB_METAL)
    column(hub, HULL_CY - 3, HULL_CY + 3, SUB_EDGE)
    for x in range(hub + 4, HULL_X0 + 4):        # shaft
        column(x, HULL_CY - 3, HULL_CY + 3, SUB_EDGE)
        column(x, HULL_CY - 1, HULL_CY + 1, SUB_METAL)

    # Tail fins: a wedge standing above and below the stern.
    for i in range(TAIL_LEN):
        x = HULL_X0 + 4 + i
        rise = TAIL_RISE * (1.0 - i / TAIL_LEN) ** 0.8
        h = half(x, 3.0) or 0.0
        column(x, HULL_CY - h - rise, HULL_CY - h, SUB_EDGE)
        column(x, HULL_CY + h, HULL_CY + h + rise, SUB_EDGE)
        if rise > 4:
            column(x, HULL_CY - h - rise + 2, HULL_CY - h, SUB_DARK)
            column(x, HULL_CY + h, HULL_CY + h + rise - 2, SUB_DARK)

    # Conning tower, again outline then fill, with a periscope on top.
    column(PERISCOPE_X - 3, TOWER_TOP - 20, TOWER_TOP, SUB_EDGE)
    column(PERISCOPE_X + 3, TOWER_TOP - 20, TOWER_TOP, SUB_EDGE)
    for x in range(PERISCOPE_X - 2, PERISCOPE_X + 3):
        column(x, TOWER_TOP - 20, TOWER_TOP, SUB_METAL)
    for x in range(PERISCOPE_X - 3, PERISCOPE_X + 13):
        column(x, TOWER_TOP - 22, TOWER_TOP - 18, SUB_EDGE)
        column(x, TOWER_TOP - 21, TOWER_TOP - 19, SUB_METAL)

    for x in range(TOWER_X0 - 4, TOWER_X1 + 5):
        u = abs(x - (TOWER_X0 + TOWER_X1) / 2.0) / ((TOWER_X1 - TOWER_X0) / 2.0 + 4)
        if u > 1.0:
            continue
        lean = 10 * u * u                      # the tower is faired at the top
        column(x, TOWER_TOP + lean, HULL_CY, SUB_EDGE)
    for x in range(TOWER_X0, TOWER_X1 + 1):
        u = abs(x - (TOWER_X0 + TOWER_X1) / 2.0) / ((TOWER_X1 - TOWER_X0) / 2.0)
        lean = 10 * u * u
        column(x, TOWER_TOP + 3 + lean, HULL_CY, SUB_BODY)
        column(x, TOWER_TOP + 3 + lean, TOWER_TOP + 8 + lean, SUB_LIGHT)

    # Hull: the outline is the same superellipse, three pixels bigger all round.
    for x in range(HULL_X0 - 4, HULL_X1 + 5):
        h = half(x, 3.0)
        if h is not None:
            column(x, HULL_CY - h, HULL_CY + h, SUB_EDGE)
    for x in range(HULL_X0, HULL_X1 + 1):
        h = half(x)
        if h is None:
            continue
        top = HULL_CY - h
        for y in range(int(round(top)), int(round(HULL_CY + h)) + 1):
            depth = (y - top) / max(1.0, 2 * h)
            put(x, y, SUB_LIGHT if depth < 0.22 else
                      SUB_DARK if depth > 0.68 else SUB_BODY)

    for px in PORTHOLES:
        disc(px, HULL_CY - 2, 9, SUB_EDGE)
        disc(px, HULL_CY - 2, 6, SUB_GLASS)
        disc(px - 2, HULL_CY - 4, 2, SUB_GLINT)

    return g


def _sub_runs(spin, _cache={}):
    """The sprite as [(dy, x, length, index)], which is how it gets stamped."""
    if spin not in _cache:
        runs = []
        for y, row in enumerate(_sub_grid(spin)):
            x = 0
            while x < SUB_BOX_W:
                idx = row[x]
                end = x
                while end < SUB_BOX_W and row[end] == idx:
                    end += 1
                if idx:
                    runs.append((y, x, end - x, idx))
                x = end
        _cache[spin] = runs
    return _cache[spin]


def sub_top(band, height=HEIGHT):
    """Where the sprite sits: mid-screen, but never poking out of the water."""
    base = height * band / 100.0
    return max(int(height * SUB_CEILING), int(base + SUB_SINK))


def sub_fits(band, height=HEIGHT):
    """Is there room for a pass at this band, between the waves and the fish?"""
    return sub_top(band, height) + SUB_BOX_H <= height * SUB_FLOOR


def sub_place(band, f, width=WIDTH, height=HEIGHT, frames=SUB_FRAMES):
    """(x, y) of the sprite on frame f, or None while it is off stage."""
    enter = SUB_ENTER * frames // SUB_FRAMES
    leave = SUB_LEAVE * frames // SUB_FRAMES
    if not enter <= f <= leave:
        return None
    u = (f - enter) / float(leave - enter)
    x = int(round(-SUB_BOX_W + u * (width + SUB_BOX_W)))
    y = sub_top(band, height) + int(round(3 * math.sin(u * math.pi * 3)))
    return x, y


def _stamp(buf, width, height, runs, x0, y0):
    for dy, rx, length, idx in runs:
        y = y0 + dy
        if not 0 <= y < height:
            continue
        a = max(0, x0 + rx)
        b = min(width, x0 + rx + length)
        if b > a:
            buf[y * width + a:y * width + b] = bytes((idx,)) * (b - a)


def _runs(base, phase, width, amp_scale):
    """Columns grouped by integer waterline row: [(x_start, length, ys), ...]."""
    out = []
    start = 0
    prev = None
    for x in range(width):
        ys = base
        ys += WAVE_AMP_A * amp_scale * math.sin(2 * math.pi * x / WAVE_LEN_A + phase)
        ys += WAVE_AMP_B * amp_scale * math.sin(2 * math.pi * x / WAVE_LEN_B - 2 * phase)
        ys = int(round(ys))
        if prev is None:
            prev = ys
        elif ys != prev:
            out.append((start, x - start, prev))
            start = x
            prev = ys
    out.append((start, width - start, prev if prev is not None else base))
    return out


def frame(pct, phase, width, height):
    base = height * (pct / 100.0)
    # Shallow water should not slosh above the floor of the image.
    amp_scale = max(0.0, min(1.0, (height - base) / 24.0))
    runs = _runs(base, phase, width, amp_scale)

    shimmer = []
    for x0, length, ys in runs:
        mid = x0 + length / 2.0
        s = math.sin(2 * math.pi * mid / SHIMMER_LEN + 3 * phase)
        shimmer.append(int(round(s)))     # -1, 0 or 1

    buf = bytearray(width * height)
    for y in range(height):
        row = y * width
        for (x0, length, ys), sh in zip(runs, shimmer):
            if y < ys:
                continue                                  # air: leave transparent
            if y == ys:
                idx = FOAM_BRIGHT
            elif y == ys + 1:
                idx = FOAM
            else:
                depth = (y - ys) / max(1.0, height - ys)
                idx = RAMP_BASE + int(depth * (RAMP_STEPS - 1)) + sh
                idx = max(RAMP_BASE, min(RAMP_BASE + RAMP_STEPS - 1, idx))
            buf[row + x0:row + x0 + length] = bytes((idx,)) * length
    return bytes(buf)


def build(path, pct, width=WIDTH, height=HEIGHT, frames=FRAMES):
    imgs = [frame(pct, 2 * math.pi * f / frames, width, height)
            for f in range(frames)]
    return gifwriter.write_gif(path, width, height, palette(), imgs,
                               delay_cs=DELAY_CS, transparent_index=TRANSPARENT)


def build_sub(path, band, width=WIDTH, height=HEIGHT, frames=SUB_FRAMES):
    """The same sea, crossed once by the submarine, then quiet for a moment.

    The quiet tail matters: the status line swaps this file out a beat after the
    pass should have ended, and the swap has to land somewhere the sub cannot be
    seen, or it would blink out of existence mid-screen.
    """
    imgs = []
    for f in range(frames):
        phase = 2 * math.pi * f * SUB_DELAY_CS / LOOP_CS
        buf = bytearray(frame(band, phase, width, height))
        at = sub_place(band, f, width, height, frames)
        if at is not None:
            _stamp(buf, width, height, _sub_runs(f % SUB_SPINS), *at)
        imgs.append(bytes(buf))
    return gifwriter.write_gif(path, width, height, palette(), imgs,
                               delay_cs=SUB_DELAY_CS,
                               transparent_index=TRANSPARENT)


def band_name(band):
    return "water-%03d.gif" % band


def sub_name(band):
    return "water-%03d-sub.gif" % band


def build_all(out_dir, step=10, width=WIDTH, height=HEIGHT, frames=FRAMES,
              log=None):
    os.makedirs(out_dir, exist_ok=True)
    written = []
    for band in range(0, 101, step):
        path = os.path.join(out_dir, band_name(band))
        size = build(path, band, width, height, frames)
        written.append((band, path, size))
        if log:
            log(band, path, size)
        if sub_fits(band, height):
            path = os.path.join(out_dir, sub_name(band))
            size = build_sub(path, band, width, height)
            written.append((band, path, size))
            if log:
                log(band, path, size)
    return written


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "/tmp/water"
    build_all(target, log=lambda b, p, s: print("band %3d%% -> %s (%d KB)"
                                                % (b, os.path.basename(p), s // 1024)))
