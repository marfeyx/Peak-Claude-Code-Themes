"""The "kyoto" theme: a quiet spring valley, and a status line that stays out of it.

A companion to the Vice City theme rather than a variant of it. That one is a
clock and an alarm — the sky tracks the hour and your context window is a
wanted level with a police helicopter attached. This one deliberately does
none of that. The light never changes, nothing flashes, nothing escalates, and
the context meter is a branch quietly coming into blossom rather than a siren.

In Windows Terminal the whole window becomes the valley: hills, a pagoda, a
torii at the water's edge, a waterfall off the ledge on the right, and the
river across the foreground, all in one long looping GIF. Because the light is
fixed there is only ever one band to render and one file to point at, and the
status line itself stays out of the way: with the background up it is two rows
of text and nothing else. Only when there is no background image — no Windows
Terminal — does the panel draw the valley itself, so the theme still has
something to show.

Sizing: SL_KYOTO_HEIGHT, else whatever `/sl kyoto <rows>` stored, else auto.
Debug: SL_KYOTO_PIXELS=half drops back to half-block resolution.
"""

import math
import os
import re
import time

import kyotogif as art
from common import (Canvas, DIM, OctantPixels, Pixels, c, dig, env_int,
                    git_branch, human_duration, money, rgb, short_path,
                    term_size, truecolor, weekly_spend)

DESCRIPTION = "a calm Kyoto valley: sakura, a waterfall and a slow river"

CLAUDE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HEIGHT_FILE = os.path.join(CLAUDE_DIR, "statusline-water-height")
APPLIED_FILE = os.path.join(CLAUDE_DIR, "statusline-wt-applied")
BG_SCRIPT = os.path.join(CLAUDE_DIR, "sl-water-bg.py")

# The background image's opacity lives in SETS["kyoto"] in sl-water-bg.py.
# Nothing here is drawn over it, so this theme has no wash to match.

# --- HUD palette: ink, moss, blossom ----------------------------------------
INK = (214, 220, 228)
BLOSSOM = (244, 172, 196)
MOSS = (142, 178, 118)
INDIGO = (146, 166, 214)
GOLD = (224, 190, 124)
STONE = (150, 150, 158)



class QuantOctants(OctantPixels):
    """Octant layer with the same 5-bit colour snap as the vice theme.

    A cell carries two colours, so the packer runs an exhaustive best-pair
    search over the distinct colours in it; snapping collapses most cells to
    one or two and keeps that search off the critical path.
    """

    def set(self, x, y, colour):
        if colour is not None:
            colour = (colour[0] & 0xF8, colour[1] & 0xF8, colour[2] & 0xF8)
        OctantPixels.set(self, x, y, colour)


def make_layer(cols, rows):
    if os.environ.get("SL_KYOTO_PIXELS", "").strip().lower() == "half":
        return Pixels(cols, rows)
    return QuantOctants(cols, rows)


# --- configuration ----------------------------------------------------------
def height_setting():
    raw = os.environ.get("SL_KYOTO_HEIGHT", "").strip().lower()
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
    return max(4, min(lines - 9, 18))


# --- the Windows Terminal background ----------------------------------------
def gif_mode():
    try:
        with open(APPLIED_FILE) as fh:
            return "kyoto" in fh.read().split()
    except OSError:
        return False


# There is only ever one band, so nothing here has to chase the clock the way
# the Vice City theme does; `/sl kyoto` applies the background once.


# --- scenery ----------------------------------------------------------------
def draw_petals(px, width, height, t, count, crowns, top_frac=0.45):
    """Blossom coming off the crowns, drifting down and to the left."""
    for i in range(count):
        tree = crowns[int(art.noise(i, 98) * len(crowns)) % len(crowns)]
        top = height * (top_frac + (art.noise(i, 99) - 0.5) * 0.10)
        span = max(1, height - top)
        fall = (art.noise(i, 91) + t * (0.020 + 0.012 * art.noise(i, 95))) % 1.0
        y = int(top + fall * span)
        sway = math.sin(t * (0.25 + 0.15 * art.noise(i, 96)) + art.noise(i, 92) * 6.28)
        x = int(tree * width + (art.noise(i, 93) - 0.5) * width * 0.05
                - fall * width * 0.055 + sway * width * 0.012)
        if not (0 <= x < width and 0 <= y < height):
            continue
        px.set(x, y, art.PETAL if art.noise(i, 97) > 0.4 else art.SAKURA_LIGHT)


