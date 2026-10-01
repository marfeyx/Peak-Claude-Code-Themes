# underwater

> Reef scene — fish, squid, jellyfish and kelp over the readout

A statusline theme for the switchable Claude Code statusline framework (the
`Base Theme-switcher` folder in this repo). It paints a small animated aquarium
above your session readout: a rippling waterline, swaying kelp on a seabed, a
pulsing jellyfish, and a rota of fish that swim across trailing bubbles. The
session data lives on one line underneath, so the scene never costs you
information.

Everything in the scene is a pure function of the wall clock. Two renders of the
same second are byte-identical, so it animates without flickering.

```
 ~~   __    ~   ___  ○ ~    _   ~~   ___    ~   __   ~ ~  ___   ~    __   ~ ~   __   ~~    __
                                o   ▄██▄▄▄▄      ▄▀▄                     ▄▄██▄▄
                      ▀        ▀  ▄██▀▀████▀▀▀▀▄███▄           ▀        █▀▀▀▀▀▀█
█▄         █         █        █   ▀██▀▀████▀▀▀▀▀███▀            █▄      █  ██  █
▄█        ▄█        █        █▄     ▀██▀▀▀▀      ▀▄▀▄           ▄█       ████ █    ▄█
▁█▂▁▁▁▁▁▁▁▁█▁▁▁▁▁▁▁▁█▁▁▁▁▁▁▁▁█▂▖▁▁▁▁▁▁▁▂█▂▁▁▁▁▁▁▖▁▁█▁▁▁▁▁▂▁▁▁▁▁▁▁█▂▁▁▂▂▁▁▁█▁▁▂▁▁▁▁▂▁█▁▁▁▁▁▁▁▂▁▁▁
▌ …/Extranet · ⎇ 1380-add-environment-indica… · ctx 47% · $222.07 · Opus 5 (1M context) · ✦xhigh
```

## What's in here

| File | Goes to | What it is |
|---|---|---|
| `underwater.sh` | the framework's `themes/` directory | the theme — one bash file, byte-identical to the author's copy |
| `underwater.hlsl` | shipped with the Base Theme-switcher | applied automatically on Windows Terminal; floods the whole window with water |
| `preview.ansi` | — | a real render with colour, 100 columns. `cat preview.ansi` |
| `install.sh` | — | copies the theme into place and selects it |

## What it looks like

At a full-width terminal the theme occupies **seven rows**: six scene rows and
one data row. Bottom-up, the scene is built as a character grid and then painted
in one pass per row, so the layers composite rather than fight.

1. **Row 0 — the waterline.** A scatter of `~` (lit, pale cyan) and `_` (shadowed,
   darker teal) marking the surface. Each column decides which glyph it shows
   from a cosine of its own position plus a phase that advances on a **29-second**
   cycle, so the ripple travels sideways along the surface. Roughly a quarter of
   the columns are permanently blank, which keeps the surface from reading as a
   solid line.

2. **Rows 1…H−2 — open water.** Deliberately left unpainted. No background colour
   is written here, so a translucent terminal shows its own tint and wallpaper
   through, and the optional shader (below) has somewhere to put the water. This
   is where the fish, the squid's ink, the bubbles and the jellyfish are drawn.

3. **Row H−1 — the seabed.** One glyph per column, chosen by a hash of the column
   index, so the sand is fixed for a given width and does not crawl: mostly `▁`
   sand, occasional `▂` dunes, rare `▖` pebbles.

4. **Kelp**, rooted on the seabed and growing up into the water. Stalk positions
   are hashed from the column index — fixed per width, minimum 9 columns apart,
   about 30 % of eligible columns — with heights of 2–4 rows and one of five
   frond variants. The whole bed bends together on a **13-second** sway cycle,
   each stalk offset by its own hashed phase, and the bend grows with height so
   the tips move further than the roots. Colour ramps from deep green at the root
   to a pale tip.

5. **The jellyfish.** Only drawn when the scene is at least 70 columns wide. It
   rises one row every **6 seconds** until it reaches the surface, then wraps back
   to the seabed. Its bell pulses between a wide and a narrow frame **every
   second**, its tentacles cycle through three poses on a 3-second loop, and it
   drifts left and right about the three-quarter mark of the width on a 47-second
   cosine.

