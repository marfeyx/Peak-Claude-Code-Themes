#!/usr/bin/env bash
# Shared data layer for the switchable Claude Code statusline.
#
# Sourced by statusline.sh before the selected theme. Parses the payload once,
# exposes it as SL_* variables, and provides layout helpers so a theme only has
# to decide what it looks like, never how to get the numbers.
#
# Expensive work (git, gateway budget, transcript token scan) is lazy: it only
# runs when a theme calls the matching sl_* getter, so cheap themes stay cheap.
#
# The contract is documented in README.md. Do not break it without updating
# every theme in themes/.

set -u

case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
  *UTF-8* | *utf-8* | *UTF8* | *utf8*) ;;
  *)
    if locale -a 2>/dev/null | grep -qix 'C.UTF-8\|C.utf8'; then
      export LC_ALL=C.UTF-8
    else
      export LC_ALL=en_US.UTF-8
    fi
    ;;
esac

SL_HOME="${SL_HOME:-${HOME:-/tmp}/.claude/statusline}"
SL_BUILD_CLI="${SL_BUILD_CLI:-}"
if [ -z "$SL_BUILD_CLI" ]; then
  SL_BUILD_CLI="$(command -v build-cli 2>/dev/null || true)"
  [ -n "$SL_BUILD_CLI" ] || SL_BUILD_CLI="${HOME:-/nonexistent}/.local/bin/build-cli"
fi
SL_FALLBACK_COLUMNS=100
SL_SAFETY_MARGIN=4
SL_GIT_CACHE_SECONDS=4
SL_GIT_TIMEOUT_SECONDS=2
SL_GATEWAY_CACHE_SECONDS=90
SL_GATEWAY_FORCE_REFRESH=1
SL_TOKEN_SCAN_BUDGET=1500000
SL_TOKEN_STATE_VERSION=4
SL_TOKEN_COUNT_CACHE_READS=0
SL_CACHE_PRUNE_MINUTES=10080

SL_ESC=$'\033'
SL_RESET="${SL_ESC}[0m"

printf -v SL_NOW '%(%s)T' -1
if [ -n "${EPOCHREALTIME:-}" ]; then
  SL_TICK=$(( ${EPOCHREALTIME/./} / 10000 ))
else
  SL_TICK=$(( SL_NOW * 100 ))
fi

case "${SL_FAKE_NOW:-}" in
  ''|*[!0-9]*) ;;
  *) SL_NOW="$SL_FAKE_NOW"; SL_TICK=$(( SL_NOW * 100 )) ;;
esac
case "${SL_FAKE_TICK:-}" in
  ''|*[!0-9]*) ;;
  *) SL_TICK="$SL_FAKE_TICK"; SL_NOW=$(( SL_TICK / 100 )) ;;
esac

SL_TERM_COLUMNS="${COLUMNS:-}"
case "$SL_TERM_COLUMNS" in
  ''|*[!0-9]*) SL_TERM_COLUMNS="$SL_FALLBACK_COLUMNS" ;;
esac
[ "$SL_TERM_COLUMNS" -lt 1 ] && SL_TERM_COLUMNS="$SL_FALLBACK_COLUMNS"
SL_COLUMNS=$(( SL_TERM_COLUMNS - SL_SAFETY_MARGIN ))
[ "$SL_COLUMNS" -lt 4 ] && SL_COLUMNS=4

SL_USE_COLOR=1
if [ -n "${NO_COLOR:-}" ]; then
  SL_USE_COLOR=0
  SL_RESET=""
fi

sl_is_number() {
  case "${1:-}" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

declare -gA SL_CHAR_WIDTH=()

sl_width() {
  local text="$1" total=0 position code char
  case "$text" in
    *[!$'\x20'-$'\x7e']*) ;;
    *) SL_W="${#text}"; return ;;
  esac
  if [ "${#text}" = "1" ] && [ -n "${SL_CHAR_WIDTH[$text]:-}" ]; then
    SL_W="${SL_CHAR_WIDTH[$text]}"
    return
  fi
  for (( position = 0; position < ${#text}; position++ )); do
    char="${text:position:1}"
    printf -v code '%d' "'$char" 2>/dev/null || code=63
    if (( code >= 4352 && ( code <= 4447 \
         || (code >= 11904 && code <= 42191) \
         || (code >= 44032 && code <= 55203) \
         || (code >= 63744 && code <= 64255) \
         || (code >= 65040 && code <= 65071) \
         || (code >= 65280 && code <= 65376) \
         || (code >= 65504 && code <= 65510) \
         || (code >= 127744 && code <= 129791) \
         || (code >= 131072 && code <= 262141) ) )); then
      total=$(( total + 2 ))
    elif (( (code >= 768 && code <= 879) || (code >= 65024 && code <= 65039) || code == 8205 )); then
      :
    else
      total=$(( total + 1 ))
    fi
  done
  SL_W="$total"
  [ "${#text}" = "1" ] && SL_CHAR_WIDTH["$text"]="$total"
  return 0
}

sl_trunc() {
  local text="$1" limit="$2" keep
  sl_width "$text"
  if [ "$SL_W" -le "$limit" ]; then
    SL_TRUNC="$text"
    return
  fi
  if [ "$limit" -lt 1 ]; then
    SL_TRUNC=""
    return
  fi
  keep="${#text}"
  while [ "$keep" -gt 0 ]; do
    keep=$(( keep - 1 ))
    sl_width "${text:0:keep}"
    [ "$SL_W" -le $(( limit - 1 )) ] && break
  done
  SL_TRUNC="${text:0:keep}…"
}

sl_clip() {
  local text="$1" limit="${2:-$SL_COLUMNS}" position=0 length="${#text}" char next
  local visible=0 output="" had_escape=0 sequence
  case "$text" in
    *"$SL_ESC"*) had_escape=1 ;;
    *)
      sl_width "$text"
      if [ "$SL_W" -le "$limit" ]; then SL_CLIP="$text"; return; fi
      ;;
  esac
  while [ "$position" -lt "$length" ]; do
    char="${text:position:1}"
    if [ "$char" = "$SL_ESC" ]; then
      sequence="$char"
      position=$(( position + 1 ))
      next="${text:position:1}"
      if [ "$next" = "[" ]; then
        sequence="$sequence["
        position=$(( position + 1 ))
        while [ "$position" -lt "$length" ]; do
          next="${text:position:1}"
          sequence="$sequence$next"
          position=$(( position + 1 ))
          case "$next" in
            [a-zA-Z]) break ;;
          esac
        done
      fi
      output="$output$sequence"
      continue
    fi
    sl_width "$char"
    if [ $(( visible + SL_W )) -gt "$limit" ]; then
      output="${output%"${output##*[![:space:]]}"}"
      [ "$had_escape" = "1" ] && output="$output$SL_RESET"
      SL_CLIP="$output"
      return
    fi
    visible=$(( visible + SL_W ))
    output="$output$char"
    position=$(( position + 1 ))
  done
  SL_CLIP="$output"
}

