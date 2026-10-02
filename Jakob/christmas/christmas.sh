#!/usr/bin/env bash
# @name: christmas
# @description: Village skyline at Christmas — fir, snowman, snowfall and a real-date advent terrace
# @order: 20

# A half-block pixel grid: two stacked pixels per terminal cell, so a pixel is
# roughly square. The street runs along the left with the fir, the gifts and the
# snowman; the terrace of houses closes the right, and the advent strip under it
# is that terrace's ground floor. Windows for days already opened burn warm,
# today pulses gold, days still to come stay dark. Every position, flake and
# twinkle is a pure function of SL_NOW, so two renders of one second match.

XMAS_WIDE_STRIP_CELLS=50
XMAS_COMPACT_STRIP_CELLS=26
XMAS_MIN_SCENE_COLUMNS=34
XMAS_MIN_WIDE_STRIP_COLUMNS=92
XMAS_SNOW_DENSITY=38
XMAS_STAR_DENSITY=9
XMAS_HOUSE_STRIDE=12
XMAS_MIN_STREET_COLUMNS=70
XMAS_MAX_EXTRA_HOUSES=8
XMAS_PULSE_SECONDS=5
XMAS_BLANK=$'\u200b'

XMAS_TREE14=(
  '......f......'
  '.....sgs.....'
  '.....lgd.....'
  '....logdd....'
  '.....lgd.....'
  '....lgggd....'
  '...wgrgddd...'
  '....lgggd....'
  '...lgggogd...'
  '..lbgggdddd..'
  '...lgggggd...'
  '..lgggggrgd..'
  '.wgogggddbdd.'
  '.....TtT.....'
)
XMAS_TREE12=(
  '......f......'
  '.....sgs.....'
  '....logdd....'
  '.....lgd.....'
  '....lgggd....'
  '...wgrgddd...'
  '...lgggogd...'
  '..lbgggdddd..'
  '..lgggggggd..'
  '.wgoggggrggd.'
  '..lggggggggd.'
  '.....TtT.....'
)
XMAS_TREE10=(
  '.....f.....'
  '....sgs....'
  '...logdd...'
  '....lgd....'
  '...lgrgd...'
  '..wgggddd..'
  '..lgggbgd..'
  '.lgoggdrdd.'
  '.lggggggdd.'
  '....TtT....'
)
XMAS_TREE8=(
  '....f....'
  '...sgs...'
  '..logdd..'
  '...lgd...'
  '..lgrgd..'
  '.lgggggd.'
  '.wbggdod.'
  '....t....'
)
XMAS_TREE6=(
  '...f...'
  '..sgs..'
  '..lod..'
  '.lgggd.'
  '.wggrd.'
  '...t...'
)

XMAS_SNOWMAN12=(
  '......GGf....'
  '.....GGGG....'
  '...fffffff...'
  '....xwwwv....'
  '....wewev....'
  '....wwnwv....'
  't...GrrrG...t'
  'tttwwwwwwvttt'
  '...wwwkwwv...'
  '..WxxxxxxxW..'
  '..Wwwwwwwwv..'
  '...Wwwwwwv...'
)
XMAS_SNOWMAN10=(
  '......GGf....'
  '.....GGGG....'
  '...fffffff...'
  '....wewev....'
  '....wwnwv....'
  't...GrrrG...t'
  'tttwwwkwwvttt'
  '..WxxxxxxxW..'
  '..Wwwwwwwwv..'
  '...Wwwwwwv...'
)
XMAS_SNOWMAN8=(
  '....GGf....'
  '..fffffff..'
  '...wewev...'
  '...wwnwv...'
  't..GrrrG..t'
  'ttwwwwwwwtt'
  '.Wxxxxxxxv.'
  '..Wwwwwwv..'
)

XMAS_GIFTS6=(
  '...o......'
  '..ooo.....'
  '.rGGGr.ooo'
  '.rrGrr.YGY'
  '.GGGGG.YYY'
  '.rrGrr.YGY'
)
XMAS_GIFTS4=(
  '..o....'
  '.rGr.YY'
  '.rrr.YY'
  '.GGG.oY'
)

XMAS_MOON8=(
  '..MMMM..'
  '.MMMMMM.'
  'MMMMMMMM'
  'MMMMuMMM'
  'MMuMMMMM'
  'MMMMMMuM'
  '.MMMMMM.'
  '..MMMM..'
)
XMAS_MOON6=(
  '..MMM.'
  '.MMMMM'
  'MMuMMM'
  'MMMMuM'
  'MMMMMM'
  '.MMMM.'
)

XMAS_HOUSE8_A=(
  '.....Ws.....'
  '....WWss....'
  '...WWWsss...'
  '..WWWWssss..'
  '.WWWWWsssss.'
  'RRRRRRRRRRRR'
  'EEEEEEEEEEEE'
  'wwwwwwwwwwww'
)
XMAS_HOUSE8_B=(
  '.CC.........'
  '.CC......CC.'
  'WWWWWWssssss'
  'WWWWWWssssss'
  'RRRRRRRRRRRR'
  'EEEEEEEEEEEE'
  'EEEEEEEEEEEE'
  'wwwwwwwwwwww'
)
XMAS_LAMP=(
  'GOG'
  'OOO'
  'GOG'
  '.P.'
  '.P.'
  '.P.'
  '.P.'
  '.P.'
  '.P.'
  '.P.'
)
XMAS_HOUSE6_A=(
  '....WWss....'
  '...WWWsss...'
  '..WWWWssss..'
  '.WWWWWsssss.'
  '.RRRRRRRRRR.'
  '.wwwwwwwwww.'
)
XMAS_HOUSE6_B=(
  '........CC..'
  '........CC..'
  '.WWWWWsssss.'
  '.WWWWWsssss.'
  '.RRRRRRRRRR.'
  '.wwwwwwwwww.'
)
XMAS_HOUSE4_A=(
  '..WWWWssss..'
  '.WWWWWsssss.'
  '.RRRRRRRRRR.'
  '.wwwwwwwwww.'
)
XMAS_HOUSE4_B=(
  '.CC.........'
  '.CC.........'
  'WWWWWWssssss'
  'wwwwwwwwwwww'
)
XMAS_STEEPLE=(
  '...k...'
  '...W...'
  '..Wss..'
  '..Wss..'
  '.WWsss.'
  '..RRR..'
  '..hyh..'
  '..hhh..'
  '..hhh..'
  '.WWsss.'
  'RRRRRRR'
  'wwwwwww'
)

XMAS_MID_TREE=(
  '...N...'
  '..NNN..'
  '..NNN..'
  '.NNNNN.'
  '..NNN..'
  '.NNNNN.'
  'NNNNNNN'
  '.NNNNN.'
  'NNNNNNN'
  '...P...'
)
XMAS_FAR_TREE=(
  '..D..'
  '.DDD.'
  '.DDD.'
  'DDDDD'
)

XMAS_FLAKE=(flake_far flake_mid flake_near)

