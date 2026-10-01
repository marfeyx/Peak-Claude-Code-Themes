#!/usr/bin/env bash
# @name: sbb
# @description: SBB station — metrics ride the wagons, expresses run the far tracks
# @order: 15

# Evolution of the sbb concourse into a working terminus. The session numbers
# ride as cargo on a rake that never moves: it stands at the platform with one
# wagon per metric, so context and cost are painted full size in every frame.
# All movement happens around it — two through tracks worked in both directions,
# catenary, exit signals, a Mondaine clock and a departure board that turns over.
# The rake only creeps forward when it is booked out, and the new rake berths
# with fresh boards.

WGP_FAR_CYCLE_SECONDS=72
WGP_RAKE_CYCLE_SECONDS=42
WGP_RAKE_DEPARTURE_SECONDS=6
WGP_RAKE_HOME_COLUMN=3
WGP_BOARD_ROTATE_SECONDS=5
WGP_SPACER=$'\u200b'
WGP_MAST_SPACING=11
WGP_SLEEPER_SPACING=4
WGP_MIN_SCENE_COLUMNS=32
WGP_MIN_TRACK_COLUMNS=56
WGP_MIN_CATENARY_COLUMNS=96
WGP_TRAIN_JUMP_DIVISOR=10
WGP_BURN_COLUMNS=86

WGP_HANDS=('↑' '↗' '→' '↘' '↓' '↙' '←' '↖')
WGP_STATIONS=('Zürich HB' 'Bern' 'Basel SBB' 'Luzern' 'Lausanne' 'Genève-Cornavin' 'Olten'
  'Winterthur' 'Chur' 'Bellinzona' 'St. Gallen' 'Biel/Bienne')
WGP_PLATFORMS=('3' '5' '7' '8' '12' '2A' '11AB' '31' '41/42' '13AB')

WGP_SERVICES=(
  'IC 1|Genève-Aéroport|ic'
  'IR 36|Basel SBB|dosto'
  'S 12|Brugg AG|flirt'
  'EC 317|Milano Centrale|giruno'
  'TGV 9264|Paris Gare de Lyon|tgv'
  'Güterzug|Domodossola (I)|freight'
  'IC 5|Lausanne|dosto'
  'RE 33|Baden|flirt'
  'IC 21|Lugano|giruno'
  'NJ 470|Hamburg-Altona|nightjet'
)

WGP_RUNS=('0|23|0' '25|23|0' '48|24|0' '10|20|1' '32|20|1' '52|20|1')

WGP_RE460="▄:metal:red ▀:roof:red:pan █:red:red ▬:glass:red ▶:red:none"
WGP_RE620="▄:metal:red ▀:roof:red:pan █:red:red ▬:glass:red █:red:red ▶:red:none"
WGP_CAB_EW4="▄:metal:white ▬:glass:white ▄:red:white █:white:white ▶:white:none"
WGP_COACH_EW4="▀:roof:white ▬:glass:white ▄:red:white ▬:glass:white ▀:roof:white"
WGP_COACH_FIRST="▀:lemon:white ▬:glass:white ▄:red:white ▬:glass:white ▀:lemon:white"
WGP_GIRUNO_HEAD="▄:metal:white ▀:roof:white:pan ▬:glass:white ▬:glass:red █:red:red ▶:red:none"
WGP_GIRUNO_CAR="▀:roof:white ▬:glass:white ▬:glass:white ▀:roof:white"
WGP_DOSTO_HEAD="▄:metal:white ▀:roof:white:pan ≡:glass:white ▬:glass:red █:red:red ▶:red:none"
WGP_DOSTO_CAR="▀:roof:white ≡:glass:white ┃:red:white ≡:glass:white ▀:roof:white"
WGP_FLIRT_HEAD="▄:metal:white ▬:glass:white ▀:roof:white:pan █:red:red ▶:red:none"
WGP_FLIRT_CAR="▀:roof:white ▬:glass:white ┃:red:white ▀:roof:white"
WGP_TGV_HEAD="▄:metal:cement ▀:roof:cement:pan ▬:glass:cement ▬:glass:red █:red:red ▶:red:none"
WGP_TGV_CAR="▀:roof:cement ▬:glass:cement ┃:red:cement ▬:glass:cement ▀:roof:cement"
WGP_NIGHT_CAR_A="▀:roof:blue ▬:lemon:blue ▬:glass:blue ▬:glass:blue ▀:roof:blue"
WGP_NIGHT_CAR_B="▀:roof:blue ▬:glass:blue ▬:glass:blue ▬:lemon:blue ▀:roof:blue"
WGP_HUPAC_A="▀:sky:metal ▀:sky:metal ▀:orange:metal ▀:orange:metal"
WGP_HUPAC_B="▀:green:metal ▀:green:metal ▀:red:metal ▀:red:metal"
WGP_HUPAC_C="▀:lemon:metal ▀:lemon:metal ▀:turquoise:metal ▀:turquoise:metal"
WGP_HUPAC_D="▀:violet:metal ▀:violet:metal ▀:cloud:metal ▀:cloud:metal"

declare -gA WGP_SGR_CACHE=()

