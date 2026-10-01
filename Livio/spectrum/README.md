# spectrum

> Three information rows under a slowly drifting rainbow rule

Livio's `rgb` renderer, bridged onto the Base Theme-switcher and renamed —
`rgb` says nothing about what you get, and the framework's list is read by
people. The only one of his four with no scenery: a full-width gradient rule
with the hue drifting sideways, and three rows of session data underneath.

This is the quiet default of his set, and the one to pick if you want his data
layout without giving up a third of the terminal to an aquarium. It is also the
only one that works on a font with no block-element coverage beyond `█ ░ ━`.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
/mnt/c/Partitio/Extranet
ctx ██████░░░░░░ 47%  │  $222.07  │  5 hours 51 minutes
xhigh effort  │  Opus 5 (1M context)
```

Real render, 100 columns, escapes stripped — which costs this theme more than
the others, because the rule is *nothing but* colour. `cat preview.ansi` for the
actual thing.

## What's in here

| File | Goes to | Whose | What it is |
|---|---|---|---|
| `spectrum.sh` | `~/.claude/statusline/themes/` | ours | the theme the framework loads |
| `rgb.py` | `vendor/livio/` | **Livio's, verbatim** | the renderer. Renamed theme, unmodified module. |
| `preview.ansi` | — | — | a real render in colour, 100 columns |
| `install.sh` | — | — | copies everything into place and selects it |

Plus `../shared/`. This theme only actually needs `common.py` out of it — no
pixel layer, no octant table, no GIF stub — but `install.sh` copies the whole
shared directory because all four themes share one `vendor/livio/` and the
files are identical either way.

## What it looks like

Four rows, always. Nothing is ever dropped from the row *count*; rows lose
segments instead.

1. **The rainbow rule.** One `━` per column of the budget. The hue of column
   *i* is `(phase + i ÷ width) mod 1` at saturation 0.68 and value 0.95, so the
   rule spans exactly one full turn of the colour wheel end to end, and `phase`
   advances on a **30-second cycle** — the whole spectrum travels past once every
   half minute. The renderer only emits an escape when the quantised colour
   actually changes from the previous column — though in practice, with one full
   turn spread over the width, it changes every column: **measured 96 escapes in
   a 96-cell rule at 100 columns.** The optimisation only pays off if you raise
   `RULE_SPREAD` or shrink the terminal.

2. **Location** — path, git branch, diffstat, joined with a dim `│`.

3. **Budget and burn** — the context meter, weekly gateway spend, session cost,
   wasted cache tokens, session duration.

4. **Model and effort** — effort level (plus `⚡ fast` and `thinking`), model
   display name, and agent / PR segments when the payload carries them.

**The context meter** is 12 cells, `█` for used over `░` for free, with a
three-step severity ramp applied to both the bar and the percentage: green under
50 %, amber under 75 %, red above. Measured on the same frame: `█░░░░░░░░░░░ 8%`,
`██████░░░░░░ 47%`, `███████████░ 92%`.

**Animation** is the rule and nothing else. It derives from `SL_NOW`, which the
bridge pins, so two renders of the same second are byte-identical. At roughly
1 fps and a 30-second cycle the rule advances about 3 columns' worth of hue per
frame — slow enough to read as drift rather than strobing.

## What data it shows

| Row | Shown | Field |
|---|---|---|
| 2 | current path | `SL_PATH`, shortened to 42 characters by his `short_path` |
| 2 | git branch | resolved by the host, never forked per frame |
| 2 | session diffstat | `+696` / `-276`, green and red |
| 3 | context used, bar and percentage | `SL_CONTEXT_PERCENT` |
| 3 | weekly gateway spend | spend / budget / `% weekly`; absent in preview mode |
| 3 | session cost | `$222.07` |
| 3 | wasted cache tokens | only when the payload carries `prompt_cache.miss_recache_tokens` |
| 3 | session duration | `5 hours 51 minutes` |
| 4 | fast mode | `⚡ fast` |
| 4 | reasoning effort | `xhigh effort`, or `thinking` when there is no effort level |
| 4 | model display name | `Opus 5 (1M context)`, with `(1M context)` appended if the window is ≥ 1 M and the name does not already say so |
| 4 | agent name | only when the payload carries `agent.name` |
| 4 | pull/merge request | `MR !123` or `PR #123`, coloured by review state, when the payload carries it |

Not read: token counts, remaining-context percentage, ahead/behind counts,
output style, version, session id, remote repo identity, API duration,
`exceeds_200k_tokens`, and ultracode.

The agent and PR segments are the interesting ones — they come from payload
fields this framework's own themes do not surface, and will simply be absent
unless your Claude Code is populating them.

## How it behaves as the terminal narrows

Measured by rendering the bundled sample payload at **every width from 20 to
180 columns**. The framework subtracts a 4-column safety margin, so the theme
budgets against `SL_COLUMNS = COLUMNS − 4`.

The row count never changes: four rows at 20 columns, four at 220. The rule
always fills the budget exactly.

