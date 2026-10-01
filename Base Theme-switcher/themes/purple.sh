#!/usr/bin/env bash
# @name: purple
# @description: The original — animated cool-rainbow rule, purple gutters, four dense lines
# @order: 10

PURPLE_BAR_WIDTH=12
PURPLE_ANIMATION_PERIOD=2
PURPLE_RAMP=(63 69 75 111 147 183 219 213 207 171 135 99)

purple_accent() {
  local -n target="$1"
  local slot="$2" glyph="$3" ramp_length="${#PURPLE_RAMP[@]}" phase=0
  if [ "$PURPLE_ANIMATION_PERIOD" -gt 0 ]; then
    phase=$(( (SL_NOW / PURPLE_ANIMATION_PERIOD) % ramp_length ))
  fi
  if [ "$SL_USE_COLOR" = "1" ]; then
    printf -v target '%s[38;5;%sm%s%s' "$SL_ESC" "${PURPLE_RAMP[$(( (phase + slot) % ramp_length ))]}" "$glyph" "$SL_RESET"
  else
    target="$glyph"
  fi
}

purple_bar() {
  local percent="${1:-0}" index output="" ramp_length="${#PURPLE_RAMP[@]}" phase=0
  local whole="${percent%%.*}"
  sl_is_number "${whole:-}" || whole=0
  sl_bar "$whole" "$PURPLE_BAR_WIDTH" '▰' '▱'
  if [ "$SL_USE_COLOR" != "1" ]; then
    PURPLE_BAR="$SL_BAR"
    return
  fi
  [ "$PURPLE_ANIMATION_PERIOD" -gt 0 ] && phase=$(( (SL_NOW / PURPLE_ANIMATION_PERIOD) % ramp_length ))
  for (( index = 0; index < SL_BAR_WIDTH; index++ )); do
    if [ "$index" -lt "$SL_BAR_FILLED" ]; then
      if [ "$whole" -ge 85 ]; then
        output="$output${PURPLE_WARN}▰"
      else
        output="$output${SL_ESC}[38;5;${PURPLE_RAMP[$(( (phase + index) % ramp_length ))]}m▰"
      fi
    else
      output="$output${PURPLE_EMPTY}▱"
    fi
  done
  PURPLE_BAR="$output$SL_RESET"
}

