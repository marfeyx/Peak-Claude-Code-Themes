# meadow

> A cat walking through overgrown grass, under a sky that turns day to night

Laibah's `meadow` theme, ported onto the Base Theme-switcher. The bottom of the
terminal becomes a strip of overgrown grass with a cat and a few flowers in it,
and behind the whole window an animated pixel sky moves from day through sunset
to night and back on a half-hour loop. The terminal's colour scheme and Claude
Code's own palette follow the sky off the same clock.

The panel is **transparent**: nothing in it paints a background except the
soil, so the sky shows through between the blades. Without the sky it is grass
on whatever your terminal background already is.

```
                           ▀▀▀       ▀▀▀                  ▄          ▄
 ▄▀▄                       ▀▀         ▀      ▀   ▄▀▄      ▀          ▀        ▀        ▄
  ▀               ▀       ▄▀▀  ▀ ▄   ▄▀ ▄     ▀ ▄▄▀ ▄▀▀▄▄▀▀▄         ▀▄   ▀   ▀▄      ▄▀ ▀
  ▀▄           ▀  ▀       ▀▀▀  ▀▀▀▀  ▀▄ ▀  ▀  ▀▀▀▀▀▄ ▀▀▀▀▀▀▀▀         ▀▄ ▄▀    ▀▄     ▀ ▀ ▀
  ▄▀▀         ▀▀▄ ▀▀      ▀▀▀  ▀▀▀▄▄ ▀▀▀▄ ▀▀▀▄▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀         ▀▀▄▀▀    ▀▀  ▄ ▀▄ ▀▀▀▀▄
  ▀▀▀▄▄▀▀   ▄▄▀▀▀▀▀▀ ▀▀▄▄ ▀▀▀▀▀▀▀▀▀▀ ▀▀▀▀▄▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▄▀  ▀▀▀▀▀▀▀▀  ▄▀▀▀▄▄▀▀▀▀▀▀▀▀▀▄▀▀▄
▄▄▀▀▀▀▀▀▀▀▄▄▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▄▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▄▀▀▀▄▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
▀ctx 47%  ·  /home/example/project  ·  Opus 5 (1M context)  ·  $222.07▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
```

Real render, 100 columns, escapes stripped, from the anonymised
`Base Theme-switcher/sample-payload.json`. It reads far better in colour:
`cat preview.ansi`.

## Whose file is which

Laibah's delivery is in `../meadow-theme/` and `../meadow-theme.zip`, written
for her own status line framework. Neither is touched by this folder. Everything
here was checked against
`../meadow-theme/meadow-theme/claude/` with `cmp`:

| File | Goes to | Whose | `cmp` against her delivery |
|---|---|---|---|
| `vendor/agentcount.py` | `vendor/meadow/` | **Laibah's** | identical to `statuslines/agentcount.py` |
| `vendor/common.py` | `vendor/meadow/` | **Laibah's** | identical to `statuslines/common.py` |
| `vendor/daylight.py` | `vendor/meadow/` | **Laibah's** | identical to `statuslines/daylight.py` |
| `vendor/meadow.py` | `vendor/meadow/` | **Laibah's** | identical to `statuslines/meadow.py` |
| `vendor/meadowsky.py` | `vendor/meadow/` | **Laibah's** | identical to `statuslines/meadowsky.py` |
| `vendor/gifwriter.py` | `vendor/meadow/` | **Laibah's, edited by us** | differs from `statuslines/gifwriter.py` — see below |
| `assets/meadow/meadow.json` | `assets/meadow/` | **Laibah's** | identical to `themes/meadow.json` |
| `assets/meadow-night/meadow-night.json` | `assets/meadow-night/` | **Laibah's** | identical to `themes/meadow-night.json` |
| `vendor/render.py` | `vendor/meadow/` | ours | no counterpart; the bridge |
| `vendor/skyband.py` | `vendor/meadow/` | ours | no counterpart; one answer to "which band is on screen" |
| `vendor/skydriver.py` | `vendor/meadow/` | ours | **same name as hers, different file** — a rewrite that replaces `statuslines/skydriver.py` |
| `meadow-sky.py` | statusline root | ours | a rewrite of her `sl-meadow-sky.py`: keeps her segment naming and manifest, drops the settings writes |
| `meadow.sh` | `themes/` | ours | the theme file the framework loads |
| `install.sh`, `README.md`, `preview.ansi` | — | ours | packaging |

