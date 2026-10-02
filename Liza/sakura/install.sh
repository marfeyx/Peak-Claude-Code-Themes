#!/usr/bin/env bash
# Installs the sakura statusline theme into the Base Theme-switcher framework:
# the theme file into themes/, and Liza's Claude Code palette and wallpaper into
# assets/sakura/, where terminal-background.py looks for them on activation.
# It does not select the theme. Override the framework location with SL_HOME.

set -eu

SL_HOME="${SL_HOME:-$HOME/.claude/statusline}"
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
THEME_NAME="sakura"
THEME_DIR="$SL_HOME/themes"
ASSET_DIR="$SL_HOME/assets/$THEME_NAME"
ASSET_FILES="sakura.json sakura-blossom.gif"

if [ ! -f "$SL_HOME/statusline.sh" ] || [ ! -f "$SL_HOME/core.sh" ] || [ ! -d "$THEME_DIR" ]; then
  printf 'the Base Theme-switcher is not installed at %s\n' "$SL_HOME" >&2
  printf 'install it first (Base Theme-switcher/install.sh), or set SL_HOME.\n' >&2
  exit 1
fi

for asset in $ASSET_FILES; do
  if [ ! -f "$SOURCE_DIR/assets/$asset" ]; then
    printf 'missing %s\n' "$SOURCE_DIR/assets/$asset" >&2
    printf 'copy the whole sakura folder, not just this script.\n' >&2
    exit 1
  fi
done

cp "$SOURCE_DIR/$THEME_NAME.sh" "$THEME_DIR/$THEME_NAME.sh"
printf 'installed %s\n' "$THEME_DIR/$THEME_NAME.sh"

mkdir -p "$ASSET_DIR"
for asset in $ASSET_FILES; do
  cp "$SOURCE_DIR/assets/$asset" "$ASSET_DIR/$asset"
  printf 'installed %s\n' "$ASSET_DIR/$asset"
done

if [ ! -f "$SL_HOME/terminal-background.py" ] || ! grep -q '"sakura"' "$SL_HOME/terminal-background.py"; then
  printf 'note: %s has no sakura look,\n' "$SL_HOME/terminal-background.py"
  printf '      so the status line will work but the wallpaper and palette will not be applied.\n'
fi

printf 'now run /sl %s\n' "$THEME_NAME"
