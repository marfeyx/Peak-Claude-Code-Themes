"""The "vice" theme: a GTA VI Vice City panorama with a live day-night cycle.

Leonida from the beach, looking out over the bay. The sky runs a real
twenty-four hour cycle off your wall clock — deep night, first light, dawn,
midday haze, golden hour, sunset, afterglow, dusk — and everything else follows
it. The sun arcs across and sinks into the water, laying a glitter path that
shimmers back at you. After dusk the stars come out, the skyline lights up
window by window, every lit window drops a wobbling reflection into the bay,
and the neon on the strip starts to pulse.

Downtown sits on the left shore and thins out into open water, so the sun
always has somewhere to set. Palms frame the edges and are placed to keep that
stretch of horizon clear. Somewhere out there a boat drifts and planes cross
overhead.

Your context window is your wanted level. An empty one is a clean record. Past
four stars a police chopper sweeps the bay with a searchlight; at five, red and
blue wash over the whole scene and the water picks it up.

Claude Code caps refreshInterval at one second, so this animates at 1 fps.
Everything is driven from wall-clock time rather than a frame counter, so it
keeps moving smoothly across the event-driven redraws that happen while you
work, and never jumps when a redraw is skipped.

In Windows Terminal the whole window becomes the bay: a looping GIF for every
ten minutes of the day is rendered once into AppData, and the profile is
re-pointed as the clock rolls over, so the sun visibly works its way down
the sky, the light turns over through sunrise and sunset, and the moon comes
up on the other side, behind your session, over a real day. The panel then draws only what the GIF cannot — the beach,
the palms, the boat and the police chopper — and leaves its sky unset so the
cells stay transparent and the panorama shows through behind them.

Sizing: SL_VICE_HEIGHT, else whatever `/sl vice <rows>` stored, else auto.
Debug: SL_VICE_HOUR pins the time of day, SL_VICE_TIMELAPSE=<seconds> runs a
whole day in that many seconds, SL_VICE_PIXELS=half drops back to half-block
resolution, and ~/.claude/statusline-vice-pct pins the wanted level.
"""

import math
import os
import re
import subprocess
import sys
import time

from common import (Canvas, DIM, OctantPixels, Pixels, c, dig, env_int, git_branch,
                    human_duration, lerp, lerp_rgb, money, short_path,
                    term_size, truecolor, weekly_spend)

DESCRIPTION = "GTA VI Vice City panorama, live day-night cycle, wanted-level heat"

M64 = (1 << 64) - 1
CLAUDE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HEIGHT_FILE = os.path.join(CLAUDE_DIR, "statusline-water-height")  # shared with /sl <name> <rows>
PCT_FILE = os.path.join(CLAUDE_DIR, "statusline-vice-pct")
APPLIED_FILE = os.path.join(CLAUDE_DIR, "statusline-wt-applied")
BG_SCRIPT = os.path.join(CLAUDE_DIR, "sl-water-bg.py")
SYNC_STAMP = os.path.join(CLAUDE_DIR, "statusline-vice-sync")

# Windows Terminal draws the background GIF at this opacity over this profile
# colour, but panel cells are painted at full strength. Must match SETS["vice"]
# in sl-water-bg.py, or the strip will not sit in the same light as the bay.
BG_OPACITY = 0.70
BG_UNDER = (11, 10, 30)          # #0B0A1E
# The panel is washed a little less than the background it sits on. Matching it
# exactly is "correct" and makes the foreground recede into the bay; a little
# more presence reads as nearer the camera without breaking the shared light.
PANEL_OPACITY = 0.80
BANDS_PER_DAY = 144              # one background every ten minutes

# --- the sky's day ---------------------------------------------------------
# (hour, zenith, horizon). Interpolated and wrapped, so the sky is never a
# lookup of discrete "times of day" but a continuous slide between them.
SKY_KEYS = [
    (0.0,  (6, 8, 30),     (18, 14, 48)),      # deep night
    (4.6,  (14, 17, 52),   (62, 34, 82)),      # first light
    (6.2,  (46, 54, 124),  (238, 124, 106)),   # dawn
    (7.6,  (74, 124, 198), (212, 184, 198)),   # early morning
    (11.0, (46, 124, 212), (148, 198, 242)),   # late morning
    (14.0, (38, 116, 208), (152, 202, 244)),   # afternoon
    (17.0, (72, 116, 202), (248, 198, 140)),   # golden hour
    (18.8, (98, 70, 170),  (255, 132, 88)),    # sunset
    (19.8, (58, 34, 114),  (240, 72, 104)),    # afterglow
    (21.0, (22, 18, 64),   (110, 34, 94)),     # dusk
    (22.6, (6, 8, 30),     (18, 14, 48)),      # night again
]

SUNRISE, SUNSET = 6.2, 19.3
TWILIGHT = 1.1          # hours of fade either side of the sun crossing

SUN_CORE = (255, 246, 214)
SUN_RIM = (255, 158, 78)
SUN_LOW = (255, 92, 84)         # the rim reddens as it touches the water
SUN_GLOW = (255, 228, 162)      # the core stays luminous, whatever the hour
MOON_CORE = (238, 240, 252)
MOON_DARK = (92, 100, 130)
STAR_COLOURS = [(255, 255, 255), (206, 224, 255), (255, 232, 206), (226, 206, 255)]

SEA_NEAR = (18, 44, 86)
SEA_FAR = (44, 92, 140)
FOAM = (226, 244, 255)

SAND_NEAR = (126, 96, 78)
SAND_FAR = (192, 158, 120)
SAND_WET = (132, 118, 116)      # the strip the surf keeps darkening

TOWER_DAY = (58, 52, 86)
TOWER_NIGHT = (16, 14, 34)
WINDOW_WARM = (255, 206, 128)
WINDOW_COOL = (176, 214, 255)

NEON_SET = [(255, 68, 152), (86, 231, 231), (172, 122, 255), (255, 176, 72),
            (120, 255, 168)]

PALM_DARK = (14, 12, 28)
PALM_EDGE = (44, 34, 62)

# Where the sun touches the water, and palm positions chosen to frame the bay
# without ever standing in front of that point.
SUNSET_FRAC = 0.84
PALM_SLOTS = (0.045, 0.175, 0.315, 0.455, 0.975)

