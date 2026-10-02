#!/usr/bin/env bash
# @name: sakura
# @description: Cherry bough and drifting petals over two rows of ink-dark readout
# @order: 32

# Liza's sakura package ships no status line — it is a Claude Code palette, a
# Windows Terminal colour scheme and an animated wallpaper. These rows are
# written to match it rather than ported from it, and every colour below is
# taken from her sakura.json or her Windows Terminal scheme.
#
# It is a LIGHT theme, which inverts two habits. Nothing paints a background:
# the sky is left unpainted so the pale wallpaper shows through, exactly as the
# underwater theme leaves open water for the acrylic tint. And depth runs the
# other way — a near petal is the darkest thing on screen, a far one is the
# palest, because contrast against a bright background falls as things recede.
#
# Every petal position is a pure function of SL_NOW, so two renders of the same
# second are identical. Rows carry no background colour, so each one is emitted
# only as far as its last painted cell; a row that caught no petal at all would
# be blank once escapes are stripped, and Claude Code discards those, so it
# emits a zero-width space instead.

SAKURA_SKY_ROWS=5
SAKURA_BOUGH_SHARE=55
SAKURA_BOUGH_MINIMUM=8
SAKURA_PETAL_SPACING=9
SAKURA_PETAL_FLOOR=4
SAKURA_SWAY_SECONDS=23
SAKURA_BAR_WIDTH=12
SAKURA_CONTEXT_WARN=85

# The directory is the one field a status line must never shed first, so the
# first readout row keeps at least SAKURA_PATH_FLOOR cells for it and sheds the
# branch and the diffstat instead. Below SAKURA_PATH_MINIMUM cells sl_path_fit
# can only return ellipses, so the field is dropped whole rather than shown as
# '……' behind an orphan separator.
SAKURA_PATH_FLOOR=10
SAKURA_PATH_MINIMUM=4

# Tone table, indexed by the numbers passed to sakura_paint.
#   0 near petal      sakura.json effortUltra / clawd_body
#   1 mid petal       between that and the pale blossom
#   2 far petal       pale enough to read as distance, not as text
#   3 bough           sakura.json bashBorder
#   4 blossom heart   sakura.json claude
SAKURA_TONES=(
  '117 27 72' '168 84 122' '200 146 170' '95 53 33' '100 24 62'
)

SAKURA_NEAR=0
SAKURA_MID=1
SAKURA_FAR=2
SAKURA_BOUGH=3
SAKURA_HEART=4

SAKURA_PETAL_GLYPHS=('❀' '✿' '∙')
SAKURA_BLOSSOM_GLYPHS=('❀' '❁' '✿')

SAKURA_GLYPH=()
SAKURA_TONE=()
SAKURA_LAST=()
SAKURA_CODE=()

sakura_hash() {
  local mixed
  mixed=$(( ($1 * 2654435761 + $2 * 40503 + 2166136261) & 0x7FFFFFFF ))
  mixed=$(( ((mixed ^ (mixed >> 13)) * 1103515245) & 0x7FFFFFFF ))
  SAKURA_HASH=$(( mixed ^ (mixed >> 16) ))
}

sakura_paint() {
  local row="$1"
  local col="$2"
  local glyph="$3"
  local tone="$4"
  local index
  [ "$row" -ge 0 ] && [ "$row" -lt "$SAKURA_SKY_ROWS" ] || return 0
  [ "$col" -ge 0 ] && [ "$col" -lt "$SAKURA_WIDTH" ] || return 0
  index=$(( row * SAKURA_WIDTH + col ))
  SAKURA_GLYPH[index]="$glyph"
  SAKURA_TONE[index]="$tone"
  [ "$col" -gt "${SAKURA_LAST[row]}" ] && SAKURA_LAST[row]="$col"
  return 0
}