sl_abbrev() {
  local value="${1:-0}"
  sl_is_number "$value" || value=0
  if [ "$value" -ge 1000000 ]; then
    printf -v SL_ABBREV '%d.%dM' $(( value / 1000000 )) $(( (value % 1000000) / 100000 ))
  elif [ "$value" -ge 1000 ]; then
    printf -v SL_ABBREV '%dk' $(( value / 1000 ))
  else
    SL_ABBREV="$value"
  fi
}

sl_group() {
  local digits="${1:-0}" grouped="" count=0 position separator="${2:-.}"
  for (( position = ${#digits} - 1; position >= 0; position-- )); do
    grouped="${digits:position:1}$grouped"
    count=$(( count + 1 ))
    [ $(( count % 3 )) -eq 0 ] && [ "$position" -gt 0 ] && grouped="$separator$grouped"
  done
  SL_GROUP="$grouped"
}

sl_duration() {
  local milliseconds="${1:-0}" seconds minutes hours
  sl_is_number "$milliseconds" || milliseconds=0
  seconds=$(( milliseconds / 1000 ))
  hours=$(( seconds / 3600 ))
  minutes=$(( (seconds % 3600) / 60 ))
  if [ "$hours" -gt 0 ]; then
    printf -v SL_DURATION '%dh%02dm' "$hours" "$minutes"
  elif [ "$minutes" -gt 0 ]; then
    printf -v SL_DURATION '%dm%02ds' "$minutes" $(( seconds % 60 ))
  else
    printf -v SL_DURATION '%ds' "$seconds"
  fi
}

sl_fg256() { [ "$SL_USE_COLOR" = "1" ] && printf '%s[38;5;%sm' "$SL_ESC" "$1"; }
sl_bg256() { [ "$SL_USE_COLOR" = "1" ] && printf '%s[48;5;%sm' "$SL_ESC" "$1"; }
sl_fg()    { [ "$SL_USE_COLOR" = "1" ] && printf '%s[38;2;%s;%s;%sm' "$SL_ESC" "$1" "$2" "$3"; }
sl_bg()    { [ "$SL_USE_COLOR" = "1" ] && printf '%s[48;2;%s;%s;%sm' "$SL_ESC" "$1" "$2" "$3"; }
sl_bold()  { [ "$SL_USE_COLOR" = "1" ] && printf '%s[1m' "$SL_ESC"; }
sl_dim()   { [ "$SL_USE_COLOR" = "1" ] && printf '%s[2m' "$SL_ESC"; }

SL_COS_QUARTER=(1000 1000 1000 1000 1000 1000 999 999 999 998 998 998 997 997 996 996 995 995 994 993 992 992 991
  990 989 988 987 986 985 984 983 982 981 980 978 977 976 974 973 972 970 969 967 965 964 962 960 959 957 955
  953 951 950 948 946 944 942 939 937 935 933 931 929 926 924 922 919 917 914 912 909 907 904 901 899 896 893
  890 888 885 882 879 876 873 870 867 864 861 858 855 851 848 845 842 838 835 831 828 825 821 818 814 810 807
  803 800 796 792 788 785 781 777 773 769 765 761 757 753 749 745 741 737 733 728 724 720 716 711 707 703 698
  694 690 685 681 676 672 667 662 658 653 649 644 639 634 630 625 620 615 610 606 601 596 591 586 581 576 571
  566 561 556 550 545 540 535 530 525 519 514 509 504 498 493 488 482 477 471 466 461 455 450 444 439 433 428
  422 416 411 405 400 394 388 383 377 371 366 360 354 348 343 337 331 325 320 314 308 302 296 290 284 279 273
  267 261 255 249 243 237 231 225 219 213 207 201 195 189 183 177 171 165 159 153 147 141 135 128 122 116 110
  104 98 92 86 80 74 67 61 55 49 43 37 31 25 18 12 6)

sl_cos() {
  local index=$(( $1 & 1023 ))
  case "$(( index / 256 ))" in
    0) SL_COS=$(( SL_COS_QUARTER[index] )) ;;
    1) SL_COS=$(( -SL_COS_QUARTER[511 - index] )) ;;
    2) SL_COS=$(( -SL_COS_QUARTER[index - 512] )) ;;
    *) SL_COS=$(( SL_COS_QUARTER[1023 - index] )) ;;
  esac
}

