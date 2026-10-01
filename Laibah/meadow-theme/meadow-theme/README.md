# Meadow — a Claude Code status line theme

> *a cat in overgrown grass under a sky that cycles day to night*

The bottom of your terminal becomes a strip of overgrown grass with a cat
walking through it. Behind the whole window, an animated pixel sky moves from
day through sunset to night and back on a 30-minute loop — and the terminal's
colour scheme and Claude Code's own UI theme move with it, off the same clock,
so they can never disagree.

The grass panel is **transparent**: nothing in it paints a background except the
soil, so the sky shows through between the blades.

---

## What you need

| | |
|---|---|
| **Python 3.8+** | Pure standard library — there is nothing to `pip install`. |
| **Claude Code** | The status line is a Claude Code feature. |
| **Windows Terminal** *(optional)* | Needed for the sky and the colour schemes. Without it you still get the grass panel. |
| **A truecolor terminal** | 24-bit colour. Windows Terminal, iTerm2, most modern Linux terminals. |
| **A font with block elements** | The grass is drawn from `▀` (U+2580) and `▄` (U+2584). Cascadia Mono — bundled with Windows Terminal — has them, as do DejaVu Sans Mono, Menlo, JetBrains Mono and most Nerd Fonts. A font without them shows tofu boxes. |

It was built on WSL2 + Windows Terminal. The **grass panel works anywhere**
Python and Claude Code do — WSL2, macOS and Linux are all fine. The **sky and
colour schemes are Windows Terminal only**; that half is skipped automatically,
and nothing breaks without it.

On **native Windows** (no WSL), the theme itself is fine but `install.sh` is a
bash script and won't run — use Git Bash, or copy the `claude/` folder into
`%USERPROFILE%\.claude\` by hand and set `statusLine.command` yourself.

If you set `CLAUDE_CONFIG_DIR`, the installer follows it.

---

## Install

```bash
unzip meadow-theme.zip
cd meadow-theme
./install.sh
```

That's it. It takes about a minute, almost all of it rendering the sky.

(If you extracted with Windows Explorer rather than `unzip`, the executable bit
is lost and you'll get *permission denied* — just run `bash install.sh`.)

Then **open a new Claude Code session** — the meadow shows up in the status line.

Other ways to run it:

```bash
./install.sh --no-build   # skip the sky render; do it later with ~/.claude/sl-switch.sh meadow
./install.sh --files      # copy files only, change none of your settings
```

---

## What it actually touches

I'd want to know this before running someone else's script, so:

**Files added** under `~/.claude/` — `statusline.py`, four `sl-*` driver
scripts, nine modules in `statuslines/`, two theme files in `themes/`, and
`commands/sl.md` for the `/sl` command. Anything already there with the same
name is copied to `<name>.before-meadow-<timestamp>.bak` first.

If you already have your own status line themes in `~/.claude/statuslines/`,
they're left in place and `/sl` will list them alongside meadow.

**`~/.claude/settings.json`** — backed up to `settings.json.before-meadow.bak`,
then *one key* is merged in: `statusLine`. The file is not replaced.

**Your Claude Code UI theme** — switched to a light theme by day and a dark one
after dark. Your original is recorded the first time it switches and put back on
uninstall. (This has to happen: Claude Code draws its own text colours, and a
dark-on-dark theme is unreadable against a bright sky.)

**Your Windows Terminal profile** — gains a background image and a colour
scheme. The original values are snapshotted before the first change, and the
whole `settings.json` is copied to `*.before-claude-water.bak` too.

**~14 MB of rendered GIF** in `%LOCALAPPDATA%\claude-statusline\`. Generated on
your machine, not shipped — that's why this zip is small.

**Nothing leaves your machine.** No network calls, no telemetry.

---

## Using it

```
/sl              show the active theme and what else is available
/sl meadow       switch to meadow (also re-applies the sky if it drifted)
/sl meadow 14    make the grass panel 14 rows tall (or "full", or "auto")
```

Peek at a different time of day without waiting for it:

```bash
# render the whole cycle as one PNG
python3 ~/.claude/statuslines/preview_meadow.py /tmp/meadow-cycle.png

