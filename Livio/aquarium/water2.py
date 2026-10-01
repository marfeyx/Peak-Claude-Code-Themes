"""The "water2" theme: the aquarium of `water`, at double pixel resolution.

Same tank, same physics, same waterline-tracks-context joke — `water2` imports
all of that from `water` rather than restating it. What differs is the pixel
layer underneath the scenery: `OctantPixels` splits each cell 2x4 instead of the
half-block 1x2, so a pixel is half as wide and half as tall and the sprites get
twice the linear resolution in the same physical space. The sprites here are
redrawn at that size with shading and highlights, because merely scaling the old
ones up 2x would cost the quantiser something and give back nothing.

The trade is colour: a cell still holds two colours, so eight subpixels have to
share them. Sprite interiors are unaffected — they are broad bands of one or two
tones — but silhouette cells, where outline and body meet open water, have to
give up either the second colour or the cutout. `OctantPixels` picks per cell.

Fish swim in whole-cell steps, and are snapped to the cell grid for it. Half-cell
steps look smoother in principle, but they land the sprite on a different
sub-cell phase every frame, and since the eight subpixels of a cell have to share
two colours, a re-phased sprite is a re-quantised one: the fish changes slightly
every frame and details the size of an eye come and go. Snapped, it is the same
fish wherever it swims.

REQUIRES a font with Unicode 16 octants (Symbols for Legacy Computing
Supplement). CaskaydiaMono NF has them; Cascadia Mono and Ubuntu Mono do not,
and this theme will render as tofu boxes in those. `/sl water` goes back.
"""

import collections
import math
import os
import time

import water
from common import Canvas, OctantPixels, lerp_rgb, term_size, env_int, truecolor

DESCRIPTION = "aquarium at 2x pixel resolution (needs an octant-capable font)"

# --- palettes ---------------------------------------------------------------
# Two keys on top of what `water` uses: 's' a mid shade for the dorsal banding
# and 'h' a highlight along the flank. At 1x there was no room for either.

FISH_PALETTES = [dict(scheme,
                      f=lerp_rgb(scheme["d"], scheme["b"], 0.50),
                      s=lerp_rgb(scheme["d"], scheme["b"], 0.75),
                      h=lerp_rgb(scheme["b"], (255, 255, 255), 0.42),
                      **water.EYE)
                 for scheme in water.FISH_SCHEMES]

# --- sprites ----------------------------------------------------------------
# Keys as in `water` (d back/outline, b body, p belly, f fin membrane, w/k eye)
# plus s mid-shade and h highlight. Every sprite faces right and every row in a
# sprite is the same length, which `blit(flip=True)` relies on to mirror cleanly.

FISH_BIG = [
    ["d..........dddd.........",
     "dd........ddffdd........",
     "dfd......ddffffdd.......",
     "dffd....ddssssssssdd....",
     "dfffd..dsbbbbbbbbbbbbsd.",
     "dffffddsbbbbbhhbbbbbwkbd",
     "dffffddsbbbbhhbbbbbbkkbd",
     "dfffd..dsbbbbbbbbbbbbpd.",
     "dffd....ddpppppppppdd...",
     "dfd......ddpffppfpdd....",
     "dd........ddffdd........",
     "d..........dddd........."],
    ["d.......ddd.......",
     "dd.....dfffd......",
     "dfd...ddsssssdd...",
     "dffd..dsbbbbbbbbdd",
     "dfffddsbbbbbbbbbbd",
     "dfffddsbbbhbbbwkbd",
     "dfffddsbbbhbbbkkbd",
     "dfffddsbbbbbbbbbbd",
     "dffd..dsppppppppdd",
     "dfd...ddpppppdd...",
     "dd.....dfffd......",
     "d.......ddd......."],
]

FISH_MED = [
    ["d.......ddd.......",
     "dd.....dfffdd.....",
     "dfd...ddsssssssdd.",
     "dffd.dsbbbbhbbwkbd",
     "dffd.dsbbbbbhbkkbd",
     "dfd...ddpppppppdd.",
     "dd.....dfffdd.....",
     "d.......ddd......."],
    ["d.....ddd.....",
     "dd...dfffd....",
     "dfd..ddssssdd.",
     "dffd.dsbbbwkbd",
     "dffd.dsbbbkkbd",
     "dfd..ddppppdd.",
     "dd...dfffd....",
     "d.....ddd....."],
]

