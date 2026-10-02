# christmas

> **Village skyline at Christmas — fir, snowman, snowfall and a real-date advent terrace**

A snowed-in village street at night, drawn in half-block pixel art in the Claude
Code status line. The fir, the presents and the snowman stand on the left; a
terrace of snow-roofed houses closes the right, and its ground floor is a
24-door advent calendar that follows the real date. Under the picture sits one
line of session data.

It is a theme for the `~/.claude/statusline` framework (see
`../../Base Theme-switcher`). One theme file, one `sl_render` function, no
daemon, no background process. It also ships a Windows Terminal pixel shader
that turns the whole window into a snowy night sky; the switcher applies it when
you activate the theme.

```
File            Goes to                         What it is
christmas.sh    ~/.claude/statusline/themes/    the theme
christmas.hlsl  ~/.claude/statusline/shaders/   the full-window snow shader (Windows Terminal only)
install.sh      —                               copies the two files above into place
preview.ansi    —                               `cat` it to see one frame in colour
```

---

## What it looks like

Every scene cell is a `▀`, `▄` or `█` with a foreground and a background
colour, so one terminal row holds two stacked pixels and a pixel is roughly
square. Empty sky is left as plain, unpainted spaces: whatever the terminal
window shows behind the text *is* the sky.

At 114 columns or wider the theme occupies **nine rows**:

| Row | Content |
|---|---|
| 1–7 | **The scene**, 14 pixels tall. From the left: a fir with a star on top, snow on its branches and red, gold and ice-blue baubles; a pile of presents (a red parcel with a gold bow and a green one); a snowman in a red, fur-trimmed hat with coal eyes and button, carrot nose, red scarf and twig arms; a street lamp; dark conifers in two depths. On the right, the terrace: gabled and flat-roofed houses with snow on the roofs, chimneys on the flat ones, and one church with a steeple, a gold clock face and a finial. A moon rises behind the terrace. Stars hang in the upper half of the sky, a snow drift runs along the street (lit warm under the fir and the presents), and flakes fall through everything. |
| 8 | **The advent row**, the terrace's ground floor. A gold `▌` gutter, the calendar label (see below), then the 24-door strip `▐0102…24▌` flush right, each two-digit number its own coloured door. Where the terrace has grown extra houses (see the width table), the stretch of row under them is painted a dim facade colour. |
| 9 | **The data row.** `▌ ` gutter, then path · `⎇ branch` · context · cost · model · `✦effort`. |

### What data it shows

All on row 9, in this order, separated by grey ` · `:

| Segment | Source | Notes |
|---|---|---|
| Path | `SL_PATH` via `sl_path_fit` | Bold snow white. Gets whatever room the other segments leave, never less than 6 columns. |
| `⎇ branch` | `SL_GIT_BRANCH` (`sl_git`) | Green. Truncated to at most 28 columns, and dropped when fewer than 6 would be left for it. Absent outside a git repo. |
| `ctx 47% 466k` | `SL_CONTEXT_PERCENT`, `SL_CONTEXT_TOKENS` | Bold. Green below 60 %, amber from 60 %, red from 85 %. The token count is dropped first if the path would otherwise get under 10 columns. Absent if the payload has no percentage. |
| `$222.07` | `SL_COST_TEXT` | Bold amber. |
| Model | `SL_MODEL_NAME`, else `SL_MODEL_SHORT` | Blue grey. The full name (`Opus 5 (1M context)`) if at least 14 columns remain for path and branch, the short name (`Opus 5`) if at least 12 do, otherwise omitted. |
| `✦effort` | `SL_EFFORT` | Gold. Only when at least 16 columns remain after it. |

Nothing else is read. The theme never calls `sl_gateway` (no budget segment, no
`build-cli`) or `sl_token_burn` (no transcript scan); diffstat, durations, repo
name, ahead/behind, version and the mode flags are not shown.

### How it behaves as the terminal narrows

The framework subtracts a 4-column safety margin (`SL_COLUMNS = COLUMNS - 4`).
Breakpoints below are **real terminal columns**, checked by rendering the
framework's `sample-payload.json`:

