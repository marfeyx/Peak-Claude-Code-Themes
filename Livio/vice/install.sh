#!/usr/bin/env bash
# Installs the vice statusline theme into the Base Theme-switcher framework
# and selects it. The renderer is Python, so it goes into the framework's
# vendor/livio/ tree alongside the shared modules from ../shared; only the
# bash wrapper lands in themes/. Override the framework location with SL_HOME.

set -eu

SL_HOME="${SL_HOME:-$HOME/.claude/statusline}"
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$(cd -- "$SOURCE_DIR/.." && pwd)/shared"
THEME_DIR="$SL_HOME/themes"
VENDOR_DIR="$SL_HOME/vendor/livio"
THEME_NAME="vice"
THEME_MODULES="vice.py"

if [ ! -d "$THEME_DIR" ]; then
  printf 'no theme directory at %s\n' "$THEME_DIR" >&2
  printf 'install the Base Theme-switcher first, or set SL_HOME.\n' >&2
  exit 1
fi

if [ ! -d "$SHARED_DIR" ]; then
  printf 'no shared directory at %s\n' "$SHARED_DIR" >&2
  printf 'copy the whole Livio folder, not just this theme.\n' >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  printf 'python3 is not on PATH; this theme is a Python renderer.\n' >&2
  exit 1
fi

mkdir -p "$VENDOR_DIR"

for module in common.py octants.py gifwriter.py render.py wrapper.sh; do
  cp "$SHARED_DIR/$module" "$VENDOR_DIR/$module"
done

for module in $THEME_MODULES; do
  cp "$SOURCE_DIR/$module" "$VENDOR_DIR/$module"
done

cp "$SOURCE_DIR/$THEME_NAME.sh" "$THEME_DIR/$THEME_NAME.sh"
printf 'installed %s\n' "$THEME_DIR/$THEME_NAME.sh"
printf 'installed renderer into %s\n' "$VENDOR_DIR"

if [ -x "$SL_HOME/switch.sh" ]; then
  "$SL_HOME/switch.sh" set "$THEME_NAME"
else
  printf '%s\n' "$THEME_NAME" > "$SL_HOME/selected"
  printf 'selected %s\n' "$THEME_NAME"
fi

if [ -x "$SL_HOME/check.sh" ]; then
  "$SL_HOME/check.sh" "$THEME_NAME"
fi
