# sakura

> Cherry bough and drifting petals over two rows of ink-dark readout

The Base Theme-switcher port of **Liza's sakura theme**. Her delivery, in
[`../sakura-theme/`](../sakura-theme/), is a Claude Code palette, a Windows
Terminal colour scheme and an animated cherry-blossom wallpaper. It ships no
status line. This folder adds one written to match it, and lets the switcher
put her wallpaper and palette in place whenever `/sl sakura` is selected.

It is a **light** theme. The status line paints no background at all, so her
wallpaper shows through behind it, and the readout is dark ink meant to be read
against that pale sky.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━──────────╌╌╌╌╌╌╌
  ❀ ╱             ❁      ∙             ✿╱ ❀   ✿  ╲✿                        ∙  ❀
  ❀❀ ❀         ❁ ❀                    ✿✿  ∙      ❁  ✿       ✿                                  ✿
                                                                       ❀                 ❀
                   ∙                          ✿
▌ /home/example/project · +696/-276
▌ Opus 5 (1M context) · xhigh effort · ━━━━━─────── 47% · $222.07
```

A real render at 100 columns against the Base Theme-switcher's anonymised
`sample-payload.json`, escapes stripped. `cat preview.ansi` shows it in colour.

## What's in here

| File | Goes to | Whose | What it is |
|---|---|---|---|
| `sakura.sh` | `~/.claude/statusline/themes/` | ours | the status line theme |
| `assets/sakura.json` | `~/.claude/statusline/assets/sakura/` | **Liza's, verbatim** | her Claude Code palette |
| `assets/sakura-blossom.gif` | `~/.claude/statusline/assets/sakura/` | **Liza's, verbatim** | her wallpaper, 960×540, 300 frames, about 2 MB |
| `install.sh` | — | ours | copies the three files above into place |
| `preview.ansi` | — | ours | a real render in colour, 100 columns |
| `README.md` | — | ours | this |

"Verbatim" is checked, not asserted. Both assets are byte-identical to
`../sakura-theme/sakura-theme/` (`cmp` returns nothing):

| File | SHA-256 |
|---|---|
| `sakura.json` | `d99d0465420c0f8eb807c4f17ea6f1cb3b4ef5d2ca1aa61e3c6eb556e1f3c2f0` |
| `sakura-blossom.gif` | `f0d174e0b655d79e88e68e1d118252d6e5bedb90935479a4d59f6fa401188f87` |

`sakura.sh` matches none of her files. It is new work.

Her Windows Terminal scheme and tab-row theme are not files here. They are
entries in the framework's `terminal-background.py`, which ships separately
with the Base Theme-switcher. Its `Sakura` colour scheme is identical, key for
key, to `SAKURA_SCHEME` in her `theme.sh`. Its `Sakura` tab-row theme matches
her `SAKURA_WT_THEME` in everything except the name, which she spelled
lower-case.

Not shipped from her delivery: `theme.sh`, `install.sh` and `sl.md` (her own
switcher and her own `/sl` command; this framework already has both, and hers
would replace them), and `sakura_gen.py` (the wallpaper generator; nothing
needs to regenerate the GIF). They stay in `../sakura-theme/`, unedited.

## What the status line shows

Seven rows at every width: five rows of sky, two rows of readout.

**The sky.**

- **Row 1** is a bough across the left 55 % of the width. It thins as it goes,
  heavy `━` for the first 68 %, then `─`, then a dotted `╌` tip for the last
  12 %. Below eight cells it spans the whole width instead.
- **Rows 2–3** hang blossom clusters off it: a `╱` or `╲` twig and three to
  five blossoms (`❀ ❁ ✿`) each, alternating between two shades of plum. There
  are `2 + bough ÷ 26` clusters, so four at 100 columns. Their positions are
  hashed, fixed for a given width, and do not move.
- **Rows 2–5** carry drifting petals, `width ÷ 9 + 4` of them (14 at 100
  columns), each at one of three depths.

Depth runs the opposite way from a dark theme. On a pale background contrast
falls as things recede, so the near petal is the darkest thing on screen and
the far one the palest.

| Depth | Glyph | Colour | Falls a row every | Drifts |
|---|---|---|---|---|
| near | `❀` | dark plum | 1 s | 1.5 cells/s |
| mid | `✿` | dusty rose | 2 s | 1 cell/s |
| far | `∙` | pale pink | 3 s | 0.5 cells/s |

**The readout.** Both rows start with a plum `▌` gutter.

| Row | Shown | Source |
|---|---|---|
| 6 | current path | `SL_PATH`, shortened from the left to fit |
| 6 | git branch, with `↑n` / `↓n` ahead and behind | `sl_git`, cached by the framework for 4 s |
| 6 | session diffstat, `+696/-276` | `SL_LINES_ADDED` / `SL_LINES_REMOVED` |
| 7 | model name, short then full | `SL_MODEL_SHORT` / `SL_MODEL_NAME` |
| 7 | reasoning effort, prefixed `ultracode ·` when that setting is on | `SL_EFFORT`, `SL_ULTRACODE` |
| 7 | a 12-cell context gauge and the percentage | `SL_CONTEXT_PERCENT` |
| 7 | session cost | `SL_COST_TEXT` |

The context percentage and the gauge turn error red at 85 %.

Not read: weekly gateway spend, session duration, token counts, remaining
context, fast mode, thinking, version, output style, session id, repository
identity.

## What animates

**The petals, and nothing else.** The bough, the clusters and the readout are
static.

- Each petal falls one row at its depth's rate and wraps from row 5 back up
  to row 2. The rate is integer division of `SL_NOW`.
- It drifts **rightward** at its depth's rate and wraps around the width. Her
  wallpaper's petals blow leftward, so the two pass each other.
- It sways ±2 cells on a 23-second cosine, each petal on its own phase. The
  sway reads `sl_phase`, which runs off `SL_TICK` (centiseconds).

Every position is computed from the clock, never from `$RANDOM`, so a fixed
`SL_FAKE_TICK` always produces the same bytes. Measured against the sample
payload: two renders at the same tick are byte-identical.

The header comment in `sakura.sh` claims more than that. It says petals are
"a pure function of `SL_NOW`" and that "two renders of the same second are
identical". **That is not true.** The sway reads `SL_TICK`, and sampling one
second at every centisecond gave six distinct frames. Sampling five ticks in
each of 23 consecutive seconds gave three to five frames per second. The theme
still meets the framework contract (identical bytes for an identical frame).
The comment overstates it, and is reproduced verbatim here anyway.

## Colours

Ten of the twelve distinct colours in `sakura.sh` are taken straight from her
`sakura.json`.

| Used for | RGB | Her key |
|---|---|---|
| near petal, branch, effort, gauge fill, gutter | 117 27 72 | `effortUltra`, `clawd_body` |
| blossom heart | 100 24 62 | `claude` |
| bough | 95 53 33 | `bashBorder` |
| path, percentage | 16 26 38 | `text` |
| separators, cost | 66 62 72 | `subtle` |
| model name | 19 67 105 | `ide` |
| ahead marker, lines added | 12 74 46 | `success` |
| behind marker | 78 48 3 | `warning` |
| lines removed, context and gauge at 85 % | 128 16 32 | `error` |
| gauge track | 190 170 180 | `rate_limit_empty` |

The mid petal (168 84 122) and the far petal (200 146 170) are ours. They are
not in her palette. Each is a step from the near petal toward the pale end so
that depth reads as distance.

## How the wallpaper and palette get applied

`sakura.sh` never touches a terminal or a settings file. Switching does.

`/sl sakura` runs `switch.sh set sakura`. On activation, and only then, it
calls `terminal-background.py sakura`. That script finds Windows Terminal's
`settings.json` itself and applies the `sakura` look:

- **Windows Terminal, `profiles.defaults`.** It sets the `Sakura` colour
  scheme (adding it if the profile lacks one), turns acrylic off, sets opacity
  to 100 and removes any pixel shader. A shader on an opaque window would cover
  the background image.
- **The wallpaper.** It copies `assets/sakura/sakura-blossom.gif` next to
  Windows Terminal's `settings.json` and points `backgroundImage` at its
  Windows path, at 0.7 opacity, `uniformToFill`, centred. These are the same
  values her `theme.sh` uses.
- **The tab row.** It adds the `Sakura` tab-row theme if missing and selects
  it.
- **The Claude Code palette.** It copies `assets/sakura/sakura.json` to
  `~/.claude/themes/sakura.json` and sets `"theme": "custom:sakura"` in
  `~/.claude/settings.json`.

Before the first change it records whatever each of those settings
displaced, under `~/.claude/statusline-state/`. Switching to a theme whose look
does not declare them puts back your own wallpaper, tab theme and palette, and
removes keys that were not there before. Each write takes a timestamped backup,
goes through a temporary file, and is re-parsed before it replaces the
original.

As her README says, Claude Code sometimes keeps the old palette until you
reselect it in `/config` or restart.

Without WSL and Windows Terminal, or without `python3`, the script changes
nothing. The status line works anyway.

## Install

The Base Theme-switcher must already be installed. Its `terminal-background.py`
must carry the `sakura` look if you want the wallpaper and the palette.

```sh
./install.sh
/sl sakura
```

`install.sh` copies `sakura.sh` to `$SL_HOME/themes/` and both assets to
`$SL_HOME/assets/sakura/`. `SL_HOME` defaults to `$HOME/.claude/statusline`.
It refuses if `statusline.sh`, `core.sh` or `themes/` is missing there. It
prints a note if `terminal-background.py` has no `sakura` look. It does
**not** select the theme or touch any terminal setting; selecting is up to you.

By hand:

```sh
mkdir -p ~/.claude/statusline/assets/sakura
cp sakura.sh ~/.claude/statusline/themes/
cp assets/sakura.json assets/sakura-blossom.gif ~/.claude/statusline/assets/sakura/
```

Then `/sl sakura`.

Check it:

```sh
~/.claude/statusline/check.sh sakura
```

## Requirements

- **The Base Theme-switcher**, and bash 4.2 or later for its core.
- **A light background.** The readout ink is `rgb(16,26,38)`. On a dark
  terminal it is close to invisible. The `sakura` look provides the background.
  On a terminal the switcher cannot restyle, give it a pale scheme yourself.
- **A truecolour terminal.** Under `NO_COLOR` the theme still draws all seven
  rows, glyphs only, with the gauge as plain `━`/`─`.
- **Glyphs for `❀ ✿ ❁ ∙`** plus the box-drawing set. If the blossoms come out
  as boxes, the font and its fallback lack the Dingbats block.
- **For the wallpaper and palette:** WSL, Windows Terminal and `python3`, used
  by `terminal-background.py` on activation. The status line itself needs no
  Python.
- **Cost:** 0.33 to 1.0 s per render at 100 columns, measured on a machine
  running at a load average of about 24. The figure is noisy and an upper
  bound, not a benchmark.

## Preview

```sh
cat preview.ansi
```

It was made with:

```sh
SL_PREVIEW=1 COLUMNS=100 ~/.claude/statusline/statusline.sh --theme sakura \
  < "Base Theme-switcher/sample-payload.json"
```

Set `SL_FAKE_TICK=<epoch centiseconds>` to pin a frame.

## Uninstall

Switch away first, so the switcher hands back your own wallpaper, tab theme and
palette:

```sh
/sl <something-else>
rm ~/.claude/statusline/themes/sakura.sh
rm -r ~/.claude/statusline/assets/sakura
```

The copies the switcher made, `~/.claude/themes/sakura.json` and
`sakura-blossom.gif` next to Windows Terminal's `settings.json`, are unused
from then on. Delete them if you want them gone.

## Credits

The palette, the colour scheme, the tab-row theme, the wallpaper and the whole
look are **Liza's**. The status line rows, the installer and this README are
port work so her theme runs on the Base Theme-switcher.
