# aquarium

> A tank whose water level is the context window you have left

Livio's `water` renderer, bridged onto the Base Theme-switcher. The panel is an
aquarium filled from the bottom, and the water level is your **remaining**
context: 47 % used leaves the bottom 53 % wet. The tank drains as the session
fills up, and when the waterline falls below the scenery the scenery dies —
kelp and coral bleach out, and fish with no room left to swim are drawn as
skeletons on the sand.

It is the one joke in the set that costs you nothing to read: you already know
how full your context is from the number, and the water tells you again without
asking for a glance.

```
                                                                                               ​
                                                                                               ​
                                                                                               ​
                                                  ~                                  ≈
~          ∼~≈~∼~≈          ~≈~∼~≈~∼~          ∼~≈ ∼~           ~≈~∼~≈~∼~          ∼~ ~∼~
 ≈~    ∼~≈~       ~∼~≈~∼  ~∼  ▄      ≈~   ~∼~≈~▄▄▄▄▄▄≈~∼~≈~   ~∼▄▀       ≈~  ≈~∼~≈~      ≈~∼~≈
   ∼~≈~                 ~≈  ▄  ▀       ∼~≈ ·   ▀▀▀▀▀▀      ∼~≈ ▀▀▄▀▄▀▀▀▀▄▄ ∼~                 ~∼
  ▄ ▄▄▄▄                   ▀▄  ▀▄        ▀ ▄ ▀        ▄         ▄▀▀▀▀▀▀▀▀▀∘▀▀▄▄▀▀
 ▀▀▀▀▀▀▀▀▀▄▀▀▀▄▀          ▀     ▀         ▀▀▀         ▀▀▀▄▀▄▀   ▄▀▀▀▀       ▀▀▀▀▀▄▀▄▀    ▄▄▄▄▄▄
  ▀ ▀▀▀▀   ▀▀▀           ▀▀     ▀▀         ▀           ▀▀▀▀     ▀▀▀▀▀        ▀▀ ▀▀▀      ▀▀▀▀▀▀
░░░░░·░░░░·░░░░░··░░░░░░░░░░░·░░░·░░░░░░·░░░░░·░░░░░░░░░░░░░·░░░░░░·░░··░░░░·░░·░░░░░░░····░░░░░
~ 53% water  ·  ctx 47%  ·  /mnt/c/Partitio/Extranet
```

Real render, 100 columns, escapes stripped. The first three rows look blank
because they are the drained air above the waterline — each carries a
zero-width space so Claude Code does not discard it and silently shorten the
panel.

## What's in here

| File | Goes to | Whose | What it is |
|---|---|---|---|
| `aquarium.sh` | `~/.claude/statusline/themes/` | ours | the theme the framework loads |
| `water.py` | `vendor/livio/` | **Livio's, verbatim** | the aquarium |
| `water2.py` | `vendor/livio/` | **Livio's, verbatim** | the same tank at 2×4 octant resolution |
| `watergif.py` | `vendor/livio/` | **Livio's, verbatim** | imported by `water.py` for `SUB_LOOP_CS` and `sub_fits`; its generator is never reached |
| `preview.ansi` | — | — | a real render in colour, 100 columns. `cat preview.ansi` |
| `preview-octants.ansi` | — | — | the same frame at octant resolution |
| `install.sh` | — | — | copies everything into place and selects it |

Plus `../shared/` — `common.py`, `octants.py`, the inert `gifwriter.py`, the
bridge and the bash launcher. Every theme here needs it.

## What it looks like

Twelve rows at a full-width terminal: eleven scene rows and one info row. The
scene is half-block pixel art — two art rows packed into each terminal row with
`▀`/`▄`/`█` and a background colour — so eleven rows of terminal carry
twenty-two rows of picture. A terminal cell is about twice as tall as it is
wide, and the half-block split is what stops the fish reading as blobs.

Top to bottom:

1. **The air.** Everything above the waterline is empty. At 47 % context that
   is three rows; at 92 % it is five and the tank is nearly dry.

2. **The surface.** A band of `~ ≈ ∼` drawn from two superimposed swells —
   a primary one 18 columns per cycle and a chop at 7 — travelling at
   0.55 radians per second with an amplitude of 0.9 rows peak to centre. The
   amplitude is scaled down as the water gets shallow, so a nearly drained tank
   goes flat instead of sloshing over its own seabed.

3. **Open water,** with bubbles rising at one row per second.

