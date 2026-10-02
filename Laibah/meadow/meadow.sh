#!/usr/bin/env bash
# @name: meadow
# @description: A cat walking through overgrown grass, on a day-to-night cycle
# @order: 30

# Thin wrapper over Laibah's meadow renderer, vendored under vendor/meadow/.
# The bridge there enforces the width budget, strips escapes under NO_COLOR and
# pins the clock, so every row arrives ready to emit and goes out with
# sl_emit_raw rather than sl_emit — clipping thousands of truecolour escapes per
# frame in bash costs seconds. Height is SL_MEADOW_ROWS; the upstream default of
# 12 is taller than anything else in themes/, and the knob is clamped at both
# ends here and again in the bridge, because a status line that prints 999 rows
# scrolls the whole terminal away.
#
# The panel paints grass and a cat across the bottom rows and nothing above
# them: the sky is a Windows Terminal background image that terminal-background.py
# owns. It moves on a half-hour day cycle cut into six segments, and the bridge
# notices the six band crossings per cycle and hands each one to a detached
# process — six and never eight, because the light/dark flip is read at a
# segment's midpoint rather than on a threshold of its own. Set
# SL_MEADOW_DRIVE_SKY=0 to freeze the sky where it is; the bridge forces that
# anyway whenever the clock is pinned or SL_PREVIEW is on, so no test render can
# move the user's terminal. SL_FAKE_NOW reaches the sky as well as the panel, so
# a pinned render shows the sky that belongs to the moment it is pinned at.

MEADOW_ROWS_DEFAULT=9
MEADOW_ROWS_MINIMUM=4
MEADOW_ROWS_MAXIMUM=16
MEADOW_BRIDGE="$SL_HOME/vendor/meadow/render.py"

meadow_rows() {
  local requested="${SL_MEADOW_ROWS:-$MEADOW_ROWS_DEFAULT}"
  sl_is_number "$requested" || requested="$MEADOW_ROWS_DEFAULT"
  [ "$requested" -lt "$MEADOW_ROWS_MINIMUM" ] && requested="$MEADOW_ROWS_MINIMUM"
  [ "$requested" -gt "$MEADOW_ROWS_MAXIMUM" ] && requested="$MEADOW_ROWS_MAXIMUM"
  MEADOW_ROWS="$requested"
  return 0
}

sl_render() {
  local output pinned=0 line

  if [ ! -f "$MEADOW_BRIDGE" ]; then
    sl_emit "$(sl_fg256 204)meadow: missing vendor/meadow/render.py${SL_RESET}"
    return
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    sl_emit "$(sl_fg256 204)meadow: python3 not found${SL_RESET}"
    return
  fi

  [ -n "${SL_FAKE_NOW:-}${SL_FAKE_TICK:-}" ] && pinned=1

  meadow_rows
  sl_git

  output="$(COLUMNS="$SL_COLUMNS" \
    SL_USE_COLOR="$SL_USE_COLOR" \
    SL_MEADOW_NOW="$SL_NOW" \
    SL_MEADOW_PINNED="$pinned" \
    SL_MEADOW_PREVIEW="${SL_PREVIEW:-0}" \
    SL_MEADOW_ROWS="$MEADOW_ROWS" \
    SL_MEADOW_BRANCH="${SL_GIT_BRANCH:-}" \
    SL_MEADOW_DRIVE_SKY="${SL_MEADOW_DRIVE_SKY:-1}" \
    PYTHONDONTWRITEBYTECODE=1 \
    python3 -B "$MEADOW_BRIDGE" <<< "$SL_PAYLOAD" 2>/dev/null)"

  if [ -z "$output" ]; then
    sl_emit "$(sl_fg256 204)meadow: the renderer produced nothing${SL_RESET}"
    return
  fi

  while IFS= read -r line; do
    sl_emit_raw "$line"
  done <<< "$output"
}