sl_palette() {
  local turn="$1"
  local base_red="$2" base_green="$3" base_blue="$4"
  local amplitude_red="$5" amplitude_green="$6" amplitude_blue="$7"
  local offset_red="$8" offset_green="$9" offset_blue="${10}"
  sl_cos $(( turn + offset_red ))
  SL_R=$(( (base_red * 1000 + amplitude_red * SL_COS) * 255 / 1000000 ))
  sl_cos $(( turn + offset_green ))
  SL_G=$(( (base_green * 1000 + amplitude_green * SL_COS) * 255 / 1000000 ))
  sl_cos $(( turn + offset_blue ))
  SL_B=$(( (base_blue * 1000 + amplitude_blue * SL_COS) * 255 / 1000000 ))
  [ "$SL_R" -lt 0 ] && SL_R=0
  [ "$SL_R" -gt 255 ] && SL_R=255
  [ "$SL_G" -lt 0 ] && SL_G=0
  [ "$SL_G" -gt 255 ] && SL_G=255
  [ "$SL_B" -lt 0 ] && SL_B=0
  [ "$SL_B" -gt 255 ] && SL_B=255
}

SL_HUE_RED=(255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255
  255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 254 252 250 248
  246 244 242 240 238 236 235 233 231 229 227 225 223 221 219 217 215 213 210 208 206 204 201 199 197 194 192
  189 186 183 180 177 174 170 167 163 159 155 150 145 140 134 127 120 112 103 92 78 60 27 0 0 0 0 0 0 0 0 0 0 0
  0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 21 41 53 63 70
  77 83 88 93 98 102 106 109 112 116 119 122 124 127 130 132 135 137 139 141 143 146 148 150 152 154 156 158 159
  161 163 165 167 169 171 172 174 176 178 180 182 184 186 188 190 192 194 196 198 200 202 205 207 209 212 214
  217 220 223 226 229 232 235 239 243 247 251 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255
  255 255 255 255 255 255 255)
SL_HUE_GREEN=(143 144 144 144 145 145 146 146 146 147 147 147 148 148 148 149 149 149 149 150 150 150 151 151
  151 151 152 152 152 152 153 153 153 154 154 154 154 155 155 155 155 156 156 156 157 157 157 158 158 160 161
  162 164 165 166 167 169 170 171 172 173 174 175 176 177 178 179 180 181 182 183 184 185 186 187 188 189 190
  191 192 193 194 195 197 198 199 200 201 202 203 205 206 207 209 210 211 213 214 216 218 219 221 222 221 221
  220 220 219 219 218 218 218 217 217 217 216 216 216 215 215 215 214 214 214 213 213 213 212 212 212 212 211
  211 211 211 210 210 210 209 209 209 209 208 208 208 207 207 207 206 206 206 205 205 205 204 204 204 203 203
  202 202 201 200 199 199 198 197 196 195 195 194 193 193 192 191 191 190 189 189 188 187 187 186 185 185 184
  184 183 182 182 181 180 180 179 179 178 177 177 176 175 175 174 173 172 172 171 170 169 168 167 167 166 165
  164 163 161 160 159 158 156 155 154 152 150 148 146 144 142 139 137 133 130 126 123 124 126 128 129 130 131
  132 133 134 135 136 137 138 138 139 140 140 141 141 142 142 143)
SL_HUE_BLUE=(180 177 175 173 171 169 166 164 162 160 158 156 154 152 149 147 145 143 141 139 137 134 132 130 127
  125 123 120 117 115 112 109 106 103 100 97 93 90 86 81 77 72 67 60 53 45 34 18 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
  0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 37 60 75 87 97 105 112 119 125 130
  135 140 144 148 152 156 159 162 165 168 171 174 177 179 182 184 187 189 191 194 196 198 200 202 204 206 208
  210 212 214 216 218 220 222 224 226 228 230 232 234 236 238 240 243 245 247 249 252 254 255 255 255 255 255
  255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255
  255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255
  255 255 255 255 255 255 255 255 255 255 255 255 255 254 249 245 240 236 232 228 224 221 218 214 211 208 205
  202 200 197 194 192 189 187 184 182)

sl_hue() {
  local index=$(( $1 & 255 ))
  SL_R=$(( SL_HUE_RED[index] ))
  SL_G=$(( SL_HUE_GREEN[index] ))
  SL_B=$(( SL_HUE_BLUE[index] ))
}

sl_phase() {
  local cycle_seconds="${1:-90}"
  [ "$cycle_seconds" -gt 0 ] || { SL_PHASE=0; return; }
  SL_PHASE=$(( SL_TICK * 1024 / (cycle_seconds * 100) % 1024 ))
}

