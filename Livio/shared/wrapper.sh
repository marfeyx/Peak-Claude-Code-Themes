#!/usr/bin/env bash
# Shared launcher for the three themes bridged from Livio's bundle.
#
# Sourced by themes/aquarium.sh, themes/kyoto.sh and
# themes/vice.sh, which differ only in which renderer they ask for and how tall
# a panel they want. Everything that makes his Python safe and width-correct
# lives in vendor/livio/render.py; this file only resolves the host data the
# bridge needs, launches it once and emits what comes back.
#
# Rows go out with sl_emit_raw rather than sl_emit because the bridge has
# already enforced the budget: clipping thousands of truecolour escapes per
# frame in bash costs seconds. The panel height is clamped here and again in
# the bridge, because a status line that prints 999 rows scrolls the whole
# terminal away.

LIVIO_BRIDGE="$SL_HOME/vendor/livio/render.py"
LIVIO_ROWS_DEFAULT=12
LIVIO_ROWS_MINIMUM=5
LIVIO_ROWS_MAXIMUM=24

livio_rows() {
  local requested="${1:-}"
  sl_is_number "$requested" || requested="$LIVIO_ROWS_DEFAULT"
  [ "$requested" -lt "$LIVIO_ROWS_MINIMUM" ] && requested="$LIVIO_ROWS_MINIMUM"
  [ "$requested" -gt "$LIVIO_ROWS_MAXIMUM" ] && requested="$LIVIO_ROWS_MAXIMUM"
  LIVIO_ROWS="$requested"
  return 0
}

livio_render() {
  local renderer="$1" output line spent limit label
  label="${SL_THEME:-$renderer}"

  if [ ! -f "$LIVIO_BRIDGE" ]; then
    sl_emit "$(sl_fg256 204)${label}: missing vendor/livio/render.py${SL_RESET}"
    return
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    sl_emit "$(sl_fg256 204)${label}: python3 not found${SL_RESET}"
    return
  fi

  livio_rows "${2:-}"
  sl_git
  sl_gateway
  spent="${SL_BUDGET_SPENT:-}"
  limit="${SL_BUDGET_LIMIT:-}"
  spent="${spent//[\$,]/}"
  limit="${limit//[\$,]/}"

  output="$(COLUMNS="$SL_COLUMNS" \
    SL_USE_COLOR="$SL_USE_COLOR" \
    SL_LIVIO_THEME="$renderer" \
    SL_LIVIO_NOW="$SL_NOW" \
    SL_LIVIO_ROWS="$LIVIO_ROWS" \
    SL_LIVIO_BRANCH="${SL_GIT_BRANCH:-}" \
    SL_LIVIO_SPENT="$spent" \
    SL_LIVIO_LIMIT="$limit" \
    PYTHONDONTWRITEBYTECODE=1 \
    python3 -B "$LIVIO_BRIDGE" <<< "$SL_PAYLOAD" 2>/dev/null)"

  if [ -z "$output" ]; then
    sl_emit "$(sl_fg256 204)${label}: the renderer produced nothing${SL_RESET}"
    return
  fi

  while IFS= read -r line; do
    sl_emit_raw "$line"
  done <<< "$output"
}