sl_render() {
  PURPLE_PATH="$(sl_fg256 183)"
  PURPLE_BRANCH="$(sl_bold)$(sl_fg256 141)"
  PURPLE_MUTED="$(sl_fg256 97)"
  PURPLE_FAINT="$(sl_fg256 60)"
  PURPLE_EMPTY="$(sl_fg256 60)"
  PURPLE_DIRTY="$(sl_fg256 215)"
  PURPLE_CLEAN="$(sl_fg256 114)"
  PURPLE_WARN="$(sl_fg256 204)"
  PURPLE_EFFORT="$(sl_bold)$(sl_fg256 141)"

  purple_accent PURPLE_GUTTER_TOP 0 '▌'
  purple_accent PURPLE_GUTTER_MIDDLE 2 '▌'
  purple_accent PURPLE_GUTTER_BOTTOM 4 '▌'
  purple_accent PURPLE_SEPARATOR_1 3 '│'
  purple_accent PURPLE_SEPARATOR_2 5 '│'
  purple_accent PURPLE_SEPARATOR_3 7 '│'
  purple_accent PURPLE_SEPARATOR_4 4 '│'
  purple_accent PURPLE_SEPARATOR_5 6 '│'
  purple_accent PURPLE_SEPARATOR_6 8 '│'

  sl_git
  sl_gateway
  sl_token_burn

  local branch_name="$SL_GIT_BRANCH" branch_marker="" branch_marker_width=0
  if [ -n "$branch_name" ]; then
    if [ "$SL_GIT_AHEAD" -gt 0 ]; then
      branch_marker="$branch_marker ${PURPLE_MUTED}↑${SL_GIT_AHEAD}${SL_RESET}"
      branch_marker_width=$(( branch_marker_width + 2 + ${#SL_GIT_AHEAD} ))
    fi
    if [ "$SL_GIT_BEHIND" -gt 0 ]; then
      branch_marker="$branch_marker ${PURPLE_MUTED}↓${SL_GIT_BEHIND}${SL_RESET}"
      branch_marker_width=$(( branch_marker_width + 2 + ${#SL_GIT_BEHIND} ))
    fi
  fi

  local diffstat_text="" diffstat_width=0
  if [ "${SL_LINES_ADDED:-0}" != "0" ] || [ "${SL_LINES_REMOVED:-0}" != "0" ]; then
    diffstat_text="${PURPLE_CLEAN}+${SL_LINES_ADDED}${SL_RESET}${PURPLE_MUTED}/${SL_RESET}${PURPLE_DIRTY}-${SL_LINES_REMOVED}${SL_RESET}"
    diffstat_width=$(( 3 + ${#SL_LINES_ADDED} + ${#SL_LINES_REMOVED} ))
  fi

  local measured
  purple_measure_line_one() {
    sl_width "$1"
    measured=$(( 2 + SL_W ))
    if [ -n "$branch_name" ]; then
      sl_width "$branch_name"
      measured=$(( measured + 3 + SL_W + branch_marker_width ))
    fi
    [ -n "$diffstat_text" ] && [ "$2" = "1" ] && measured=$(( measured + 3 + diffstat_width ))
  }

  sl_path_tail 3; local variant_three="$SL_PATH_TAIL"
  sl_path_tail 2; local variant_two="$SL_PATH_TAIL"
  sl_path_tail 1; local variant_one="$SL_PATH_TAIL"

  local path_display="$variant_one" fit_diffstat=0 candidate_variant candidate_diffstat
  for candidate_variant in "$SL_PATH" "$variant_three" "$variant_two" "$variant_one"; do
    for candidate_diffstat in 1 0; do
      purple_measure_line_one "$candidate_variant" "$candidate_diffstat"
      if [ "$measured" -le "$SL_COLUMNS" ]; then
        path_display="$candidate_variant"
        fit_diffstat="$candidate_diffstat"
        break 2
      fi
    done
  done
  [ "$fit_diffstat" = "1" ] || diffstat_text=""

  sl_trunc "$path_display" $(( SL_COLUMNS - 2 ))
  path_display="$SL_TRUNC"

  if [ -n "$branch_name" ]; then
    purple_measure_line_one "$path_display" "$fit_diffstat"
    local overflow=$(( measured - SL_COLUMNS ))
    if [ "$overflow" -gt 0 ]; then
      sl_width "$branch_name"
      local allowed=$(( SL_W - overflow ))
      if [ "$allowed" -lt 2 ]; then
        branch_name=""
        branch_marker=""
      else
        sl_trunc "$branch_name" "$allowed"
        branch_name="$SL_TRUNC"
      fi
    fi
  fi

  local line_one="${PURPLE_GUTTER_TOP} ${PURPLE_PATH}${path_display}${SL_RESET}"
  [ -n "$branch_name" ] && line_one="$line_one ${PURPLE_SEPARATOR_1} ${PURPLE_BRANCH}${branch_name}${SL_RESET}${branch_marker}"
  [ -n "$diffstat_text" ] && line_one="$line_one ${PURPLE_SEPARATOR_2} ${diffstat_text}"

  local line_two="${PURPLE_GUTTER_MIDDLE} " line_two_width=2
  purple_append_two() {
    local candidate_width=$(( line_two_width + $1 ))
    [ "$candidate_width" -le "$SL_COLUMNS" ] || return 0
    line_two="$line_two$2"
    line_two_width="$candidate_width"
  }

  if [ -n "$SL_BUDGET_SPENT" ] && [ -n "$SL_BUDGET_LIMIT" ]; then
    purple_bar "${SL_BUDGET_PERCENT:-0}"
    purple_append_two $(( PURPLE_BAR_WIDTH + 2 )) "${PURPLE_BAR}  "
    purple_append_two "${#SL_BUDGET_SPENT}" "${PURPLE_PATH}${SL_BUDGET_SPENT}${SL_RESET}"
    purple_append_two $(( 3 + ${#SL_BUDGET_LIMIT} )) " ${PURPLE_FAINT}/${SL_RESET} ${PURPLE_MUTED}${SL_BUDGET_LIMIT}${SL_RESET}"
    [ -n "$SL_BUDGET_PERCENT" ] && purple_append_two $(( 4 + ${#SL_BUDGET_PERCENT} )) " ${PURPLE_FAINT}·${SL_RESET} ${PURPLE_MUTED}${SL_BUDGET_PERCENT}%${SL_RESET}"
    [ -n "$SL_BUDGET_PERIOD" ] && purple_append_two $(( 1 + ${#SL_BUDGET_PERIOD} )) " ${PURPLE_FAINT}${SL_BUDGET_PERIOD}${SL_RESET}"
  elif [ -n "$SL_GATEWAY_RAW" ] && [[ "$SL_GATEWAY_RAW" == *[0-9]* ]]; then
    local gateway_fallback="${SL_GATEWAY_RAW%%$'\n'*}" gateway_room=$(( SL_COLUMNS - line_two_width ))
    [ "${#gateway_fallback}" -gt "$gateway_room" ] && gateway_fallback="${gateway_fallback:0:gateway_room}"
    purple_append_two "${#gateway_fallback}" "${PURPLE_MUTED}${gateway_fallback}${SL_RESET}"
  else
    purple_append_two 15 "${PURPLE_FAINT}gateway offline${SL_RESET}"
  fi

  if [ -n "$SL_COST_TEXT" ]; then
    if [ "$line_two_width" -le 2 ]; then
      purple_append_two "${#SL_COST_TEXT}" "${PURPLE_MUTED}${SL_COST_TEXT}${SL_RESET}"
    else
      purple_append_two $(( 3 + ${#SL_COST_TEXT} )) " ${PURPLE_SEPARATOR_4} ${PURPLE_MUTED}${SL_COST_TEXT}${SL_RESET}"
    fi
  fi

  if [ -n "$SL_TOKENS_BURNED_TEXT" ]; then
    local burned_label="tokens wasted: ${SL_TOKENS_BURNED_TEXT}"
    purple_append_two $(( 3 + ${#burned_label} )) " ${PURPLE_SEPARATOR_5} ${PURPLE_MUTED}${burned_label}${SL_RESET}"
  fi

  local line_three="" line_three_width=0
  purple_append_three() {
    local candidate_width=$(( line_three_width + $1 ))
    [ "$candidate_width" -le "$SL_COLUMNS" ] || return 0
    line_three="$line_three$2"
    line_three_width="$candidate_width"
  }

  if [ -n "$SL_EFFORT" ]; then
    local effort_head="$SL_EFFORT effort"
    [ "$SL_ULTRACODE" = "1" ] && effort_head="ultracode · $SL_EFFORT effort"
    sl_trunc "$effort_head" $(( SL_COLUMNS - 4 ))
    effort_head="$SL_TRUNC"
    sl_width "$effort_head"
    line_three="${PURPLE_GUTTER_BOTTOM} ${PURPLE_EFFORT}✦ ${effort_head}${SL_RESET}"
    line_three_width=$(( 4 + SL_W ))
  fi

  local context_label="" context_text=""
  if sl_is_number "${SL_CONTEXT_PERCENT:-}"; then
    context_label="context ${SL_CONTEXT_PERCENT}%"
    if [ "${SL_CONTEXT_TOKENS:-0}" -gt 0 ]; then
      sl_abbrev "$SL_CONTEXT_TOKENS"
      context_label="${context_label} (${SL_ABBREV})"
    fi
    if [ "$SL_CONTEXT_PERCENT" -ge 85 ]; then
      context_text="${PURPLE_WARN}${context_label}${SL_RESET}"
    else
      context_text="${PURPLE_MUTED}${context_label}${SL_RESET}"
    fi
  fi

  if [ -n "$context_text" ]; then
    if [ -z "$line_three" ]; then
      line_three="${PURPLE_GUTTER_BOTTOM} ${context_text}"
      line_three_width=$(( 2 + ${#context_label} ))
    else
      purple_append_three $(( 3 + ${#context_label} )) " ${PURPLE_SEPARATOR_6} ${context_text}"
    fi
  fi

  if [ -n "$SL_MODEL_NAME" ]; then
    if [ -z "$line_three" ]; then
      sl_trunc "$SL_MODEL_NAME" $(( SL_COLUMNS - 2 ))
      sl_width "$SL_TRUNC"
      line_three="${PURPLE_GUTTER_BOTTOM} ${PURPLE_MUTED}${SL_TRUNC}${SL_RESET}"
      line_three_width=$(( 2 + SL_W ))
    else
      sl_width "$SL_MODEL_NAME"
      if [ $(( line_three_width + 3 + SL_W )) -le "$SL_COLUMNS" ]; then
        purple_append_three $(( 3 + SL_W )) " ${PURPLE_SEPARATOR_3} ${PURPLE_MUTED}${SL_MODEL_NAME}${SL_RESET}"
      else
        sl_width "$SL_MODEL_SHORT"
        purple_append_three $(( 3 + SL_W )) " ${PURPLE_SEPARATOR_3} ${PURPLE_MUTED}${SL_MODEL_SHORT}${SL_RESET}"
      fi
    fi
  fi

  if [ "$SL_USE_COLOR" = "1" ]; then
    sl_rule "$SL_COLUMNS" '─' 90
    sl_emit "$SL_RULE"
  fi
  sl_emit "$line_one"
  sl_emit "$line_two"
  [ -n "$line_three" ] && sl_emit "$line_three"
}
