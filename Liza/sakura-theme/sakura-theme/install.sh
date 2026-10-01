#!/usr/bin/env bash
# Installs the sakura theme: Claude Code palette, the /sl command, the wallpaper
# generator, and the wallpaper itself -- then applies the whole thing.
#
# Safe to re-run. Anything it overwrites in Windows Terminal's or Claude Code's
# settings.json is backed up to ~/.claude/backups/ first by theme.sh.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
claude="$HOME/.claude"

say() { printf '  %s\n' "$*"; }

command -v python3 >/dev/null || {
  echo "python3 is required (the generator and the switcher are both python)." >&2
  exit 1
}

echo "installing the sakura theme"

mkdir -p "$claude/themes" "$claude/commands" "$claude/art"

install -m 0644 "$here/sakura.json"    "$claude/themes/sakura.json"
install -m 0644 "$here/sl.md"          "$claude/commands/sl.md"
install -m 0644 "$here/sakura_gen.py"  "$claude/art/sakura_gen.py"
install -m 0755 "$here/theme.sh"       "$claude/theme.sh"
say "claude code   -> $claude/themes/sakura.json"
say "slash command -> $claude/commands/sl.md"
say "generator     -> $claude/art/sakura_gen.py"
say "switcher      -> $claude/theme.sh"

# theme.sh already knows how to find Windows Terminal; reuse that rather than
# duplicating the search here.
if localstate="$("$claude/theme.sh" --localstate)" && [ -n "$localstate" ]; then
  install -m 0644 "$here/sakura-blossom.gif" "$localstate/sakura-blossom.gif"
  say "wallpaper     -> $localstate/sakura-blossom.gif"
else
  echo
  echo "! Windows Terminal's settings.json was not found." >&2
  echo "  The Claude Code palette will still install. For the wallpaper and the" >&2
  echo "  terminal colours, set WT_LOCALSTATE to the folder holding that file" >&2
  echo "  and re-run this script:" >&2
  echo "      WT_LOCALSTATE=/mnt/c/Users/<you>/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState ./install.sh" >&2
  echo >&2
fi

echo
"$claude/theme.sh" sakura