def scene(cols, rows, t):
    """The whole valley in the panel, for terminals with no background image."""
    px = make_layer(cols, rows)
    width, height = px.width, px.height
    horizon = int(height * 0.34)
    water_top = int(height * 0.62)
    bank_top = int(height * 0.84)

    # Fill all the way down to the waterline, not just to the horizon: the
    # ridges dip below it in places and anything the hills do not cover would
    # otherwise be left transparent, showing as black bands across the valley.
    for y in range(water_top):
        f = min(1.0, y / max(1, horizon - 1)) ** 0.9
        col = art.mix(art.SKY_TOP, art.SKY_LOW, f)
        for x in range(width):
            px.set(x, y, col)

    for layer, (base, amp, colour, seed) in enumerate((
            (horizon * 1.20, height * 0.10, art.FAR_HILL, 1.7),
            (horizon * 1.55, height * 0.09, art.MID_HILL, 4.3),
            (horizon * 1.95, height * 0.07, art.FOREST, 8.1))):
        for x in range(width):
            n = (math.sin(x * 0.026 + seed) * 0.5
                 + math.sin(x * 0.070 + seed * 2.1) * 0.3
                 + math.sin(x * 0.135 + seed * 3.7) * 0.2)
            top = int(base - (n + 1.0) * 0.5 * amp)
            for y in range(max(0, top), water_top):
                px.set(x, y, colour)
            px.set(x, top, art.shade(colour, 1.14))

    for y in range(water_top, bank_top):
        f = (y - water_top) / max(1, bank_top - water_top)
        base = art.mix(art.WATER_FAR, art.WATER_NEAR, f)
        for x in range(width):
            n = art.noise(int((x + t * 6) % 40), y, 81)
            px.set(x, y, art.mix(base, art.FOAM, 0.5) if n > 0.982 else base)

    for y in range(bank_top, height):
        f = (y - bank_top) / max(1, height - bank_top)
        for x in range(width):
            n = art.noise(x // 2, y // 2, 41)
            tone = art.mix(art.GRASS_DARK, art.GRASS, 0.35 + 0.5 * n + 0.25 * f)
            if n > 0.94:
                tone = art.mix(tone, art.SAKURA_LIGHT, 0.4)
            px.set(x, y, tone)

    unit = max(1, height // 22)
    for i, frac in enumerate((0.10, 0.30, 0.52, 0.76, 0.93)):
        sway = math.sin(t * 0.22 + i) * 0.8
        bx = int(frac * width + sway)
        trunk_h = int(unit * (3.0 + art.noise(i, 2) * 1.6))
        for k in range(trunk_h):
            px.set(bx, water_top - 1 - k, art.TRUNK)
        r = max(2, int(unit * (1.5 + art.noise(i, 3) * 0.8)))
        cy = water_top - trunk_h - r // 2
        for dy in range(-r, r + 1):
            for dx in range(-r * 2, r * 2 + 1):
                if math.hypot(dx * 0.5, dy) > r:
                    continue
                up = 0.5 - dy / max(1, r) * 0.5
                px.set(bx + dx, cy + dy,
                       art.mix(art.SAKURA_DARK, art.SAKURA_LIGHT,
                               up + 0.3 * art.noise(i, bx + dx, cy + dy)))

    tw = max(1, height // 30)
    tx, ty = int(width * 0.80), water_top - 1
    for side in (-1, 1):
        for k in range(tw * 6):
            px.set(tx + side * tw * 4, ty - k, art.VERMILLION)
    for dx in range(-tw * 6, tw * 6 + 1):
        lift = int((abs(dx) / (tw * 6.0)) ** 2 * tw * 1.5)
        px.set(tx + dx, ty - tw * 6 - lift, art.VERMILLION)
    for dx in range(-tw * 5, tw * 5 + 1):
        px.set(tx + dx, ty - int(tw * 4.4), art.VERMILLION_DARK)

    draw_petals(px, width, height, t, max(12, width // 12),
                crowns=(0.10, 0.30, 0.52, 0.76, 0.93), top_frac=0.42)

    canvas = Canvas(width // px.ppc, rows)
    px.flush(canvas)
    return canvas


# --- HUD --------------------------------------------------------------------
ANSI = re.compile(r"\033\[[0-9;]*m")


def vislen(s):
    return len(ANSI.sub("", s))


def paint(colour, code, s):
    return rgb(*colour, s) if truecolor() else c(code, s)


def sep():
    return paint((96, 108, 120), DIM, "   ·   ")


def join_fit(segments, width):
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


def blossom_meter(pct, cells=12):
    """Context as a branch coming into blossom, not as an alarm.

    Deliberately unlike the wanted level in the Vice City theme: it fills, the
    colour warms a little, and that is all it ever does.
    """
    pct = max(0.0, min(100.0, float(pct or 0.0)))
    filled = int(round(pct / 100 * cells))
    if truecolor():
        tone = art.mix(BLOSSOM, GOLD, pct / 100.0)
        return (paint((120, 128, 140), DIM, "ctx ")
                + paint(tone, 218, "❀" * filled)
                + paint((66, 74, 84), 237, "·" * (cells - filled))
                + paint(tone, 218, " %.0f%%" % pct))
    sev = 71 if pct < 50 else (179 if pct < 75 else 167)
    return (c(DIM, "ctx ") + c(sev, "*" * filled)
            + c(237, "." * (cells - filled)) + c(sev, " %.0f%%" % pct))


def hud(d, pct, width):
    rows = []
    seg = [paint(BLOSSOM, 218, time.strftime("%H:%M"))]

    cwd = dig(d, "workspace", "current_dir") or d.get("cwd") or os.getcwd()
    seg.append(paint(MOSS, 108, short_path(cwd, budget=34)))
    branch = dig(d, "worktree", "branch") or git_branch(cwd)
    if branch:
        seg.append(paint(INDIGO, 110, branch))

    added = dig(d, "cost", "total_lines_added", default=0) or 0
    removed = dig(d, "cost", "total_lines_removed", default=0) or 0
    if added or removed:
        seg.append(paint(MOSS, 71, "+%d" % added) + c(DIM, "/")
                   + paint((214, 140, 140), 167, "-%d" % removed))
    rows.append(join_fit(seg, width))

    seg = [blossom_meter(pct)]
    cost = dig(d, "cost", "total_cost_usd")
    if cost is not None:
        seg.append(paint(GOLD, 179, money(cost)))
    wk = weekly_spend()
    if wk:
        spend, budget = wk
        share = (spend / budget * 100) if budget else 0.0
        seg.append(paint(GOLD, 179, money(spend)) + c(DIM, " / ")
                   + paint(STONE, 244, money(budget))
                   + c(DIM, " · ") + paint(GOLD, 179, "%.1f%%" % share))

    model = dig(d, "model", "display_name") or dig(d, "model", "id") or ""
    if model:
        size = dig(d, "context_window", "context_window_size", default=0) or 0
        if size >= 1_000_000 and "1M" not in model:
            model = "%s (1M)" % model
        seg.append(paint(INK, 252, model))

    effort = dig(d, "effort", "level")
    bits = []
    if d.get("fast_mode"):
        bits.append("fast")
    if effort:
        bits.append("%s effort" % effort)
    if bits:
        seg.append(c(DIM, " · ").join(paint(INDIGO, 110, b) for b in bits))

    agent = dig(d, "agent", "name")
    if agent:
        seg.append(paint(INDIGO, 140, "agent: %s" % agent))

    pr = dig(d, "pr", "number")
    if pr:
        kind = "MR" if dig(d, "pr", "kind") == "mr" else "PR"
        label = "%s !%d" % (kind, pr) if kind == "MR" else "%s #%d" % (kind, pr)
        state = dig(d, "pr", "review_state") or ""
        colour = {"approved": MOSS, "changes_requested": (214, 140, 140),
                  "draft": STONE}.get(state, GOLD)
        seg.append(paint(colour, 179, label))

    dur = dig(d, "cost", "total_duration_ms")
    if dur:
        seg.append(paint(STONE, 244, human_duration(dur)))

    rows.append(join_fit(seg, width))
    return rows


def plain(width):
    return [c(72, "─" * width)]


def render(d):
    cols, lines = term_size()
    width = max(24, cols - env_int("STATUSLINE_RULE_PAD", 2))
    t = time.time()

    pct = dig(d, "context_window", "used_percentage")
    pct = 0.0 if pct is None else max(0.0, min(100.0, float(pct)))

    if not truecolor():
        return plain(width) + hud(d, pct, width)

    if gif_mode():
        # The valley already fills the window; a strip of scenery under the
        # prompt would only be a second, smaller foreground in front of it.
        return hud(d, pct, width)

    # Without a background image there is nothing behind the terminal, so the
    # panel draws the valley itself.
    return scene(width, panel_height(lines), t).rows() + hud(d, pct, width)
