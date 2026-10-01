#!/usr/bin/env python3
"""Generates the animated cherry-blossom wallpaper for the `sakura` terminal theme.

Nothing on this machine can encode an image -- no Pillow, no ImageMagick, no
ffmpeg, no pip -- so this module carries its own GIF89a encoder (LZW), a GIF
decoder (used to prove the encoder round-trips), and a PNG writer (used to eyeball
frames during development). Everything below is stdlib.

The output dialect deliberately matches the wallpaper Windows Terminal already
renders for the hello-kitty theme: GIF89a, 256-entry global palette, disposal
method 1, no transparency, NETSCAPE2.0 loop=0.

Scene, back to front:
    sky gradient -> far ridge -> clouds -> near ridge -> hills -> bank and water
    -> cherry tree (anchored right) -> petals streaming left.

Everything loops seamlessly over FRAMES frames:

  * Clouds. Each layer is a horizontally tileable strip scrolled by
    `(f * TILE) // FRAMES`, so at f == FRAMES the offset is exactly one whole
    tile and the layer is back where it started.

  * Petals. A petal's progress is `u = (f * k / FRAMES) mod 1` for integer k, so
    it completes exactly k cycles per loop. Its y is `spawn_y + fall*u +
    amp*sin(2*pi*m*u + phase)` with integer m, which is periodic in u. The wrap
    from u=1 back to u=0 teleports the petal from off-screen-left to its spawn
    point -- and every spawn point is sampled from *inside the blossom canopy*,
    so the reappearance happens against pink and is invisible.

Value range is deliberately compressed: the darkest ink in the scene is the
trunk, kept a mid warm brown rather than the near-black of the reference art, so
dark terminal text stays readable wherever it crosses the image.

Usage:
    python3 sakura_gen.py --gif OUT.gif      # write the wallpaper
    python3 sakura_gen.py --png 0,60,120 P   # dump frames as P0.png ... for review
    python3 sakura_gen.py --selftest         # encoder/decoder round-trip
    python3 sakura_gen.py --decode IN.gif N P  # decode frame N of any gif to P.png
"""

import math
import random
import struct
import sys
import zlib

# ---- geometry ----------------------------------------------------------------

W, H = 320, 180          # logical pixel-art grid
SCALE = 3                # -> 960x540, the size already proven in this terminal
FRAMES = 300
DELAY = 10               # hundredths of a second -> 10fps, 30s loop
HORIZON = 116

# ---- palette -----------------------------------------------------------------
# Hand-authored so the art is drawn straight in palette indices: no quantiser,
# no dithering, guaranteed under 256 entries and perfectly flat colour fields
# (which is also what makes the LZW output small).

_P = []
_NAME = {}


def _c(name, rgb):
    _NAME[name] = len(_P)
    _P.append(rgb)
    return _NAME[name]


SKY = [_c("sky%d" % i, v) for i, v in enumerate([
    (116, 188, 230), (128, 196, 235), (140, 203, 238), (152, 210, 241),
    (164, 217, 244), (176, 223, 246), (188, 229, 248), (199, 234, 250),
    (209, 239, 251), (218, 243, 252),
])]

CLOUD_HI = _c("cloud_hi", (255, 255, 255))
CLOUD_MD = _c("cloud_md", (243, 250, 254))
CLOUD_LO = _c("cloud_lo", (226, 241, 250))
CLOUD_SH = _c("cloud_sh", (208, 230, 245))

MTN_F = _c("mtn_f", (170, 201, 223))
MTN_F_HI = _c("mtn_f_hi", (190, 215, 232))
MTN_F_SN = _c("mtn_f_sn", (226, 238, 247))

MTN_N = _c("mtn_n", (152, 192, 188))
MTN_N_HI = _c("mtn_n_hi", (172, 206, 196))
MTN_N_LO = _c("mtn_n_lo", (140, 180, 178))

HILL = _c("hill", (158, 200, 158))
HILL_HI = _c("hill_hi", (174, 210, 166))

GRASS_HI = _c("grass_hi", (168, 212, 146))
GRASS = _c("grass", (150, 196, 138))
GRASS_LO = _c("grass_lo", (140, 186, 128))
GRASS_DK = _c("grass_dk", (124, 170, 116))

WATER_HI = _c("water_hi", (206, 234, 240))
WATER = _c("water", (176, 214, 230))
WATER_LO = _c("water_lo", (152, 196, 218))

