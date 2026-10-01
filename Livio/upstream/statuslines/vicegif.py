"""Render the Vice City panorama to looping GIFs for the terminal background.

Windows Terminal has no escape sequence for the background, so the only way to
put the bay behind your whole session is to point the profile at a GIF and let
WT hot-reload. One GIF every ten minutes of the day: the sky, sun, moon,
skyline, boats and traffic chopper are baked per band, and `sl-water-bg.py`
swaps which one is pointed at as the clock moves. At that spacing the sun
visibly creeps down the sky, the light turns over through sunrise and sunset,
and the moon comes up on the other side. The status line panel then draws only
the live foreground, leaving its sky transparent so this shows through.

Two things shape the implementation:

*   Everything that moves inside a loop has to return exactly to its starting
    state or the seam shows every second and a half. Translation cannot do that
    at this frame rate without looking like a conveyor belt, so within a loop
    only the water sparkles, the crests breathe, the stars twinkle and the
    rotor spins — all periodic. Anything that should travel (the sun, the
    boats, the chopper) moves *between* bands instead, over the real day.
*   Only about a third of a frame actually changes. The static parts are
    rendered once per band and the animated pass overlays the rest, which is
    what makes 144 bands affordable.

    python3 -c "import vicegif; vicegif.build_all('/tmp/vice')"
"""

import math
import os
import sys

import gifwriter
import vice

WIDTH = 480
HEIGHT = 270
FRAMES = 12
DELAY_CS = 11             # 110 ms per frame -> 1.32 s loop
HORIZON = 0.52            # share of the frame above the waterline
MAX_COLOURS = 255         # slot 0 is kept for transparency
BANDS = 144               # one band every ten minutes

BOATS = 3
HULL = (46, 42, 60)
CABIN = (206, 204, 214)
WAKE = (196, 218, 236)
CHOPPER_SHELL = (34, 36, 52)
CHOPPER_GLASS = (140, 186, 222)


def band_name(band):
    return "vice-%03d.gif" % band


def band_to_hour(band):
    """The middle of a band, in hours."""
    return (band + 0.5) * 24.0 / BANDS


