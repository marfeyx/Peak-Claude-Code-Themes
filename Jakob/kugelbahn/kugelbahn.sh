#!/usr/bin/env bash
# @name: kugelbahn
# @description: Wooden marble run — one red Kugel per finished workflow subagent, filling a 65-ball preserve jar
# @order: 22

# A glass preserve jar standing on the workbench at the foot of the Kugelbahn,
# anchored at the left edge where the background run's last chute comes down.
# Every workflow subagent that finishes sends one red marble down the run; it
# drops in under the brass lid and settles on the pile. The jar holds exactly
# 65, in five courses of thirteen, graduated on the scale beside the glass at
# 13, 26, 39, 52 and 65. The glass shows twelve round marbles, about one per
# five and a half, stacked five, four and three up into the neck, so the pile
# climbs the scale in step with the ticks, the jar only looks full at 65 and the
# exact figure is in the readout. Marble 66 and onward come over the lip and
# heap up on the bench to the right, two courses deep, as far as the width goes.
#
# The count is real and exact. It is the number of {"type":"result"} and
# {"type":"failed"} records in this session's workflow journals under
# <transcript>/subagents/workflows/wf_*/journal.jsonl, read incrementally from a
# byte offset ledger so a frame only ever reads the tail that is new. A plain
# Task-tool subagent outside a workflow writes no completion record anywhere, so
# it never drops a marble; only workflow agents are counted. Failures count as
# done — they are drawn as dull marbles spread evenly through the jar, which
# states the ratio without claiming an order, and tallied as ✗N in the readout.
#
# The terminal background shader is DECORATIVE. It receives nothing but Time,
# Scale, Resolution and Background, it cannot read a file, and this theme never
# rewrites it. Its Kugelbahn runs on its own cadence from the clock alone. The
# exact count lives here, in the jar below the input field, and nowhere else.
#
# The marbles are the shared tiles in kugel-sprites.sh and the jar is drawn
# here, both as square sub-pixels packed two to a cell as half blocks with a
# per-cell foreground and background, so every marble is a shaded sphere with a
# specular dot and the jar has a domed knurled lid wider than its neck, a
# rounded shoulder, a bellied body and a foot standing on the bench. Under NO_COLOR every
# sub-pixel that is lit stays a block, so the silhouettes survive.
#
# SL_KUGEL_FAKE_BALLS, SL_KUGEL_FAKE_FAILED and SL_KUGEL_FAKE_PENDING force the
# ledger for testing; SL_KUGEL_BALLS and SL_KUGEL_FAILED are accepted as aliases.

. "$SL_HOME/kugel-sprites.sh"

KUGELBAHN_CAPACITY=65
KUGELBAHN_PER_COURSE=13
KUGELBAHN_COURSES=5
KUGELBAHN_ROLL_SECONDS=4
KUGELBAHN_RELEASE_SPACING=3
KUGELBAHN_QUEUE_CAP=12
KUGELBAHN_FRESH_SECONDS=2
KUGELBAHN_SCHEMA=kgb1

KUGELBAHN_TIER_JAR_COLUMNS=44
KUGELBAHN_TIER_GAUGE_COLUMNS=32
KUGELBAHN_SCALE_FULL=4
KUGELBAHN_SCALE_COMPACT=6
KUGELBAHN_TICK_TOP=2
KUGELBAHN_BEAD=4
KUGELBAHN_PITCH=5
KUGELBAHN_GLASS=vtu
KUGELBAHN_ENTRY_FULL=13
KUGELBAHN_ENTRY_COMPACT=8
KUGELBAHN_PILE_COURSES_FULL=2
KUGELBAHN_PILE_COURSES_COMPACT=1
KUGELBAHN_COUNT_FIELD=8
KUGELBAHN_PATH_FLOOR=14
KUGELBAHN_BRANCH_MAX=24

KUGELBAHN_JAR_FULL=(
  '.....OLLLMMMMMMMMMMNNNO.....'
  '...OLNLNLNMOMOMOMONPNPNPP...'
  '.....WvvvvvvvvvvvvvvvvY.....'
  '.....WvvvvvvvvvvvvvvvvY.....'
  '..XWWvvvvvvvvvvvvvvvvvvYZz..'
  '.WvvvvvvvvvvvvvvvvvvvvvvvvZ.'
  'WvvvvvvvvvvvvvvvvvvvvvvvvvvY'
  'WtvvvvvvvvvvvvvvvvvvvvvvvvuY'
  'WtvvvvvvvvvvvvvvvvvvvvvvvvuY'
  'WtvvvvvvvvvvvvvvvvvvvvvvvvuY'
  'WtvvvvvvvvvvvvvvvvvvvvvvvvuY'
  'WtvvvvvvvvvvvvvvvvvvvvvvvvuY'
  'WvvvvvvvvvvvvvvvvvvvvvvvvvvY'
  '.XvvvvvvvvvvvvvvvvvvvvvvvvZ.'
  '..XXXXXXXXYYYYYYYYYZZZZZZZ..'
)
KUGELBAHN_SLOTS_FULL=('2 10' '22 10' '7 10' '17 10' '12 10' '4 6' '19 6' '9 6' '14 6' '7 2' '17 2' '12 2')

KUGELBAHN_JAR_COMPACT=(
  '....OLLMMMMNNO....'
  '..OLNLNMOMONPNPP..'
  '...WvvvvvvvvvvY...'
  '...WvvvvvvvvvvY...'
  '.XWvvvvvvvvvvvvYZ.'
  'WvvvvvvvvvvvvvvvvY'
  'WtvvvvvvvvvvvvvvuY'
  'WtvvvvvvvvvvvvvvuY'
  'WvvvvvvvvvvvvvvvvY'
  '.XvvvvvvvvvvvvvvZ.'
  '..XXXXXYYYYYZZZZ..'
)
KUGELBAHN_SLOTS_COMPACT=('2 6' '12 6' '7 6' '4 2' '9 2')

declare -gA KUGELBAHN_RGB=(
  [wood_shadow]='74;48;26'
  [glass_wall]='96;132;140'
  [bead_spec]='255;240;236'
  [bead_hi]='255;186;170'
  [bead_lit]='250;108;94'
  [dead_lit]='146;116;112'
  [text_path]='226;196;156'
  [text_branch]='164;206;150'
  [text_faint]='126;104;82'
  [text_good]='142;204;142'
  [text_caution]='236;196;120'
  [text_warn]='236;120;100'
  [text_cost]='236;186;128'
  [text_model]='170;178;196'
  [text_count]='255;196;150'
)

declare -gA KUGELBAHN_SGR_CACHE=()

