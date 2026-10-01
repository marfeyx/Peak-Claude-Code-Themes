"""The "water" theme: an aquarium whose water level is your remaining context.

The panel is filled from the bottom with water. Water height is the *remaining*
share of the context window, so 40% context used leaves the bottom 60% wet and
the tank drains as the session fills up. Below the surface there are swaying
kelp, corals, rising bubbles and fish that swim a step per frame — all drawn as
half-block pixel art rather than as ASCII.

Claude Code caps `refreshInterval` at one second, so this animates at 1 fps plus
whatever event-driven redraws happen while you work. Everything moves slowly on
purpose; faster motion just looks like teleporting at that frame rate.

Sizing: the panel defaults to the terminal height minus room for the prompt box.
Override with SL_WATER_HEIGHT (a row count, or "full").
"""

import math
import os
import subprocess
import sys
import time

import watergif
from common import (Canvas, DIM, Pixels, c, dig, env_int, git_branch, lerp_rgb,
                    money, short_path, term_size, truecolor, weekly_spend)

DESCRIPTION = "aquarium whose water level tracks remaining context"

# --- palette --------------------------------------------------------------
SURFACE_FOAM = (198, 242, 255)
WATER_TOP = (46, 134, 193)
WATER_DEEP = (6, 24, 56)
SAND_BG = (92, 76, 52)
SAND_FG = (158, 136, 98)
PEBBLE_FG = (118, 104, 82)
BUBBLE_FG = (206, 240, 255)

CORAL_FG = [(232, 118, 142), (240, 158, 88), (204, 112, 196), (238, 196, 96)]

# Kelp shades, darkest at the root and lightest at the tip.
KELP_FG = [(38, 108, 66), (56, 138, 80), (82, 170, 96), (116, 200, 112),
           (158, 226, 140)]

SURFACE_CHARS = "~≈~∼"

# --- pixel sprites ----------------------------------------------------------
# Fish, kelp and corals are drawn as half-block pixels (two per text row) rather
# than as ASCII rebuses like "><(((°>", so they read as pixel art. Sprite keys:
#   d  back and fins      b  body        p  belly
#   f  fin membrane       w  eye white   k  pupil      .  transparent
# Every sprite faces right; `blit(flip=True)` mirrors it for the other direction.

EYE = {"w": (248, 250, 252), "k": (9, 16, 33)}

FISH_SCHEMES = [
    {"d": (14, 116, 144), "b": (34, 211, 238), "p": (165, 243, 252)},   # cyan
    {"d": (157, 74, 110), "b": (244, 114, 182), "p": (251, 207, 232)},  # pink
    {"d": (154, 52, 18), "b": (251, 146, 60), "p": (254, 215, 170)},    # orange
    {"d": (161, 98, 7), "b": (250, 204, 21), "p": (254, 240, 138)},     # yellow
    {"d": (22, 101, 52), "b": (74, 222, 128), "p": (187, 247, 208)},    # green
    {"d": (67, 56, 202), "b": (129, 140, 248), "p": (199, 210, 254)},   # violet
]
FISH_PALETTES = [dict(scheme, f=lerp_rgb(scheme["d"], scheme["b"], 0.5), **EYE)
                 for scheme in FISH_SCHEMES]

FISH_BIG = [
    [".d..dddd....",
     "ddf.ddddd...",
     "ddfbbbbbwkbb",
     "ddfbbbbbbbbb",
     "ddf.pppppp..",
     ".d..ddd....."],
    [".d..ddd..",
     "ddf.dd...",
     "ddfbbwkbb",
     "ddfbbbbbb",
     "ddf.ppp..",
     ".d..ddd.."],
]
FISH_MED = [
    [".d.dddd..",
     "ddfbbwkbb",
     "ddfppppbb",
     ".d.ddd..."],
    [".d.ddd..",
     "ddfbwkbb",
     "ddfpppbb",
     ".d.dd..."],
]
FISH_SMALL = [
    ["dfbbwkb",
     "dfppbbb"],
    ["dfbwkb",
     "dfpbbb"],
]

# --- what is left when the tank runs dry ------------------------------------
# Scenery above the waterline does not disappear, it dies: kelp and coral bleach
# out and any fish that no longer has water to swim in ends up as bones on the
# sand. Skeletons face right like the fish and share their row counts.