FISH_SMALL = [
    ["d...ddssssdd..",
     "dd.dsbbbbbwkbd",
     "dd.dsbbbbbkkbd",
     "d...ddppppdd.."],
    ["d..ddsssdd..",
     "dd.dsbbbwkbd",
     "dd.dsbbbkkbd",
     "d..ddpppdd.."],
]

SKEL_BIG = [
    ["o.......................",
     ".o......................",
     "..o.....o...o...o.......",
     "...o....o...o...o.oooo..",
     "....o...o...o...o.o..oo.",
     "ooooooooooooooooooook.o.",
     "ooooooooooooooooooook.o.",
     "....o...o...o...o.o..oo.",
     "...o....o...o...o.oooo..",
     "..o.....o...o...o.......",
     ".o......................",
     "o......................."],
    ["o.................",
     ".o................",
     "..o...o...o.......",
     "...o..o...o.oooo..",
     "....o.o...o.o..oo.",
     "oooooooooooook.o..",
     "oooooooooooook.o..",
     "....o.o...o.o..oo.",
     "...o..o...o.oooo..",
     "..o...o...o.......",
     ".o................",
     "o................."],
]

SKEL_MED = [
    ["o.................",
     ".o....o...o.......",
     "..o...o...o.oooo..",
     "oooooooooooooko.o.",
     "oooooooooooooko.o.",
     "..o...o...o.oooo..",
     ".o....o...o.......",
     "o................."],
    ["o.............",
     ".o...o...o....",
     "..o..o...o.ooo",
     "ooooooooooko.o",
     "ooooooooooko.o",
     "..o..o...o.ooo",
     ".o...o...o....",
     "o............."],
]

SKEL_SMALL = [
    ["o...o...o.....",
     "ooooooooooko.o",
     "ooooooooooko.o",
     "o...o...o....."],
    ["o...o...o...",
     "oooooooko.o.",
     "oooooooko.o.",
     "o...o...o..."],
]

# --- named species ----------------------------------------------------------
# The generic shoal above takes a random colour scheme per fish, which is fine
# for anonymous background fish but wrong for anything recognisable: a koi that
# came out cyan, or a clownfish that came out violet, is not that animal any
# more. These three carry their own palette instead, and their own key sets —
# 'W' body white against 'w' eye white, and so on.

KOI = [
    "d.........ddddd.........",
    "dd.......ddfffdd........",
    "dfd.....ddfffffdd.......",
    "dffd...ddWWWWOOOOWWdd...",
    "dfffd.dlWWWoOOOOoWWWWWd.",
    "dffffddlWWoooOOooWWWwkWd",
    "dffffddlWWWooooooWWWkkWd",
    "dfffd.dllWWWoooWWWWlllWd",
    "dffd...ddlllWWlllllddd..",
    "dfd.....ddlffllfldd.....",
    "dd.......ddfffdd........",
    "d.........ddddd.........",
]

KOI_PALETTE = dict(water.EYE,
                   d=(96, 74, 74),        # warm dark edge, not a black outline
                   f=(236, 232, 236),     # fin membrane
                   W=(247, 246, 244),     # body white
                   l=(206, 204, 208),     # white turned away from the light
                   o=(234, 106, 38),      # kohaku patch
                   O=(250, 152, 74))      # lit edge of a patch

KOI_SKEL = [
    "o.......................",
    ".o.....o...o...o........",
    "..o....o...o...o........",
    "...o...o...o...o..oooo..",
    "....o..o...o...o.oo..ooo",
    "ooooooooooooooooooook..o",
    "ooooooooooooooooooook..o",
    "....o..o...o...o.oo..ooo",
    "...o...o...o...o..oooo..",
    "..o....o...o...o........",
    ".o.....o...o...o........",
    "o.......................",
]

