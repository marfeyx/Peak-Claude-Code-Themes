#!/usr/bin/env bash
# Instrument panel for the Claude Code statusline: one labelled meter per line,
# every bar starting and ending in the same column, closed by a row of raw
# totals that shares the same grid.
#
# @name: gauges
# @description: Aligned meter stack with sub-cell bars and a raw totals row
# @order: 70

GAUGES_LABEL_WIDTH=7
GAUGES_PERCENT_WIDTH=4
GAUGES_BAR_MINIMUM=8
GAUGES_BAR_MAXIMUM=28
GAUGES_DETAIL_RESERVE=20
GAUGES_DETAIL_MINIMUM=6
GAUGES_BRANCH_MAXIMUM=26
GAUGES_PATH_MINIMUM=20
GAUGES_PARTIAL_BLOCKS=('' '▏' '▎' '▍' '▌' '▋' '▊' '▉')

gauges_palette() {
  GAUGES_FRAME="$(sl_fg256 240)"
  GAUGES_KEY="$(sl_fg256 244)"
  GAUGES_LABEL="$(sl_fg256 246)"
  GAUGES_VALUE="$(sl_fg256 252)"
  GAUGES_MUTED="$(sl_fg256 247)"
  GAUGES_TROUGH="$(sl_fg256 238)"
  GAUGES_ADDED="$(sl_fg256 108)"
  GAUGES_REMOVED="$(sl_fg256 167)"
  GAUGES_BRANCH="$(sl_bold)$(sl_fg256 252)"
  GAUGES_LEVELS=("$(sl_fg256 108)" "$(sl_fg256 179)" "$(sl_fg256 208)" "$(sl_fg256 203)")
}