# or pin the clock for a single session
SL_MEADOW_PHASE=night claude
```

Knobs, all optional environment variables:

| Variable | Effect |
|---|---|
| `SL_MEADOW_PHASE` | Pin the clock: `day`, `sunset`, `night`, `dawn`, or `0`–`1`. |
| `SL_MEADOW_PERIOD` | Seconds for a full cycle. Default `1800`. Minimum `30`. |
| `SL_MEADOW_HEIGHT` | Panel height in rows, or `full`. |
| `SL_DEBUG=1` | Raise theme errors instead of swallowing them. |
| `STATUSLINE_NO_TRUECOLOR=1` | Fall back to the 256-colour palette. |

Changing the period means the sky needs re-rendering — `/sl meadow` notices and
does it.

---

## Uninstalling

```bash
./uninstall.sh           # restore your terminal, colour scheme and UI theme
./uninstall.sh --purge   # also delete the installed files and the rendered sky
```

Your `*.before-meadow*.bak` backups are never deleted.

**Keep this folder** — `uninstall.sh` lives here, and it's the way back out.
Meadow is the only theme in the bundle, so `/sl` has nothing else to switch to.

---

## If something looks wrong

**Status line is blank or shows an error.** Run it by hand to see the real
exception:

```bash
echo '{}' | SL_DEBUG=1 python3 ~/.claude/statusline.py
```

**Sky doesn't appear.** It needs Windows Terminal, and `WT_SESSION` must be set
in the shell you ran the installer from. Check what it thinks is going on:

```bash
python3 ~/.claude/sl-meadow-sky.py status
```

If it says `stale`, render it: `python3 ~/.claude/sl-meadow-sky.py build`

**Sky is there but the text is hard to read.** The background image, the
terminal scheme and the Claude Code theme are supposed to move together;
`/sl meadow` re-applies all three.

**Grass panel but no cat.** The cat wanders — give it a moment.

**Colours look wrong or banded.** The theme emits 24-bit colour by default. If
your terminal can't do truecolor, set `STATUSLINE_NO_TRUECOLOR=1` to drop to the
256-colour palette. (`COLORTERM` is not consulted — don't bother setting it.)

**Empty boxes instead of grass.** Your font is missing `▀`/`▄`. Switch the
terminal font to Cascadia Mono, DejaVu Sans Mono, or anything with Unicode Block
Elements.

**You're in Windows Terminal but the installer says you aren't.** It keys off
`WT_SESSION`. That's normally set inside WSL automatically; if it isn't, run
`WT_SESSION=1 ./install.sh`.

---

## How it fits together

```
settings.json  statusLine.command
       │
       └─> statusline.py ──reads──> ~/.claude/statusline-theme  ("meadow")
                  │
                  └─> statuslines/meadow.py          the grass, the cat, the info line
                            ├─> daylight.py          ONE clock: phase -> palette
                            ├─> common.py            canvas / half-block pixel layer
                            ├─> agentcount.py        live subagent count
                            └─> skydriver.py         notices a segment boundary, detaches:
                                       │
                                       └─> sl-meadow-sky.py
                                                ├─> meadowsky.py + gifwriter.py   render the sky
                                                ├─> sl-water-bg.py    Windows Terminal bg + scheme
                                                └─> sl-cc-theme.py    Claude Code UI theme
```

The sky is cut into six GIFs rather than one long one for a specific reason:
Windows Terminal hands the image to the XAML decoder, which offers no way to
read or seek playback position. Changing the image *path* is the only thing that
restarts a GIF from frame zero — so each segment swap re-anchors the sky to the
same wall clock the panel reads. `sl-water-bg.py` is named for an earlier water
theme; meadow shares its Windows Terminal plumbing so that two scripts can't
both claim to know your profile's "original" settings.

Enjoy the cat.