| Terminal columns | Lines | Scene |
|---|---|---|
| **≥ 114** | 9 | 14 px. Everything listed above. |
| **96 – 113** | 8 | 12 px. The same cast with a shorter fir. The street lamp needs 102 columns or more. |
| **78 – 95** | 7 | 10 px. Smaller presents, snowman and moon; far conifers only; houses 6 and 4 px tall; no church, no lamp. |
| **62 – 77** | 6 | 8 px. Fir, a small snowman, far conifers, houses. No presents, no moon, no smoke. |
| **48 – 61** | 5 | 6 px. A small fir and a row of low houses. |
| **38 – 47** | 4 | 4 px. No fir and no houses: a full-width snow drift with stars and flakes. |
| **≤ 37** | 2 | **Compact fallback**, no scene: line 1 is the path plus ` · branch` if it fits, line 2 is the short calendar label, context, cost and short model name, each dropped when it no longer fits. |

The numbered strip (50 cells) is used from **96 columns**; below that it shrinks
to a 26-cell strip of `█` and `▒` without numbers. The calendar label shortens
as the street narrows (long → medium → short → none), and each foreground
object (fir, presents, snowman, lamp) is only placed if it fits left of the
terrace.

From **136 columns** the terrace grows leftwards by one 12-column house per 12
extra columns, up to 8 extra houses at 220 columns; beyond that the street
widens instead. Which houses are tall or short, gabled or flat, and which slot
holds the church are deterministic hashes of their position, so a given width
always draws the same village.

Under `NO_COLOR` the scene is still drawn, in uncoloured block glyphs, each
scene row prefixed with a zero-width space and one column narrower. The numbered
strip then shows 24 identical numbers, since door state is carried by colour
alone; the label still tells you the day.

---

## What animates

Everything is derived from `SL_NOW`, plus `SL_TICK` for the colour pulse, so
the picture is a pure function of the clock. The status line refreshes about
once a second.

| Thing | Cycle | Behaviour |
|---|---|---|
| **Snowfall** | continuous | 38 % of columns carry one flake each, in three depths: far flakes are dim, fall 1 pixel per second and drift one column left every 3 s; middle flakes fall 2 pixels per second straight down; near flakes are bright, fall 3 pixels per second and drift right. They wrap from bottom to top. Flakes only fill empty sky, so they pass *behind* the fir, the houses and the snowman. |
| **Stars** | 9 s | 9 % of columns have a star in the upper half of the sky. Each is bright for 5 s of every 9, offset per star. |
| **Baubles** | 7 s | Each bauble is lit for 4 s of every 7, offset by its position, and dim otherwise. From 25 to 31 December they stay lit. |
| **Tree-top star** | 5 s | A cosine colour pulse between deep gold and pale cream. From 25 to 31 December the pulse swings wider. |
| **Today's door** | 5 s | The same 5-second pulse on today's door in the calendar. |
| **Chimney smoke** | 2 s / ~11 s | From 78 columns, each flat-roofed house sends four puffs up from one chimney, the lower two lighter. The plume bobs one pixel every 2 seconds and sways sideways on a slow cosine. |

---

## The advent calendar

The calendar reads the **local date** of the machine running the status line
(`SL_NOW` formatted in the local time zone), so doors open at local midnight.
There are three modes:

**1 – 24 December: advent.** Door *n* is today.

- Doors before today are opened: bold dark numbers on warm gold, alternating
  two shades.
- Today pulses gold (see *What animates*).
- Doors still to come stay dark: dim numbers on deep maroon, alternating two
  shades.
- In the narrow strip, opened doors and today are a `█` in their colour,
  later doors a `▒`.
- Label: `TÜRCHEN 5/24 · NOCH 19 TAGE` (the count is days left until the 24th;
  `NOCH 1 TAG` on the 23rd), shortened to `TÜRCHEN 5/24`, then `5/24`. On the
  24th the long label reads `TÜRCHEN 24/24 · HEILIGABEND`.

**25 – 31 December: Christmas.** All 24 doors are lit, every bauble on the fir
stays lit instead of twinkling, the tree-top star pulses wider, and the label
turns gold: `FROHE WEIHNACHTEN`, then `WEIHNACHTEN`, then `XMAS`.