ROCK = _c("rock", (176, 178, 176))
ROCK_HI = _c("rock_hi", (198, 200, 197))

# Sunlit bark, not silhouette. The trunk is the darkest thing in the frame and
# it sits in the right-hand third where the statusline and long lines run, so
# its value sets the contrast floor for every colour the terminal draws.
TRUNK_HI = _c("trunk_hi", (216, 196, 178))
TRUNK = _c("trunk", (202, 178, 158))
TRUNK_MD = _c("trunk_md", (186, 160, 140))
TRUNK_LO = _c("trunk_lo", (168, 142, 124))

BL_HI = _c("bl_hi", (255, 231, 242))
BL_LT = _c("bl_lt", (252, 208, 228))
BL_MD = _c("bl_md", (246, 180, 210))
BL_DK = _c("bl_dk", (231, 150, 188))
BL_SH = _c("bl_sh", (216, 146, 182))
BL_EYE = _c("bl_eye", (255, 248, 218))    # stamen at the centre of a flower

# Weighted toward the mid and deep pinks: BL_HI is near-white and vanishes
# against the sky and the clouds, which is exactly where most petals fly.
PETAL_COLS = (BL_LT, BL_MD, BL_MD, BL_DK, BL_DK, BL_SH)
NCOL = len(_P)

# ---- tiny raster helpers -----------------------------------------------------


def blank():
    return bytearray(W * H)


def setpx(buf, x, y, c):
    if 0 <= x < W and 0 <= y < H:
        buf[y * W + x] = c