wgp_colour() {
  case "$1" in
    red) WGP_CODE='2;235;0;0' ;;
    red_dark) WGP_CODE='2;198;0;24' ;;
    red_bright) WGP_CODE='2;255;56;56' ;;
    white) WGP_CODE='5;231' ;;
    cloud) WGP_CODE='5;254' ;;
    cement) WGP_CODE='5;250' ;;
    storm) WGP_CODE='5;248' ;;
    smoke) WGP_CODE='5;245' ;;
    metal) WGP_CODE='5;243' ;;
    granite) WGP_CODE='5;242' ;;
    iron) WGP_CODE='5;238' ;;
    charcoal) WGP_CODE='5;234' ;;
    roof) WGP_CODE='5;237' ;;
    glass) WGP_CODE='5;233' ;;
    blue) WGP_CODE='2;45;50;125' ;;
    sky) WGP_CODE='2;18;142;222' ;;
    green) WGP_CODE='2;16;157;71' ;;
    turquoise) WGP_CODE='2;0;165;155' ;;
    orange) WGP_CODE='2;251;142;25' ;;
    peach) WGP_CODE='2;255;199;39' ;;
    lemon) WGP_CODE='2;255;229;71' ;;
    violet) WGP_CODE='2;179;108;197' ;;
    *) WGP_CODE='5;245' ;;
  esac
}

wgp_sgr() {
  if [ "$SL_USE_COLOR" != "1" ]; then
    WGP_SGR=""
    return
  fi
  local cache_key="$1:$2:$3" attributes='0'
  if [ -n "${WGP_SGR_CACHE[$cache_key]:-}" ]; then
    WGP_SGR="${WGP_SGR_CACHE[$cache_key]}"
    return
  fi
  [ "$3" = "1" ] && attributes='0;1'
  wgp_colour "$1"
  attributes="$attributes;38;$WGP_CODE"
  if [ "$2" != "none" ]; then
    wgp_colour "$2"
    attributes="$attributes;48;$WGP_CODE"
  fi
  printf -v WGP_SGR '%s[%sm' "$SL_ESC" "$attributes"
  WGP_SGR_CACHE["$cache_key"]="$WGP_SGR"
}

wgp_paint() {
  wgp_sgr "$1" "$2" "${4:-0}"
  WGP_PAINT="$WGP_SGR$3"
}

wgp_line_reset() {
  WGP_LINE=""
  WGP_LINE_STATE=""
}

wgp_line_add() {
  if [ "$1" = "keep" ]; then
    WGP_LINE="$WGP_LINE$4"
    return
  fi
  wgp_sgr "$1" "$2" "$3"
  if [ "$WGP_SGR" != "$WGP_LINE_STATE" ]; then
    WGP_LINE="$WGP_LINE$WGP_SGR"
    WGP_LINE_STATE="$WGP_SGR"
  fi
  WGP_LINE="$WGP_LINE$4"
}

wgp_clock() {
  local second=$(( SL_NOW % 60 ))
  printf -v WGP_TIME '%(%H:%M)T' "$SL_NOW"
  printf -v WGP_NEXT_TIME '%(%H:%M)T' $(( SL_NOW - second + 60 ))
  printf -v WGP_HOUR '%(%H)T' "$SL_NOW"
  WGP_HOUR="${WGP_HOUR#0}"
  sl_is_number "${WGP_HOUR:-}" || WGP_HOUR=12
  WGP_IS_NIGHT=0
  { [ "$WGP_HOUR" -ge 23 ] || [ "$WGP_HOUR" -le 4 ]; } && WGP_IS_NIGHT=1
  if [ "$second" -ge 58 ]; then
    WGP_HAND="${WGP_HANDS[0]}"
  else
    WGP_HAND="${WGP_HANDS[second * 8 / 58]}"
  fi
}

wgp_identity() {
  local source_text="${SL_SESSION_ID:-$SL_PATH}" total=0 index limit character code
  limit="${#source_text}"
  [ "$limit" -gt 12 ] && limit=12
  for (( index = 0; index < limit; index++ )); do
    character="${source_text:index:1}"
    printf -v code '%d' "'$character" 2>/dev/null || code=0
    total=$(( total + code ))
  done
  WGP_PLATFORM="${WGP_PLATFORMS[total % ${#WGP_PLATFORMS[@]}]}"
  WGP_STATION="${WGP_STATIONS[total % ${#WGP_STATIONS[@]}]}"
}

wgp_service_badge() {
  case "${SL_EFFORT:-}" in
    low) WGP_BADGE='S 12' ;;
    medium) WGP_BADGE='RE 33' ;;
    high) WGP_BADGE='IR 90' ;;
    xhigh) WGP_BADGE='IC 1' ;;
    max) WGP_BADGE='EC 13' ;;
    *) WGP_BADGE='R' ;;
  esac
  [ "$WGP_IS_NIGHT" = "1" ] && [ "$WGP_BADGE" = "S 12" ] && WGP_BADGE='SN 12'
}