**1 January – 30 November: sealed.** All 24 doors are drawn in a cold grey on
slate, and the label counts down to 1 December, leap years included:
`ADVENTSKALENDER VERSIEGELT · NOCH 60 TAGE`, then `ADVENT NOCH 60 TAGE`, then
`ADV-60`. On 30 November it reads `NOCH 1 TAG`. The rest of the scene is the
same all year.

---

## The snow window

`christmas.hlsl` is a Windows Terminal pixel shader, used through
`profiles.defaults.experimental.pixelShaderPath`. It covers the whole window,
not just the status line:

- **Sky.** A vertical gradient from near-black navy at the top to deep indigo
  at the bottom.
- **Light.** A warm candle glow rising from just below the bottom edge, about
  a sixth of the way in from the left, and a cold moonlight wash from just
  above the top edge on the right.
- **Snow.** Three parallax layers: a dense, dim layer of small flakes that
  crosses the window in about 33 s, a middle layer (about 18 s) and a sparse
  near layer of the largest, brightest flakes (about 12 s). All drift slightly
  right and weave on a sine as they fall. Flake positions come from a hash of
  each grid cell and Windows Terminal's `Time`, so nothing is random, and the
  shader moves at the terminal's own frame rate rather than the status line's
  one frame per second.
- **Drift.** The bottom 14 % of the window brightens towards the lower edge.
- **Text stays sharp.** The terminal is sampled exactly on its pixel grid, so
  the half-block pixel art is not smeared. A pixel counts as content when its
  colour is measurably away from the scheme background or bright enough;
  content is drawn opaque on top of the night, and everything else becomes the
  night at the window's own acrylic translucency. That is why the theme leaves
  its sky unpainted: those cells show the shader's snow.