COP_RED = (255, 58, 58)
COP_BLUE = (72, 140, 255)
SEARCH = (255, 248, 206)

# --- HUD palette -----------------------------------------------------------
NEON_PINK = (255, 78, 152)
NEON_CYAN = (86, 231, 231)
NEON_GOLD = (255, 196, 84)
NEON_VIOLET = (172, 122, 255)
CASH_GREEN = (126, 217, 87)
STAR_COLD = (168, 168, 184)

STARS = 5
RADIO = ["WKTT Talk Radio", "Flylo FM", "Vice City FM", "Radio Espantoso",
         "Emotion 98.3", "Wave 103", "Fever 105", "Non-Stop-Pop"]

# --- motion ----------------------------------------------------------------
CLOUD_SPEED = 0.45          # columns per second
WAVE_SPEED = 0.8            # radians per second
WAVE_LEN = 15.0             # columns per swell
GLITTER_SPEED = 2.3
PLANE_PERIOD = 190.0        # seconds between flyovers
PLANE_SPEED = 7.0           # columns per second
BOAT_SPEED = 0.55
CHOPPER_SPEED = 5.5


class QuantOctants(OctantPixels):
    """Octant layer that snaps colours to a 5-bit-per-channel grid.

    A cell carries at most two colours, so `OctantPixels` runs an exhaustive
    best-pair search over the distinct colours inside it. Per-pixel grain and
    shimmer give almost every cell the full eight, and that search is then
    quadratic in eight for every cell of every frame — it was 95% of the render.
    Snapping to 5 bits is a colour error of at most 7/255, invisible against
    dithered pixel art, and collapses most cells to one or two distinct values.
    """

    def __init__(self, cols, rows, wash=False):
        OctantPixels.__init__(self, cols, rows)
        # Over the background GIF, paint in the same washed-out light it is
        # composited into. Full-strength sand on a 38%-opacity bay reads as a
        # bright sticker laid over the photo.
        self.wash = wash

    def set(self, x, y, colour):
        if colour is not None:
            if self.wash:
                colour = mix(BG_UNDER, colour, PANEL_OPACITY)
            colour = (colour[0] & 0xF8, colour[1] & 0xF8, colour[2] & 0xF8)
        OctantPixels.set(self, x, y, colour)


def make_layer(cols, rows, wash=False):
    """The pixel layer to draw on.

    Octants give 2x4 subpixels per cell against the half-block's 1x2 — double
    the linear resolution — but need a font with Unicode 16 octant glyphs. Set
    SL_VICE_PIXELS=half to fall back if they come out as empty boxes.
    """
    if os.environ.get("SL_VICE_PIXELS", "").strip().lower() == "half":
        return Pixels(cols, rows)
    return QuantOctants(cols, rows, wash=wash)


def blit_scaled(px, x0, y0, sprite, palette, scale=1, flip=False):
    """Blit a sprite with each source pixel expanded to scale x scale.

    Sprite art is authored at half-block resolution; at octant resolution it
    would otherwise come out half the physical size.
    """
    if scale <= 1:
        px.blit(x0, y0, sprite, palette, flip=flip)
        return
    span = max(len(line) for line in sprite)
    for dy, line in enumerate(sprite):
        for dx, key in enumerate(line):
            colour = palette.get(key)
            if colour is None:
                continue
            sx = (span - 1 - dx) if flip else dx
            for oy in range(scale):
                for ox in range(scale):
                    px.set(x0 + sx * scale + ox, y0 + dy * scale + oy, colour)


def noise(*key):
    """Deterministic hash in [0, 1). Keeps scenery stable between frames."""
    h = 0x9E3779B97F4A7C15
    for k in key:
        h = (h + (int(k) & M64) + 0x9E3779B97F4A7C15) & M64
        h = ((h ^ (h >> 30)) * 0xBF58476D1CE4E5B9) & M64
        h = ((h ^ (h >> 27)) * 0x94D049BB133111EB) & M64
        h ^= h >> 31
    return (h & 0xFFFFFFFF) / 4294967296.0


def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else (hi if v > hi else v)


def smooth(t):
    """Smoothstep; used wherever a linear fade looks mechanical."""
    t = clamp(t)
    return t * t * (3.0 - 2.0 * t)


def mix(c0, c1, t):
    return lerp_rgb(c0, c1, clamp(t))


def shade(colour, f):
    """Scale a colour toward black (f<1) or white (f>1)."""
    if f <= 1.0:
        return (int(colour[0] * f), int(colour[1] * f), int(colour[2] * f))
    return mix(colour, (255, 255, 255), f - 1.0)


# --- configuration ---------------------------------------------------------
def height_setting():
    raw = os.environ.get("SL_VICE_HEIGHT", "").strip().lower()
    if raw:
        return raw
    try:
        with open(HEIGHT_FILE) as fh:
            return fh.read().strip().lower()
    except OSError:
        return ""


def panel_height(lines):
    raw = height_setting()
    if raw == "full":
        return max(8, lines - 4)
    if raw and raw != "auto":
        try:
            return max(5, min(int(raw), max(5, lines - 2)))
        except ValueError:
            pass
    # Leave room for the two HUD rows and the prompt box. The floor is low
    # enough that a short terminal gets a squashed panorama rather than a
    # status line taller than the window it lives in.
    return max(4, min(lines - 9, 20))


def forced_pct():
    try:
        with open(PCT_FILE) as fh:
            return max(0.0, min(100.0, float(fh.read().strip())))
    except (OSError, ValueError):
        return None


def clock_hour(t):
    """Local time of day in hours, honouring the debug overrides."""
    raw = os.environ.get("SL_VICE_HOUR", "").strip()
    if raw:
        try:
            return float(raw) % 24.0
        except ValueError:
            pass
    lapse = os.environ.get("SL_VICE_TIMELAPSE", "").strip()
    if lapse:
        try:
            span = float(lapse)
            if span > 0:
                return (t / span * 24.0) % 24.0
        except ValueError:
            pass
    lt = time.localtime(t)
    return lt.tm_hour + lt.tm_min / 60.0 + lt.tm_sec / 3600.0


# --- the Windows Terminal background ---------------------------------------
def gif_mode():
    """True when one of this theme's GIFs is currently the WT background."""
    try:
        with open(APPLIED_FILE) as fh:
            return "vice" in fh.read().split()
    except OSError:
        return False


