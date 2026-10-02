#!/usr/bin/env bash
# Installs the meadow statusline theme into the Base Theme-switcher framework.
# The renderer is Python, so its modules go into the framework's vendor/meadow/
# tree, the sky builder sits beside switch.sh where terminal-background.py looks
# for it, and the two Claude Code palettes go under assets/. Only the bash
# wrapper lands in themes/. Override the framework location with SL_HOME.
#
# Nothing is selected and nothing is built: switching to the theme is what
# applies the terminal look and starts the sky render, so that stays with /sl.

set -eu

SL_HOME="${SL_HOME:-$HOME/.claude/statusline}"
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
THEME_DIR="$SL_HOME/themes"
VENDOR_DIR="$SL_HOME/vendor/meadow"
ASSET_DIR="$SL_HOME/assets"
THEME_NAME="meadow"
MODULES="agentcount.py common.py daylight.py gifwriter.py meadow.py meadowsky.py render.py skyband.py skydriver.py"
PALETTES="meadow meadow-night"

if [ ! -f "$SL_HOME/statusline.sh" ] || [ ! -d "$THEME_DIR" ]; then
  printf 'the Base Theme-switcher is not installed at %s\n' "$SL_HOME" >&2
  printf 'install it first, or point SL_HOME at it.\n' >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  printf 'python3 is not on PATH; this theme is a Python renderer.\n' >&2
  exit 1
fi

for module in $MODULES; do
  if [ ! -f "$SOURCE_DIR/vendor/$module" ]; then
    printf 'missing vendor/%s next to this script; copy the whole meadow folder.\n' "$module" >&2
    exit 1
  fi
done

mkdir -p "$VENDOR_DIR"
for module in $MODULES; do
  cp "$SOURCE_DIR/vendor/$module" "$VENDOR_DIR/$module"
done
printf 'installed renderer into %s\n' "$VENDOR_DIR"

for palette in $PALETTES; do
  mkdir -p "$ASSET_DIR/$palette"
  cp "$SOURCE_DIR/assets/$palette/$palette.json" "$ASSET_DIR/$palette/$palette.json"
done
printf 'installed palettes into %s\n' "$ASSET_DIR"

cp "$SOURCE_DIR/meadow-sky.py" "$SL_HOME/meadow-sky.py"
printf 'installed %s\n' "$SL_HOME/meadow-sky.py"

cp "$SOURCE_DIR/$THEME_NAME.sh" "$THEME_DIR/$THEME_NAME.sh"
printf 'installed %s\n' "$THEME_DIR/$THEME_NAME.sh"

if ! grep -q '"meadow"' "$SL_HOME/terminal-background.py" 2>/dev/null; then
  printf 'note: %s has no meadow look, so the panel will render without its sky.\n' \
    "$SL_HOME/terminal-background.py"
  printf 'update the Base Theme-switcher to get the sky background.\n'
fi

printf 'now run /sl %s\n' "$THEME_NAME"
