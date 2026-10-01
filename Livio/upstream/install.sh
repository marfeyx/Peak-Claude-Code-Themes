#!/usr/bin/env bash
# Install the Claude Code status line themes into ~/.claude.
#
#   ./install.sh              install into $HOME/.claude
#   CLAUDE_DIR=/x ./install.sh  install somewhere else
#
# Existing files are backed up next to themselves as *.bak-<timestamp> before
# they are overwritten, and settings.json is only touched to point statusLine at
# the dispatcher.
set -eu

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${CLAUDE_DIR:-$HOME/.claude}"
STAMP="$(date +%Y%m%d-%H%M%S)"

command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }

backup_copy() {
    local from="$1" to="$2"
    [ -e "$to" ] && cp -p "$to" "$to.bak-$STAMP"
    cp "$from" "$to"
}

mkdir -p "$DEST/statuslines" "$DEST/commands"

backup_copy "$SRC/statusline.py"   "$DEST/statusline.py"
backup_copy "$SRC/sl-switch.sh"    "$DEST/sl-switch.sh"
backup_copy "$SRC/sl-water-bg.py"  "$DEST/sl-water-bg.py"
chmod +x "$DEST/sl-switch.sh" "$DEST/sl-water-bg.py"

for f in "$SRC"/statuslines/*.py; do
    backup_copy "$f" "$DEST/statuslines/$(basename "$f")"
done

# The slash command has to name an absolute path, so bake this install's in.
[ -e "$DEST/commands/sl.md" ] && cp -p "$DEST/commands/sl.md" "$DEST/commands/sl.md.bak-$STAMP"
sed "s|__CLAUDE_DIR__|$DEST|g" "$SRC/commands/sl.md" > "$DEST/commands/sl.md"

python3 - "$DEST" <<'PY'
import json, os, shutil, sys

dest = sys.argv[1]
path = os.path.join(dest, "settings.json")
data = {}
if os.path.exists(path):
    shutil.copy2(path, path + ".bak-statusline")
    with open(path, encoding="utf-8-sig") as fh:
        data = json.load(fh) or {}

data["statusLine"] = {
    "type": "command",
    "command": "python3 %s/statusline.py" % dest,
    "refreshInterval": 1,
}
with open(path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
print("statusLine -> python3 %s/statusline.py" % dest)
PY

printf '\nInstalled. In Claude Code run:  /sl        (lists the themes)\n'
printf 'Themes:                         water, water2, kyoto, vice, rgb\n'
printf 'Scenery height:                 /sl water 14  (or full, or auto)\n'