kugelbahn_style() {
  if [ "$SL_USE_COLOR" != "1" ]; then
    KUGELBAHN_STYLE=''
    return 0
  fi
  local key="${1}|${2}"
  if [ -n "${KUGELBAHN_SGR_CACHE[$key]:-}" ]; then
    KUGELBAHN_STYLE="${KUGELBAHN_SGR_CACHE[$key]}"
    return 0
  fi
  if [ -z "$2" ]; then
    printf -v KUGELBAHN_STYLE '%s[0;38;2;%sm' "$SL_ESC" "${KUGELBAHN_RGB[$1]}"
  elif [ -z "$1" ]; then
    printf -v KUGELBAHN_STYLE '%s[0;48;2;%sm' "$SL_ESC" "${KUGELBAHN_RGB[$2]}"
  else
    printf -v KUGELBAHN_STYLE '%s[0;38;2;%s;48;2;%sm' \
      "$SL_ESC" "${KUGELBAHN_RGB[$1]}" "${KUGELBAHN_RGB[$2]}"
  fi
  KUGELBAHN_SGR_CACHE["$key"]="$KUGELBAHN_STYLE"
  return 0
}

kugelbahn_paint() {
  if [ "$SL_USE_COLOR" = "1" ]; then
    KUGELBAHN_PAINT="${SL_ESC}[0;38;2;${KUGELBAHN_RGB[$1]}m${2}"
  else
    KUGELBAHN_PAINT="$2"
  fi
  return 0
}

# ------------------------------------------------------------------ the count