declare -gA XMAS_SGR_CACHE=()
declare -gA XMAS_TONE_CACHE=()
declare -gA XMAS_CELL_CACHE=()

XMAS_STAR_RGB='255;246;214'
XMAS_TODAY_RGB='255;214;102'

xmas_rgb() {
  case "$1" in
    star_core) XMAS_RGB="$XMAS_STAR_RGB" ;;
    star_arm) XMAS_RGB='255;198;72' ;;
    fir_lit) XMAS_RGB='52;132;74' ;;
    fir) XMAS_RGB='24;92;56' ;;
    fir_deep) XMAS_RGB='12;58;40' ;;
    branch_snow) XMAS_RGB='236;248;255' ;;
    trunk) XMAS_RGB='94;58;36' ;;
    trunk_dark) XMAS_RGB='62;38;24' ;;
    bauble_red) XMAS_RGB='255;86;96' ;;
    bauble_red_dim) XMAS_RGB='142;30;42' ;;
    bauble_gold) XMAS_RGB='255;214;102' ;;
    bauble_gold_dim) XMAS_RGB='150;112;36' ;;
    bauble_ice) XMAS_RGB='168;230;255' ;;
    bauble_ice_dim) XMAS_RGB='72;118;142' ;;
    snow_hi) XMAS_RGB='255;255;255' ;;
    snow) XMAS_RGB='236;248;255' ;;
    snow_shade) XMAS_RGB='198;216;230' ;;
    snow_deep) XMAS_RGB='176;198;214' ;;
    fur) XMAS_RGB='255;244;212' ;;
    scarf) XMAS_RGB='196;30;46' ;;
    scarf_deep) XMAS_RGB='168;24;36' ;;
    coal) XMAS_RGB='14;14;18' ;;
    carrot) XMAS_RGB='240;126;38' ;;
    twig) XMAS_RGB='94;58;36' ;;
    gift_red) XMAS_RGB='196;30;46' ;;
    gift_red_dark) XMAS_RGB='168;24;36' ;;
    gift_green) XMAS_RGB='34;104;58' ;;
    ribbon_gold) XMAS_RGB='255;198;72' ;;
    roof_snow) XMAS_RGB='232;244;252' ;;
    roof_shade) XMAS_RGB='172;192;210' ;;
    eave) XMAS_RGB='28;18;24' ;;
    wall) XMAS_RGB='66;46;52' ;;
    wall_lit) XMAS_RGB='86;62;64' ;;
    wall_warm) XMAS_RGB='112;74;48' ;;
    chimney) XMAS_RGB='82;56;54' ;;
    smoke_near) XMAS_RGB='112;112;124' ;;
    smoke_far) XMAS_RGB='74;76;88' ;;
    spire) XMAS_RGB='52;40;50' ;;
    clock) XMAS_RGB='255;214;102' ;;
    finial) XMAS_RGB='255;226;140' ;;
    forest_mid) XMAS_RGB='20;68;46' ;;
    forest_trunk) XMAS_RGB='14;50;34' ;;
    forest_far) XMAS_RGB='12;36;30' ;;
    lamp_glow) XMAS_RGB='255;216;128' ;;
    lamp_frame) XMAS_RGB='122;92;52' ;;
    lamp_post) XMAS_RGB='70;56;50' ;;
    moon) XMAS_RGB='255;252;236' ;;
    moon_mare) XMAS_RGB='226;212;184' ;;
    star_lit) XMAS_RGB='255;232;176' ;;
    star_dim) XMAS_RGB='120;118;102' ;;
    drift) XMAS_RGB='186;206;222' ;;
    drift_hump) XMAS_RGB='226;240;250' ;;
    drift_crest) XMAS_RGB='248;252;255' ;;
    drift_warm) XMAS_RGB='232;214;182' ;;
    flake_far) XMAS_RGB='74;100;128' ;;
    flake_mid) XMAS_RGB='120;150;180' ;;
    flake_near) XMAS_RGB='200;222;240' ;;
    facade) XMAS_RGB='40;28;32' ;;
    facade_dim) XMAS_RGB='78;58;60' ;;
    cal_frame) XMAS_RGB='190;150;70' ;;
    cal_lit_fg) XMAS_RGB='72;44;16' ;;
    cal_lit_bg_odd) XMAS_RGB='230;178;80' ;;
    cal_lit_bg_even) XMAS_RGB='208;154;62' ;;
    cal_dark_fg) XMAS_RGB='146;104;86' ;;
    cal_dark_bg_odd) XMAS_RGB='60;30;32' ;;
    cal_dark_bg_even) XMAS_RGB='46;24;26' ;;
    cal_today_fg) XMAS_RGB='34;20;6' ;;
    cal_today_bg) XMAS_RGB="$XMAS_TODAY_RGB" ;;
    cal_sealed_fg) XMAS_RGB='96;104;118' ;;
    cal_sealed_bg) XMAS_RGB='28;34;44' ;;
    cal_label) XMAS_RGB='226;196;130' ;;
    cal_label_xmas) XMAS_RGB='255;214;102' ;;
    cal_label_sealed) XMAS_RGB='132;146;164' ;;
    gutter) XMAS_RGB='226;182;86' ;;
    path) XMAS_RGB='236;248;255' ;;
    separator) XMAS_RGB='84;96;110' ;;
    branch) XMAS_RGB='92;186;116' ;;
    model) XMAS_RGB='140;166;190' ;;
    cost) XMAS_RGB='255;206;120' ;;
    effort) XMAS_RGB='226;182;86' ;;
    context_good) XMAS_RGB='122;206;140' ;;
    context_caution) XMAS_RGB='255;206;120' ;;
    context_warn) XMAS_RGB='255;110;110' ;;
    *) XMAS_RGB='140;150;164' ;;
  esac
}

xmas_tone_bold() {
  case "$1" in
    star_core|star_arm|finial|clock|lamp_glow|snow_hi|branch_snow|bauble_red|bauble_gold|bauble_ice|roof_snow)
      XMAS_TONE_BOLD=1 ;;
    *) XMAS_TONE_BOLD=0 ;;
  esac
}

xmas_sgr() {
  if [ "$SL_USE_COLOR" != "1" ]; then
    XMAS_SGR=""
    return
  fi
  local key="$1|$2|$3"
  if [ -n "${XMAS_SGR_CACHE[$key]:-}" ]; then
    XMAS_SGR="${XMAS_SGR_CACHE[$key]}"
    return
  fi
  local weight='0' foreground background=''
  [ "$2" = "1" ] && weight='0;1'
  xmas_rgb "$1"
  foreground="$XMAS_RGB"
  if [ -n "$3" ]; then
    xmas_rgb "$3"
    background="$XMAS_RGB"
  fi
  if [ -n "$background" ]; then
    printf -v XMAS_SGR '%s[%s;38;2;%s;48;2;%sm' "$SL_ESC" "$weight" "$foreground" "$background"
  else
    printf -v XMAS_SGR '%s[%s;38;2;%sm' "$SL_ESC" "$weight" "$foreground"
  fi
  XMAS_SGR_CACHE["$key"]="$XMAS_SGR"
}

