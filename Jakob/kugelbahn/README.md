# kugelbahn

> **Wooden marble run — one red Kugel per finished workflow subagent, filling a 65-ball preserve jar**

A glass preserve jar standing on a workbench, drawn in the Claude Code status
line. Every workflow subagent that finishes in the current session drops one
red marble into it. The jar holds 65; marble 66 and onward come over the lip
and pile up on the bench beside it. One line of session data sits underneath.

Behind it, on Windows Terminal, the whole window becomes a workshop wall with a
wooden spiral marble tower on it, marbles rolling down and falling into the
bottom left corner where the jar is drawn. That part is scenery. Only the jar
knows the real count.

It is a theme for the `~/.claude/statusline` framework (see
`../../Base Theme-switcher`). One `sl_render` function, no daemon, no
background process.

| File | Goes to | What it is |
|---|---|---|
| `kugelbahn.sh` | `$SL_HOME/themes/` | the theme |
| `kugel-sprites.sh` | `$SL_HOME/` | shared marble tiles, palette and half-block packer; `kugelbahn.sh` sources it on every render, so the theme does not run without it |
| `kugelbahn.hlsl` | `$SL_HOME/shaders/` | the Windows Terminal background, applied by the switcher when you activate the theme |
| `install.sh` | — | copies the three files above into place |
| `preview.ansi` | — | `cat` it to see a real render in colour |

`SL_HOME` is `~/.claude/statusline` unless you say otherwise.

The `kugelbahn` look itself — the `Workshop Night` colour scheme, acrylic,
opacity and the shader filename — is an entry in the framework's
`terminal-background.py`, not in this folder. This folder only ships the shader
file that entry points at.

---

## What it looks like

At 44 terminal columns or more the theme occupies **nine rows**:

| Row | Content |
|---|---|
| 1 | **Lid.** A domed, knurled brass lid, wider than the neck. |
| 2 | **Neck.** The top three marbles sit here, reaching down into the shoulder. |
| 3 | **Shoulder**, and the top of the scale: `┤65`. |
| 4–7 | **Body**, with the rest of the scale beside the glass: `┤52`, `┤39`, `┤26`, `┤13`. |
| 8 | **Foot and bench.** The jar's foot standing on a wood-grain bench that runs to the right edge. Overflow marbles sit on it right of the scale, two courses high, reaching up to row 4. A `+N` chip at the end when the pile is wider than the terminal. |
| 9 | **Readout.** `40/65 · path · ⎇ branch · ctx 47% · $222.07 · Opus 5 · ✦xhigh`. |

The scale has one tick per course of thirteen. The course the current count
falls in is drawn `┫` in a pale highlight; courses already filled are lit red;
courses not reached yet are the glass colour.

### What animates

Nothing moves unless the count changes. A static jar is a pure function of the
count and the width, so two renders of the same second are byte-identical.

| Thing | When | Behaviour |
|---|---|---|
| **Falling marble** | a new completion is discovered | The marble falls in under the lid, straight down to the row of the next free slot, then rolls sideways into it. It is only painted over glass, so it passes behind the walls and behind marbles already settled. |
| **Rolling marble** | a new completion once the jar is full | It comes out from behind the scale and rolls along the bench to the next free spot in the pile, riding up over marbles it passes. |
| **Queue** | several completions at once | The first marble lands 4 s after it is discovered, the rest follow 3 s apart. The readout shows the ones still on their way as `▸N`. At most twelve can queue; any beyond that are settled at once, without the animation. |
| **Fresh marble** | for 2 s after a landing | The newest marble is drawn one shade brighter. |

The flight is driven by `SL_NOW` / `SL_TICK` and the landing time stored in the
ledger, so it advances with the roughly one-second refresh.

---

## How the count works

**What is read.** The theme takes the session's transcript path from the
payload, strips `.jsonl`, and reads every file matching

```
<transcript>/subagents/workflows/wf_*/journal.jsonl
```

Nothing else is read, so a subagent that does not run inside a workflow never
drops a marble.

**What counts as finished.** One marble per journal line containing the literal
text `"type":"result"` or `"type":"failed"`. It is a substring match per line
in `awk`, not a JSON parse. A line that contains both counts once, as a result.
Failures count as done: the total is results plus failures.

**Per session, not cumulative.** The journals are found under *this* session's
transcript, and the ledger file is keyed on the transcript path:

```sh
local -a journals=("${SL_TRANSCRIPT%.jsonl}"/subagents/workflows/wf_*/journal.jsonl)
sl_state_path "${KUGELBAHN_SCHEMA}${SL_TRANSCRIPT//\//_}"
```

