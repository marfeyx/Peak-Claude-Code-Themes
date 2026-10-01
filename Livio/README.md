# Livio

Four status line themes for the **Base Theme-switcher**, adapted from Livio's own
Python status line framework. His renderers do the drawing; everything in this
folder that is not his is the layer that makes them fit this repo's engine.

| `/sl` | theme | what it is |
|---|---|---|
| `/sl 40` | [`aquarium`](aquarium/) | a tank whose water level is the context window you have left |
| `/sl 41` | [`kyoto`](kyoto/) | a calm Kyoto valley — sakura, a waterfall, a slow river |
| `/sl 42` | [`vice`](vice/) | a Vice City panorama on a day-night cycle, context as a wanted level |
| `/sl 43` | [`spectrum`](spectrum/) | three information rows under a drifting rainbow rule |

All four pass `check.sh` with **zero failing checks** at 30, 40, 50, 60, 80, 100,
160 and 220 columns plus `NO_COLOR`.

## Layout

```
Livio/
  README.md            this
  shared/              the Python every theme imports, and the adapter layer
  aquarium/            one folder per theme: wrapper, renderer, README, preview, installer
  kyoto/
  vice/
  spectrum/
  upstream/            Livio's delivery, byte-identical and unexecuted
```

Each theme folder is self-contained **except** for `shared/`, which all four
import. That is the one place the Python lives; no module is duplicated between
theme folders, and every `install.sh` copies `shared/` alongside its own modules.

## Install

The Base Theme-switcher must already be installed at `~/.claude/statusline/`.

```sh
./kyoto/install.sh
```

That copies `shared/*.py`, `shared/wrapper.sh` and the theme's own modules into
`~/.claude/statusline/vendor/livio/`, the bash wrapper into
`~/.claude/statusline/themes/`, selects the theme and runs the linter. Install
somewhere else with `SL_HOME=/path/to/statusline ./kyoto/install.sh`.

By hand, if you prefer:

```sh
mkdir -p ~/.claude/statusline/vendor/livio
cp shared/*.py shared/wrapper.sh ~/.claude/statusline/vendor/livio/
cp kyoto/kyoto.py kyoto/kyotogif.py ~/.claude/statusline/vendor/livio/
cp kyoto/kyoto.sh ~/.claude/statusline/themes/
```

Then `/sl kyoto`. Installing all four is the same four files plus each theme's
modules; they share one `vendor/livio/` directory and do not collide.

`python3` is required — these are Python renderers behind a bash wrapper. Stdlib
only, no pip, no network.

## Whose file is which

Livio's code is **never edited**. Not in `upstream/`, not in the theme folders.
Every adaptation is done from the outside, by patching his module objects at
import time, so a future delivery from him is a file copy rather than a merge.

| Path | Whose | Note |
|---|---|---|
| `upstream/**` | **his** | the delivery as it arrived, byte-identical |
| `shared/common.py` | **his** | verbatim copy of `upstream/statuslines/common.py` |
| `shared/octants.py` | **his** | verbatim; the generated 2×4 glyph table |
| `aquarium/water.py`, `water2.py`, `watergif.py` | **his** | verbatim |
| `kyoto/kyoto.py`, `kyotogif.py` | **his** | verbatim |
| `vice/vice.py` | **his** | verbatim |
| `spectrum/rgb.py` | **his** | verbatim |
| `shared/render.py` | ours | the bridge: width, colour, clock, config safety |
| `shared/wrapper.sh` | ours | the bash launcher all four wrappers source |
| `shared/gifwriter.py` | ours | an **inert stub** replacing his GIF writer |
| `*/[theme].sh` | ours | the theme file the framework actually loads |
| `*/install.sh`, `*/README.md`, `*/preview*.ansi` | ours | packaging |

`shared/common.py` and `shared/octants.py` are byte-identical to
`upstream/statuslines/`, as are all seven theme modules. `cmp` them if you want
to check.

## What the adapter layer does

`shared/render.py` is the whole adaptation, and it exists because his framework
and this one disagree about five things. Each item below is something his
renderers do that this engine's linter would reject.

- **Width.** He renders against `COLUMNS` minus 2. This engine budgets against
  `SL_COLUMNS`, which is `COLUMNS` minus 4, and `check.sh` fails any row wider
  than that. Measured: every scenery row of `aquarium`, `kyoto` and `spectrum`
  comes out exactly 2 cells over budget at every width, and **`vice` comes out
  at twice the budget** — 196 cells at 100 columns, 276 at 140 — because
  `vice.scene` builds its canvas from the pixel width rather than the text
  width. The bridge zeroes his padding, clamps vice's canvas, sheds tail
  segments from the text rows, and clips every row cell-accurately as a backstop.
- **Determinism.** All four call `time.time()` in the render path and `vice`
  also calls `time.localtime()`. Two renders of the same second have to be
  byte-identical or the line flickers, so the bridge replaces the time module
  each one imported with a shim pinned to `SL_NOW`.
- **Processes.** `common.git_branch` forks `git` once per frame and
  `common.weekly_spend` forks a shell to refresh a cache under `/tmp`. Both are
  replaced with values this engine has already resolved, so no frame forks
  anything.
