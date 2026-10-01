#!/usr/bin/env bash
# @name: spectrum
# @description: Three information rows under a slowly drifting rainbow rule
# @order: 43

# Livio's "rgb" renderer, vendored under vendor/livio/ and launched through the
# bridge there. The only one of his themes with no scenery, so it has no height
# knob: the rule plus three rows of session data, and the rows shed their tail
# segments in the bridge rather than wrapping on a narrow terminal.

LIVIO_WRAPPER="$SL_HOME/vendor/livio/wrapper.sh"
[ -r "$LIVIO_WRAPPER" ] && . "$LIVIO_WRAPPER"

sl_render() {
  if ! declare -F livio_render >/dev/null; then
    sl_emit "$(sl_fg256 204)spectrum: missing vendor/livio/wrapper.sh${SL_RESET}"
    return
  fi

  livio_render "rgb" ""
}