def applied_band():
    try:
        with open(APPLIED_FILE) as fh:
            return int(fh.read().split()[0])
    except (OSError, ValueError, IndexError):
        return None


def band_hour(hour):
    """The hour the current band's GIF was actually baked at.

    The panel's own light moves continuously while the background steps every
    half hour; lighting the beach from the real clock would leave it drifting
    out of step with the bay behind it for minutes at a time.
    """
    band = int(hour * BANDS_PER_DAY / 24.0) % BANDS_PER_DAY
    return (band + 0.5) * 24.0 / BANDS_PER_DAY


def sync_background(hour):
    """Re-point the background when the clock rolls into a new hour.

    Fire and forget: rewriting settings.json takes long enough that waiting on
    it would stall the status line, and there is nothing to do with the result.
    Guarded by the applied band so this runs 24 times a day, not once a second.
    """
    want = int(hour * BANDS_PER_DAY / 24.0) % BANDS_PER_DAY
    if applied_band() == want:
        return
    # A failed apply — a band whose GIF was never rendered, say — leaves the
    # state file untouched, so without a cooldown this would fork a process
    # every single second forever.
    now = time.time()
    try:
        if now - os.path.getmtime(SYNC_STAMP) < 8.0:
            return
    except OSError:
        pass
    try:
        with open(SYNC_STAMP, "w"):
            pass
        subprocess.Popen([sys.executable, BG_SCRIPT, "apply", str(want), "--set", "vice"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass


# --- sky -------------------------------------------------------------------
def sky_stops(hour):
    """Zenith and horizon colours for this moment, wrapped across midnight."""
    keys = SKY_KEYS
    for i in range(len(keys) - 1):
        h0, top0, bot0 = keys[i]
        h1, top1, bot1 = keys[i + 1]
        if h0 <= hour < h1:
            f = smooth((hour - h0) / (h1 - h0))
            return mix(top0, top1, f), mix(bot0, bot1, f)
    # After the last keyframe: wrap around to the first.
    h0, top0, bot0 = keys[-1]
    h1, top1, bot1 = keys[0]
    span = (24.0 - h0) + h1
    f = smooth(((hour - h0) % 24.0) / span)
    return mix(top0, top1, f), mix(bot0, bot1, f)


def daylight(hour):
    """1.0 in full day, 0.0 in full night, smooth through twilight."""
    if SUNRISE - TWILIGHT <= hour <= SUNRISE:
        return smooth((hour - (SUNRISE - TWILIGHT)) / TWILIGHT)
    if SUNRISE < hour < SUNSET:
        return 1.0
    if SUNSET <= hour <= SUNSET + TWILIGHT:
        return smooth(1.0 - (hour - SUNSET) / TWILIGHT)
    return 0.0


def celestial(hour, width, horizon_py):
    """Where the sun or moon sits, and which one it is.

    Both ride the same arc: the sun between sunrise and sunset, the moon over
    the complementary night window. Returns None when neither is up, which only
    happens in the moments the two hand over.
    """
    if SUNRISE - 0.6 <= hour <= SUNSET + 0.6:
        u = (hour - SUNRISE) / (SUNSET - SUNRISE)
        kind = "sun"
    else:
        night_start, night_span = SUNSET, (24.0 - SUNSET) + SUNRISE
        u = ((hour - night_start) % 24.0) / night_span
        kind = "moon"
    # Kept just inside the frame: an arc that runs off the edge means the sun
    # is invisible for the last hour before it should be at its most dramatic.
    # It touches down at SUNSET_FRAC, which PALM_SLOTS is built to keep clear.
    x = width * 0.06 + u * width * (SUNSET_FRAC - 0.06)
    # A flattened arc: the body clears the skyline but never hugs the top row.
    alt = math.sin(math.pi * clamp(u, -0.2, 1.2))
    y = horizon_py - alt * horizon_py * 0.82
    return kind, x, y, alt


# --- skyline ---------------------------------------------------------------
def skyline(width, horizon_py, seed=7, res=1):
    """Deterministic tower strip: (x, w, h) in pixels, left to right.

    Heights are a share of the sky rather than absolute, so the skyline stays a
    band along the horizon at any panel size instead of turning into a barcode
    that reaches the top row. A couple of towers are allowed to be landmarks.
    """
    # The city sits on the left shore of the bay and tapers out, leaving open
    # water to the right. Ringing the whole horizon with towers walls the sun
    # in behind the skyline at exactly the hour it should be setting into the
    # sea, which is the one shot this theme exists for.
    ceiling = max(3.0, horizon_py * 0.62)
    downtown = width * 0.46
    outskirts = width * 0.66
    towers, x = [], -2
    while x < outskirts:
        k = noise(seed, x, 2)
        tall = noise(seed, x, 4) < 0.14      # the odd landmark tower
        w = (4 + int(noise(seed, x, 1) * 4)) if tall else (2 + int(noise(seed, x, 1) * 6))
        w *= res
        h = 2 + int((k ** 1.5) * ceiling * (1.35 if tall else 0.9))
        # Taper toward the edge of town so the city thins into the bay instead
        # of stopping at a wall.
        if x > downtown:
            h = int(h * max(0.18, 1.0 - (x - downtown) / (outskirts - downtown)))
        # Leave the top of the sky clear: a tower that reaches it stops reading
        # as a skyline and becomes a pole down the middle of the panel.
        h = max(1, min(h, int(horizon_py * 0.74)))
        # Shape: a plain block, a stepped setback, or a spire on the tall ones.
        roll = noise(seed, x, 5)
        shape = "spire" if (tall and roll < 0.65) else ("step" if roll < 0.42 else "flat")
        towers.append((x, w, h, shape))
        x += w + (1 if noise(seed, x, 3) < 0.72 else 2) * res
    return towers


# --- scene -----------------------------------------------------------------
def scene(cols, rows, pct, t):
    px = make_layer(cols, rows)
    res = px.ppc                      # 1 at half-block, 2 at octant resolution
    width, height = px.width, px.height
    hour = clock_hour(t)
    day = daylight(hour)
    night = 1.0 - day
    top_c, horiz_c = sky_stops(hour)

    horizon_py = int(height * 0.58)
    beach_py = height - max(2 * res, height // 7)

    # Wanted level drives the police presence.
    stars_lit = wanted_stars(pct)
    siren = 0.0
    if stars_lit >= STARS:
        siren = 0.5 + 0.5 * math.sin(t * math.pi)      # 1 Hz throb

    body = celestial(hour, width, horizon_py)

    # --- sky gradient ------------------------------------------------------
    # Stepped to whole text rows. A cell holds at most two colours, so one that
    # contains four distinct gradient values pays for an exhaustive best-pair
    # search; a smooth gradient gains nothing visible from subpixel vertical
    # resolution, and this makes almost every sky cell a single flat colour.
    grp = px.ppr
    for y in range(horizon_py):
        f = smooth(((y // grp) * grp) / max(1, horizon_py - 1)) ** 0.85
        col = mix(top_c, horiz_c, f)
        for x in range(width):
            px.set(x, y, col)

    # --- stars -------------------------------------------------------------
    if night > 0.04:
        count = int(width * height * 0.0055)
        for i in range(count):
            sx = int(noise(i, 11) * width)
            sy = int(noise(i, 12) ** 1.6 * horizon_py * 0.92)
            twinkle = 0.55 + 0.45 * math.sin(t * (0.7 + noise(i, 13) * 1.8)
                                             + noise(i, 14) * 6.28)
            vis = night * twinkle * (0.35 + 0.65 * noise(i, 15))
            if vis <= 0.08:
                continue
            base = px.px.get((sx, sy), top_c)
            px.set(sx, sy, mix(base, STAR_COLOURS[i % len(STAR_COLOURS)], vis))

    # --- clouds ------------------------------------------------------------
    bands = 3
    for b in range(bands):
        cy = int(horizon_py * (0.14 + 0.19 * b)) + 1
        speed = CLOUD_SPEED * res * (0.5 + 0.5 * b)
        drift = (t * speed + b * 37.0) % (width + 60) - 30
        length = (12 + int(noise(b, 21) * 16)) * res
        for dx in range(length):
            x = int(drift + dx)
            if not 0 <= x < width:
                continue
            # Soft ends so a cloud fades in and out instead of snapping.
            edge = smooth(min(dx, length - 1 - dx) / (3.0 * res))
            puff = 0.5 + 0.5 * math.sin(dx * 0.7 / res + b)
            thick = res + int(puff * 1.8 * res)
            for dy in range(thick):
                y = cy + dy
                if not 0 <= y < horizon_py:
                    continue
                base = px.px.get((x, y), top_c)
                # Undersides catch the horizon colour: sunset-lit cloud bellies.
                lit = mix((236, 236, 244), horiz_c, dy / max(1, thick))
                px.set(x, y, mix(base, lit, 0.5 * edge * (0.55 + 0.45 * day)))

    # --- sun / moon --------------------------------------------------------
    if body:
        kind, bx, by, alt = body
        radius = (3.2 if kind == "sun" else 2.4) * res
        if kind == "sun":
            low = clamp(1.0 - alt * 2.2)            # reddens as it sinks
            # Only the rim goes red. Letting the core redden too sinks the disc
            # into a sunset sky of the same hue and the sun simply vanishes at
            # the exact hour it should be the brightest thing on screen.
            core, rim = mix(SUN_CORE, SUN_GLOW, low), mix(SUN_RIM, SUN_LOW, low)
        else:
            core, rim = MOON_CORE, MOON_DARK
        glow = 0.9 if kind == "sun" else 0.5
        for y in range(max(0, int(by - radius * 3)), min(height, int(by + radius * 3))):
            for x in range(max(0, int(bx - radius * 4)), min(width, int(bx + radius * 4))):
                # Both pixel layers are square (a half-block is one cell wide by
                # half tall, an octant half by a quarter), so no x compensation.
                dx, dy = x - bx, y - by
                dist = math.hypot(dx, dy)
                if y >= horizon_py and kind == "sun" and alt < 0.06:
                    continue                          # already below the water
                base = px.px.get((x, y))
                if base is None:
                    continue
                if dist <= radius:
                    tone = mix(core, rim, clamp(dist / radius) ** 0.7)
                    if kind == "moon":
                        # Terminator: light the side away from the sun.
                        phase = clamp((dx / radius + 1.0) * 0.5)
                        tone = mix(MOON_DARK, tone, smooth(phase * 1.3))
                    px.set(x, y, tone)
                elif dist <= radius * 3.4:
                    halo = (1.0 - (dist - radius) / (radius * 2.4)) ** 2
                    px.set(x, y, mix(base, rim, clamp(halo) * 0.55 * glow))

    # --- skyline -----------------------------------------------------------
    tower_body = mix(TOWER_DAY, TOWER_NIGHT, night)
    lit = []            # window positions, for the reflections in the bay
    # A dimmer layer set back behind the main strip, for depth.
    haze = mix(tower_body, horiz_c, 0.45)
    for bx_, bw, bh, _ in skyline(width, horizon_py, seed=19, res=res):
        btop = horizon_py - max(1, int(bh * 0.7))
        for x in range(max(0, bx_ + 2 * res), min(width, bx_ + bw + 2 * res)):
            for y in range(max(0, btop), horizon_py):
                px.set(x, y, haze)

    for tx, tw, th, shape in skyline(width, horizon_py, res=res):
        top = horizon_py - th
        for x in range(tx, min(width, tx + tw)):
            if x < 0:
                continue
            y0 = top
            if shape == "step" and tw >= 4:
                # Inset the outer columns so the roof steps down at the edges.
                inset = min(x - tx, tx + tw - 1 - x)
                y0 = top + (2 if inset == 0 else (1 if inset == 1 else 0))
            for y in range(max(0, y0), horizon_py):
                px.set(x, y, tower_body)
        if shape == "spire":
            sx = tx + tw // 2
            for y in range(max(0, top - 3), top):
                px.set(sx, y, tower_body)
            if night > 0.15:               # aircraft warning light on the mast
                blink = 0.35 + 0.65 * (1.0 if math.sin(t * 2.4 + tx) > 0.4 else 0.0)
                px.set(sx, max(0, top - 3), mix(tower_body, COP_RED, night * blink))
        # Lit windows after dusk, one grid cell every other pixel.
        if night > 0.12:
            for wy in range(top + 1, horizon_py - 1, 2):
                for wx in range(tx + 1, min(width, tx + tw) - 1, 2):
                    if wx < 0:
                        continue
                    k = noise(tx, wx, wy, 31)
                    if k > 0.42 * night + 0.06:
                        continue
                    # A few windows flicker: someone is up and moving about.
                    if noise(tx, wx, wy, 32) < 0.06:
                        if math.sin(t * 0.7 + k * 40.0) < 0.2:
                            continue
                    warm = WINDOW_WARM if noise(tx, wx, wy, 33) < 0.78 else WINDOW_COOL
                    px.set(wx, wy, mix(tower_body, warm, 0.55 + 0.45 * night))
                    lit.append((wx, warm))
        # Neon crown on the taller towers.
        if th > 9 and night > 0.2:
            hue = NEON_SET[int(noise(tx, 41) * len(NEON_SET)) % len(NEON_SET)]
            pulse = 0.55 + 0.45 * math.sin(t * 1.6 + tx * 0.7)
            for x in range(max(0, tx), min(width, tx + tw)):
                px.set(x, top, mix(tower_body, hue, night * pulse))

    # --- sea ---------------------------------------------------------------
    sun_x = body[1] if body else width * 0.5
    sun_kind = body[0] if body else "sun"
    sea_rows = max(1, min(beach_py, height) - horizon_py)
    for y in range(horizon_py, min(beach_py, height)):
        f = smooth(max(0, (y // grp) * grp - horizon_py) / sea_rows)
        base = mix(SEA_FAR, SEA_NEAR, f)
        # The sea has no light of its own. Leaving it at its daylight value
        # after dark gives a bright slate bay under a night sky, and drowns
        # both the moon's glitter path and the city reflections in it.
        base = shade(base, 0.44 + 0.56 * day)
        # The sky bleeds into the water, strongest at the horizon but never
        # fully gone — a sunset that stops dead at the waterline looks pasted on.
        base = mix(base, horiz_c, 0.22 + (1.0 - f) * 0.48)
        for x in range(width):
            px.set(x, y, base)

        # Chop: short horizontal crests that drift. A single sine across x and
        # y draws diagonal corduroy instead — the sea has to be made of
        # discrete, scattered dashes to read as water at this resolution.
        step = max(3, int(10 - f * 5)) * res
        crest_len = (1 + int(f * 3)) * res
        drift = t * (0.5 + 2.0 * f) * res
        for slot in range(-1, width // step + 2):
            if noise(y, slot, 111) > 0.52:
                continue
            jitter = noise(y, slot, 112) * step
            x0 = int(slot * step + jitter + drift) % (width + 2 * crest_len) - crest_len
            lift = 0.10 + 0.13 * noise(y, slot, 113)
            for k in range(crest_len):
                x = x0 + k
                if 0 <= x < width:
                    px.set(x, y, shade(base, 1.0 + lift))

        # Glitter: the sun or moon laid out across the water, widening toward
        # the viewer and broken up into sparkles.
        if body and body[3] > 0.02:
            spread = (1.2 + f * 8.0) * res
            tint = SUN_GLOW if sun_kind == "sun" else MOON_CORE
            # A glitter path is a low-sun effect: near the zenith the light
            # goes into the water rather than bouncing off it toward you.
            low = 0.30 + 0.70 * clamp(1.0 - body[3])
            strength = low * (0.85 if sun_kind == "sun" else 0.55)
            for dx in range(-int(spread), int(spread) + 1):
                x = int(sun_x + dx)
                if not 0 <= x < width:
                    continue
                falloff = (1.0 - abs(dx) / (spread + 0.5)) ** 1.5
                # A faint steady column plus sparkles that re-roll a few times
                # a second, so the path shimmers rather than glows solid.
                amount = falloff * strength * 0.16
                if noise(x, y, int(t * GLITTER_SPEED)) > 0.72 - 0.26 * falloff:
                    amount += falloff * strength * 0.52
                px.set(x, y, mix(px.px[(x, y)], tint, clamp(amount)))

        # Siren wash: red and blue crawling over the water at five stars.
        if siren > 0.02:
            for x in range(width):
                side = COP_RED if math.sin(x * 0.18 + t * 2.2) > 0 else COP_BLUE
                px.set(x, y, mix(px.px[(x, y)], side, 0.16 * siren * (0.3 + f)))

    # --- horizon ------------------------------------------------------------
    # One crisp line where the water meets the sky. In the small hours the two
    # are nearly the same value and the bay loses its edge without it.
    if 0 <= horizon_py < height:
        for x in range(width):
            base = px.px.get((x, horizon_py))
            if base:
                px.set(x, horizon_py, shade(base, 1.18 + 0.12 * (1.0 - day)))

    # --- city lights on the water ------------------------------------------
    # Every lit window drops a wobbling streak into the bay below it. This is
    # what makes the night scene: without it the city is a lit strip sitting on
    # top of flat black water, and the two do not belong to the same picture.
    if night > 0.15 and lit:
        for lx, lcol in lit:
            depth = (2 + int(noise(lx, 201) * 4)) * res
            for k in range(depth):
                y = horizon_py + k
                if y >= min(beach_py, height):
                    break
                wobble = int(round(math.sin(t * 1.1 + lx * 0.45 + k * 0.9)
                                   * (0.4 + k * 0.5)))
                x = lx + wobble
                if not 0 <= x < width:
                    continue
                fade = (1.0 - k / depth) ** 1.4 * 0.62 * night
                px.set(x, y, mix(px.px[(x, y)], lcol, fade))

    # --- surf line ---------------------------------------------------------
    if beach_py < height:
        for x in range(width):
            wobble = (math.sin(x / (9.0 * res) + t * 1.1)
                      + 0.5 * math.sin(x / (3.3 * res) - t * 1.7))
            y = beach_py + (res if wobble > 0.7 else 0)
            if 0 <= y < height:
                foam = mix(SEA_NEAR, FOAM, 0.35 + 0.45 * clamp(wobble))
            px.set(x, y, shade(foam, 0.45 + 0.55 * day))

    # --- beach -------------------------------------------------------------
    for y in range(min(beach_py + 1, height), height):
        f = max(0, (y // grp) * grp - beach_py) / max(1, height - beach_py)
        base = mix(SAND_FAR, SAND_NEAR, f)
        # Wet sand right at the surf line, drying out toward the viewer.
        base = mix(SAND_WET, base, smooth(f * 2.2))
        # Sand takes the colour of whatever is lighting it.
        base = mix(base, horiz_c, 0.18 * (1.0 - day))
        base = shade(base, 0.44 + 0.56 * day)
        for x in range(width):
            # 2x2 blocks. Per-pixel grain gives a 2x4 octant cell three or four
            # distinct colours, the packer can only keep two, and which one it
            # drops varies cell to cell — that is the banding across the beach.
            grain = noise(x // 2, y // 2, 51)
            col = shade(base, 0.93 + 0.07 * int(grain * 3))
            if grain > 0.985:                     # the odd shell or pebble
                col = shade(col, 1.35)
            px.set(x, y, col)

    # --- palms -------------------------------------------------------------
    # Grouped at the left and on the far right edge, framing the bay and
    # deliberately leaving the sun's arc — and above all the point where it
    # meets the water — unobstructed.
    for i, frac in enumerate(PALM_SLOTS):
        if width < 80 and i in (1, 3):
            continue                       # thin out on a narrow terminal
        bx = int(frac * width + (noise(i, 61) - 0.5) * 5)
        draw_palm(px, max(1, min(width - 2, bx)), height, beach_py, t, i, day, res,
                  sky=horiz_c)

    # --- boat --------------------------------------------------------------
    if horizon_py + 3 < beach_py:
        span = width + 24
        bx = (t * BOAT_SPEED * res + noise(int(t // 600), 71) * span) % span - 12
        by = horizon_py + (2 + int(noise(int(t // 600), 72) * 2)) * res
        draw_boat(px, int(bx), by, day, night, res)

    # --- plane -------------------------------------------------------------
    leg = t % PLANE_PERIOD
    if leg < (width + 30) / (PLANE_SPEED * res):
        planes_seen = int(t // PLANE_PERIOD)
        py = 2 * res + int(noise(planes_seen, 81) * max(1, horizon_py // 3))
        pxx = leg * PLANE_SPEED * res - 12
        rtl = noise(planes_seen, 82) < 0.5
        draw_plane(px, int(pxx if not rtl else width - pxx), py, t, rtl, night, res)

    # --- police chopper ----------------------------------------------------
    if stars_lit >= 4:
        span = width + 40 * res
        travelled = t * CHOPPER_SPEED * res
        outbound = int(travelled // span) % 2 == 0     # alternate legs: a patrol
        u = travelled % span
        sweep = (u if outbound else span - u) - 20 * res
        cy = int((5.5 + 2.0 * math.sin(t * 0.6)) * res)
        # The art is drawn nose-left, so it has to be mirrored on the leg that
        # travels to the right, or the thing flies tail-first.
        draw_chopper(px, int(sweep), cy, t, horizon_py, height, siren, px,
                     res=res, flip=outbound)

    canvas = Canvas(width, rows)
    px.flush(canvas)
    return canvas


def draw_palm(px, bx, height, beach_py, t, seed, day, res=1, span=(0.44, 0.30),
              sky=None):
    """A leaning palm, drawn as a silhouette.

    Fronds leave the crown heading up and outward, then droop under their own
    weight — the quadratic term in `fy`. Without the droop they fan out like a
    TV aerial; with it they read as a palm even at six pixels long.
    """
    # Palms are sized off the panel, not in absolute pixels, so the crown always
    # clears the horizon and is silhouetted against the bright sky. Rooted in
    # the sand its crown sits on the waterline, where a dark shape on dark water
    # simply disappears.
    scale = span[0] + noise(seed, 101) * span[1]
    tall = max(6, int(px.height * scale))
    lean = (noise(seed, 102) - 0.5) * 3.4 * res
    sway = math.sin(t * 0.5 + seed * 1.7) * 0.9 * res
    dark = mix(PALM_DARK, PALM_EDGE, 0.30 * day)
    # Rim light: the lit edge of the trunk picks up whatever colour the sky is
    # doing. Flat black silhouettes are what make the strip look dead at dusk,
    # when everything behind them has gone orange.
    edge = mix(dark, sky if sky else PALM_EDGE, 0.42)

    root = min(px.height - 1, beach_py + 2 * res)
    top_y = max(0, root - tall)

    for k in range(tall + 1):
        f = k / max(1, tall)
        x = bx + lean * f * f + sway * f * f
        y = root - k
        px.set(int(x), y, dark)
        if f < 0.55:                      # the trunk thickens toward the root
            for k2 in range(1, res + 1):
                px.set(int(x) + k2, y, edge)

    cx, cy = int(bx + lean + sway), top_y
    fronds = 6
    # A frond is about as wide as it is long and falls away steeply. Let the
    # horizontal term outrun the vertical one and the crown flattens into a
    # spider; the quadratic droop is what pulls the tips back down.
    for i in range(fronds):
        ang = -math.pi * 0.86 + i * (math.pi * 0.72 / (fronds - 1)) + sway * 0.04
        length = max(3, int((3.2 + noise(seed, i, 103) * 1.6) * res + tall * 0.16))
        for s in range(1, length + 1):
            u = s / length
            fx = cx + math.cos(ang) * s * 0.95
            fy = cy + math.sin(ang) * s * 0.55 + (u ** 2) * length * 0.85
            px.set(int(fx), int(fy), dark)
            if s <= max(1, length // 3):  # fronds are fat where they attach
                for k2 in range(1, res + 1):
                    px.set(int(fx), int(fy) + k2, dark)

    for dx in range(0, res + 1):
        for dy in range(0, res + 1):
            px.set(cx + dx - res // 2, cy + dy, dark)
    if noise(seed, 104) < 0.5:            # a couple of coconuts under the crown
        px.set(cx - res, cy + 2 * res, edge)
        px.set(cx + res, cy + 2 * res, edge)


BOAT = ["..ww..", ".hhhh.", "bbbbbb"]


def draw_boat(px, x0, y0, day, night, res=1):
    hull = mix((44, 40, 58), (16, 16, 30), night)
    house = mix((208, 206, 214), (64, 66, 88), night)
    light = (255, 214, 128) if night > 0.3 else house
    blit_scaled(px, x0, y0, BOAT, {"b": hull, "h": house, "w": light}, res)


PLANE = [".ppp..", "ppppp.", ".p..l."]


def draw_plane(px, x0, y0, t, flip, night, res=1):
    body = mix((216, 220, 232), (96, 100, 124), night)
    blink = (255, 70, 70) if (t % 1.6) < 0.5 else mix(body, (120, 40, 40), 0.6)
    blit_scaled(px, x0, y0, PLANE, {"p": body, "l": blink}, res, flip=flip)


# A gap between the rotor and the hull, a tail boom that actually reads as one,
# and a glass nose: without those three it is just a dark lump with a bar on top.
CHOPPER = [
    ".rrrrrrrrrrr..",
    "......m.......",
    "...bbbbbb.tttt",
    "..gcbbbbbb...v",
    "...bbbbbb....v",
    "....s..s......",
]


def draw_chopper(px, x0, y0, t, horizon_py, height, siren, layer, res=1, flip=False):
    """Police chopper with a rotor blur and a searchlight sweeping the bay."""
    shell = (26, 28, 42)
    glass = (128, 176, 214)
    rotor = (162, 166, 190) if (t * 8) % 2 < 1 else (98, 102, 126)
    skid = (48, 50, 68)
    blit_scaled(px, x0, y0, CHOPPER,
                {"b": shell, "g": glass, "c": glass, "m": skid,
                 "r": rotor, "t": shell, "v": rotor, "s": skid}, res, flip=flip)

    # The belly sits under the hull, which mirrors along with the sprite.
    span = max(len(line) for line in CHOPPER)
    belly = (span - 1 - 5) if flip else 5
    cone_x = x0 + belly * res + res // 2
    beacon = COP_RED if math.sin(t * 6.0) > 0 else COP_BLUE
    for k in range(res):
        px.set(cone_x + k, y0 + 5 * res, beacon)

    # Searchlight: a widening cone from the belly, brightest where it lands.
    top = y0 + 6 * res
    for y in range(top, height):
        f = (y - top) / max(1, height - top)
        halfw = (1.0 + f * 7.0) * res
        on_water = horizon_py <= y
        for dx in range(-int(halfw), int(halfw) + 1):
            x = cone_x + dx
            if not 0 <= x < layer.width:
                continue
            base = layer.px.get((x, y))
            if base is None:
                continue
            edge = clamp(1.0 - abs(dx) / (halfw + 0.6)) ** 1.5
            amount = edge * (0.40 - 0.14 * f)
            if on_water:
                # The pool where the beam hits the water is the bright part;
                # the beam itself is only haze in the air above it.
                amount *= 1.9
                if noise(x, y, int(t * 3.0)) > 0.66:
                    amount *= 1.5
            layer.set(x, y, mix(base, SEARCH, clamp(amount * (0.75 + 0.25 * siren))))


def foreground(cols, rows, pct, t):
    """The live strip drawn over the background GIF.

    Only the things the GIF cannot do: it is baked per hour, so anything that
    has to react to the wanted level, or move faster than an hour, lives here.
    The sky and sea are left unset so the cells stay transparent and the GIF
    shows through behind them.
    """
    px = make_layer(cols, rows, wash=True)
    res = px.ppc
    width, height = px.width, px.height
    hour = band_hour(clock_hour(t))
    day = daylight(hour)
    _, horiz_c = sky_stops(hour)

    beach_py = int(height * 0.62)
    stars_lit = wanted_stars(pct)
    siren = 0.5 + 0.5 * math.sin(t * math.pi) if stars_lit >= STARS else 0.0

    # --- surf line ---------------------------------------------------------
    for x in range(width):
        wobble = (math.sin(x / (9.0 * res) + t * 1.1)
                  + 0.5 * math.sin(x / (3.3 * res) - t * 1.7))
        y = beach_py + (res if wobble > 0.7 else 0)
        if 0 <= y < height:
            foam = mix(SEA_NEAR, FOAM, 0.35 + 0.45 * clamp(wobble))
            px.set(x, y, shade(foam, 0.45 + 0.55 * day))

    # --- beach -------------------------------------------------------------
    grp = px.ppr
    for y in range(beach_py + 1, height):
        f = max(0, (y // grp) * grp - beach_py) / max(1, height - beach_py)
        base = mix(SAND_FAR, SAND_NEAR, f)
        base = mix(SAND_WET, base, smooth(f * 2.2))
        base = mix(base, horiz_c, 0.18 * (1.0 - day))
        base = shade(base, 0.44 + 0.56 * day)
        for x in range(width):
            # 2x2 blocks. Per-pixel grain gives a 2x4 octant cell three or four
            # distinct colours, the packer can only keep two, and which one it
            # drops varies cell to cell — that is the banding across the beach.
            grain = noise(x // 2, y // 2, 51)
            col = shade(base, 0.93 + 0.07 * int(grain * 3))
            if grain > 0.985:
                col = shade(col, 1.35)
            if siren > 0.02:
                side = COP_RED if math.sin(x * 0.18 + t * 2.2) > 0 else COP_BLUE
                col = mix(col, side, 0.14 * siren)
            px.set(x, y, col)

    # --- palms -------------------------------------------------------------
    for i, frac in enumerate(PALM_SLOTS):
        if width < 80 and i in (1, 3):
            continue
        bx = int(frac * width + (noise(i, 61) - 0.5) * 5)
        # Shorter than in the full panel: the strip is only a few rows tall and
        # a clipped crown reads as a snapped-off trunk.
        draw_palm(px, max(1, min(width - 2, bx)), height, beach_py, t, i, day,
                  res, span=(0.30, 0.22), sky=horiz_c)

    # --- boat --------------------------------------------------------------
    if beach_py > 6 * res:
        span = width + 24
        bx = (t * BOAT_SPEED * res + noise(int(t // 600), 71) * span) % span - 12
        draw_boat(px, int(bx), max(0, beach_py - 5 * res), day, 1.0 - day, res)

    # --- police chopper ----------------------------------------------------
    if stars_lit >= 4:
        span = width + 40 * res
        travelled = t * CHOPPER_SPEED * res
        outbound = int(travelled // span) % 2 == 0
        u = travelled % span
        sweep = (u if outbound else span - u) - 20 * res
        cy = int(1.0 + 1.5 * (1.0 + math.sin(t * 0.6)) * res)
        draw_chopper(px, int(sweep), cy, t, beach_py, height, siren, px,
                     res=res, flip=outbound)

    canvas = Canvas(width // px.ppc, rows)
    px.flush(canvas)
    return canvas


# --- HUD -------------------------------------------------------------------
def wanted_stars(pct):
    pct = clamp(float(pct or 0.0), 0.0, 100.0)
    return min(STARS, int(pct / 100 * STARS) + (1 if pct > 0 else 0))


def wanted(pct, t):
    lit = wanted_stars(pct)
    if lit >= STARS:
        colour = (255, 64, 64) if time.time() % 2.0 < 1.0 else (176, 30, 30)
    elif lit >= 4:
        colour = (255, 108, 58)
    elif lit >= 3:
        colour = NEON_GOLD
    else:
        colour = NEON_PINK

    if truecolor():
        return (paint(STAR_COLD, DIM, "WANTED ")
                + paint(colour, 167, "★" * lit)
                + paint((70, 62, 86), 237, "☆" * (STARS - lit))
                + paint(colour, 167, f" {pct:.0f}%"))
    sev = 71 if pct < 50 else (179 if pct < 75 else 167)
    return (c(DIM, "WANTED ") + c(sev, "★" * lit)
            + c(237, "☆" * (STARS - lit)) + c(sev, f" {pct:.0f}%"))


def paint(colour, code, s):
    from common import rgb
    return rgb(*colour, s) if truecolor() else c(code, s)


def sep():
    from common import rgb
    return rgb(122, 74, 150, "  ◆  ") if truecolor() else c(DIM, "  ·  ")


ANSI = re.compile(r"\033\[[0-9;]*m")


def vislen(s):
    return len(ANSI.sub("", s))


def join_fit(segments, width):
    """Join segments, dropping the trailing ones that will not fit.

    Segments are supplied in priority order, so a narrow terminal loses the
    duration and the PR before it loses the wanted level. Letting the host
    truncate instead cuts mid-escape and drops a whole row's worth of colour.
    """
    glue = sep()
    glue_len = vislen(glue)
    kept, used = [], 0
    for seg in segments:
        cost = vislen(seg) + (glue_len if kept else 0)
        if kept and used + cost > width:
            break
        kept.append(seg)
        used += cost
    return glue.join(kept)


def hud(d, pct, t, width):
    """Two HUD rows under the panorama."""
    rows = []
    hour = clock_hour(t)

    seg = [paint(NEON_GOLD, 221, f"{int(hour):02d}:{int(hour % 1 * 60):02d}"),
           paint(NEON_PINK, 212, RADIO[int(t // 45) % len(RADIO)])]

    cwd = dig(d, "workspace", "current_dir") or d.get("cwd") or os.getcwd()
    seg.append(paint(NEON_CYAN, 80, short_path(cwd, budget=34)))

    branch = dig(d, "worktree", "branch") or git_branch(cwd)
    if branch:
        seg.append(paint(NEON_VIOLET, 140, branch))

    added = dig(d, "cost", "total_lines_added", default=0) or 0
    removed = dig(d, "cost", "total_lines_removed", default=0) or 0
    if added or removed:
        seg.append(paint(CASH_GREEN, 71, f"+{added}") + c(DIM, "/")
                   + paint((255, 86, 86), 167, f"-{removed}"))
    rows.append(join_fit(seg, width))

    seg = [wanted(pct, t)]

    session_cost = dig(d, "cost", "total_cost_usd")
    if session_cost is not None:
        seg.append(paint(CASH_GREEN, 71, money(session_cost)))

    wk = weekly_spend()
    if wk:
        spend, budget = wk
        share = (spend / budget * 100) if budget else 0.0
        seg.append(paint(NEON_GOLD, 179, money(spend)) + c(DIM, " / ")
                   + c(244, money(budget)) + c(DIM, " · ")
                   + paint(NEON_GOLD, 179, f"{share:.1f}%"))

    model = dig(d, "model", "display_name") or dig(d, "model", "id") or ""
    if model:
        size = dig(d, "context_window", "context_window_size", default=0) or 0
        if size >= 1_000_000 and "1M" not in model:
            model = f"{model} (1M)"
        seg.append(paint(NEON_VIOLET, 110, model))

    effort = dig(d, "effort", "level")
    bits = []
    if d.get("fast_mode"):
        bits.append("⚡ fast")
    if effort:
        bits.append(f"{effort} effort")
    if bits:
        seg.append(c(DIM, " · ").join(paint(NEON_GOLD, 221, b) for b in bits))

    agent = dig(d, "agent", "name")
    if agent:
        seg.append(paint(NEON_VIOLET, 140, f"agent: {agent}"))

    pr = dig(d, "pr", "number")
    if pr:
        state = dig(d, "pr", "review_state") or ""
        kind = "MR" if dig(d, "pr", "kind") == "mr" else "PR"
        label = f"{kind} !{pr}" if kind == "MR" else f"{kind} #{pr}"
        colour = {"approved": CASH_GREEN, "changes_requested": (255, 86, 86),
                  "draft": (140, 140, 150)}.get(state, NEON_GOLD)
        seg.append(paint(colour, 179, label))

    dur = dig(d, "cost", "total_duration_ms")
    if dur:
        seg.append(c(244, human_duration(dur)))

    rows.append(join_fit(seg, width))
    return rows


def plain(width, pct, t):
    """256-colour fallback: a flat horizon instead of the panorama."""
    hour = clock_hour(t)
    day = daylight(hour)
    band = 214 if day > 0.5 else (97 if day > 0.05 else 61)
    return [c(band, "▀" * width)]


def render(d):
    cols, lines = term_size()
    width = max(24, cols - env_int("STATUSLINE_RULE_PAD", 2))
    t = time.time()

    pct = dig(d, "context_window", "used_percentage")
    pct = 0.0 if pct is None else clamp(float(pct), 0.0, 100.0)
    override = forced_pct()
    if override is not None:
        pct = override

    if not truecolor():
        return plain(width, pct, t) + hud(d, pct, t, width)

    if gif_mode():
        # The panorama is already behind the whole window; drawing it again in
        # the panel would just put a second, smaller horizon over the top of it.
        sync_background(clock_hour(t))
        strip_rows = max(5, min(10, lines // 4))
        return foreground(width, strip_rows, pct, t).rows() + hud(d, pct, t, width)

    rows = panel_height(lines)
    return scene(width, rows, pct, t).rows() + hud(d, pct, t, width)