BONE = {"o": (226, 232, 240), "k": (28, 32, 44)}

SKEL_BIG = [
    ["o...........",
     ".o..o.o.o...",
     "..o.o.o.oooo",
     "..oooooooko.",
     ".o..o.o.oooo",
     "o..........."],
    ["o........",
     ".o..o.o..",
     "..o.o.ooo",
     "..oooooko",
     ".o..o.ooo",
     "o........"],
]
SKEL_MED = [
    ["o..o.o...",
     ".o.o.o.oo",
     ".ooooooko",
     "o..o.o.oo"],
    ["o..o.o..",
     ".o.o.ooo",
     ".oooooko",
     "o..o.ooo"],
]
SKEL_SMALL = [
    ["o.o.o.o",
     ".ooooko"],
    ["o.o.oo",
     ".oooko"],
]


def wither(colour):
    """Sun-bleached version of a colour: drained of hue and a shade darker."""
    lum = 0.30 * colour[0] + 0.56 * colour[1] + 0.14 * colour[2]
    return (int(lum * 0.72) + 26, int(lum * 0.70) + 24, int(lum * 0.64) + 22)


KELP_DEAD = [wither(colour) for colour in KELP_FG]


# 'c' is the coral's own colour, 'C' a lighter tip of it.
CORAL_SPRITES = [
    ["C...C",
     "c.C.c",
     ".ccc.",
     "..c..",
     "..c..",
     "..c.."],
    ["C.C.C.C",
     ".c.c.c.",
     "..ccc..",
     "...c..."],
    [".CCC.",
     "ccccc",
     "ccccc",
     ".c.c."],
]

# --- motion ---------------------------------------------------------------
WAVE_SPEED = 0.55        # radians per second
WAVE_LEN_A = 18.0        # columns per cycle, primary swell
WAVE_LEN_B = 7.0         # columns per cycle, chop
WAVE_AMP = 0.9           # rows, peak to centre
SWAY_SPEED = 0.35
BUBBLE_SPEED = 1.0       # rows per second
SEABED_ROWS = 1


M64 = 0xFFFFFFFFFFFFFFFF


def noise(*key):
    """Deterministic hash in [0, 1). Keeps scenery stable between frames.

    splitmix64's finalizer, because a plain FNV over two small integers barely
    moves the low bits and every threshold test then lands on the same side.
    """
    h = 0x9E3779B97F4A7C15
    for k in key:
        h = (h + (int(k) & M64) + 0x9E3779B97F4A7C15) & M64
        h = ((h ^ (h >> 30)) * 0xBF58476D1CE4E5B9) & M64
        h = ((h ^ (h >> 27)) * 0x94D049BB133111EB) & M64
        h ^= h >> 31
    return (h & 0xFFFFFFFF) / 4294967296.0


HEIGHT_FILE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                           "statusline-water-height")


def height_setting():
    """SL_WATER_HEIGHT wins, then whatever `/sl water <rows>` last stored."""
    raw = os.environ.get("SL_WATER_HEIGHT", "").strip().lower()
    if raw:
        return raw
    try:
        with open(HEIGHT_FILE) as fh:
            return fh.read().strip().lower()
    except OSError:
        return ""


PCT_FILE = os.path.join(os.path.dirname(HEIGHT_FILE), "statusline-water-pct")


def forced_pct():
    """Debug override from ~/.claude/statusline-water-pct.

    A number pins the tank at that context percentage; the word "partial" asks
    for whichever level leaves the tank half dead. Deleting the file goes back
    to the live number. It beats filling the real context window to see what a
    drained tank looks like.
    """
    try:
        with open(PCT_FILE) as fh:
            raw = fh.read().strip().lower()
    except OSError:
        return None
    if raw == "partial":
        return raw
    try:
        return max(0.0, min(100.0, float(raw)))
    except ValueError:
        return None


def panel_height(lines):
    raw = height_setting()
    if raw == "full":
        return max(6, lines - 4)
    if raw and raw != "auto":
        try:
            return max(3, min(int(raw), max(3, lines - 2)))
        except ValueError:
            pass
    return max(6, min(lines - 10, 28))