# --- buildings --------------------------------------------------------------
def draw_tower(px, tx, tw, th, shape, horizon_py, width, night, day,
               sun_x, base_col, scale, lit_out):
    """One tower: lit and shaded faces, a window grid, and roof clutter."""
    top = horizon_py - th
    # Every building is a slightly different concrete.
    tint = vice.mix(base_col, (96, 86, 120), vice.noise(tx, 51) * 0.30)
    tint = vice.mix(tint, (62, 54, 74), vice.noise(tx, 52) * 0.25)

    # The face turned toward the sun catches the light; the other falls away.
    centre = tx + tw * 0.5
    sunward = 1.0 if sun_x >= centre else -1.0
    relief = 0.30 * day

    for x in range(max(0, tx), min(width, tx + tw)):
        u = (x - tx) / max(1, tw - 1)
        facing = u if sunward > 0 else 1.0 - u
        col = vice.shade(tint, (1.0 - relief * 0.5) + relief * facing)
        y0 = top
        if shape == "step" and tw >= 4 * scale:
            inset = min(x - tx, tx + tw - 1 - x) // scale
            y0 = top + (2 * scale if inset == 0 else (scale if inset == 1 else 0))
        for y in range(max(0, y0), horizon_py):
            px[y][x] = col

    # --- windows -----------------------------------------------------------
    # Visible by day as a darker grid on the facade, lit after dusk.
    step_x, step_y = 2 * scale, 2 * scale
    for wy in range(top + step_y, horizon_py - scale, step_y):
        for wx in range(tx + scale, min(width, tx + tw) - scale, step_x):
            if wx < 0:
                continue
            under = px[wy][wx]
            on = night > 0.12 and vice.noise(tx, wx, wy, 31) < 0.42 * night + 0.06
            if on:
                warm = (vice.WINDOW_WARM if vice.noise(tx, wx, wy, 33) < 0.78
                        else vice.WINDOW_COOL)
                tone = vice.mix(under, warm, 0.55 + 0.45 * night)
                lit_out.append((wx, warm))
            else:
                tone = vice.shade(under, 0.80 + 0.12 * vice.noise(tx, wx, wy, 34))
            for oy in range(max(1, scale - 1)):
                for ox in range(max(1, scale - 1)):
                    if wy + oy < horizon_py and wx + ox < width:
                        px[wy + oy][wx + ox] = tone

    # --- roof clutter ------------------------------------------------------
    roll = vice.noise(tx, 61)
    if shape == "spire":
        sx = tx + tw // 2
        for y in range(max(0, top - 4 * scale), top):
            for k in range(max(1, scale // 2)):
                if 0 <= sx + k < width:
                    px[y][sx + k] = tint
        if night > 0.15:
            for k in range(max(1, scale // 2)):
                if 0 <= sx + k < width and top - 4 * scale >= 0:
                    px[top - 4 * scale][sx + k] = vice.COP_RED
    elif roll < 0.34 and tw >= 4 * scale:
        # Water tank on legs.
        bx_ = tx + tw // 3
        h = 2 * scale
        for y in range(max(0, top - h), top):
            for x in range(bx_, min(width, bx_ + 2 * scale)):
                if x >= 0:
                    px[y][x] = vice.shade(tint, 1.12)
    elif roll < 0.58:
        # Antenna mast.
        sx = tx + tw // 2
        for y in range(max(0, top - 3 * scale), top):
            if 0 <= sx < width:
                px[y][sx] = vice.shade(tint, 0.8)

    # A parapet line so the roof reads as a surface, not a cut.
    for x in range(max(0, tx), min(width, tx + tw)):
        if 0 <= top < horizon_py:
            px[top][x] = vice.shade(px[top][x], 1.16)

    if th > 9 * scale and night > 0.2:
        hue = vice.NEON_SET[int(vice.noise(tx, 41) * len(vice.NEON_SET))
                            % len(vice.NEON_SET)]
        for x in range(max(0, tx), min(width, tx + tw)):
            for k in range(max(1, scale // 2)):
                if 0 <= top + k < horizon_py:
                    px[top + k][x] = vice.mix(px[top + k][x], hue, night * 0.85)


# --- vessels and aircraft ---------------------------------------------------
def draw_boat(px, cx, cy, size, night, width, height):
    """A boat with a cabin, a wake, and running lights after dark."""
    hull_w = max(3, size * 3)
    for dx in range(-hull_w, hull_w + 1):
        x = cx + dx
        if not 0 <= x < width:
            continue
        taper = abs(dx) / hull_w
        for dy in range(max(1, size - int(taper * size))):
            y = cy + dy
            if 0 <= y < height:
                px[y][x] = HULL
    for dx in range(-size, size + 1):
        x = cx + dx
        for dy in range(1, max(2, size)):
            y = cy - dy
            if 0 <= x < width and 0 <= y < height:
                px[y][x] = vice.shade(CABIN, 0.45 + 0.55 * (1.0 - night))
    if night > 0.3:
        for k, colour in ((-hull_w, (255, 90, 90)), (hull_w, (120, 255, 150))):
            x = cx + k
            if 0 <= x < width and 0 <= cy < height:
                px[cy][x] = colour
    # Wake: a short pale smear trailing behind.
    for dx in range(hull_w, hull_w * 3):
        x = cx - dx
        y = cy + max(1, size // 2)
        if 0 <= x < width and 0 <= y < height:
            fade = 1.0 - (dx - hull_w) / (hull_w * 2)
            px[y][x] = vice.mix(px[y][x], WAKE, 0.30 * fade * (1.0 - 0.6 * night))


CHOPPER_ART = [
    "..rrrrrrrrrrrrr..",
    ".......mm........",
    "tttt..bbbbbbb....",
    "..v..bbbbbbbgg...",
    "..v...bbbbbbb....",
    ".......ss.ss.....",
]


def draw_chopper(px, x0, y0, scale, night, width, height, rotor_cells):
    """Traffic chopper over the bay. Rotor pixels are collected for animating."""
    palette = {"b": CHOPPER_SHELL, "g": CHOPPER_GLASS, "t": CHOPPER_SHELL,
               "m": (70, 72, 92), "s": (70, 72, 92), "v": (150, 154, 176),
               "r": (150, 154, 176)}
    span = max(len(line) for line in CHOPPER_ART)
    for dy, line in enumerate(CHOPPER_ART):
        for dx, key in enumerate(line):
            colour = palette.get(key)
            if colour is None:
                continue
            for oy in range(scale):
                for ox in range(scale):
                    x, y = x0 + dx * scale + ox, y0 + dy * scale + oy
                    if 0 <= x < width and 0 <= y < height:
                        px[y][x] = colour
                        if key in "rv":
                            rotor_cells.append((x, y))
    if night > 0.2:
        bx = x0 + (span // 2) * scale
        by = y0 + 5 * scale
        if 0 <= bx < width and 0 <= by < height:
            px[by][bx] = vice.COP_RED


# --- the static half of a frame ---------------------------------------------
def build_scene(width, height, hour):
    """Everything that does not change inside the loop, plus animation hooks."""
    day = vice.daylight(hour)
    night = 1.0 - day
    top_c, horiz_c = vice.sky_stops(hour)
    horizon_py = int(height * HORIZON)
    px = [[(0, 0, 0)] * width for _ in range(height)]

    for y in range(horizon_py):
        f = vice.smooth(y / max(1, horizon_py - 1)) ** 0.85
        col = vice.mix(top_c, horiz_c, f)
        row = px[y]
        for x in range(width):
            row[x] = col

    stars = []
    if night > 0.04:
        for i in range(int(width * height * 0.0016)):
            sx = int(vice.noise(i, 11) * width)
            sy = int(vice.noise(i, 12) ** 1.6 * horizon_py * 0.92)
            if not (0 <= sy < horizon_py and 0 <= sx < width):
                continue
            stars.append((sx, sy, vice.STAR_COLOURS[i % len(vice.STAR_COLOURS)],
                          px[sy][sx], 1 + (i % 3), vice.noise(i, 14),
                          night * (0.35 + 0.65 * vice.noise(i, 15))))

    for b in range(4):
        cy = int(horizon_py * (0.12 + 0.17 * b)) + 1
        drift = (vice.noise(b, 77) * (width + 120)) - 60
        length = int(width * (0.10 + vice.noise(b, 21) * 0.16))
        for dx in range(length):
            x = int(drift + dx)
            if not 0 <= x < width:
                continue
            edge = vice.smooth(min(dx, length - 1 - dx) / (length * 0.22 + 1))
            puff = 0.5 + 0.5 * math.sin(dx * 0.05 + b)
            thick = max(2, int(puff * height * 0.022))
            for dy in range(thick):
                y = cy + dy
                if not 0 <= y < horizon_py:
                    continue
                lit = vice.mix((236, 236, 244), horiz_c, dy / thick)
                px[y][x] = vice.mix(px[y][x], lit, 0.5 * edge * (0.55 + 0.45 * day))

    body = vice.celestial(hour, width, horizon_py)
    sun_x = body[1] if body else width * 0.5
    if body:
        kind, bx, by, alt = body
        radius = (0.030 if kind == "sun" else 0.023) * height
        if kind == "sun":
            low = vice.clamp(1.0 - alt * 2.2)
            core = vice.mix(vice.SUN_CORE, vice.SUN_GLOW, low)
            rim = vice.mix(vice.SUN_RIM, vice.SUN_LOW, low)
        else:
            core, rim = vice.MOON_CORE, vice.MOON_DARK
        glow = 0.9 if kind == "sun" else 0.5
        for y in range(max(0, int(by - radius * 4)), min(height, int(by + radius * 4))):
            for x in range(max(0, int(bx - radius * 4)), min(width, int(bx + radius * 4))):
                dist = math.hypot(x - bx, y - by)
                if y >= horizon_py and kind == "sun" and alt < 0.06:
                    continue
                if dist <= radius:
                    tone = vice.mix(core, rim, vice.clamp(dist / radius) ** 0.7)
                    if kind == "moon":
                        ph = vice.clamp(((x - bx) / radius + 1.0) * 0.5)
                        tone = vice.mix(vice.MOON_DARK, tone, vice.smooth(ph * 1.3))
                    px[y][x] = tone
                elif dist <= radius * 3.4:
                    halo = (1.0 - (dist - radius) / (radius * 2.4)) ** 2
                    px[y][x] = vice.mix(px[y][x], rim, vice.clamp(halo) * 0.55 * glow)

    scale = max(1, int(width / 110))
    tower_body = vice.mix(vice.TOWER_DAY, vice.TOWER_NIGHT, night)
    haze = vice.mix(tower_body, horiz_c, 0.45)
    lit = []
    for bx_, bw, bh, _ in vice.skyline(width, horizon_py, seed=19, res=scale):
        btop = horizon_py - max(1, int(bh * 0.7))
        for x in range(max(0, bx_ + 2 * scale), min(width, bx_ + bw + 2 * scale)):
            for y in range(max(0, btop), horizon_py):
                px[y][x] = haze
    for tx, tw, th, shape in vice.skyline(width, horizon_py, res=scale):
        draw_tower(px, tx, tw, th, shape, horizon_py, width, night, day,
                   sun_x, tower_body, scale, lit)

    # --- sea base ----------------------------------------------------------
    sea_rows = max(1, height - horizon_py)
    sea_base = {}
    for y in range(horizon_py, height):
        f = vice.smooth((y - horizon_py) / sea_rows)
        base = vice.mix(vice.SEA_FAR, vice.SEA_NEAR, f)
        base = vice.shade(base, 0.44 + 0.56 * day)
        base = vice.mix(base, horiz_c, 0.22 + (1.0 - f) * 0.48)
        sea_base[y] = base
        row = px[y]
        for x in range(width):
            row[x] = base

    for x in range(width):
        px[horizon_py][x] = vice.shade(px[horizon_py][x], 1.18 + 0.12 * (1.0 - day))

    if night > 0.15 and lit:
        for lx, lcol in lit:
            depth = (2 + int(vice.noise(lx, 201) * 4)) * scale * 2
            for k in range(depth):
                y = horizon_py + k
                if y >= height:
                    break
                wob = int(round(math.sin(lx * 0.45 + k * 0.9) * (0.4 + k * 0.35)))
                x = lx + wob
                if 0 <= x < width:
                    fade = (1.0 - k / depth) ** 1.4 * 0.62 * night
                    px[y][x] = vice.mix(px[y][x], lcol, fade)

    # --- boats: they travel between bands, not inside the loop -------------
    for i in range(BOATS):
        speed = 0.55 + 0.5 * vice.noise(i, 302)
        u = (vice.noise(i, 301) + hour / 24.0 * speed) % 1.0
        depth = 0.14 + 0.34 * vice.noise(i, 303)
        cy = horizon_py + int(depth * sea_rows)
        size = max(1, int(scale * (0.7 + depth * 1.6)))
        draw_boat(px, int(u * (width + 60)) - 30, cy, size, night, width, height)

    # --- traffic chopper ---------------------------------------------------
    rotor_cells = []
    cu = (vice.noise(0, 401) + hour / 24.0 * 0.85) % 1.0
    cx = int(cu * (width + 80)) - 40
    cy = int(horizon_py * (0.22 + 0.16 * math.sin(hour * 0.7)))
    draw_chopper(px, cx, cy, max(1, scale - 1), night, width, height, rotor_cells)

    return {"rows": px, "horizon": horizon_py, "sea_base": sea_base,
            "stars": stars, "body": body, "sun_x": sun_x, "day": day,
            "height": height, "width": width, "rotor": rotor_cells}


def animate(scene, phase, frame_index):
    """Overlay the parts that move inside the loop onto a copy of the base."""
    width, height = scene["width"], scene["height"]
    horizon_py, sea_base = scene["horizon"], scene["sea_base"]
    body, sun_x = scene["body"], scene["sun_x"]
    px = [list(row) for row in scene["rows"]]
    sea_rows = max(1, height - horizon_py)

    for y in range(horizon_py, height):
        f = vice.smooth((y - horizon_py) / sea_rows)
        base = sea_base[y]
        row = px[y]

        step = max(4, int(width * (0.055 - 0.025 * f)))
        crest_len = max(2, int(width * (0.004 + 0.012 * f)))
        for slot in range(-1, width // step + 2):
            if vice.noise(y, slot, 111) > 0.52:
                continue
            jitter = vice.noise(y, slot, 112) * step
            x0 = int(slot * step + jitter) % (width + 2 * crest_len) - crest_len
            breathe = 0.72 + 0.28 * math.sin(2 * math.pi
                                             * (phase + vice.noise(y, slot, 114)))
            lift = (0.09 + 0.10 * vice.noise(y, slot, 113)) * breathe
            for k in range(crest_len):
                x = x0 + k
                if 0 <= x < width:
                    row[x] = vice.shade(base, 1.0 + lift)

        for x in range(width):
            if vice.noise(x, y, frame_index, 131) > 0.9975 - 0.0015 * f:
                row[x] = vice.shade(row[x], 1.55)

        if body and body[3] > 0.02:
            spread = (0.012 + f * 0.075) * width
            tint = vice.SUN_GLOW if body[0] == "sun" else vice.MOON_CORE
            low = 0.30 + 0.70 * vice.clamp(1.0 - body[3])
            strength = low * (0.85 if body[0] == "sun" else 0.55)
            for dx in range(-int(spread), int(spread) + 1):
                x = int(sun_x + dx)
                if not 0 <= x < width:
                    continue
                falloff = (1.0 - abs(dx) / (spread + 0.5)) ** 1.5
                amount = falloff * strength * 0.16
                if vice.noise(x, y, frame_index, 132) > 0.72 - 0.26 * falloff:
                    amount += falloff * strength * 0.52
                row[x] = vice.mix(row[x], tint, vice.clamp(amount))

    for sx, sy, star, sky, cycles, off, amp in scene["stars"]:
        twinkle = 0.55 + 0.45 * math.sin(2 * math.pi * (phase * cycles + off))
        vis = amp * twinkle
        if vis > 0.08:
            px[sy][sx] = vice.mix(sky, star, vis)

    # Rotor blur: two alternating greys, which at 12 fps reads as spinning.
    blur = (172, 176, 198) if frame_index % 2 else (104, 108, 130)
    for x, y in scene["rotor"]:
        px[y][x] = blur

    return px


# --- palette ----------------------------------------------------------------
def _key(colour):
    return ((colour[0] >> 3) << 10) | ((colour[1] >> 3) << 5) | (colour[2] >> 3)


def _unkey(k):
    return (((k >> 10) & 31) << 3, ((k >> 5) & 31) << 3, (k & 31) << 3)


def median_cut(hist, want):
    """Split the colour cloud on its widest axis until `want` boxes remain.

    A fixed colour cube bands the sky gradient badly — most of a frame is one
    narrow sweep of blues and pinks, and an even cube spends its entries on
    colours that are not in the picture.
    """
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

    palette = []
    for box in boxes:
        total = sum(hist[k] for k in box) or 1
        r = sum(_unkey(k)[0] * hist[k] for k in box) / total
        g = sum(_unkey(k)[1] * hist[k] for k in box) / total
        b = sum(_unkey(k)[2] * hist[k] for k in box) / total
        palette.append((int(r), int(g), int(b)))
    return palette


def build(path, hour, width=WIDTH, height=HEIGHT, frames=FRAMES):
    scene = build_scene(width, height, hour)
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


def build_all(out_dir, width=WIDTH, height=HEIGHT, frames=FRAMES, log=None):
    os.makedirs(out_dir, exist_ok=True)
    written = []
    for band in range(BANDS):
        path = os.path.join(out_dir, band_name(band))
        size = build(path, band_to_hour(band), width, height, frames)
        written.append((band, path, size))
        if log:
            log(band, path, size)
    return written


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "/tmp/vice"
    build_all(target, log=lambda b, p, s: print("band %03d -> %s (%d KB)"
                                                % (b, os.path.basename(p), s // 1024)))