wgp_service() {
  local slot=$(( $1 % ${#WGP_SERVICES[@]} )) entry
  entry="${WGP_SERVICES[slot]}"
  WGP_RUN_BADGE="${entry%%|*}"
  entry="${entry#*|}"
  WGP_RUN_DESTINATION="${entry%%|*}"
  WGP_RUN_STOCK="${entry##*|}"
}

wgp_run_duration_floor() {
  local run entry duration
  WGP_RUN_DURATION_FLOOR=0
  for run in "${WGP_RUNS[@]}"; do
    entry="${run#*|}"
    duration="${entry%%|*}"
    sl_is_number "$duration" || continue
    if [ "$WGP_RUN_DURATION_FLOOR" -eq 0 ] || [ "$duration" -lt "$WGP_RUN_DURATION_FLOOR" ]; then
      WGP_RUN_DURATION_FLOOR="$duration"
    fi
  done
  [ "$WGP_RUN_DURATION_FLOOR" -gt "$WGP_TRAIN_JUMP_DIVISOR" ] || WGP_RUN_DURATION_FLOOR=$(( WGP_TRAIN_JUMP_DIVISOR + 1 ))
}

wgp_vehicle() {
  local specification="$1" reversed="${2:-0}" token glyph foreground background extra
  local token_index
  local -a tokens=() ordered=()
  if [ "${#WGP_CELL[@]}" -gt 0 ]; then
    WGP_CELL+=('╍')
    WGP_CELL_FG+=('iron')
    WGP_CELL_BG+=('none')
    WGP_CELL_PAN+=('0')
  fi
  read -ra ordered <<< "$specification"
  if [ "$reversed" = "1" ]; then
    for (( token_index = ${#ordered[@]} - 1; token_index >= 0; token_index-- )); do
      tokens+=("${ordered[token_index]}")
    done
  else
    tokens=("${ordered[@]}")
  fi
  for token in "${tokens[@]}"; do
    glyph="${token%%:*}"
    extra="${token#*:}"
    foreground="${extra%%:*}"
    extra="${extra#*:}"
    background="${extra%%:*}"
    extra="${extra#*:}"
    [ "$extra" = "$background" ] && extra=""
    if [ "$reversed" = "1" ]; then
      case "$glyph" in
        '▶') glyph='◀' ;;
        '◀') glyph='▶' ;;
      esac
    fi
    WGP_CELL+=("$glyph")
    WGP_CELL_FG+=("$foreground")
    WGP_CELL_BG+=("$background")
    if [ "$extra" = "pan" ]; then
      WGP_CELL_PAN+=('1')
    else
      WGP_CELL_PAN+=('0')
    fi
  done
}

wgp_room_for() {
  [ $(( ${#WGP_CELL[@]} + $1 + WGP_TAIL_RESERVE + 1 )) -le "$WGP_TRAIN_BUDGET" ]
}

wgp_compose_train() {
  local stock="$1" wagon_index
  WGP_CELL=()
  WGP_CELL_FG=()
  WGP_CELL_BG=()
  WGP_CELL_PAN=()
  case "$stock" in
    giruno)
      WGP_TAIL_RESERVE=6
      wgp_vehicle "$WGP_GIRUNO_HEAD" 1
      for (( wagon_index = 0; wagon_index < 16; wagon_index++ )); do
        wgp_room_for 5 || break
        wgp_vehicle "$WGP_GIRUNO_CAR"
      done
      wgp_vehicle "$WGP_GIRUNO_HEAD"
      ;;
    dosto)
      WGP_TAIL_RESERVE=6
      wgp_vehicle "$WGP_DOSTO_HEAD" 1
      for (( wagon_index = 0; wagon_index < 16; wagon_index++ )); do
        wgp_room_for 6 || break
        wgp_vehicle "$WGP_DOSTO_CAR"
      done
      wgp_vehicle "$WGP_DOSTO_HEAD"
      ;;
    flirt)
      WGP_TAIL_RESERVE=5
      wgp_vehicle "$WGP_FLIRT_HEAD" 1
      for (( wagon_index = 0; wagon_index < 16; wagon_index++ )); do
        wgp_room_for 5 || break
        wgp_vehicle "$WGP_FLIRT_CAR"
      done
      wgp_vehicle "$WGP_FLIRT_HEAD"
      ;;
    tgv)
      WGP_TAIL_RESERVE=6
      wgp_vehicle "$WGP_TGV_HEAD" 1
      for (( wagon_index = 0; wagon_index < 16; wagon_index++ )); do
        wgp_room_for 6 || break
        wgp_vehicle "$WGP_TGV_CAR"
      done
      wgp_vehicle "$WGP_TGV_HEAD"
      ;;
    freight)
      WGP_TAIL_RESERVE=7
      for (( wagon_index = 0; wagon_index < 20; wagon_index++ )); do
        wgp_room_for 5 || break
        case $(( wagon_index % 4 )) in
          0) wgp_vehicle "$WGP_HUPAC_A" ;;
          1) wgp_vehicle "$WGP_HUPAC_B" ;;
          2) wgp_vehicle "$WGP_HUPAC_C" ;;
          *) wgp_vehicle "$WGP_HUPAC_D" ;;
        esac
      done
      wgp_vehicle "$WGP_RE620"
      ;;
    nightjet)
      WGP_TAIL_RESERVE=6
      for (( wagon_index = 0; wagon_index < 16; wagon_index++ )); do
        wgp_room_for 6 || break
        if [ $(( wagon_index % 2 )) -eq 0 ]; then
          wgp_vehicle "$WGP_NIGHT_CAR_A"
        else
          wgp_vehicle "$WGP_NIGHT_CAR_B"
        fi
      done
      wgp_vehicle "$WGP_RE460"
      ;;
    *)
      WGP_TAIL_RESERVE=6
      wgp_vehicle "$WGP_CAB_EW4" 1
      for (( wagon_index = 0; wagon_index < 16; wagon_index++ )); do
        wgp_room_for 6 || break
        if [ "$wagon_index" -eq 0 ]; then
          wgp_vehicle "$WGP_COACH_FIRST"
        else
          wgp_vehicle "$WGP_COACH_EW4"
        fi
      done
      wgp_vehicle "$WGP_RE460"
      ;;
  esac
  WGP_TRAIN_WIDTH="${#WGP_CELL[@]}"
}