4. **Kelp,** rooted in the sand and swaying on a 0.35 rad/s cycle, each stalk
   offset by its own hashed phase so the bed moves as a bed and not as one
   object. Colour ramps through five shades, darkest at the root.

5. **Coral** along the floor, in four colours.

6. **Fish,** drawn as sprites in three sizes and six colour schemes, swimming
   a step per frame. They are clipped to stay under the waterline, so as the
   tank drains they are pushed down into a thinner and thinner band.

7. **The seabed** — one row of `░` sand with `·` pebbles, hashed from the
   column index so it is fixed for a given width and does not crawl.

8. **The info row.** The water percentage, the context percentage, then as much
   of path / branch / model / cost / weekly gateway spend as fits.

**As the tank drains,** anything above the waterline is drawn dead: kelp
withers to a grey-green, coral bleaches, and fish are replaced by skeleton
sprites. Measured at the two extremes with the same frame:

| Context | Info row reads | Scene |
|---|---|---|
| 8 % | `~ 92% water · ctx 8%` | full tank, two rows of surface at the top, fish throughout |
| 47 % | `~ 53% water · ctx 47%` | the render above |
| 92 % | `~ 8% water · ctx 92%` | five empty rows at the top, no surface band left in frame, and markedly sparser scenery in the two rows above the sand |

The bleaching and the skeletons are what the code does above the waterline —
`draw_kelp`, `draw_coral` and `draw_fish` each take an `alive(x, y)` predicate
and swap to `KELP_DEAD`, a bleached palette and the `SKEL_*` sprites when it
returns false. What is measurable from a plain-text render is the geometry: the
tank visibly empties and the scenery thins. The colour change needs
`cat preview.ansi` and a drained session to see properly.

**Animation.** Everything derives from `SL_NOW`, which the bridge pins, so two
renders of the same second are byte-identical. The refresh is roughly 1 fps.

## What data it shows

The info row, in the order segments are dropped — the last one listed goes first.

| Shown | Field |
|---|---|
| water remaining, `~ 53% water` | `100 − SL_CONTEXT_PERCENT` |
| context used, `ctx 47%` | `SL_CONTEXT_PERCENT` |
| current path | `SL_PATH`, shortened to 34 characters by his own `short_path` |
| git branch | resolved by the host and handed in, never forked per frame |
| model display name | `Opus 5 (1M context)` |
| session cost | `$222.07` |
| weekly gateway spend | `wk $412/$1,500 28%`, from `sl_gateway`; absent in preview mode |

Not read at all: the session diffstat, wall-clock and API durations, token
counts, ahead/behind counts, output style, version, session id, remote repo
identity, and the fast-mode / thinking / ultracode flags. The scene is using
eleven rows; the one text row answers "how full, where, what is it costing" and
stops.

## How it behaves as the terminal narrows

Measured by rendering the bundled sample payload at **every width from 20 to
180 columns** and recording where the output changes. The framework subtracts a
4-column safety margin, so the theme budgets against `SL_COLUMNS = COLUMNS − 4`.

**Height.** The panel is `min(requested, SL_COLUMNS ÷ 3)`, floored at 5 rows.
The default request is 11 scene rows, so the panel only reaches full height once
the terminal is wide enough to pay for it:

| Terminal columns | Total rows |
|---|---|
| 20 – 21 | 6 |
| 22 – 24 | 7 |
| 25 – 27 | 8 |
| 28 – 30 | 9 |
| 31 – 33 | 10 |
| 34 – 36 | 11 |
| ≥ 37 | 12 — full height, and it stops growing |

**The info row** sheds whole segments at separator boundaries rather than
truncating, so a field is either fully there or not there at all:

| Terminal columns | Info row |
|---|---|
| 20 – 26 | `~ 53% water` |
| 27 – 55 | `+ ctx 47%` |
| 56 – 130 | `+ /mnt/c/Partitio/Extranet` |
| 131 – 154 | `+ the git branch` |
| 155 – 166 | `+ Opus 5 (1M context)` |
| ≥ 167 | `+ $222.07` |

The branch in these measurements is **70 characters** long
(`1380-add-environment-indicator-test-prod-to-partitio-matching-extranet`),
which is why it costs 75 columns to admit. Re-measured against a repo on branch
`main` at path `/tmp/shortbranch`, the same sweep gives: path at 48, branch at
**57**, model at 81, cost at 93. So the table above is payload-dependent and the
long branch is the worst case, not the normal one.