sl_rule() {
  local width="${1:-$SL_COLUMNS}" glyph="${2:-─}" cycle="${3:-90}" column turn output=""
  if [ "$SL_USE_COLOR" != "1" ]; then
    printf -v SL_RULE '%*s' "$width" ''
    SL_RULE="${SL_RULE// /$glyph}"
    return
  fi
  [ "$width" -gt 0 ] || { SL_RULE=""; return; }
  sl_phase "$cycle"
  for (( column = 0; column < width; column++ )); do
    turn=$(( column * 256 / width + SL_PHASE / 4 ))
    sl_hue "$turn"
    output="$output${SL_ESC}[38;2;${SL_R};${SL_G};${SL_B}m$glyph"
  done
  SL_RULE="$output$SL_RESET"
}

sl_bar() {
  local percent="${1:-0}" width="${2:-12}" filled_glyph="${3:-▰}" empty_glyph="${4:-▱}"
  local whole="${percent%%.*}" filled index
  sl_is_number "${whole:-}" || whole=0
  filled=$(( whole * width / 100 ))
  [ "$filled" -gt "$width" ] && filled="$width"
  [ "$filled" -lt 0 ] && filled=0
  if [ "$filled" -eq 0 ] && [ "$whole" -gt 0 ]; then
    filled=1
  fi
  SL_BAR_FILLED="$filled"
  SL_BAR_WIDTH="$width"
  SL_BAR=""
  for (( index = 0; index < width; index++ )); do
    if [ "$index" -lt "$filled" ]; then
      SL_BAR="$SL_BAR$filled_glyph"
    else
      SL_BAR="$SL_BAR$empty_glyph"
    fi
  done
}