wgp_mirror_train() {
  local index glyph
  local -a mirrored_cell=() mirrored_fg=() mirrored_bg=() mirrored_pan=()
  for (( index = WGP_TRAIN_WIDTH - 1; index >= 0; index-- )); do
    glyph="${WGP_CELL[index]}"
    case "$glyph" in
      '▶') glyph='◀' ;;
      '◀') glyph='▶' ;;
    esac
    mirrored_cell+=("$glyph")
    mirrored_fg+=("${WGP_CELL_FG[index]}")
    mirrored_bg+=("${WGP_CELL_BG[index]}")
    mirrored_pan+=("${WGP_CELL_PAN[index]}")
  done
  WGP_CELL=("${mirrored_cell[@]}")
  WGP_CELL_FG=("${mirrored_fg[@]}")
  WGP_CELL_BG=("${mirrored_bg[@]}")
  WGP_CELL_PAN=("${mirrored_pan[@]}")
}

wgp_track_fill() {
  local column
  WGP_G=()
  WGP_F=()
  WGP_B=()
  WGP_O=()
  for (( column = 0; column < SL_COLUMNS; column++ )); do
    if [ $(( column % WGP_SLEEPER_SPACING )) -eq 0 ]; then
      WGP_G[column]='┯'
    else
      WGP_G[column]='━'
    fi
    WGP_F[column]='iron'
    WGP_B[column]='none'
    WGP_O[column]='0'
  done
}

wgp_stamp_signal() {
  local column="$1" aspect="$2"
  [ "$column" -ge 0 ] && [ "$column" -lt "$SL_COLUMNS" ] || return 0
  WGP_G[column]='▮'
  WGP_F[column]="$aspect"
  WGP_B[column]='none'
  WGP_O[column]='1'
}

wgp_stamp_train() {
  local left="$1" index column
  for (( index = 0; index < WGP_TRAIN_WIDTH; index++ )); do
    column=$(( left + index ))
    [ "$column" -ge 0 ] && [ "$column" -lt "$SL_COLUMNS" ] || continue
    WGP_G[column]="${WGP_CELL[index]}"
    WGP_F[column]="${WGP_CELL_FG[index]}"
    WGP_B[column]="${WGP_CELL_BG[index]}"
    WGP_O[column]='0'
    [ "${WGP_CELL_PAN[index]}" = "1" ] && WGP_PAN[column]='1'
  done
}

wgp_row_string() {
  local column
  wgp_line_reset
  for (( column = 0; column < SL_COLUMNS; column++ )); do
    wgp_line_add "${WGP_F[column]}" "${WGP_B[column]}" "${WGP_O[column]}" "${WGP_G[column]}"
  done
  WGP_LINE="$WGP_LINE$SL_RESET"
}

