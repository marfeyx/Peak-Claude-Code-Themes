# sbb

> **SBB station — metrics ride the wagons, expresses run the far tracks**

A Swiss railway terminus rendered in the Claude Code status line. Your session
metrics are painted on the side of a stationary rake standing at the platform;
everything else in the picture — two through tracks worked in both directions,
the catenary, the exit signals, the departure board — moves around it.

It is a theme for the `~/.claude/statusline` framework (see
`../../Base Theme-switcher`). One file, one `sl_render` function, no daemon,
no background process.

```
File        Goes to                        What it is
sbb.sh      ~/.claude/statusline/themes/   the theme
preview.ansi  —                            `cat` it to see the thing in colour
```

---

## What it looks like

At a comfortable width (100 columns or more) the theme occupies **nine rows**,
top to bottom:

| Row | Content |
|---|---|
| 1 | **Concourse header.** A red `▐ SBB CFF FFS ↔ ▌` plate, then a blue plate holding the current path. |
| 2 | **Catenary.** A contact wire `╌` with masts `┬` every 11 columns, and a `∧` wherever a pantograph on the track below is passing under it. |
| 3 | **Far track A.** A through train running left → right. |
| 4 | Spacer (a zero-width space — visually an empty line, used to give the two tracks air). |
| 5 | **Far track B.** A through train running right → left. |
| 6 | Spacer. |
| 7 | **The rake.** A red shunting loco carrying the service number, then one wagon per metric — this is the row with your actual data on it. Past the end of the train the rest of the platform is furnished with lamp posts `╥` and benches `▄` on a fixed 9-column pattern, so the furniture appears to slide past as the rake creeps out. |
| 8 | **Underframe.** Rail with wheels `●` under each wagon, sleepers `┯` beyond the train, and a red buffer stop `╣` at the end of the platform. |
| 9 | **Departure board.** Next minute, service number, `nach <branch>`, and a status word. |

### What animates

Every movement is derived arithmetically from `SL_NOW` / `SL_TICK`, so two
renders of the same second are byte-identical and the line never flickers. The
refresh rate is roughly 1 fps.

| Thing | Cycle | Behaviour |
|---|---|---|
| **Far trains** | 72 s | Six booked runs per cycle: three left → right starting at t+0 s (23 s run), t+25 s (23 s) and t+48 s (24 s); three right → left at t+10 s (20 s), t+32 s (20 s) and t+52 s (20 s). Each is drawn from a 10-entry timetable with its own rolling stock — IC 1, IR 36, S 12, EC 317, TGV 9264, a Hupac intermodal freight, IC 5, RE 33, IC 21 and NJ 470. The stock is actually different per service: Giruno, double-deck IC2000, FLIRT, TGV Lyria grey, Nightjet blue sleepers, EW IV coaches behind an Re 460, and multicoloured Hupac flats behind an Re 620. |
| **Exit signals** | with the trains | The `▮` at the far end of each track is **green** when the track is clear, **amber** in the three seconds before a booked run, **red** while a train is on it. |
| **Pantographs** | with the trains | Every powered vehicle raises a `∧` onto the catenary row as it passes. |
| **The rake** | 42 s | Stands still at column 3 for 36 s, then is "booked out": in the last 6 s it creeps one column left every two seconds until it reaches column 0, and the cycle restarts with a fresh rake. |
| **End caps** | 42 s | White for the first 3 s after a rake berths (arrival), the wagon's own accent colour thereafter, and flashing lemon on even seconds while departing. |
| **Context alarm** | 1 s | At ≥ 90 % context the context wagon's end caps flash bright red on even seconds. |
| **SBB logo** | 4 s | The red plate brightens for one second in four. |
| **Clock** | 60 s | The departure board shows the *next* whole minute, like a real Swiss board. |

There is a Mondaine-style second hand and a night flag computed in the source;
only the night flag reaches the screen (see *Known dead weight* below).

---

## What data it shows

**On the rake (row 7), one wagon per metric**, in this fixed order:

| Wagon | Variable | Notes |
|---|---|---|
| `Kontext` | `SL_CONTEXT_PERCENT` | Always present. Green < 50 %, orange 50–74 %, dark red 75–89 %, SBB red ≥ 90 %. Renders `k. A.` in grey if the payload has no number. |
| `Kosten` | `SL_COST_TEXT` | Always present. Falls back to `$0.00`. |
| `Diff` | `SL_LINES_ADDED` / `SL_LINES_REMOVED` | Only when the session has touched a line. `+696` in green, `/-276` in red. |
| `Ladung` | `SL_TOKENS_BURNED` | Total tokens burned this session, abbreviated (`41.0M`). Only requested at ≥ 90 terminal columns. |
| `Traktion` | `SL_MODEL_SHORT` | e.g. `Opus 5`. |

**Elsewhere:**

- **Header** — `SL_PATH`, fitted to the space left over (`sl_path_fit`, so it
  degrades `/mnt/c/Partitio/Extranet` → `…/c/Partitio/Extranet` → `…/Extranet`).
- **Loco number and board badge** — derived from `SL_EFFORT`:
  `low → S 12`, `medium → RE 33`, `high → IR 90`, `xhigh → IC 1`,
  `max → EC 13`, unset → `R`. Between 23:00 and 04:59 local, `S 12` becomes
  `SN 12` (the Swiss night-S-Bahn).
- **Board destination** — `SL_GIT_BRANCH`, truncated to fit. With no branch it
  falls back to a Swiss station name chosen deterministically from
  `SL_SESSION_ID`, so a given session always "goes to" the same place.
- **Board clock** — the next whole minute.
- **Board status word** — `Einfahrt` (arriving) for the first 4 s of a rake
  cycle, `Abfahrt` (departing) for the last 6 s, `überfüllt` when context is
  ≥ 90 %. Earlier conditions win.

**Deliberately omitted:**

- **The gateway budget.** `sl_gateway` is never called, so the theme never
  shells out to `build-cli`. Nothing in the picture shows spend-against-limit.
- `SL_DURATION_MS`, `SL_API_DURATION_MS`, `SL_REPO_NAME` — a "Fahrzeit …"
  notice for these exists in the source but is behind a flag that is never set.
- `SL_GIT_AHEAD` / `SL_GIT_BEHIND`, `SL_VERSION`, `SL_OUTPUT_STYLE`,
  `SL_ULTRACODE`, `SL_FAST_MODE`, `SL_THINKING`, `SL_EXCEEDS_200K` — not shown.

---

## How it behaves as the terminal narrows

The framework subtracts a 4-column safety margin, so `SL_COLUMNS = COLUMNS - 4`.
All breakpoints below are given in **real terminal columns** and were measured
by rendering, not read off the constants.

Two kinds of shedding happen independently: **scene rows** drop out at hard
constants, and the **rake** is replanned to fit whatever width is left.

Scene rows:

| Terminal columns | Rows | Scene |
|---|---|---|
| **≥ 100** | 9 | Header, catenary, track A, track B, rake, underframe, board. |
| **60 – 99** | 8 | Same without the catenary row. |
| **36 – 59** | 4 | Header, rake, underframe, board. No tracks, no signals, no catenary. |
| **≤ 35** | 2 | **Compact fallback** — the station is abandoned: row 1 is `▐ ↔ ▌ HH:MM ▐ path ▌`, row 2 is `ctx 47% · $222.07 · <branch>`, each element dropped in turn as space runs out. |

The 60 / 100 thresholds are hard constants and do not move. The 36 is a
constant *plus* a feasibility test: if the rake cannot be made to fit at all,
the theme falls back to compact even above 36.

Two more breakpoints in the furniture:

- **52** — below this the `SBB CFF FFS ↔` plate shrinks to a bare `▐ ↔ ▌`.
- **45** — below this the departure board drops `nach <branch>` and shows only
  the time and the service number. (Badge-width dependent; a wider badge like
  `RE 33` pushes it up a column or two.)

The rake, measured with the framework's sample payload (`IC 1`, `47%`,
`$222.07`, `+696/-276`, `41.0M`, `Opus 5`):