def wave_amp(base, floor_y):
    """Shallow water sloshes less, so a nearly drained tank stays flat."""
    return WAVE_AMP * max(0.0, min(1.0, (floor_y - base) / 3.0))


def surface_at(x, base, t, amp=WAVE_AMP):
    """Row index of the waterline in column x, as a float."""
    return (base
            + amp * math.sin(t * WAVE_SPEED + x * 2 * math.pi / WAVE_LEN_A)
            + amp * 0.35 * math.sin(t * WAVE_SPEED * 1.7
                                    - x * 2 * math.pi / WAVE_LEN_B))


def water_bg(y, surface, floor):
    """Depth shading from the surface down to the seabed."""
    span = max(1.0, floor - surface)
    return lerp_rgb(WATER_TOP, WATER_DEEP, (y - surface) / span)


def draw_sand(canvas, floor_y):
    """The seabed strip the scenery grows out of."""
    for y in range(floor_y, canvas.height):
        canvas.fill_row(y, SAND_BG, SAND_FG, "░")
    for x in range(canvas.width):
        if noise(x, 7) < 0.18:
            canvas.put(x, floor_y, "·", PEBBLE_FG, SAND_BG)


def all_wet(x, py):
    return True


def submerged_px(base, t, amp, floor_y):
    """Predicate in pixel rows: is this pixel below the waterline?

    Scenery above the line is still drawn, just dead: that is the whole joke of
    a tank that drains as the context fills.
    """
    def ok(x, py):
        surface = surface_at(x, base, t, amp)
        return surface < floor_y and py >= surface * 2 + 1
    return ok


def above(surface_py):
    """Same predicate for GIF mode, where the waterline is a flat pixel row."""
    def ok(x, py):
        return py >= surface_py
    return ok


def draw_kelp(px, t, floor_py, alive, tall=False):
    """Pixel seaweed: one-pixel stalks that bend more the further up they go.

    The dry part of a stalk barely moves and is bleached grey, so a half-drained
    tank gets kelp that sways below the waterline and stands stiff above it.
    """
    reach = 3.0 if tall else 1.8
    for x in range(px.width):
        if noise(x, 101) >= 0.12:
            continue
        stalk = (8 + int(noise(x, 202) * 13)) if tall else (4 + int(noise(x, 202) * 7))
        root = int(noise(x, 303) * 2)
        for i in range(stalk):
            y = floor_py - 1 - i
            if y < 0:
                break
            grow = i / max(1, stalk - 1)
            sway = math.sin(t * SWAY_SPEED + x * 0.55 + i * 0.3)
            bend = int(round(sway * grow ** 1.5 * reach))
            shade = min(len(KELP_FG) - 1, root + int(grow * 3))
            if not alive(x + bend, y):
                bend = int(round(bend * 0.2))
                shades = KELP_DEAD
            else:
                shades = KELP_FG
            px.set(x + bend, y, shades[shade])
            # A leaf every third pixel, on whichever side the stalk leans.
            if i % 3 == 1 and i < stalk - 2:
                leaf = x + bend + (1 if sway > 0 else -1)
                pot = KELP_FG if alive(leaf, y) else KELP_DEAD
                px.set(leaf, y, pot[min(len(pot) - 1, shade + 1)])


def draw_coral(px, floor_py, alive):
    for x in range(px.width):
        if noise(x, 404) >= 0.09:
            continue
        base = CORAL_FG[int(noise(x, 505) * len(CORAL_FG)) % len(CORAL_FG)]
        palette = {"c": base, "C": lerp_rgb(base, (255, 255, 255), 0.35)}
        bleached = {key: wither(col) for key, col in palette.items()}
        sprite = CORAL_SPRITES[int(noise(x, 606) * len(CORAL_SPRITES))
                               % len(CORAL_SPRITES)]
        x0 = x - max(len(line) for line in sprite) // 2
        y0 = floor_py - len(sprite)
        for dy, line in enumerate(sprite):
            for dx, key in enumerate(line):
                if key == ".":
                    continue
                pot = palette if alive(x0 + dx, y0 + dy) else bleached
                px.set(x0 + dx, y0 + dy, pot[key])