# Three bands, black-edged, held at the same columns in every body row so they
# read as bands rather than as speckle.
NEMO = [
    "d.......ddd.......",
    "dd.....dfffdd.....",
    "dfd..dWWdbbdWWbbdd",
    "dffd.sWWdbhdWWbwkd",
    "dffd.sWWdbbdWWbkkd",
    "dfd..dWWdssdWWlldd",
    "dd.....dfffdd.....",
    "d.......ddd.......",
]

NEMO_PALETTE = dict(water.EYE,
                    d=(32, 24, 22),       # the black edging does the work here
                    f=(246, 170, 110),
                    b=(245, 126, 32),
                    h=(252, 172, 92),
                    s=(198, 92, 22),
                    W=(250, 250, 246),
                    l=(208, 208, 210))

NEMO_SKEL = [
    "o.................",
    ".o..o..o..o.......",
    "..o.o..o..o.oooo..",
    "ooooooooooooooko.o",
    "ooooooooooooooko.o",
    "..o.o..o..o.oooo..",
    ".o..o..o..o.......",
    "o.................",
]

JELLY = [
    "....BBBBBB....",
    "..BBggggggBB..",
    ".BggggggggggB.",
    "BgggbbggbbgggB",
    "BggbbbggbbbggB",
    "BbbbbbbbbbbbbB",
    "sbbbbbbbbbbbbs",
    ".ssbbbbbbbbss.",
    "..tt.tt.tt.tt.",
    "..tt.tt.tt.tt.",
    ".tt..tt.tt..tt",
    ".TT..TT.TT..TT",
]

JELLY_PALETTE = {"B": (214, 234, 255),    # lit rim of the bell
                 "g": (240, 248, 255),    # the translucent part you see through
                 "b": (156, 190, 238),
                 "s": (104, 138, 200),
                 "t": (176, 204, 242),
                 "T": (226, 240, 255)}

# A jellyfish has nothing to leave a skeleton with, so what it leaves is a dried
# membrane: flatter than a fish's bones and only four pixel rows tall, which puts
# it lying on the sand rather than standing in it. Drawn in BONE like the rest.
JELLY_SKEL = [
    "...oooooooo...",
    ".oooooooooooo.",
    "oookooookooooo",
    ".oo.oo..oo.oo.",
]

# The other jellyfish: a lion's mane. Narrower bell, and where the moon jelly
# has a fringe of stubby oral arms this one trails tentacles for twice its own
# height, which is what makes the two read as different animals at a glance
# rather than as the same one recoloured.
MANE = [
    "....BBBB....",
    "..BBggggBB..",
    ".BggggggggB.",
    "BggggggggggB",
    "BgbggbbggbgB",
    "BbbbbbbbbbbB",
    "sbbbbbbbbbbs",
    ".t.t..t.t.t.",
    ".t.t..t.t.t.",
    ".t.t..t.t.t.",
    ".t..t.t..tt.",
    "t...t.t..t.t",
    "t...tt...T.t",
    "t...Tt.....t",
    "t....t.....T",
    "T....T......",
]

MANE_PALETTE = {"B": (246, 205, 255),     # lit rim of the bell
                "g": (252, 235, 255),     # the translucent part you see through
                "b": (206, 142, 235),
                "s": (146, 92, 186),
                "t": (226, 160, 236),     # tentacle
                "T": (252, 226, 255)}     # and the stinging tip of one

MANE_SKEL = [
    "...oooooo...",
    ".oooooooooo.",
    "oookooookooo",
    "..o.o.oo.o..",
]

Species = collections.namedtuple("Species", "sprite bones palette speed bubbles alt",
                                 defaults=(None, 1.0, True, None))

# Pairing each sprite with its bones in one record rather than in two parallel
# lists indexed by the same number: the old arrangement was one insertion away
# from a fish dying into somebody else's skeleton.
KOI_S = Species(KOI, KOI_SKEL, KOI_PALETTE, 0.8)
NEMO_S = Species(NEMO, NEMO_SKEL, NEMO_PALETTE, 1.15)

