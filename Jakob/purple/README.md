# purple

> The original — animated cool-rainbow rule, purple gutters, four dense lines

The first theme written for the switchable statusline framework, and still its
built-in default. It is the maximalist one: it spends four terminal rows and
asks the framework for everything it can get — git, the gateway budget, the
transcript token scan — then packs the result into three dense data rows under
an animated rainbow rule.

If you want something cheap and quiet, this is the wrong theme. This one is for
people who would rather read the damage than not know.

## What's in here

| File | Goes to | What it is |
|---|---|---|
| `purple.sh` | `~/.claude/statusline/themes/` | the theme — one bash file, one `sl_render` function |
| `preview.ansi` | — | a real render at 100 columns, with colour. `cat` it |
| `README.md` | — | this file |

No assets, no helper scripts, no Windows Terminal config. One file installs it.

## What it looks like

Four rows, top to bottom. Row 0 is dropped under `NO_COLOR`, so the honest
answer is **4 rows in colour, 3 rows in plain mode** — verified by
`check.sh purple`, which reports `4 line(s)` at every colour width and
`3 line(s)` at 100 plain.

```
row 0   ────────────────────────────────────────────   full-width animated gradient rule
row 1   ▌ path │ branch ↑2 ↓1 │ +696/-276
row 2   ▌ ▰▰▱▱▱▱▱▱▱▱▱▱  $1,234.50 / $5,000.00 · 24.7% monthly │ $222.07 │ tokens wasted: 41.017.650
row 3   ▌ ✦ xhigh effort │ context 47% (466k) │ Opus 5 (1M context)
```

Each data row opens with a `▌` half-block gutter. The three gutters and the six
`│` separators are all drawn from one 12-step 256-colour ramp
(`63 69 75 111 147 183 219 213 207 171 135 99` — violet up through blue, pink,
magenta and back), each element offset a fixed number of slots along the ramp so
the whole block reads as one diagonal wash of colour rather than nine
independent dots.

### What animates

Two things, on two different clocks.

- **The gutters and separators** step one slot along the 12-colour ramp every
  **2 seconds** (`PURPLE_ANIMATION_PERIOD=2`), so the full cycle is **24
  seconds**. Confirmed by render: at `SL_FAKE_NOW=0` the top gutter is colour
  63, at 2 it is 69, at 4 it is 75, and at 24 it is back to 63.
- **The rule on row 0** is `sl_rule` with the framework's default 90-second
  cycle. It paints a truecolour cosine-palette gradient across the full width
  and slides it sideways, so the whole band completes one revolution every
  **90 seconds**. Confirmed by render: the leading cell is
  `255;143;180` at both `SL_FAKE_NOW=0` and `SL_FAKE_NOW=90`.
- **The budget bar** on row 2 also animates: its filled `▰` cells are coloured
  from the same ramp with the same 2-second phase, so the fill shimmers. Above
  **85%** spent it stops animating and goes flat warning-pink (256-colour 204)
  instead — a deliberate "stop looking at the pretty colours" signal.

Everything is derived arithmetically from `SL_NOW` / `SL_TICK`, so two renders
of the same second are byte-identical and the line does not flicker.

## What data it shows

Row 1 — **where you are**:

| Shown | Source |
|---|---|
| current directory, `~`-relative, progressively shortened | `SL_PATH`, `sl_path_tail` |
| git branch, bold | `SL_GIT_BRANCH` |
| ahead / behind markers `↑2` `↓1`, only when non-zero | `SL_GIT_AHEAD`, `SL_GIT_BEHIND` |
| session diffstat `+696/-276`, green adds, orange deletes | `SL_LINES_ADDED`, `SL_LINES_REMOVED` |

Row 2 — **what it is costing**. This row has three mutually exclusive moods
depending on what the gateway gave back:

| Gateway state | Row 2 opens with |
|---|---|
| budget parsed | a 12-cell `▰▱` bar, then `spent / limit · percent period` |
| raw text that contains a digit but no parseable budget | the first line of that raw text, clipped |
| nothing | the words `gateway offline`, dimmed |

All three verified by seeding a fake gateway cache and rendering:

```
▌ ▰▰▱▱▱▱▱▱▱▱▱▱  $1,234.50 / $5,000.00 · 24.7% monthly │ $222.07 │ tokens wasted: 41.017.650
▌ ▰▰▰▰▰▰▰▰▰▰▱▱  $4,300.00 / $5,000.00 · 88.0% weekly │ $222.07 │ tokens wasted: 41.017.650
▌ rate limit 42 of 100 │ $222.07 │ tokens wasted: 41.017.650
▌ gateway offline │ $222.07 │ tokens wasted: 41.017.650
```

After the gateway segment the row appends session cost (`SL_COST_TEXT`) and then
the transcript token burn, labelled `tokens wasted:` and thousands-grouped with
dots (`SL_TOKENS_BURNED_TEXT`). The label is not a typo and not a bug — it is
the point of the row.

Row 3 — **how you are thinking**:

| Shown | Source |
|---|---|
| `✦ xhigh effort`, bold violet, prefixed `ultracode · ` when ultracode is on | `SL_EFFORT`, `SL_ULTRACODE` |
| `context 47% (466k)` — percent plus abbreviated token count, turning warning-pink at ≥85% | `SL_CONTEXT_PERCENT`, `SL_CONTEXT_TOKENS` |
| model display name, falling back to the short name when the long one will not fit | `SL_MODEL_NAME`, `SL_MODEL_SHORT` |

### Deliberately omitted

The theme reads none of these, even though the framework hands them over for
free: `SL_DURATION_MS` and `SL_API_DURATION_MS` (wall clock / API time),
`SL_CONTEXT_REMAINING`, `SL_CONTEXT_OUTPUT_TOKENS`, `SL_CONTEXT_SIZE`,
`SL_OUTPUT_STYLE`, `SL_VERSION`, `SL_SESSION_ID`, `SL_MODEL_ID`,
`SL_REPO_HOST` / `SL_REPO_OWNER` / `SL_REPO_NAME`, `SL_FAST_MODE`,
`SL_THINKING`, `SL_EXCEEDS_200K`, and the absolute `SL_CWD` / `SL_PROJECT_DIR`.
Three rows is already dense; these lost the argument.

## How it behaves as the terminal narrows

Note first that the framework subtracts a 4-column safety margin, so
`SL_COLUMNS = COLUMNS - 4`. Every number below is the **real terminal width**,
measured by rendering `sample-payload.json` one column at a time from 20 to 130.

The breakpoints depend on how long your actual strings are. The sample payload
has a brutal 70-character branch name (`1380-add-environment-indicator-test-prod-to-partitio-matching-extranet`),
a `/mnt/c/Partitio/Extranet` path and a 25-character model name, which is why
things shed as late as they do here. With a short branch everything arrives much
earlier.

Measured, widest to narrowest:

| Width | What changes |
|---|---|
| **115+** | everything: full absolute-style path, full branch, diffstat `+696/-276` |
| **114 → 103** | diffstat dropped. Path still full (`/mnt/c/Partitio/Extranet`) |
| **102 → 100** | path shortened to 3 tail segments (`…/c/Partitio/Extranet`) |
| **99 → 98** | path shortened to 2 tail segments (`…/Partitio/Extranet`) |
| **97 → 89** | path shortened to 1 tail segment (`…/Extranet`); branch still complete |
| **88 → 63** | branch begins to ellipsise, one character at a time |
| **62 → 50** | model drops from `Opus 5 (1M context)` to `Opus 5` |
| **58 → 41** | `tokens wasted: …` dropped from row 2 |
| **49 → 41** | model dropped entirely from row 3 |
| **40 → 29** | `context 47% (466k)` dropped; row 3 is effort + `Opus 5` only |
| **30 → 21** | session cost dropped; row 2 is `gateway offline` alone |
| **28 → 21** | model dropped again; row 3 is `✦ xhigh effort` alone |
| **≤ 20** | `gateway offline` no longer fits, so row 2 falls back to bare `$222.07` with no separator; row 1 is path only |

Rendered at 60 columns, for example:

```
────────────────────────────────────────────────────────
▌ …/Extranet │ 1380-add-environment-indicator-test-prod…
▌ gateway offline │ $222.07 │ tokens wasted: 41.017.650
▌ ✦ xhigh effort │ context 47% (466k) │ Opus 5
```

The mechanism, if you care: row 1 runs a nested search over four path variants
(full, 3 tails, 2 tails, 1 tail) crossed with diffstat on/off, takes the first
combination that measures within budget, and only then truncates the branch
name by whatever is still overflowing — dropping the branch outright if fewer
than 2 columns remain for it. Rows 2 and 3 use a simpler append-if-it-fits
accumulator, so segments vanish from the right as space runs out. The rule on
row 0 always spans the full `SL_COLUMNS` and never sheds.

