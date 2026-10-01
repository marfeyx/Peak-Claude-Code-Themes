#!/usr/bin/env bash
# @name: kyoto
# @description: A calm Kyoto valley: sakura, a waterfall and a slow river
# @order: 41

# Livio's "kyoto" renderer, vendored under vendor/livio/ and launched through
# the bridge there. SL_KYOTO_ROWS sets the panel height; SL_KYOTO_PIXELS=half
# drops the scenery from octant to half-block resolution when the font has no
# Unicode 16 octant glyphs and the valley comes out as empty boxes.

LIVIO_WRAPPER="$SL_HOME/vendor/livio/wrapper.sh"
[ -r "$LIVIO_WRAPPER" ] && . "$LIVIO_WRAPPER"

sl_render() {
  if ! declare -F livio_render >/dev/null; then
    sl_emit "$(sl_fg256 204)kyoto: missing vendor/livio/wrapper.sh${SL_RESET}"
    return
  fi

  livio_render "kyoto" "${SL_KYOTO_ROWS:-12}"
}