# The two jellyfish share one place in the pool and take turns at it, rather
# than each taking a place of their own. The pool is dealt round-robin and a
# tank only has room for three or four, so a fifth entry would simply never come
# up at most widths — and two jellyfish out of four would be a lot of jellyfish.
# `alt` must drift at the same speed, because the hand-over happens at a lap
# boundary computed from it.
MANE_S = Species(MANE, MANE_SKEL, MANE_PALETTE, 0.4, bubbles=False)
JELLY_S = Species(JELLY, JELLY_SKEL, JELLY_PALETTE, 0.4, bubbles=False,
                  alt=MANE_S)

GENERIC_BIG = [Species(FISH_BIG[0], SKEL_BIG[0]),
               Species(FISH_BIG[1], SKEL_BIG[1])]
GENERIC_MED = [Species(FISH_MED[0], SKEL_MED[0]),
               Species(FISH_MED[1], SKEL_MED[1])]
GENERIC_SMALL = [Species(FISH_SMALL[0], SKEL_SMALL[0]),
                 Species(FISH_SMALL[1], SKEL_SMALL[1])]

# Dealt round-robin rather than hashed per slot. The hash is deterministic, so
# "which species you get" was not luck that varies — it was fixed, and it landed
# on generic fish for every slot a tank under 120 columns has room for, which
# made the named species unreachable at most widths. Dealing in order also means
# no duplicates until the pool is exhausted.
BIG_POOL = [KOI_S, NEMO_S, JELLY_S] + GENERIC_BIG + GENERIC_MED
SMALL_POOL = [NEMO_S, JELLY_S] + GENERIC_MED + GENERIC_SMALL

# Coral keys are their own small ramp rather than the fish's: 'H' a lit crown,
# 'C' the lit face, 'c' the body, 's' a face turned away. Light comes from above
# — it is the surface — so every sprite is bright on top and shadowed where it
# meets the sand, and nothing is thinner than two pixels. A one-pixel feature is
# half a cell wide, which the two-colour quantiser can only render by guessing,
# and a whole colony of those guesses is what made the first set look like noise.

CORAL_SPRITES = [
    # staghorn: branches forking off a shadowed trunk
    ["...HH..HH...",
     "..CccC.CccC.",
     "..Cccs.Cccs.",
     "..Cccs.Cccs.",
     "...CccsCccs.",
     "....CcccCcs.",
     "HH..Ccccccs.",
     "CccC.Cccccs.",
     "Cccs..Cccccs",
     ".Cccs.Ccccs.",
     "..CcccCcccs.",
     "...Cccccccs.",
     "..sCcccccccs",
     ".ssccccccsss"],
    # sea fan: two slits so it reads as a fan rather than a paddle
    ["....HHHHHHHH....",
     "..CCccccccccCC..",
     ".Cccc.cccc.cccC.",
     "Ccccc.cccc.ccccs",
     "Ccccc.cccc.ccccs",
     "Ccccc.cccc.ccccs",
     ".Cccc.cccc.cccs.",
     "..Ccc.cccc.ccs..",
     "...Cccccccccs...",
     "....Cccccccs....",
     ".......Ccs......",
     ".......scs......"],
    # brain: diagonal grooves, which is the only thing that sells a solid mound
    ["....HHHHHH....",
     "..CCcccccccC..",
     ".CccccsccccCc.",
     "Ccccsccccscccs",
     "Cccsccccsccccs",
     "Ccsccccsccccss",
     "csccccsccccsss",
     ".sccccsccccss.",
     ".ssccccccccss.",
     "..ssssssssss.."],
    # pipe organ: three tubes of different heights on a common base
    [".....HHH.....",
     ".....Ccs.....",
     "HHH..Ccs.....",
     "Ccs..Ccs.....",
     "Ccs..Ccs..HHH",
     "Ccs..Ccs..Ccs",
     "Ccs..Ccs..Ccs",
     "Ccs..Ccs..Ccs",
     "Ccs..Ccs..Ccs",
     "Ccs..Ccs..Ccs",
     "Ccccccccccccs",
     "sssssssssssss"],
]

