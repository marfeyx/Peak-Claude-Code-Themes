# vice

> A Vice City panorama on a day-night cycle, context as a wanted level

Livio's `vice` renderer, bridged onto the Base Theme-switcher. Leonida from the
beach, looking out over the bay: downtown on the left shore thinning into open
water, palms framing the edges, surf on the sand, a boat somewhere out there and
planes crossing overhead.

The sky runs a real twenty-four hour cycle off the clock. The sun arcs across and
sinks into the water laying a glitter path, the stars come out after dusk, the
skyline lights up window by window, every lit window drops a wobbling reflection
into the bay, and the neon on the strip starts to pulse.

Your context window is your **wanted level**. An empty one is a clean record.
Past four stars a police chopper sweeps the bay with a searchlight; at five, red
and blue wash over the whole scene and the water picks it up.

```
                 𜶖 𜵰𜷋𜵰𜴏𜴂𜴗𜴗▀▀🮅𜴦▀𜴦𜴦𜴢𜴢𜴢 ▙
                   ▘▘𜵊▛𜴏𜴗𜴂▀🮂▀𜺫▜𜴢𜶘𜶘𜶘𜷀𜶫 ▌
    𜵊🮂🮂𜵳𜶮𜶮𜴸🮂🮂🮂𜶘    ▐▐▌▌▌▌▌▌𜷂𜷖▐▐▐▐▐🮅🮅🮅 ▌
    ▙▄▖    𜷤𜷞▄▟    ▙▂▂𜶿𜵰🮅𜶻𜺠𜷋▄𜷞▄𜶻🮅𜶮▂▂ 🮂🮅🮅🮅🮅🮅🮅🮅🮅🮅🮅                                           𜺠▂
   ▆▆▆𜷤▆▆     𜷋𜶤𜷥▆𜵭𜷥  𜷤▆𜺠𜴐𜵍𜺫𜶇▜▜𜷋𜴠𜺣▆▆▆𜶻𜷋𜶻▄▄▄▄▄𜷞▂▄▂▂▂▂▂▄▄▄▄▄                               ▄𜶪𜵰  𜴤▖
 𜷋▄▄▄▂    ▂▂𜺠𜴞𜴁𜴃𜶘🮂▘ 𜴠𜺣 ▗𜷌𜶽  ▂▐𜷡𜴗𜷋𜷍▆▆𜶻▄𜺠▄▄𜷞▄𜺣                                           𜺠𜴁▘ 𜴀▐𜺫 𜺫
𜵰🮅𜴂𜶫𜶫🮅𜶫🮅🮅🮅🮅𜴳𜴴𜴳𜴳𜴳𜵯𜴳🮅🮅🮅🮅🮅🮅🮅🮅🮅𜴳𜴳𜶪𜴳𜴳▂🮅🮅🮅🮅𜵩🮅🮅𜵀𜶫𜵰🮅𜵰𜴧🮅🮅🮅🮅🮅🮅🮅🮅🮅𜴧𜴧𜴧𜴧𜴧𜴳▂𜺣𜴧𜴧𜴧𜴧𜴧𜴧𜴧▂▂🮅▂▂▂▂▂▂▂▂▂▂▂▂▂▂𜺨▂▂▂▂▐▂▂▂
𜺨𜷥 𜵉𜷚 ▆𜺫𜴀𜵰𜶫  𜷠𜷣𜺠𜴍  𜵰𜶫  𜷝  𜵮𜵨▆▐▆𜶺    𜴃𜺨   ▐𜶺𜷝𜺫𜴄  𜵄𜶫   𜷤𜷥  𜷠𜷣 ▆       ▆              𜶺𜴗𜷏𜴲 𜷤𜷥  ▐▂
   ▌▖    𜷤𜷥  𜴗🮅𜺫🮂🮅   𜷝𜶺  ▟𜵣𜶆𜵹▐ 𜷚        𜷤𜺫𜵈▖      𜷠𜷆𜵰𜶫    𜷤𜷥𜶮    𜴮𜷣 ▆𜵰𜶩𜷉𜷚𜶯𜷣🮅     𜷊𜷝    𜵰𜶫   ▐ 𜷤𜷥
𜶺 𜷤▌▐𜶺𜶺 𜷤𜶷𜶹  𜴳▆▆▆𜴳𜴳𜷝𜷝 𜷈𜷈𜶹𜴞𜴣𜶅𜷉▐ 𜵟  ▆▆▆𜵰🮅𜶫𜷤▆▌▐▄𜶮𜶺  𜷤▆𜷥  𜷝𜶮𜶺𜷚𜵰🮅𜶩▆𜷥 ▆▆𜶺𜶺    𜷠𜷝𜷡▆𜶲𜶮𜴲🮅𜴗𜴂𜷎𜷣𜷤▆▆▆ 𜶺𜷝𜷝▐  𜷊
▀🮅𜴆▌𜷊𜶺𜶺𜶺𜶺𜶺🮅𜶺𜶺𜴗𜶺▐ 𜶺𜶺𜶺𜶺𜶺𜶺𜶺𜶺𜶺𜶺𜶺𜶺▐ 𜴆🮅▘🮅🮅🮅🮅🮅▀▀▀▌𜷈🮅🮅🮅🮅🮅▀▀▀▀𜴆𜴆𜴆▀▀▀▀🮅🮅𜶺▀𜶺𜶺🮅𜶺𜶺𜶺𜶺𜶺𜶺𜶺𜶺𜷚𜶺𜶺▀▀▀▀🮅🮂🮂𜴆𜴆𜴆▀▀🮅🮅▐ ▀▀
▄▄ 𜴍𜴍▄ ▄▄  ▀▀▄ 𜴡🮅▄▄▀▀ ▄▀▀▄▄▄▄▝🮅𜴉▀▄▀ ▄    ▀𜴝𜴬▀▀▀▄ ▀ ▀▀ ▄ ▄  ▀▄▄▄ ▄▄▄▀▄▄ ▄▄ ▄▄▄  ▄▄ ▀ ▀▄▀▀▀ ▄ 𜴡🮅
10:00  ◆  WKTT Talk Radio  ◆  /mnt/c/Partitio/Extranet
WANTED ★★★☆☆ 47%  ◆  $222.07  ◆  Opus 5 (1M context)  ◆  xhigh effort  ◆  5 hours 51 minutes
```

