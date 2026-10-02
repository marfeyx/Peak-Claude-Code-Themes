# Switchable Claude Code statusline

```
~/.claude/statusline/
  statusline.sh     entry point — settings.json points here
  core.sh           shared data layer + layout helpers
  switch.sh         CLI behind the /sl slash command
  selected          plain-text file holding the active theme name
  themes/*.sh       one file per look
```

Switch with `/sl <number|name>` in Claude Code, or `switch.sh set <name>` from a shell.

## Writing a theme

A theme is a bash file in `themes/` that defines **one function, `sl_render`**, and nothing else
at top level except its metadata header. `core.sh` is already sourced; the payload is already
parsed. Call `sl_emit` once per line, top to bottom. Every emitted line is clipped to the terminal
width for you, so a theme can never wrap the prompt.

```bash
#!/usr/bin/env bash
# @name: neon
# @description: One-line loud cyan look
# @order: 40

sl_render() {
  sl_git
  sl_path_fit $(( SL_COLUMNS - 20 ))
  sl_emit "$(sl_fg256 51)${SL_PATH_FIT}${SL_RESET} ${SL_GIT_BRANCH}"
}
```

The header keys are parsed by `switch.sh` for the theme list. `@order` decides where a theme
sorts; `/sl <number>` takes the theme's position in that sorted list. It survives renames
because it lives in the file.

### Rules

- Define `sl_render` only. No top-level side effects, no `exit`, no reading stdin — the payload is
  already consumed.
- Respect `SL_USE_COLOR=0` (set when `NO_COLOR` is in the environment). The `sl_fg*`/`sl_bg*`
  helpers already return an empty string in that mode; hand-written escapes must be guarded.
- Reset colour before the end of a line. `sl_emit` will do it for you if it has to truncate, but a
  theme that leaves a background colour open will bleed into the prompt.
- Keep it fast. This runs roughly once a second. Shelling out is what costs; the lazy getters are
  cached, plain bash arithmetic is free.
- Budget against `SL_COLUMNS`, not `COLUMNS`. Shed segments when they do not fit rather than
  relying on the clip.

## Data available to `sl_render`

Free — already parsed, no cost to read:

| Variable | Meaning |
|---|---|
| `SL_PATH` | current directory, `~`-relative |
| `SL_CWD` `SL_PROJECT_DIR` | absolute paths |
| `SL_REPO_HOST` `SL_REPO_OWNER` `SL_REPO_NAME` | remote repo identity, may be empty |
| `SL_MODEL_NAME` `SL_MODEL_SHORT` `SL_MODEL_ID` | e.g. `Opus 5 (1M context)`, `Opus 5`, `claude-opus-5[1m]` |
| `SL_EFFORT` | `low`…`max`, may be empty |
| `SL_ULTRACODE` | `1` when ultracode is on |
| `SL_FAST_MODE` `SL_THINKING` `SL_EXCEEDS_200K` | `1`/`0` |
| `SL_COST_TEXT` `SL_COST_MICRO` | session cost, e.g. `$222.07` |
| `SL_LINES_ADDED` `SL_LINES_REMOVED` | diffstat for the session |
| `SL_DURATION_MS` `SL_API_DURATION_MS` | wall clock and API time |
| `SL_CONTEXT_PERCENT` `SL_CONTEXT_REMAINING` | integers, no `%` sign |
| `SL_CONTEXT_TOKENS` `SL_CONTEXT_OUTPUT_TOKENS` `SL_CONTEXT_SIZE` | raw token counts |
| `SL_OUTPUT_STYLE` `SL_VERSION` `SL_SESSION_ID` | strings |
| `SL_COLUMNS` | usable width, already has a safety margin subtracted |
| `SL_USE_COLOR` | `0` under `NO_COLOR` |
| `SL_NOW` `SL_TICK` | epoch seconds, and centiseconds for animation |
| `SL_THEME` | the active theme's name |

Lazy — call the getter first, then read the variables. Each is cached and safe to call twice:

| Call | Then read |
|---|---|
| `sl_git` | `SL_GIT_BRANCH` `SL_GIT_AHEAD` `SL_GIT_BEHIND` |
| `sl_gateway` | `SL_BUDGET_SPENT` `SL_BUDGET_LIMIT` `SL_BUDGET_PERCENT` `SL_BUDGET_PERIOD` `SL_GATEWAY_RAW` |
| `sl_token_burn` | `SL_TOKENS_BURNED` `SL_TOKENS_BURNED_TEXT` |

`sl_gateway` shells out to `build-cli` (90 s cache) and `sl_token_burn` scans the transcript
incrementally. A one-line theme should skip both.

## Helpers

Each writes its result to a variable rather than printing, so there is no subshell.

| Call | Result |
|---|---|
| `sl_width TEXT` | `SL_W` — display columns, wide glyphs counted as 2 |
| `sl_trunc TEXT LIMIT` | `SL_TRUNC` — ellipsised to fit |
| `sl_clip TEXT LIMIT` | `SL_CLIP` — ANSI-aware clip, keeps escapes intact |
| `sl_abbrev N` | `SL_ABBREV` — `466900` → `466k`, `1200000` → `1.2M` |
| `sl_group N [SEP]` | `SL_GROUP` — `466900` → `466.900` |
| `sl_duration MS` | `SL_DURATION` — `5h51m` |
| `sl_path_tail N [PATH]` | `SL_PATH_TAIL` — last N segments, `…/` prefixed |
| `sl_path_fit LIMIT` | `SL_PATH_FIT` — longest path variant that fits |
| `sl_bar PCT WIDTH [FULL] [EMPTY]` | `SL_BAR`, `SL_BAR_FILLED`, `SL_BAR_WIDTH` — uncoloured |
| `sl_rule WIDTH [GLYPH] [CYCLE]` | `SL_RULE` — animated gradient horizontal rule |
| `sl_cos TURN` | `SL_COS` — cosine, −1000…1000, `TURN` is 0…1023 per revolution |
| `sl_palette T bR bG bB aR aG aB oR oG oB` | `SL_R` `SL_G` `SL_B` — cosine gradient palette |
| `sl_phase CYCLE_SECONDS` | `SL_PHASE` — 0…1023, advances with wall clock |
| `sl_home_relative PATH` | `SL_HOME_RELATIVE` |

Colour helpers print to stdout, so use them inside `"$( )"`:
`sl_fg256 N`, `sl_bg256 N`, `sl_fg R G B`, `sl_bg R G B`, `sl_bold`, `sl_dim`, and `$SL_RESET`.

## Animation

`SL_NOW` (epoch seconds) and `SL_TICK` (epoch centiseconds) are the only clocks. Derive every
animated value from them arithmetically — never `$RANDOM`, never `date`. Two renders of the same
frame must be byte-identical, or the statusline flickers.

The refresh interval is one second, so an animation gets roughly 1 fps. Budget movement per frame
accordingly: anything that moves less than a cell per frame looks frozen, anything that jumps more
than a tenth of the width looks broken.

## Testing a theme

```bash
~/.claude/statusline/check.sh <theme>     # renders at five widths + NO_COLOR, fails on overflow,
                                          # stderr, missing resets, escapes leaking, empty output
~/.claude/statusline/check.sh --all
```

Three environment variables exist for testing and are honoured by `core.sh`:

| Variable | Effect |
|---|---|
| `SL_PREVIEW=1` | never shells out to the gateway and never writes token state — use this for every test render, so a preview cannot corrupt the live session's counters |
| `SL_FAKE_NOW=<epoch seconds>` | pins `SL_NOW`, and derives `SL_TICK` from it |
| `SL_FAKE_TICK=<epoch centiseconds>` | pins `SL_TICK`, and derives `SL_NOW` from it |

Step an animation frame by frame:

```bash
for t in $(seq 0 1 60); do
  SL_FAKE_NOW=$t SL_PREVIEW=1 COLUMNS=100 \
    ~/.claude/statusline/statusline.sh --theme <name> < ~/.claude/statusline/sample-payload.json
  echo
done
```

`switch.sh preview <theme>` renders one theme with a header, `switch.sh preview --all` renders the
whole set.
