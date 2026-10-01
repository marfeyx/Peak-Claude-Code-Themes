"""The meadow theme's day cycle: three looks, blended, on a repeating loop.

One clock, shared by every surface the theme paints, so they cannot disagree:

  * `meadow.py`          the grass panel -- re-reads this every frame
  * `meadowsky.py`       the Windows Terminal sky GIF -- bakes it into frames
  * `meadow_daylight.py` the terminal colour scheme and the Claude Code UI theme

THREE KEYFRAMES, not a continuum. `DAY` is the theme exactly as it was authored;
`SUNSET` and `NIGHT` are the two new looks. The loop ping-pongs through them --
day, sunset, night, sunset again as dawn, day -- which is why dawn needs no
palette of its own: a sunrise and a sunset are the same light from the other
side.

DWELL IS THE POINT. A plain lerp between three stops spends almost all of its
time in between them, so you would never actually see "day" or "night", only the
blends. Each keyframe therefore holds for a stretch of the loop before it starts
moving, and the moves themselves are smoothstepped. The stops below are set so
that roughly half the loop is spent parked on a keyframe.

The period is wall-clock and absolute -- `time.time() % PERIOD` -- not a counter.
Every status line frame is a fresh process with nothing carried over, and the GIF
segments are applied by whichever process happens to notice the boundary, so the
only phase both can agree on is one derived from the clock itself.
"""

import os
import time

# --- the loop ---------------------------------------------------------------

DEFAULT_PERIOD = 1800.0          # seconds for a full day -> night -> day
PERIOD_FILE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                           "statusline-meadow-period")


def period():
    """Seconds per full cycle. SL_MEADOW_PERIOD wins, then the state file."""
    for raw in (os.environ.get("SL_MEADOW_PERIOD", ""), _read(PERIOD_FILE)):
        try:
            value = float(raw.strip())
        except (AttributeError, ValueError):
            continue
        if value >= 30.0:        # below this the sky GIF cannot keep up
            return value
    return DEFAULT_PERIOD


def _read(path):
    try:
        with open(path) as fh:
            return fh.read()
    except OSError:
        return ""


def phase(t=None):
    """Position in the loop, in [0, 1). 0 is high noon.

    SL_MEADOW_PHASE pins it, which is the only way to look at a single moment of
    the cycle: everything downstream reads the clock, so a preview of "sunset"
    is otherwise a matter of waiting for one.
    """
    pinned = os.environ.get("SL_MEADOW_PHASE", "").strip()
    if pinned:
        try:
            return float(pinned) % 1.0
        except ValueError:
            if pinned in ("day", "sunset", "night", "dawn"):
                return {"day": 0.1, "sunset": 0.38,
                        "night": 0.65, "dawn": 0.895}[pinned]
    if t is None:
        t = time.time()
    # A fixed offset would be arbitrary either way; anchoring at the unix epoch
    # at least makes the phase reproducible from a timestamp alone, which is
    # what lets the GIF generator and the panel agree without talking.
    return (t % period()) / period()


# --- keyframes ---------------------------------------------------------------
# Every value is an (r, g, b) triple or a list of them. The three dicts must
# have identical keys and identical list lengths -- `blend` walks them in
# lockstep and does not check.

DAY = {
    # Grass, dark at the root to bright at the tip.
    "grass": [(30, 82, 42), (44, 108, 52), (62, 138, 62), (88, 172, 74),
              (124, 202, 92)],
    "ground": (46, 74, 44),
    "flowers": [(252, 252, 246), (250, 214, 92), (240, 150, 182),
                (186, 146, 226)],
    "flower_eye": (250, 206, 96),
    # Cat, by role: outline / fur / markings / nose.
    "cat_o": (46, 34, 28),
    "cat_l": (232, 152, 72),
    "cat_m": (250, 226, 190),
    "cat_p": (240, 138, 160),
    # The info strip: what the grass under the text is blended toward, the text
    # itself, and the separators.
    "info_shade": (14, 26, 16),
    "info_text": (255, 255, 255),
    "info_sep": (176, 206, 178),
    # Sky gradient, top of frame to horizon. Three stops so sunset can put a
    # band of rose between a blue zenith and a gold horizon; day and night just
    # place their middle stop on the straight line between the other two.
    "sky_top": (58, 186, 214),
    "sky_mid": (118, 209, 227),
    "sky_horizon": (178, 231, 240),
    "cloud_lit": (255, 255, 255),
    "cloud_mid": (226, 243, 250),
    "cloud_shade": (166, 202, 224),
    # The sun/moon disc and its glow, and the stars.
    "disc": (255, 246, 214),
    "disc_glow": (186, 226, 240),
    "star": (58, 186, 214),          # = sky_top: invisible by day, by design
    "firefly": (124, 202, 92),       # = a grass tone: invisible by day
}

