#!/usr/bin/env bash
# Installs the gauges statusline theme into the Base Theme-switcher framework
# and selects it. Override the framework location with SL_HOME.

set -eu

SL_HOME="${SL_HOME:-$HOME/.claude/statusline}"
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
THEME_DIR="$SL_HOME/themes"

if [ ! -d "$THEME_DIR" ]; then
  printf 'no theme directory at %s\n' "$THEME_DIR" >&2
  printf 'install the Base Theme-switcher first, or set SL_HOME.\n' >&2
  exit 1
fi

cp "$SOURCE_DIR/gauges.sh" "$THEME_DIR/gauges.sh"
printf 'installed %s\n' "$THEME_DIR/gauges.sh"

if [ -x "$SL_HOME/switch.sh" ]; then
  "$SL_HOME/switch.sh" set gauges
else
  printf 'gauges\n' > "$SL_HOME/selected"
  printf 'selected gauges\n'
fi

if [ -x "$SL_HOME/check.sh" ]; then
  "$SL_HOME/check.sh" gauges
fi