xmas_paint() {
  xmas_sgr "$1" "${3:-0}" ''
  XMAS_PAINT="$XMAS_SGR$2$SL_RESET"
}

xmas_hash() {
  local mixed=$(( ( ($1 + $2) * 2654435761 ) & 0xFFFFFFFF ))
  mixed=$(( (mixed ^ (mixed >> 13)) & 0xFFFFFFFF ))
  mixed=$(( (mixed * 1274126177) & 0xFFFFFFFF ))
  XMAS_HASH=$(( (mixed ^ (mixed >> 16)) & 0xFFFF ))
}

xmas_season() {
  local now="$1" raw year month day doy leap first
  printf -v raw '%(%Y %m %d %j)T' "$now"
  read -r year month day doy <<< "$raw"
  year=$(( 10#$year ))
  month=$(( 10#$month ))
  day=$(( 10#$day ))
  doy=$(( 10#$doy ))
  if [ "$month" -eq 12 ] && [ "$day" -le 24 ]; then
    XMAS_MODE=advent
    XMAS_DOOR="$day"
    XMAS_LEFT=$(( 24 - day ))
    return 0
  fi
  if [ "$month" -eq 12 ]; then
    XMAS_MODE=christmas
    XMAS_DOOR=0
    XMAS_LEFT=0
    return 0
  fi
  leap=0
  if [ $(( year % 4 )) -eq 0 ] && { [ $(( year % 100 )) -ne 0 ] || [ $(( year % 400 )) -eq 0 ]; }; then
    leap=1
  fi
  first=$(( 335 + leap ))
  XMAS_MODE=sealed
  XMAS_DOOR=0
  XMAS_LEFT=$(( first - doy ))
  return 0
}

xmas_pulse() {
  local green blue
  sl_phase "$XMAS_PULSE_SECONDS"
  sl_cos "$SL_PHASE"
  green=$(( 232 + SL_COS * 20 / 1000 ))
  blue=$(( 150 + SL_COS * 70 / 1000 ))
  [ "$XMAS_MODE" = "christmas" ] && blue=$(( 150 + SL_COS * 100 / 1000 ))
  XMAS_STAR_RGB="255;${green};${blue}"
  green=$(( 229 + SL_COS * 15 / 1000 ))
  blue=$(( 149 + SL_COS * 47 / 1000 ))
  XMAS_TODAY_RGB="255;${green};${blue}"
}

xmas_twinkle() {
  xmas_hash "$1" "$2"
  XMAS_LIT=0
  [ $(( (SL_NOW + XMAS_HASH) % 7 )) -lt 4 ] && XMAS_LIT=1
  [ "$XMAS_MODE" = "christmas" ] && XMAS_LIT=1
  return 0
}

xmas_put() {
  local row="$1" column="$2"
  [ "$row" -ge 0 ] && [ "$row" -lt "$XMAS_PX" ] || return 0
  [ "$column" -ge 0 ] && [ "$column" -lt "$XMAS_W" ] || return 0
  XMAS_PIX[row * XMAS_W + column]="$3"
  return 0
}

xmas_put_empty() {
  local row="$1" column="$2" index
  [ "$row" -ge 0 ] && [ "$row" -lt "$XMAS_PX" ] || return 0
  [ "$column" -ge 0 ] && [ "$column" -lt "$XMAS_W" ] || return 0
  index=$(( row * XMAS_W + column ))
  [ -z "${XMAS_PIX[index]:-}" ] || return 0
  XMAS_PIX[index]="$3"
  return 0
}

xmas_cell_tone() {
  local species="$1" code="$2"
  case "$species" in
    tree)
      case "$code" in
        f) XMAS_CELL_TONE=star_core ;;
        s) XMAS_CELL_TONE=star_arm ;;
        l) XMAS_CELL_TONE=fir_lit ;;
        d) XMAS_CELL_TONE=fir_deep ;;
        w) XMAS_CELL_TONE=branch_snow ;;
        r) XMAS_CELL_TONE=bauble_red ;;
        o) XMAS_CELL_TONE=bauble_gold ;;
        b) XMAS_CELL_TONE=bauble_ice ;;
        t) XMAS_CELL_TONE=trunk ;;
        T) XMAS_CELL_TONE=trunk_dark ;;
        *) XMAS_CELL_TONE=fir ;;
      esac
      ;;
    snowman)
      case "$code" in
        W) XMAS_CELL_TONE=snow_hi ;;
        x) XMAS_CELL_TONE=snow_shade ;;
        v) XMAS_CELL_TONE=snow_deep ;;
        f) XMAS_CELL_TONE=fur ;;
        G) XMAS_CELL_TONE=scarf_deep ;;
        r) XMAS_CELL_TONE=scarf ;;
        e|k) XMAS_CELL_TONE=coal ;;
        n) XMAS_CELL_TONE=carrot ;;
        t) XMAS_CELL_TONE=twig ;;
        *) XMAS_CELL_TONE=snow ;;
      esac
      ;;
    gifts)
      case "$code" in
        G) XMAS_CELL_TONE=gift_red_dark ;;
        Y) XMAS_CELL_TONE=gift_green ;;
        o) XMAS_CELL_TONE=ribbon_gold ;;
        *) XMAS_CELL_TONE=gift_red ;;
      esac
      ;;
    house)
      case "$code" in
        s) XMAS_CELL_TONE=roof_shade ;;
        R) XMAS_CELL_TONE=eave ;;
        E) XMAS_CELL_TONE=wall ;;
        C) XMAS_CELL_TONE=chimney ;;
        k) XMAS_CELL_TONE=finial ;;
        K) XMAS_CELL_TONE=spire ;;
        S) XMAS_CELL_TONE=roof_shade ;;
        y) XMAS_CELL_TONE=clock ;;
        h) XMAS_CELL_TONE=wall_lit ;;
        w) XMAS_CELL_TONE=wall_warm ;;
        *) XMAS_CELL_TONE=roof_snow ;;
      esac
      ;;
    forest)
      case "$code" in
        P) XMAS_CELL_TONE=forest_trunk ;;
        D) XMAS_CELL_TONE=forest_far ;;
        *) XMAS_CELL_TONE=forest_mid ;;
      esac
      ;;
    lamp)
      case "$code" in
        O) XMAS_CELL_TONE=lamp_glow ;;
        P) XMAS_CELL_TONE=lamp_post ;;
        *) XMAS_CELL_TONE=lamp_frame ;;
      esac
      ;;
    *)
      case "$code" in
        u) XMAS_CELL_TONE=moon_mare ;;
        *) XMAS_CELL_TONE=moon ;;
      esac
      ;;
  esac
}

