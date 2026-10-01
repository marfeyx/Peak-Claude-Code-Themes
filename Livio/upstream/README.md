# upstream — Livio's delivery, as it arrived

**Do not execute anything in this directory.** It is an archive, kept so that
Livio recognises his own work and so the next delivery from him is a diff rather
than an argument.

Nothing here has been edited, reformatted or renamed, with one exception: his
`README.md` is stored as `README.md.orig` so it does not collide with this
label. `SHA256SUMS` lists every file as it stands; `sha256sum -c SHA256SUMS`
from this directory checks it.

That manifest pins the archive from the day it was taken forward. It is not
proof of the delivery itself: no pristine copy of Livio's bundle and no
checksum list from him survives on this machine, so *"byte-identical to what he
sent"* rests on the archivist's word and nothing else. What can be checked, and
is clean, is the internal cross-check — every shipped module `cmp`s equal to
its original under `statuslines/`.

The warning at the top of this file is the only safeguard there is. This tree
sits on a drvfs mount of `C:`, which reports every file as mode `777`: the
execute bit cannot be cleared here, and a `git add` would record these scripts
as `100755`. `install.sh` and `sl-switch.sh` are executable whatever anyone
intends. Do not run them.

```
upstream/
  README.md          this label
  SHA256SUMS         checksums of everything below, taken on archiving
  README.md.orig     his README
  install.sh         his installer
  sl-switch.sh       his /sl implementation
  sl-water-bg.py     his Windows Terminal background driver
  statusline.py      his theme dispatcher
  commands/sl.md     his slash command
  statuslines/*.py   all eleven modules, original names and layout
```

## Why these four are not shipped

They are a complete, working status line framework. This repo already has one.
Running his would replace it, which is a fine outcome if that is what you want
and a bad surprise otherwise.

| File | What running it does |
|---|---|
| `install.sh` | rewrites `statusLine` in `~/.claude/settings.json` to point at `statusline.py`, and overwrites `~/.claude/commands/sl.md`. The Base Theme-switcher goes off the air until a `.bak-*` is restored. |
| `sl-switch.sh` | a second switcher with its own state file, its own height file, and a call into `sl-water-bg.py`. |
| `statusline.py` | his dispatcher, reading the theme name from `~/.claude/statusline-theme`. |
| `commands/sl.md` | replaces this framework's `/sl`. Carries a `__CLAUDE_DIR__` placeholder that `install.sh` substitutes. |

He is not careless about it — `install.sh` backs up everything it overwrites as
`*.bak-<timestamp>` and `settings.json.bak-statusline`. The objection is only
that two frameworks cannot own one `statusLine.command`.

## Why `sl-water-bg.py` is not shipped

It points a Windows Terminal profile at a pre-rendered animated GIF, so the whole
window becomes the scene. The feature works and the script is careful.

It is not shipped because of **where it is called from**: `water.sync_band` and
`vice.sync_background` spawn it from inside a render, roughly once a second, and
it rewrites `settings.json`. Rendering must never write configuration. The
engine's `terminal-background.py` does the same job from theme *activation*, and
that is where any window background for these themes belongs.

Two further details worth recording, both found by reading:

- Its settings discovery globs `/mnt/c/Users/*/AppData/Local/...` and picks the
  newest by mtime — WSL-only, but user-wildcarded, so nothing is hardcoded to
  his machine.
- Profile selection reads `WT_PROFILE_ID`, falls back to `defaultProfile`, then
  to `profiles[0]`. That last fallback can silently modify a profile nobody
  chose.

Credit where it is due: there is **no** hardcoded username, home directory or
Windows Terminal profile GUID anywhere in this bundle. That is unusual and
welcome.

## The eleven modules

| Module | Ships as | Note |
|---|---|---|
| `common.py` | `../shared/common.py` | verbatim |
| `octants.py` | `../shared/octants.py` | verbatim |
| `gifwriter.py` | **replaced by a stub** | a renderer must not write files |
| `water.py` | `../aquarium/water.py` | verbatim |
| `water2.py` | `../aquarium/water2.py` | verbatim; reached via `SL_AQUARIUM_PIXELS=octant` |
| `watergif.py` | `../aquarium/watergif.py` | verbatim; `water.py` imports it for `SUB_LOOP_CS` and `sub_fits` |
| `kyoto.py` | `../kyoto/kyoto.py` | verbatim |
| `kyotogif.py` | `../kyoto/kyotogif.py` | verbatim; **not optional** — `kyoto.py` does `import kyotogif as art` and pulls sixteen art constants out of it |
| `vice.py` | `../vice/vice.py` | verbatim |
| `vicegif.py` | **not shipped** | a pure generator; `vice.py` imports nothing but `common` |
| `rgb.py` | **not shipped** | his rainbow-rule theme; shipped once as `spectrum`, since withdrawn |

Regenerating the background GIFs, if anyone ever wants them, means working in
this directory with his real `gifwriter.py` — deliberately, by hand, and not
from a status line.