sakura_draw_bough() {
  local length="$1"
  local col glyph heavy light clusters index anchor lean stem petals offset
  local jitter bud tone row
  heavy=$(( length * 68 / 100 ))
  light=$(( length * 88 / 100 ))
  for (( col = 0; col < length; col++ )); do
    if [ "$col" -lt "$heavy" ]; then
      glyph='━'
    elif [ "$col" -lt "$light" ]; then
      glyph='─'
    else
      glyph='╌'
    fi
    sakura_paint 0 "$col" "$glyph" "$SAKURA_BOUGH"
  done

  [ "$length" -ge 6 ] || return 0

  clusters=$(( 2 + length / 26 ))
  for (( index = 0; index < clusters; index++ )); do
    sakura_hash "$index" 613
    anchor=$(( 1 + SAKURA_HASH % (length - 3) ))
    sakura_hash "$index" 911
    lean=$(( SAKURA_HASH % 2 ))
    if [ "$lean" -eq 0 ]; then
      sakura_paint 1 "$anchor" '╲' "$SAKURA_BOUGH"
      stem=$(( anchor + 1 ))
    else
      sakura_paint 1 "$anchor" '╱' "$SAKURA_BOUGH"
      stem=$(( anchor - 1 ))
    fi

    sakura_hash "$index" 1217
    petals=$(( 3 + SAKURA_HASH % 3 ))
    for (( offset = 0; offset < petals; offset++ )); do
      sakura_hash $(( index * 31 + offset )) 1409
      jitter=$(( SAKURA_HASH % 3 - 1 ))
      sakura_hash $(( index * 31 + offset )) 1613
      bud=$(( SAKURA_HASH % 3 ))
      row=$(( 1 + (offset + lean) % 2 ))
      if [ $(( (index + offset) % 2 )) -eq 0 ]; then
        tone="$SAKURA_HEART"
      else
        tone="$SAKURA_NEAR"
      fi
      sakura_paint "$row" $(( stem + jitter + offset - 1 )) \
        "${SAKURA_BLOSSOM_GLYPHS[bud]}" "$tone"
    done
  done
  return 0
}

sakura_draw_petals() {
  local count index depth glyph tone sway start fall row col
  count=$(( SAKURA_WIDTH / SAKURA_PETAL_SPACING + SAKURA_PETAL_FLOOR ))
  sl_phase "$SAKURA_SWAY_SECONDS"

  for (( index = 0; index < count; index++ )); do
    sakura_hash "$index" 17
    start=$(( SAKURA_HASH % SAKURA_WIDTH ))
    sakura_hash "$index" 23
    depth=$(( SAKURA_HASH % 3 ))
    glyph="${SAKURA_PETAL_GLYPHS[depth]}"
    tone="$depth"

    fall=$(( depth + 1 ))
    sakura_hash "$index" 29
    row=$(( 1 + (SL_NOW / fall + SAKURA_HASH) % (SAKURA_SKY_ROWS - 1) ))

    sl_cos $(( SL_PHASE + index * 97 ))
    sway=$(( SL_COS * 2 / 1000 ))
    col=$(( (start + (SL_NOW * (3 - depth)) / 2 + sway) % SAKURA_WIDTH ))
    [ "$col" -lt 0 ] && col=$(( col + SAKURA_WIDTH ))

    sakura_paint "$row" "$col" "$glyph" "$tone"
  done
  return 0
}

sakura_emit_sky() {
  local row col index last glyph tone previous text
  for (( row = 0; row < SAKURA_SKY_ROWS; row++ )); do
    last="${SAKURA_LAST[row]}"
    if [ "$last" -lt 0 ]; then
      sl_emit_raw "$SAKURA_BLANK"
      continue
    fi
    text=""
    previous=""
    for (( col = 0; col <= last; col++ )); do
      index=$(( row * SAKURA_WIDTH + col ))
      glyph="${SAKURA_GLYPH[index]:-}"
      if [ -z "$glyph" ]; then
        text="$text "
        continue
      fi
      tone="${SAKURA_TONE[index]}"
      if [ "$tone" != "$previous" ]; then
        text="$text${SAKURA_CODE[tone]}"
        previous="$tone"
      fi
      text="$text$glyph"
    done
    sl_emit "$text$SL_RESET"
  done
  return 0
}

sakura_bar() {
  local percent="${1:-0}"
  local whole="${percent%%.*}"
  local index output=""
  sl_is_number "${whole:-}" || whole=0
  sl_bar "$whole" "$SAKURA_BAR_WIDTH" '━' '─'
  if [ "$SL_USE_COLOR" != "1" ]; then
    SAKURA_BAR="$SL_BAR"
    return 0
  fi
  for (( index = 0; index < SL_BAR_WIDTH; index++ )); do
    if [ "$index" -lt "$SL_BAR_FILLED" ]; then
      if [ "$whole" -ge "$SAKURA_CONTEXT_WARN" ]; then
        output="$output${SAKURA_ERROR}━"
      else
        output="$output${SAKURA_PLUM}━"
      fi
    else
      output="$output${SAKURA_TRACK}─"
    fi
  done
  SAKURA_BAR="$output$SL_RESET"
  return 0
}

