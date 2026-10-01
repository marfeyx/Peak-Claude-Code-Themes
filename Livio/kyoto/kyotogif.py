"""Render the Kyoto valley to a single looping GIF for the terminal background.

A spring afternoon: hazed hills, a five-tier pagoda on the slope, a vermillion
torii by the water, sakura in full bloom, and a waterfall dropping off a ledge
into a pool that feeds the river across the foreground. Petals come down the
whole time. The light never changes — this one is meant to be quiet furniture,
not a clock, so unlike the Vice City theme there is exactly one band and one
GIF, which is why it can afford a long loop and a lot of frames.

Everything that moves has to return exactly to its starting state at the end of
the loop or the seam shows every five seconds:

*   the waterfall and the river scroll by a whole multiple of their own stripe
    period, so the pattern lands back on itself;
*   petals fall exactly one screen height per loop and sway on a whole number
    of sine cycles;
*   branches sway one cycle per loop;
*   pool rings expand from nothing and are fully faded before they wrap.

    python3 -c "import kyotogif; kyotogif.build('/tmp/kyoto-000.gif')"
"""

import math
import os
import sys

import gifwriter
from common import lerp_rgb

WIDTH = 480
HEIGHT = 270
FRAMES = 50
DELAY_CS = 11             # 110 ms -> 5.5 s loop
MAX_COLOURS = 255

M64 = (1 << 64) - 1

# --- palette ----------------------------------------------------------------
SKY_TOP = (150, 196, 230)
SKY_LOW = (222, 234, 236)
CLOUD = (250, 250, 248)

FAR_HILL = (150, 166, 186)
MID_HILL = (116, 142, 146)
NEAR_HILL = (84, 116, 100)
FOREST = (62, 96, 74)
FOREST_DARK = (46, 76, 60)

ROCK = (132, 126, 120)
ROCK_DARK = (94, 88, 86)
ROCK_LIGHT = (166, 160, 152)

WATER_FAR = (132, 176, 190)
WATER_NEAR = (78, 136, 160)
FOAM = (242, 250, 250)
SPRAY = (226, 240, 244)

SAKURA = (246, 190, 208)
SAKURA_LIGHT = (255, 224, 234)
SAKURA_DARK = (226, 156, 182)
PETAL = (255, 208, 222)
TRUNK = (88, 68, 60)
TRUNK_LIGHT = (116, 92, 78)

VERMILLION = (198, 66, 50)
VERMILLION_DARK = (154, 46, 38)
TILE = (78, 86, 96)
TILE_LIGHT = (108, 116, 128)
PLASTER = (232, 226, 212)
WOOD = (104, 68, 52)

GRASS = (104, 142, 82)
GRASS_DARK = (78, 112, 64)

HORIZON = 0.42            # where the hills meet the sky
WATER_TOP = 0.70          # the river band starts here
BANK_TOP = 0.855          # the near bank the camera stands on
FALL_X = 0.80             # the waterfall's centre, as a share of width
FALL_TOP = 0.475
FALL_BOTTOM = 0.705
CLIFF_LEFT = 0.635        # the rock face runs from here to the right edge


def noise(*key):
    h = 0x9E3779B97F4A7C15
    for k in key:
        h = (h + (int(k) & M64) + 0x9E3779B97F4A7C15) & M64
        h = ((h ^ (h >> 30)) * 0xBF58476D1CE4E5B9) & M64
        h = ((h ^ (h >> 27)) * 0x94D049BB133111EB) & M64
        h ^= h >> 31
    return (h & 0xFFFFFFFF) / 4294967296.0


def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else (hi if v > hi else v)


def mix(a, b, t):
    return lerp_rgb(a, b, clamp(t))


def shade(colour, f):
    if f <= 1.0:
        return (int(colour[0] * f), int(colour[1] * f), int(colour[2] * f))
    return mix(colour, (255, 255, 255), f - 1.0)


def put(px, x, y, colour, w, h):
    if 0 <= x < w and 0 <= y < h:
        px[y][x] = colour