6. **The traffic.** A fixed timetable of six runs on a **153-second** loop, so the
   full cast comes round roughly every two and a half minutes:

   | Starts at | For | Direction | Creature |
   |---|---|---|---|
   | 0 s | 34 s | left → right | clownfish (large, orange, white bands) |
   | 37 s | 18 s | right → left | a school of three yellow minnows |
   | 57 s | 22 s | left → right | pink snapper |
   | 81 s | 18 s | right → left | a school of three minnows, higher up |
   | 101 s | 26 s | left → right | purple squid |
   | 129 s | 22 s | right → left | pale manta ray |

   Each crosses the full width over its run, mirrored to face the way it is
   going, and beats its tail or its arms on a per-species frame sequence that
   steps once a second. The smaller fish also bob: their swim depth wobbles
   against a cosine of their own horizontal position, so they undulate instead of
   tracking a straight line. The clownfish, snapper and squid vent **bubbles** from
   their trailing edge: one every **3 seconds**, each living **17 seconds**, rising
   one row every three seconds while drifting backwards and wobbling sideways,
   and growing through four glyph/colour stages `.` → `o` → `○` → a bright `○` as
   it ages. The squid additionally puffs a small **ink cloud** beside itself on
   about two seconds in every eleven.

   Creatures are drawn with half-block cells — two art rows packed into one
   terminal row using `▀`/`▄`/`█` with a background colour where the two halves
   differ — which is why a 6-row-tall fish fits in 3 rows of terminal.

7. **The last row — the data.** A pale `▌` gutter, then the session readout, its
   fields separated by a dim ` · `. Nothing on this row animates.

Under `NO_COLOR` every colour helper returns empty and the scene renders as
monochrome block art. It stays legible; it just stops being a reef.

## What data it shows

| Shown | Field | Notes |
|---|---|---|
| ✅ | current path | `~`-relative, shortened to the longest variant that fits |
| ✅ | git branch | `⎇ ` prefixed, truncated, capped at 28 columns. Only on wide terminals |
| ✅ | context used | `ctx 47%`, bold, green → amber at 60 % → red at 85 % |
| ✅ | context tokens | `466k` appended to the context chip when there is room |
| ✅ | session cost | `$222.07`, bold amber |
| ✅ | model | full display name (`Opus 5 (1M context)`) when it fits, else the short name (`Opus 5`) |
| ✅ | reasoning effort | `✦xhigh` |

Deliberately omitted — the theme never reads them:

- the session diffstat (lines added/removed)
- wall-clock and API durations
- the gateway spend budget (so it never shells out to `build-cli`)
- the transcript token-burn counter (so it never scans the transcript)
- git ahead/behind counts — only the branch name
- output style, Claude Code version, session id, remote repo identity
- the fast-mode / thinking / ultracode / exceeds-200k flags
- remaining-context percentage and output-token count

The reasoning is that the scene is already using five or six rows; the data row
earns its keep by answering "where am I, how full am I, what is this costing" and
nothing more.

## How it behaves as the terminal narrows

The framework hands the theme `SL_COLUMNS`, which is the real terminal width
**minus a 4-column safety margin**. Both numbers are given below because only one
of them is something you can see.

| Terminal columns | `SL_COLUMNS` | Total rows | Scene |
|---|---|---|---|
| ≥ 80 | ≥ 76 | 7 | 6 scene rows — the full look |
| 64 – 79 | 60 – 75 | 6 | 5 scene rows |
| 50 – 63 | 46 – 59 | 5 | 4 scene rows |
| 40 – 49 | 36 – 45 | 4 | 3 scene rows — waterline, one row of water, seabed |
| ≤ 39 | ≤ 35 | 2 | **no scene at all** — a two-line text readout |

Two further thresholds inside the scene:

- **Jellyfish: terminal ≥ 74 columns** (`SL_COLUMNS` ≥ 70). Below that it is not
  drawn, because the bell is 12 columns wide and sits at the three-quarter mark.
- **A creature is skipped entirely if it is taller than the water column**, so the
  cast thins out before the rows do. Measured:

  | Terminal columns | Who still swims |
  |---|---|
  | ≥ 64 | everyone — clownfish, minnows, snapper, squid, manta |
  | 50 – 63 | minnows, snapper, manta. The clownfish and the squid are dropped |
  | 40 – 49 | the minnow schools only. Everything else is too tall |

The data row sheds on its own budget, and it is **not monotone** — the planner
reserves room back-to-front and will trade one field for another at a given
width. Measured against a long branch name and a long model name:

| Terminal columns | Data row |
|---|---|
| 40 | `▌ …/Extranet · ctx 47% · $222.07` |
| 42 – 50 | adds the token count: `ctx 47% 466k` |
| 52 | adds the short model name: `· Opus 5` |
| 60 – 76 | the token count and the `✦effort` chip take turns, depending on the exact width; the full model name appears around 62 |
| ≥ 82 | the branch appears, and the path shortens to `…/Extran…` to pay for it |
| ≥ 116 | the path stops being abbreviated at all |

Below 40 columns the scene is abandoned and you get two plain rows: the path
(with the branch appended if it fits) on top, and as many of `ctx`, cost and the
short model name as fit underneath, first-fit. At truly punishing widths that
means you may see the model name and no context percentage, because `Opus 5` is
shorter than `ctx 47%` — that is first-fit, not a priority order.

## Requirements

- **A truecolour terminal. Not optional.** Every colour in this theme is written
  as a 24-bit `38;2;r;g;b` escape; there is no 256-colour fallback path. On a
  terminal that only speaks 256 colours the escapes will be approximated badly or
  ignored, and the fish will be the wrong animal. Set `COLORTERM=truecolor` if
  your terminal supports it but does not advertise it.
- **Bash 4.2 or newer.** The colour cache is an associative array declared with
  `declare -gA`. macOS ships bash 3.2 by default — install a current bash.
- **A font with block-element coverage.** The scene is built almost entirely from
  `▀ ▄ █ ▁ ▂ ▖ ▌` (U+2580–U+259F) and `○` (U+25CB). The data row also uses `⎇`
  (U+2387, the branch marker), `✦` (U+2726, the effort marker), `…` and `·`. Any
  Nerd Font, DejaVu Sans Mono, Cascadia Code or JetBrains Mono has all of it. A
  font missing the block elements will turn the reef into a field of tofu.
- **No python3.** No external assets. No network.
- **Cheap on processes, expensive on bash.** The theme calls `sl_git` and nothing
  else that shells out — it never touches the gateway and never scans the
  transcript, so it does not grow more expensive as a session gets longer. What
  it does do is maintain a width × height cell grid in pure bash arithmetic, which
  on this machine costs roughly 180 ms above the framework baseline at 100
  columns and 410 ms at 220 columns. The statusline refreshes about once a
  second, so that is comfortable, but it is the heaviest theme in the set and it
  scales with your terminal width. On a very slow box, or a 400-column ultrawide,
  prefer something simpler.
- **Platform-independent** — plain bash and ANSI. Only the optional shader below
  is Windows-specific.

## Install

Assuming you already have the Base Theme-switcher installed at
`~/.claude/statusline/`:

```sh
install -m 0644 underwater.sh ~/.claude/statusline/themes/underwater.sh
```

Then, in Claude Code:

```
/sl underwater
```

`/sl 18` also works — the theme declares `@order: 18` in its header, and that
number travels with the file.

Or run the installer in this folder, which does both and offers to place the
shader:

```sh
./install.sh
```

Check it before you trust it:

```sh
~/.claude/statusline/check.sh underwater
```

That renders at 60/80/100/160/220 columns plus `NO_COLOR` and fails on overflow,
stray stderr, a line that ends without resetting colour, escapes leaking under
`NO_COLOR`, trailing whitespace and empty output. The copy in this folder passes
with zero failures.

### The Windows Terminal background

On Windows Terminal this theme **changes the whole window, not just the status
line rows**. Selecting it with `/sl underwater` makes the switcher:

- set the colour scheme to `Deep Water` (creating it if the profile does not
  define it)
- turn on acrylic at 60% opacity, so the window goes translucent cyan
- load `underwater.hlsl`, a pixel shader that paints animated caustics, surface
  light shafts and rising bubbles behind everything

Switching to any other theme puts it back to opaque black. None of this needs
configuring: the Base Theme-switcher installs the shader and
`terminal-background.py` discovers your Windows Terminal settings file, so there
are no paths to edit.

Outside Windows Terminal the background simply does not change and the theme
renders normally on the status line rows alone.

The shader uses `experimental.pixelShaderPath`. Microsoft may rename or remove
that setting, and enabling a shader disables Windows Terminal's own retro
terminal effect.

## Credits

Theme and shader are mine. The framework they plug into is the Base
Theme-switcher in this repo.