xmas_stamp() {
  local species="$1" top="$2" left="$3" line height width row column code tone key
  local target_row target_column base
  local -n sprite="$4"
  height="${#sprite[@]}"
  width="${#sprite[0]}"
  for (( row = 0; row < height; row++ )); do
    target_row=$(( top + row ))
    [ "$target_row" -ge 0 ] && [ "$target_row" -lt "$XMAS_PX" ] || continue
    base=$(( target_row * XMAS_W ))
    line="${sprite[row]}"
    for (( column = 0; column < width; column++ )); do
      code="${line:column:1}"
      [ "$code" = "." ] && continue
      target_column=$(( left + column ))
      [ "$target_column" -ge 0 ] && [ "$target_column" -lt "$XMAS_W" ] || continue
      key="$species$code"
      tone="${XMAS_TONE_CACHE[$key]:-}"
      if [ -z "$tone" ]; then
        xmas_cell_tone "$species" "$code"
        tone="$XMAS_CELL_TONE"
        XMAS_TONE_CACHE["$key"]="$tone"
      fi
      case "$tone" in
        bauble_red|bauble_gold|bauble_ice)
          xmas_twinkle "$target_column" "$target_row"
          [ "$XMAS_LIT" = "0" ] && tone="${tone}_dim"
          ;;
      esac
      XMAS_PIX[base + target_column]="$tone"
    done
  done
  return 0
}

xmas_stars() {
  local column row limit
  limit=$(( XMAS_PX / 2 ))
  [ "$limit" -lt 1 ] && limit=1
  for (( column = 0; column < XMAS_W; column++ )); do
    xmas_hash "$column" 577
    [ $(( XMAS_HASH % 100 )) -lt "$XMAS_STAR_DENSITY" ] || continue
    row=$(( XMAS_HASH / 128 % limit ))
    if [ $(( (SL_NOW + XMAS_HASH) % 9 )) -lt 5 ]; then
      xmas_put_empty "$row" "$column" star_lit
    else
      xmas_put_empty "$row" "$column" star_dim
    fi
  done
}

xmas_moon() {
  local top left
  [ "$XMAS_PX" -ge 10 ] || return 0
  left=$(( XMAS_STRIP_LEFT + 5 ))
  if [ "$XMAS_PX" -ge 12 ]; then
    top=$(( XMAS_PX - 12 ))
    [ $(( left + 8 )) -le "$XMAS_W" ] || return 0
    xmas_stamp moon "$top" "$left" XMAS_MOON8
    return 0
  fi
  top=$(( XMAS_PX - 9 ))
  [ "$top" -lt 0 ] && top=0
  [ $(( left + 6 )) -le "$XMAS_W" ] || return 0
  xmas_stamp moon "$top" "$left" XMAS_MOON6
  return 0
}

xmas_terrace() {
  local slot left tall short height flat
  [ "$XMAS_PX" -ge 6 ] || return 0
  [ "$XMAS_TERRACE_SLOTS" -ge 1 ] || return 0
  if [ "$XMAS_PX" -ge 12 ]; then
    tall=8
    short=6
  elif [ "$XMAS_PX" -ge 8 ]; then
    tall=6
    short=4
  else
    tall=4
    short=4
  fi
  for (( slot = 0; slot < XMAS_TERRACE_SLOTS; slot++ )); do
    [ "$slot" = "$XMAS_STEEPLE_SLOT" ] && continue
    left=$(( XMAS_TERRACE_LEFT + slot * XMAS_HOUSE_STRIDE ))
    xmas_hash "$left" 811
    height="$tall"
    [ $(( XMAS_HASH % 5 )) -lt 2 ] && height="$short"
    flat=$(( XMAS_HASH / 32 % 2 ))
    case "${height}${flat}" in
      80) xmas_stamp house $(( XMAS_PX - 8 )) "$left" XMAS_HOUSE8_A ;;
      81) xmas_stamp house $(( XMAS_PX - 8 )) "$left" XMAS_HOUSE8_B ;;
      60) xmas_stamp house $(( XMAS_PX - 6 )) "$left" XMAS_HOUSE6_A ;;
      61) xmas_stamp house $(( XMAS_PX - 6 )) "$left" XMAS_HOUSE6_B ;;
      40) xmas_stamp house $(( XMAS_PX - 4 )) "$left" XMAS_HOUSE4_A ;;
      *) xmas_stamp house $(( XMAS_PX - 4 )) "$left" XMAS_HOUSE4_B ;;
    esac
  done
  [ "$XMAS_STEEPLE_SLOT" -ge 0 ] || return 0
  left=$(( XMAS_TERRACE_LEFT + XMAS_STEEPLE_SLOT * XMAS_HOUSE_STRIDE ))
  xmas_stamp house $(( XMAS_PX - 8 )) "$left" XMAS_HOUSE8_A
  xmas_stamp house $(( XMAS_PX - 12 )) $(( left + 3 )) XMAS_STEEPLE
  return 0
}

xmas_smoke() {
  local slot left top column row offset age height
  [ "$XMAS_PX" -ge 10 ] || return 0
  for (( slot = 0; slot < XMAS_TERRACE_SLOTS; slot++ )); do
    [ "$slot" = "$XMAS_STEEPLE_SLOT" ] && continue
    left=$(( XMAS_TERRACE_LEFT + slot * XMAS_HOUSE_STRIDE ))
    xmas_hash "$left" 811
    [ $(( XMAS_HASH / 32 % 2 )) -eq 1 ] || continue
    height=8
    [ $(( XMAS_HASH % 5 )) -lt 2 ] && height=6
    top=$(( XMAS_PX - height ))
    column=$(( left + 1 ))
    [ "$height" = "6" ] && column=$(( left + 8 ))
    for (( age = 1; age <= 4; age++ )); do
      row=$(( top - age - (SL_NOW / 2 + slot) % 2 ))
      [ "$row" -ge 0 ] || break
      sl_cos $(( (SL_NOW + age * 3 + slot * 7) * 90 ))
      offset=$(( SL_COS * 2 / 1000 ))
      if [ "$age" -le 2 ]; then
        xmas_put_empty "$row" $(( column + offset )) smoke_near
      else
        xmas_put_empty "$row" $(( column + offset )) smoke_far
      fi
    done
  done
  return 0
}

xmas_conifers() {
  local column last_column stride top
  [ "$XMAS_PX" -ge 8 ] || return 0
  last_column=-99
  for (( column = XMAS_CONIFER_LEFT; column <= XMAS_STREET_RIGHT; column++ )); do
    xmas_hash "$column" 229
    [ $(( XMAS_HASH % 100 )) -lt 46 ] || continue
    if [ "$XMAS_PX" -ge 12 ] && [ $(( XMAS_HASH % 2 )) -eq 1 ]; then
      stride=9
      [ $(( column - last_column )) -ge "$stride" ] || continue
      [ $(( column + 7 )) -le $(( XMAS_STREET_RIGHT + 1 )) ] || continue
      last_column="$column"
      top=$(( XMAS_PX - 11 ))
      xmas_stamp forest "$top" "$column" XMAS_MID_TREE
    else
      stride=6
      [ $(( column - last_column )) -ge "$stride" ] || continue
      [ $(( column + 5 )) -le $(( XMAS_STREET_RIGHT + 1 )) ] || continue
      last_column="$column"
      top=$(( XMAS_PX - 6 ))
      xmas_stamp forest "$top" "$column" XMAS_FAR_TREE
    fi
  done
  return 0
}

