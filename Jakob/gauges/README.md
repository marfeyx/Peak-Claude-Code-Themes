# gauges

**Aligned meter stack with sub-cell bars and a raw totals row.**

An instrument panel rather than a status *line*. Five rows, one labelled meter
per row, every bar starting and ending in the same column, closed by a row of
raw totals that shares the same grid. Nothing moves, nothing blinks — it reads
like a dashboard you glance at, not a ticker you watch.

```
/mnt/c/Partitio/Extranet │ 1380-add-environment-indi… │ Opus 5 (1M context) │ xhigh effort
context  █████████████░░░░░░░░░░░░░░░   47%  466k / 1.0M tokens · 53% free
gateway  ███████▋░░░░░░░░░░░░░░░░░░░░   28%  $412.50 / $1,500.00 · monthly
session  ████▏░░░░░░░░░░░░░░░░░░░░░░░   15%  $222.07 of $1,500.00
totals   in 466k  out 311  diff +696 -276  wall 5h51m  burn 41.0M
```

## What's in here

| File | Goes to | What it is |
|---|---|---|
| `gauges.sh` | `~/.claude/statusline/themes/` | the theme — one bash file, one `sl_render` |
| `install.sh` | — | copies it there and selects it |
| `preview.ansi` | — | `cat` it to see the real thing in colour |
| `README.md` | — | this |

No assets, no wallpaper, no shader, no generator script. One file is the whole
theme.

## What it looks like

Up to **five rows**, top to bottom. Every row is optional except the header;
rows drop out when the data behind them is missing or the terminal is too
narrow.

**Row 1 — header.** The current path, then up to four segments separated by a
dim `│`, added left to right as width allows:

1. the git branch in bold, with `↑N` / `↓N` ahead/behind markers, truncated at
   26 columns
2. the full model display name (`Opus 5 (1M context)`, not the short form)
3. the effort level as `xhigh effort`; with ultracode on it becomes
   `ultracode · xhigh effort`, or plain `ultracode` when no effort is set
4. the Claude Code version as `v2.1.274`

The path gets whatever is left and is fitted by `sl_path_fit`, so it degrades
through `/mnt/c/Partitio/Extranet` → `…/c/Partitio/Extranet` →
`…/Partitio/Extranet` → `…/Extranet` rather than being hard-clipped. The
header reserves at least 20 columns for the path and sheds segments from the
right until that holds — which is why the path sometimes *shortens* as the
terminal gets wider: a new segment has just been admitted.

**Rows 2–4 — the meters.** `context`, `gateway`, `session`. Each row is a
7-column label, a bar, a right-aligned percentage, and a muted detail string,
all on a fixed grid so the bars line up vertically.

The bar is drawn in eighths using partial block glyphs (`▏▎▍▌▋▊▉`) over a
`░` trough, so a 28-cell bar resolves 224 steps rather than 28. A non-zero
value never renders as empty — it is floored at one eighth.

The fill colour is a four-step severity ramp, applied to both the bar and the
percentage:

| Fill | Colour | 256-colour index |
|---|---|---|
| under 50% | green | 108 |
| 50–74.9% | amber | 179 |
| 75–89.9% | orange | 208 |
| 90% and over | red | 203 |

The detail string is chosen, not truncated blindly: each row offers the
renderer a list of candidates longest-first, and it picks the first one that
fits the detail column. `context` offers
`466k / 1.0M tokens · 53% free` → `466k / 1.0M tokens` → `466k / 1.0M`. Only
if even the shortest overflows does it get ellipsised.

`gateway` and `session` fall back to a plain label-and-text note when there is
no percentage to draw:

- `gateway` with no budget data shows the first line of whatever the gateway
  returned, or the word `unavailable`
- `session` shows the bare cost figure when no spend limit is known, and only
  becomes a bar once a limit exists to divide by

**Row 5 — totals.** Raw numbers on the same 7-column grid, each a dim key and a
bright value, appended left to right until the row is full: `in`, `out`,
`diff`, `wall`, `burn`. Additions are green, deletions red. The row is dropped
entirely if nothing fits.

**Animation: none.** The theme never reads `SL_NOW`, `SL_TICK` or `sl_phase`.
Two renders of the same session are byte-identical. `SL_FAKE_NOW` changes
nothing about it.

## What data it shows