def fill_rect(px, x0, y0, rw, rh, colour, w, h):
    for y in range(y0, y0 + rh):
        for x in range(x0, x0 + rw):
            put(px, x, y, colour, w, h)


# --- landscape --------------------------------------------------------------
def ridge(px, w, h, base_y, amp, colour, seed, roughness=0.014):
    """A hill ridge filled down to the waterline."""
    heights = []
    for x in range(w):
        n = (math.sin(x * roughness + seed) * 0.5
             + math.sin(x * roughness * 2.7 + seed * 2.1) * 0.3
             + math.sin(x * roughness * 5.3 + seed * 3.7) * 0.2)
        heights.append(int(base_y - (n + 1.0) * 0.5 * amp))
    fill_to = int(h * WATER_TOP)
    for x in range(w):
        top = heights[x]
        for y in range(max(0, top), fill_to):
            px[y][x] = colour
        # A lighter lip along the ridge line catches the sun.
        if 0 <= top < h:
            px[top][x] = shade(colour, 1.14)
    return heights


def draw_conifers(px, w, h, heights, colour, density, seed):
    """Little triangular trees standing on a ridge."""
    for x in range(0, w, 3):
        if noise(seed, x, 7) > density:
            continue
        top = heights[x] - 2 - int(noise(seed, x, 8) * 4)
        base = heights[x] + 1
        half = 1 + int(noise(seed, x, 9) * 1.6)
        for y in range(top, base):
            span = int(half * (y - top + 1) / max(1, base - top))
            for dx in range(-span, span + 1):
                put(px, x + dx, y, colour, w, h)