Real render at 10:00, 100 columns, escapes stripped. Those `🮅 𜶺 𜴆` are **octant
glyphs** — see Requirements. `cat preview-dusk.ansi` for the same frame at 21:30,
which is the theme actually showing off.

## What's in here

| File | Goes to | Whose | What it is |
|---|---|---|---|
| `vice.sh` | `~/.claude/statusline/themes/` | ours | the theme the framework loads |
| `vice.py` | `vendor/livio/` | **Livio's, verbatim** | the whole panorama. It imports nothing local but `common`. |
| `preview.ansi` | — | — | a real render in colour at 10:00, 100 columns |
| `preview-dusk.ansi` | — | — | the same frame at 21:30 |
| `install.sh` | — | — | copies everything into place and selects it |

Plus `../shared/`. His `vicegif.py` **does not ship**: it is a pure background
generator, `vice.py` does not import it, and its `build_all` takes about nine
minutes to produce 144 bands. It is preserved under `../upstream/statuslines/`.

## What it looks like

Fourteen rows at a full-width terminal: twelve scene rows and two HUD rows,
drawn on a 2×4 octant pixel grid so twelve terminal rows carry forty-eight rows
of picture.

Reading down:

1. **The sky,** a gradient interpolated between the eleven keyed states of
   `SKY_KEYS` — deep night, first light, dawn, early morning, late morning,
   afternoon, golden hour, sunset, afterglow, dusk, and a wrap back to night —
   chosen from the hour with 1.1 hours of fade either side of the sun crossing.
   (His module docstring still advertises the eight it started with, including a
   "midday haze" key the table no longer has. The table is the truth.) **Stars**
   after dusk, in four tints, placed by a hash so they do not twinkle randomly.

   Measured across three pinned hours on the same frame, counting distinct
   24-bit colours in the output: **91 at 14:00**, **57 at 21:30**, **47 at
   02:00**. The night sky really is a different, sparser picture rather than the
   day one dimmed — at 02:00 the top rows are mostly empty with scattered star
   glyphs and a lit skyline, where at 14:00 they are a full gradient.

2. **The sun or the moon,** arcing across and sinking into the bay at 84 % of
   the way across. The rim reddens as it touches the water while the core stays
   luminous, and a glitter path shimmers back along the water toward you.

3. **The skyline** on the left shore, thinning into open water so the sun always
   has somewhere to set. Towers shift from `TOWER_DAY` to `TOWER_NIGHT`, and
   after dark windows light up in warm and cool tints, each dropping a wobbling
   reflection into the bay below it. Visible in the 02:00 render as a lit block
   on an otherwise dark upper band.

4. **The neon strip**, five colours, pulsing after dark.

5. **The bay,** a gradient from `SEA_FAR` to `SEA_NEAR` with swells at
   15 columns per cycle moving at 0.8 rad/s, and foam.

6. **The surf and the sand** — a wet strip the surf keeps darkening, then dry
   sand.