| Terminal columns | Rake |
|---|---|
| **≥ 110** | loco, long labels, all five wagons incl. `Traktion` |
| **90 – 109** | loco, long labels, four wagons (`Traktion` gone) |
| **74 – 89** | loco, long labels, three wagons (`Ladung` gone — token burn is not even requested below 90) |
| **54 – 73** | loco, long labels, two wagons (`Diff` gone) |
| **44 – 53** | loco, **short** labels (`ctx 47%`, `$222.07`), two wagons |
| **42 – 43** | **no loco**, long labels, two wagons |
| **36 – 41** | no loco, short labels, two wagons |

The 42–43 band looks like a bug and is not: the planner tries
loco + short labels *before* no-loco + long labels, so there is a two-column
window where dropping the locomotive buys back the full German labels. These
rake numbers all move with the width of your own figures — a four-digit diff or
a `$1,234.56` cost shifts each band by a couple of columns.

`Kontext` and `Kosten` are never dropped. If even those two will not fit, the
theme bails out to the compact fallback.

---

## Requirements

- **bash 4.2 or newer.** The theme uses `declare -gA`, `printf -v`, and
  `printf '%(%H:%M)T'`. macOS ships bash 3.2 — install a newer bash, or run the
  status line under one.
- **A truecolour terminal.** Non-negotiable for the look. SBB red
  (`235,0,0`), the Nightjet blue, the Hupac container colours and the signal
  amber are all emitted as 24-bit `38;2;R;G;B` sequences, mixed with 256-colour
  greys for the rolling stock shells. On a 256-colour-only terminal the greys
  survive and every brand colour collapses to whatever the terminal guesses —
  which is to say, the train stops being red. Windows Terminal, iTerm2, kitty,
  Alacritty, WezTerm and modern VTE are all fine.
- **A UTF-8 locale.** The theme prints `Zürich HB`, `Genève-Cornavin`,
  `überfüllt` and `Biel/Bienne`.
- **Glyph coverage, but no Nerd Font.** Everything is plain Unicode: box
  drawing (`━ ┯ ┬ ┃ ╍ ╌ ╥ ╣`), block elements (`█ ▀ ▄ ▌ ▐ ▮`), geometric shapes
  (`● ▶ ◀`), `≡`, `∧`, `↔`. Any reasonably complete monospace font has them.
  A font that renders the half-blocks `▀`/`▄` without a hairline gap between
  cells makes the trains look considerably more solid.
- **Zero-width space tolerance.** Rows 4 and 6 are a single `U+200B`. A
  terminal that renders that as a visible box will put two dots in your picture.
- **Cheap, with one caveat.** The theme never calls the gateway, so there is no
  `build-cli` subprocess and no network. It does call `sl_git` every frame
  (cached by the framework) and, **only at 90 columns or wider**, `sl_token_burn`,
  which `stat`s the transcript and reads the new bytes since last frame against
  a byte budget, caching its offsets. That is the one non-trivial cost; at
  narrower widths the theme is pure bash arithmetic.
- **`python3`** is needed by the framework's `check.sh` linter, not by the theme.
- **Nothing platform-specific.** No Windows Terminal shader, no wallpaper, no
  generated assets. It works the same in WSL, Linux and macOS.

---

## Install

Assuming the Base Theme-switcher is already installed at
`~/.claude/statusline/`:

```sh
cp sbb.sh ~/.claude/statusline/themes/sbb.sh
```

Then, inside Claude Code:

```
/sl sbb
```

or from a shell:

```sh
~/.claude/statusline/switch.sh set sbb
```

The theme header declares `@order: 15`, so `/sl 15` selects it too, and the
number survives a rename.

There is **no second file**. Nothing goes into Windows Terminal, nothing goes
into `~/.claude/themes/`, no settings file is touched beyond the switcher's own
`selected` marker.

Verify it with the framework's linter:

```sh
~/.claude/statusline/check.sh sbb
```

It renders at 60, 80, 100, 160 and 220 columns plus `NO_COLOR`, and fails on
overflow, stderr, a missing colour reset, escapes leaking under `NO_COLOR`,
trailing whitespace or empty output. As shipped here, `sbb` reports
`0 failing check(s)`.

To watch the animation without waiting for real time to pass:

```sh
for t in $(seq 1759300200 1759300280); do
  SL_FAKE_NOW=$t SL_PREVIEW=1 COLUMNS=120 \
    ~/.claude/statusline/statusline.sh --theme sbb \
    < ~/.claude/statusline/sample-payload.json
  echo
done
```

---

## Preview

Rendered with the framework's `sample-payload.json` at 100 columns, frame
`SL_FAKE_NOW=1759300431` — a double-deck IC2000 on track A heading right under
two raised pantographs, a Hupac intermodal freight on track B heading left, and
the rake standing at the platform with all four metric wagons:

```
▐ SBB CFF FFS ↔ ▌  ▐ /mnt/c/Partitio/Extranet ▌
┬╌╌╌╌╌╌╌╌╌╌┬╌╌╌╌╌╌╌╌╌╌┬╌╌╌╌╌╌╌╌╌╌┬╌╌╌╌╌╌╌╌╌╌┬╌∧╌╌╌╌╌╌╌╌┬╌╌╌╌∧╌╌╌╌╌┬╌╌╌╌╌╌╌╌╌╌┬╌╌╌╌╌╌╌╌╌╌┬╌╌╌╌╌╌╌
┯━━━┯━━━┯━━━┯━━━┯━━━┯━━━┯━━━┯━━━┯━━━┯━━━┯━◀█▬≡▀▄╍▀≡┃≡▀╍▀≡┃≡▀╍▀≡┃≡▀╍▀≡┃≡▀╍▀≡┃≡▀╍▀≡┃≡▀╍▀≡┃≡▮

▮━━━┯━━━┯━━━┯━━━┯━━━┯━━━┯━━━┯━━━┯━━━┯━━━┯━━━┯━━━┯━━━┯━━━◀█▬█▀▄╍▀▀▀▀╍▀▀▀▀╍▀▀▀▀╍▀▀▀▀╍▀▀▀▀╍▀▀▀▀╍▀▀▀

   ◀█▬ IC 1 ▄▀╍▐ Kontext 47% ▌╍▐ Kosten $222.07 ▌╍▐ Diff +696/-276 ▌╍▐ Ladung 41.0M ▌  ▄    ╥  ╥
┯━━━●━━━━━━━●━━━━●●━━━━━━━●●━━━━━●●━━━━━━━━━━●●━━━━━●●━━━━━━━━━━●●━━━━━●●━━━━━━━━●●━━━━━┯━━━┯━━╣
08:34   IC 1   nach 1380-add-environment-indicator-test-prod-to-partitio-matchin…
```

The two apparently blank lines are the zero-width-space spacer rows; they are
one invisible character wide, not empty.

For the same frame in colour:

```sh
cat preview.ansi
```

Regenerate it with:

```sh
SL_PREVIEW=1 SL_FAKE_NOW=1759300431 COLUMNS=100 \
  ~/.claude/statusline/statusline.sh --theme sbb \
  < ~/.claude/statusline/sample-payload.json > preview.ansi
```

---

## Known dead weight

Read the source and you will find machinery that never reaches the screen.
Listing it here so nobody wastes an afternoon looking for it in the render:

- `wgp_monitor_text` and `WGP_BOARD_ROTATE_SECONDS` — a rotating 5-second
  "next departures" monitor, including the `Türen schliessen selbsttätig`
  message. The function is defined and never called.
- `WGP_HANDS` / `WGP_HAND` — a Mondaine second hand, computed every frame and
  never printed. The logo uses a static `↔`.
- `WGP_PLATFORM` and the `Gleis N` label — computed from the session id, built
  into a local variable in `wgp_build_board`, and never appended to the board.
- `poster_text` in `wgp_build_header` is initialised empty and never assigned,
  which disables the right-hand poster *and* the `Fahrzeit 5h51m · Extranet`
  notice that would otherwise sit next to it.
- `WGP_TRACK_BADGE` / `WGP_TRACK_DESTINATION` — the identity of whatever is
  currently running on the far tracks is recorded and never displayed.

None of it costs anything measurable, and none of it breaks the linter. It is
simply scenery that was built and then not wired up.