| Terminal columns | What the rows read |
|---|---|
| 20 – 27 | row 2 is the path **hard-clipped** mid-string — `/mnt/c/Partitio/` at 20, one character more per column. Row 3 is `ctx ██████░░░░░░` with no percentage until 22, then the percentage arrives a digit at a time: `4` at 22, `47` at 23, `47%` at 24 |
| 28 – 35 | the path fits whole, `/mnt/c/Partitio/Extranet` |
| 36 – 39 | row 3 gains `$222.07` |
| 40 – 58 | row 4 gains `Opus 5 (1M context)` |
| 59 – 102 | row 3 gains `5 hours 51 minutes` |
| 103 – 116 | row 2 gains the git branch |
| ≥ 117 | row 2 gains the diffstat `+696/-276` |

Two things worth calling out, because they are the honest rough edges:

- **Row 2 is the one place a field is clipped rather than shed.** It starts as a
  single segment — the path — and the bridge can only shed at separator
  boundaries, so below 28 columns the path is cut mid-string instead of being
  abbreviated to `…/Extranet` the way a native theme would.
- **The branch is shed whole, not truncated.** The branch in these measurements
  is **70 characters** long
  (`1380-add-environment-indicator-test-prod-to-partitio-matching-extranet`),
  which is why it costs until 103 columns. Re-measured against a repo on branch
  `main` at path `/tmp/shortbranch`, the whole sweep compresses dramatically:
  branch at **29** columns, cost at 36, model at 40, diffstat at **43**,
  duration at 59, and everything is present by 59. So the table above is a worst
  case, not a typical one — a 70-character branch costs roughly 74 columns.

**Under `NO_COLOR`** the theme is the only one of the four that keeps its full
shape: all four rows survive, the rule becomes a flat dim `━` band and the
context bar stays `██████░░░░░░`. No escapes are emitted at all. It is the
`NO_COLOR` pick of the set.

## Requirements

- **`python3`**, stdlib only. No pip, no network.
- **A truecolour terminal** for the rule — it is 24-bit per column. On a
  256-colour terminal the rule degrades to a dim flat band via his own
  `STATUSLINE_NO_TRUECOLOR` path; the three data rows are 256-colour throughout
  and look identical either way.
- **No block-art font needed.** The only non-ASCII glyphs are `━ █ ░ │ ⚡ ·`.
  Any monospace font has them. **No octants, no Nerd Font, no powerline
  glyphs** — this is the one theme of the four that is safe on a default font.
- **bash 4.2+** for the framework.
- **Cost: about 230 ms per render** at 100 columns on this machine, measured over
  five warm renders, including Python startup. Cheapest of the four, and almost
  all of it is interpreter start — there is no pixel layer and no scene. It calls
  `sl_git` and `sl_gateway`; the Python itself forks nothing.
- Platform-neutral. No terminal background, no assets, no generator.

## Install

With the Base Theme-switcher already at `~/.claude/statusline/`:

```sh
./install.sh
```

By hand:

```sh
mkdir -p ~/.claude/statusline/vendor/livio
cp ../shared/*.py ../shared/wrapper.sh ~/.claude/statusline/vendor/livio/
cp rgb.py ~/.claude/statusline/vendor/livio/
cp spectrum.sh ~/.claude/statusline/themes/
```

Then `/sl spectrum`, or `/sl 43` from the `@order: 43` header. Note the theme is
`spectrum` but the module stays `rgb.py` — the wrapper asks the bridge for
`rgb`, so Livio's file keeps its own name.

Check it:

```sh
~/.claude/statusline/check.sh spectrum
```

Renders at 30/40/50/60/80/100/160/220 columns plus `NO_COLOR`. **The copy in
this folder passes with zero failures.** Nothing else is copied anywhere.

## Tuning

No height knob — there is no panel. The constants worth knowing live at the top
of `rgb.py`, and changing them means editing Livio's file, which this folder
otherwise never does:

| Constant | Default | Effect |
|---|---|---|
| `RULE_CYCLE` | `30.0` | seconds for the gradient to travel a full colour wheel |
| `RULE_SPREAD` | `1.0` | turns of the wheel spanned end to end; `2.0` gives two rainbows |
| `RULE_SAT` `RULE_VAL` | `0.68` `0.95` | saturation and value of the rule |
| `RULE_CHAR` | `━` | the rule glyph |

`RULE_PAD` and `STATUSLINE_RULE_PAD` are overridden by the bridge, which sets the
padding to zero and hands in the already-reduced budget as `COLUMNS`. Leave them
alone.

## Preview

```sh
cat preview.ansi
```

and against your own live session at any width:

```sh
SL_PREVIEW=1 COLUMNS=60 ~/.claude/statusline/statusline.sh --theme spectrum \
  < ~/.claude/statusline/sample-payload.json
```

To watch the rule drift, step the pinned clock:

```sh
for t in $(seq 0 3 30); do
  SL_FAKE_NOW=$t SL_PREVIEW=1 COLUMNS=100 \
    ~/.claude/statusline/statusline.sh --theme spectrum \
    < ~/.claude/statusline/sample-payload.json | head -1
done
```

## Uninstall

```sh
rm ~/.claude/statusline/themes/spectrum.sh
```

Then `/sl <something-else>`. The modules under `vendor/livio/` are shared with
the other three themes; only remove `rgb.py` if none of those are installed.

## Credits

The rule, the layout and the data choices are Livio's. The bridge, the rename
and the packaging are adaptation work.