- **`NO_COLOR`.** None of them honour it — they only know
  `STATUSLINE_NO_TRUECOLOR`, and even those fallback paths still emit
  256-colour escapes. The bridge asks for the fallback and then strips every
  escape itself.
- **Blank rows.** Claude Code silently discards a status row that is empty once
  escapes are stripped, which would shorten a panel without saying so. Such
  rows get a zero-width space, and the cell it occupies is budgeted for
  *before* the clip rather than appended after it.

## What was deliberately left out

### The Windows Terminal backgrounds

His bundle's best trick does not ship, and this is a design disagreement rather
than a criticism — the feature is genuinely impressive and the implementation is
careful about backups.

`sl-water-bg.py` points a Windows Terminal profile at a pre-rendered animated
GIF so the whole window becomes the aquarium, the valley or the bay. The GIFs
are generated once on first switch by `watergif.py`, `kyotogif.py` and
`vicegif.py` (vice's set is 144 bands and takes about nine minutes).

The problem is **where it is called from**. `water.sync_band` and
`vice.sync_background` invoke `sl-water-bg.py` *from inside a render* — once per
frame, roughly once a second — and that script rewrites Windows Terminal's
`settings.json`. A status line is a hot path that runs on every keystroke-ish
redraw; it must never write configuration. This repo has already shipped that
bug once and left a terminal with a background image its owner could not remove.

So the whole mechanism is out:

| Not shipped | Why |
|---|---|
| `sl-water-bg.py` | rewrites `settings.json`, reached from a render |
| `vicegif.py` | pure generator, nothing at runtime imports it |
| `gifwriter.py` (his) | replaced by an inert stub that raises if called |
| the generated GIFs | nothing points a profile at them any more |

`watergif.py` and `kyotogif.py` *do* ship, because the themes import them for
art constants and two timing values, not to generate anything —
`kyoto.py` does `import kyotogif as art` and pulls twenty names out of it, so
dropping it means kyoto does not render at all. Their `build_all` entry points
are never wired to anything, and the `gifwriter` they would need is the stub,
which raises rather than writing a file. Belt and braces: the bridge forces
every `gif_mode()` to `False`, so the branches containing those calls are
unreachable, and replaces the two sync functions with no-ops anyway.

Verified, not asserted: 36 renders across all four themes and every pixel mode
left `~/.claude/settings.json` and Windows Terminal's `settings.json`
byte-identical, and created no `claude-statusline` directory.

**The sanctioned route still exists.** The engine applies terminal looks from
the `LOOKS` table in `~/.claude/statusline/terminal-background.py`, which
`switch.sh` calls **on activation only** — never from a render. It discovers the
settings path, snapshots what it displaces *before* the first application, takes
a timestamped backup, writes through a temp file and re-parses it before
replacing the original. If one of these themes should get a window background,
that is where the entry belongs. None of the four has one today, so switching to
them resets the terminal to the plain look and properly restores whatever the
previous theme had installed.

### His framework

Four files whose only purpose is to *be* a status line framework. This repo
already has one, and running his would replace it.

| Not shipped | What running it would do |
|---|---|
| `install.sh` | repoints `statusLine` in `settings.json` at his dispatcher and overwrites `commands/sl.md` — the live system goes off the air |
| `sl-switch.sh` | a second, competing switcher with its own state file |
| `statusline.py` | his dispatcher; `statusline.sh` + `switch.sh` is this one |
| `commands/sl.md` | replaces this framework's `/sl` command |

They are kept under `upstream/` for reference. **Do not execute them.** They are
stored without the execute bit for that reason.

### `water2` as a fifth theme

His `water2` is not a separate theme — it is `water` at 2×4 octant pixel
resolution, importing `water` for its physics, geometry, palette and info row.
Shipping it as a fifth entry would put three reef scenes in a list that already
has a native `underwater` theme. It is exposed as a resolution knob instead:
`SL_AQUARIUM_PIXELS=octant`, mirroring the `SL_KYOTO_PIXELS` / `SL_VICE_PIXELS`
pattern his own themes use. `water2.py` ships unmodified and
`aquarium/preview-octants.ansi` is a real render of it.

## Known issues

- **`SL_KYOTO_PIXELS=half` and `SL_VICE_PIXELS=half` do not work.** Both are
  documented upstream as the fallback for a font without Unicode 16 octants, and
  both render a flat band of `▀` with no scenery instead. This is **upstream
  behaviour, not the bridge** — verified by rendering his modules directly,
  outside this framework, with the same result. `make_layer` is handed pixel
  dimensions sized for the 2×4 octant grid and `Pixels` interprets them as 1×2,
  so the art lands off-canvas. Nothing in this folder works around it, because
  nothing in this folder edits his source. Consequence: **`kyoto` and `vice`
  effectively require an octant-capable font.** `aquarium` is the half-block
  renderer natively and is unaffected.
- A git branch longer than roughly 30 characters is **shed whole** rather than
  truncated, because the bridge sheds at separator boundaries. The branch used
  in every measurement here is 70 characters, which is why it only appears past
  103–147 columns depending on the theme. Each theme README gives the measured
  numbers.

## Credits

The renderers, the art, the physics, the day-night cycle and the whole idea are
Livio's. The bridge, the wrappers, the packaging and this documentation are
adaptation work so his themes run on the Base Theme-switcher in this repo.