SUNSET = {
    # Low sun rakes across the field: tips catch gold, roots fall into a cool
    # shadow. The spread stays wide so the blade banding still reads.
    "grass": [(34, 46, 44), (62, 70, 48), (104, 98, 54), (162, 132, 64),
              (226, 178, 92)],
    "ground": (62, 50, 42),
    "flowers": [(255, 228, 198), (255, 198, 100), (250, 152, 150),
                (188, 134, 198)],
    "flower_eye": (255, 182, 82),
    "cat_o": (48, 28, 26),
    "cat_l": (242, 150, 74),
    "cat_m": (255, 220, 176),
    "cat_p": (240, 138, 150),
    "info_shade": (30, 18, 16),
    "info_text": (255, 250, 244),
    "info_sep": (232, 192, 152),
    "sky_top": (52, 62, 126),
    "sky_mid": (206, 106, 116),
    "sky_horizon": (255, 190, 112),
    "cloud_lit": (255, 214, 170),
    "cloud_mid": (238, 156, 132),
    "cloud_shade": (148, 90, 118),
    "disc": (255, 214, 140),
    "disc_glow": (248, 160, 108),
    "star": (52, 62, 126),           # = sky_top
    "firefly": (226, 178, 92),       # = the brightest grass tone
}

NIGHT = {
    # Moonlight is dim and blue, and the eye loses colour with it: the whole
    # field collapses toward one desaturated teal, keeping only enough spread
    # between the bands to tell a blade from its neighbour.
    "grass": [(10, 20, 26), (16, 30, 38), (22, 44, 52), (32, 60, 68),
              (48, 82, 90)],
    "ground": (14, 22, 26),
    "flowers": [(196, 208, 220), (198, 196, 164), (172, 152, 178),
                (142, 132, 182)],
    "flower_eye": (150, 152, 142),
    "cat_o": (16, 18, 26),
    "cat_l": (96, 92, 96),
    "cat_m": (162, 168, 182),
    "cat_p": (120, 96, 110),
    "info_shade": (4, 8, 14),
    "info_text": (236, 244, 255),
    "info_sep": (120, 146, 170),
    "sky_top": (6, 10, 28),
    "sky_mid": (14, 24, 50),
    "sky_horizon": (28, 44, 78),
    "cloud_lit": (86, 100, 132),
    "cloud_mid": (56, 68, 96),
    "cloud_shade": (30, 38, 60),
    "disc": (240, 242, 228),
    "disc_glow": (78, 96, 140),
    "star": (226, 236, 250),         # the one keyframe where stars are visible
    "firefly": (214, 240, 140),
}

# A TRANSITION STOP, not a fourth look. Straight-line RGB from a gold sunset
# horizon to a navy night one passes through (141, 117, 95) -- a flat warm grey.
# Rendered, the twenty minutes on either side of dusk came out the colour of wet
# cardboard, and those two legs are a quarter of the loop.
#
# The fix is to route the blend through where the light actually goes. Blue hour
# is not sunset-dimmed: the sky reddens out at the horizon and the zenith turns
# violet while the ground goes cold ahead of it. Putting that in as a waypoint
# costs one dict and keeps every other stop where it was. The loop still shows
# three LOOKS -- nothing dwells here, the blend only passes through.
TWILIGHT = {
    "grass": [(16, 26, 34), (26, 40, 46), (40, 56, 58), (64, 78, 70),
              (98, 104, 82)],
    "ground": (28, 30, 38),
    "flowers": [(212, 208, 216), (216, 190, 150), (198, 152, 168),
                (162, 138, 196)],
    "flower_eye": (196, 158, 128),
    "cat_o": (28, 24, 32),
    "cat_l": (146, 114, 98),
    "cat_m": (202, 186, 184),
    "cat_p": (154, 112, 122),
    "info_shade": (10, 10, 20),
    "info_text": (250, 250, 255),
    "info_sep": (168, 158, 188),
    "sky_top": (20, 22, 60),
    "sky_mid": (62, 44, 96),
    "sky_horizon": (152, 86, 98),
    "cloud_lit": (176, 130, 150),
    "cloud_mid": (114, 82, 116),
    "cloud_shade": (64, 50, 84),
    "disc": (250, 198, 152),
    "disc_glow": (142, 92, 122),
    "star": (86, 78, 130),           # just starting to separate from the sky
    "firefly": (186, 214, 126),
}

LOOKS = {"day": DAY, "sunset": SUNSET, "night": NIGHT}

# Stops around the loop: (phase, keyframe). Pairs with the same keyframe on
# either side of a span are what produce the dwell. Must start at 0.0 and the
# last entry must be 1.0 with the same keyframe as the first, or the loop seam
# shows as a jump once per cycle.
STOPS = (
    (0.00, DAY),
    (0.22, DAY),        # noon holds
    (0.34, SUNSET),
    (0.42, SUNSET),     # evening holds
    (0.48, TWILIGHT),   # dusk passes through, does not hold
    (0.54, NIGHT),
    (0.76, NIGHT),      # night holds -- the longest, as it should be
    (0.83, TWILIGHT),   # and again on the way out
    (0.87, SUNSET),     # dawn: the same light from the other side
    (0.92, SUNSET),
    (1.00, DAY),
)


