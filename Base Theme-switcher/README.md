# Base Theme-switcher

The engine every theme in this repo's person folders plugs into. It is a Claude Code
status line that can hold many looks at once: one bash file per theme, a numbered list,
and `/sl 3` to switch between them without editing a config file.

Install this first. Then drop in any theme from `Jakob/`, `Laibah/`, `Livio/` or
`Liza/`, and it shows up in the list.

```
~/.claude/statusline/
  statusline.sh           entry point — settings.json statusLine.command points here
  core.sh                 shared data layer and layout helpers
  switch.sh               the CLI behind /sl and /statusline-theme
  check.sh                the objective linter for a theme
  terminal-background.py  optional Windows Terminal look, applied on theme switch
  sample-payload.json     a frozen payload, used for previews and checks
  selected                plain text, the active theme's name
  themes/*.sh             one file per look
~/.claude/commands/
  sl.md                   /sl
  statusline-theme.md     /statusline-theme
```

## Why themes are separate files

Claude Code gives you exactly one hook: `statusLine.command`, a program that gets a JSON
payload on stdin and prints lines. Everything else — which look is active, how you switch,
how you preview — has to be built on top of that one string.

So the string never changes. It always points at `statusline.sh`, and `statusline.sh`
decides at render time which theme file to source. Switching a theme is then a one-word
write to a text file, not an edit of `settings.json`, which means it is instant, reversible,
and cannot leave your config broken. It also means a theme is a self-contained artifact:
one file, one function, no dependencies on the others, and you can hand it to someone else
by copying it into their `themes/` folder.

## Architecture

**`statusline.sh`** reads the payload, sources `core.sh`, resolves the theme, sources
`themes/<name>.sh`, and calls its `sl_render`. Theme resolution, first match wins:

1. `--theme NAME` on the command line (how previews work)
2. `$CLAUDE_STATUSLINE_THEME`
3. `<project>/.claude/statusline-theme` — a per-repo override
4. `~/.claude/statusline/selected`
5. the default, `purple`

A missing theme does not break the status line: it falls back to the default and says so
on its own line.

**`core.sh`** parses the payload exactly once into `SL_*` variables — path, model, effort,
cost, context percentage, token counts, session duration, terminal width, colour support,
clock. Reading any of those is free.

The three expensive things are lazy getters, so a cheap theme stays cheap: `sl_git` shells
out to git, `sl_gateway` queries the gateway budget with a 90 second cache, and
`sl_token_burn` incrementally scans the session transcript. A one-line theme calls none of
them and costs almost nothing. `core.sh` also carries the layout helpers — ANSI-aware
clipping, path fitting, number abbreviation, bars, cosine gradient palettes — each writing
to a variable rather than printing, so no theme has to fork a subshell to lay out a line.

**A theme** is one bash file defining one function, `sl_render`, plus a metadata header:

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

`@order` fixes the number the theme answers to in `/sl <number>`, and survives renames
because it lives in the file rather than in an index. Every line `sl_emit` produces is
clipped to the terminal width, so a theme can never wrap your prompt.

## Install

```sh
./install.sh
```

It copies the renderer, `core.sh`, `switch.sh`, `check.sh`, `terminal-background.py` and
`sample-payload.json` into `~/.claude/statusline/`, the bundled themes into
`~/.claude/statusline/themes/`, and the slash commands into `~/.claude/commands/` —
rewriting the absolute path baked into those command files so they point at *your* home
and not the author's.

It then sets `statusLine.command` in `~/.claude/settings.json`, backing the file up with a
timestamp first and writing through a temporary file that is re-parsed before it replaces
the original. Other keys in `settings.json` are left alone. If the file does not exist, it
is created.

Finally it seeds `selected` with `purple` if no theme is selected yet, so a fresh install
renders something immediately.

Re-running is safe and does nothing surprising: files are overwritten with the same
content, the selected theme is kept, and another backup is taken.

Install somewhere other than `~/.claude` with `CLAUDE_DIR`:

```sh
CLAUDE_DIR=/tmp/try-it ./install.sh
```

Restart Claude Code afterwards, or at least start a new session — it reads
`statusLine.command` at startup.

## Using `/sl`

`/sl` and `/statusline-theme` are the same command; the long one is just more discoverable.
Both wrap `switch.sh`, which also works from a plain shell.

| Command | What it does |
|---|---|
| `/sl` | list the themes, active one marked |
| `/sl list` | the same, numbered table |
| `/sl 3` | activate theme number 3 |
| `/sl underwater` | activate by name; a unique prefix is enough |
| `/sl next` / `/sl prev` | step through the list, wrapping at the ends |
| `/sl show` | report which theme is active |
| `/sl preview <ref>` | render one theme against the sample payload |
| `/sl preview --all` | render every theme, with headers |
| `/sl path <ref>` | print the absolute path of a theme file |
| `/sl rename <ref> <name>` | rename the file and its `@name` header together |
| `/sl describe <ref> <text>` | rewrite the `@description` header |
| `/sl clone <ref> <name>` | copy a theme to the end of the list — the way to start a new one |
| `/sl delete <ref> [--force]` | remove a theme file |
| `/sl apply-background` | re-apply the terminal look for the active theme |

A theme's number is its rank once all themes are sorted by `@order` and then by name, so it
is derived from the files every time and never stored. Anywhere a `<ref>` is taken, both the
number and the name work.

## Installing a theme from this repo

Each person folder holds themes. Most are a single `.sh` file:

```sh
cp "Jakob/underwater/underwater.sh" ~/.claude/statusline/themes/
/sl underwater
```

Themes that carry assets — a shader, a wallpaper, a generator — ship their own `install.sh`
and their own README. Read that one; it will tell you what else it touches.