# A giant clam, after the photo reference: the two valves are not a lid parked
# above a bowl but a pair of tilted ellipses hinged at the back right, opening
# to a wedge at the front left with the pearl sitting in it. Rasterised from
# that geometry rather than typed by hand — the flutes are rays from the umbo,
# so they fan the way a real shell's do, and the free edge of each valve carries
# the scalloped rim that is the whole silhouette of the animal. The symmetric
# version this replaces read as a striped rock, which is what you get when both
# valves are parallel and the rim is straight.
CLAM = [
    "...ssssssSS...............",
    "...dssssssSSS.............",
    "....sssssssSSSS...........",
    "....rrrsssssSSSS..........",
    "......dssssssSSSS.........",
    ".......rrrsssssSSS........",
    ".........RrsssssSSs.......",
    ".........RR.rssssSSs......",
    "............RRRsssSs......",
    ".......pqq.....RSSsSd.....",
    "......pppqq.......dddd....",
    ".....Pppppqq..rd..dddd....",
    ".....PPppppqrrrMRMmddM....",
    "......PPpppmMMMMMmmMmM....",
    "....rrPPPppMMMMMmmMMm.....",
    "...mmmmMMMMMMMMmmmM.......",
    "..mmMMMMMMMMMmmm..........",
    "..MMMMMMMMMMm.............",
]

CLAM_PALETTE = {"S": (238, 230, 208),   # upper valve, inner face in the light
                "s": (198, 180, 146),   # the flute between two ridges
                "M": (172, 114, 78),    # lower valve, the mahogany inside
                "m": (118, 70, 48),
                "R": (240, 208, 200),   # scalloped rim, pink as in the photo
                "r": (204, 152, 142),
                "d": (84, 56, 44),      # hinge and the shell's own shadow
                "P": (255, 255, 255),   # pearl: replaced per frame, see draw_clam
                "p": (232, 234, 240),
                "q": (176, 182, 200)}

CORAL_COUNT = 3

KELP_DEAD = water.KELP_DEAD
SEABED_ROWS = water.SEABED_ROWS


# --- scenery ----------------------------------------------------------------
# Placement is decided per *text column*, not per pixel column, so the kelp and
# coral stand exactly where the 1x theme puts them and switching themes does not
# rearrange the tank. Everything else is doubled: stalks are two pixels thick,
# twice as long, and bend twice as far.

def draw_kelp(px, t, floor_py, alive, tall=False):
    reach = 6.0 if tall else 3.6
    for cx in range(px.cols):
        if water.noise(cx, 101) >= 0.12:
            continue
        x = cx * 2
        stalk = ((16 + int(water.noise(cx, 202) * 26)) if tall
                 else (8 + int(water.noise(cx, 202) * 14)))
        root = int(water.noise(cx, 303) * 2)
        for i in range(stalk):
            y = floor_py - 1 - i
            if y < 0:
                break
            grow = i / max(1, stalk - 1)
            sway = math.sin(t * water.SWAY_SPEED + cx * 0.55 + i * 0.15)
            bend = int(round(sway * grow ** 1.5 * reach))
            shade = min(len(water.KELP_FG) - 1, root + int(grow * 3))
            if not alive(x + bend, y):
                bend = int(round(bend * 0.2))
                shades = KELP_DEAD
            else:
                shades = water.KELP_FG
            px.set(x + bend, y, shades[shade])
            px.set(x + bend + 1, y, shades[max(0, shade - 1)])
            if i % 6 == 2 and i < stalk - 4:
                side = 2 if sway > 0 else -1
                pot = water.KELP_FG if alive(x + bend + side, y) else KELP_DEAD
                tip = min(len(pot) - 1, shade + 1)
                px.set(x + bend + side, y, pot[tip])
                px.set(x + bend + side + (1 if sway > 0 else -1), y, pot[tip])


def _stamp(px, sprite, x0, y0, palette, bleached, alive):
    """Blit a seabed sprite, bleaching whatever part of it is out of the water."""
    for dy, line in enumerate(sprite):
        for dx, key in enumerate(line):
            if key == ".":
                continue
            pot = palette if alive(x0 + dx, y0 + dy) else bleached
            px.set(x0 + dx, y0 + dy, pot[key])