- **Magenta knock-out.** Pixels in or near the sentinel magenta `#FF00FF` (the colour
  the framework's border-eraser shader also targets, see the Base README) have
  their colour zeroed and take their opacity from the terminal 26 pixels above,
  or below if that is magenta too.
- A light warm grade is applied over the whole frame.

**When it is applied.** Only on activation, by the switcher: `/sl christmas`
(or `switch.sh set christmas`, `next`, `prev`, `/sl apply-background`) runs
the framework's `terminal-background.py`, whose `christmas` look sets, on
`profiles.defaults`:

- colour scheme `Christmas Night` (added to the settings if missing),
- acrylic on, opacity 72 (unfocused: acrylic, opacity 58),
- `experimental.pixelShaderPath` = `christmas.hlsl`, copied next to Windows
  Terminal's `settings.json` from `~/.claude/statusline/shaders/`.

A render never touches Windows Terminal; `christmas.sh` contains no shader or
settings code at all. Selecting the theme any other way — `CLAUDE_STATUSLINE_THEME`,
a per-project `.claude/statusline-theme`, or editing `selected` by hand — renders
the status line without the window look. If `shaders/christmas.hlsl` is missing when you
activate, the switcher drops the shader setting instead of pointing at
nothing. Activating another theme replaces the whole look with that theme's.
The helper refuses to rewrite a Windows Terminal `settings.json` that contains
`//` comments; see the Base README for its backups and what else it touches.

Outside WSL, or without Windows Terminal, there is no window look: the status
line is unchanged and its sky is simply your terminal's background.

---

## Install

The Base Theme-switcher must already be installed at `~/.claude/statusline/`.
From this folder:

```sh
./install.sh
```

It copies `christmas.sh` into `~/.claude/statusline/themes/` and
`christmas.hlsl` into `~/.claude/statusline/shaders/` (creating that folder if
needed), overwriting earlier copies, and prints `now run /sl christmas`. It
refuses with a message if `statusline.sh`, `core.sh`, `switch.sh` or `themes/`
is missing there. It does not select the theme, does not run `switch.sh` or
`check.sh`, and does not touch Windows Terminal or `settings.json`.

For a framework installed elsewhere:

```sh
SL_HOME=/path/to/statusline ./install.sh
```

Then, inside Claude Code:

```
/sl christmas
```

That selects the theme and, on Windows Terminal under WSL, applies the snow
window. The header declares `@order: 20`, which fixes its place in `/sl list`.

Verify it with the framework's linter:

```sh
~/.claude/statusline/check.sh christmas
```

As shipped here it reports `0 failing check(s)`.

To watch a given day without waiting for December, pin the clock:

```sh
SL_FAKE_NOW=$(date -d '2026-12-05 18:00' +%s) SL_PREVIEW=1 COLUMNS=120 \
  ~/.claude/statusline/statusline.sh --theme christmas \
  < ~/.claude/statusline/sample-payload.json
```

---

## Preview

`preview.ansi` is one frame at 100 columns, rendered on 2 October 2026 (sealed
mode, 60 days to go) with the Base folder's anonymised `sample-payload.json`:

```
      ▄▀▄▄      ▄    ▀           ▄██▀▀          ▀   ▄████▄      ▀      ▀▄         ▄
   ▄ ▀▀██▀                     ▀▀▀▀▀▀▀        ▀    ████▀███    ███     ▀                  ▄
▀   ▄▀▀█▀█▄           ▄      ▀  █▀▀▀█   ▄  ▄   ██  ██▀█▀▀▀█   █▀▀▀▀    ██ ▄    ▄▄
   ▄▀███▀▀█▄   ▀  ▄█▄       █▄▄▄▀▀▀▀▀▄▄▄█     ████████████  ▄███▀██▄  ████████████   ▄████▄
▄▄▄▀▀████▀█▀▄▄▄▄▄█▀█▀█ ▀▀▀  ▀ ▄▀▀▀▀▀▀▀▄       ▀▀▀▀▀▀▀▀▀▀▀▀▄▀▀▀█▀▀▀█▀▀▄▀▀▀▀▀▀▀▀▀▀▀▀ ▄████████▄  ▄
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀█▀▀▀█▀█▀▀▀▀▀▀█████▀▀▀▀▀▀▀▀ ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀ ▀▀▀▀▀▀▀▀▀▀  ▀
▌ ADVENTSKALENDER VERSIEGELT · NOCH 60 TAGE   ▐010203040506070809101112131415161718192021222324▌
▌ /home/example/project · ctx 47% 466k · $222.07 · Opus 5 (1M context) · ✦xhigh
```

Without colour the pixel art is mostly noise; see it properly with:

```sh
cat preview.ansi
```

Regenerate it (this renders the current moment, so the frame and the calendar
mode will differ):

```sh
SL_PREVIEW=1 COLUMNS=100 ~/.claude/statusline/statusline.sh --theme christmas \
  < "../../Base Theme-switcher/sample-payload.json" > preview.ansi
```

---

## Known quirks

- **Smoke at 78 – 95 columns.** The smoke code assumes the 8/6-pixel house
  heights of the taller scenes, but at this width houses are 6/4 pixels. Plumes
  can therefore start from the wrong column, float above the roof, or land
  outside the window and not appear at all.
- **One chimney smokes.** Tall flat-roofed houses have two chimneys; smoke only
  rises from the left one.
- **Unused palette entries.** The `spire` colour and the house sprite codes
  `K` and `S` are defined but no sprite uses them.

None of it affects the linter.

---

## Requirements

- **The Base Theme-switcher**, with a `terminal-background.py` that has the
  `christmas` look (the copy in `../../Base Theme-switcher` does). An older
  copy without it gives Christmas the default `plain` look: no snow window.
- **bash 4.3 or newer.** The theme uses namerefs (`local -n`), `declare -gA`,
  `printf -v` and `printf '%(…)T'`.
- **A truecolour terminal.** Every colour is a 24-bit `38;2`/`48;2` sequence;
  there is no 256-colour fallback.
- **Glyph coverage, no Nerd Font.** Block elements (`▀ ▄ █ ▒ ▐ ▌`), `·`, `✦`,
  `⎇` and `Ü`, plus a zero-width space on rows with nothing drawn. `⎇` (U+2387)
  is the one most likely to be missing from a font.
- **git**, only for the branch segment. Without it the segment is empty.
- **For the snow window only:** Windows Terminal with pixel shader support,
  reached from WSL, and `python3` for the framework's helper. Everything else
  works without it.
- **Cost.** The pixel grid is rebuilt in plain bash every frame and grows with
  terminal width. No gateway call, no transcript scan; the only subprocess is
  the framework's cached `sl_git`.
