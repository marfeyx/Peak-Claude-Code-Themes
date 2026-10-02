#!/usr/bin/env bash
# Installs the christmas statusline theme into the Base Theme-switcher framework:
# the theme into themes/ and its Windows Terminal snow shader into shaders/.
# It does not select the theme and does not touch Windows Terminal; the switcher
# applies the shader when the theme is activated. Override the framework
# location with SL_HOME.

set -eu

SL_HOME="${SL_HOME:-$HOME/.claude/statusline}"
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
THEME_DIR="$SL_HOME/themes"
SHADER_DIR="$SL_HOME/shaders"
THEME_NAME="christmas"

for required in statusline.sh core.sh switch.sh; do
  if [ ! -f "$SL_HOME/$required" ]; then
    printf 'the Base Theme-switcher is not installed at %s (no %s)\n' "$SL_HOME" "$required" >&2
    printf 'install it first with its own install.sh, or set SL_HOME.\n' >&2
    exit 1
  fi
done

if [ ! -d "$THEME_DIR" ]; then
  printf 'no theme directory at %s\n' "$THEME_DIR" >&2
  printf 'the Base Theme-switcher install looks incomplete; re-run its install.sh.\n' >&2
  exit 1
fi

for asset in "$THEME_NAME.sh" "$THEME_NAME.hlsl"; do
  if [ ! -f "$SOURCE_DIR/$asset" ]; then
    printf 'missing %s next to this script\n' "$asset" >&2
    printf 'copy the whole %s folder, not just install.sh.\n' "$THEME_NAME" >&2
    exit 1
  fi
done

mkdir -p "$SHADER_DIR"

cp "$SOURCE_DIR/$THEME_NAME.sh" "$THEME_DIR/$THEME_NAME.sh"
printf 'installed %s\n' "$THEME_DIR/$THEME_NAME.sh"

cp "$SOURCE_DIR/$THEME_NAME.hlsl" "$SHADER_DIR/$THEME_NAME.hlsl"
printf 'installed %s\n' "$SHADER_DIR/$THEME_NAME.hlsl"

printf 'now run /sl %s\n' "$THEME_NAME"
