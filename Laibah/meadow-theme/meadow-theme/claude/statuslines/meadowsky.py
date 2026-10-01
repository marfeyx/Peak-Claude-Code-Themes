"""Renders the animated sky GIFs used as the Windows Terminal background.

The status line can only paint its own rows, so putting sky behind the WHOLE
window means Windows Terminal's per-profile `backgroundImage`. This generates
it; `sl-meadow-sky.py` points the profile at the right one.

THE SKY CARRIES THE DAY CYCLE. `daylight.py` blends three looks -- day, sunset,
night -- around a loop, and every frame here is coloured from that blend at the
moment the frame plays. The pixels are palette INDICES (which sky band, which
cloud tone, which star), so the whole cycle costs nothing but a different colour
table per frame: GIF89a lets each frame carry its own Local Colour Table, and
that is the only reason a half-hour of sky fits in a few megabytes.

SEGMENTS. The loop is cut into pieces, one GIF each, because Windows Terminal
gives no way to read or seek a background GIF's playback position -- and the
cheap parts of the cycle would drift out of step with the panel below with no
way to notice. Pointing the profile at a different file is the one thing that
reliably restarts playback, so each segment boundary re-anchors the sky to the
same clock the panel uses. Cloud drift, disc position and palette are all pure
functions of the GLOBAL frame index, so the seams are continuous.

SEAMLESS LOOPING is still the constraint that shapes the clouds. A GIF restarts
hard, so any drift that does not land exactly back where it started shows up as
a jump once per loop. Every cloud therefore travels an exact whole number of
screen widths over the WHOLE loop and is drawn with wraparound. Because the loop
is now half an hour rather than eighty seconds, that whole number is large --
see LAPS_FAR -- which is what keeps the clouds moving at their original speed
instead of freezing into a still.

Deliberately low resolution. The image is stretched over a ~1900 px window, so
320 px across gives roughly 6 screen pixels per art pixel -- which is what makes
it read as pixel art rather than as a blurry photo. Generating it larger would
look worse, not better.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import daylight
import gifwriter

# Bump when the ART changes in a way that should force a rebuild. Period and
# segment count are tracked separately, in the manifest.
REVISION = 2

WIDTH = 320
HEIGHT = 180
DELAY_CS = 50          # 0.5 s per frame

# Eighty seconds per crossing for the far band, forty for the near one -- the
# speed the single-loop sky was tuned to. Held constant as the loop got longer
# by raising the lap count rather than the step: seamlessness requires a whole
# number of widths per loop, so the laps are what has to scale.
SECONDS_PER_LAP = 80.0

SKY_STEPS = 32
I_LIT = SKY_STEPS
I_MID = SKY_STEPS + 1
I_SHADE = SKY_STEPS + 2
I_DISC = SKY_STEPS + 3
I_GLOW = SKY_STEPS + 4
I_STAR = SKY_STEPS + 5          # first of STAR_BANDS * STAR_CLASSES slots

# Stars cannot simply be "white pixels": by day they have to disappear, and a
# GIF index is one colour per frame for the whole image. So a star's index
# encodes WHICH SKY BAND it sits in, and by day that index is set to the colour
# of the band it is in -- the star is still there, painted in sky. Four bands is
# enough that the mismatch (at most an eighth of the gradient) is invisible.
#
# The three classes on top of that are the twinkle. Each class pulses on its own
# co-prime period, entirely in the colour table, so the pixels never change and
# the twinkle costs nothing.
STAR_BANDS = 4
STAR_CLASSES = 3
STAR_PERIODS = (7, 11, 13)      # frames
STARS = 90
STAR_CEILING = 0.58             # stars only above this fraction of the image

PALETTE_LEN = I_STAR + STAR_BANDS * STAR_CLASSES

# The sun and the moon are the same disc on the same arc, half a loop apart.
# Its span above the horizon is set against `daylight.STOPS`, so the disc
# touches down in the middle of the sunset dwell and comes back up in the middle
# of the dawn one -- the colour and the geometry describe the same event.
SUN_RISE = 0.895
SUN_SET = 0.38
DISC_HORIZON = 0.62             # fraction of HEIGHT the disc sets into
DISC_APEX = 0.09
SUN_R = 11
MOON_R = 8

M64 = 0xFFFFFFFFFFFFFFFF


def noise(*key):
    h = 0x9E3779B97F4A7C15
    for k in key:
        h = (h + (int(k) & M64) + 0x9E3779B97F4A7C15) & M64
        h = ((h ^ (h >> 30)) * 0xBF58476D1CE4E5B9) & M64
        h = ((h ^ (h >> 27)) * 0x94D049BB133111EB) & M64
        h ^= h >> 31
    return (h & 0xFFFFFFFF) / 4294967296.0


# --- timing -----------------------------------------------------------------

def total_frames():
    """Frames in the whole loop. Rounded up to a multiple of the segment count
    so every segment is the same length and the seams land on frame boundaries."""
    n = daylight.segments()
    raw = max(n, int(round(daylight.period() / (DELAY_CS / 100.0))))
    return ((raw + n - 1) // n) * n


def laps_far():
    """Whole screen-widths the far band travels per loop. Never zero."""
    return max(1, int(round(daylight.period() / SECONDS_PER_LAP)))


# --- palette -----------------------------------------------------------------

def sky_ramp(pal):
    """SKY_STEPS colours from the top of the frame down to the horizon.

    Three stops, not two. A sunset is not a line in RGB between a blue zenith
    and a gold horizon -- that line runs through mud. The middle stop is what
    puts the band of rose where it belongs; day and night place theirs on the
    straight line anyway, so they are unaffected.
    """
    top, mid, low = pal["sky_top"], pal["sky_mid"], pal["sky_horizon"]
    out = []
    for i in range(SKY_STEPS):
        t = i / float(SKY_STEPS - 1)
        if t <= 0.5:
            a, b, u = top, mid, t * 2.0
        else:
            a, b, u = mid, low, (t - 0.5) * 2.0
        out.append(tuple(int(round(a[c] + (b[c] - a[c]) * u)) for c in range(3)))
    return out


def star_band_index(ramp, band):
    """Which sky colour a star in `band` is hiding against by day."""
    rows = STAR_CEILING * (SKY_STEPS - 1)
    return ramp[min(SKY_STEPS - 1, int((band + 0.5) / STAR_BANDS * rows))]


def frame_palette(p, f):
    """The colour table for the frame at phase `p`, global frame index `f`."""
    pal = daylight.palette(p)
    night = daylight.nightness(p)
    ramp = sky_ramp(pal)

    cols = list(ramp)
    cols += [pal["cloud_lit"], pal["cloud_mid"], pal["cloud_shade"]]
    cols += [pal["disc"], pal["disc_glow"]]

    star = pal["star"]
    for band in range(STAR_BANDS):
        hidden = star_band_index(ramp, band)
        for cls in range(STAR_CLASSES):
            twinkle = 0.55 + 0.45 * math.sin(
                2.0 * math.pi * (f / float(STAR_PERIODS[cls]) + cls / 3.0))
            k = night * twinkle
            cols.append(tuple(int(round(hidden[c] + (star[c] - hidden[c]) * k))
                              for c in range(3)))
    return cols


# --- clouds ------------------------------------------------------------------

def make_cloud(seed):
    """A cumulus as a union of discs, returned as (w, h, set-of-(x,y)).

    Discs rather than a hand-drawn grid because these are four times the size of
    the ones in the panel and hand-authoring them at this scale is all downside.
    The radii rise to a peak and fall away, which is what gives a cumulus its
    one tall shoulder instead of a symmetric mound.
    """
    lobes = 5 + int(noise(seed, 3) * 4)
    r_max = 11 + int(noise(seed, 11) * 10)
    step = max(3, int(r_max * 0.68))
    peak = 0.30 + 0.40 * noise(seed, 29)

    discs = []
    xs = []
    x = r_max
    for i in range(lobes):
        f = i / float(max(1, lobes - 1))
        d = abs(f - peak) / max(peak, 1.0 - peak)
        r = max(3, int(r_max * (1.0 - 0.45 * d) * (0.82 + 0.36 * noise(seed, i, 7))))
        discs.append((x, r_max, r))          # common centre line -> flat base
        xs.append((x, r, f))
        x += step + int(noise(seed, i, 13) * 3)

    for j in range(1 + int(noise(seed, 31) * 2)):
        cx, cr, _ = min(xs, key=lambda e: abs(e[2] - peak))
        off = int((noise(seed, j, 37) - 0.5) * cr)
        rr = max(3, int(cr * (0.62 - 0.12 * j)))
        discs.append((cx + off, r_max - int(cr * (0.55 + 0.45 * j)), rr))

    w = x + r_max
    base = r_max + max(r for cx, cy, r in discs if cy == r_max)
    h = base + 2

    mask = set()
    for cx, cy, r in discs:
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dx * dx + dy * dy <= r * r:
                    mask.add((cx + dx, cy + dy))
    mask = {(px, py) for px, py in mask if py <= base}
    return w, h, mask


def shade_cloud(mask):
    """Split a cloud mask into lit / mid / shaded pixels by column depth."""
    cols = {}
    for px, py in mask:
        lo, hi = cols.get(px, (py, py))
        cols[px] = (min(lo, py), max(hi, py))

    lit, mid, shade = set(), set(), set()
    for px, py in mask:
        top, bottom = cols[px]
        depth = py - top
        height = max(1, bottom - top)
        if depth <= max(1, int(height * 0.30)):
            lit.add((px, py))
        elif py >= bottom - max(1, int(height * 0.22)):
            shade.add((px, py))
        else:
            mid.add((px, py))
    return lit, mid, shade


def build_clouds():
    """Lay the clouds out once, flattened into the form `frame` wants.

    Each cloud becomes a list of (row_offset, x, index) with the row already
    multiplied out and off-image rows dropped. The inner loop then costs one
    modulo and one store per pixel instead of a bounds check and two
    multiplications, which is the difference between a two-minute build and a
    ten-minute one at this frame count.
    """
    out = []
    n = 9
    for i in range(n):
        w, h, mask = make_cloud(i)
        lit, mid, shade = shade_cloud(mask)
        # Near clouds (every third) move at twice the speed and sit lower.
        #
        # Both bands stay in the top ~55% of the image. The status line's field
        # occupies the bottom third of the window and is transparent between the
        # blades, so a cloud any lower shows THROUGH the grass -- white blobs at
        # ground level, which reads as fog in the field rather than sky.
        near = (i % 3 == 0)
        band_lo = 0.30 if near else 0.03
        band_hi = 0.52 if near else 0.28
        y0 = int((band_lo + (band_hi - band_lo) * noise(i, 41)) * HEIGHT)
        x0 = int(noise(i, 53) * WIDTH)

        pixels = []
        for tone, index in ((shade, I_SHADE), (mid, I_MID), (lit, I_LIT)):
            for px, py in tone:
                y = y0 + py
                if 0 <= y < HEIGHT:
                    pixels.append((y * WIDTH, px, index))
        out.append({"x0": x0, "k": 2 if near else 1, "pixels": pixels})
    return out


# --- the static layers -------------------------------------------------------

def background():
    """Gradient plus stars, as one buffer to copy per frame.

    Neither moves: the gradient is fixed and a star's position is fixed, because
    everything that changes about them changes in the colour table instead. So
    the whole layer is built once and each frame starts life as a copy of it,
    which is a C-level memcpy rather than 57 600 Python stores.
    """
    buf = bytearray(WIDTH * HEIGHT)
    for y in range(HEIGHT):
        idx = min(SKY_STEPS - 1, int(y / float(HEIGHT - 1) * SKY_STEPS))
        row = y * WIDTH
        buf[row:row + WIDTH] = bytes((idx,)) * WIDTH

    ceiling = int(HEIGHT * STAR_CEILING)
    for s in range(STARS):
        x = int(noise(s, 811) * WIDTH)
        # Squared, so stars crowd the top of the frame and thin out toward the
        # horizon. Spread evenly they read as a texture rather than as a sky.
        y = int((noise(s, 823) ** 2) * ceiling)
        band = min(STAR_BANDS - 1, int(y / float(max(1, ceiling)) * STAR_BANDS))
        cls = int(noise(s, 829) * STAR_CLASSES) % STAR_CLASSES
        buf[y * WIDTH + x] = I_STAR + band * STAR_CLASSES + cls
    return bytes(buf)


BACKGROUND = None


def disc_position(p):
    """(x, y, radius) of the sun or moon at phase `p`, or None below the horizon."""
    span = (SUN_SET - SUN_RISE) % 1.0            # sun's share of the loop
    u = ((p - SUN_RISE) % 1.0) / span
    radius = SUN_R
    if u > 1.0:
        # Below the horizon means the other body is up: the moon runs the same
        # arc over the rest of the loop.
        u = ((p - SUN_SET) % 1.0) / (1.0 - span)
        radius = MOON_R
    x = WIDTH * (0.08 + 0.84 * u)
    y = HEIGHT * (DISC_HORIZON - (DISC_HORIZON - DISC_APEX) * math.sin(math.pi * u))
    return int(round(x)), int(round(y)), radius


def draw_disc(buf, p):
    x0, y0, r = disc_position(p)
    glow = r + max(3, r // 2)
    for dy in range(-glow, glow + 1):
        y = y0 + dy
        if not (0 <= y < HEIGHT):
            continue
        row = y * WIDTH
        for dx in range(-glow, glow + 1):
            d2 = dx * dx + dy * dy
            if d2 > glow * glow:
                continue
            buf[row + ((x0 + dx) % WIDTH)] = I_DISC if d2 <= r * r else I_GLOW


def frame(clouds, f, total):
    buf = bytearray(BACKGROUND)
    p = f / float(total)
    draw_disc(buf, p)

    laps = laps_far()
    for cl in clouds:
        shift = (cl["x0"] + f * cl["k"] * laps * WIDTH // total) % WIDTH
        for row, px, index in cl["pixels"]:
            # Wraparound, not clipping: a cloud leaving the right edge is the
            # same cloud entering on the left.
            buf[row + (px + shift) % WIDTH] = index
    return bytes(buf)


# --- output ------------------------------------------------------------------

def _prepare():
    global BACKGROUND
    if BACKGROUND is None:
        BACKGROUND = background()
    return build_clouds()


def build_segment(path, index, count, total=None):
    """Write segment `index` of `count`. Returns the file size in bytes."""
    clouds = _prepare()
    if total is None:
        total = total_frames()
    per = total // count
    first = index * per

    frames, palettes = [], []
    for j in range(per):
        f = first + j
        frames.append(frame(clouds, f, total))
        palettes.append(frame_palette(f / float(total), f))

    # Opaque frames, so disposal 1 ("leave in place") is both correct and
    # smaller than clearing between frames. No transparent slot at all: the sky
    # IS the background, rather than letting the terminal's own show through.
    # Disposal stays in 0-3 -- XAML's image decoder refuses to render GIFs that
    # use the reserved values.
    return gifwriter.write_gif(path, WIDTH, HEIGHT, palettes, frames,
                               delay_cs=DELAY_CS, transparent_index=None,
                               disposal=1)


def build(path, frames=160):
    """A single static-palette sky, in the daytime look.

    Kept for the fallback in `sl-meadow-sky.py`: if the segment set is missing
    or half-built, a window with a midday sky is a much better failure than a
    window with none.
    """
    clouds = _prepare()
    total = frames
    imgs = [frame(clouds, f, total) for f in range(frames)]
    return gifwriter.write_gif(path, WIDTH, HEIGHT, frame_palette(0.0, 0), imgs,
                               delay_cs=DELAY_CS, transparent_index=None,
                               disposal=1)


def verify_seamless():
    """Frame 0 and frame `total` must be identical, or the loop visibly jumps."""
    clouds = _prepare()
    total = total_frames()
    return frame(clouds, 0, total) == frame(clouds, total, total)


if __name__ == "__main__":
    import time
    total = total_frames()
    n = daylight.segments()
    print("period %.0fs  %d frames  %d segments x %d frames  %d laps"
          % (daylight.period(), total, n, total // n, laps_far()))
    print("seamless:", verify_seamless())

    target = sys.argv[1] if len(sys.argv) > 1 else "/tmp"
    t0 = time.time()
    written = 0
    for i in range(n):
        path = os.path.join(target, "meadow-sky-%02d.gif" % i)
        size = build_segment(path, i, n, total)
        written += size
        print("  %s  %d KB" % (os.path.basename(path), size // 1024))
    print("%.1f MB in %.0f s" % (written / 1048576.0, time.time() - t0))