This is the one place the theme is less graceful than a native one: there is no
truncation step between "whole branch" and "no branch". Native themes ellipsise
a long branch to a cap; this one drops it.

**Under `NO_COLOR`** the theme collapses to four rows — his flat-tank fallback,
three rows of `~` and `≈` marking the water, plus the info row — and emits no
escapes at all. The scene is dropped rather than rendered monochrome, because
the water body is a painted background with a space in it: strip the colour and
you get blank rows, not art.

## Requirements

- **`python3`**, stdlib only. No pip, no network, no node.
- **A truecolour terminal.** Every colour is a 24-bit escape. Under
  `NO_COLOR` you get the four-row fallback described above, which is legible
  but is not an aquarium.
- **A font with block-element coverage** — `▀ ▄ █ ░ ▌` (U+2580–U+259F) plus
  `~ ≈ ∼ · ∘`. Any Nerd Font, DejaVu Sans Mono, Cascadia Code or JetBrains Mono
  has all of it. **No octant glyphs are needed** in the default mode, which is
  why this is the one scenery theme here that works on an ordinary font.
- **bash 4.2+** for the framework.
- **Cost: about 240 ms per render** at 100 columns on this machine, measured
  over five warm renders. That includes Python startup. The refresh is about
  once a second, so it is comfortable. The theme calls `sl_git` and
  `sl_gateway`; the Python itself forks nothing.
- Platform-neutral. Nothing Windows-, WSL- or macOS-specific — the Windows
  Terminal background machinery is deliberately not shipped (see
  [`../README.md`](../README.md)).

## Install

With the Base Theme-switcher already at `~/.claude/statusline/`:

```sh
./install.sh
```

That copies `../shared/{common,octants,gifwriter,render}.py` and
`../shared/wrapper.sh` plus `water.py`, `water2.py` and `watergif.py` into
`~/.claude/statusline/vendor/livio/`, drops `aquarium.sh` into `themes/`,
selects the theme and runs the linter. `SL_HOME=/elsewhere ./install.sh` to
install into another framework.

By hand:

```sh
mkdir -p ~/.claude/statusline/vendor/livio
cp ../shared/*.py ../shared/wrapper.sh ~/.claude/statusline/vendor/livio/
cp water.py water2.py watergif.py ~/.claude/statusline/vendor/livio/
cp aquarium.sh ~/.claude/statusline/themes/
```

Then `/sl aquarium`, or its number in the `/sl` list — `@order: 40` in the
file's header decides where it sorts and survives a rename.

Check it:

```sh
~/.claude/statusline/check.sh aquarium
```

Renders at 30/40/50/60/80/100/160/220 columns plus `NO_COLOR` and fails on
overflow, stray stderr, a missing reset, escapes leaking under `NO_COLOR`,
trailing whitespace and empty output. **The copy in this folder passes with
zero failures.**

Nothing else is copied anywhere: no font, no wallpaper, no shader, no terminal
configuration. Selecting this theme resets the terminal background to the plain
look and restores whatever the previous theme had installed.

## Tuning

| Variable | Default | Effect |
|---|---|---|
| `SL_AQUARIUM_ROWS` | `11` | panel height, clamped to 5…24 and again by the width |
| `SL_AQUARIUM_PIXELS` | half-block | set to `octant` for `water2`, the same tank at 2×4 resolution |

### `SL_AQUARIUM_PIXELS=octant`

`water2.py` redraws the sprites at 2×4 subpixel resolution instead of 1×2 — the
fish get shading and a highlight along the flank, the kelp gets an edge. Same
physics, same geometry, same info row; it imports `water` for all of that.

`cat preview-octants.ansi` for a real render of the same frame. It is visibly
denser.

The catch is that it **needs a font carrying Unicode 16's Symbols for Legacy
Computing Supplement** (U+1CD00–U+1CDE5). CaskaydiaMono NF has them; Cascadia
Mono and Ubuntu Mono do not, and the tank comes out as a field of tofu boxes.
There is no automatic detection and no graceful degradation — `water2` *is* the
octant variant. If it looks wrong, unset the variable; the default is the
half-block renderer precisely because it works everywhere.

## Uninstall

```sh
rm ~/.claude/statusline/themes/aquarium.sh
```

Then `/sl <something-else>`. The modules under `vendor/livio/` are shared with
`kyoto` and `vice`; only remove `water*.py` if neither of those is
installed either.

## Credits

The aquarium, the physics, the sprites and the joke are Livio's. The bridge and
the packaging are adaptation work.