sl_home_relative() {
  case "$1" in
    "${HOME:-/nonexistent}"/*|"${HOME:-/nonexistent}") printf -v SL_HOME_RELATIVE '~%s' "${1#"${HOME:-}"}" ;;
    *) SL_HOME_RELATIVE="$1" ;;
  esac
}

sl_path_tail() {
  local keep_count="${1:-2}" source_path="${2:-$SL_PATH}" index total assembled
  local -a parts=()
  local IFS='/'
  read -ra parts <<< "$source_path"
  total="${#parts[@]}"
  if [ "$total" -le "$keep_count" ]; then
    SL_PATH_TAIL="$source_path"
    return
  fi
  assembled=""
  for (( index = total - keep_count; index < total; index++ )); do
    assembled="$assembled/${parts[index]}"
  done
  SL_PATH_TAIL="…$assembled"
}

sl_path_fit() {
  local limit="${1:-$SL_COLUMNS}" variant
  sl_path_tail 3; local three="$SL_PATH_TAIL"
  sl_path_tail 2; local two="$SL_PATH_TAIL"
  sl_path_tail 1; local one="$SL_PATH_TAIL"
  for variant in "$SL_PATH" "$three" "$two" "$one"; do
    sl_width "$variant"
    if [ "$SL_W" -le "$limit" ]; then
      SL_PATH_FIT="$variant"
      return
    fi
  done
  sl_trunc "$one" "$limit"
  SL_PATH_FIT="$SL_TRUNC"
}

SL_CACHE_DIR="${TMPDIR:-/tmp}/claude-statusline-$(id -u 2>/dev/null || echo 0)"
if [ -d "$SL_CACHE_DIR" ] && [ ! -L "$SL_CACHE_DIR" ] && [ -O "$SL_CACHE_DIR" ]; then
  :
elif [ -e "$SL_CACHE_DIR" ]; then
  SL_CACHE_DIR="$(mktemp -d 2>/dev/null)" || SL_CACHE_DIR=""
else
  mkdir -m 700 -p "$SL_CACHE_DIR" 2>/dev/null
fi
[ -n "$SL_CACHE_DIR" ] && chmod 700 "$SL_CACHE_DIR" 2>/dev/null

sl_cache_key() {
  SL_CACHE_KEY="$1"
  if [ "${#SL_CACHE_KEY}" -gt 180 ]; then
    SL_CACHE_KEY="${SL_CACHE_KEY:0:40}_${#SL_CACHE_KEY}_${SL_CACHE_KEY: -120}"
  fi
}

sl_cache_read() {
  [ -n "$SL_CACHE_DIR" ] || return 1
  sl_cache_key "$1"
  local cache_file="$SL_CACHE_DIR/$SL_CACHE_KEY" cache_stamp cache_age
  [ -f "$cache_file" ] || return 1
  cache_stamp=$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)
  cache_age=$(( SL_NOW - cache_stamp ))
  [ "$cache_age" -ge 0 ] && [ "$cache_age" -lt "$2" ] || return 1
  cat "$cache_file"
}

sl_cache_write() {
  [ -n "$SL_CACHE_DIR" ] || return 0
  sl_cache_key "$1"
  local cache_temp="$SL_CACHE_DIR/.$SL_CACHE_KEY.$$"
  rm -f "$cache_temp" 2>/dev/null
  if 2>/dev/null printf '%s' "$2" > "$cache_temp"; then
    mv -f "$cache_temp" "$SL_CACHE_DIR/$SL_CACHE_KEY" 2>/dev/null || rm -f "$cache_temp" 2>/dev/null
  fi
}

SL_STATE_DIR="${HOME:-/tmp}/.claude/statusline-state"
if [ ! -d "$SL_STATE_DIR" ]; then
  mkdir -m 700 -p "$SL_STATE_DIR" 2>/dev/null
fi
[ -d "$SL_STATE_DIR" ] && [ -w "$SL_STATE_DIR" ] || SL_STATE_DIR="$SL_CACHE_DIR"

sl_state_path() {
  sl_cache_key "$1"
  SL_STATE_FILE="$SL_STATE_DIR/$SL_CACHE_KEY"
}

sl_parse_payload() {
  local payload="$1" key value
  declare -gA SL_FIELD=()
  while IFS=$'\t' read -r key value; do
    [ -n "$key" ] || continue
    SL_FIELD["$key"]="$value"
  done < <(printf '%s' "$payload" | awk '
  function get_block(key,   pattern, start, depth, index_position, character, in_string, escaped) {
    pattern = "\"" key "\"[ \t]*:[ \t]*\\{"
    if (!match(document, pattern)) { return "" }
    start = RSTART + RLENGTH - 1
    depth = 0; in_string = 0; escaped = 0
    for (index_position = start; index_position <= length(document); index_position++) {
      character = substr(document, index_position, 1)
      if (in_string) {
        if (escaped) { escaped = 0 }
        else if (character == "\\") { escaped = 1 }
        else if (character == "\"") { in_string = 0 }
      } else if (character == "\"") { in_string = 1 }
      else if (character == "{") { depth++ }
      else if (character == "}") {
        depth--
        if (depth == 0) { return substr(document, start, index_position - start + 1) }
      }
    }
    return ""
  }
  function get_string(scope, key,   pattern, value) {
    pattern = "\"" key "\"[ \t]*:[ \t]*\"[^\"]*\""
    if (match(scope, pattern)) {
      value = substr(scope, RSTART, RLENGTH)
      sub("^\"" key "\"[ \t]*:[ \t]*\"", "", value)
      sub("\"$", "", value)
      return value
    }
    return ""
  }
  function get_number(scope, key,   pattern, value) {
    pattern = "\"" key "\"[ \t]*:[ \t]*-?[0-9]+(\\.[0-9]+)?([eE][-+]?[0-9]+)?"
    if (match(scope, pattern)) {
      value = substr(scope, RSTART, RLENGTH)
      sub(".*:[ \t]*", "", value)
      return value
    }
    return ""
  }
  function get_bool(scope, key,   pattern, value) {
    pattern = "\"" key "\"[ \t]*:[ \t]*(true|false)"
    if (match(scope, pattern)) {
      value = substr(scope, RSTART, RLENGTH)
      sub(".*:[ \t]*", "", value)
      return (value == "true") ? "1" : "0"
    }
    return ""
  }
  function emit(key, value) {
    gsub(/[\t\r\n]/, " ", value)
    if (value != "") { printf "%s\t%s\n", key, value }
  }
  { document = document $0 }
  END {
    model = get_block("model")
    workspace = get_block("workspace")
    repo = get_block("repo")
    cost = get_block("cost")
    context = get_block("context_window")
    effort = get_block("effort")
    style = get_block("output_style")
    thinking = get_block("thinking")

    emit("session_id", get_string(document, "session_id"))
    emit("transcript_path", get_string(document, "transcript_path"))
    emit("cwd", get_string(document, "cwd"))
    emit("version", get_string(document, "version"))
    emit("model_id", get_string(model, "id"))
    emit("model_name", get_string(model, "display_name"))
    emit("current_dir", get_string(workspace, "current_dir"))
    emit("project_dir", get_string(workspace, "project_dir"))
    emit("repo_host", get_string(repo, "host"))
    emit("repo_owner", get_string(repo, "owner"))
    emit("repo_name", get_string(repo, "name"))
    emit("output_style", get_string(style, "name"))
    emit("effort", get_string(effort, "level"))

    raw_cost = get_number(cost, "total_cost_usd")
    if (raw_cost != "") { emit("cost_micro", sprintf("%d", raw_cost * 1000000 + 0.5)) }
    emit("duration_ms", get_number(cost, "total_duration_ms"))
    emit("api_duration_ms", get_number(cost, "total_api_duration_ms"))
    emit("lines_added", get_number(cost, "total_lines_added"))
    emit("lines_removed", get_number(cost, "total_lines_removed"))

    emit("context_percent", get_number(context, "used_percentage"))
    emit("context_remaining", get_number(context, "remaining_percentage"))
    emit("context_tokens", get_number(context, "total_input_tokens"))
    emit("context_output_tokens", get_number(context, "total_output_tokens"))
    emit("context_size", get_number(context, "context_window_size"))

    emit("fast_mode", get_bool(document, "fast_mode"))
    emit("exceeds_200k", get_bool(document, "exceeds_200k_tokens"))
    emit("thinking", get_bool(thinking, "enabled"))
  }
  ')

  SL_SESSION_ID="${SL_FIELD[session_id]:-}"
  SL_TRANSCRIPT="${SL_FIELD[transcript_path]:-}"
  SL_VERSION="${SL_FIELD[version]:-}"
  SL_MODEL_ID="${SL_FIELD[model_id]:-}"
  SL_MODEL_NAME="${SL_FIELD[model_name]:-}"
  SL_MODEL_SHORT="${SL_MODEL_NAME%% (*}"
  SL_PROJECT_DIR="${SL_FIELD[project_dir]:-}"
  SL_REPO_HOST="${SL_FIELD[repo_host]:-}"
  SL_REPO_OWNER="${SL_FIELD[repo_owner]:-}"
  SL_REPO_NAME="${SL_FIELD[repo_name]:-}"
  SL_OUTPUT_STYLE="${SL_FIELD[output_style]:-}"
  SL_EFFORT="${SL_FIELD[effort]:-}"
  SL_LINES_ADDED="${SL_FIELD[lines_added]:-0}"
  SL_LINES_REMOVED="${SL_FIELD[lines_removed]:-0}"
  SL_DURATION_MS="${SL_FIELD[duration_ms]:-0}"
  SL_API_DURATION_MS="${SL_FIELD[api_duration_ms]:-0}"
  SL_CONTEXT_PERCENT="${SL_FIELD[context_percent]:-}"
  SL_CONTEXT_PERCENT="${SL_CONTEXT_PERCENT%%.*}"
  SL_CONTEXT_REMAINING="${SL_FIELD[context_remaining]:-}"
  SL_CONTEXT_REMAINING="${SL_CONTEXT_REMAINING%%.*}"
  SL_CONTEXT_TOKENS="${SL_FIELD[context_tokens]:-0}"
  SL_CONTEXT_OUTPUT_TOKENS="${SL_FIELD[context_output_tokens]:-0}"
  SL_CONTEXT_SIZE="${SL_FIELD[context_size]:-0}"
  SL_FAST_MODE="${SL_FIELD[fast_mode]:-0}"
  SL_EXCEEDS_200K="${SL_FIELD[exceeds_200k]:-0}"
  SL_THINKING="${SL_FIELD[thinking]:-0}"

  SL_CWD="${SL_FIELD[current_dir]:-}"
  [ -n "$SL_CWD" ] || SL_CWD="${SL_FIELD[cwd]:-}"
  [ -n "$SL_CWD" ] || SL_CWD="$PWD"
  sl_home_relative "$SL_CWD"
  SL_PATH="$SL_HOME_RELATIVE"

  SL_COST_MICRO="${SL_FIELD[cost_micro]:-0}"
  sl_is_number "$SL_COST_MICRO" || SL_COST_MICRO=0
  SL_COST_TEXT=""
  if [ "$SL_COST_MICRO" -gt 0 ]; then
    printf -v SL_COST_TEXT '$%d.%02d' $(( SL_COST_MICRO / 1000000 )) $(( (SL_COST_MICRO % 1000000) / 10000 ))
  fi

  SL_ULTRACODE=0
  local candidate content
  for candidate in "$SL_CWD/.claude/settings.local.json" \
                   "$SL_CWD/.claude/settings.json" \
                   "${HOME:-/nonexistent}/.claude/settings.local.json" \
                   "${HOME:-/nonexistent}/.claude/settings.json"; do
    [ -f "$candidate" ] || continue
    content=$(<"$candidate") 2>/dev/null || continue
    case "$content" in
      *'"ultracode"'*) ;;
      *) continue ;;
    esac
    [[ "$content" =~ \"ultracode\"[[:space:]]*:[[:space:]]*true ]] && SL_ULTRACODE=1
    break
  done
}

SL_GIT_LOADED=0
SL_GIT_BRANCH=""
SL_GIT_AHEAD=0
SL_GIT_BEHIND=0

sl_git() {
  [ "$SL_GIT_LOADED" = "1" ] && return 0
  SL_GIT_LOADED=1
  local directory_key="${SL_CWD//\//_}" data
  data=$(sl_cache_read "git$directory_key" "$SL_GIT_CACHE_SECONDS") || {
    data=$(sl_collect_git "$SL_CWD" || printf '')
    sl_cache_write "git$directory_key" "$data"
  }
  [ -n "$data" ] || return 0
  IFS=$'\t' read -r SL_GIT_BRANCH SL_GIT_AHEAD SL_GIT_BEHIND <<< "$data"
  sl_is_number "${SL_GIT_AHEAD:-}" || SL_GIT_AHEAD=0
  sl_is_number "${SL_GIT_BEHIND:-}" || SL_GIT_BEHIND=0
}

sl_collect_git() {
  local git_directory="$1" branch tracking ahead=0 behind=0
  local -a git_run
  command -v git >/dev/null 2>&1 || return 1
  if command -v timeout >/dev/null 2>&1; then
    git_run=(timeout "$SL_GIT_TIMEOUT_SECONDS" git -C "$git_directory" --no-optional-locks)
  else
    git_run=(git -C "$git_directory" --no-optional-locks)
  fi
  "${git_run[@]}" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1

  branch=$("${git_run[@]}" symbolic-ref --quiet --short HEAD 2>/dev/null)
  if [ -z "$branch" ]; then
    branch=$("${git_run[@]}" rev-parse --short HEAD 2>/dev/null)
    [ -n "$branch" ] && branch="detached@$branch"
  fi
  [ -n "$branch" ] || return 1

  tracking=$("${git_run[@]}" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null)
  if [ -n "$tracking" ]; then
    behind="${tracking%%[[:space:]]*}"
    ahead="${tracking##*[[:space:]]}"
  fi
  printf '%s\t%s\t%s' "$branch" "$ahead" "$behind"
}

SL_GATEWAY_LOADED=0
SL_GATEWAY_RAW=""
SL_BUDGET_SPENT=""
SL_BUDGET_LIMIT=""
SL_BUDGET_PERCENT=""
SL_BUDGET_PERIOD=""

sl_gateway() {
  [ "$SL_GATEWAY_LOADED" = "1" ] && return 0
  SL_GATEWAY_LOADED=1
  local stale_cache
  if [ "${SL_PREVIEW:-0}" = "1" ]; then
    SL_GATEWAY_RAW=$(sl_cache_read "gateway" 86400) || SL_GATEWAY_RAW=""
  else
  SL_GATEWAY_RAW=$(sl_cache_read "gateway" "$SL_GATEWAY_CACHE_SECONDS") || {
    if [ -x "$SL_BUILD_CLI" ] && [ "$SL_GATEWAY_FORCE_REFRESH" = "1" ]; then
      for stale_cache in "${XDG_CONFIG_HOME:-${HOME:-/nonexistent}/.config}"/build-cli/usage-cache-v*.json; do
        [ -f "$stale_cache" ] && rm -f "$stale_cache" 2>/dev/null
      done
    fi
    if [ -x "$SL_BUILD_CLI" ]; then
      if command -v timeout >/dev/null 2>&1; then
        SL_GATEWAY_RAW=$(printf '%s' "$SL_PAYLOAD" | timeout 5 "$SL_BUILD_CLI" claude statusline 2>/dev/null)
      else
        SL_GATEWAY_RAW=$(printf '%s' "$SL_PAYLOAD" | "$SL_BUILD_CLI" claude statusline 2>/dev/null)
      fi
      case "$SL_GATEWAY_RAW" in
        *"$SL_ESC"*) SL_GATEWAY_RAW=$(printf '%s' "$SL_GATEWAY_RAW" | sed "s/${SL_ESC}\[[0-9;]*[a-zA-Z]//g") ;;
      esac
    else
      SL_GATEWAY_RAW=""
    fi
    sl_cache_write "gateway" "$SL_GATEWAY_RAW"
    find "$SL_CACHE_DIR" -maxdepth 1 -type f -mmin +"$SL_CACHE_PRUNE_MINUTES" -delete 2>/dev/null
  }
  fi

  if [[ "$SL_GATEWAY_RAW" =~ (\$[0-9][0-9,]*(\.[0-9]+)?)[[:space:]]*/[[:space:]]*(\$[0-9][0-9,]*(\.[0-9]+)?) ]]; then
    SL_BUDGET_SPENT="${BASH_REMATCH[1]}"
    SL_BUDGET_LIMIT="${BASH_REMATCH[3]}"
  fi
  [[ "$SL_GATEWAY_RAW" =~ ([0-9]+(\.[0-9]+)?)% ]] && SL_BUDGET_PERCENT="${BASH_REMATCH[1]}"
  [[ "$SL_GATEWAY_RAW" =~ (hourly|daily|weekly|monthly) ]] && SL_BUDGET_PERIOD="${BASH_REMATCH[1]}"
}