xmas_drift() {
  local column tone
  for (( column = 0; column <= XMAS_DRIFT_RIGHT; column++ )); do
    tone=drift
    if [ "$column" -ge "$XMAS_WARM_LEFT" ] && [ "$column" -le "$XMAS_WARM_RIGHT" ]; then
      tone=drift_warm
    fi
    xmas_put $(( XMAS_PX - 1 )) "$column" "$tone"
    xmas_put $(( XMAS_PX - 2 )) "$column" drift_hump
    xmas_hash $(( column / 3 )) 31
    [ $(( XMAS_HASH % 5 )) -lt 2 ] && xmas_put $(( XMAS_PX - 3 )) "$column" drift_crest
  done
  return 0
}

xmas_snow() {
  local column span depth speed shift row target
  span=$(( XMAS_PX + 4 ))
  for (( column = 0; column < XMAS_W; column++ )); do
    xmas_hash "$column" 911
    [ $(( XMAS_HASH % 100 )) -lt "$XMAS_SNOW_DENSITY" ] || continue
    depth=$(( XMAS_HASH % 3 ))
    speed=$(( depth + 1 ))
    shift=$(( SL_NOW * (depth - 1) / 3 ))
    row=$(( (SL_NOW * speed + XMAS_HASH) % span - 2 ))
    target=$(( (column + shift) % XMAS_W ))
    [ "$target" -lt 0 ] && target=$(( target + XMAS_W ))
    xmas_put_empty "$row" "$target" "${XMAS_FLAKE[depth]}"
  done
  return 0
}

xmas_plan() {
  local cursor
  cursor=1
  XMAS_TREE_LEFT=-1
  XMAS_GIFTS_LEFT=-1
  XMAS_GIFTS_BIG=0
  XMAS_SNOWMAN_LEFT=-1
  XMAS_SNOWMAN_PX=0
  XMAS_WARM_LEFT=0
  XMAS_WARM_RIGHT=-1
  case "$XMAS_PX" in
    14) XMAS_TREE_W=13; XMAS_TREE_H=14 ;;
    12) XMAS_TREE_W=13; XMAS_TREE_H=12 ;;
    10) XMAS_TREE_W=11; XMAS_TREE_H=10 ;;
    8) XMAS_TREE_W=9; XMAS_TREE_H=8 ;;
    6) XMAS_TREE_W=7; XMAS_TREE_H=6 ;;
    *) XMAS_TREE_W=0; XMAS_TREE_H=0 ;;
  esac
  if [ "$XMAS_TREE_W" -gt 0 ] && [ $(( cursor + XMAS_TREE_W - 1 )) -le "$XMAS_STREET_RIGHT" ]; then
    XMAS_TREE_LEFT="$cursor"
    XMAS_WARM_LEFT="$cursor"
    XMAS_WARM_RIGHT=$(( cursor + XMAS_TREE_W - 1 ))
    cursor=$(( cursor + XMAS_TREE_W + 2 ))
  fi
  if [ "$XMAS_PX" -ge 12 ] && [ $(( cursor + 9 )) -le "$XMAS_STREET_RIGHT" ]; then
    XMAS_GIFTS_LEFT="$cursor"
    XMAS_GIFTS_BIG=1
    XMAS_WARM_RIGHT=$(( cursor + 9 ))
    cursor=$(( cursor + 12 ))
  elif [ "$XMAS_PX" -ge 10 ] && [ $(( cursor + 6 )) -le "$XMAS_STREET_RIGHT" ]; then
    XMAS_GIFTS_LEFT="$cursor"
    XMAS_GIFTS_BIG=0
    XMAS_WARM_RIGHT=$(( cursor + 6 ))
    cursor=$(( cursor + 9 ))
  fi
  if [ "$XMAS_PX" -ge 12 ] && [ $(( cursor + 12 )) -le "$XMAS_STREET_RIGHT" ]; then
    XMAS_SNOWMAN_LEFT="$cursor"
    XMAS_SNOWMAN_PX=12
    cursor=$(( cursor + 15 ))
  elif [ "$XMAS_PX" -ge 10 ] && [ $(( cursor + 12 )) -le "$XMAS_STREET_RIGHT" ]; then
    XMAS_SNOWMAN_LEFT="$cursor"
    XMAS_SNOWMAN_PX=10
    cursor=$(( cursor + 15 ))
  elif [ "$XMAS_PX" -ge 8 ] && [ $(( cursor + 10 )) -le "$XMAS_STREET_RIGHT" ]; then
    XMAS_SNOWMAN_LEFT="$cursor"
    XMAS_SNOWMAN_PX=8
    cursor=$(( cursor + 13 ))
  fi
  XMAS_LAMP_LEFT=-1
  if [ "$XMAS_PX" -ge 12 ] && [ $(( cursor + 3 )) -le "$XMAS_STREET_RIGHT" ]; then
    XMAS_LAMP_LEFT="$cursor"
    cursor=$(( cursor + 6 ))
  fi
  XMAS_CONIFER_LEFT="$cursor"
  return 0
}

xmas_foreground() {
  if [ "$XMAS_TREE_LEFT" -ge 0 ]; then
    case "$XMAS_PX" in
      14) xmas_stamp tree 0 "$XMAS_TREE_LEFT" XMAS_TREE14 ;;
      12) xmas_stamp tree 0 "$XMAS_TREE_LEFT" XMAS_TREE12 ;;
      10) xmas_stamp tree 0 "$XMAS_TREE_LEFT" XMAS_TREE10 ;;
      8) xmas_stamp tree 0 "$XMAS_TREE_LEFT" XMAS_TREE8 ;;
      *) xmas_stamp tree 0 "$XMAS_TREE_LEFT" XMAS_TREE6 ;;
    esac
  fi
  if [ "$XMAS_GIFTS_LEFT" -ge 0 ]; then
    if [ "$XMAS_GIFTS_BIG" = "1" ]; then
      xmas_stamp gifts $(( XMAS_PX - 6 )) "$XMAS_GIFTS_LEFT" XMAS_GIFTS6
    else
      xmas_stamp gifts $(( XMAS_PX - 4 )) "$XMAS_GIFTS_LEFT" XMAS_GIFTS4
    fi
  fi
  if [ "$XMAS_SNOWMAN_LEFT" -ge 0 ]; then
    case "$XMAS_SNOWMAN_PX" in
      12) xmas_stamp snowman $(( XMAS_PX - 12 )) "$XMAS_SNOWMAN_LEFT" XMAS_SNOWMAN12 ;;
      10) xmas_stamp snowman $(( XMAS_PX - 10 )) "$XMAS_SNOWMAN_LEFT" XMAS_SNOWMAN10 ;;
      *) xmas_stamp snowman $(( XMAS_PX - 8 )) "$XMAS_SNOWMAN_LEFT" XMAS_SNOWMAN8 ;;
    esac
  fi
  if [ "$XMAS_LAMP_LEFT" -ge 0 ]; then
    xmas_stamp lamp $(( XMAS_PX - 12 )) "$XMAS_LAMP_LEFT" XMAS_LAMP
  fi
  return 0
}