Everything it surfaces, by row:

| Row | Field | Source |
|---|---|---|
| header | path, `~`-relative, best-fitting variant | `SL_PATH` via `sl_path_fit` |
| header | git branch, bold, max 26 columns | `SL_GIT_BRANCH` |
| header | ahead / behind counts as `↑N` `↓N` | `SL_GIT_AHEAD` `SL_GIT_BEHIND` |
| header | model display name, in full | `SL_MODEL_NAME` |
| header | effort level, and ultracode | `SL_EFFORT` `SL_ULTRACODE` |
| header | Claude Code version | `SL_VERSION` |
| context | tokens used, window size, percent free | `SL_CONTEXT_TOKENS` `SL_CONTEXT_SIZE` `SL_CONTEXT_REMAINING` |
| context | percent fallback when raw counts are absent | `SL_CONTEXT_PERCENT` |
| gateway | spend, limit, percent, billing period | `SL_BUDGET_SPENT` `SL_BUDGET_LIMIT` `SL_BUDGET_PERCENT` `SL_BUDGET_PERIOD` |
| gateway | raw first line when unparsed | `SL_GATEWAY_RAW` |
| session | session cost, and its share of the gateway limit | `SL_COST_TEXT` `SL_COST_MICRO` |
| totals | `in` — context input tokens | `SL_CONTEXT_TOKENS` |
| totals | `out` — output tokens | `SL_CONTEXT_OUTPUT_TOKENS` |
| totals | `diff` — session diffstat | `SL_LINES_ADDED` `SL_LINES_REMOVED` |
| totals | `wall` — session wall clock | `SL_DURATION_MS` |
| totals | `burn` — tokens burned, from the transcript scan | `SL_TOKENS_BURNED` |

Deliberately omitted, though the framework offers them: the remote repo
identity (`SL_REPO_HOST` / `SL_REPO_OWNER` / `SL_REPO_NAME`), the short model
name and model id, `SL_FAST_MODE`, `SL_THINKING`, `SL_EXCEEDS_200K`,
`SL_OUTPUT_STYLE`, `SL_SESSION_ID`, `SL_API_DURATION_MS`, the absolute
`SL_CWD` / `SL_PROJECT_DIR`, and any clock or time of day. There is no git
dirty-file count — only branch and divergence.

## How it behaves as the terminal narrows

The framework subtracts a 4-column safety margin, so the theme budgets against
`SL_COLUMNS = COLUMNS - 4`. The breakpoints below are **terminal columns**, and
were measured by rendering the bundled sample payload at every width from 14 to
110. They are payload-dependent: a shorter path, branch or model name moves the
header breakpoints left.

| At | What appears |
|---|---|
| 1–16 | header only — the path, nothing else |
| 17 | `context` row, as label + percentage, no bar, no detail |
| 19 | `gateway` and `session` rows |
| 20 | `totals` row, with `in` |
| 27 | the bars appear, at their 8-cell floor |
| 29 | `totals` gains `out` |
| 35 | the detail column opens at its 6-column minimum, ellipsised |
| 45 | `totals` gains `diff` |
| 47 | detail fits `466k / 1.0M tokens` whole |
| 48 | the bars start growing past 8 cells |
| 53 | the branch joins the header |
| 57 | `totals` gains `wall` |
| 67 | the bars reach their 28-cell ceiling and stop |
| 69 | `totals` gains `burn` |
| 75 | the model name joins the header |
| 78 | context detail gains `· 53% free` |
| 90 | the effort level joins the header |
| 101 | the version joins the header |

Past 101 columns nothing further is added — the theme stops growing and the
extra width is simply left empty. The bar never exceeds 28 cells and the detail
column takes the slack.

Narrower than 17 columns the meter rows cannot fit label + percentage and are
dropped outright; below that the header alone survives, clipped by the
framework.

## Requirements

- **256-colour terminal.** Every colour is an `sl_fg256` index — there is not a
  single truecolour escape in the file. It looks identical on a truecolour
  terminal and degrades correctly under `NO_COLOR` (verified: no escapes leak,
  the layout holds).
- **Unicode block glyphs**, nothing more exotic: `█ ░ ▏▎▍▌▋▊▉ │ · … ↑ ↓`.
  **No Nerd Font, no powerline glyphs, no emoji.** Any monospace font with
  Unicode block-element coverage will do. If your font lacks the eighth-blocks
  the bar still works, it just quantises to whole cells visually.
