#!/usr/bin/env bash
# Entry point for the Claude Code statusline. Reads the payload on stdin,
# loads the shared data layer, resolves which theme is selected, and hands
# rendering to that theme's sl_render function.
#
# Theme resolution, first match wins:
#   1. --theme NAME on the command line (used by switch.sh for previews)
#   2. $CLAUDE_STATUSLINE_THEME
#   3. <project>/.claude/statusline-theme
#   4. ~/.claude/statusline/selected
#   5. the default theme
#
# Switch themes with /sl or /statusline-theme in Claude Code, or switch.sh from a shell.

set -u

SL_HOME="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SL_THEME_DIR="$SL_HOME/themes"
SL_SELECTED_FILE="$SL_HOME/selected"
SL_DEFAULT_THEME="purple"

SL_REQUESTED_THEME=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --theme) SL_REQUESTED_THEME="${2:-}"; shift 2 ;;
    --theme=*) SL_REQUESTED_THEME="${1#--theme=}"; shift ;;
    *) shift ;;
  esac
done

SL_PAYLOAD="$(cat)"

# shellcheck source=core.sh
. "$SL_HOME/core.sh"

sl_parse_payload "$SL_PAYLOAD"

sl_valid_theme_name() {
  case "${1:-}" in
    ''|*[!a-zA-Z0-9_-]*) return 1 ;;
    *) return 0 ;;
  esac
}

sl_resolve_theme() {
  local candidate

  if sl_valid_theme_name "$SL_REQUESTED_THEME"; then
    SL_THEME="$SL_REQUESTED_THEME"
    return
  fi

  if sl_valid_theme_name "${CLAUDE_STATUSLINE_THEME:-}"; then
    SL_THEME="$CLAUDE_STATUSLINE_THEME"
    return
  fi

  for candidate in "$SL_CWD/.claude/statusline-theme" "${SL_PROJECT_DIR:-}/.claude/statusline-theme"; do
    [ -f "$candidate" ] || continue
    IFS= read -r SL_THEME < "$candidate" 2>/dev/null || continue
    SL_THEME="${SL_THEME//[[:space:]]/}"
    sl_valid_theme_name "$SL_THEME" && return
  done

  if [ -f "$SL_SELECTED_FILE" ]; then
    IFS= read -r SL_THEME < "$SL_SELECTED_FILE" 2>/dev/null || SL_THEME=""
    SL_THEME="${SL_THEME//[[:space:]]/}"
    sl_valid_theme_name "$SL_THEME" && return
  fi

  SL_THEME="$SL_DEFAULT_THEME"
}

sl_resolve_theme

SL_THEME_FILE="$SL_THEME_DIR/$SL_THEME.sh"
SL_THEME_MISSING=""
if [ ! -f "$SL_THEME_FILE" ]; then
  SL_THEME_MISSING="$SL_THEME"
  SL_THEME="$SL_DEFAULT_THEME"
  SL_THEME_FILE="$SL_THEME_DIR/$SL_THEME.sh"
fi

if [ -f "$SL_THEME_FILE" ]; then
  # shellcheck source=/dev/null
  . "$SL_THEME_FILE"
fi

if ! declare -F sl_render >/dev/null 2>&1; then
  sl_render() {
    sl_git
    sl_path_fit $(( SL_COLUMNS - 2 ))
    sl_emit "$SL_PATH_FIT${SL_GIT_BRANCH:+  $SL_GIT_BRANCH}"
  }
fi

if [ -n "$SL_THEME_MISSING" ]; then
  sl_emit "$(sl_fg256 204)no such theme: ${SL_THEME_MISSING} — using ${SL_THEME}${SL_RESET}"
fi

sl_render
sl_flush