xmas_row_render() {
  local row="$1" base_top base_bottom last column top bottom glyph key state output sgr
  base_top=$(( row * 2 * XMAS_W ))
  base_bottom=$(( (row * 2 + 1) * XMAS_W ))
  last=-1
  for (( column = XMAS_W - 1; column >= 0; column-- )); do
    if [ -n "${XMAS_PIX[base_top + column]:-}" ] || [ -n "${XMAS_PIX[base_bottom + column]:-}" ]; then
      last="$column"
      break
    fi
  done
  if [ "$last" -lt 0 ]; then
    XMAS_ROW="$XMAS_BLANK"
    return 0
  fi
  state=""
  output=""
  [ "$SL_USE_COLOR" = "1" ] || output="$XMAS_BLANK"
  for (( column = 0; column <= last; column++ )); do
    top="${XMAS_PIX[base_top + column]:-}"
    bottom="${XMAS_PIX[base_bottom + column]:-}"
    if [ -z "$top" ] && [ -z "$bottom" ]; then
      if [ -n "$state" ]; then
        output="$output$SL_RESET"
        state=""
      fi
      output="$output "
      continue
    fi
    key="$top|$bottom"
    sgr="${XMAS_CELL_CACHE[$key]:-}"
    if [ -z "$sgr" ]; then
      if [ -z "$bottom" ]; then
        glyph='▀'
        xmas_tone_bold "$top"
        xmas_sgr "$top" "$XMAS_TONE_BOLD" ''
      elif [ -z "$top" ]; then
        glyph='▄'
        xmas_tone_bold "$bottom"
        xmas_sgr "$bottom" "$XMAS_TONE_BOLD" ''
      elif [ "$top" = "$bottom" ]; then
        glyph='█'
        xmas_tone_bold "$top"
        xmas_sgr "$top" "$XMAS_TONE_BOLD" ''
      else
        glyph='▀'
        xmas_tone_bold "$top"
        xmas_sgr "$top" "$XMAS_TONE_BOLD" "$bottom"
      fi
      sgr="$XMAS_SGR$glyph"
      XMAS_CELL_CACHE["$key"]="$sgr"
    fi
    glyph="${sgr: -1}"
    sgr="${sgr%?}"
    if [ "$sgr" != "$state" ]; then
      output="$output$sgr"
      state="$sgr"
    fi
    output="$output$glyph"
  done
  XMAS_ROW="$output$SL_RESET"
  return 0
}

xmas_door_state() {
  local door="$1"
  case "$XMAS_MODE" in
    christmas) XMAS_DOOR_STATE=lit ;;
    sealed) XMAS_DOOR_STATE=sealed ;;
    *)
      if [ "$door" -lt "$XMAS_DOOR" ]; then
        XMAS_DOOR_STATE=lit
      elif [ "$door" -eq "$XMAS_DOOR" ]; then
        XMAS_DOOR_STATE=today
      else
        XMAS_DOOR_STATE=dark
      fi
      ;;
  esac
}

xmas_door_sgr() {
  local door="$1" parity
  parity=$(( door % 2 ))
  xmas_door_state "$door"
  case "$XMAS_DOOR_STATE" in
    today) xmas_sgr cal_today_fg 1 cal_today_bg ;;
    lit)
      if [ "$parity" = "1" ]; then
        xmas_sgr cal_lit_fg 1 cal_lit_bg_odd
      else
        xmas_sgr cal_lit_fg 1 cal_lit_bg_even
      fi
      ;;
    sealed) xmas_sgr cal_sealed_fg 0 cal_sealed_bg ;;
    *)
      if [ "$parity" = "1" ]; then
        xmas_sgr cal_dark_fg 0 cal_dark_bg_odd
      else
        xmas_sgr cal_dark_fg 0 cal_dark_bg_even
      fi
      ;;
  esac
}

xmas_door_fg() {
  local door="$1"
  xmas_door_state "$door"
  case "$XMAS_DOOR_STATE" in
    today) xmas_sgr cal_today_bg 1 '' ;;
    lit) xmas_sgr cal_lit_bg_odd 1 '' ;;
    sealed) xmas_sgr cal_sealed_bg 0 '' ;;
    *) xmas_sgr cal_dark_bg_odd 0 '' ;;
  esac
}

xmas_strip() {
  local wide="$1" door output number
  xmas_sgr cal_frame 0 ''
  output="$XMAS_SGR▐"
  for (( door = 1; door <= 24; door++ )); do
    if [ "$wide" = "1" ]; then
      printf -v number '%02d' "$door"
      xmas_door_sgr "$door"
      output="$output$XMAS_SGR$number"
    else
      xmas_door_fg "$door"
      case "$XMAS_DOOR_STATE" in
        lit|today) output="$output$XMAS_SGR█" ;;
        *) output="$output$XMAS_SGR▒" ;;
      esac
    fi
  done
  xmas_sgr cal_frame 0 ''
  XMAS_STRIP="$output$SL_RESET$XMAS_SGR▌$SL_RESET"
  return 0
}

xmas_days_left() {
  if [ "$1" -eq 1 ]; then
    XMAS_DAYS_LEFT='NOCH 1 TAG'
  else
    XMAS_DAYS_LEFT="NOCH $1 TAGE"
  fi
}

xmas_labels() {
  XMAS_LABEL_TONE=cal_label
  xmas_days_left "$XMAS_LEFT"
  case "$XMAS_MODE" in
    christmas)
      XMAS_LABEL_TONE=cal_label_xmas
      XMAS_LABEL_LONG='FROHE WEIHNACHTEN'
      XMAS_LABEL_MID='WEIHNACHTEN'
      XMAS_LABEL_SHORT='XMAS'
      ;;
    sealed)
      XMAS_LABEL_TONE=cal_label_sealed
      XMAS_LABEL_LONG="ADVENTSKALENDER VERSIEGELT · ${XMAS_DAYS_LEFT}"
      XMAS_LABEL_MID="ADVENT ${XMAS_DAYS_LEFT}"
      XMAS_LABEL_SHORT="ADV-${XMAS_LEFT}"
      ;;
    *)
      if [ "$XMAS_LEFT" -eq 0 ]; then
        XMAS_LABEL_LONG="TÜRCHEN ${XMAS_DOOR}/24 · HEILIGABEND"
      else
        XMAS_LABEL_LONG="TÜRCHEN ${XMAS_DOOR}/24 · ${XMAS_DAYS_LEFT}"
      fi
      XMAS_LABEL_MID="TÜRCHEN ${XMAS_DOOR}/24"
      XMAS_LABEL_SHORT="${XMAS_DOOR}/24"
      ;;
  esac
  return 0
}

