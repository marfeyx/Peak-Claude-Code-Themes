#!/usr/bin/env bash
# @name: aquarium
# @description: A tank whose water level is the context window you have left
# @order: 40

# Livio's "water" renderer, vendored under vendor/livio/ and launched through
# the bridge there. SL_AQUARIUM_ROWS sets the panel height. SL_AQUARIUM_PIXELS
# =octant switches to his water2 renderer, which draws the same aquarium at 2x4
# subpixel resolution and needs a font carrying Unicode 16's octant glyphs; it
# has no graceful degradation, so the half-block version is the default.

LIVIO_WRAPPER="$SL_HOME/vendor/livio/wrapper.sh"
[ -r "$LIVIO_WRAPPER" ] && . "$LIVIO_WRAPPER"

sl_render() {
  local renderer="water"

  if ! declare -F livio_render >/dev/null; then
    sl_emit "$(sl_fg256 204)aquarium: missing vendor/livio/wrapper.sh${SL_RESET}"
    return
  fi

  [ "${SL_AQUARIUM_PIXELS:-}" = "octant" ] && renderer="water2"
  livio_render "$renderer" "${SL_AQUARIUM_ROWS:-11}"
}
