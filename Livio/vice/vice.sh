#!/usr/bin/env bash
# @name: vice
# @description: A Vice City panorama on a day-night cycle, context as a wanted level
# @order: 42

# Livio's "vice" renderer, vendored under vendor/livio/ and launched through
# the bridge there. SL_VICE_ROWS sets the panel height; SL_VICE_PIXELS=half
# drops the panorama from octant to half-block resolution when the font has no
# Unicode 16 octant glyphs. SL_VICE_HOUR pins the time of day for a look at
# dusk without waiting for it.

LIVIO_WRAPPER="$SL_HOME/vendor/livio/wrapper.sh"
[ -r "$LIVIO_WRAPPER" ] && . "$LIVIO_WRAPPER"

sl_render() {
  if ! declare -F livio_render >/dev/null; then
    sl_emit "$(sl_fg256 204)vice: missing vendor/livio/wrapper.sh${SL_RESET}"
    return
  fi

  livio_render "vice" "${SL_VICE_ROWS:-12}"
}