def disc(buf, cx, cy, r, pick):
    """Filled circle. `pick(dx, dy)` chooses the colour, which is how the trunk
    gets its shading without a second pass."""
    r2 = r * r
    for y in range(int(cy - r) - 1, int(cy + r) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            dx, dy = x - cx, y - cy
            if dx * dx + dy * dy <= r2:
                setpx(buf, x, y, pick(dx, dy, r))


def value_noise(seed, cell):
    """Smooth [0,1) field over the whole grid: a coarse random lattice with
    smoothstep bilinear interpolation. Used to give the blossom mass texture."""
    rng = random.Random(seed)
    gw, gh = W // cell + 2, H // cell + 2
    g = [[rng.random() for _ in range(gw)] for _ in range(gh)]
    out = [0.0] * (W * H)
    for y in range(H):
        fy = y / cell
        iy = int(fy)
        ty = fy - iy
        ty = ty * ty * (3 - 2 * ty)
        r0, r1 = g[iy], g[iy + 1]
        base = y * W
        for x in range(W):
            fx = x / cell
            ix = int(fx)
            tx = fx - ix
            tx = tx * tx * (3 - 2 * tx)
            a = r0[ix] + (r0[ix + 1] - r0[ix]) * tx
            b = r1[ix] + (r1[ix + 1] - r1[ix]) * tx
            out[base + x] = a + (b - a) * ty
    return out


def ridge(points, jitter, rng, sharp=False):
    """Skyline through (x, y) knots.

    `sharp` interpolates linearly, so each knot stays a hard angular peak -- that
    is what makes a ridge read as rock. Smoothstep rounds the knots into domes,
    which is right for the grassy bank and wrong for a mountain.

    The jitter is correspondingly different: a ridge wants fine high-frequency
    chipping that keeps its facets crisp, a hill wants a slow roll.
    """
    ys = [0] * W
    for i in range(len(points) - 1):
        x0, y0 = points[i]
        x1, y1 = points[i + 1]
        for x in range(max(0, x0), min(W, x1 + 1)):
            t = (x - x0) / float(x1 - x0) if x1 != x0 else 0.0
            if not sharp:
                t = t * t * (3 - 2 * t)      # smoothstep: rounded hills
            ys[x] = y0 + (y1 - y0) * t
    if jitter:
        acc = 0.0
        decay = 0.30 if sharp else 0.72
        for x in range(W):
            acc = acc * decay + rng.uniform(-jitter, jitter) * (1 - decay)
            ys[x] += acc
    return ys


# ---- static scene ------------------------------------------------------------


def build_scene():
    """Returns (static, cloud_ok, cloud_layers, spawn_points).

    `static` is the fully composited still image. `cloud_ok` marks pixels a cloud
    is allowed to overwrite -- sky that nothing in front of it occupies -- which
    lets each frame be a cheap copy of `static` plus a few thousand cloud pixels
    instead of a full recomposite.
    """
    rng = random.Random(0xC5EA)
    buf = blank()

    # sky: banded gradient, palest at the horizon
    for y in range(HORIZON + 8):
        t = y / float(HORIZON + 8)
        idx = SKY[min(len(SKY) - 1, int((1.0 - t) * len(SKY)))]
        for x in range(W):
            buf[y * W + x] = idx

    # far ridge -- hazy, cool, with a little snow on the high shoulders
    far = ridge([(-10, 102), (16, 78), (40, 98), (68, 58), (96, 90),
                 (124, 70), (150, 94), (182, 52), (212, 88), (244, 72),
                 (272, 96), (300, 76), (330, 98)], 0.8, rng, sharp=True)
    for x in range(W):
        top = int(far[x])
        for y in range(top, HORIZON + 6):
            c = MTN_F_HI if y < top + 3 else MTN_F
            buf[y * W + x] = c
        # snow caps: thickest at the peak, ragged along the lower edge
        if top < 80:
            depth = int((80 - top) * 0.55)
            for y in range(top, top + depth):
                buf[y * W + x] = MTN_F_SN
            if depth and rng.random() < 0.5:
                setpx(buf, x, top + depth, MTN_F_SN)

    cloud_ok = bytearray(1 if i < (HORIZON + 2) * W else 0 for i in range(W * H))

    # near ridge -- blue-green, reads as the closer massif
    near = ridge([(-10, 116), (22, 100), (48, 115), (78, 88), (106, 110),
                  (140, 99), (172, 116), (206, 91), (240, 108), (272, 103),
                  (302, 115), (330, 98)], 0.6, rng, sharp=True)
    for x in range(W):
        top = int(near[x])
        for y in range(top, HORIZON + 10):
            if y < top + 2:
                c = MTN_N_HI
            elif y > top + 9 and rng.random() < 0.25:
                c = MTN_N_LO
            else:
                c = MTN_N
            setpx(buf, x, y, c)
            cloud_ok[y * W + x] = 0

    # rolling hills at the waterline
    hl = ridge([(-10, 120), (54, 115), (118, 121), (186, 114), (252, 119),
                (330, 116)], 0.7, rng)
    for x in range(W):
        top = int(hl[x])
        for y in range(top, HORIZON + 16):
            setpx(buf, x, y, HILL_HI if y < top + 2 else HILL)
            if 0 <= y < H:
                cloud_ok[y * W + x] = 0

    # bank: grass sweeping down, rising on the right under the tree
    bank = ridge([(-10, 132), (60, 136), (130, 133), (200, 128), (262, 124),
                  (330, 127)], 0.8, rng)
    for x in range(W):
        top = int(bank[x])
        for y in range(top, H):
            d = y - top
            if d < 2:
                c = GRASS_HI
            elif d < 14:
                c = GRASS
            elif d < 30:
                c = GRASS_LO
            else:
                c = GRASS_DK
            if rng.random() < 0.06:
                c = GRASS_HI if c is GRASS else c
            setpx(buf, x, y, c)
            cloud_ok[y * W + x] = 0

    # still water in the lower left -- pale, so statusline text reads over it
    wtop = ridge([(-10, 150), (40, 152), (86, 155), (124, 160), (160, 168),
                  (200, 182), (330, 196)], 0.0, rng)
    for x in range(W):
        top = int(wtop[x])
        for y in range(top, H):
            d = y - top
            if d < 2:
                c = WATER_HI
            elif (y % 7) < 2 and rng.random() < 0.5:
                c = WATER_HI
            elif d < 18:
                c = WATER
            else:
                c = WATER_LO
            setpx(buf, x, y, c)

    # a few rocks at the water's edge
    for _ in range(9):
        rx = rng.randint(4, 150)
        ry = int(wtop[min(W - 1, max(0, rx))]) + rng.randint(-3, 3)
        rr = rng.uniform(2.0, 4.5)
        disc(buf, rx, ry, rr, lambda dx, dy, r: ROCK_HI if dy < -r * 0.15 else ROCK)

    canopy = []
    draw_tree(buf, rng, canopy)

    for i, v in enumerate(buf):
        if v in (TRUNK, TRUNK_HI, TRUNK_MD, TRUNK_LO, BL_HI, BL_LT, BL_MD,
                 BL_DK, BL_SH, BL_EYE):
            cloud_ok[i] = 0

    # A layer's speed is tile/FRAMES px per frame -- it has to cover a whole
    # number of tile widths per loop or the wrap shows. So the only ways to slow
    # clouds down are a narrower tile (more visible repetition) or a longer loop.
    # Hence FRAMES 250 -> 300 and the near layer 320 -> 240: together the far
    # layer drifts 1.5x slower than before and the near one 2.1x slower.
    layers = [build_cloud_layer(160, 6, 50, 0.55, 0xA11CE),
              build_cloud_layer(240, 24, 74, 1.0, 0xB0554)]
    return buf, cloud_ok, layers, canopy


def draw_tree(buf, rng, canopy):
    """Gnarled trunk anchored bottom-right, branches reaching left, blossom mass
    filling the top-right. Appends every blossom pixel to `canopy` -- those
    double as the hidden spawn points for the petals."""
    tips = []

    def bark(dx, dy, r):
        if dx < -r * 0.25:
            return TRUNK_HI
        if dx > r * 0.30:
            return TRUNK_LO
        return TRUNK if dy < r * 0.4 else TRUNK_MD

    def branch(x, y, ang, length, width, depth):
        steps = max(3, int(length))
        wob = rng.uniform(0, 6.283)
        curl = rng.uniform(-0.30, 0.30)
        for i in range(steps):
            t = i / float(steps)
            w = max(0.55, width * (1.0 - 0.58 * t))
            a = ang + math.sin(t * 2.7 + wob) * 0.16 + curl * t
            x += math.cos(a)
            y += math.sin(a)
            disc(buf, x, y, w, bark)
        if depth <= 0:
            tips.append((x, y, width))
            return
        n = 2 if depth > 2 else rng.choice((2, 2, 3))
        for k in range(n):
            spread = rng.uniform(0.34, 0.78) * (1 if k % 2 else -1)
            # bias every branch to the left: the wind has shaped this tree
            branch(x, y, ang + spread - 0.17, length * rng.uniform(0.62, 0.78),
                   width * rng.uniform(0.60, 0.72), depth - 1)

    # flared root base: wide at the ground, tapering as it rises
    for i in range(34):
        t = i / 34.0
        disc(buf, 254 - t * 5 + math.sin(t * 2.4) * 2.5, 180 - i * 1.0,
             17.0 - t * 7.0, bark)
    # surface roots gripping the bank
    for rx, ra, rl in ((236, 2.62, 20), (268, 0.58, 16), (230, 2.92, 24),
                       (272, 0.30, 13)):
        branch(rx, 177, ra, rl, 5.0, 0)
    tips.clear()

    branch(250, 148, -1.70, 44, 13.0, 5)

    # blossom mass: a blob per tip, plus filler so the canopy reads as one body
    pts = [(x, y, 8.0 + w * 3.0) for x, y, w in tips]
    for x, y, w in list(tips):
        for _ in range(3):
            pts.append((x + rng.uniform(-16, 15), y + rng.uniform(-14, 10),
                        rng.uniform(7.0, 14.0)))

    # Shade the canopy as ONE body, not as a pile of discs. Per-disc rim shading
    # outlines every circle and the result reads as bubbles; instead the discs
    # only union into a mask, and colour comes from how deep a pixel sits below
    # the canopy's own top surface, broken up by two octaves of value noise.
    mask = bytearray(W * H)
    for cx, cy, r in pts:
        r2 = r * r
        for y in range(max(0, int(cy - r) - 1), min(H, int(cy + r) + 2)):
            row = y * W
            dy = y - cy
            for x in range(max(0, int(cx - r) - 1), min(W, int(cx + r) + 2)):
                dx = x - cx
                if dx * dx + dy * dy <= r2:
                    mask[row + x] = 1

    n1 = value_noise(0x51A, 13)
    n2 = value_noise(0x2B7, 5)

    top = [-1] * W
    for x in range(W):
        for y in range(H):
            if mask[y * W + x]:
                top[x] = y
                break

    for x in range(W):
        if top[x] < 0:
            continue
        for y in range(top[x], H):
            i = y * W + x
            if not mask[i]:
                continue
            nz = n1[i] * 0.66 + n2[i] * 0.34
            depth = (y - top[x]) / 30.0
            v = 1.05 - min(depth, 1.0) * 0.85 + (nz - 0.5) * 0.85
            if nz < 0.17 and 0.12 < depth < 0.92:
                continue                      # gaps: branches and sky show through
            if v > 0.86:
                c = BL_HI
            elif v > 0.62:
                c = BL_LT
            elif v > 0.38:
                c = BL_MD
            elif v > 0.17:
                c = BL_DK
            else:
                c = BL_SH
            buf[i] = c

    # Individual flowers on the sunlit surface: a cream stamen ringed by four
    # pale petals. Five pixels is the smallest motif that still reads as a
    # flower rather than as noise once the art is upscaled.
    #
    # Placement walks a jittered grid rather than sampling freely, so the
    # blossoms spread evenly instead of clumping the way pure random would --
    # and only lands on pixels already lit, leaving the canopy's underside in
    # shadow where it belongs.
    # A flower is drawn one step lighter than whatever it lands on, rather than
    # a flat highlight. Painting every blossom BL_HI turned the canopy into pink
    # noise and threw away the top-lit form underneath; shading relative to the
    # local tone keeps that form and still reads as thousands of blossoms.
    lighter = {BL_SH: BL_DK, BL_DK: BL_MD, BL_MD: BL_LT, BL_LT: BL_HI,
               BL_HI: BL_HI}
    for gy in range(0, H, 5):
        for gx in range(0, W, 5):
            if rng.random() > 0.42:
                continue
            cx, cy = gx + rng.randrange(5), gy + rng.randrange(5)
            if not (0 < cx < W - 1 and 0 < cy < H - 1):
                continue
            i = cy * W + cx
            petal = lighter.get(buf[i]) if mask[i] else None
            if petal is None:
                continue
            for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
                j = (cy + dy) * W + cx + dx
                if mask[j]:                 # never spill past the silhouette
                    buf[j] = petal
            # only the sunlit blossoms show a stamen; in shadow it would glow
            buf[i] = BL_EYE if buf[i] in (BL_LT, BL_HI) else petal

    for i, v in enumerate(buf):
        if v in (BL_HI, BL_LT, BL_MD, BL_DK, BL_SH):
            canopy.append(i)


def build_cloud_layer(tile, y0, y1, density, seed):
    """A horizontally tileable band of cloud, returned sparse as (x, y, colour).

    Blobs that run off the right edge are redrawn at x-tile so the seam matches.
    """
    rng = random.Random(seed)
    strip = [[0] * tile for _ in range(y1 - y0)]

    def blob(cx, cy, r):
        for yy in range(int(cy - r) - 1, int(cy + r * 0.75) + 2):
            if not 0 <= yy - y0 < y1 - y0:
                continue
            row = strip[yy - y0]
            for xx in range(int(cx - r) - 1, int(cx + r) + 2):
                dx = (xx - cx) / r
                dy = (yy - cy) / (r * 0.52)
                d = dx * dx + dy * dy
                if d > 1.0:
                    continue
                c = CLOUD_HI if dy < -0.25 else (
                    CLOUD_MD if d < 0.45 else (
                        CLOUD_LO if d < 0.80 else CLOUD_SH))
                row[xx % tile] = c

    # few and large, with real gaps of open sky between them
    n = max(2, int(tile * density / 88.0))
    for _ in range(n):
        bx = rng.uniform(0, tile)
        by = rng.uniform(y0 + 9, y1 - 9)
        base = rng.uniform(15, 27)
        for k in range(rng.randint(3, 5)):
            blob(bx + k * base * rng.uniform(0.44, 0.72) - base,
                 by + rng.uniform(-2.0, 1.5),
                 base * rng.uniform(0.58, 1.0))

    out = []
    for yy in range(y1 - y0):
        row = strip[yy]
        for xx in range(tile):
            if row[xx]:
                out.append((xx, yy + y0, row[xx]))
    return tile, out


# ---- petals ------------------------------------------------------------------


def build_petals(canopy, rng):
    petals = []
    for _ in range(230):
        idx = canopy[rng.randrange(len(canopy))]
        sx, sy = idx % W, idx // W
        if sx < 130:
            continue
        petals.append({
            "x": sx,
            "y": sy,
            "u0": rng.random(),                    # spread along the path, so
            # cycles per loop -> speed. Bumped alongside the longer, slower loop
            # so the petals keep their pace while the clouds lose theirs.
            "k": rng.choice((2, 2, 3, 3, 4, 5)),
            "fall": rng.uniform(14, 74),
            "amp": rng.uniform(2.5, 9.0),
            "m": rng.randint(2, 6),                # integer -> periodic in u
            "ph": rng.uniform(0, 6.283),
            "col": rng.choice(PETAL_COLS),
            "big": rng.random() < 0.22,            # the "flowers"
        })
    return petals


def draw_petals(buf, petals, f):
    for p in petals:
        u = (p["u0"] + f * p["k"] / float(FRAMES)) % 1.0
        x = p["x"] - u * (p["x"] + 8.0)
        y = p["y"] + p["fall"] * u + p["amp"] * math.sin(
            6.283185307 * p["m"] * u + p["ph"])
        xi, yi = int(x), int(y)
        if not (-2 <= xi < W and 0 <= yi < H):
            continue
        c = p["col"]
        # a 3-phase tumble so petals read as spinning rather than sliding
        ph = int((u * p["m"] * 3.0) % 3)
        setpx(buf, xi, yi, c)
        if p["big"]:
            if ph == 0:
                setpx(buf, xi + 1, yi, c)
                setpx(buf, xi, yi + 1, BL_LT)
            elif ph == 1:
                setpx(buf, xi + 1, yi, BL_LT)
            else:
                setpx(buf, xi, yi + 1, c)
        elif ph == 0:
            setpx(buf, xi + 1, yi, BL_LT)


# ---- frame assembly ----------------------------------------------------------


class Scene:
    def __init__(self):
        self.static, self.cloud_ok, self.layers, canopy = build_scene()
        self.petals = build_petals(canopy, random.Random(0x5EED))

    def frame(self, f):
        buf = bytearray(self.static)
        ok = self.cloud_ok
        for tile, pts in self.layers:
            off = (f * tile) // FRAMES          # exactly one tile per loop
            for x, y, c in pts:
                sx = (x - off) % tile
                base = y * W
                while sx < W:
                    i = base + sx
                    if ok[i]:
                        buf[i] = c
                    sx += tile
        draw_petals(buf, self.petals, f)
        return buf


_REP = [bytes((i,)) * SCALE for i in range(256)]


def upscale(buf):
    """Nearest-neighbour x SCALE. Keeps the pixels square and hard-edged."""
    out = bytearray()
    for y in range(H):
        row = buf[y * W:(y + 1) * W]
        srow = b"".join([_REP[p] for p in row])
        for _ in range(SCALE):
            out += srow
    return bytes(out)


# ---- GIF encoder -------------------------------------------------------------


def lzw(data, mcs):
    """GIF-flavoured LZW.

    The code-width bump is the subtle part: a GIF decoder adds its dictionary
    entry one code *later* than the encoder does, so the encoder must widen at
    next_code == (1 << width) + 1, not at (1 << width). --selftest pins this.
    """
    clear, eoi = 1 << mcs, (1 << mcs) + 1
    width = mcs + 1
    nxt = eoi + 1
    table = {}
    out = bytearray()
    acc = nbits = 0

    def emit(code):
        nonlocal acc, nbits
        acc |= code << nbits
        nbits += width
        while nbits >= 8:
            out.append(acc & 0xFF)
            acc >>= 8
            nbits -= 8

    emit(clear)
    it = iter(data)
    prefix = next(it)
    for ch in it:
        key = (prefix << 8) | ch
        got = table.get(key)
        if got is not None:
            prefix = got
            continue
        emit(prefix)
        if nxt < 4096:
            table[key] = nxt
            nxt += 1
            if nxt == (1 << width) + 1 and width < 12:
                width += 1
        else:
            emit(clear)
            table.clear()
            width = mcs + 1
            nxt = eoi + 1
        prefix = ch
    emit(prefix)
    emit(eoi)
    if nbits:
        out.append(acc & 0xFF)
    return bytes(out)


def blocks(data):
    out = bytearray()
    for i in range(0, len(data), 255):
        chunk = data[i:i + 255]
        out.append(len(chunk))
        out += chunk
    out.append(0)
    return bytes(out)


def write_gif(path, items, palette, delay=DELAY, tidx=None):
    """`items` is a list of (pixels, is_diff). Diff frames mark unchanged pixels
    with `tidx`; combined with disposal method 1 (leave the canvas alone) the
    decoder shows the previous pixel there.

    This is what keeps the file small: the scene is detailed enough that full
    frames cost ~25 KB each, while only ~500 logical pixels actually move per
    frame. Frame 0 is always fully opaque, so looping back onto it repaints the
    whole canvas and nothing can accumulate.
    """
    gw, gh = W * SCALE, H * SCALE
    need = len(palette) + (1 if tidx is not None else 0)
    size = 2
    while size < need:
        size <<= 1
    bits = size.bit_length() - 1

    out = bytearray(b"GIF89a")
    out += struct.pack("<HH", gw, gh)
    out += bytes((0x80 | ((bits - 1) & 7), 0, 0))
    for i in range(size):
        out += bytes(palette[i] if i < len(palette) else (0, 0, 0))
    out += b"\x21\xFF\x0BNETSCAPE2.0\x03\x01\x00\x00\x00"

    mcs = max(2, bits)
    for px, is_diff in items:
        flags = 0x04 | (0x01 if is_diff else 0x00)   # disposal 1 (+transparent)
        out += (b"\x21\xF9\x04" + bytes((flags,)) + struct.pack("<H", delay)
                + bytes((tidx if is_diff else 0,)) + b"\x00")
        out += b"\x2C" + struct.pack("<HHHH", 0, 0, gw, gh) + b"\x00"
        out += bytes((mcs,)) + blocks(lzw(px, mcs))
    out += b"\x3B"
    with open(path, "wb") as fh:
        fh.write(out)
    return len(out)


# ---- GIF decoder (verification only) -----------------------------------------


def read_gif(path):
    d = open(path, "rb").read()
    gw, gh = struct.unpack("<HH", d[6:10])
    flags = d[10]
    i = 13
    pal = []
    if flags & 0x80:
        n = 2 << (flags & 7)
        pal = [tuple(d[i + 3 * k:i + 3 * k + 3]) for k in range(n)]
        i += 3 * n
    frames = []
    tnext = None
    while i < len(d) and d[i] != 0x3B:
        b = d[i]
        if b == 0x21:
            if d[i + 1] == 0xF9:
                blk = d[i + 3:i + 3 + d[i + 2]]
                tnext = blk[3] if (blk[0] & 1) else None
            i += 2
            while d[i]:
                i += 1 + d[i]
            i += 1
        elif b == 0x2C:
            fx, fy, fw, fh = struct.unpack("<HHHH", d[i + 1:i + 9])
            lf = d[i + 9]
            i += 10
            if lf & 0x80:
                i += 3 * (2 << (lf & 7))
            mcs = d[i]
            i += 1
            raw = bytearray()
            while d[i]:
                n = d[i]
                raw += d[i + 1:i + 1 + n]
                i += 1 + n
            i += 1
            frames.append((fx, fy, fw, fh, unlzw(bytes(raw), mcs, fw * fh),
                           tnext))
            tnext = None
        else:
            break
    return gw, gh, pal, frames


def unlzw(data, mcs, count):
    """Textbook GIF decoder -- written to spec, then validated by decoding the
    known-good hello-kitty wallpaper. That makes it a trustworthy oracle for
    --selftest."""
    clear, eoi = 1 << mcs, (1 << mcs) + 1
    width = mcs + 1
    table = {k: bytes((k,)) for k in range(clear)}
    nxt = eoi + 1
    out = bytearray()
    acc = nbits = pos = 0
    prev = None
    while len(out) < count:
        while nbits < width:
            if pos >= len(data):
                return bytes(out)
            acc |= data[pos] << nbits
            nbits += 8
            pos += 1
        code = acc & ((1 << width) - 1)
        acc >>= width
        nbits -= width
        if code == clear:
            table = {k: bytes((k,)) for k in range(clear)}
            width = mcs + 1
            nxt = eoi + 1
            prev = None
            continue
        if code == eoi:
            break
        if prev is None:
            entry = table[code]
        elif code in table:
            entry = table[code]
        else:
            entry = table[prev] + table[prev][:1]
        out += entry
        if prev is not None:
            table[nxt] = table[prev] + entry[:1]
            nxt += 1
            if nxt == (1 << width) and width < 12:
                width += 1
        prev = code
    return bytes(out)


# ---- PNG (so frames can be eyeballed during development) ---------------------


def write_png(path, indices, w, h, palette):
    rows = bytearray()
    for y in range(h):
        rows.append(0)
        base = y * w
        for x in range(w):
            rows += bytes(palette[indices[base + x]])
    comp = zlib.compress(bytes(rows), 6)

    def chunk(tag, payload):
        return (struct.pack(">I", len(payload)) + tag + payload
                + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF))

    with open(path, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n")
        fh.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)))
        fh.write(chunk(b"IDAT", comp))
        fh.write(chunk(b"IEND", b""))