def draw_bubbles(canvas, t, base, floor_y, amp):
    width = canvas.width
    for lane in range(max(2, width // 14)):
        x = int(noise(lane, 11) * width)
        period = 6.0 + noise(lane, 12) * 7.0
        phase = noise(lane, 13) * period
        climbed = ((t + phase) % period) * BUBBLE_SPEED
        y = int(round(floor_y - 1 - climbed))
        if y < 0:
            continue
        if y <= surface_at(x, base, t, amp):
            continue
        drift = int(round(math.sin(t * 0.8 + lane) * 1.2))
        canvas.put(x + drift, y, "∘" if (lane % 2) else "·", BUBBLE_FG)


def draw_fish(px, t, floor_py, ceiling_at, big=False):
    """Swim pixel fish across the tank.

    `ceiling_at(x)` gives the highest pixel row a fish may reach in that column,
    which is the waterline in panel mode and the top of the panel in GIF mode.

    A fish whose sprite no longer fits between the waterline and the sand has
    run out of tank: it is drawn instead as a skeleton lying on the seabed, at a
    resting spot that depends only on which fish it is, so the bones stay put.
    Tall fish stop fitting first, so the big ones go belly-up before the tiddlers.
    """
    width = px.width
    shoal = (FISH_BIG + FISH_MED) if big else (FISH_MED + FISH_SMALL)
    graves = (SKEL_BIG + SKEL_MED) if big else (SKEL_MED + SKEL_SMALL)
    count = max(2, min(6 if big else 7, width // (26 if big else 20)))

    for i in range(count):
        pick = int(noise(i, 25) * len(shoal)) % len(shoal)
        sprite = shoal[pick]
        palette = FISH_PALETTES[int(noise(i, 24) * len(FISH_PALETTES))
                                % len(FISH_PALETTES)]
        rightward = noise(i, 23) < 0.5
        speed = 0.6 + noise(i, 22) * (1.8 if big else 1.5)
        depth = 0.15 + noise(i, 21) * 0.7
        span_w = max(len(line) for line in sprite)
        span_h = len(sprite)

        span = width + span_w * 2
        travel = (t * speed + noise(i, 26) * span) % span
        x0 = int(travel) - span_w if rightward else width - int(travel)

        ceiling = ceiling_at(max(0, min(width - 1, x0 + span_w // 2)))
        room = floor_py - 1 - span_h - ceiling
        if room <= 0:
            bones = graves[pick]
            # One lane each, so the bones do not pile up where two fish happen
            # to hash to the same spot.
            lane = width / count
            rest = int(i * lane + noise(i, 27) * max(1.0, lane - len(bones[0])))
            rest = max(0, min(rest, width - len(bones[0])))
            px.blit(rest, floor_py - len(bones), bones, BONE,
                    flip=not rightward)
            continue
        bob = math.sin(t * 0.55 + i * 1.3) * 1.4
        y0 = int(round(ceiling + depth * room + bob))
        y0 = max(int(math.ceil(ceiling)), min(y0, floor_py - 1 - span_h))

        px.blit(x0, y0, sprite, palette, flip=not rightward)


def scene(width, height, pct, t):
    canvas = Canvas(width, height)
    floor_y = max(1, height - SEABED_ROWS)

    # Water fills the tank from the bottom with the share of context still free.
    base = height * (pct / 100.0)
    base = max(0.0, min(float(height), base))

    amp = wave_amp(base, floor_y)
    for x in range(width):
        surface = surface_at(x, base, t, amp)
        if surface >= floor_y:      # this column is dry
            continue
        top = int(math.floor(surface))
        for y in range(max(0, top), floor_y):
            if y == top:
                ch = SURFACE_CHARS[(x + int(t)) % len(SURFACE_CHARS)]
                canvas.put(x, y, ch, SURFACE_FOAM, water_bg(y, surface, floor_y))
            else:
                canvas.put(x, y, " ", None, water_bg(y, surface, floor_y))

    draw_sand(canvas, floor_y)
    if base < floor_y:
        draw_bubbles(canvas, t, base, floor_y, amp)

    px = Pixels(width, height)
    alive = submerged_px(base, t, amp, floor_y)
    draw_kelp(px, t, floor_y * 2, alive)
    draw_coral(px, floor_y * 2, alive)
    draw_fish(px, t, floor_y * 2,
              lambda x: (surface_at(x, base, t, amp) + 0.5) * 2)
    px.flush(canvas)

    return canvas


def plain(width, height, pct):
    """No-truecolor fallback: a simple filled tank."""
    rows = []
    base = int(round(height * (pct / 100.0)))
    for y in range(height):
        rows.append(c(DIM, " " * width) if y < base
                    else c(31, "~" * width if y == base else "≈" * width))
    return rows


def info_row(d, pct):
    seg = []
    left = 100 - pct
    seg.append(c(45, f"~ {left:.0f}% water") if left >= 1 else c(244, "- bone dry"))
    seg.append(c(DIM, f"ctx {pct:.0f}%"))

    cwd = dig(d, "workspace", "current_dir") or d.get("cwd") or os.getcwd()
    seg.append(c(80, short_path(cwd, 34)))

    branch = dig(d, "worktree", "branch") or git_branch(cwd)
    if branch:
        seg.append(c(252, branch))

    model = dig(d, "model", "display_name") or dig(d, "model", "id")
    if model:
        seg.append(c(110, model))

    cost = dig(d, "cost", "total_cost_usd")
    if cost is not None:
        seg.append(c(215, money(cost)))

    seg.extend(budget_seg())
    return c(DIM, "  ·  ").join(seg)


def budget_seg():
    """This week's gateway spend against the budget, as a one-element list.

    `weekly_spend` is cached and refreshed out of band, so an empty list just
    means the first refresh has not landed yet — never a stall in the status line.
    """
    week = weekly_spend()
    if not week:
        return []
    spend, budget = week
    if budget <= 0:
        return []
    frac = spend / budget
    tone = 114 if frac < 0.6 else 215 if frac < 0.85 else 203
    return [c(tone, f"wk ${spend:,.0f}/${budget:,.0f}")
            + c(DIM, f" {frac * 100:.0f}%")]


# --- full-screen mode ------------------------------------------------------
# When the Windows Terminal background GIF is in play the water is already being
# drawn behind the whole window, so the panel stops painting its own and becomes
# a transparent overlay of scenery only.

CLAUDE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APPLIED_FILE = os.path.join(CLAUDE_DIR, "statusline-wt-applied")
BG_SCRIPT = os.path.join(CLAUDE_DIR, "sl-water-bg.py")

def gif_mode():
    return os.path.exists(APPLIED_FILE)


SUB_PASS = watergif.SUB_LOOP_CS / 100.0     # seconds one submarine pass lasts
SUB_MEAN_GAP = 360.0                        # average seconds between passes


def applied_state():
    """(band, variant) the background is currently pointed at, or (None, "")."""
    try:
        with open(APPLIED_FILE) as fh:
            parts = fh.read().split()
        return int(parts[0]), ("sub" if "sub" in parts[1:] else "")
    except (OSError, ValueError, IndexError):
        return None, ""


def applied_band():
    return applied_state()[0]


def applied_at():
    try:
        return os.path.getmtime(APPLIED_FILE)
    except OSError:
        return None


def sub_due(now, band):
    """Is a submarine passing right now?

    Time is cut into slots exactly one pass long and each slot draws a lottery.
    Every refresh inside a slot therefore agrees on the answer without anything
    being remembered between them, which matters because the status line is a
    fresh process every second — and because the slot and the GIF's loop are the
    same length, the pass ends where it began, with an empty sea.

    Only the shallower bands are in it: deeper than that and the waterline is
    already below where the submarine would swim.
    """
    return (watergif.sub_fits(band)
            and noise(int(now // SUB_PASS), 4242) < SUB_PASS / SUB_MEAN_GAP)


def sync_band(pct):
    """Re-point the terminal background: the 10% band, and any passing submarine.

    Detached and fire-and-forget: rewriting Windows Terminal's settings makes it
    reload, which is far too slow to sit in the status line's critical path.
    """
    now = time.time()
    band = max(0, min(100, int(round(pct / 10.0)) * 10))
    have_band, have_variant = applied_state()
    since = applied_at()
    want = "sub" if sub_due(now, band) else ""

    # A pass already in flight plays out, even if the band moved under it: eight
    # seconds of a slightly stale waterline beats a submarine cut in half. This
    # is also what keeps a hand-fired `sl-water-bg.py sub` on screen.
    if have_variant == "sub" and since is not None and now - since < SUB_PASS:
        return band
    # One pass per slot. Without this the rest of a slot would re-fire the pass
    # the moment it finished — and it also covers a missing sub variant, where
    # asking for one gets the plain sea written back instead.
    if since is not None and int(since // SUB_PASS) == int(now // SUB_PASS):
        want = ""

    if (have_band, have_variant) == (band, want):
        return band

    args = [sys.executable, BG_SCRIPT, "apply", str(band)] + ([want] if want else [])
    try:
        with open(os.devnull, "wb") as null:
            subprocess.Popen(args, stdout=null, stderr=null, stdin=null,
                             start_new_session=True)
    except Exception:
        pass
    return band


def gif_surface(band, lines, height):
    """Where the background GIF's waterline falls inside the panel, in rows.

    The GIF is stretched over the whole window and its water starts `band`% down,
    so with the panel sitting on the last `height + 2` rows (info row and the
    mode hint below it) the waterline only reaches the scenery near the end of
    the context window. Negative means the panel is fully submerged.
    """
    return lines * band / 100.0 - (lines - height - 2)


def half_dead_band(lines, height):
    """The 10% band that catches the tank mid-die-off, for the debug override.

    Wanted: a waterline inside the panel, at least one fish still swimming and
    at least one already on the sand. Short panels have no such band — the fish
    sizes are too close together — so the fallback is whichever band drops the
    waterline nearest two thirds of the way down, which at least leaves the kelp
    dead on top and alive at the roots.
    """
    floor_py = max(1, height - SEABED_ROWS) * 2
    fallback, miss = 80, None
    for band in range(0, 101, 10):
        surf = gif_surface(band, lines, height)
        if not 0 < surf < height:
            continue
        rooms = [floor_py - 1 - len(sprite) - surf * 2
                 for sprite in FISH_BIG + FISH_MED]
        if any(r > 0 for r in rooms) and any(r <= 0 for r in rooms):
            return band
        off = abs(surf - height * 0.66)
        if miss is None or off < miss:
            fallback, miss = band, off
    return fallback


def overlay(width, height, t, surface_row):
    """Scenery only: no background colours, so the GIF shows through."""
    canvas = Canvas(width, height)
    floor_y = max(1, height - SEABED_ROWS)

    for x in range(width):
        canvas.put(x, floor_y, "░" if noise(x, 7) >= 0.18 else "·",
                   SAND_FG if noise(x, 7) >= 0.18 else PEBBLE_FG)

    draw_bubbles(canvas, t, surface_row, floor_y, 0.0)

    px = Pixels(width, height)
    alive = all_wet if surface_row <= 0 else above(surface_row * 2)
    draw_kelp(px, t, floor_y * 2, alive, tall=True)
    draw_coral(px, floor_y * 2, alive)
    draw_fish(px, t, floor_y * 2, lambda x: max(0.0, surface_row * 2), big=True)
    px.flush(canvas)
    return canvas


def render(d):
    cols, lines = term_size()
    width = max(20, cols - env_int("STATUSLINE_RULE_PAD", 2))

    pct = dig(d, "context_window", "used_percentage")
    pct = 0.0 if pct is None else max(0.0, min(100.0, float(pct)))
    t = time.time()

    override = forced_pct()
    if isinstance(override, float):
        pct = override

    if gif_mode():
        # The GIF already covers the whole window, so the panel only needs to be
        # the seabed strip. A full-height overlay just scatters the scenery.
        raw = height_setting()
        height = (panel_height(lines) if raw and raw != "auto"
                  else max(7, min(12, lines // 3)))
        if override == "partial":
            pct = float(half_dead_band(lines, height))
        band = sync_band(pct)
        if not truecolor():
            return [info_row(d, pct)]
        surface_row = gif_surface(band, lines, height)
        return overlay(width, height, t, surface_row).rows() + [info_row(d, pct)]

    height = panel_height(lines)
    if override == "partial":
        pct = 80.0          # panel mode: waterline down among the scenery
    if not truecolor():
        return plain(width, height, pct) + [info_row(d, pct)]

    return scene(width, height, pct, t).rows() + [info_row(d, pct)]