**`gifwriter.py` is the one to watch.** It is her file with one change: the
finished GIF is written to a temporary file and moved into place with
`os.replace`, instead of being written straight to its final path, so a build
that dies halfway cannot leave a truncated sky for Windows Terminal to load. Its
header is unchanged and says nothing about the edit, and the docstring at the
top of `render.py` claims every vendored module beside it is a byte-identical
copy of upstream. For `gifwriter.py` that claim is wrong. Nothing here edits it
back — the files in this folder are byte-identical copies of the installed
port — but a future refresh from Laibah that overwrites `gifwriter.py` drops
the atomic write.

### What of hers does not ship

| Not shipped | Why |
|---|---|
| `install.sh`, `uninstall.sh` | install her framework, repointing `statusLine` and overwriting `/sl` |
| `claude/statusline.py`, `claude/sl-switch.sh`, `claude/commands/sl.md.template` | her dispatcher and switcher; `statusline.sh` and `switch.sh` are this framework's |
| `claude/sl-meadow-sky.py` | builds the sky **and** rewrites Windows Terminal's and Claude Code's settings; the build half lives on as `meadow-sky.py`, the write half is `terminal-background.py`'s band mode |
| `claude/sl-cc-theme.py` | switches Claude Code's palette; `terminal-background.py` does that, with a snapshot of what it displaced |
| `claude/sl-water-bg.py` | a background driver for another theme |
| `statuslines/skydriver.py` (hers) | spawned her `sl-meadow-sky.py apply` and trusted `WT_SESSION`; replaced by ours |
| `statuslines/preview_meadow.py`, `preview_png.py`, `preview.png` | PNG preview tooling; `preview.ansi` stands in |

Her `meadow.render()` is never called either. The bridge rebuilds the same
frame from her `scene()` and `draw_info()` so it can pin the clock, which also
means the `skydriver.tick(p)` call inside her `render()` is unreachable. Keep it
that way: our `tick()` takes a timestamp, not a phase, so wiring her `render()`
back in would silently ask for the wrong band.

## What the bridge does

`vendor/render.py` reads the payload and prints finished rows, and
`meadow.sh` hands them to `sl_emit_raw` unclipped, because clipping thousands of
truecolour escapes in bash costs seconds. Her modules are patched from outside
at import time, never edited:

- **Width.** Renders against `SL_COLUMNS` and clips every row in terminal
  cells, so a wide glyph in a path cannot push a row over.
- **Clock.** Animation and day phase come from `SL_NOW`, so two renders of the
  same second are identical and `SL_FAKE_NOW` pins the sky as well as the grass.
- **No forks.** Her per-frame `git branch` is replaced with the branch the
  framework already resolved.
- **`NO_COLOR`.** Escapes are stripped by the bridge. Her 256-colour fallback is
  deliberately not used — it draws the field in colour alone — so the
  half-block glyphs survive and the panel stays legible.
- **Blank and trailing.** A row that is empty once stripped gets a zero-width
  space; trailing spaces are trimmed only on rows that paint no background.
- **Height.** `SL_MEADOW_ROWS`, default 9, clamped to 4…16 in both the wrapper
  and the bridge.
- **Quiet renders.** Under `SL_PREVIEW` or a pinned clock the subagent counter
  is suppressed (it caches a transcript offset in the temp directory) and the
  sky is never driven.

## How the day-to-night sky works

Three parts, and only one of them runs inside a frame.