If a theme does not appear in `/sl list`, its header block is missing or malformed. Run
`~/.claude/statusline/check.sh <name>`.

## Writing a theme

The full authoring contract is **[THEME-CONTRACT.md](THEME-CONTRACT.md)** — every `SL_*`
variable, every helper, the animation rules, and the list of things a theme is not allowed
to do. Read it before you start; it is short.

The short version:

```sh
/sl clone purple mytheme      # start from a working theme
/sl path mytheme              # find the file
$EDITOR "$(~/.claude/statusline/switch.sh path mytheme)"
~/.claude/statusline/check.sh mytheme
/sl mytheme
```

Four rules that cause most of the breakage:

- Define `sl_render` and nothing else at top level. No `exit`, no reading stdin — the
  payload is already consumed.
- Budget against `SL_COLUMNS`, not `COLUMNS`. Drop segments that do not fit rather than
  relying on the clip to save you.
- Reset colour before the end of every line, or it bleeds into the prompt.
- Derive animation only from `SL_NOW` and `SL_TICK`. Never `$RANDOM`, never `date`. Two
  renders of the same frame must be byte-identical or the line flickers.

## Checking a theme

```sh
~/.claude/statusline/check.sh mytheme
~/.claude/statusline/check.sh --all
```

`check.sh` renders the theme against `sample-payload.json` at 60, 80, 100, 160 and 220
columns, plus once at 100 with `NO_COLOR` set, and fails on:

- a non-zero exit status
- anything written to stderr
- a line wider than its width budget
- a line whose last escape sequence is not a reset
- any escape sequence at all under `NO_COLOR`
- trailing whitespace on a line that is not painting a background
- rendering nothing

The exit status is the number of failing checks, so it works in a loop. It prints a preview
at 100 columns at the end so you can see what you actually built.

## Testing environment variables

| Variable | Effect |
|---|---|
| `SL_PREVIEW=1` | never calls the gateway and never writes token state — use it for every test render, so a preview cannot corrupt the live session's counters |
| `SL_FAKE_NOW=<epoch seconds>` | pins `SL_NOW`, derives `SL_TICK` from it |
| `SL_FAKE_TICK=<epoch centiseconds>` | pins `SL_TICK`, derives `SL_NOW` from it |

Render one frame:

```sh
SL_PREVIEW=1 COLUMNS=100 ~/.claude/statusline/statusline.sh --theme purple \
  < ~/.claude/statusline/sample-payload.json
```

Step an animation frame by frame:

```sh
for t in $(seq 0 1 60); do
  SL_FAKE_NOW=$t SL_PREVIEW=1 COLUMNS=100 \
    ~/.claude/statusline/statusline.sh --theme mytheme \
    < ~/.claude/statusline/sample-payload.json
  echo
done
```

## Requirements

- **bash 4+.** The scripts use namerefs, associative arrays and `${var,,}`. macOS ships
  bash 3.2 as `/bin/bash`; install a newer one from Homebrew and make sure it is the one on
  `PATH`, or the switcher will not run.
- **awk** — `switch.sh` parses theme metadata headers with it.
- **python3** — required by `install.sh` for the JSON edit, by `check.sh` for the render
  analysis, and by `terminal-background.py`. Stdlib only; nothing to pip install.
- **git**, only if a theme calls `sl_git`. Without it the branch segment is empty and
  nothing breaks.
- **A truecolour terminal** for most themes. 256-colour terminals degrade to something
  wrong but readable; `NO_COLOR` is handled properly and gives plain text.
- Claude Code itself, obviously, for `statusLine.command` to be read at all.

## Limitations

**The terminal background helper is Windows Terminal only.** `terminal-background.py`
edits a Windows Terminal `settings.json` to match the active theme — colour scheme,
acrylic, opacity, pixel shader. On macOS, Linux without WSL, iTerm, Alacritty, Kitty or
anything else, it finds no such file and does nothing. The status line itself is entirely
unaffected; you just do not get the matching window.

**It also hardcodes a path.** The `SETTINGS` constant near the top of
`terminal-background.py` points at one specific Windows user profile. If you are on WSL and
want this to work, open the installed copy at
`~/.claude/statusline/terminal-background.py` and change that path to your own Windows
username. This file is shipped byte-identical to the author's, deliberately — it is a
reference, not a portable tool.

**`erase-prompt-border.hlsl` is Windows Terminal only, and optional.** It is a pixel shader
that replaces a sentinel magenta — the colour Claude Code paints its input-field border —
with a clone of the terminal a few rows away, so the rules above and below the prompt
disappear into whatever is actually behind them. That matters on a translucent window,
where simply painting over them leaves a solid streak. `install.sh` does not install it.
Copy it next to your Windows Terminal `settings.json` and set
`profiles.defaults.experimental.pixelShaderPath` yourself, or let
`terminal-background.py` do it once you have fixed its path. Everything works without it;
you just see the border.

**One theme bundled.** `purple` ships here so a fresh install renders immediately. The rest
live in the person folders of this repo.

**Gateway budget is environment specific.** `sl_gateway` shells out to a `build-cli` binary
that exists inside one corporate setup. Elsewhere it reports "gateway offline" and the theme
carries on. Any theme showing a budget segment will show that instead.

**One second refresh.** Claude Code decides when to re-render, roughly once a second, and
nothing here can make it faster. An animation gets about 1 fps — budget movement
accordingly: less than a cell per frame looks frozen, more than a tenth of the width looks
broken.

**No uninstaller.** Remove `~/.claude/statusline/`, remove the two `.md` files from
`~/.claude/commands/`, and delete the `statusLine` key from `~/.claude/settings.json` — or
restore one of the `settings.json.backup.*` files the installer left next to it.