- **bash 4.2+** and **awk**. No `python3`, no `jq`.
- **git** on `PATH` for the branch segment; without it the header simply has no
  branch.
- **Not cheap.** `sl_render` calls all three lazy getters: `sl_git`,
  `sl_gateway` and `sl_token_burn`. That means a git call (4 s cache), a
  `build-cli` subprocess for the gateway budget (90 s cache, 5 s timeout) and an
  incremental scan of the session transcript. If you do not have `build-cli`
  installed the gateway row just reads `unavailable` and costs nothing; the
  transcript scan always runs. This is the expensive end of the theme set — it
  is a dashboard, and it pays for it.
- Platform-neutral. Nothing Windows-, WSL- or macOS-specific.

## Install

Assuming the **Base Theme-switcher** is already installed at
`~/.claude/statusline/`:

```sh
cp gauges.sh ~/.claude/statusline/themes/
```

Then in Claude Code:

```
/sl gauges
```

or from a shell:

```sh
~/.claude/statusline/switch.sh set gauges
```

`./install.sh` does both. Nothing else has to be copied anywhere — no font, no
terminal config, no wallpaper, no shader.

Check it rendered honestly at every width:

```sh
~/.claude/statusline/check.sh gauges
```

`gauges` answers to `/sl 70` as well as `/sl gauges` — the number comes from the
`@order: 70` line in the file's header and survives a rename.

## Preview

Rendered at 100 columns against the framework's sample payload, escapes
stripped. This is the preview-mode render, so the gateway budget is not
fetched and that row falls back to its note form:

```
/mnt/c/Partitio/Extranet │ 1380-add-environment-indi… │ Opus 5 (1M context) │ xhigh effort
context  █████████████░░░░░░░░░░░░░░░   47%  466k / 1.0M tokens · 53% free
gateway  unavailable
session  $222.07
totals   in 466k  out 311  diff +696 -276  wall 5h51m  burn 41.0M
```

With a gateway that actually answers, rows 3 and 4 become meters too and the
panel is complete:

```
/mnt/c/Partitio/Extranet │ 1380-add-environment-indi… │ Opus 5 (1M context) │ xhigh effort
context  █████████████░░░░░░░░░░░░░░░   47%  466k / 1.0M tokens · 53% free
gateway  ███████▋░░░░░░░░░░░░░░░░░░░░   28%  $412.50 / $1,500.00 · monthly
session  ████▏░░░░░░░░░░░░░░░░░░░░░░░   15%  $222.07 of $1,500.00
totals   in 466k  out 311  diff +696 -276  wall 5h51m  burn 41.0M
```

In colour:

```sh
cat preview.ansi
```

and to render it against your own live session at any width:

```sh
SL_PREVIEW=1 COLUMNS=60 ~/.claude/statusline/statusline.sh --theme gauges \
  < ~/.claude/statusline/sample-payload.json
```

## Tuning

The constants at the top of `gauges.sh` are the whole knob panel:

| Constant | Default | Effect |
|---|---|---|
| `GAUGES_LABEL_WIDTH` | 7 | width of the `context` / `gateway` / … label column |
| `GAUGES_BAR_MINIMUM` | 8 | bar floor; below this the bar is dropped entirely |
| `GAUGES_BAR_MAXIMUM` | 28 | bar ceiling; raise it for very wide terminals |
| `GAUGES_DETAIL_RESERVE` | 20 | columns held back from the bar for the detail text |
| `GAUGES_DETAIL_MINIMUM` | 6 | below this the detail column closes |
| `GAUGES_BRANCH_MAXIMUM` | 26 | branch truncation point in the header |
| `GAUGES_PATH_MINIMUM` | 20 | floor the header protects for the path |

`GAUGES_LEVELS` in `gauges_palette` is the severity ramp, green → amber →
orange → red; the thresholds live in `gauges_level` as permille (500 / 750 /
900). Re-run `check.sh gauges` after changing any of them — the linter catches
overflow at five widths plus `NO_COLOR`.

## Uninstall

```sh
rm ~/.claude/statusline/themes/gauges.sh
```

Then `/sl <something-else>`. If `gauges` was still selected the framework falls
back to the default theme and says so on the status line.