# Second readout row, built as a ladder rather than a greedy append.
#
# Appending segment by segment until the budget runs out is not monotonic: the
# full model name is longer than the short one, so there are widths where
# 'Opus 5 (1M context)' fits and then eats the context percentage that 'Opus 5'
# had left room for, and dragging the pane wider made the most useful number
# vanish and come back. Priority shedding has the same flaw from the other side,
# because admitting a higher-priority field evicts a lower one.
#
# Each level below is a strict superset of the one before, in content and in
# width, so the widest level that fits is also the most informative one, and
# widening the pane can only ever add. The context percentage is in level 0 and
# is therefore the one thing that is never shed.
#
#   0  context percentage
#   1  + model, short name
#   2  + effort
#   3  + session cost
#   4  model name grows to its full form
#   5  + context gauge
SAKURA_TWO_LEVELS=5

sakura_two_push() {
  SAKURA_PART+=( "$1" )
  SAKURA_PART_WIDTH=$(( SAKURA_PART_WIDTH + $2 ))
  return 0
}

sakura_two_level() {
  local level="$1"
  local model effort_text context_label context_body context_width index

  SAKURA_PART=()
  SAKURA_PART_WIDTH=0

  model=""
  if [ "$level" -ge 1 ]; then
    model="$SL_MODEL_SHORT"
    [ "$level" -ge 4 ] && [ -n "$SL_MODEL_NAME" ] && model="$SL_MODEL_NAME"
    [ -z "$model" ] && model="$SL_MODEL_NAME"
  fi
  if [ -n "$model" ]; then
    sl_width "$model"
    sakura_two_push "${SAKURA_BLUE}${model}${SL_RESET}" "$SL_W"
  fi

  if [ "$level" -ge 2 ] && [ -n "$SL_EFFORT" ]; then
    effort_text="$SL_EFFORT effort"
    [ "$SL_ULTRACODE" = "1" ] && effort_text="ultracode · $effort_text"
    sl_width "$effort_text"
    sakura_two_push "${SAKURA_PLUM}${effort_text}${SL_RESET}" "$SL_W"
  fi

  if sl_is_number "${SL_CONTEXT_PERCENT:-}"; then
    context_label="${SL_CONTEXT_PERCENT}%"
    if [ "$SL_CONTEXT_PERCENT" -ge "$SAKURA_CONTEXT_WARN" ]; then
      context_body="${SAKURA_ERROR}${context_label}${SL_RESET}"
    else
      context_body="${SAKURA_INK}${context_label}${SL_RESET}"
    fi
    context_width="${#context_label}"
    if [ "$level" -ge 5 ]; then
      sakura_bar "$SL_CONTEXT_PERCENT"
      context_body="${SAKURA_BAR} ${context_body}"
      context_width=$(( context_width + 1 + SAKURA_BAR_WIDTH ))
    fi
    sakura_two_push "$context_body" "$context_width"
  fi

  if [ "$level" -ge 3 ] && [ -n "$SL_COST_TEXT" ]; then
    sakura_two_push "${SAKURA_SUBTLE}${SL_COST_TEXT}${SL_RESET}" "${#SL_COST_TEXT}"
  fi

  SAKURA_TWO="$SAKURA_GUTTER"
  SAKURA_TWO_WIDTH=$(( 1 + SAKURA_PART_WIDTH ))
  for index in "${!SAKURA_PART[@]}"; do
    if [ "$index" -eq 0 ]; then
      SAKURA_TWO="$SAKURA_TWO ${SAKURA_PART[index]}"
      SAKURA_TWO_WIDTH=$(( SAKURA_TWO_WIDTH + 1 ))
    else
      SAKURA_TWO="$SAKURA_TWO ${SAKURA_SUBTLE}·${SL_RESET} ${SAKURA_PART[index]}"
      SAKURA_TWO_WIDTH=$(( SAKURA_TWO_WIDTH + 3 ))
    fi
  done
  return 0
}