7. **Five palms** at 4.5 %, 17.5 %, 31.5 %, 45.5 % and 97.5 % of the width,
   placed to keep the sunset stretch of horizon clear. Each leans and sways on
   its own hashed phase; the fronds leave the crown heading up and outward and
   then droop under a quadratic term, which is what makes six pixels of frond
   read as a palm rather than a TV aerial. The lit edge of the trunk picks up
   whatever colour the sky is doing, because a flat black silhouette is what
   makes the strip look dead at dusk.

8. **A boat** drifting and **planes** crossing — both occasional, both on long
   cycles, so neither is in the two previews here. Clouds drift at 0.45 columns
   per second.

9. **The police chopper** — only past four wanted stars. It sweeps the bay with
   a searchlight, and is mirrored so it never flies tail-first.

10. **HUD row one** — the clock, the radio station, the path, the branch, the
    diffstat.

11. **HUD row two** — the wanted level, cost, weekly spend, model, effort,
    duration.

**The wanted level** is `int(pct ÷ 20) + 1` for any non-zero percentage, capped
at five; a genuinely empty context is zero stars. Measured on the same frame:
`★☆☆☆☆` at 8 % context, `★★★☆☆` at 47 %, `★★★★★` at 92 %. The colour goes pink →
gold at three stars → orange at four → red at five.

At five stars it **flashes once per second**. Measured: at 92 % context the
wanted row is `rgb(255,64,64)` at one pinned second and `rgb(176,30,30)` at the
next. The scene as a whole also changes with the wanted level — rendering the
same frame at 47 % and 92 % gives different output — which is the chopper
arriving and the red-and-blue wash coming up.

**The radio station** rotates every 45 seconds through eight stations. Measured
on three pinned timestamps 45 s apart: `WKTT Talk Radio` → `Flylo FM` →
`Vice City FM`.

**Animation.** Everything derives from `SL_NOW`, which the bridge pins, so two
renders of the same second are byte-identical — including the siren flash, which
upstream read from `time.time()` directly. The refresh is about 1 fps.

## What data it shows

| Row | Shown | Field |
|---|---|---|
| 1 | wall clock, `10:00` | `SL_NOW`, or `SL_VICE_HOUR` when pinned |
| 1 | radio station | rotates on `SL_NOW ÷ 45` |
| 1 | current path | `SL_PATH`, shortened to 34 characters |
| 1 | git branch | resolved by the host, never forked per frame |
| 1 | session diffstat | `+696` / `-276` |
| 2 | context used as a wanted level | `SL_CONTEXT_PERCENT` |
| 2 | session cost | `$222.07` |
| 2 | weekly gateway spend | spend / budget / share; absent in preview mode |
| 2 | model display name | `Opus 5 (1M context)` |
| 2 | reasoning effort | `xhigh effort`, and `⚡ fast` when fast mode is on |
| 2 | session duration | `5 hours 51 minutes` |

Not read: token counts, ahead/behind counts, remaining-context percentage,
output style, version, session id, remote repo identity, API duration, and the
thinking / ultracode / exceeds-200k flags.

## How it behaves as the terminal narrows

Measured by rendering the bundled sample payload at **every width from 20 to
180 columns**. The framework subtracts a 4-column safety margin, so the theme
budgets against `SL_COLUMNS = COLUMNS − 4`.

**Height** is `min(requested, SL_COLUMNS ÷ 3)`, floored at 5 scene rows. The
default request is 12:

| Terminal columns | Total rows |
|---|---|
| 20 – 21 | 7 |
| 22 – 24 | 8 |
| 25 – 27 | 9 |
| 28 – 30 | 10 |
| 31 – 33 | 11 |
| 34 – 36 | 12 |
| 37 – 39 | 13 |
| ≥ 40 | 14 — full height, and it stops growing |

**The two HUD rows.** `vice` is the only one of the three with a shedding helper
of its own upstream (`join_fit`), applied to the HUD, which is why these rows
behave at every width even though his scenery did not:

| Terminal columns | HUD |
|---|---|
| 20 – 28 | `10:00` / `WANTED ★★★☆☆ 47%` |
| 29 – 31 | row 1 gains `WKTT Talk Radio` |
| 32 – 55 | row 2 gains `$222.07` |
| 56 – 57 | row 2 gains `Opus 5 (1M context)` |
| 58 – 72 | row 1 gains the path |
| 73 – 95 | row 2 gains `xhigh effort` |
| 96 – 132 | row 2 gains `5 hours 51 minutes` |
| 133 – 146 | row 1 gains the git branch |
| ≥ 147 | row 1 gains the diffstat `+696/-276` |

The wanted level never sheds — it is first in priority order on row 2, so a
20-column terminal still tells you how full your context is.

The branch here is **70 characters** long, which is why it costs until 133
columns. That number is payload-dependent; a short branch appears far earlier,
and there is no truncation step between "whole branch" and "no branch".

