# shared

The Python every theme in this folder imports, plus the adapter layer that makes
Livio's renderers fit the Base Theme-switcher. One copy, here — no theme folder
duplicates any of it, and every `install.sh` copies this directory alongside its
own modules.

Everything here is installed into `~/.claude/statusline/vendor/livio/`, which is
a flat directory shared by all three themes. Installing a second theme overwrites
these five files with identical content.

| File | Whose | What it is |
|---|---|---|
| `common.py` | **Livio's, verbatim** | `Canvas`, `Pixels` (1×2 half-block), `OctantPixels` (2×4), colour and formatting helpers, `git_branch`, `weekly_spend`. Imported by all three themes. |
| `octants.py` | **Livio's, verbatim** | a generated 256-entry glyph table for U+1CD00…U+1CDE5, imported lazily by `OctantPixels._paint`. Needed by `kyoto`, `vice` and `aquarium` in octant mode. |
| `gifwriter.py` | ours | an **inert stub**. See below. |
| `render.py` | ours | the bridge. The whole adaptation lives here. |
| `wrapper.sh` | ours | the bash launcher that all three `themes/*.sh` files source. |

`common.py` and `octants.py` are byte-identical to
`../upstream/statuslines/`. Check with `cmp common.py ../upstream/statuslines/common.py`.

## `gifwriter.py` is a stub

Livio's real `gifwriter.py` is a minimal GIF89a writer. `watergif.py` and
`kyotogif.py` import it at module scope because their `build_all()` generators
write animation frames to disk — but the themes only pull **art constants and
two timing values** out of those modules, never the generators.

Shipping a working image writer next to a renderer that must never touch the
filesystem is a hazard with no upside, so the import is satisfied by a stub
whose only function raises. Anything that tries to produce a file gets a loud
failure instead of a surprise write into AppData.

His original is preserved at `../upstream/statuslines/gifwriter.py` if the
background GIFs ever need regenerating — by hand, deliberately, outside a
render.

## `render.py`

Reads the Claude Code payload on stdin, prints one ready-to-emit row per line.
Patches the imported module objects at runtime rather than editing Livio's
sources, so a refresh from him stays a plain file copy.

Environment it expects, all set by `wrapper.sh`:

| Variable | Meaning |
|---|---|
| `COLUMNS` | the width budget in cells — this engine's `SL_COLUMNS`, not the raw terminal width |
| `SL_USE_COLOR` | `0` to ask for the fallback and strip every escape |
| `SL_LIVIO_THEME` | `water`, `water2`, `kyoto`, `vice` or `rgb` |
| `SL_LIVIO_NOW` | epoch seconds driving every animation |
| `SL_LIVIO_ROWS` | requested panel height |
| `SL_LIVIO_BRANCH` | git branch, already resolved by the host |
| `SL_LIVIO_SPENT` `SL_LIVIO_LIMIT` | gateway figures, blank when unknown |

What it fixes, and why each one matters, is written out in the file's own
docstring and summarised in [`../README.md`](../README.md).

## `wrapper.sh`

Sourced by each `themes/<name>.sh`, which differ only in which renderer they ask
for and how tall a panel they want. It resolves the host data, launches the
bridge once and emits what comes back with `sl_emit_raw` rather than `sl_emit`,
because the bridge has already enforced the budget and clipping thousands of
truecolour escapes per frame in bash costs seconds.

Panel height is clamped to 5…24 rows here and again in the bridge, because a
status line that prints 999 rows scrolls the whole terminal away.