# ---- cli ---------------------------------------------------------------------


def composite(path):
    """Replay a GIF the way a viewer does: disposal 1 leaves the canvas in
    place, transparent pixels reveal what was already there. Yields each
    fully-composited frame."""
    gw, gh, pal, frames = read_gif(path)
    canvas = bytearray(gw * gh)
    for fx, fy, fw, fh, px, t in frames:
        for row in range(fh):
            src = row * fw
            dst = (fy + row) * gw + fx
            if t is None:
                canvas[dst:dst + fw] = px[src:src + fw]
            else:
                for c in range(fw):
                    v = px[src + c]
                    if v != t:
                        canvas[dst + c] = v
        yield gw, gh, pal, bytes(canvas)


def build_frames(sc, tidx):
    """Logical frames, diffed against the previous one, then upscaled. Diffing
    before the upscale is the cheap way round: one comparison per logical pixel
    covers the whole SCALE x SCALE block it expands into."""
    prev = None
    for f in range(FRAMES):
        cur = sc.frame(f)
        if prev is None:
            yield upscale(cur), False
        else:
            yield upscale(bytearray(
                [c if c != p else tidx for c, p in zip(cur, prev)])), True
        prev = cur


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__)
        return

    if a[0] == "--decode":
        n = int(a[2])
        for i, (gw, gh, pal, px) in enumerate(composite(a[1])):
            if i == n:
                write_png(a[3], px, gw, gh, pal)
                print("composited %s frame %d -> %s (%dx%d, %d colours)"
                      % (a[1], n, a[3], gw, gh, len(pal)))
                return
        print("no such frame")
        return

    if a[0] == "--selftest":
        rng = random.Random(7)
        ok = True
        cases = [(bytes(rng.randrange(NCOL) for _ in range(5000)), 8),
                 (bytes([3]) * 40000, 8),
                 (bytes(range(256)) * 90, 8),          # forces width 8->12
                 (bytes(rng.randrange(64) for _ in range(9000)), 6),
                 (Scene().frame(0), 8)]
        for n, (src, mcs) in enumerate(cases):
            enc = lzw(src, mcs)
            good = unlzw(enc, mcs, len(src)) == src
            ok &= good
            print("  lzw case %d (mcs=%d): %6d px -> %6d B  %s"
                  % (n, mcs, len(src), len(enc), "ok" if good else "MISMATCH"))
        sc = Scene()
        loop = sc.frame(0) == sc.frame(FRAMES)
        ok &= loop
        print("  loop frame(0) == frame(%d): %s" % (FRAMES, "ok" if loop else "MISMATCH"))
        print("selftest:", "PASS" if ok else "FAIL")
        sys.exit(0 if ok else 1)

    if a[0] == "--verify":
        sc = Scene()
        bad = 0
        want = [upscale(sc.frame(f)) for f in range(FRAMES)]
        for i, (gw, gh, pal, got) in enumerate(composite(a[1])):
            if i >= FRAMES:
                bad += 1
                break
            if got != want[i]:
                bad += 1
                if bad < 4:
                    d = sum(1 for p, q in zip(got, want[i]) if p != q)
                    print("  frame %d differs in %d px" % (i, d))
        print("verify %s: %s (%d frames)"
              % (a[1], "PASS - composites exactly" if not bad else "FAIL", FRAMES))
        sys.exit(0 if not bad else 1)

    sc = Scene()

    if a[0] == "--png":
        for n in [int(v) for v in a[1].split(",")]:
            p = "%s%d.png" % (a[2], n)
            write_png(p, sc.frame(n), W, H, _P)
            print("wrote", p)
        return

    if a[0] == "--gif":
        items = []
        for f, item in enumerate(build_frames(sc, NCOL)):
            items.append(item)
            if f % 50 == 0:
                print("  frame %d/%d" % (f, FRAMES), flush=True)
        n = write_gif(a[1], items, _P, tidx=NCOL)
        print("wrote %s  %dx%d  %d frames  %.1f KB  %.1fs loop"
              % (a[1], W * SCALE, H * SCALE, FRAMES, n / 1024.0,
                 FRAMES * DELAY / 100.0))
        return

    print("unknown mode:", a[0])


if __name__ == "__main__":
    main()