`check.sh purple` passes clean at 60, 80, 100, 160 and 220 columns, plus 100
under `NO_COLOR`: **0 failing checks.** No overflow, no stderr, no unreset
colour at end of line, no escapes leaking under `NO_COLOR`, no trailing
whitespace.

## Requirements

- **Truecolour terminal for the rule.** Row 0 emits 24-bit `38;2;R;G;B`
  sequences, one per column. On a 256-colour-only terminal the rule will look
  banded, wrong, or (on a terminal that does not understand the sequence at all)
  garbled. Rows 1–3 are pure 256-colour (`38;5;N`) and are safe anywhere. If you
  are stuck on 256 colours, the honest advice is to pick a different theme
  rather than patch this one.
- **Glyph coverage**, all plain Unicode — no Nerd Font, no patched font:
  `▌` U+258C, `│` U+2502, `─` U+2500, `▰` U+25B0, `▱` U+25B1, `✦` U+2726,
  `…` U+2026. Any modern monospace font with box-drawing and geometric-shape
  coverage will do. DejaVu Sans Mono, Cascadia Code, JetBrains Mono: fine.
- **python3** — not used by the theme itself, only by the framework's
  `check.sh` linter. You can install and run purple without it.
- **This is an expensive theme.** It calls all three lazy getters:
  - `sl_git` — shells out to git once per render
  - `sl_gateway` — shells out to `build-cli claude statusline`, cached 90
    seconds. If you have no `build-cli`, you get `gateway offline` forever and
    no cost at all; the theme degrades cleanly
  - `sl_token_burn` — incrementally scans the session transcript JSONL (and any
    subagent transcripts) for token counts, keeping a byte-offset state file so
    it only reads what is new

  A one-line theme that skips all three is dramatically cheaper. Purple is not
  that theme. On a slow filesystem — a WSL session working off a Windows drive,
  say — expect it to be the slowest thing in your statusline.
- **No platform-specific code.** Pure bash with `set -u`, plus git. Works on
  Linux, macOS and WSL alike. `build-cli` presence is the only environmental
  variable, and its absence is handled.

## Install

Assuming you already have the Base Theme-switcher installed at
`~/.claude/statusline/`:

```sh
cp purple.sh ~/.claude/statusline/themes/purple.sh
```

Then, inside Claude Code:

```
/sl purple
```

Or from a shell:

```sh
~/.claude/statusline/switch.sh set purple
```

Nothing else has to go anywhere else. No palette file, no wallpaper, no
Windows Terminal edit, no slash command to register.

Two notes:

- Purple is the framework's hard-coded fallback theme
  (`SL_DEFAULT_THEME="purple"` in `statusline.sh`), so a stock switcher install
  may already have it. Copying over it is harmless — the file here is byte
  identical to the one in the source tree.
- Verify it with the framework's own linter before trusting it:

  ```sh
  ~/.claude/statusline/check.sh purple
  ```

  It should report `0 failing check(s)` and print a preview at 100 columns.

To step the animation frame by frame:

```sh
for t in $(seq 0 1 24); do
  SL_FAKE_NOW=$t SL_PREVIEW=1 COLUMNS=100 \
    ~/.claude/statusline/statusline.sh --theme purple \
    < ~/.claude/statusline/sample-payload.json
  echo
done
```

`SL_PREVIEW=1` is not optional in testing: it stops the gateway shell-out and
stops the token-burn state file being rewritten, so a preview cannot corrupt
your live session's counters.

## Preview

A real render at 100 columns against the framework's `sample-payload.json`,
escape sequences stripped, frame pinned at `SL_FAKE_NOW=1758000000`:

```
────────────────────────────────────────────────────────────────────────────────────────────────
▌ …/c/Partitio/Extranet │ 1380-add-environment-indicator-test-prod-to-partitio-matching-extranet
▌ gateway offline │ $222.07 │ tokens wasted: 41.017.650
▌ ✦ xhigh effort │ context 47% (466k) │ Opus 5 (1M context)
```

For the same thing in colour:

```sh
cat preview.ansi
```

The rule and the gutters are flat grey in the stripped version above and the
whole reason to look at the colour one.