wgp_build_track() {
  local direction="$1" pass_index slot cycle_tick start duration run entry
  local distance progress left occupied=0 approaching=0 remaining
  cycle_tick=$(( SL_TICK % (WGP_FAR_CYCLE_SECONDS * 100) ))
  pass_index=$(( SL_TICK / (WGP_FAR_CYCLE_SECONDS * 100) ))
  wgp_track_fill
  for (( slot = 0; slot < ${#WGP_RUNS[@]}; slot++ )); do
    run="${WGP_RUNS[slot]}"
    entry="${run##*|}"
    [ "$entry" = "$direction" ] || continue
    start="${run%%|*}"
    entry="${run#*|}"
    duration="${entry%%|*}"
    remaining=$(( start * 100 - cycle_tick ))
    [ "$remaining" -gt 0 ] && [ "$remaining" -le 300 ] && approaching=1
    [ "$cycle_tick" -ge $(( start * 100 )) ] || continue
    [ "$cycle_tick" -lt $(( (start + duration) * 100 )) ] || continue
    wgp_service $(( pass_index * 7 + slot * 3 ))
    wgp_compose_train "$WGP_RUN_STOCK"
    [ "$direction" = "1" ] && wgp_mirror_train
    distance=$(( SL_COLUMNS + WGP_TRAIN_WIDTH ))
    progress=$(( (cycle_tick - start * 100) * distance / (duration * 100) + 1 ))
    if [ "$direction" = "0" ]; then
      left=$(( progress - WGP_TRAIN_WIDTH ))
    else
      left=$(( SL_COLUMNS - progress ))
    fi
    wgp_stamp_train "$left"
    occupied=1
    WGP_TRACK_BADGE="$WGP_RUN_BADGE"
    WGP_TRACK_DESTINATION="$WGP_RUN_DESTINATION"
  done
  if [ "$occupied" = "1" ]; then
    WGP_SIGNAL_ASPECT='red'
  elif [ "$approaching" = "1" ]; then
    WGP_SIGNAL_ASPECT='peach'
  else
    WGP_SIGNAL_ASPECT='green'
  fi
  if [ "$direction" = "0" ]; then
    wgp_stamp_signal $(( SL_COLUMNS - 1 )) "$WGP_SIGNAL_ASPECT"
  else
    wgp_stamp_signal 0 "$WGP_SIGNAL_ASPECT"
  fi
  wgp_row_string
}

wgp_build_catenary() {
  local column
  wgp_line_reset
  for (( column = 0; column < SL_COLUMNS; column++ )); do
    if [ "${WGP_PAN[column]}" = "1" ]; then
      wgp_line_add cloud none 0 '∧'
    elif [ $(( column % WGP_MAST_SPACING )) -eq 0 ]; then
      wgp_line_add metal none 0 '┬'
    else
      wgp_line_add iron none 0 '╌'
    fi
  done
  WGP_CATENARY="$WGP_LINE$SL_RESET"
}

wgp_wagon_add() {
  WGP_WAGON_LABEL+=("$1")
  WGP_WAGON_VALUE+=("$2")
  WGP_WAGON_SHORT+=("$3")
  WGP_WAGON_ACCENT+=("$4")
  WGP_WAGON_COLOUR+=("$5")
  WGP_WAGON_KIND+=("$6")
}

wgp_build_wagons() {
  local context_value="" context_colour=green cost_value="$SL_COST_TEXT"
  WGP_WAGON_LABEL=()
  WGP_WAGON_VALUE=()
  WGP_WAGON_SHORT=()
  WGP_WAGON_ACCENT=()
  WGP_WAGON_COLOUR=()
  WGP_WAGON_KIND=()

  WGP_CONTEXT_FULL=0
  if sl_is_number "${SL_CONTEXT_PERCENT:-}"; then
    context_value="${SL_CONTEXT_PERCENT}%"
    [ "$SL_CONTEXT_PERCENT" -ge 90 ] && WGP_CONTEXT_FULL=1
    [ "$SL_CONTEXT_PERCENT" -ge 50 ] && context_colour=orange
    [ "$SL_CONTEXT_PERCENT" -ge 75 ] && context_colour=red_dark
    [ "$SL_CONTEXT_PERCENT" -ge 90 ] && context_colour=red
  else
    context_value='k. A.'
    context_colour=granite
  fi
  wgp_wagon_add 'Kontext' "$context_value" "ctx $context_value" "$context_colour" "$context_colour" context

  [ -n "$cost_value" ] || cost_value='$0.00'
  wgp_wagon_add 'Kosten' "$cost_value" "$cost_value" red red_dark cost

  WGP_WAGON_REQUIRED=2

  if [ "${SL_LINES_ADDED:-0}" != "0" ] || [ "${SL_LINES_REMOVED:-0}" != "0" ]; then
    wgp_wagon_add 'Diff' "+${SL_LINES_ADDED}/-${SL_LINES_REMOVED}" \
      "+${SL_LINES_ADDED}/-${SL_LINES_REMOVED}" sky green diff
  fi
  if [ -n "${SL_TOKENS_BURNED_TEXT:-}" ] && [ "${SL_TOKENS_BURNED:-0}" -gt 0 ]; then
    sl_abbrev "$SL_TOKENS_BURNED"
    wgp_wagon_add 'Ladung' "$SL_ABBREV" "$SL_ABBREV" turquoise blue tokens
  fi
  if [ -n "$SL_MODEL_SHORT" ]; then
    wgp_wagon_add 'Traktion' "$SL_MODEL_SHORT" "$SL_MODEL_SHORT" violet charcoal model
  fi
  WGP_WAGON_COUNT="${#WGP_WAGON_LABEL[@]}"
}

wgp_rake_width() {
  local with_loco="$1" with_labels="$2" count="$3" index total=0
  [ "$with_loco" = "1" ] && total=$(( 7 + ${#WGP_BADGE} ))
  for (( index = 0; index < count; index++ )); do
    [ "$total" -gt 0 ] && total=$(( total + 1 ))
    if [ "$with_labels" = "1" ]; then
      sl_width "${WGP_WAGON_LABEL[index]} ${WGP_WAGON_VALUE[index]}"
    else
      sl_width "${WGP_WAGON_SHORT[index]}"
    fi
    total=$(( total + SL_W + 4 ))
  done
  WGP_RAKE_WIDTH="$total"
}

wgp_rake_plan() {
  local budget="$1" with_loco with_labels count
  for with_loco in 1 0; do
    for with_labels in 1 0; do
      for (( count = WGP_WAGON_COUNT; count >= WGP_WAGON_REQUIRED; count-- )); do
        wgp_rake_width "$with_loco" "$with_labels" "$count"
        if [ "$WGP_RAKE_WIDTH" -le "$budget" ]; then
          WGP_RAKE_LOCO="$with_loco"
          WGP_RAKE_LABELS="$with_labels"
          WGP_RAKE_WAGONS="$count"
          return 0
        fi
      done
    done
  done
  return 1
}

wgp_rake_push() {
  WGP_RAKE_G+=("$1")
  WGP_RAKE_F+=("$2")
  WGP_RAKE_B+=("$3")
  WGP_RAKE_O+=("$4")
  WGP_RAKE_W+=("$5")
}

wgp_rake_text() {
  local text="$1" index character
  for (( index = 0; index < ${#text}; index++ )); do
    character="${text:index:1}"
    wgp_rake_push "$character" "$2" "$3" "$4" 0
  done
}

wgp_rake_compose() {
  local index cap_colour wheel_left wheel_right body_start value kind
  WGP_RAKE_G=()
  WGP_RAKE_F=()
  WGP_RAKE_B=()
  WGP_RAKE_O=()
  WGP_RAKE_W=()
  if [ "$WGP_RAKE_LOCO" = "1" ]; then
    wgp_rake_push '◀' red none 1 0
    wgp_rake_push '█' red red 0 1
    wgp_rake_push '▬' glass red 0 0
    wgp_rake_text " $WGP_BADGE " white red 1
    wgp_rake_push '▄' metal red 0 1
    wgp_rake_push '▀' roof red 0 0
  fi
  for (( index = 0; index < WGP_RAKE_WAGONS; index++ )); do
    cap_colour="${WGP_WAGON_ACCENT[index]}"
    [ "$WGP_RAKE_AGE" -lt 3 ] && cap_colour=white
    if [ $(( SL_NOW % 2 )) -eq 0 ]; then
      [ "$WGP_RAKE_DEPARTING" = "1" ] && cap_colour=lemon
      [ "${WGP_WAGON_KIND[index]}" = "context" ] && [ "$WGP_CONTEXT_FULL" = "1" ] && cap_colour=red_bright
    fi
    [ "${#WGP_RAKE_G[@]}" -gt 0 ] && wgp_rake_push '╍' iron none 0 0
    wgp_rake_push '▐' "$cap_colour" none 0 0
    body_start="${#WGP_RAKE_G[@]}"
    wgp_rake_text ' ' granite cloud 0
    if [ "$WGP_RAKE_LABELS" = "1" ]; then
      wgp_rake_text "${WGP_WAGON_LABEL[index]} " granite cloud 0
    fi
    kind="${WGP_WAGON_KIND[index]}"
    if [ "$WGP_RAKE_LABELS" = "1" ]; then
      value="${WGP_WAGON_VALUE[index]}"
    else
      value="${WGP_WAGON_SHORT[index]}"
    fi
    if [ "$kind" = "diff" ]; then
      wgp_rake_text "${value%%/*}" green cloud 1
      wgp_rake_text "/${value#*/}" red_dark cloud 1
    else
      wgp_rake_text "$value" "${WGP_WAGON_COLOUR[index]}" cloud 1
    fi
    wgp_rake_text ' ' granite cloud 0
    wheel_left=$(( body_start + 1 ))
    wheel_right=$(( ${#WGP_RAKE_G[@]} - 3 ))
    [ "$wheel_right" -gt $(( wheel_left + 1 )) ] || wheel_right=$(( wheel_left + 1 ))
    WGP_RAKE_W[wheel_left]=1
    WGP_RAKE_W[wheel_left + 1]=1
    WGP_RAKE_W[wheel_right]=1
    WGP_RAKE_W[wheel_right + 1]=1
    wgp_rake_push '▌' "$cap_colour" none 0 0
  done
  WGP_RAKE_CELLS="${#WGP_RAKE_G[@]}"
}

wgp_monitor_text() {
  local slot=$(( (SL_TICK / (WGP_BOARD_ROTATE_SECONDS * 100)) % 3 )) pass
  pass=$(( SL_TICK / (WGP_FAR_CYCLE_SECONDS * 100) ))
  wgp_service $(( pass * 7 + slot * 3 + 1 ))
  if [ "$WGP_RAKE_DEPARTING" = "1" ]; then
    WGP_MONITOR="Türen schliessen selbsttätig"
    WGP_MONITOR_TONE=peach
    return
  fi
  WGP_MONITOR="${WGP_NEXT_TIME}  ${WGP_RUN_BADGE} nach ${WGP_RUN_DESTINATION}"
  WGP_MONITOR_TONE=lemon
}

wgp_platform_furniture() {
  local count="$1" index absolute
  for (( index = 0; index < count; index++ )); do
    absolute=$(( WGP_RAKE_LEFT + WGP_RAKE_CELLS + index ))
    case $(( absolute % 9 )) in
      2) wgp_line_add granite none 0 '╥' ;;
      6) wgp_line_add granite none 0 '▄' ;;
      *) wgp_line_add keep none 0 ' ' ;;
    esac
  done
}

wgp_build_rake_rows() {
  local index column padding monitor_width tail=0
  wgp_line_reset
  for (( column = 0; column < WGP_RAKE_LEFT; column++ )); do
    wgp_line_add keep none 0 ' '
  done
  for (( index = 0; index < WGP_RAKE_CELLS; index++ )); do
    wgp_line_add "${WGP_RAKE_F[index]}" "${WGP_RAKE_B[index]}" "${WGP_RAKE_O[index]}" "${WGP_RAKE_G[index]}"
  done
  tail=$(( SL_COLUMNS - WGP_RAKE_LEFT - WGP_RAKE_CELLS ))
  if [ "$tail" -gt 0 ]; then
    wgp_platform_furniture $(( tail - 1 ))
    wgp_line_add metal none 0 '╥'
  fi
  WGP_RAKE_ROW="$WGP_LINE$SL_RESET"

  wgp_line_reset
  for (( column = 0; column < SL_COLUMNS; column++ )); do
    index=$(( column - WGP_RAKE_LEFT ))
    if [ "$index" -ge 0 ] && [ "$index" -lt "$WGP_RAKE_CELLS" ]; then
      if [ "${WGP_RAKE_W[index]}" = "1" ]; then
        wgp_line_add charcoal none 0 '●'
      else
        wgp_line_add granite none 0 '━'
      fi
    elif [ "$column" -eq $(( SL_COLUMNS - 1 )) ]; then
      wgp_line_add red none 1 '╣'
    elif [ $(( column % WGP_SLEEPER_SPACING )) -eq 0 ]; then
      wgp_line_add granite none 0 '┯'
    else
      wgp_line_add granite none 0 '━'
    fi
  done
  WGP_UNDERFRAME="$WGP_LINE$SL_RESET"
}

wgp_build_header() {
  local logo_text=' SBB CFF FFS ↔ ' logo_width=17 logo_tone=red
  local sign_text="" sign_width=0 poster_text="" poster_width=0 remaining used padding notice
  local line=""
  [ $(( SL_NOW % 4 )) -eq 0 ] && logo_tone=red_bright
  if [ $(( SL_COLUMNS - logo_width - 17 )) -lt 14 ]; then
    logo_text=' ↔ '
    logo_width=5
  fi
  remaining=$(( SL_COLUMNS - logo_width - 2 - 9 - 2 - 4 ))
  sl_path_fit "$remaining"
  sign_text="$SL_PATH_FIT"
  sl_width "$sign_text"
  sign_width="$SL_W"

  wgp_paint "$logo_tone" none '▐'
  line="$WGP_PAINT"
  wgp_paint white "$logo_tone" "$logo_text" 1
  line="$line$WGP_PAINT"
  wgp_paint "$logo_tone" none '▌'
  line="$line$WGP_PAINT$SL_RESET  "

  wgp_paint blue none '▐'
  line="$line$WGP_PAINT"
  wgp_paint white blue " $sign_text "
  line="$line$WGP_PAINT"
  wgp_paint blue none '▌'
  line="$line$WGP_PAINT$SL_RESET"

  if [ -n "$poster_text" ]; then
    used=$(( logo_width + 2 + 9 + 2 + sign_width + 4 ))
    padding=$(( SL_COLUMNS - used - poster_width ))
    sl_duration "${SL_DURATION_MS:-0}"
    notice="Fahrzeit ${SL_DURATION}"
    [ -n "$SL_REPO_NAME" ] && notice="${notice} · ${SL_REPO_NAME}"
    sl_width "$notice"
    if [ "$padding" -ge $(( SL_W + 6 )) ]; then
      wgp_paint granite none "  $notice"
      line="$line$WGP_PAINT$SL_RESET"
      padding=$(( padding - SL_W - 2 ))
    fi
    [ "$padding" -lt 2 ] && padding=2
    printf -v line '%s%*s' "$line" "$padding" ''
    wgp_paint peach none '▐'
    line="$line$WGP_PAINT"
    wgp_paint charcoal peach "$poster_text" 1
    line="$line$WGP_PAINT"
    wgp_paint peach none '▌'
    line="$line$WGP_PAINT"
  fi
  WGP_HEADER="$line$SL_RESET"
}

wgp_board_append() {
  [ $(( WGP_BOARD_WIDTH + $1 )) -le "$WGP_BOARD_LIMIT" ] || return 1
  WGP_BOARD="$WGP_BOARD$2"
  WGP_BOARD_WIDTH=$(( WGP_BOARD_WIDTH + $1 ))
  return 0
}

wgp_build_board() {
  local platform_label="Gleis ${WGP_PLATFORM}" platform_width destination
  local destination_limit separator padding note="" note_tone=smoke
  platform_width=0
  WGP_BOARD=""
  WGP_BOARD_WIDTH=0
  WGP_BOARD_LIMIT=$(( SL_COLUMNS - platform_width - 2 ))

  wgp_paint cloud none "$WGP_NEXT_TIME" 1
  wgp_board_append 5 "$WGP_PAINT$SL_RESET"

  sl_width "$WGP_BADGE"
  wgp_paint white iron " $WGP_BADGE " 1
  wgp_board_append $(( SL_W + 4 )) "  $WGP_PAINT$SL_RESET"

  destination="$SL_GIT_BRANCH"
  [ -n "$destination" ] || destination="$WGP_STATION"
  destination_limit=$(( WGP_BOARD_LIMIT - WGP_BOARD_WIDTH - 20 ))
  if [ "$destination_limit" -ge 6 ]; then
    sl_trunc "$destination" "$destination_limit"
    destination="$SL_TRUNC"
    sl_width "$destination"
    wgp_paint smoke none '  nach '
    separator="$WGP_PAINT"
    wgp_paint white none "$destination" 1
    wgp_board_append $(( SL_W + 8 )) "$separator$WGP_PAINT$SL_RESET"
  fi

  if [ "$WGP_RAKE_DEPARTING" = "1" ]; then
    note='Abfahrt'
    note_tone=peach
  elif [ "$WGP_RAKE_AGE" -lt 4 ]; then
    note='Einfahrt'
    note_tone=lemon
  elif sl_is_number "${SL_CONTEXT_PERCENT:-}" && [ "$SL_CONTEXT_PERCENT" -ge 90 ]; then
    note='überfüllt'
    note_tone=red_bright
  fi
  if [ -n "$note" ]; then
    sl_width "$note"
    wgp_paint "$note_tone" none "$note" 1
    wgp_board_append $(( SL_W + 2 )) "  $WGP_PAINT$SL_RESET"
  fi

  WGP_BOARD="$WGP_BOARD$SL_RESET"
}

wgp_build_compact() {
  local line="" budget context_text="" context_colour=green cost_text="$SL_COST_TEXT"
  wgp_paint red none '▐'
  line="$WGP_PAINT"
  wgp_paint white red ' ↔ ' 1
  line="$line$WGP_PAINT"
  wgp_paint red none '▌'
  line="$line$WGP_PAINT"
  wgp_paint cloud none " $WGP_TIME " 1
  line="$line$WGP_PAINT"
  budget=$(( SL_COLUMNS - 16 ))
  [ "$budget" -lt 6 ] && budget=6
  sl_path_fit "$budget"
  wgp_paint blue none '▐'
  line="$line$WGP_PAINT"
  wgp_paint white blue " $SL_PATH_FIT "
  line="$line$WGP_PAINT"
  wgp_paint blue none '▌'
  WGP_COMPACT_TOP="$line$WGP_PAINT$SL_RESET"

  if sl_is_number "${SL_CONTEXT_PERCENT:-}"; then
    context_text="ctx ${SL_CONTEXT_PERCENT}%"
    [ "$SL_CONTEXT_PERCENT" -ge 50 ] && context_colour=orange
    [ "$SL_CONTEXT_PERCENT" -ge 75 ] && context_colour=red_bright
  else
    context_text='ctx k. A.'
    context_colour=granite
  fi
  [ -n "$cost_text" ] || cost_text='$0.00'
  wgp_paint "$context_colour" none "$context_text" 1
  line="$WGP_PAINT"
  wgp_paint iron none ' · '
  line="$line$WGP_PAINT"
  wgp_paint red_bright none "$cost_text" 1
  line="$line$WGP_PAINT"
  sl_width "$context_text · $cost_text"
  if [ -n "$SL_GIT_BRANCH" ] && [ $(( SL_W + 4 )) -lt "$SL_COLUMNS" ]; then
    sl_trunc "$SL_GIT_BRANCH" $(( SL_COLUMNS - SL_W - 3 ))
    wgp_paint iron none ' · '
    line="$line$WGP_PAINT"
    wgp_paint storm none "$SL_TRUNC"
    line="$line$WGP_PAINT"
  fi
  WGP_COMPACT_BOTTOM="$line$SL_RESET"
}

sl_render() {
  local rake_tick rake_phase rake_budget creep column

  sl_git
  wgp_clock
  wgp_identity
  wgp_service_badge
  [ "$SL_COLUMNS" -ge "$WGP_BURN_COLUMNS" ] && sl_token_burn
  wgp_build_wagons

  rake_tick=$(( SL_TICK % (WGP_RAKE_CYCLE_SECONDS * 100) ))
  WGP_RAKE_AGE=$(( rake_tick / 100 ))
  rake_phase=$(( WGP_RAKE_CYCLE_SECONDS - WGP_RAKE_AGE ))
  WGP_RAKE_DEPARTING=0
  [ "$rake_phase" -le "$WGP_RAKE_DEPARTURE_SECONDS" ] && WGP_RAKE_DEPARTING=1

  rake_budget=$(( SL_COLUMNS - WGP_RAKE_HOME_COLUMN - 1 ))
  if [ "$SL_COLUMNS" -lt "$WGP_MIN_SCENE_COLUMNS" ] || ! wgp_rake_plan "$rake_budget"; then
    wgp_build_compact
    sl_emit "$WGP_COMPACT_TOP"
    sl_emit "$WGP_COMPACT_BOTTOM"
    return
  fi

  creep=0
  if [ "$WGP_RAKE_DEPARTING" = "1" ]; then
    creep=$(( (WGP_RAKE_DEPARTURE_SECONDS - rake_phase) / 2 + 1 ))
    [ "$creep" -gt "$WGP_RAKE_HOME_COLUMN" ] && creep="$WGP_RAKE_HOME_COLUMN"
  fi
  WGP_RAKE_LEFT=$(( WGP_RAKE_HOME_COLUMN - creep ))
  wgp_rake_compose
  wgp_build_rake_rows

  WGP_TRACK_BADGE=""
  WGP_TRACK_DESTINATION=""
  if [ "$SL_COLUMNS" -ge "$WGP_MIN_TRACK_COLUMNS" ]; then
    wgp_run_duration_floor
    WGP_TRAIN_CEILING=$(( SL_COLUMNS * (WGP_RUN_DURATION_FLOOR - WGP_TRAIN_JUMP_DIVISOR) / WGP_TRAIN_JUMP_DIVISOR ))
    WGP_TRAIN_BUDGET=$(( SL_COLUMNS * 2 / 3 ))
    [ "$WGP_TRAIN_BUDGET" -gt "$WGP_TRAIN_CEILING" ] && WGP_TRAIN_BUDGET="$WGP_TRAIN_CEILING"
    WGP_PAN=()
    for (( column = 0; column < SL_COLUMNS; column++ )); do
      WGP_PAN[column]='0'
    done
    wgp_build_track 0
    WGP_TRACK_A="$WGP_LINE"
    wgp_build_track 1
    WGP_TRACK_B="$WGP_LINE"
    wgp_build_catenary
  fi

  wgp_build_header
  wgp_build_board

  sl_emit "$WGP_HEADER"
  if [ "$SL_COLUMNS" -ge "$WGP_MIN_TRACK_COLUMNS" ]; then
    [ "$SL_COLUMNS" -ge "$WGP_MIN_CATENARY_COLUMNS" ] && sl_emit "$WGP_CATENARY"
    sl_emit "$WGP_TRACK_A"
    sl_emit "$WGP_SPACER"
    sl_emit "$WGP_TRACK_B"
    sl_emit "$WGP_SPACER"
  fi
  sl_emit "$WGP_RAKE_ROW"
  sl_emit "$WGP_UNDERFRAME"
  sl_emit "$WGP_BOARD"
}