SL_BURN_LOADED=0
SL_TOKENS_BURNED=0
SL_TOKENS_BURNED_TEXT=""

sl_token_burn() {
  [ "$SL_BURN_LOADED" = "1" ] && return 0
  SL_BURN_LOADED=1
  [ -n "${SL_TRANSCRIPT:-}" ] && [ -f "$SL_TRANSCRIPT" ] || return 0

  local -a token_files=("$SL_TRANSCRIPT") token_sizes=()
  local restore_nullglob restore_globstar candidate token_pattern
  shopt -q nullglob && restore_nullglob=1 || restore_nullglob=0
  shopt -q globstar && restore_globstar=1 || restore_globstar=0
  shopt -s nullglob globstar
  for candidate in "${SL_TRANSCRIPT%.jsonl}"/subagents/**/*.jsonl; do
    [ -f "$candidate" ] && token_files+=("$candidate")
  done
  [ "$restore_nullglob" = "1" ] || shopt -u nullglob
  [ "$restore_globstar" = "1" ] || shopt -u globstar

  local -A token_offsets=() token_subtotals=()
  if [ "$SL_TOKEN_COUNT_CACHE_READS" = "1" ]; then
    token_pattern='"(input_tokens|cache_creation_input_tokens|cache_read_input_tokens|output_tokens)":[0-9]+'
  else
    token_pattern='"(input_tokens|cache_creation_input_tokens|output_tokens)":[0-9]+'
  fi

  sl_state_path "tok${SL_TOKEN_STATE_VERSION}${SL_TOKEN_COUNT_CACHE_READS}${SL_TRANSCRIPT//\//_}"
  local token_state_file="$SL_STATE_FILE" state_file_path state_offset state_subtotal
  if [ "${SL_PREVIEW:-0}" = "1" ]; then
    local preview_total=0
    if [ -f "$token_state_file" ]; then
      while IFS=$'\t' read -r state_file_path state_offset state_subtotal; do
        sl_is_number "${state_subtotal:-}" || continue
        preview_total=$(( preview_total + state_subtotal ))
      done < "$token_state_file"
    fi
    SL_TOKENS_BURNED="$preview_total"
    if [ "$preview_total" -gt 0 ]; then
      sl_group "$preview_total"
      SL_TOKENS_BURNED_TEXT="$SL_GROUP"
    fi
    return 0
  fi
  if [ -f "$token_state_file" ]; then
    while IFS=$'\t' read -r state_file_path state_offset state_subtotal; do
      [ -n "$state_file_path" ] || continue
      sl_is_number "$state_offset" || continue
      sl_is_number "$state_subtotal" || continue
      token_offsets["$state_file_path"]="$state_offset"
      token_subtotals["$state_file_path"]="$state_subtotal"
    done < "$token_state_file"
  fi

  mapfile -t token_sizes < <(stat -c %s "${token_files[@]}" 2>/dev/null)
  if [ "${#token_sizes[@]}" -ne "${#token_files[@]}" ]; then
    token_sizes=()
    for candidate in "${token_files[@]}"; do
      token_sizes+=("$(stat -c %s "$candidate" 2>/dev/null || printf 0)")
    done
  fi

  local token_grand=0 token_new_state="" token_budget="$SL_TOKEN_SCAN_BUDGET"
  local token_index token_file token_size token_offset token_subtotal
  local token_attempt token_pending token_take token_complete token_added token_consumed
  for (( token_index = 0; token_index < ${#token_files[@]}; token_index++ )); do
    token_file="${token_files[token_index]}"
    token_size="${token_sizes[token_index]:-0}"
    token_offset="${token_offsets[$token_file]:-0}"
    token_subtotal="${token_subtotals[$token_file]:-0}"
    sl_is_number "$token_size" || token_size=0
    sl_is_number "$token_offset" || token_offset=0
    sl_is_number "$token_subtotal" || token_subtotal=0

    if [ "$token_size" -lt "$token_offset" ]; then
      token_offset=0
      token_subtotal=0
    fi

    token_attempt=0
    while :; do
      token_pending=$(( token_size - token_offset ))
      [ "$token_pending" -gt 0 ] || break
      token_attempt=$(( token_attempt + 1 ))
      [ "$token_attempt" -le 2 ] || break
      if [ "$token_attempt" -eq 1 ]; then
        [ "$token_budget" -gt 0 ] || break
        if [ "$token_pending" -le "$token_budget" ]; then
          token_take="$token_pending"
        else
          token_take="$token_budget"
        fi
      else
        token_take="$token_pending"
      fi
      if [ -z "$(tail -c +$(( token_offset + token_take )) "$token_file" 2>/dev/null | head -c 1)" ]; then
        token_complete=1
      else
        token_complete=0
      fi
      token_budget=$(( token_budget - token_take ))
      [ "$token_budget" -lt 0 ] && token_budget=0

      read -r token_added token_consumed < <(
        tail -c +$(( token_offset + 1 )) "$token_file" 2>/dev/null | head -c "$token_take" | LC_ALL=C awk -v complete="$token_complete" -v pattern="$token_pattern" '
        function line_tokens(text,   running, value) {
          running = 0
          while (match(text, pattern)) {
            value = substr(text, RSTART, RLENGTH); sub(/.*:/, "", value)
            running += value
            text = substr(text, RSTART + RLENGTH)
          }
          return running
        }
        function commit(text) {
          if (index(text, "\"usage\"")) total += line_tokens(text)
        }
        {
          if (have) { commit(previous); consumed += previous_length }
          previous = $0; previous_length = length($0) + 1; have = 1
        }
        END {
          if (have && complete == 1) { commit(previous); consumed += previous_length }
          printf "%d %d\n", total + 0, consumed + 0
        }'
      )
      sl_is_number "${token_added:-}" || token_added=0
      sl_is_number "${token_consumed:-}" || token_consumed=0
      token_subtotal=$(( token_subtotal + token_added ))
      token_offset=$(( token_offset + token_consumed ))
      [ "$token_consumed" -gt 0 ] && break
      [ "$token_take" -ge "$token_pending" ] && break
    done

    token_grand=$(( token_grand + token_subtotal ))
    token_new_state="${token_new_state}${token_file}"$'\t'"${token_offset}"$'\t'"${token_subtotal}"$'\n'
  done

  printf '%s' "$token_new_state" > "$token_state_file" 2>/dev/null
  SL_TOKENS_BURNED="$token_grand"
  if [ "$token_grand" -gt 0 ]; then
    sl_group "$token_grand"
    SL_TOKENS_BURNED_TEXT="$SL_GROUP"
  fi
}

SL_LINES=()

# Claude Code trims every line of a statusline command's output and drops the
# lines that are empty afterwards, so a line may neither begin with whitespace
# nor be blank. A leading SGR reset costs no cell, survives the trim and keeps
# column 0 where the theme put it.
sl_line_guard() {
  SL_LINE="$1"
  [ "$SL_USE_COLOR" = "1" ] || return 0
  case "$SL_LINE" in
    ''|[[:space:]]*) SL_LINE="${SL_ESC}[m$SL_LINE" ;;
  esac
}

sl_emit() {
  local text="$1"
  sl_clip "$text" "$SL_COLUMNS"
  sl_line_guard "$SL_CLIP"
  SL_LINES+=("$SL_LINE")
}

# Emits a line whose visible width the caller already knows. Clipping an
# ANSI-heavy line costs a pass over every escape byte, which a pixel-art theme
# pays on every row of every frame, so a line that provably fits skips it.
sl_emit_sized() {
  if [ "${2:-$(( SL_COLUMNS + 1 ))}" -le "$SL_COLUMNS" ]; then
    sl_line_guard "$1"
    SL_LINES+=("$SL_LINE")
    return 0
  fi
  sl_emit "$1"
}

sl_emit_raw() {
  sl_line_guard "$1"
  SL_LINES+=("$SL_LINE")
}

sl_flush() {
  local index
  for (( index = 0; index < ${#SL_LINES[@]}; index++ )); do
    [ "$index" -gt 0 ] && printf '\n'
    printf '%s' "${SL_LINES[index]}"
  done
}