gauges_integer() {
  local value="${1:-0}"
  value="${value%%.*}"
  sl_is_number "${value:-}" || value=0
  GAUGES_INTEGER=$(( 10#$value ))
}

gauges_money_micro() {
  local text="${1:-}"
  text="${text//,/}"
  text="${text//\$/}"
  local whole="${text%%.*}"
  local fraction="00"
  case "$text" in
    *.*) fraction="${text#*.}00" ;;
  esac
  fraction="${fraction:0:2}"
  GAUGES_MICRO=-1
  sl_is_number "${whole:-}" || return 0
  sl_is_number "$fraction" || fraction="00"
  GAUGES_MICRO=$(( 10#$whole * 1000000 + 10#$fraction * 10000 ))
}

gauges_permille_of_percent() {
  local text="${1:-}"
  local whole="${text%%.*}"
  local fraction="0"
  case "$text" in
    *.*) fraction="${text#*.}" ;;
  esac
  fraction="${fraction:0:1}"
  GAUGES_PERMILLE=-1
  sl_is_number "${whole:-}" || return 0
  sl_is_number "$fraction" || fraction=0
  GAUGES_PERMILLE=$(( 10#$whole * 10 + 10#$fraction ))
}

gauges_level() {
  local permille="$1"
  if [ "$permille" -ge 900 ]; then
    GAUGES_LEVEL="${GAUGES_LEVELS[3]}"
  elif [ "$permille" -ge 750 ]; then
    GAUGES_LEVEL="${GAUGES_LEVELS[2]}"
  elif [ "$permille" -ge 500 ]; then
    GAUGES_LEVEL="${GAUGES_LEVELS[1]}"
  else
    GAUGES_LEVEL="${GAUGES_LEVELS[0]}"
  fi
}

gauges_meter() {
  local permille="$1"
  local width="$2"
  local capacity=$(( width * 8 ))
  local eighths=$(( permille * capacity / 1000 ))
  [ "$eighths" -gt "$capacity" ] && eighths="$capacity"
  [ "$eighths" -lt 0 ] && eighths=0
  [ "$eighths" -eq 0 ] && [ "$permille" -gt 0 ] && eighths=1
  local full=$(( eighths / 8 ))
  local part=$(( eighths % 8 ))
  local drawn="$full"
  local body=""
  local trough=""
  local index
  for (( index = 0; index < full; index++ )); do
    body="$body█"
  done
  if [ "$part" -gt 0 ] && [ "$full" -lt "$width" ]; then
    body="$body${GAUGES_PARTIAL_BLOCKS[part]}"
    drawn=$(( drawn + 1 ))
  fi
  for (( index = drawn; index < width; index++ )); do
    trough="$trough░"
  done
  gauges_level "$permille"
  GAUGES_METER="${GAUGES_LEVEL}${body}${GAUGES_TROUGH}${trough}${SL_RESET}"
}

gauges_pick() {
  local candidate
  local shortest=""
  GAUGES_PICK=""
  for candidate in "$@"; do
    [ -n "$candidate" ] || continue
    shortest="$candidate"
    sl_width "$candidate"
    if [ "$SL_W" -le "$GAUGES_DETAIL_WIDTH" ]; then
      GAUGES_PICK="$candidate"
      return 0
    fi
  done
  [ -n "$shortest" ] || return 0
  sl_trunc "$shortest" "$GAUGES_DETAIL_WIDTH"
  GAUGES_PICK="$SL_TRUNC"
}

gauges_row() {
  local label="$1"
  local permille="$2"
  shift 2
  [ $(( GAUGES_LABEL_WIDTH + 2 + GAUGES_PERCENT_WIDTH )) -le "$SL_COLUMNS" ] || return 0
  local percent=$(( (permille + 5) / 10 ))
  [ "$percent" -gt 999 ] && percent=999
  local heading
  printf -v heading '%-*s' "$GAUGES_LABEL_WIDTH" "$label"
  local percent_text
  printf -v percent_text '%*d%%' $(( GAUGES_PERCENT_WIDTH - 1 )) "$percent"
  gauges_level "$permille"
  local row="${GAUGES_LABEL}${heading}${SL_RESET}"
  if [ "$GAUGES_BAR_WIDTH" -gt 0 ]; then
    gauges_meter "$permille" "$GAUGES_BAR_WIDTH"
    row="$row  ${GAUGES_METER}"
  fi
  row="$row  ${GAUGES_LEVEL}${percent_text}${SL_RESET}"
  gauges_pick "$@"
  [ -n "$GAUGES_PICK" ] && row="$row  ${GAUGES_MUTED}${GAUGES_PICK}${SL_RESET}"
  sl_emit "$row"
}

gauges_note() {
  local label="$1"
  local text="$2"
  local room=$(( SL_COLUMNS - GAUGES_LABEL_WIDTH - 2 ))
  [ -n "$text" ] || return 0
  [ "$room" -ge "$GAUGES_DETAIL_MINIMUM" ] || return 0
  sl_trunc "$text" "$room"
  [ -n "$SL_TRUNC" ] || return 0
  local heading
  printf -v heading '%-*s' "$GAUGES_LABEL_WIDTH" "$label"
  sl_emit "${GAUGES_LABEL}${heading}${SL_RESET}  ${GAUGES_MUTED}${SL_TRUNC}${SL_RESET}"
}

gauges_add() {
  local width="$1"
  local text="$2"
  [ "$GAUGES_ROW_IS_FULL" = "0" ] || return 0
  if [ $(( GAUGES_ROW_WIDTH + width )) -gt "$SL_COLUMNS" ]; then
    GAUGES_ROW_IS_FULL=1
    return 0
  fi
  GAUGES_ROW="$GAUGES_ROW$text"
  GAUGES_ROW_WIDTH=$(( GAUGES_ROW_WIDTH + width ))
}

gauges_add_pair() {
  local key="$1"
  local value="$2"
  local rendered="${3:-}"
  [ -n "$value" ] || return 0
  sl_width "$value"
  local width=$(( 3 + ${#key} + SL_W ))
  [ -n "$rendered" ] || rendered="${GAUGES_VALUE}${value}${SL_RESET}"
  gauges_add "$width" "  ${GAUGES_KEY}${key}${SL_RESET} ${rendered}"
}

gauges_header() {
  local -a chunk_text=()
  local -a chunk_width=()
  local branch_label="$SL_GIT_BRANCH"
  local marker=""
  local marker_width=0
  if [ -n "$branch_label" ]; then
    sl_trunc "$branch_label" "$GAUGES_BRANCH_MAXIMUM"
    branch_label="$SL_TRUNC"
    sl_width "$branch_label"
    local branch_width="$SL_W"
    if [ "$SL_GIT_AHEAD" -gt 0 ]; then
      marker="$marker ${GAUGES_KEY}↑${SL_GIT_AHEAD}${SL_RESET}"
      marker_width=$(( marker_width + 2 + ${#SL_GIT_AHEAD} ))
    fi
    if [ "$SL_GIT_BEHIND" -gt 0 ]; then
      marker="$marker ${GAUGES_KEY}↓${SL_GIT_BEHIND}${SL_RESET}"
      marker_width=$(( marker_width + 2 + ${#SL_GIT_BEHIND} ))
    fi
    chunk_text+=("${GAUGES_BRANCH}${branch_label}${SL_RESET}${marker}")
    chunk_width+=( $(( branch_width + marker_width )) )
  fi
  if [ -n "$SL_MODEL_NAME" ]; then
    sl_width "$SL_MODEL_NAME"
    chunk_text+=("${GAUGES_MUTED}${SL_MODEL_NAME}${SL_RESET}")
    chunk_width+=("$SL_W")
  fi
  local effort_label=""
  [ -n "$SL_EFFORT" ] && effort_label="$SL_EFFORT effort"
  if [ "$SL_ULTRACODE" = "1" ]; then
    if [ -n "$effort_label" ]; then
      effort_label="ultracode · $effort_label"
    else
      effort_label="ultracode"
    fi
  fi
  if [ -n "$effort_label" ]; then
    sl_width "$effort_label"
    chunk_text+=("${GAUGES_KEY}${effort_label}${SL_RESET}")
    chunk_width+=("$SL_W")
  fi
  if [ -n "$SL_VERSION" ]; then
    sl_width "v$SL_VERSION"
    chunk_text+=("${GAUGES_FRAME}v${SL_VERSION}${SL_RESET}")
    chunk_width+=("$SL_W")
  fi

  local keep="${#chunk_text[@]}"
  local tail_width=0
  local index
  while [ "$keep" -gt 0 ]; do
    tail_width=0
    for (( index = 0; index < keep; index++ )); do
      tail_width=$(( tail_width + 3 + chunk_width[index] ))
    done
    [ $(( SL_COLUMNS - tail_width )) -ge "$GAUGES_PATH_MINIMUM" ] && break
    keep=$(( keep - 1 ))
    tail_width=0
  done

  local path_limit=$(( SL_COLUMNS - tail_width ))
  [ "$path_limit" -lt 4 ] && path_limit=4
  sl_path_fit "$path_limit"
  local line="${GAUGES_VALUE}${SL_PATH_FIT}${SL_RESET}"
  for (( index = 0; index < keep; index++ )); do
    line="$line${GAUGES_FRAME} │ ${SL_RESET}${chunk_text[index]}"
  done
  sl_emit "$line"
}

sl_render() {
  gauges_palette
  sl_git
  sl_gateway
  sl_token_burn

  local grid_room=$(( SL_COLUMNS - GAUGES_LABEL_WIDTH - GAUGES_PERCENT_WIDTH - 4 ))
  GAUGES_BAR_WIDTH=0
  GAUGES_DETAIL_WIDTH=0
  if [ "$grid_room" -ge "$GAUGES_BAR_MINIMUM" ]; then
    GAUGES_BAR_WIDTH=$(( grid_room - GAUGES_DETAIL_RESERVE ))
    [ "$GAUGES_BAR_WIDTH" -lt "$GAUGES_BAR_MINIMUM" ] && GAUGES_BAR_WIDTH="$GAUGES_BAR_MINIMUM"
    [ "$GAUGES_BAR_WIDTH" -gt "$GAUGES_BAR_MAXIMUM" ] && GAUGES_BAR_WIDTH="$GAUGES_BAR_MAXIMUM"
    [ "$GAUGES_BAR_WIDTH" -gt "$grid_room" ] && GAUGES_BAR_WIDTH="$grid_room"
    GAUGES_DETAIL_WIDTH=$(( grid_room - GAUGES_BAR_WIDTH - 2 ))
    [ "$GAUGES_DETAIL_WIDTH" -lt "$GAUGES_DETAIL_MINIMUM" ] && GAUGES_DETAIL_WIDTH=0
  fi

  gauges_header

  gauges_integer "${SL_CONTEXT_TOKENS:-0}"
  local context_tokens="$GAUGES_INTEGER"
  gauges_integer "${SL_CONTEXT_SIZE:-0}"
  local context_size="$GAUGES_INTEGER"
  gauges_integer "${SL_CONTEXT_OUTPUT_TOKENS:-0}"
  local output_tokens="$GAUGES_INTEGER"
  gauges_integer "${SL_LINES_ADDED:-0}"
  local lines_added="$GAUGES_INTEGER"
  gauges_integer "${SL_LINES_REMOVED:-0}"
  local lines_removed="$GAUGES_INTEGER"

  local context_permille=-1
  if [ "$context_size" -gt 0 ] && [ "$context_tokens" -gt 0 ]; then
    context_permille=$(( context_tokens * 1000 / context_size ))
  elif sl_is_number "${SL_CONTEXT_PERCENT:-}"; then
    context_permille=$(( SL_CONTEXT_PERCENT * 10 ))
  fi

  if [ "$context_permille" -ge 0 ]; then
    sl_abbrev "$context_tokens"
    local tokens_text="$SL_ABBREV"
    local context_long="$tokens_text tokens"
    local context_short="$tokens_text"
    if [ "$context_size" -gt 0 ]; then
      sl_abbrev "$context_size"
      context_long="$tokens_text / $SL_ABBREV tokens"
      context_short="$tokens_text / $SL_ABBREV"
    fi
    if sl_is_number "${SL_CONTEXT_REMAINING:-}"; then
      gauges_row "context" "$context_permille" "$context_long · ${SL_CONTEXT_REMAINING}% free" "$context_long" "$context_short"
    else
      gauges_row "context" "$context_permille" "$context_long" "$context_short"
    fi
  fi

  local budget_permille=-1
  if [ -n "$SL_BUDGET_PERCENT" ]; then
    gauges_permille_of_percent "$SL_BUDGET_PERCENT"
    budget_permille="$GAUGES_PERMILLE"
  fi
  local spent_micro=-1
  local limit_micro=-1
  if [ -n "$SL_BUDGET_SPENT" ]; then
    gauges_money_micro "$SL_BUDGET_SPENT"
    spent_micro="$GAUGES_MICRO"
  fi
  if [ -n "$SL_BUDGET_LIMIT" ]; then
    gauges_money_micro "$SL_BUDGET_LIMIT"
    limit_micro="$GAUGES_MICRO"
  fi
  if [ "$budget_permille" -lt 0 ] && [ "$spent_micro" -ge 0 ] && [ "$limit_micro" -gt 0 ]; then
    budget_permille=$(( spent_micro * 1000 / limit_micro ))
  fi

  if [ "$budget_permille" -ge 0 ]; then
    local budget_long=""
    local budget_short=""
    if [ -n "$SL_BUDGET_SPENT" ] && [ -n "$SL_BUDGET_LIMIT" ]; then
      budget_short="$SL_BUDGET_SPENT / $SL_BUDGET_LIMIT"
      budget_long="$budget_short"
      [ -n "$SL_BUDGET_PERIOD" ] && budget_long="$budget_short · $SL_BUDGET_PERIOD"
    elif [ -n "$SL_BUDGET_PERIOD" ]; then
      budget_long="$SL_BUDGET_PERIOD"
      budget_short="$SL_BUDGET_PERIOD"
    fi
    gauges_row "gateway" "$budget_permille" "$budget_long" "$budget_short"
  else
    local gateway_note="unavailable"
    if [ -n "$SL_GATEWAY_RAW" ] && [[ "$SL_GATEWAY_RAW" == *[0-9]* ]]; then
      gateway_note="${SL_GATEWAY_RAW%%$'\n'*}"
    fi
    gauges_note "gateway" "$gateway_note"
  fi

  if [ -n "$SL_COST_TEXT" ]; then
    if [ "$limit_micro" -gt 0 ]; then
      local session_permille=$(( SL_COST_MICRO * 1000 / limit_micro ))
      gauges_row "session" "$session_permille" "$SL_COST_TEXT of $SL_BUDGET_LIMIT" "$SL_COST_TEXT"
    else
      gauges_note "session" "$SL_COST_TEXT"
    fi
  fi

  local heading
  printf -v heading '%-*s' "$GAUGES_LABEL_WIDTH" "totals"
  GAUGES_ROW="${GAUGES_LABEL}${heading}${SL_RESET}"
  GAUGES_ROW_WIDTH="$GAUGES_LABEL_WIDTH"
  GAUGES_ROW_IS_FULL=0
  if [ "$context_tokens" -gt 0 ]; then
    sl_abbrev "$context_tokens"
    gauges_add_pair "in" "$SL_ABBREV"
  fi
  if [ "$output_tokens" -gt 0 ]; then
    sl_abbrev "$output_tokens"
    gauges_add_pair "out" "$SL_ABBREV"
  fi
  local diff_value=""
  local diff_rendered=""
  if [ "$lines_added" -gt 0 ]; then
    diff_value="+$lines_added"
    diff_rendered="${GAUGES_ADDED}+${lines_added}${SL_RESET}"
  fi
  if [ "$lines_removed" -gt 0 ]; then
    [ -n "$diff_value" ] && diff_value="$diff_value "
    [ -n "$diff_rendered" ] && diff_rendered="$diff_rendered "
    diff_value="$diff_value-$lines_removed"
    diff_rendered="$diff_rendered${GAUGES_REMOVED}-${lines_removed}${SL_RESET}"
  fi
  if [ -n "$diff_value" ]; then
    gauges_add_pair "diff" "$diff_value" "$diff_rendered"
  fi
  gauges_integer "${SL_DURATION_MS:-0}"
  if [ "$GAUGES_INTEGER" -gt 0 ]; then
    sl_duration "$GAUGES_INTEGER"
    gauges_add_pair "wall" "$SL_DURATION"
  fi
  if [ "${SL_TOKENS_BURNED:-0}" -gt 0 ]; then
    sl_abbrev "$SL_TOKENS_BURNED"
    gauges_add_pair "burn" "$SL_ABBREV"
  fi
  if [ "$GAUGES_ROW_WIDTH" -gt "$GAUGES_LABEL_WIDTH" ]; then
    sl_emit "$GAUGES_ROW"
  fi
}