A new session has a different transcript, finds no journals and starts with an
empty jar. Earlier sessions never contribute. Within one session the count only
goes up: the ledger keeps a high-water mark and the jar never shows less than
it.

**How it reads cheaply.** The ledger stores, per journal, the byte offset read
so far and the results and failures counted up to there. Each frame `stat`s the
session's journals, and only a journal that has grown is read, and only from
its stored offset (`tail -c`). A journal seen for the first time is counted in
one `awk` pass together with any other new ones. A last line without its
newline yet is not counted until it is complete. A journal that shrinks below
its stored offset is recounted from zero, but the high-water mark still holds.
The ledger is rewritten — through a temporary file and `mv` — only when the
count or the queue changes.

It lives in the framework's state directory, `~/.claude/statusline-state/`,
under a name built from `kgb1` and the transcript path.

**Capacity.** The jar holds exactly **65**, five courses of thirteen. Past 65
the jar stays full and the rest go onto the bench:

| Count | Readout | Picture |
|---|---|---|
| 0 | `0/65` | empty jar |
| 1–65 | `N/65` | jar filling, see *The jar and the marbles* |
| 66 and up | `65/65+N` | full jar, `N` marbles on the bench, as many as fit, then a `+K` chip for the ones that do not |

**Failures** are tallied as `✗N` after the count, and drawn as dull grey
marbles spread evenly through everything on screen — jar and bench together —
in proportion to the failure ratio. That states the ratio without claiming an
order. At least one marble goes dull if anything failed, and while more than one
marble is on screen they never all go dull unless everything failed.

**`SL_PREVIEW=1`** never writes the ledger. If no ledger exists yet, the whole
count is shown settled at once, with no animation.

**Faking the count** for screenshots and testing. These skip the journals and
the ledger entirely and write nothing:

| Variable | Effect |
|---|---|
| `SL_KUGEL_FAKE_BALLS=N` | pretend `N` completions have settled. Required for the other two. `SL_KUGEL_BALLS` is accepted as an alias. |
| `SL_KUGEL_FAKE_FAILED=N` | of those, `N` failed. Alias `SL_KUGEL_FAILED`. |
| `SL_KUGEL_FAKE_PENDING=N` | `N` more in flight. One marble is drawn falling (or rolling, if the jar is full) on a 4-second loop from the clock. |

```sh
SL_KUGEL_FAKE_BALLS=90 SL_KUGEL_FAKE_FAILED=10 SL_PREVIEW=1 COLUMNS=100 \
  ~/.claude/statusline/statusline.sh --theme kugelbahn \
  < ~/.claude/statusline/sample-payload.json
```

---

## The jar and the marbles

Everything is painted on a framebuffer of square sub-pixels, one terminal
column wide and half a row tall, then packed two to a cell as `▀` / `▄` / `█`
with a per-cell foreground and background. A marble four sub-pixels across
covers four columns and two rows and stays round.

The work is split between the two files:

- **`kugel-sprites.sh`** supplies the marble tile (a shaded sphere with a
  specular dot, in a nine-step ruby ramp and a nine-step dull ramp), the shared
  palette every tone code resolves to, the framebuffer, and the packer that
  turns it into terminal rows.
- **`kugelbahn.sh`** carries the jar art, the slot positions, the scale, the
  bench, the overflow pile and all the animation.

**The glass shows twelve marbles, not sixty-five** — five on the bottom, four
above, three up in the neck. The count maps onto them proportionally, so the
first completion shows one marble and only 65 fills the neck:

| Marbles in the glass | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| from count | 1 | 7 | 13 | 19 | 25 | 31 | 36 | 42 | 48 | 54 | 60 | 65 |

The bottom course is full at 25, the middle at 48, the neck at 65. The exact
figure is always in the readout.

The narrower **compact** jar shows five marbles — three on the bottom, two
above — appearing at counts 1, 17, 33, 49 and 65, and replaces the scale with
a single `N/65` beside the neck.

**On the bench** every marble is drawn individually, as many as the width
allows. At full size the pile is two courses deep, the upper marbles sitting in
the gaps of the lower; in the compact tier it is one course.

**Under `NO_COLOR`** the glass interior drops out and every lit sub-pixel stays
a block, so the jar outline and each marble survive as silhouettes. The scale
marks become `-13` and `>52` instead of `┤13` and `┫52`.

---

## The background shader