kugelbahn_scan() {
  KUGELBAHN_RESULTS=0
  KUGELBAHN_FAILURES=0
  KUGELBAHN_ROWS=""
  KUGELBAHN_LEDGER_LINE=""
  KUGELBAHN_STATE_FILE=""

  [ -n "${SL_TRANSCRIPT:-}" ] || return 0
  sl_state_path "${KUGELBAHN_SCHEMA}${SL_TRANSCRIPT//\//_}"
  KUGELBAHN_STATE_FILE="$SL_STATE_FILE"

  local tag first second third fourth fifth
  local -A stored_offset=() stored_results=() stored_failures=()
  if [ -f "$KUGELBAHN_STATE_FILE" ]; then
    while IFS=$'\t' read -r tag first second third fourth fifth; do
      case "${tag:-}" in
        j)
          [ -n "${first:-}" ] || continue
          sl_is_number "${second:-}" || continue
          sl_is_number "${third:-}" || continue
          sl_is_number "${fourth:-}" || continue
          stored_offset["$first"]="$second"
          stored_results["$first"]="$third"
          stored_failures["$first"]="$fourth"
          ;;
        L)
          KUGELBAHN_LEDGER_LINE="${first:-0}"$'\t'"${second:-0}"$'\t'"${third:-0}"$'\t'"${fourth:-0}"$'\t'"${fifth:-0}"
          ;;
      esac
    done < "$KUGELBAHN_STATE_FILE"
  fi

  local restore_nullglob
  shopt -q nullglob && restore_nullglob=1 || restore_nullglob=0
  shopt -s nullglob
  local -a journals=("${SL_TRANSCRIPT%.jsonl}"/subagents/workflows/wf_*/journal.jsonl)
  [ "$restore_nullglob" = "1" ] || shopt -u nullglob
  [ "${#journals[@]}" -gt 0 ] || return 0

  local -a sizes=()
  mapfile -t sizes < <(stat -c %s "${journals[@]}" 2>/dev/null)
  if [ "${#sizes[@]}" -ne "${#journals[@]}" ]; then
    sizes=()
    local probe
    for probe in "${journals[@]}"; do
      sizes+=("$(stat -c %s "$probe" 2>/dev/null || printf 0)")
    done
  fi

  local index journal size offset results failures
  local -a cold=()
  local -A cold_size=()
  for (( index = 0; index < ${#journals[@]}; index++ )); do
    journal="${journals[index]}"
    size="${sizes[index]:-0}"
    sl_is_number "$size" || size=0
    sizes[index]="$size"
    offset="${stored_offset[$journal]:-0}"
    if [ "$size" -lt "$offset" ]; then
      stored_offset["$journal"]=0
      stored_results["$journal"]=0
      stored_failures["$journal"]=0
      offset=0
    fi
    if [ "$offset" -eq 0 ] && [ "$size" -gt 0 ]; then
      cold+=("$journal")
      cold_size["$journal"]="$size"
    fi
  done

  local cold_path cold_bytes cold_results cold_failures cold_length cold_kind
  if [ "${#cold[@]}" -gt 0 ]; then
    while IFS=$'\t' read -r cold_path cold_bytes cold_results cold_failures cold_length cold_kind; do
      [ -n "${cold_path:-}" ] || continue
      sl_is_number "${cold_bytes:-}" || continue
      size="${cold_size[$cold_path]:-0}"
      if [ "$cold_bytes" -gt "$size" ]; then
        cold_bytes=$(( cold_bytes - cold_length - 1 ))
        [ "$cold_kind" = "1" ] && cold_results=$(( cold_results - 1 ))
        [ "$cold_kind" = "2" ] && cold_failures=$(( cold_failures - 1 ))
      fi
      [ "$cold_bytes" -lt 0 ] && cold_bytes=0
      [ "$cold_results" -lt 0 ] && cold_results=0
      [ "$cold_failures" -lt 0 ] && cold_failures=0
      stored_offset["$cold_path"]="$cold_bytes"
      stored_results["$cold_path"]="$cold_results"
      stored_failures["$cold_path"]="$cold_failures"
    done < <(LC_ALL=C awk '
      function flush() {
        if (previous != "") {
          printf "%s\t%d\t%d\t%d\t%d\t%d\n", previous, bytes, results, failures, lastlen, lastkind
        }
      }
      FNR == 1 {
        flush()
        previous = FILENAME
        bytes = 0; results = 0; failures = 0; lastlen = 0; lastkind = 0
      }
      {
        lastlen = length($0)
        lastkind = 0
        if (index($0, "\"type\":\"result\"")) { lastkind = 1; results++ }
        else if (index($0, "\"type\":\"failed\"")) { lastkind = 2; failures++ }
        bytes += lastlen + 1
      }
      END { flush() }
    ' "${cold[@]}" 2>/dev/null)
  fi

  local waiting added_results added_failures consumed
  for (( index = 0; index < ${#journals[@]}; index++ )); do
    journal="${journals[index]}"
    size="${sizes[index]:-0}"
    offset="${stored_offset[$journal]:-0}"
    results="${stored_results[$journal]:-0}"
    failures="${stored_failures[$journal]:-0}"
    waiting=$(( size - offset ))
    if [ "$waiting" -gt 0 ]; then
      read -r added_results added_failures consumed < <(
        tail -c +$(( offset + 1 )) "$journal" 2>/dev/null | LC_ALL=C awk -v waiting="$waiting" '
        {
          lastlen = length($0)
          lastkind = 0
          if (index($0, "\"type\":\"result\"")) { lastkind = 1; results++ }
          else if (index($0, "\"type\":\"failed\"")) { lastkind = 2; failures++ }
          consumed += lastlen + 1
        }
        END {
          if (consumed > waiting) {
            consumed -= lastlen + 1
            if (lastkind == 1) { results-- } else if (lastkind == 2) { failures-- }
          }
          printf "%d %d %d\n", results + 0, failures + 0, consumed + 0
        }'
      )
      sl_is_number "${added_results:-}" || added_results=0
      sl_is_number "${added_failures:-}" || added_failures=0
      sl_is_number "${consumed:-}" || consumed=0
      results=$(( results + added_results ))
      failures=$(( failures + added_failures ))
      offset=$(( offset + consumed ))
    fi
    KUGELBAHN_RESULTS=$(( KUGELBAHN_RESULTS + results ))
    KUGELBAHN_FAILURES=$(( KUGELBAHN_FAILURES + failures ))
    KUGELBAHN_ROWS="${KUGELBAHN_ROWS}j"$'\t'"${journal}"$'\t'"${offset}"$'\t'"${results}"$'\t'"${failures}"$'\n'
  done
  return 0
}

kugelbahn_derive() {
  if [ "$KUGELBAHN_SETTLED" -gt "$KUGELBAHN_CAPACITY" ]; then
    KUGELBAHN_JAR="$KUGELBAHN_CAPACITY"
    KUGELBAHN_SPILL=$(( KUGELBAHN_SETTLED - KUGELBAHN_CAPACITY ))
  else
    KUGELBAHN_JAR="$KUGELBAHN_SETTLED"
    KUGELBAHN_SPILL=0
  fi
  [ "$KUGELBAHN_FAILED" -gt "$KUGELBAHN_SETTLED" ] && KUGELBAHN_FAILED="$KUGELBAHN_SETTLED"
  return 0
}

kugelbahn_forced() {
  local balls="${SL_KUGEL_FAKE_BALLS:-${SL_KUGEL_BALLS:-}}"
  sl_is_number "$balls" || return 1
  KUGELBAHN_SETTLED="$balls"
  local failed="${SL_KUGEL_FAKE_FAILED:-${SL_KUGEL_FAILED:-}}"
  sl_is_number "$failed" && KUGELBAHN_FAILED="$failed"
  if sl_is_number "${SL_KUGEL_FAKE_PENDING:-}" && [ "$SL_KUGEL_FAKE_PENDING" -gt 0 ]; then
    KUGELBAHN_PENDING="$SL_KUGEL_FAKE_PENDING"
    local landing span remaining
    landing=$(( ( SL_NOW / KUGELBAHN_ROLL_SECONDS + 1 ) * KUGELBAHN_ROLL_SECONDS ))
    span=$(( KUGELBAHN_ROLL_SECONDS * 100 ))
    remaining=$(( landing * 100 - SL_TICK ))
    [ "$remaining" -lt 0 ] && remaining=0
    [ "$remaining" -gt "$span" ] && remaining="$span"
    KUGELBAHN_FLIGHT=$(( 1000 - remaining * 1000 / span ))
  fi
  KUGELBAHN_TOTAL=$(( KUGELBAHN_SETTLED + KUGELBAHN_PENDING ))
  kugelbahn_derive
  return 0
}

kugelbahn_ledger() {
  KUGELBAHN_SETTLED=0
  KUGELBAHN_PENDING=0
  KUGELBAHN_FAILED=0
  KUGELBAHN_JAR=0
  KUGELBAHN_SPILL=0
  KUGELBAHN_TOTAL=0
  KUGELBAHN_FLIGHT=-1
  KUGELBAHN_LANDED=0

  kugelbahn_forced && return 0

  kugelbahn_scan
  KUGELBAHN_FAILED="$KUGELBAHN_FAILURES"
  KUGELBAHN_TOTAL=$(( KUGELBAHN_RESULTS + KUGELBAHN_FAILURES ))

  local high=0 settled=0 queued=0 landing=0 landed=0
  if [ -n "$KUGELBAHN_LEDGER_LINE" ]; then
    IFS=$'\t' read -r high settled queued landing landed <<< "$KUGELBAHN_LEDGER_LINE"
    sl_is_number "${high:-}" || high=0
    sl_is_number "${settled:-}" || settled=0
    sl_is_number "${queued:-}" || queued=0
    sl_is_number "${landing:-}" || landing=0
    sl_is_number "${landed:-}" || landed=0
  fi
  [ "$KUGELBAHN_TOTAL" -gt "$high" ] && high="$KUGELBAHN_TOTAL"

  if [ "${SL_PREVIEW:-0}" = "1" ]; then
    if [ -z "$KUGELBAHN_LEDGER_LINE" ]; then
      settled="$high"
      landed=0
    fi
    KUGELBAHN_SETTLED="$settled"
    KUGELBAHN_LANDED="$landed"
    kugelbahn_derive
    return 0
  fi

  local was_high="$high" was_settled="$settled" was_queued="$queued" was_landing="$landing"
  local discovered excess

  discovered=$(( high - settled - queued ))
  [ "$discovered" -gt 0 ] && queued=$(( queued + discovered ))
  [ "$queued" -lt 0 ] && queued=0
  if [ "$queued" -gt "$KUGELBAHN_QUEUE_CAP" ]; then
    excess=$(( queued - KUGELBAHN_QUEUE_CAP ))
    settled=$(( settled + excess ))
    queued="$KUGELBAHN_QUEUE_CAP"
    landed="$SL_NOW"
  fi
  if [ "$queued" -gt 0 ] && [ "$landing" -le 0 ]; then
    landing=$(( SL_NOW + KUGELBAHN_ROLL_SECONDS ))
  fi
  while [ "$queued" -gt 0 ] && [ "$SL_NOW" -ge "$landing" ]; do
    settled=$(( settled + 1 ))
    queued=$(( queued - 1 ))
    landed="$landing"
    if [ "$queued" -gt 0 ]; then
      landing=$(( landing + KUGELBAHN_RELEASE_SPACING ))
    else
      landing=0
    fi
  done

  KUGELBAHN_SETTLED="$settled"
  KUGELBAHN_PENDING="$queued"
  KUGELBAHN_LANDED="$landed"

  if [ "$high" != "$was_high" ] || [ "$settled" != "$was_settled" ] ||
     [ "$queued" != "$was_queued" ] || [ "$landing" != "$was_landing" ]; then
    if [ -n "$KUGELBAHN_STATE_FILE" ]; then
      local payload="${KUGELBAHN_ROWS}L"$'\t'"${high}"$'\t'"${settled}"$'\t'"${queued}"$'\t'"${landing}"$'\t'"${landed}"$'\n'
      local temporary="${KUGELBAHN_STATE_FILE}.$$"
      if 2>/dev/null printf '%s' "$payload" > "$temporary"; then
        mv -f "$temporary" "$KUGELBAHN_STATE_FILE" 2>/dev/null || rm -f "$temporary" 2>/dev/null
      else
        rm -f "$temporary" 2>/dev/null
      fi
    fi
  fi

  if [ "$queued" -gt 0 ] && [ "$landing" -gt 0 ]; then
    local span=$(( KUGELBAHN_ROLL_SECONDS * 100 )) remaining
    remaining=$(( landing * 100 - SL_TICK ))
    [ "$remaining" -lt 0 ] && remaining=0
    [ "$remaining" -gt "$span" ] && remaining="$span"
    KUGELBAHN_FLIGHT=$(( 1000 - remaining * 1000 / span ))
  fi

  kugelbahn_derive
  return 0
}

# -------------------------------------------------------------------- the art

kugelbahn_bench_tone() {
  local x="$1"
  if [ $(( x % 9 )) -eq 4 ]; then
    KUGELBAHN_TONE=s
  elif [ $(( x % 5 )) -eq 2 ]; then
    KUGELBAHN_TONE=r
  else
    KUGELBAHN_TONE=q
  fi
  return 0
}

kugelbahn_marble() {
  local x0="$1" y0="$2" set="$KUGEL_RUBY" shade="${4:-0}" mask="${5:-}" iy ix row c index tone x y
  [ "${3:-ruby}" = dull ] && set="$KUGEL_DULL"
  for (( iy = 0; iy < ${#KUGEL_TILE_4_0[@]}; iy++ )); do
    row="${KUGEL_TILE_4_0[iy]}"
    y=$(( y0 + iy ))
    [ "$y" -ge 0 ] && [ "$y" -lt "$KUGEL_CH" ] || continue
    for (( ix = 0; ix < ${#row}; ix++ )); do
      c="${row:ix:1}"
      [ "$c" = . ] && continue
      x=$(( x0 + ix ))
      [ "$x" -ge 0 ] && [ "$x" -lt "$KUGEL_CW" ] || continue
      if [ -n "$mask" ]; then
        tone="${KUGEL_PX[y * KUGEL_CW + x]}"
        case "$mask" in *"$tone"*) ;; *) continue ;; esac
      fi
      index=$(( c + shade ))
      [ "$c" -eq 0 ] && [ "$shade" -gt 0 ] && index=0
      [ "$index" -lt 0 ] && index=0
      [ "$index" -gt 8 ] && index=8
      KUGEL_PX[y * KUGEL_CW + x]="${set:index:1}"
    done
  done
  return 0
}

kugelbahn_beads() {
  local -n slots="KUGELBAHN_SLOTS_${KUGELBAHN_VARIANT}"
  local count="${#slots[@]}"
  KUGELBAHN_BEADS=0
  [ "$1" -gt 0 ] || return 0
  KUGELBAHN_BEADS=$(( 1 + ( $1 - 1 ) * ( count - 1 ) / ( KUGELBAHN_CAPACITY - 1 ) ))
  [ "$KUGELBAHN_BEADS" -gt "$count" ] && KUGELBAHN_BEADS="$count"
  return 0
}

kugelbahn_dull_plan() {
  local shown=$(( KUGELBAHN_BEADS + KUGELBAHN_SPILL_SHOWN )) settled=$(( KUGELBAHN_JAR + KUGELBAHN_SPILL )) dull
  KUGELBAHN_SHOWN="$shown"
  KUGELBAHN_DULL=0
  [ "$KUGELBAHN_FAILED" -gt 0 ] && [ "$shown" -gt 0 ] && [ "$settled" -gt 0 ] || return 0
  dull=$(( ( KUGELBAHN_FAILED * shown + settled / 2 ) / settled ))
  [ "$dull" -lt 1 ] && dull=1
  if [ "$KUGELBAHN_FAILED" -lt "$settled" ] && [ "$dull" -ge "$shown" ] && [ "$shown" -gt 1 ]; then
    dull=$(( shown - 1 ))
  fi
  [ "$dull" -gt "$shown" ] && dull="$shown"
  KUGELBAHN_DULL="$dull"
  return 0
}

kugelbahn_look() {
  local index="$1" newest="$2" half=$(( KUGELBAHN_SHOWN / 2 ))
  KUGELBAHN_LOOK=ruby
  KUGELBAHN_SHADE=0
  if [ "$KUGELBAHN_DULL" -gt 0 ] &&
     [ $(( ( ( index + 1 ) * KUGELBAHN_DULL + half ) / KUGELBAHN_SHOWN )) -gt $(( ( index * KUGELBAHN_DULL + half ) / KUGELBAHN_SHOWN )) ]; then
    KUGELBAHN_LOOK=dull
  fi
  if [ "$KUGELBAHN_FRESH" -eq 1 ] && [ "$newest" -eq 1 ]; then
    KUGELBAHN_LOOK=ruby
    KUGELBAHN_SHADE=-1
  fi
  return 0
}

kugelbahn_drop() {
  local -n slots="KUGELBAHN_SLOTS_${KUGELBAHN_VARIANT}" entry="KUGELBAHN_ENTRY_${KUGELBAHN_VARIANT}"
  local slot tx ty start=-4 fall roll distance travelled x y
  [ "$KUGELBAHN_FLIGHT" -ge 0 ] || return 0
  [ "$KUGELBAHN_SETTLED" -lt "$KUGELBAHN_CAPACITY" ] || return 0
  [ "$KUGELBAHN_BEADS" -lt "${#slots[@]}" ] || return 0
  slot=(${slots[KUGELBAHN_BEADS]})
  tx="${slot[0]}"
  ty="${slot[1]}"
  fall=$(( ty - start ))
  roll=$(( tx - entry ))
  [ "$roll" -lt 0 ] && roll=$(( - roll ))
  distance=$(( fall + roll ))
  travelled=$(( ( distance * KUGELBAHN_FLIGHT + 500 ) / 1000 ))
  if [ "$travelled" -le "$fall" ]; then
    x="$entry"
    y=$(( start + travelled ))
  else
    y="$ty"
    if [ "$tx" -ge "$entry" ]; then
      x=$(( entry + travelled - fall ))
    else
      x=$(( entry - travelled + fall ))
    fi
  fi
  kugelbahn_marble "$x" "$y" ruby -1 "$KUGELBAHN_GLASS"
  return 0
}

kugelbahn_jar_canvas() {
  local -n art="KUGELBAHN_JAR_${KUGELBAHN_VARIANT}" slots="KUGELBAHN_SLOTS_${KUGELBAHN_VARIANT}"
  local width=$(( KUGELBAHN_JAR_WIDTH + KUGELBAHN_SCALE )) height bottom x y row c index slot newest
  height=$(( ${#art[@]} + 1 ))
  bottom=$(( height - 1 ))
  kugel_canvas "$width" "$height"
  for (( y = 0; y < ${#art[@]}; y++ )); do
    row="${art[y]}"
    for (( x = 0; x < ${#row}; x++ )); do
      c="${row:x:1}"
      [ "$c" = . ] || KUGEL_PX[y * width + x]="$c"
    done
  done
  for (( x = 0; x < width; x++ )); do
    kugelbahn_bench_tone "$x"
    KUGEL_PX[bottom * width + x]="$KUGELBAHN_TONE"
  done
  for (( index = 0; index < KUGELBAHN_BEADS; index++ )); do
    slot=(${slots[index]})
    newest=0
    [ "$KUGELBAHN_SPILL" -eq 0 ] && [ "$index" -eq $(( KUGELBAHN_BEADS - 1 )) ] && newest=1
    kugelbahn_look "$index" "$newest"
    kugelbahn_marble "${slot[0]}" "${slot[1]}" "$KUGELBAHN_LOOK" "$KUGELBAHN_SHADE"
  done
  kugelbahn_drop
  kugel_compose
  KUGELBAHN_JAR_ROWS=("${KUGEL_ROWS[@]}")
  KUGELBAHN_JAR_WIDTHS=("${KUGEL_WIDTHS[@]}")
  return 0
}

kugelbahn_pile_slot() {
  local index="$1" column
  local -n courses="KUGELBAHN_PILE_COURSES_${KUGELBAHN_VARIANT}"
  KUGELBAHN_SLOT_Y=$(( KUGELBAHN_HEIGHT - 1 - KUGELBAHN_BEAD ))
  if [ "$courses" -lt 2 ] || [ "$index" -eq 0 ]; then
    KUGELBAHN_SLOT_X=$(( index * KUGELBAHN_PITCH + 1 ))
  elif [ $(( index % 2 )) -eq 1 ]; then
    column=$(( ( index + 1 ) / 2 ))
    KUGELBAHN_SLOT_X=$(( column * KUGELBAHN_PITCH + 1 ))
  else
    column=$(( ( index - 2 ) / 2 ))
    KUGELBAHN_SLOT_X=$(( column * KUGELBAHN_PITCH + 4 ))
    KUGELBAHN_SLOT_Y=$(( KUGELBAHN_SLOT_Y - KUGELBAHN_BEAD ))
  fi
  return 0
}

kugelbahn_pile_fit() {
  local width="$1" index
  KUGELBAHN_SPILL_SHOWN=0
  for (( index = 0; index < KUGELBAHN_SPILL; index++ )); do
    kugelbahn_pile_slot "$index"
    [ $(( KUGELBAHN_SLOT_X + KUGELBAHN_BEAD )) -le "$width" ] || break
    KUGELBAHN_SPILL_SHOWN=$(( index + 1 ))
  done
  return 0
}

kugelbahn_pile_layout() {
  local room="$1"
  KUGELBAHN_CHIP=''
  KUGELBAHN_PILE_WIDTH=0
  KUGELBAHN_SPILL_SHOWN=0
  [ "$room" -gt 0 ] || return 0
  KUGELBAHN_PILE_WIDTH="$room"
  kugelbahn_pile_fit "$room"
  if [ "$KUGELBAHN_SPILL" -gt "$KUGELBAHN_SPILL_SHOWN" ]; then
    KUGELBAHN_PILE_WIDTH=$(( room - ${#KUGELBAHN_SPILL} - 1 ))
    [ "$KUGELBAHN_PILE_WIDTH" -lt 0 ] && KUGELBAHN_PILE_WIDTH=0
    kugelbahn_pile_fit "$KUGELBAHN_PILE_WIDTH"
    KUGELBAHN_CHIP="+$(( KUGELBAHN_SPILL - KUGELBAHN_SPILL_SHOWN ))"
  fi
  return 0
}

kugelbahn_rest() {
  local x="$1" index gap clearance
  KUGELBAHN_REST=$(( KUGELBAHN_HEIGHT - 1 - KUGELBAHN_BEAD ))
  for (( index = 0; index < KUGELBAHN_SPILL_SHOWN; index++ )); do
    kugelbahn_pile_slot "$index"
    gap=$(( x - KUGELBAHN_SLOT_X ))
    [ "$gap" -lt 0 ] && gap=$(( - gap ))
    [ "$gap" -le 3 ] || continue
    clearance="$KUGELBAHN_BEAD"
    [ "$gap" -eq 3 ] && clearance=$(( KUGELBAHN_BEAD - 1 ))
    [ $(( KUGELBAHN_SLOT_Y - clearance )) -lt "$KUGELBAHN_REST" ] &&
      KUGELBAHN_REST=$(( KUGELBAHN_SLOT_Y - clearance ))
  done
  return 0
}

kugelbahn_roll() {
  local width="$1" start target x
  [ "$KUGELBAHN_FLIGHT" -ge 0 ] && [ "$KUGELBAHN_SETTLED" -ge "$KUGELBAHN_CAPACITY" ] || return 0
  start=$(( - KUGELBAHN_BEAD ))
  target=$(( width - KUGELBAHN_BEAD - 1 ))
  if [ "$KUGELBAHN_SPILL_SHOWN" -eq "$KUGELBAHN_SPILL" ]; then
    kugelbahn_pile_slot "$KUGELBAHN_SPILL_SHOWN"
    [ $(( KUGELBAHN_SLOT_X + KUGELBAHN_BEAD )) -le "$width" ] && target="$KUGELBAHN_SLOT_X"
  fi
  [ "$target" -lt "$start" ] && target="$start"
  x=$(( start + ( ( target - start ) * KUGELBAHN_FLIGHT + 500 ) / 1000 ))
  kugelbahn_rest "$x"
  [ "$KUGELBAHN_REST" -lt 0 ] && KUGELBAHN_REST=0
  kugelbahn_marble "$x" "$KUGELBAHN_REST" ruby -1 .
  return 0
}

kugelbahn_pile_canvas() {
  local origin="$1" width="$KUGELBAHN_PILE_WIDTH" bottom x index newest
  bottom=$(( KUGELBAHN_HEIGHT - 1 ))
  KUGELBAHN_PILE_ROWS=()
  KUGELBAHN_PILE_WIDTHS=()
  [ "$width" -gt 0 ] || return 0
  kugel_canvas "$width" "$KUGELBAHN_HEIGHT"
  for (( x = 0; x < width; x++ )); do
    kugelbahn_bench_tone $(( origin + x ))
    KUGEL_PX[bottom * width + x]="$KUGELBAHN_TONE"
  done
  for (( index = 0; index < KUGELBAHN_SPILL_SHOWN; index++ )); do
    kugelbahn_pile_slot "$index"
    newest=0
    [ "$index" -eq $(( KUGELBAHN_SPILL_SHOWN - 1 )) ] && newest=1
    kugelbahn_look $(( KUGELBAHN_BEADS + index )) "$newest"
    if [ $(( KUGELBAHN_SLOT_Y + KUGELBAHN_BEAD )) -eq "$bottom" ]; then
      KUGEL_PX[bottom * width + KUGELBAHN_SLOT_X + 1]=p
      KUGEL_PX[bottom * width + KUGELBAHN_SLOT_X + 2]=p
    fi
    kugelbahn_marble "$KUGELBAHN_SLOT_X" "$KUGELBAHN_SLOT_Y" "$KUGELBAHN_LOOK" "$KUGELBAHN_SHADE"
  done
  kugelbahn_roll "$width"
  kugel_compose
  KUGELBAHN_PILE_ROWS=("${KUGEL_ROWS[@]}")
  KUGELBAHN_PILE_WIDTHS=("${KUGEL_WIDTHS[@]}")
  return 0
}

kugelbahn_tick() {
  local row="$1" value reached tone mark plain course
  KUGELBAHN_TICK=''
  KUGELBAHN_TICK_WIDTH=0
  if [ "$KUGELBAHN_VARIANT" = COMPACT ]; then
    [ "$row" -eq 1 ] || return 0
    tone=bead_lit
    [ "$KUGELBAHN_JAR" -ge "$KUGELBAHN_CAPACITY" ] && tone=bead_spec
    plain="${KUGELBAHN_JAR}/${KUGELBAHN_CAPACITY}"
    kugelbahn_paint "$tone" "$plain"
    KUGELBAHN_TICK="$KUGELBAHN_PAINT"
    KUGELBAHN_TICK_WIDTH="${#plain}"
    return 0
  fi
  course=$(( KUGELBAHN_COURSES + KUGELBAHN_TICK_TOP - row ))
  [ "$course" -ge 1 ] && [ "$course" -le "$KUGELBAHN_COURSES" ] || return 0
  value=$(( course * KUGELBAHN_PER_COURSE ))
  reached=0
  [ "$KUGELBAHN_JAR" -gt 0 ] && reached=$(( ( KUGELBAHN_JAR + KUGELBAHN_PER_COURSE - 1 ) / KUGELBAHN_PER_COURSE ))
  tone=glass_wall
  mark='┤'
  plain='-'
  if [ "$reached" -eq "$course" ]; then
    tone=bead_hi
    mark='┫'
    plain='>'
  elif [ "$KUGELBAHN_JAR" -ge "$value" ]; then
    tone=bead_lit
    [ "$value" -eq "$KUGELBAHN_CAPACITY" ] && tone=bead_spec
  fi
  [ "$SL_USE_COLOR" = "1" ] || mark="$plain"
  kugelbahn_paint "$tone" "${mark}${value}"
  KUGELBAHN_TICK="$KUGELBAHN_PAINT"
  KUGELBAHN_TICK_WIDTH=$(( 1 + ${#value} ))
  return 0
}

kugelbahn_visible() {
  KUGELBAHN_PART="$1"
  KUGELBAHN_PART_WIDTH="$2"
  if [ "$KUGELBAHN_PART" = "$KUGEL_ZWSP" ]; then
    KUGELBAHN_PART=''
    KUGELBAHN_PART_WIDTH=0
  elif [ "${KUGELBAHN_PART:0:1}" = "$KUGEL_ZWSP" ]; then
    KUGELBAHN_PART="${KUGELBAHN_PART:1}"
    KUGELBAHN_PART_WIDTH=$(( KUGELBAHN_PART_WIDTH - 1 ))
  fi
  return 0
}

kugelbahn_pad() {
  local target="$1"
  while [ "$KUGELBAHN_ROW_WIDTH" -lt "$target" ]; do
    KUGELBAHN_ROW="${KUGELBAHN_ROW} "
    KUGELBAHN_ROW_WIDTH=$(( KUGELBAHN_ROW_WIDTH + 1 ))
  done
  return 0
}

kugelbahn_scene() {
  local row origin bottom chip_style lead shift
  KUGELBAHN_VARIANT="$1"
  local -n art="KUGELBAHN_JAR_${KUGELBAHN_VARIANT}" scale="KUGELBAHN_SCALE_${KUGELBAHN_VARIANT}"
  KUGELBAHN_JAR_WIDTH="${#art[0]}"
  KUGELBAHN_HEIGHT=$(( ${#art[@]} + 1 ))
  KUGELBAHN_SCALE="$scale"
  origin=$(( KUGELBAHN_JAR_WIDTH + KUGELBAHN_SCALE ))

  KUGELBAHN_FRESH=0
  if [ "$KUGELBAHN_LANDED" -gt 0 ] &&
     [ $(( SL_NOW - KUGELBAHN_LANDED )) -ge 0 ] &&
     [ $(( SL_NOW - KUGELBAHN_LANDED )) -lt "$KUGELBAHN_FRESH_SECONDS" ]; then
    KUGELBAHN_FRESH=1
  fi
  kugelbahn_beads "$KUGELBAHN_JAR"
  kugelbahn_pile_layout $(( SL_COLUMNS - origin ))
  kugelbahn_dull_plan
  kugelbahn_jar_canvas
  kugelbahn_pile_canvas "$origin"
  bottom=$(( ${#KUGELBAHN_JAR_ROWS[@]} - 1 ))

  for (( row = 0; row <= bottom; row++ )); do
    kugelbahn_visible "${KUGELBAHN_JAR_ROWS[row]}" "${KUGELBAHN_JAR_WIDTHS[row]}"
    lead=''
    shift=0
    case "$KUGELBAHN_PART" in
      '' | ' '*)
        lead="$SL_RESET"
        if [ "$SL_USE_COLOR" != "1" ]; then
          lead="$KUGEL_ZWSP"
          shift=1
        fi
        ;;
    esac
    KUGELBAHN_ROW="${lead}${KUGELBAHN_PART}"
    KUGELBAHN_ROW_WIDTH=$(( shift + KUGELBAHN_PART_WIDTH ))
    origin=$(( shift + KUGELBAHN_JAR_WIDTH + KUGELBAHN_SCALE ))
    kugelbahn_tick "$row"
    if [ -n "$KUGELBAHN_TICK" ]; then
      kugelbahn_pad $(( shift + KUGELBAHN_JAR_WIDTH ))
      KUGELBAHN_ROW="${KUGELBAHN_ROW}${KUGELBAHN_TICK}${SL_RESET}"
      KUGELBAHN_ROW_WIDTH=$(( KUGELBAHN_ROW_WIDTH + KUGELBAHN_TICK_WIDTH ))
    fi
    kugelbahn_visible "${KUGELBAHN_PILE_ROWS[row]:-}" "${KUGELBAHN_PILE_WIDTHS[row]:-0}"
    if [ -n "$KUGELBAHN_PART" ]; then
      kugelbahn_pad "$origin"
      KUGELBAHN_ROW="${KUGELBAHN_ROW}${KUGELBAHN_PART}"
      KUGELBAHN_ROW_WIDTH=$(( KUGELBAHN_ROW_WIDTH + KUGELBAHN_PART_WIDTH ))
    fi
    if [ "$row" -eq "$bottom" ] && [ -n "$KUGELBAHN_CHIP" ]; then
      kugelbahn_style bead_hi wood_shadow
      chip_style="$KUGELBAHN_STYLE"
      KUGELBAHN_ROW="${KUGELBAHN_ROW}${chip_style}${KUGELBAHN_CHIP}${SL_RESET}"
      KUGELBAHN_ROW_WIDTH=$(( KUGELBAHN_ROW_WIDTH + ${#KUGELBAHN_CHIP} ))
    fi
    sl_emit_sized "$KUGELBAHN_ROW" "$KUGELBAHN_ROW_WIDTH"
  done
  return 0
}
# ---------------------------------------------------------------- the readout

kugelbahn_count_text() {
  local text
  if [ "$KUGELBAHN_SPILL" -gt 0 ]; then
    text="${KUGELBAHN_CAPACITY}/${KUGELBAHN_CAPACITY}+${KUGELBAHN_SPILL}"
  else
    text="${KUGELBAHN_JAR}/${KUGELBAHN_CAPACITY}"
  fi
  [ "$KUGELBAHN_PENDING" -gt 0 ] && text="${text}▸${KUGELBAHN_PENDING}"
  sl_width "$text"
  KUGELBAHN_COUNT_WIDTH="$SL_W"
  while [ "$KUGELBAHN_COUNT_WIDTH" -lt "$KUGELBAHN_COUNT_FIELD" ]; do
    text="${text} "
    KUGELBAHN_COUNT_WIDTH=$(( KUGELBAHN_COUNT_WIDTH + 1 ))
  done
  KUGELBAHN_COUNT_TEXT="$text"
  KUGELBAHN_FAIL_TEXT=''
  KUGELBAHN_FAIL_WIDTH=0
  if [ "$KUGELBAHN_FAILED" -gt 0 ]; then
    KUGELBAHN_FAIL_TEXT="✗${KUGELBAHN_FAILED}"
    sl_width "$KUGELBAHN_FAIL_TEXT"
    KUGELBAHN_FAIL_WIDTH="$SL_W"
  fi
  return 0
}

kugelbahn_context() {
  KUGELBAHN_CONTEXT_TEXT=''
  KUGELBAHN_CONTEXT_TONE=text_good
  sl_is_number "${SL_CONTEXT_PERCENT:-}" || return 0
  KUGELBAHN_CONTEXT_TEXT="ctx ${SL_CONTEXT_PERCENT}%"
  [ "$SL_CONTEXT_PERCENT" -ge 60 ] && KUGELBAHN_CONTEXT_TONE=text_caution
  [ "$SL_CONTEXT_PERCENT" -ge 85 ] && KUGELBAHN_CONTEXT_TONE=text_warn
  return 0
}

kugelbahn_join() {
  local width="$1" text="$2"
  if [ "$KUGELBAHN_LINE_WIDTH" -gt 0 ]; then
    kugelbahn_paint text_faint ' · '
    KUGELBAHN_LINE="${KUGELBAHN_LINE}${KUGELBAHN_PAINT}${text}"
    KUGELBAHN_LINE_WIDTH=$(( KUGELBAHN_LINE_WIDTH + width + 3 ))
    return 0
  fi
  KUGELBAHN_LINE="${KUGELBAHN_LINE}${text}"
  KUGELBAHN_LINE_WIDTH=$(( KUGELBAHN_LINE_WIDTH + width ))
  return 0
}

kugelbahn_readout() {
  local budget="$1" room branch_width context_width cost_width model_width effort_width
  local take_fail=0 take_branch=0 take_cost=0 take_context=0 take_model=0 take_effort=0
  local path_room

  kugelbahn_count_text
  kugelbahn_context

  branch_width=0
  if [ -n "${SL_GIT_BRANCH:-}" ]; then
    sl_trunc "$SL_GIT_BRANCH" "$KUGELBAHN_BRANCH_MAX"
    KUGELBAHN_BRANCH_TEXT="$SL_TRUNC"
    sl_width "$KUGELBAHN_BRANCH_TEXT"
    branch_width=$(( SL_W + 2 ))
  else
    KUGELBAHN_BRANCH_TEXT=''
  fi
  context_width="${#KUGELBAHN_CONTEXT_TEXT}"
  cost_width=0
  [ -n "${SL_COST_TEXT:-}" ] && cost_width="${#SL_COST_TEXT}"
  model_width=0
  if [ -n "${SL_MODEL_SHORT:-}" ]; then
    sl_width "$SL_MODEL_SHORT"
    model_width="$SL_W"
  fi
  effort_width=0
  [ -n "${SL_EFFORT:-}" ] && effort_width=$(( ${#SL_EFFORT} + 1 ))

  room=$(( budget - KUGELBAHN_COUNT_WIDTH - KUGELBAHN_PATH_FLOOR - 3 ))
  if [ "$KUGELBAHN_FAIL_WIDTH" -gt 0 ] && [ "$room" -ge $(( KUGELBAHN_FAIL_WIDTH + 3 )) ]; then
    take_fail=1
    room=$(( room - KUGELBAHN_FAIL_WIDTH - 3 ))
  fi
  if [ "$branch_width" -gt 0 ] && [ "$room" -ge $(( branch_width + 3 )) ]; then
    take_branch=1
    room=$(( room - branch_width - 3 ))
  fi
  if [ "$cost_width" -gt 0 ] && [ "$room" -ge $(( cost_width + 3 )) ]; then
    take_cost=1
    room=$(( room - cost_width - 3 ))
  fi
  if [ "$context_width" -gt 0 ] && [ "$room" -ge $(( context_width + 3 )) ]; then
    take_context=1
    room=$(( room - context_width - 3 ))
  fi
  if [ "$model_width" -gt 0 ] && [ "$room" -ge $(( model_width + 3 )) ]; then
    take_model=1
    room=$(( room - model_width - 3 ))
  fi
  if [ "$effort_width" -gt 0 ] && [ "$room" -ge $(( effort_width + 3 )) ]; then
    take_effort=1
    room=$(( room - effort_width - 3 ))
  fi

  path_room=$(( KUGELBAHN_PATH_FLOOR + room ))
  [ "$path_room" -lt 4 ] && path_room=4
  sl_path_fit "$path_room"
  case "$SL_PATH_FIT" in
    *…*…*)
      sl_trunc "${SL_PATH##*/}" "$path_room"
      SL_PATH_FIT="$SL_TRUNC"
      ;;
  esac

  KUGELBAHN_LINE=''
  KUGELBAHN_LINE_WIDTH=0
  kugelbahn_paint text_count "$KUGELBAHN_COUNT_TEXT"
  kugelbahn_join "$KUGELBAHN_COUNT_WIDTH" "$KUGELBAHN_PAINT"
  if [ "$take_fail" -eq 1 ]; then
    kugelbahn_paint dead_lit "$KUGELBAHN_FAIL_TEXT"
    kugelbahn_join "$KUGELBAHN_FAIL_WIDTH" "$KUGELBAHN_PAINT"
  fi
  sl_width "$SL_PATH_FIT"
  kugelbahn_paint text_path "$SL_PATH_FIT"
  kugelbahn_join "$SL_W" "$KUGELBAHN_PAINT"
  if [ "$take_branch" -eq 1 ]; then
    kugelbahn_paint text_branch "⎇ $KUGELBAHN_BRANCH_TEXT"
    kugelbahn_join "$branch_width" "$KUGELBAHN_PAINT"
  fi
  if [ "$take_context" -eq 1 ]; then
    kugelbahn_paint "$KUGELBAHN_CONTEXT_TONE" "$KUGELBAHN_CONTEXT_TEXT"
    kugelbahn_join "$context_width" "$KUGELBAHN_PAINT"
  fi
  if [ "$take_cost" -eq 1 ]; then
    kugelbahn_paint text_cost "$SL_COST_TEXT"
    kugelbahn_join "$cost_width" "$KUGELBAHN_PAINT"
  fi
  if [ "$take_model" -eq 1 ]; then
    kugelbahn_paint text_model "$SL_MODEL_SHORT"
    kugelbahn_join "$model_width" "$KUGELBAHN_PAINT"
  fi
  if [ "$take_effort" -eq 1 ]; then
    kugelbahn_paint text_faint "✦$SL_EFFORT"
    kugelbahn_join "$effort_width" "$KUGELBAHN_PAINT"
  fi
  KUGELBAHN_LINE="${KUGELBAHN_LINE}${SL_RESET}"
  return 0
}

# ------------------------------------------------------------ the small tiers

kugelbahn_text_tier() {
  local budget="$1"
  kugelbahn_count_text
  kugelbahn_context

  KUGELBAHN_LINE=''
  KUGELBAHN_LINE_WIDTH=0
  kugelbahn_paint text_count "$KUGELBAHN_COUNT_TEXT"
  kugelbahn_join "$KUGELBAHN_COUNT_WIDTH" "$KUGELBAHN_PAINT"
  if [ $(( budget - KUGELBAHN_LINE_WIDTH - 3 )) -ge 4 ]; then
    sl_path_fit $(( budget - KUGELBAHN_LINE_WIDTH - 3 ))
    case "$SL_PATH_FIT" in
      *…*…*) SL_PATH_FIT="${SL_PATH##*/}" ;;
    esac
    sl_width "$SL_PATH_FIT"
    if [ $(( KUGELBAHN_LINE_WIDTH + SL_W + 3 )) -le "$budget" ]; then
      kugelbahn_paint text_path "$SL_PATH_FIT"
      kugelbahn_join "$SL_W" "$KUGELBAHN_PAINT"
    fi
  fi
  KUGELBAHN_TEXT_TOP="${KUGELBAHN_LINE}${SL_RESET}"

  KUGELBAHN_LINE=''
  KUGELBAHN_LINE_WIDTH=0
  if [ -n "$KUGELBAHN_CONTEXT_TEXT" ] &&
     [ $(( ${#KUGELBAHN_CONTEXT_TEXT} )) -le "$budget" ]; then
    kugelbahn_paint "$KUGELBAHN_CONTEXT_TONE" "$KUGELBAHN_CONTEXT_TEXT"
    kugelbahn_join "${#KUGELBAHN_CONTEXT_TEXT}" "$KUGELBAHN_PAINT"
  fi
  if [ -n "${SL_COST_TEXT:-}" ] &&
     [ $(( KUGELBAHN_LINE_WIDTH + ${#SL_COST_TEXT} + 3 )) -le "$budget" ]; then
    kugelbahn_paint text_cost "$SL_COST_TEXT"
    kugelbahn_join "${#SL_COST_TEXT}" "$KUGELBAHN_PAINT"
  fi
  if [ -n "${SL_MODEL_SHORT:-}" ]; then
    sl_width "$SL_MODEL_SHORT"
    if [ $(( KUGELBAHN_LINE_WIDTH + SL_W + 3 )) -le "$budget" ]; then
      kugelbahn_paint text_model "$SL_MODEL_SHORT"
      kugelbahn_join "$SL_W" "$KUGELBAHN_PAINT"
    fi
  fi
  if [ "$KUGELBAHN_LINE_WIDTH" -eq 0 ]; then
    kugelbahn_paint text_faint '·'
    kugelbahn_join 1 "$KUGELBAHN_PAINT"
  fi
  KUGELBAHN_TEXT_BOTTOM="${KUGELBAHN_LINE}${SL_RESET}"
  return 0
}

# ---------------------------------------------------------------- the scene

sl_render() {
  kugelbahn_ledger

  if [ "$SL_TERM_COLUMNS" -lt "$KUGELBAHN_TIER_GAUGE_COLUMNS" ]; then
    kugelbahn_text_tier "$SL_COLUMNS"
    sl_emit "$KUGELBAHN_TEXT_TOP"
    sl_emit "$KUGELBAHN_TEXT_BOTTOM"
    return 0
  fi

  sl_git
  KUGELBAHN_SPILL_SHOWN=0
  if [ "$SL_TERM_COLUMNS" -lt "$KUGELBAHN_TIER_JAR_COLUMNS" ]; then
    kugelbahn_scene COMPACT
  else
    kugelbahn_scene FULL
  fi

  kugelbahn_readout "$SL_COLUMNS"
  sl_emit "$KUGELBAHN_LINE"
  return 0
}