**Under `NO_COLOR`** the theme collapses to three rows: one `▀` band standing in
for the horizon, plus the two HUD rows. No escapes are emitted at all. Note the
stars survive — `WANTED ★★★☆☆ 47%` still reads.

## Requirements

- **`python3`**, stdlib only.
- **A font carrying Unicode 16 octants** — Symbols for Legacy Computing
  Supplement, U+1CD00–U+1CDE5, plus `🮂 🮅` and the quadrant glyphs `▌ ▐ ▘ ▙ ▛ ▜`.
  **Treat this as mandatory.** CaskaydiaMono NF has them; Cascadia Mono and
  Ubuntu Mono do not, and the bay comes out as a field of tofu boxes.
  Livio documents `SL_VICE_PIXELS=half` as the fallback — **it does not work.**
  See Known issues.
- The HUD also uses `★ ☆ ◆ ⚡`.
- **A truecolour terminal.** The day-night cycle is a 24-bit gradient; there is
  no meaningful 256-colour version of it. Under `NO_COLOR` you get the
  three-row text fallback.
- **bash 4.2+** for the framework.
- **Cost: about 264 ms per render** at 100 columns on this machine, measured over
  five warm renders, including Python startup. Second most expensive of the three.
  The refresh is about once a second, so it fits.
- Platform-neutral. The Windows Terminal background version — 144 GIF bands, one
  per ten minutes of the day, so the sun visibly works down the sky behind your
  session over a real day — is deliberately **not shipped**. It is the single
  most impressive thing in Livio's bundle and the reason it is out is purely
  where it was called from; see [`../README.md`](../README.md).

## Known issues

**`SL_VICE_PIXELS=half` is broken.** Setting it produces twelve identical rows of
`▀` and no scenery. This is **upstream behaviour, not the bridge** — verified by
importing `vice.py` directly, outside this framework, with the same result.
`make_layer` is handed pixel dimensions sized for the 2×4 octant grid and
`Pixels` interprets them as 1×2, so every drawn pixel lands off-canvas.

Separately, and this one the bridge **does** fix: `vice.scene` builds its canvas
from the pixel width rather than the text width, so every scenery row came out at
exactly twice the budget — 196 cells at 100 columns, 276 at 140. His own GIF path
gets it right and so does `kyoto`; only the panel path is wrong. Rather than edit
his source, the bridge replaces `vice.Canvas` with a factory that clamps the
width. The pixel layer already flushes in text-cell coordinates, so clamping the
canvas is the whole fix.

## Install

With the Base Theme-switcher already at `~/.claude/statusline/`:

```sh
./install.sh
```

By hand:

```sh
mkdir -p ~/.claude/statusline/vendor/livio
cp ../shared/*.py ../shared/wrapper.sh ~/.claude/statusline/vendor/livio/
cp vice.py ~/.claude/statusline/vendor/livio/
cp vice.sh ~/.claude/statusline/themes/
```

Then `/sl vice`, or its number in the `/sl` list (`@order: 42` decides where it sorts).

Check it:

```sh
~/.claude/statusline/check.sh vice
```

Renders at 30/40/50/60/80/100/160/220 columns plus `NO_COLOR`. **The copy in
this folder passes with zero failures.** Nothing else is copied anywhere: no
font, no wallpaper, no shader, no terminal configuration, and no nine-minute GIF
build on first switch.

## Tuning

| Variable | Default | Effect |
|---|---|---|
| `SL_VICE_ROWS` | `12` | panel height, clamped to 5…24 and again by the width |
| `SL_VICE_HOUR` | live | pin the time of day, e.g. `21.5` for 21:30. Verified working through the bridge |
| `SL_VICE_PIXELS` | octant | `half` is documented upstream and does not work — see Known issues |

`SL_VICE_HOUR` is the one worth knowing: the day-night cycle is the whole theme
and you would otherwise have to wait for dusk to see it.

```sh
SL_VICE_HOUR=21.5 SL_PREVIEW=1 COLUMNS=100 \
  ~/.claude/statusline/statusline.sh --theme vice \
  < ~/.claude/statusline/sample-payload.json
```

## Preview

```sh
cat preview.ansi        # 10:00
cat preview-dusk.ansi   # 21:30, SL_VICE_HOUR=21.5
```

`SL_FAKE_NOW=<epoch>` pins the clock for a reproducible frame — that is how both
previews were made.

## Uninstall

```sh
rm ~/.claude/statusline/themes/vice.sh
```

Then `/sl <something-else>`. The modules under `vendor/livio/` are shared with
the other three themes; only remove `vice.py` if none of those are installed.

## Credits

The bay, the day-night cycle, the wanted level and the chopper are Livio's. The
bridge and the packaging are adaptation work.