`kugelbahn.hlsl` is a Windows Terminal pixel shader. It paints a dark
plank wall with a wooden spiral marble tower in front of it, left of centre: a
central post, four corner rods and a base plank, with ramps winding round the
post as a square helix seen from the front, two turns deep. Three red marbles
drop one at a time out of a hopper at the top, roll down both turns, shrinking
and darkening as they go round the back, leave along an exit ramp and fall down
a chute on the far left that ends in the bottom rows — where the status line
draws its jar, so a falling marble disappears behind the jar's glyphs. One
marble's trip takes about 18.5 s and the three are spaced a third of that
apart.

**It is decorative.** A pixel shader gets the terminal's rendered pixels plus
`Time`, `Scale`, `Resolution` and `Background`, and nothing else. It cannot read a file, so it cannot know how
many subagents have finished, and it runs on the clock alone. The theme never
rewrites it. The jar in the status line is the only place the real count
exists.

The terminal's own text is composited on top of the scene wherever it differs
from the background colour or is bright, sampled strictly on the cell grid so
the half-block art is not smeared. Pixels close to the sentinel magenta
`#FF00FF` are blacked out and take their opacity from the terminal 26 pixels
above them (or below, if that is magenta too) — the same job the framework's
`erase-prompt-border.hlsl` does for the input-field border.

**When it is applied.** Only when the theme is activated: `/sl kugelbahn` (or
`switch.sh set kugelbahn`) runs the framework's `terminal-background.py`, whose
`kugelbahn` entry selects the `Workshop Night` scheme (added to Windows Terminal
if it is missing), acrylic at 76 % opacity (60 % unfocused), and this shader.
The shader is copied from `$SL_HOME/shaders/` next to Windows Terminal's
`settings.json` and set as `profiles.defaults` `experimental.pixelShaderPath`.
If the file is not in `$SL_HOME/shaders/`, the helper removes the shader
setting instead of pointing at nothing. `/sl apply-background` re-applies the
look. Rendering the status line never touches Windows Terminal.

On any other terminal the helper finds no Windows Terminal settings and changes
nothing (`/sl` prints a one-line warning); the jar works the same.

---

## How it behaves as the terminal narrows

The tiers use the real terminal width (`COLUMNS`), not the framework's
`SL_COLUMNS`, which is four less.

| Terminal columns | Rows | Scene |
|---|---|---|
| **≥ 44** | 9 | Full jar with the five-tick scale, bench pile, readout. |
| **32 – 43** | 7 | Compact jar, `N/65` beside the neck, one-course bench pile, readout. |
| **≤ 31** | 2 | No jar. Row 1: count and path. Row 2: `ctx 47% · $222.07 · Opus 5`, each dropped when it does not fit, a lone `·` if nothing does. |

The bench pile takes whatever width is left right of the scale; marbles that do
not fit become the `+N` chip.

The readout always keeps the count (padded to eight cells) and at least 14
cells of path. The rest are admitted while there is room, in this order:
`✗N` failures, `⎇ branch` (truncated to 24 characters), cost, context, model,
`✦effort`. They are displayed in a different order —
count · `✗N` · path · branch · context · cost · model · effort — and whatever
room is left goes to the path, which shortens to `…/tail` or its last segment.
Context turns amber at 60 % and red at 85 %.

---

## Requirements

- **bash 4.3 or newer.** Both files use namerefs (`local -n`), plus
  `declare -gA`, `mapfile` and `printf -v`. macOS ships bash 3.2.
- **GNU `stat` and `tail`.** Journal sizes are probed with `stat -c %s`. On a
  BSD `stat` that probe fails, every journal reads as empty and the jar stays at
  0 — on macOS install coreutils so a GNU `stat` comes first on `PATH`. `awk` is
  needed as well; any POSIX one will do.
- **A truecolour terminal.** Every tone is a 24-bit `38;2` / `48;2` sequence.
- **A UTF-8 locale and a font with block elements** (`▀ ▄ █`), box drawing
  (`┤ ┫`) and `⎇ ✦ ✗ ▸ · …`. No Nerd Font. A font whose half blocks meet
  without a hairline gap makes the glass look solid. Under `NO_COLOR`, rows
  that would start blank begin with a zero-width space.
- **The Base Theme-switcher**, installed. `install.sh` refuses without it.
- **Windows Terminal**, only for the background, and **`python3`**, which the
  switcher's `terminal-background.py` and `check.sh` need. The theme itself
  runs no Python.
- **Cost.** No gateway call, no token-burn scan. One `sl_git` per frame
  (cached by the framework) in the jar tiers, one `stat` over this session's
  workflow journals, and a read of only the bytes that are new.

---

## Install

With the Base Theme-switcher already installed at `~/.claude/statusline/`:

```sh
./install.sh
```