def draw_coral(px, seed, centre, floor_py, alive):
    base = water.CORAL_FG[int(water.noise(seed, 505) * len(water.CORAL_FG))
                          % len(water.CORAL_FG)]
    palette = {"s": lerp_rgb(base, water.WATER_DEEP, 0.50),
               "c": base,
               "C": lerp_rgb(base, (255, 255, 255), 0.30),
               "H": lerp_rgb(base, (255, 255, 255), 0.62)}
    bleached = {key: water.wither(col) for key, col in palette.items()}
    sprite = CORAL_SPRITES[int(water.noise(seed, 606) * len(CORAL_SPRITES))
                           % len(CORAL_SPRITES)]
    _stamp(px, sprite, centre - max(len(line) for line in sprite) // 2,
           floor_py - len(sprite), palette, bleached, alive)


def draw_clam(px, t, centre, floor_py, alive):
    """The clam, with the pearl's specular breathing in and out.

    A still pearl just looks like a pale pebble; the whole point of it is that
    it catches the light, and at 1 fps a slow pulse is the only way to say so.
    """
    glint = 0.5 + 0.5 * math.sin(t * 0.9)
    palette = dict(CLAM_PALETTE,
                   P=lerp_rgb((238, 240, 248), (255, 255, 255), glint),
                   p=lerp_rgb((202, 206, 220), (240, 242, 250), glint))
    bleached = {key: water.wither(col) for key, col in palette.items()}
    _stamp(px, CLAM, centre - len(CLAM[0]) // 2, floor_py - len(CLAM),
           palette, bleached, alive)


def draw_seabed(px, t, floor_py, alive):
    """Three corals and the clam, one per lane.

    Placement used to be a per-column dice roll, which was fine at ten colonies
    and is not at four: two of them landing on the same column is no longer a
    bit of clutter, it is most of the seabed in one heap. A lane each keeps them
    apart, and the offset within the lane keeps them from looking pegged out.
    """
    lanes = CORAL_COUNT + 1
    clam_lane = int(water.noise(7, 909) * lanes) % lanes
    span = px.width / float(lanes)
    for lane in range(lanes):
        centre = int(span * (lane + 0.5)
                     + (water.noise(lane, 808) - 0.5) * span * 0.45)
        if lane == clam_lane:
            draw_clam(px, t, centre, floor_py, alive)
        else:
            draw_coral(px, lane, centre, floor_py, alive)


BUBBLE_RISE = 5.0        # pixels per second
BUBBLE_LIFE = 3.2        # seconds before it has gone far enough to forget
BUBBLE_GAP = 0.45        # seconds between the bubbles of one breath


def blow_bubbles(px, t, i, place, span_w, span_h, rightward, ceiling_at):
    """A couple of bubbles from the mouth every ten seconds or so.

    Real fish do this in short bursts rather than as a steady stream, so each
    fish gets a breath every 9-17s and lets two or three go in quick succession.
    Nothing is remembered between frames: a bubble's position is derived from
    where `place` says the mouth was at the moment it was blown, plus how far it
    has risen since. Both the current breath and the previous one are checked,
    because the older one may still have bubbles in the water.
    """
    period = 9.0 + water.noise(i, 31) * 8.0
    phase = water.noise(i, 33) * period
    per_breath = 2 + int(water.noise(i, 32) * 2)
    latest = math.floor((t - phase) / period)

    for breath in (latest, latest - 1):
        for k in range(per_breath):
            age = t - (phase + breath * period + k * BUBBLE_GAP)
            if not 0.0 <= age <= BUBBLE_LIFE:
                continue
            mx, my, _ = place(t - age)
            if my is None:
                continue
            mx += span_w - 1 if rightward else 0
            my += span_h // 2
            wobble = math.sin(t * 1.3 + k * 2.0 + i) * 1.5
            bx = int(round(mx + wobble + (1 if rightward else -1) * age * 1.2))
            by = int(round(my - age * BUBBLE_RISE))
            if by < ceiling_at(max(0, min(px.width - 1, bx))):
                continue            # reached the surface and popped
            px.set(bx, by, water.BUBBLE_FG)
            if age > 1.2:           # they swell on the way up
                px.set(bx + 1, by, water.BUBBLE_FG)
                px.set(bx, by + 1, water.BUBBLE_FG)
                px.set(bx + 1, by + 1, water.BUBBLE_FG)