**Built once, by `meadow-sky.py`.** The sky is a 30-minute loop (`1800` s) cut
into six segments, one animated GIF each, 320×180 at half a second per frame.
Windows Terminal gives no way to read or seek a background GIF's playback, so
re-pointing the profile at the next file is the only reliable way to keep the
sky on the clock the grass reads; Laibah's segmenting is what makes that work.
Every frame carries its own colour table over pixels that never change, which
is how a whole day fits in roughly 13 MB (the switcher's figure). `meadow-sky.py build` renders the set beside Windows Terminal's
`settings.json`, in a `claude-statusline-sky/` folder inside the terminal's own
package data (`SL_MEADOW_SKY_DIR` overrides). A manifest is deleted first and
written last, so a half-finished set reads as stale and is rebuilt rather than
applied. By the code's own account the full set takes about a minute; that was
not re-measured for this export. `dir`, `image` and `status` are read-only
queries.

**Applied by the switcher.** `/sl meadow` runs `switch.sh`, which calls the
framework's `terminal-background.py meadow` once, on activation. That points
`profiles.defaults` at the segment the clock is in — or renders and applies a
single static midday sky if no set exists yet — selects the `Meadow` or
`Meadow Night` colour scheme, copies the matching palette from `assets/` into
`~/.claude/themes` and selects it in Claude Code, records meadow
as the owner of the background after snapshotting what it displaced, and then
starts `meadow-sky.py build` in a detached process if the set is stale. The
meadow entry in that file is maintained with the Base Theme-switcher, not here.
Switching to any other theme hands the background back and clears meadow's
ownership.

**Advanced at band crossings, by `skydriver.py`.** After the rows are written,
the bridge calls `skydriver.tick()`. It compares the band the clock asks for —
segment plus light/dark, from `skyband.py` — against the band recorded in
`~/.claude/statusline-state/meadow-applied.json`. On all but six frames per
cycle they match and it returns, having read one small file and written
nothing. Darkness is read at the segment's midpoint, so the scheme only ever
flips on a boundary where the image is changing anyway: six crossings per cycle,
two of them scheme changes.

On a mismatch it still refuses unless **all** of these hold:

- the render is not a preview and the clock is not pinned (`SL_PREVIEW`,
  `SL_FAKE_NOW`, `SL_FAKE_TICK` all switch it off);
- `SL_MEADOW_DRIVE_SKY` is not `0`;
- `selected` names meadow;
- `statusline-state/background-owner` names meadow — written only once an
  activation has actually applied the look and taken its snapshots;
- `terminal-background.py` exists;
- there is a Windows Terminal to drive: `WT_SESSION` in this process or any of
  its twelve nearest ancestors, or failing that a WSL kernel with a Windows
  Terminal `settings.json` that can be found (`SL_WT_SETTINGS` overrides).

Then it takes a lock and starts `terminal-background.py band meadow <segment>
<light|dark>` detached, and returns. The frame waits for those checks and the
spawn, never for the settings write. Band mode is the narrowest write the
switcher has: background image, colour scheme and Claude Code palette only, no
snapshot, and it refuses outright unless meadow owns the background and the
snapshots already exist.

Honest limits of those guards:

- **The lock is not a mutex.** It is a check of the lock file's age followed by
  an atomic replace, so two sessions crossing in the same instant can both
  spawn. Band mode's writes are idempotent, so the cost is a duplicate apply.
- **A failing apply retries every three minutes.** The lock is released only by
  a successful band write. If the write keeps refusing — `//` comments in
  `settings.json`, a missing snapshot — the lock expires after 180 s and the
  next frame tries again, indefinitely, one detached process each time.
- **`tick()` itself does not catch exceptions.** The bridge wraps the call, so a
  failure there costs nothing but the sky staying where it is.

**Static sky, no writes: `SL_MEADOW_DRIVE_SKY=0`.** Set it in the environment
Claude Code runs the status line in. Every frame then stops at the guard list
above, before the lock: no lock file, no state file, no spawned process, no
settings write. The sky stays on whatever band the last activation applied and
keeps replaying that segment's GIF on a loop; it simply never moves on to sunset
or night. Activation is unaffected — `/sl meadow` still applies the look and
starts the build, because that is the switcher's job, not the frame's. One
thing the switch does not cover: the subagent counter in her `agentcount.py`
still caches a transcript offset in the temp directory on live renders.

## What data it shows

One info row under the grass, segments shed lowest priority first:

| Shown | Field | Measured appearance with the sample payload |
|---|---|---|
| context used | `context_window.used_percentage` | always |
| subagents in flight | read from the transcript tree; empty when none run | live renders only |
| current path | `workspace.current_dir`, shortened to 34 characters | from 39 columns |
| git branch | resolved by the framework, never forked per frame | when there is one |
| model | `model.display_name` | from 63 columns |
| session cost | `cost.total_cost_usd` | from 75 columns |

The panel is 9 rows at every width from 30 to 220 columns. Under `NO_COLOR` it
is the same 9 rows with the glyphs and no escapes.

## Requirements

- **The Base Theme-switcher**, installed. `install.sh` refuses without it.
- **`python3`**, standard library only.
- **A truecolour terminal** and a font with `▀` and `▄`, which nearly every
  monospace font has.
- **For the sky: Windows Terminal under WSL**, and a `terminal-background.py`
  that carries the meadow look. Without either, the grass renders and the sky
  half quietly does nothing.
- **Cost: roughly 0.4–0.85 s per render** at 100 columns on this machine,
  five warm preview renders including Python startup and the framework. Inside
  the one-second refresh, without much to spare.

## Install

With the Base Theme-switcher already at `~/.claude/statusline/`:

```sh
./install.sh
```

It copies `meadow.sh` into `themes/`, the nine modules into `vendor/meadow/`,
`meadow-sky.py` into the statusline root and the two palettes into
`assets/meadow/` and `assets/meadow-night/`. Somewhere else:
`SL_HOME=/path/to/statusline ./install.sh`. It does not select the theme and
does not build the sky; it ends with `now run /sl meadow`, and that is the step
that applies the look and starts the build.

By hand:

```sh
SL=~/.claude/statusline
mkdir -p "$SL/vendor/meadow" "$SL/assets/meadow" "$SL/assets/meadow-night"
cp vendor/*.py "$SL/vendor/meadow/"
cp meadow-sky.py "$SL/"
cp assets/meadow/meadow.json "$SL/assets/meadow/"
cp assets/meadow-night/meadow-night.json "$SL/assets/meadow-night/"
cp meadow.sh "$SL/themes/"
```

Then `/sl meadow`, or `/sl 30` from the `@order: 30` header. Check it with
`~/.claude/statusline/check.sh meadow`; this copy passes with zero failing
checks.

## Tuning

| Variable | Default | Effect |
|---|---|---|
| `SL_MEADOW_ROWS` | `9` | panel height, clamped to 4…16 |
| `SL_MEADOW_DRIVE_SKY` | `1` | `0` freezes the sky on its current band and stops all per-frame writes |
| `SL_MEADOW_PERIOD` | `1800` | seconds per day cycle, minimum 30; must reach both the render and the build, see Known issues |
| `SL_MEADOW_SEGMENTS` | `6` | segments per cycle, 1…60; changing it makes the built set stale |
| `SL_MEADOW_PHASE` | — | pins the cycle: a number in `[0,1)` or `day`, `sunset`, `night`, `dawn` |
| `SL_MEADOW_SKY_DIR` | beside `settings.json` | where the sky GIFs are built |
| `SL_WT_SETTINGS` | discovered | the Windows Terminal `settings.json` to use |

## Known issues

- **The period file is shadowed in renders.** `skyband.py` re-points her
  `daylight.py` at `~/.claude/statusline-state/meadow-period` so a persisted
  period works. But `render.py` sets `SL_MEADOW_PERIOD` to `1800` whenever it is
  unset, and the environment wins over the file, so a render never reads it —
  while activation and `meadow-sky.py build`, which do not go through the
  bridge, do. A period stored only in that file therefore makes the sky and the
  grass disagree. Set `SL_MEADOW_PERIOD` in the environment instead, or leave
  the default.
- **Settings discovery assumes the default WSL mount.** Both `meadow-sky.py` and
  `skydriver.py` look for `/mnt/c/Users/*/AppData/Local/Packages/
  Microsoft.WindowsTerminal*/LocalState/settings.json`. No username is in it,
  but a non-default automount root or a profile on another drive will not be
  found. `SL_WT_SETTINGS` overrides it.
- **`gifwriter.py` is edited and does not say so** — see Whose file is which.

## Preview

```sh
cat preview.ansi
```

Regenerate it the way it was made:

```sh
SL_PREVIEW=1 COLUMNS=100 ~/.claude/statusline/statusline.sh --theme meadow \
  < "../../Base Theme-switcher/sample-payload.json" > preview.ansi
```

Add `SL_FAKE_NOW=<epoch>` or `SL_MEADOW_PHASE=night` for a reproducible frame;
the bundled preview was taken at the wall clock of its export.

## Uninstall

```sh
/sl <something-else>
rm ~/.claude/statusline/themes/meadow.sh
rm -r ~/.claude/statusline/vendor/meadow
rm ~/.claude/statusline/meadow-sky.py
rm -r ~/.claude/statusline/assets/meadow ~/.claude/statusline/assets/meadow-night
```

Switch away first, so `terminal-background.py` hands the background, scheme and
palette back while it can still find meadow's files. The built GIFs stay in the
`claude-statusline-sky/` folder beside Windows Terminal's `settings.json` until
you delete them.

## Credits

The grass, the cat, the flowers, the sky, the day cycle, its keyframes and the
segmented-GIF trick that keeps a Windows Terminal background on the clock are
Laibah's. The bridge, the band logic, the rewritten driver and sky builder, the
wrapper and this packaging are adaptation work so her theme runs on the Base
Theme-switcher.