It copies `kugelbahn.sh` into `themes/`, `kugel-sprites.sh` next to `core.sh`
and `kugelbahn.hlsl` into `shaders/`, and prints `now run /sl kugelbahn`. It
refuses, and changes nothing, if `statusline.sh`, `core.sh`, `switch.sh` or
`themes/` is missing. Install somewhere else with `SL_HOME`:

```sh
SL_HOME=/path/to/statusline ./install.sh
```

It does not select the theme and does not touch Windows Terminal. Activating
is a separate step, and it is the step that applies the background:

```
/sl kugelbahn
```

The header declares `@order: 22`, which places it in `/sl list`; its number
there is its rank.

Check it with the framework's linter:

```sh
~/.claude/statusline/check.sh kugelbahn
```

As shipped here, it reports `0 failing check(s)`.

---

## Preview

Rendered at 100 columns against the Base Theme-switcher's `sample-payload.json`
with `SL_KUGEL_FAKE_BALLS=40` — seven marbles in the glass, the `52` course
current. In plain text, under `NO_COLOR`:

```
​   ▄▄██████████████████▄▄
​     █                █
​ ▄▀▀▀                  ▀▀▀▄ -65
█   ▄██▄           ▄██▄    █>52
█   ▀██▀           ▀██▀    █-39
█ ▄██▄ ▄██▄ ▄██▄ ▄██▄ ▄██▄ █-26
▀▄▀██▀ ▀██▀ ▀██▀ ▀██▀ ▀██▀▄▀-13
▄▄████████████████████████▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
40/65    · /home/example/project · ctx 47% · $222.07 · Opus 5 · ✦xhigh
```

And at 90 with 10 failed — full jar, 23 marbles on the bench, two more than
fit:

```
​   ▄▄██████████████████▄▄
​     █ ▄██▄ ▄██▄ ▄██▄ █
​ ▄▀▀▀  ▀██▀ ▀██▀ ▀██▀  ▀▀▀▄ >65
█   ▄██▄ ▄██▄ ▄██▄ ▄██▄    █-52      ▄▄   ▄▄   ▄▄   ▄▄   ▄▄   ▄▄   ▄▄   ▄▄   ▄▄   ▄▄   ▄▄
█   ▀██▀ ▀██▀ ▀██▀ ▀██▀    █-39     ████ ████ ████ ████ ████ ████ ████ ████ ████ ████ ████
█ ▄██▄ ▄██▄ ▄██▄ ▄██▄ ▄██▄ █-26   ▄▄ ▀▀▄▄ ▀▀▄▄ ▀▀▄▄ ▀▀▄▄ ▀▀▄▄ ▀▀▄▄ ▀▀▄▄ ▀▀▄▄ ▀▀▄▄ ▀▀▄▄ ▀▀▄▄
▀▄▀██▀ ▀██▀ ▀██▀ ▀██▀ ▀██▀▄▀-13  ████ ████ ████ ████ ████ ████ ████ ████ ████ ████ ████ ████
▄▄████████████████████████▄▄▄▄▄▄▄▄██▄▄▄██▄▄▄██▄▄▄██▄▄▄██▄▄▄██▄▄▄██▄▄▄██▄▄▄██▄▄▄██▄▄▄██▄▄▄██▄▄+2
65/65+25 · ✗10 · /home/example/project · ctx 47% · $222.07 · Opus 5 · ✦xhigh
```

The 40-marble frame in colour:

```sh
cat preview.ansi
```

Regenerate it from this folder with:

```sh
SL_KUGEL_FAKE_BALLS=40 SL_PREVIEW=1 COLUMNS=100 \
  ~/.claude/statusline/statusline.sh --theme kugelbahn \
  < "../../Base Theme-switcher/sample-payload.json" > preview.ansi
```

---

## Known dead weight

`kugel-sprites.sh` is a shared sprite file and carries more than this theme
uses. Listing it so nobody goes looking for it in the render:

- `kugel_jar`, `kugel_draw_jar` and the `KUGEL_JAR_*` arrays — a different,
  ready-made jar (six or three marbles) with its own overflow layout. This
  theme draws its own jar and never calls them.
- `kugel_marble`, `kugel_blit_marble`, `kugel_blit_marble_at` and `kugel_put`,
  and every marble tile except the four-sub-pixel one at phase 0. This theme
  blits that one tile with its own routine.
- `KUGEL_CAPACITY=65` — the theme uses its own `KUGELBAHN_CAPACITY`, also 65.
- The comments naming `vendor/kugel/generate_sprites.py`. The block between
  the `>>> generated` markers was produced by a generator that is not part of
  this export; treat it as data.

None of it costs anything measurable or trips the linter.
