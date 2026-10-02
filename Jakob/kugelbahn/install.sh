#!/usr/bin/env bash
# Installs the kugelbahn statusline theme into the Base Theme-switcher
# framework. The theme goes into themes/, the shared marble sprites it sources
# at runtime go next to core.sh, and the background shader goes into shaders/
# where the framework's terminal-background.py looks for it. Nothing is
# selected: activating the theme is left to /sl, which also applies the
# Windows Terminal look. Override the framework location with SL_HOME.

set -eu

SL_HOME="${SL_HOME:-$HOME/.claude/statusline}"
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
THEME_DIR="$SL_HOME/themes"
SHADER_DIR="$SL_HOME/shaders"
THEME_NAME="kugelbahn"

for required in statusline.sh core.sh switch.sh; do
  if [ ! -f "$SL_HOME/$required" ]; then
    printf 'the Base Theme-switcher is not installed at %s (no %s)\n' "$SL_HOME" "$required" >&2
    printf 'install the Base Theme-switcher first, or set SL_HOME.\n' >&2
    exit 1
  fi
done

if [ ! -d "$THEME_DIR" ]; then
  printf 'no theme directory at %s\n' "$THEME_DIR" >&2
  printf 'install the Base Theme-switcher first, or set SL_HOME.\n' >&2
  exit 1
fi

for shipped in "$THEME_NAME.sh" kugel-sprites.sh "$THEME_NAME.hlsl"; do
  if [ ! -f "$SOURCE_DIR/$shipped" ]; then
    printf 'missing %s next to this script\n' "$shipped" >&2
    printf 'copy the whole kugelbahn folder, not just install.sh.\n' >&2
    exit 1
  fi
done

mkdir -p "$SHADER_DIR"

cp "$SOURCE_DIR/$THEME_NAME.sh" "$THEME_DIR/$THEME_NAME.sh"
printf 'installed %s\n' "$THEME_DIR/$THEME_NAME.sh"

cp "$SOURCE_DIR/kugel-sprites.sh" "$SL_HOME/kugel-sprites.sh"
printf 'installed %s\n' "$SL_HOME/kugel-sprites.sh"

cp "$SOURCE_DIR/$THEME_NAME.hlsl" "$SHADER_DIR/$THEME_NAME.hlsl"
printf 'installed %s\n' "$SHADER_DIR/$THEME_NAME.hlsl"

printf 'now run /sl %s\n' "$THEME_NAME"