def draw_fish(px, t, floor_py, ceiling_at, big=False):
    """As `water.draw_fish`, but over the 2x4 grid and the hi-res shoal.

    Counts come off the *column* count so the tank holds as many fish as the 1x
    theme at the same width; the sprites are twice the pixels but the same
    apparent size. Speeds and the bob are doubled for the same reason, which
    incidentally buys half-cell steps instead of whole-cell teleports.
    """
    shoal = BIG_POOL if big else SMALL_POOL
    count = max(2, min(6 if big else 7, px.cols // (26 if big else 20)))
    width = px.width

    for i in range(count):
        species = shoal[i % len(shoal)]
        sprite = species.sprite
        palette = species.palette or FISH_PALETTES[
            int(water.noise(i, 24) * len(FISH_PALETTES)) % len(FISH_PALETTES)]
        rightward = water.noise(i, 23) < 0.5
        speed = ((0.6 + water.noise(i, 22) * (1.8 if big else 1.5))
                 * 2 * species.speed)
        depth = 0.15 + water.noise(i, 21) * 0.7
        span_w = max(len(line) for line in sprite)
        span_h = len(sprite)

        if species.alt is not None:
            # Two models to a slot: swap between laps, off screen at the far
            # edge, where the change cannot be watched happening. Both have to
            # agree on the span or the swap would shunt the animal sideways as
            # well as change what it is.
            span_w = max(span_w, max(len(l) for l in species.alt.sprite))
            span = width + span_w * 2
            if int((t * speed + water.noise(i, 26) * span) // span) % 2:
                species = species.alt
                sprite = species.sprite
                palette = species.palette or palette
                span_h = len(sprite)

        span = width + span_w * 2

        def place(at, _sw=span_w, _sh=span_h, _sp=span, _i=i,
                  _speed=speed, _right=rightward, _depth=depth):
            """Where this fish is at time `at` — (x0, y0, room), y0 None if beached.

            Pulled out of the draw loop because the bubbles need it too: a bubble
            has to leave the mouth from where the mouth *was* when it was blown,
            not from where the fish has since swum to.

            The result is snapped to the cell grid. Eight subpixels share two
            colours, so which subpixels a cell happens to contain decides what
            that cell can show: land the same fish on a different sub-cell phase
            and it is re-quantised into a slightly different fish, frame after
            frame. Snapped, every cell of the sprite always holds the same eight
            subpixels and the fish is identical wherever it swims — it moves by
            whole cells instead, which at one frame a second is no loss.
            """
            trav = (at * _speed + water.noise(_i, 26) * _sp) % _sp
            x = int(trav) - _sw if _right else width - int(trav)
            x -= x % px.ppc
            ceil_ = ceiling_at(max(0, min(width - 1, x + _sw // 2)))
            gap = floor_py - 1 - _sh - ceil_
            if gap <= 0:
                return x, None, gap
            bob_ = math.sin(at * 0.55 + _i * 1.3) * 2.8
            y = int(round(ceil_ + _depth * gap + bob_))
            y = max(int(math.ceil(ceil_)), min(y, floor_py - 1 - _sh))
            return x, y - y % px.ppr, gap

        x0, _, room = place(t)
        if room <= 0:
            bones = species.bones
            lane = width / count
            rest = int(i * lane
                       + water.noise(i, 27) * max(1.0, lane - len(bones[0])))
            rest = max(0, min(rest, width - len(bones[0])))
            rest -= rest % px.ppc      # sprite heights are whole cells already
            px.blit(rest, floor_py - len(bones), bones, water.BONE,
                    flip=not rightward)
            continue

        _, y0, _ = place(t)
        px.blit(x0, y0, sprite, palette, flip=not rightward)
        if species.bubbles:
            blow_bubbles(px, t, i, place, span_w, span_h, rightward, ceiling_at)


# --- panels -----------------------------------------------------------------

def scene(width, height, pct, t):
    canvas = Canvas(width, height)
    floor_y = max(1, height - SEABED_ROWS)

    base = max(0.0, min(float(height), height * (pct / 100.0)))
    amp = water.wave_amp(base, floor_y)
    for x in range(width):
        surface = water.surface_at(x, base, t, amp)
        if surface >= floor_y:
            continue
        top = int(math.floor(surface))
        for y in range(max(0, top), floor_y):
            if y == top:
                ch = water.SURFACE_CHARS[(x + int(t)) % len(water.SURFACE_CHARS)]
                canvas.put(x, y, ch, water.SURFACE_FOAM,
                           water.water_bg(y, surface, floor_y))
            else:
                canvas.put(x, y, " ", None, water.water_bg(y, surface, floor_y))

    water.draw_sand(canvas, floor_y)
    if base < floor_y:
        water.draw_bubbles(canvas, t, base, floor_y, amp)

    px = OctantPixels(width, height)
    ppr = px.ppr
    # The waterline predicate works in pixel rows, so it has to be told that a
    # text row is now four pixels tall rather than two.
    def alive(x, py):
        surface = water.surface_at(x // 2, base, t, amp)
        return surface < floor_y and py >= surface * ppr + 2

    draw_kelp(px, t, floor_y * ppr, alive)
    draw_seabed(px, t, floor_y * ppr, alive)
    draw_fish(px, t, floor_y * ppr,
              lambda x: (water.surface_at(x // 2, base, t, amp) + 0.5) * ppr)
    px.flush(canvas)
    return canvas


def overlay(width, height, t, surface_row):
    """Scenery only, so the background GIF shows through — see `water.overlay`."""
    canvas = Canvas(width, height)
    floor_y = max(1, height - SEABED_ROWS)

    for x in range(width):
        canvas.put(x, floor_y, "░" if water.noise(x, 7) >= 0.18 else "·",
                   water.SAND_FG if water.noise(x, 7) >= 0.18 else water.PEBBLE_FG)

    water.draw_bubbles(canvas, t, surface_row, floor_y, 0.0)

    px = OctantPixels(width, height)
    ppr = px.ppr
    alive = water.all_wet if surface_row <= 0 else water.above(surface_row * ppr)
    draw_kelp(px, t, floor_y * ppr, alive, tall=True)
    draw_seabed(px, t, floor_y * ppr, alive)
    draw_fish(px, t, floor_y * ppr, lambda x: max(0.0, surface_row * ppr), big=True)
    px.flush(canvas)
    return canvas


def half_dead_band(lines, height):
    """`water.half_dead_band` against this theme's taller sprites."""
    floor_py = max(1, height - SEABED_ROWS) * 4
    fallback, miss = 80, None
    for band in range(0, 101, 10):
        surf = water.gif_surface(band, lines, height)
        if not 0 < surf < height:
            continue
        rooms = [floor_py - 1 - len(species.sprite) - surf * 4
                 for species in BIG_POOL]
        if any(r > 0 for r in rooms) and any(r <= 0 for r in rooms):
            return band
        off = abs(surf - height * 0.66)
        if miss is None or off < miss:
            fallback, miss = band, off
    return fallback


def render(d):
    cols, lines = term_size()
    width = max(20, cols - env_int("STATUSLINE_RULE_PAD", 2))

    pct = water.dig(d, "context_window", "used_percentage")
    pct = 0.0 if pct is None else max(0.0, min(100.0, float(pct)))
    t = time.time()

    override = water.forced_pct()
    if isinstance(override, float):
        pct = override

    if water.gif_mode():
        raw = water.height_setting()
        height = (water.panel_height(lines) if raw and raw != "auto"
                  else max(7, min(12, lines // 3)))
        if override == "partial":
            pct = float(half_dead_band(lines, height))
        band = water.sync_band(pct)
        if not truecolor():
            return [water.info_row(d, pct)]
        surface_row = water.gif_surface(band, lines, height)
        return overlay(width, height, t, surface_row).rows() + [water.info_row(d, pct)]

    height = water.panel_height(lines)
    if override == "partial":
        pct = 80.0
    if not truecolor():
        return water.plain(width, height, pct) + [water.info_row(d, pct)]

    return scene(width, height, pct, t).rows() + [water.info_row(d, pct)]