sl_render() {
  local tone bough_length
  local path_display branch_name markers marker_width diffstat diffstat_width
  local line_one line_one_width
  local level best_level

  SAKURA_WIDTH="$SL_COLUMNS"
  printf -v SAKURA_BLANK '​'

  SAKURA_CODE=()
  for tone in "${!SAKURA_TONES[@]}"; do
    SAKURA_CODE[tone]="$(sl_fg ${SAKURA_TONES[tone]})"
  done

  SAKURA_INK="$(sl_fg 16 26 38)"
  SAKURA_SUBTLE="$(sl_fg 66 62 72)"
  SAKURA_PLUM="$(sl_fg 117 27 72)"
  SAKURA_BLUE="$(sl_fg 19 67 105)"
  SAKURA_LEAF="$(sl_fg 12 74 46)"
  SAKURA_ERROR="$(sl_fg 128 16 32)"
  SAKURA_WARN="$(sl_fg 78 48 3)"
  SAKURA_TRACK="$(sl_fg 190 170 180)"
  SAKURA_GUTTER="$(sl_fg 117 27 72)▌$SL_RESET"

  SAKURA_GLYPH=()
  SAKURA_TONE=()
  SAKURA_LAST=()
  local row
  for (( row = 0; row < SAKURA_SKY_ROWS; row++ )); do
    SAKURA_LAST[row]=-1
  done

  bough_length=$(( SAKURA_WIDTH * SAKURA_BOUGH_SHARE / 100 ))
  [ "$bough_length" -lt "$SAKURA_BOUGH_MINIMUM" ] && bough_length="$SAKURA_WIDTH"
  [ "$bough_length" -gt "$SAKURA_WIDTH" ] && bough_length="$SAKURA_WIDTH"
  sakura_draw_bough "$bough_length"
  sakura_draw_petals
  sakura_emit_sky

  sl_git

  branch_name="$SL_GIT_BRANCH"
  markers=""
  marker_width=0
  if [ -n "$branch_name" ]; then
    if [ "${SL_GIT_AHEAD:-0}" -gt 0 ]; then
      markers="$markers ${SAKURA_LEAF}↑${SL_GIT_AHEAD}${SL_RESET}"
      marker_width=$(( marker_width + 2 + ${#SL_GIT_AHEAD} ))
    fi
    if [ "${SL_GIT_BEHIND:-0}" -gt 0 ]; then
      markers="$markers ${SAKURA_WARN}↓${SL_GIT_BEHIND}${SL_RESET}"
      marker_width=$(( marker_width + 2 + ${#SL_GIT_BEHIND} ))
    fi
  fi

  diffstat=""
  diffstat_width=0
  if [ "${SL_LINES_ADDED:-0}" != "0" ] || [ "${SL_LINES_REMOVED:-0}" != "0" ]; then
    diffstat="${SAKURA_LEAF}+${SL_LINES_ADDED}${SL_RESET}${SAKURA_SUBTLE}/${SL_RESET}${SAKURA_ERROR}-${SL_LINES_REMOVED}${SL_RESET}"
    diffstat_width=$(( 3 + ${#SL_LINES_ADDED} + ${#SL_LINES_REMOVED} ))
  fi

  local path_room path_floor reserved
  path_room=$(( SL_COLUMNS - 2 ))
  path_floor="$SAKURA_PATH_FLOOR"
  [ "$path_floor" -gt "$path_room" ] && path_floor="$path_room"
  reserved=0
  [ -n "$branch_name" ] && reserved=$(( reserved + 3 + marker_width ))
  [ -n "$diffstat" ] && reserved=$(( reserved + 3 + diffstat_width ))
  [ $(( path_room - reserved )) -lt "$path_floor" ] && reserved=$(( path_room - path_floor ))
  [ "$reserved" -lt 0 ] && reserved=0

  path_display=""
  if [ $(( path_room - reserved )) -ge "$SAKURA_PATH_MINIMUM" ]; then
    sl_path_fit $(( path_room - reserved ))
    path_display="$SL_PATH_FIT"
  fi

  line_one="$SAKURA_GUTTER"
  line_one_width=2
  if [ -n "$path_display" ]; then
    sl_width "$path_display"
    line_one="$line_one ${SAKURA_INK}${path_display}${SL_RESET}"
    line_one_width=$(( line_one_width + SL_W ))
  fi

  if [ -n "$branch_name" ]; then
    local branch_room
    branch_room=$(( SL_COLUMNS - line_one_width - 3 - marker_width ))
    [ -n "$diffstat" ] && branch_room=$(( branch_room - 3 - diffstat_width ))
    if [ "$branch_room" -ge 4 ]; then
      sl_trunc "$branch_name" "$branch_room"
      branch_name="$SL_TRUNC"
      sl_width "$branch_name"
      line_one="$line_one ${SAKURA_SUBTLE}·${SL_RESET} ${SAKURA_PLUM}${branch_name}${SL_RESET}${markers}"
      line_one_width=$(( line_one_width + 3 + SL_W + marker_width ))
    fi
  fi
  if [ -n "$diffstat" ] && [ $(( line_one_width + 3 + diffstat_width )) -le "$SL_COLUMNS" ]; then
    line_one="$line_one ${SAKURA_SUBTLE}·${SL_RESET} $diffstat"
    line_one_width=$(( line_one_width + 3 + diffstat_width ))
  fi
  sl_emit "$line_one"

  best_level=0
  for (( level = SAKURA_TWO_LEVELS; level > 0; level-- )); do
    sakura_two_level "$level"
    if [ "$SAKURA_TWO_WIDTH" -le "$SL_COLUMNS" ]; then
      best_level="$level"
      break
    fi
  done
  [ "$best_level" -eq 0 ] && sakura_two_level 0

  sl_emit "$SAKURA_TWO"
  return 0
}