def smoothstep(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3.0 - 2.0 * x)


def _mix(a, b, t):
    return (int(round(a[0] + (b[0] - a[0]) * t)),
            int(round(a[1] + (b[1] - a[1]) * t)),
            int(round(a[2] + (b[2] - a[2]) * t)))


def blend(a, b, t):
    """Interpolate two keyframe dicts. Lists blend element-wise."""
    out = {}
    for key, va in a.items():
        vb = b[key]
        if isinstance(va, list):
            out[key] = [_mix(x, y, t) for x, y in zip(va, vb)]
        else:
            out[key] = _mix(va, vb, t)
    return out


def palette(p):
    """The blended palette at phase `p` in [0, 1)."""
    p = p % 1.0
    for i in range(len(STOPS) - 1):
        p0, k0 = STOPS[i]
        p1, k1 = STOPS[i + 1]
        if p0 <= p <= p1:
            if k0 is k1 or p1 <= p0:
                return dict(k0)
            return blend(k0, k1, smoothstep((p - p0) / (p1 - p0)))
    return dict(DAY)


def palette_now(t=None):
    return palette(phase(t))


# How much of the NIGHT keyframe is in the current mix, in [0, 1]. Scene
# elements that only exist after dark -- stars, fireflies -- fade in on this
# rather than switching on at a threshold, so they arrive with the colour
# instead of popping in against a sunset.
_NIGHTNESS = {id(DAY): 0.0, id(SUNSET): 0.12, id(TWILIGHT): 0.45, id(NIGHT): 1.0}


def nightness(p=None):
    if p is None:
        p = phase()
    p = p % 1.0
    for i in range(len(STOPS) - 1):
        p0, k0 = STOPS[i]
        p1, k1 = STOPS[i + 1]
        if p0 <= p <= p1:
            a, b = _NIGHTNESS[id(k0)], _NIGHTNESS[id(k1)]
            if k0 is k1 or p1 <= p0:
                return a
            return a + (b - a) * smoothstep((p - p0) / (p1 - p0))
    return 0.0


# --- how dark is it? ---------------------------------------------------------
# The terminal colour scheme and the Claude Code UI theme cannot blend -- a
# light theme half-way to a dark one is a grey theme that fails against both
# backgrounds. They switch instead, and this is where. The threshold is set on
# the SKY, because that is what the text actually sits on: the flip happens once
# the horizon has dropped below the point where dark text still clears 4.5:1.

DARK_FROM = 0.47        # dusk: sky has gone past sunset into blue hour
DARK_UNTIL = 0.93       # dawn: sky has come back up


def is_dark(p=None):
    """True when the sky is too dark for the light scheme."""
    if p is None:
        p = phase()
    p = p % 1.0
    return DARK_FROM <= p < DARK_UNTIL


def look_name(p=None):
    """Nearest keyframe name, for status output. Not used for rendering."""
    if p is None:
        p = phase()
    p = p % 1.0
    for lo, hi, name in ((0.00, 0.26, "day"), (0.26, 0.47, "sunset"),
                         (0.47, 0.82, "night"), (0.82, 1.00, "dawn")):
        if lo <= p < hi:
            return name
    return "day"


# --- sky segments ------------------------------------------------------------
# The sky is not one GIF. Windows Terminal restarts a background GIF whenever
# settings.json is reloaded and gives no way to read back its playback position,
# so a single loop-long GIF would drift out of step with this clock the first
# time anything touched the profile -- and stay there.
#
# The loop is therefore cut into SEGMENTS, one GIF each, and the status line
# points the profile at the segment the clock says it is in. Restarting the GIF
# at the segment boundary is not a problem to be tolerated, it is the
# resynchronisation: every boundary re-anchors the sky to the same clock the
# panel uses. Cloud positions and palettes are continuous across the seams, so
# the swap is invisible when it lands on time and merely repeats the last
# segment when it does not.

DEFAULT_SEGMENTS = 6


def segments():
    return max(1, min(60, int(os.environ.get("SL_MEADOW_SEGMENTS", "")
                              or DEFAULT_SEGMENTS)))


def segment_of(p=None):
    if p is None:
        p = phase()
    n = segments()
    return min(n - 1, int((p % 1.0) * n))


if __name__ == "__main__":
    import sys
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 24
    print("period %.0fs  %d segments" % (period(), segments()))
    for i in range(n):
        p = i / float(n)
        pal = palette(p)
        print("  p=%.3f  %-6s seg %d  %-5s sky_top=%-16s grass_tip=%-16s"
              % (p, look_name(p), segment_of(p),
                 "dark" if is_dark(p) else "light",
                 pal["sky_top"], pal["grass"][4]))