# --- buildings --------------------------------------------------------------
def draw_pagoda(px, cx, base_y, unit, w, h, tiers=5):
    """A five-tier pagoda: each roof wider than the body under it, eaves flicked up."""
    width_ = unit * 9
    y = base_y
    for t in range(tiers):
        body_w = max(3, int(width_ * 0.52))
        body_h = max(2, int(unit * 1.7))
        fill_rect(px, cx - body_w // 2, y - body_h, body_w, body_h, WOOD, w, h)
        # Plaster panel with a dark post at each end.
        fill_rect(px, cx - body_w // 2 + 1, y - body_h + 1,
                  max(1, body_w - 2), max(1, body_h - 2), PLASTER, w, h)

        roof_y = y - body_h
        roof_h = max(2, int(unit * 1.1))
        for r in range(roof_h):
            # Widest at the bottom course, and the last one flicks out further.
            span = int(width_ * (0.5 - 0.30 * r / roof_h))
            if r == 0:
                span += max(1, unit // 2)
            tone = TILE if r else TILE_LIGHT
            for x in range(cx - span, cx + span + 1):
                put(px, x, roof_y - r, tone, w, h)
            if r == 0:                       # upturned corner tips
                put(px, cx - span - 1, roof_y - 1, TILE_LIGHT, w, h)
                put(px, cx + span + 1, roof_y - 1, TILE_LIGHT, w, h)
        # The roof's topmost course is at roof_y - roof_h + 1, so the next
        # storey has to start there, not a row higher, or every tier is joined
        # to the one above it by a one-pixel gap.
        y = roof_y - roof_h + 1
        width_ *= 0.84

    # Finial.
    for k in range(int(unit * 2)):
        put(px, cx, y - k, TILE_LIGHT, w, h)


def draw_torii(px, cx, base_y, unit, w, h):
    """A vermillion torii: two posts, the curved kasagi, and the nuki beam."""
    post_h = unit * 7
    post_w = max(1, unit)
    span = unit * 5
    for side in (-1, 1):
        x0 = cx + side * span - post_w // 2
        fill_rect(px, x0, base_y - post_h, post_w, post_h, VERMILLION, w, h)
        fill_rect(px, x0, base_y - post_h, max(1, post_w // 2), post_h,
                  shade(VERMILLION, 1.12), w, h)

    nuki_y = base_y - int(post_h * 0.74)
    fill_rect(px, cx - span - unit, nuki_y, span * 2 + unit * 2,
              max(1, unit), VERMILLION_DARK, w, h)

    top_y = base_y - post_h
    for dx in range(-span - unit * 2, span + unit * 2 + 1):
        # A shallow upward curve toward the ends.
        lift = int((abs(dx) / (span + unit * 2.0)) ** 2 * unit * 1.6)
        for k in range(max(1, unit)):
            put(px, cx + dx, top_y - lift - k, VERMILLION, w, h)
        put(px, cx + dx, top_y - lift - max(1, unit), VERMILLION_DARK, w, h)


def draw_teahouse(px, cx, base_y, unit, w, h):
    """A low machiya-style building with a deep hipped roof."""
    body_w, body_h = unit * 9, unit * 3
    fill_rect(px, cx - body_w // 2, base_y - body_h, body_w, body_h, PLASTER, w, h)
    for k in range(0, body_w, max(2, unit * 2)):
        fill_rect(px, cx - body_w // 2 + k, base_y - body_h, 1, body_h, WOOD, w, h)
    roof_h = max(2, unit * 2)
    for r in range(roof_h):
        span = int(body_w * 0.62 - r * body_w * 0.16 / roof_h)
        tone = TILE if r else TILE_LIGHT
        for x in range(cx - span, cx + span + 1):
            put(px, x, base_y - body_h - r, tone, w, h)


# --- sakura -----------------------------------------------------------------
def blossom_cluster(px, cx, cy, r, w, h, seed):
    """A soft pink canopy blob, lighter on the upper left."""
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r * 2, cx + r * 2 + 1):
            dx, dy = (x - cx) * 0.5, y - cy
            d = math.hypot(dx, dy)
            if d > r:
                continue
            edge = noise(seed, x, y) * 0.9
            if d > r - 1 and edge < 0.45:
                continue
            up = clamp(0.5 - (dy / max(1, r)) * 0.6 - (dx / max(1, r)) * 0.25)
            tone = mix(SAKURA_DARK, SAKURA_LIGHT, up + 0.25 * edge)
            put(px, x, y, tone, w, h)


def draw_sakura(px, cx, base_y, scale, w, h, seed):
    """Trunk, a few boughs, and overlapping blossom clusters."""
    trunk_h = int(scale * 9)
    lean = (noise(seed, 2) - 0.5) * scale * 1.6
    for k in range(trunk_h):
        f = k / max(1, trunk_h)
        x = int(cx + lean * f * f)
        thick = max(1, int(scale * (1.5 - f)))
        for dx in range(thick):
            put(px, x + dx, base_y - k, TRUNK if dx else TRUNK_LIGHT, w, h)

    top_x, top_y = int(cx + lean), base_y - trunk_h
    boughs = 3 + int(noise(seed, 3) * 2)
    for b in range(boughs):
        ang = -math.pi * 0.80 + b * (math.pi * 0.60 / max(1, boughs - 1))
        ang += (noise(seed, b, 4) - 0.5) * 0.3
        length = int(scale * (3 + noise(seed, b, 5) * 3))
        for s in range(length):
            bx = int(top_x + math.cos(ang) * s * 1.5)
            by = int(top_y + math.sin(ang) * s)
            put(px, bx, by, TRUNK, w, h)
        blossom_cluster(px, int(top_x + math.cos(ang) * length * 1.5),
                        int(top_y + math.sin(ang) * length),
                        max(2, int(scale * (1.8 + noise(seed, b, 6) * 1.2))),
                        w, h, seed * 31 + b)
    blossom_cluster(px, top_x, top_y - int(scale * 1.2),
                    max(3, int(scale * 2.4)), w, h, seed * 17)


# --- water ------------------------------------------------------------------
def draw_cliff(px, w, h):
    """The rock face on the right, its mossy lip, and the notch the fall cuts."""
    fx = int(w * FALL_X)
    top = int(h * FALL_TOP)
    bottom = int(h * FALL_BOTTOM)
    left = int(w * CLIFF_LEFT)

    for y in range(top, bottom + 1):
        f = (y - top) / max(1, bottom - top)
        # A ragged left edge so the face does not end on a ruled line.
        edge_x = left + int(math.sin(y * 0.21) * w * 0.012
                            + noise(y // 3, 24) * w * 0.018)
        for x in range(edge_x, w):
            # Horizontal strata, the band pattern varying slowly down the face.
            band = int((y + noise(x // 9, 25) * 4) // max(2, h // 60))
            lit = 0.30 + 0.45 * ((x - edge_x) / max(1, w - edge_x))
            tone = mix(ROCK_DARK, ROCK, lit + 0.22 * noise(band, 26))
            n = noise(x // 2, y // 2, 21)
            if n > 0.88:
                tone = ROCK_LIGHT
            elif n < 0.09:
                tone = shade(tone, 0.82)
            tone = mix(tone, ROCK_DARK, 0.35 * f)     # the base sits in shadow
            px[y][x] = tone

    # Moss and a few tufts along the top edge.
    for x in range(left, w):
        y = top + int(math.sin(x * 0.17) * 1.5)
        if noise(x, 22) > 0.2:
            put(px, x, y, mix(FOREST, GRASS, noise(x, 23)), w, h)
            if noise(x, 27) > 0.75:
                put(px, x, y - 1, FOREST_DARK, w, h)
    return fx, top, bottom


def fall_channel(w):
    """Half-width of the falling water at a given depth."""
    return max(2, int(w * 0.022))


# --- the static half of the frame -------------------------------------------
def build_scene(width=WIDTH, height=HEIGHT):
    px = [[(0, 0, 0)] * width for _ in range(height)]
    horizon = int(height * HORIZON)

    # Down to the waterline, not just to the horizon: the ridges dip below it
    # in places, and anything no hill covers would be left unpainted — that is
    # the band of black pixels across the middle of the frame.
    for y in range(int(height * WATER_TOP)):
        f = min(1.0, y / max(1, horizon - 1)) ** 0.9
        col = mix(SKY_TOP, SKY_LOW, f)
        row = px[y]
        for x in range(width):
            row[x] = col

    for b in range(5):
        cy = int(horizon * (0.16 + 0.13 * b))
        cx = int(noise(b, 31) * width)
        length = int(width * (0.09 + noise(b, 32) * 0.13))
        thick = max(2, int(height * 0.012 * (0.6 + noise(b, 33))))
        for dx in range(length):
            x = cx + dx
            if not 0 <= x < width:
                continue
            edge = clamp(min(dx, length - 1 - dx) / (length * 0.3 + 1))
            for dy in range(thick):
                y = cy + dy
                if 0 <= y < horizon:
                    px[y][x] = mix(px[y][x], CLOUD,
                                   0.75 * edge * (1.0 - dy / thick))

    ridge(px, width, height, int(horizon * 1.06), height * 0.11, FAR_HILL, 1.7)
    ridge(px, width, height, int(horizon * 1.16), height * 0.10, MID_HILL, 4.3)
    near = ridge(px, width, height, int(horizon * 1.30), height * 0.09, NEAR_HILL, 8.1)
    draw_conifers(px, width, height, near, FOREST, 0.42, 5)
    front = ridge(px, width, height, int(horizon * 1.46), height * 0.07, FOREST, 11.9)
    draw_conifers(px, width, height, front, FOREST_DARK, 0.35, 9)

    unit = max(1, int(height / 90))
    draw_pagoda(px, int(width * 0.285), int(horizon * 1.10), int(unit * 2.4),
                width, height)
    draw_teahouse(px, int(width * 0.52), int(horizon * 1.42), unit, width, height)

    # --- the far bank -------------------------------------------------------
    # The ridge fill left the whole far shore one flat green. Up close to the
    # water it should read as grass, not as a painted wall.
    far_water = int(height * WATER_TOP)
    margin = max(4, int(height * 0.055))
    for y in range(far_water - margin, far_water):
        f = (y - (far_water - margin)) / max(1, margin)
        for x in range(width):
            if px[y][x] not in (FOREST, FOREST_DARK, NEAR_HILL):
                continue
            n = noise(x // 2, y // 2, 61)
            tone = mix(GRASS_DARK, GRASS, 0.25 + 0.55 * n + 0.30 * f)
            if n > 0.95:
                tone = mix(tone, SAKURA_LIGHT, 0.30)      # fallen blossom
            px[y][x] = tone
    # Tufts and reeds leaning over the water along the shoreline.
    for x in range(width):
        if px[far_water - 1][x] in (WATER_FAR, WATER_NEAR):
            continue
        if noise(x, 62) > 0.55:
            tall = 1 + int(noise(x, 63) * 3)
            lean = -1 if noise(x, 64) > 0.5 else 1
            for k in range(tall):
                put(px, x + int(lean * k * 0.4), far_water - 1 - k,
                    mix(GRASS_DARK, GRASS, 0.3 + 0.5 * noise(x, k, 65)), width, height)
        if noise(x, 66) > 0.93:                            # a taller reed
            for k in range(3 + int(noise(x, 67) * 3)):
                put(px, x, far_water - 1 - k, FOREST_DARK, width, height)

    fx, fall_top, fall_bottom = draw_cliff(px, width, height)

    # --- water: the pool under the fall, then the river band ---------------
    water_top = int(height * WATER_TOP)
    bank_top = int(height * BANK_TOP)
    water_base = {}
    for y in range(min(fall_bottom, water_top), bank_top):
        f = clamp((y - water_top) / max(1, bank_top - water_top))
        base = mix(WATER_FAR, WATER_NEAR, f)
        water_base[y] = base
        row = px[y]
        for x in range(width):
            row[x] = base

    # --- the near bank the camera stands on --------------------------------
    for y in range(bank_top, height):
        f = (y - bank_top) / max(1, height - bank_top)
        for x in range(width):
            n = noise(x // 2, y // 2, 41)
            tone = mix(GRASS_DARK, GRASS, 0.35 + 0.5 * n + 0.25 * f)
            if n > 0.93:
                tone = mix(tone, SAKURA_LIGHT, 0.35)      # fallen petals
            px[y][x] = tone
    # The waterline: a damp margin, then scattered stones sitting half in it.
    # A ruled edge between grass and river is the one thing that gives away
    # that this is two rectangles rather than a bank.
    for x in range(width):
        lip = int(math.sin(x * 0.09) * 1.4 + noise(x // 3, 47) * 2.2)
        for dy in range(3):
            y = bank_top + dy - lip
            if 0 <= y < height:
                px[y][x] = mix(GRASS_DARK, WATER_NEAR, 0.45 + 0.2 * dy)
        if noise(x // 4, 43) > 0.62:
            sw = 2 + int(noise(x, 44) * 3)
            sh = 1 + int(noise(x, 45) * 2)
            for dx in range(sw):
                for dy in range(sh):
                    put(px, x + dx, bank_top - lip - dy,
                        mix(ROCK, ROCK_LIGHT, noise(x, dy, 46)), width, height)

    # Everything from here on stands nearer the camera than the cliff, so the
    # animated waterfall must not paint over it. Snapshot, draw, diff: whatever
    # changed is in front of the fall.
    behind = [row[:] for row in px]

    draw_torii(px, int(width * 0.13), water_top + int(height * 0.012),
               max(1, int(unit * 1.5)), width, height)

    # Mid-ground sakura along the far bank, then two big ones on the near bank
    # whose crowns run off the top of the frame — that is what gives the shot
    # depth instead of a row of identical trees on one line.
    for i, (sx, sy, sscale) in enumerate(MID_TREES):
        # Clamp the root onto land: a couple of these sat a pixel or two below
        # the waterline and looked like they were growing out of the river.
        base = min(int(height * sy), water_top - 2)
        draw_sakura(px, int(width * sx), base,
                    unit * sscale * 1.4, width, height, seed=i + 1)
    for i, (sx, sscale) in enumerate(BIG_TREES):
        draw_sakura(px, int(width * sx), int(height * 0.99),
                    unit * sscale, width, height, seed=40 + i)

    front = set()
    for y in range(height):
        row, was = px[y], behind[y]
        for x in range(width):
            if row[x] != was[x]:
                front.add((x, y))

    # Anything standing in or over the river — trunks, the torii, the stones —
    # has overwritten the flat fill, so whatever still matches it is open water.
    # Without this the animated pass repaints the river over the foreground.
    water_mask = {}
    for y, base in water_base.items():
        row = px[y]
        water_mask[y] = [x for x in range(width) if row[x] == base]

    return {"rows": px, "width": width, "height": height, "horizon": horizon,
            "fall_x": fx, "fall_top": fall_top, "fall_bottom": fall_bottom,
            "water_top": water_top, "bank_top": bank_top,
            "water_mask": water_mask, "water_base": water_base,
            "front": front}


# --- the animated half ------------------------------------------------------
# Where the sakura stand, as fractions of the frame. Shared with the petal
# spawner: blossom has to come off a tree, not out of the sky above it.
MID_TREES = ((0.05, 0.706, 1.15), (0.21, 0.681, 0.75), (0.33, 0.714, 1.30),
             (0.45, 0.674, 0.62), (0.57, 0.700, 0.95), (0.66, 0.686, 0.70))
BIG_TREES = ((0.03, 2.6), (0.93, 2.9))
CANOPY_X = tuple(t[0] for t in MID_TREES) + tuple(t[0] for t in BIG_TREES)
CANOPY_Y = 0.60           # roughly where the crowns sit
PETAL_DRIFT = 0.055       # share of the width a petal blows left as it falls

PETALS = 70
SPLASH = 46               # droplets thrown up where the fall lands
FALL_PERIOD = 26          # px of the waterfall stripe pattern
RIVER_PERIOD = 34         # px of the river stripe pattern


def animate(scene, phase, frame):
    w, h = scene["width"], scene["height"]
    fx, ftop, fbot = scene["fall_x"], scene["fall_top"], scene["fall_bottom"]
    water_top = scene["water_top"]
    bank_top = scene["bank_top"]
    px = [list(row) for row in scene["rows"]]

    # --- waterfall ---------------------------------------------------------
    half = fall_channel(w)
    front = scene["front"]
    for y in range(ftop, fbot + 1):
        f = (y - ftop) / max(1, fbot - ftop)
        spread = int(half * (1.0 + 0.55 * f))
        for dx in range(-spread, spread + 1):
            x = fx + dx
            if not 0 <= x < w or (x, y) in front:
                continue
            edge = 1.0 - abs(dx) / (spread + 0.5)
            # Scrolls exactly one whole pattern per loop, so it lands back on
            # itself; anything else and the fall jumps every five seconds.
            v = (y - phase * FALL_PERIOD) % FALL_PERIOD / FALL_PERIOD
            streak = noise(x, int(v * FALL_PERIOD), 51)
            tone = mix(WATER_FAR, FOAM, 0.35 + 0.5 * edge)
            if streak > 0.62:
                tone = FOAM
            elif streak < 0.22:
                tone = mix(WATER_NEAR, FOAM, 0.25)
            px[y][x] = tone

    # Spray where it lands, breathing in and out over the loop.
    puff = 0.55 + 0.45 * math.sin(2 * math.pi * phase)
    for i in range(70):
        a = noise(i, 61) * math.pi - math.pi / 2
        r = (0.3 + 0.7 * noise(i, 62)) * w * 0.045 * (0.7 + 0.5 * puff)
        sx = int(fx + math.cos(a) * r * 1.8)
        sy = int(fbot + abs(math.sin(a)) * r * 0.5) - int(noise(i, 63) * 3)
        if 0 <= sx < w and 0 <= sy < h and (sx, sy) not in front:
            px[sy][sx] = mix(px[sy][sx], SPRAY, 0.55 * puff * noise(i, 64))

    # --- splash at the foot of the fall -------------------------------------
    # Each droplet's life is one loop offset by its own phase, so the whole
    # spray repeats exactly and nothing pops at the seam.
    impact = fbot
    for i in range(SPLASH):
        u = (phase + noise(i, 81)) % 1.0
        side = -1.0 if i % 2 else 1.0
        reach = (0.35 + 0.65 * noise(i, 82)) * w * 0.055
        rise = (0.45 + 0.55 * noise(i, 83)) * h * 0.055
        # Ballistic: out at a steady rate, up then down under gravity.
        dx = side * u * reach
        dy = -rise * (4.0 * u * (1.0 - u))
        x, y = int(fx + dx), int(impact + dy)
        if not (0 <= x < w and 0 <= y < h) or (x, y) in front:
            continue
        fade = (1.0 - u) ** 0.6
        px[y][x] = mix(px[y][x], FOAM if noise(i, 84) > 0.4 else SPRAY, 0.35 + 0.6 * fade)
        if noise(i, 85) > 0.7 and 0 <= y + 1 < h and (x, y + 1) not in front:
            px[y + 1][x] = mix(px[y + 1][x], SPRAY, 0.3 * fade)

    # A churned, brighter patch where the column actually lands.
    froth = int(w * 0.030)
    for dx in range(-froth, froth + 1):
        x = fx + dx
        if not 0 <= x < w:
            continue
        edge = 1.0 - abs(dx) / (froth + 0.5)
        for dy in range(0, max(2, int(h * 0.020 * (0.35 + 0.65 * edge)))):
            y = impact + dy
            if not 0 <= y < h or (x, y) in front:
                continue
            churn = noise(x, y, int(phase * FRAMES), 86)
            if churn > 0.72 - 0.25 * edge:
                px[y][x] = mix(px[y][x], FOAM, 0.30 + 0.45 * edge)

    # --- expanding rings on the pool ---------------------------------------
    mask_rows = {y: set(xs) for y, xs in scene["water_mask"].items()}
    for i in range(4):
        off = noise(i, 71)
        t = (phase + off) % 1.0
        rr = t * w * 0.07
        fade = (1.0 - t) ** 2
        cx = int(fx + (noise(i, 72) - 0.5) * w * 0.10)
        cy = int(fbot + 4 + noise(i, 73) * (h - fbot - 6))
        for a in range(0, 360, 6):
            rad = math.radians(a)
            x = int(cx + math.cos(rad) * rr * 1.9)
            y = int(cy + math.sin(rad) * rr * 0.55)
            if y in mask_rows and x in mask_rows[y]:
                px[y][x] = mix(px[y][x], FOAM, 0.35 * fade)

    # --- the near river ----------------------------------------------------
    mask = scene["water_mask"]
    for y in range(water_top, bank_top):
        f = (y - water_top) / max(1, bank_top - water_top)
        row = px[y]
        drift = phase * RIVER_PERIOD
        for x in mask.get(y, ()):
            u = (x + drift) % RIVER_PERIOD
            n = noise(int(u), y, 81)
            if n > 0.982 - 0.010 * f:
                row[x] = mix(row[x], FOAM, 0.45 + 0.25 * f)
            elif n < 0.055:
                row[x] = shade(row[x], 0.94)

    # --- falling petals ----------------------------------------------------
    for i in range(PETALS):
        # Each petal belongs to a tree, starts at that tree's crown, and blows
        # steadily left on the way down. Both the wrap in `drop` and the reset
        # of the leftward drift happen on the same frame, so the petal simply
        # reads as a new one falling rather than as a jump.
        tree = CANOPY_X[int(noise(i, 98) * len(CANOPY_X)) % len(CANOPY_X)]
        top = h * (CANOPY_Y + (noise(i, 99) - 0.5) * 0.09)
        span = h - top
        drop = (noise(i, 91) + phase) % 1.0
        y = int(top + drop * span)
        sway = math.sin(2 * math.pi * (phase * (1 + i % 2) + noise(i, 92)))
        x = int(tree * w + (noise(i, 93) - 0.5) * w * 0.055
                - drop * w * PETAL_DRIFT + sway * w * 0.012)
        if not (0 <= x < w and 0 <= y < h):
            continue
        # Petals in front of the water pick up a touch more light.
        tone = PETAL if y < water_top else SAKURA_LIGHT
        px[y][x] = tone
        if noise(i, 94) > 0.6:
            put(px, x + 1, y, mix(tone, SAKURA, 0.5), w, h)

    return px


# --- palette and writing ----------------------------------------------------
def _key(c):
    return ((c[0] >> 3) << 10) | ((c[1] >> 3) << 5) | (c[2] >> 3)


def _unkey(k):
    return (((k >> 10) & 31) << 3, ((k >> 5) & 31) << 3, (k & 31) << 3)


def median_cut(hist, want):
    boxes = [list(hist.keys())]
    while len(boxes) < want:
        best, best_score = None, -1
        for i, box in enumerate(boxes):
            if len(box) < 2:
                continue
            cols = [_unkey(k) for k in box]
            weight = sum(hist[k] for k in box)
            spread = max(max(c[ch] for c in cols) - min(c[ch] for c in cols)
                         for ch in range(3))
            score = spread * (weight ** 0.5)
            if score > best_score:
                best, best_score = i, score
        if best is None:
            break
        box = boxes.pop(best)
        cols = [(_unkey(k), k) for k in box]
        axis = max(range(3), key=lambda ch: (max(c[0][ch] for c in cols)
                                             - min(c[0][ch] for c in cols)))
        cols.sort(key=lambda c: c[0][axis])
        half = len(cols) // 2
        boxes.append([k for _, k in cols[:half]])
        boxes.append([k for _, k in cols[half:]])

    out = []
    for box in boxes:
        total = sum(hist[k] for k in box) or 1
        out.append(tuple(int(sum(_unkey(k)[ch] * hist[k] for k in box) / total)
                         for ch in range(3)))
    return out


def build(path, width=WIDTH, height=HEIGHT, frames=FRAMES):
    scene = build_scene(width, height)
    rasters = [animate(scene, i / frames, i) for i in range(frames)]

    hist = {}
    for raster in rasters:
        for row in raster:
            for colour in row:
                k = _key(colour)
                hist[k] = hist.get(k, 0) + 1

    palette = median_cut(hist, MAX_COLOURS)
    full = [(0, 0, 0)] + palette
    nearest = {}

    def index_of(colour):
        k = _key(colour)
        hit = nearest.get(k)
        if hit is None:
            c = _unkey(k)
            hit = 1 + min(range(len(palette)),
                          key=lambda i: ((palette[i][0] - c[0]) ** 2
                                         + (palette[i][1] - c[1]) ** 2
                                         + (palette[i][2] - c[2]) ** 2))
            nearest[k] = hit
        return hit

    buffers = []
    for raster in rasters:
        buf = bytearray(width * height)
        i = 0
        for row in raster:
            for colour in row:
                buf[i] = index_of(colour)
                i += 1
        buffers.append(bytes(buf))

    gifwriter.write_gif(path, width, height, full, buffers,
                        delay_cs=DELAY_CS, transparent_index=None, disposal=1)
    return os.path.getsize(path)


def build_all(out_dir, log=None):
    """One band only: the light never changes, so there is nothing to sweep."""
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "kyoto-000.gif")
    size = build(path)
    if log:
        log(0, path, size)
    return [(0, path, size)]


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "/tmp/kyoto"
    build_all(target, log=lambda b, p, s: print("%s (%d KB)"
                                                % (os.path.basename(p), s // 1024)))