xmas_advent_row() {
  local wide="$1" room facade label label_width pad gutter
  xmas_labels
  xmas_strip "$wide"
  room="$XMAS_TERRACE_LEFT"
  facade=""
  if [ "$XMAS_STRIP_LEFT" -gt "$XMAS_TERRACE_LEFT" ]; then
    printf -v pad '%*s' $(( XMAS_STRIP_LEFT - XMAS_TERRACE_LEFT )) ''
    xmas_sgr facade_dim 0 facade
    facade="$XMAS_SGR$pad$SL_RESET"
  fi
  label=""
  label_width=0
  for label in "$XMAS_LABEL_LONG" "$XMAS_LABEL_MID" "$XMAS_LABEL_SHORT" ""; do
    [ -n "$label" ] || break
    sl_width "$label"
    if [ $(( SL_W + 3 )) -le "$room" ]; then
      label_width="$SL_W"
      break
    fi
  done
  xmas_sgr gutter 0 ''
  gutter="$XMAS_SGR▌$SL_RESET"
  if [ -z "$label" ] || [ "$label_width" -eq 0 ]; then
    printf -v pad '%*s' $(( room - 1 )) ''
    XMAS_ADVENT_ROW="${gutter}${pad}${facade}${XMAS_STRIP}"
    return 0
  fi
  gutter="$gutter "
  xmas_paint "$XMAS_LABEL_TONE" "$label"
  printf -v pad '%*s' $(( room - label_width - 2 )) ''
  XMAS_ADVENT_ROW="${gutter}${XMAS_PAINT}${pad}${facade}${XMAS_STRIP}"
  return 0
}

xmas_context() {
  XMAS_CONTEXT_TEXT=""
  XMAS_CONTEXT_SHORT=""
  XMAS_CONTEXT_TONE=context_good
  sl_is_number "${SL_CONTEXT_PERCENT:-}" || return 0
  XMAS_CONTEXT_SHORT="ctx ${SL_CONTEXT_PERCENT}%"
  XMAS_CONTEXT_TEXT="$XMAS_CONTEXT_SHORT"
  if [ "${SL_CONTEXT_TOKENS:-0}" -gt 0 ]; then
    sl_abbrev "$SL_CONTEXT_TOKENS"
    XMAS_CONTEXT_TEXT="${XMAS_CONTEXT_TEXT} ${SL_ABBREV}"
  fi
  [ "$SL_CONTEXT_PERCENT" -ge 60 ] && XMAS_CONTEXT_TONE=context_caution
  [ "$SL_CONTEXT_PERCENT" -ge 85 ] && XMAS_CONTEXT_TONE=context_warn
  return 0
}

xmas_append() {
  local width="$1" text="$2"
  if [ "$XMAS_LINE_WIDTH" -gt 0 ]; then
    [ $(( XMAS_LINE_WIDTH + width + 3 )) -le "$XMAS_LINE_BUDGET" ] || return 1
    xmas_paint separator ' · '
    XMAS_LINE="$XMAS_LINE$XMAS_PAINT$text"
    XMAS_LINE_WIDTH=$(( XMAS_LINE_WIDTH + width + 3 ))
    return 0
  fi
  [ "$width" -le "$XMAS_LINE_BUDGET" ] || return 1
  XMAS_LINE="$XMAS_LINE$text"
  XMAS_LINE_WIDTH="$width"
  return 0
}

xmas_data_plan() {
  local budget="$1" context_text="$2" tail=0 branch_room
  XMAS_PLAN_CONTEXT="$context_text"
  XMAS_PLAN_MODEL=""
  XMAS_PLAN_BRANCH=""
  XMAS_PLAN_EFFORT=""
  [ -n "$context_text" ] && tail=$(( tail + ${#context_text} + 3 ))
  [ -n "$SL_COST_TEXT" ] && tail=$(( tail + ${#SL_COST_TEXT} + 3 ))
  if [ -n "$SL_MODEL_NAME" ]; then
    sl_width "$SL_MODEL_NAME"
    if [ $(( budget - tail - SL_W - 3 )) -ge 14 ]; then
      XMAS_PLAN_MODEL="$SL_MODEL_NAME"
      tail=$(( tail + SL_W + 3 ))
    elif [ -n "$SL_MODEL_SHORT" ]; then
      sl_width "$SL_MODEL_SHORT"
      if [ $(( budget - tail - SL_W - 3 )) -ge 12 ]; then
        XMAS_PLAN_MODEL="$SL_MODEL_SHORT"
        tail=$(( tail + SL_W + 3 ))
      fi
    fi
  fi
  if [ -n "$SL_EFFORT" ] && [ $(( budget - tail - ${#SL_EFFORT} - 4 )) -ge 16 ]; then
    XMAS_PLAN_EFFORT="✦$SL_EFFORT"
    tail=$(( tail + ${#SL_EFFORT} + 4 ))
  fi
  XMAS_PLAN_PATH_ROOM=$(( budget - tail ))
  if [ -n "$SL_GIT_BRANCH" ]; then
    branch_room=$(( XMAS_PLAN_PATH_ROOM - 14 ))
    [ "$branch_room" -gt 28 ] && branch_room=28
    if [ "$branch_room" -ge 6 ]; then
      sl_trunc "$SL_GIT_BRANCH" "$branch_room"
      XMAS_PLAN_BRANCH="$SL_TRUNC"
      sl_width "$XMAS_PLAN_BRANCH"
      XMAS_PLAN_PATH_ROOM=$(( XMAS_PLAN_PATH_ROOM - SL_W - 5 ))
    fi
  fi
  return 0
}

xmas_data_row() {
  local budget="$1" gutter="$2"
  XMAS_LINE=""
  XMAS_LINE_WIDTH=0
  XMAS_LINE_BUDGET="$budget"
  xmas_context
  xmas_data_plan "$budget" "$XMAS_CONTEXT_TEXT"
  if [ "$XMAS_PLAN_PATH_ROOM" -lt 10 ] && [ -n "$XMAS_CONTEXT_SHORT" ]; then
    xmas_data_plan "$budget" "$XMAS_CONTEXT_SHORT"
  fi
  [ "$XMAS_PLAN_PATH_ROOM" -lt 6 ] && XMAS_PLAN_PATH_ROOM=6
  sl_path_fit "$XMAS_PLAN_PATH_ROOM"
  sl_width "$SL_PATH_FIT"
  xmas_paint path "$SL_PATH_FIT" 1
  xmas_append "$SL_W" "$XMAS_PAINT"
  if [ -n "$XMAS_PLAN_BRANCH" ]; then
    sl_width "$XMAS_PLAN_BRANCH"
    xmas_paint branch "⎇ $XMAS_PLAN_BRANCH"
    xmas_append $(( SL_W + 2 )) "$XMAS_PAINT"
  fi
  if [ -n "$XMAS_PLAN_CONTEXT" ]; then
    xmas_paint "$XMAS_CONTEXT_TONE" "$XMAS_PLAN_CONTEXT" 1
    xmas_append "${#XMAS_PLAN_CONTEXT}" "$XMAS_PAINT"
  fi
  if [ -n "$SL_COST_TEXT" ]; then
    xmas_paint cost "$SL_COST_TEXT" 1
    xmas_append "${#SL_COST_TEXT}" "$XMAS_PAINT"
  fi
  if [ -n "$XMAS_PLAN_MODEL" ]; then
    sl_width "$XMAS_PLAN_MODEL"
    xmas_paint model "$XMAS_PLAN_MODEL"
    xmas_append "$SL_W" "$XMAS_PAINT"
  fi
  if [ -n "$XMAS_PLAN_EFFORT" ]; then
    xmas_paint effort "$XMAS_PLAN_EFFORT"
    xmas_append $(( ${#SL_EFFORT} + 1 )) "$XMAS_PAINT"
  fi
  if [ -n "$gutter" ]; then
    xmas_paint gutter "$gutter"
    XMAS_LINE="$XMAS_PAINT$XMAS_LINE"
  fi
  return 0
}

xmas_compact() {
  local budget="$1"
  xmas_labels
  sl_path_fit "$budget"
  xmas_paint path "$SL_PATH_FIT" 1
  XMAS_COMPACT_TOP="$XMAS_PAINT"
  if [ -n "$SL_GIT_BRANCH" ]; then
    sl_width "$SL_PATH_FIT"
    if [ $(( budget - SL_W - 3 )) -ge 4 ]; then
      sl_trunc "$SL_GIT_BRANCH" $(( budget - SL_W - 3 ))
      xmas_paint separator ' · '
      XMAS_COMPACT_TOP="$XMAS_COMPACT_TOP$XMAS_PAINT"
      xmas_paint branch "$SL_TRUNC"
      XMAS_COMPACT_TOP="$XMAS_COMPACT_TOP$XMAS_PAINT"
    fi
  fi
  XMAS_LINE=""
  XMAS_LINE_WIDTH=0
  XMAS_LINE_BUDGET="$budget"
  xmas_paint "$XMAS_LABEL_TONE" "$XMAS_LABEL_SHORT" 1
  xmas_append "${#XMAS_LABEL_SHORT}" "$XMAS_PAINT"
  xmas_context
  if [ -n "$XMAS_CONTEXT_TEXT" ]; then
    xmas_paint "$XMAS_CONTEXT_TONE" "$XMAS_CONTEXT_TEXT" 1
    xmas_append "${#XMAS_CONTEXT_TEXT}" "$XMAS_PAINT"
  fi
  if [ -n "$SL_COST_TEXT" ]; then
    xmas_paint cost "$SL_COST_TEXT" 1
    xmas_append "${#SL_COST_TEXT}" "$XMAS_PAINT"
  fi
  if [ -n "$SL_MODEL_SHORT" ]; then
    sl_width "$SL_MODEL_SHORT"
    xmas_paint model "$SL_MODEL_SHORT"
    xmas_append "$SL_W" "$XMAS_PAINT"
  fi
  XMAS_COMPACT_BOTTOM="$XMAS_LINE"
  return 0
}

xmas_layout() {
  local spare extra
  XMAS_W="$SL_COLUMNS"
  [ "$SL_USE_COLOR" = "1" ] || XMAS_W=$(( SL_COLUMNS - 1 ))
  if [ "$XMAS_W" -ge 110 ]; then
    XMAS_PX=14
  elif [ "$XMAS_W" -ge 92 ]; then
    XMAS_PX=12
  elif [ "$XMAS_W" -ge 74 ]; then
    XMAS_PX=10
  elif [ "$XMAS_W" -ge 58 ]; then
    XMAS_PX=8
  elif [ "$XMAS_W" -ge 44 ]; then
    XMAS_PX=6
  else
    XMAS_PX=4
  fi
  if [ "$XMAS_W" -ge "$XMAS_MIN_WIDE_STRIP_COLUMNS" ]; then
    XMAS_WIDE=1
    XMAS_STRIP_LEFT=$(( XMAS_W - XMAS_WIDE_STRIP_CELLS ))
  else
    XMAS_WIDE=0
    XMAS_STRIP_LEFT=$(( XMAS_W - XMAS_COMPACT_STRIP_CELLS ))
  fi
  XMAS_TERRACE_LEFT="$XMAS_STRIP_LEFT"
  if [ "$XMAS_PX" -ge 8 ]; then
    spare=$(( XMAS_STRIP_LEFT - XMAS_MIN_STREET_COLUMNS ))
    if [ "$spare" -gt 0 ]; then
      extra=$(( spare / XMAS_HOUSE_STRIDE ))
      [ "$extra" -gt "$XMAS_MAX_EXTRA_HOUSES" ] && extra="$XMAS_MAX_EXTRA_HOUSES"
      XMAS_TERRACE_LEFT=$(( XMAS_STRIP_LEFT - extra * XMAS_HOUSE_STRIDE ))
    fi
  fi
  XMAS_STREET_RIGHT=$(( XMAS_TERRACE_LEFT - 2 ))
  XMAS_TERRACE_SLOTS=$(( (XMAS_W - XMAS_TERRACE_LEFT + XMAS_HOUSE_STRIDE - 1) / XMAS_HOUSE_STRIDE ))
  XMAS_STEEPLE_SLOT=-1
  if [ "$XMAS_PX" -ge 12 ] && [ "$XMAS_TERRACE_SLOTS" -ge 2 ]; then
    xmas_hash "$XMAS_TERRACE_SLOTS" 404
    XMAS_STEEPLE_SLOT=$(( XMAS_HASH % (XMAS_TERRACE_SLOTS - 1) ))
  fi
  if [ "$XMAS_PX" -ge 6 ]; then
    XMAS_DRIFT_RIGHT="$XMAS_STREET_RIGHT"
  else
    XMAS_DRIFT_RIGHT=$(( XMAS_W - 1 ))
  fi
  XMAS_CONIFER_LEFT=1
  XMAS_WARM_LEFT=0
  XMAS_WARM_RIGHT=-1
  return 0
}

sl_render() {
  local row rows

  sl_git
  xmas_season "$SL_NOW"
  xmas_pulse

  if [ "$SL_COLUMNS" -lt "$XMAS_MIN_SCENE_COLUMNS" ]; then
    xmas_compact "$SL_COLUMNS"
    sl_emit "$XMAS_COMPACT_TOP"
    [ -n "$XMAS_COMPACT_BOTTOM" ] && sl_emit "$XMAS_COMPACT_BOTTOM"
    return 0
  fi

  xmas_layout
  xmas_plan
  XMAS_PIX=()
  xmas_stars
  xmas_moon
  xmas_terrace
  xmas_smoke
  xmas_conifers
  xmas_drift
  xmas_foreground
  xmas_snow

  rows=$(( XMAS_PX / 2 ))
  for (( row = 0; row < rows; row++ )); do
    xmas_row_render "$row"
    sl_emit_raw "$XMAS_ROW"
  done

  xmas_advent_row "$XMAS_WIDE"
  sl_emit_raw "$XMAS_ADVENT_ROW"
  xmas_data_row $(( SL_COLUMNS - 2 )) '▌ '
  sl_emit "$XMAS_LINE"
  return 0
}
