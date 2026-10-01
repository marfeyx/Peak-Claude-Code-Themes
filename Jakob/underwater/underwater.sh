#!/usr/bin/env bash
# @name: underwater
# @description: Reef scene — fish, squid, jellyfish and kelp over the readout
# @order: 18

# A cell grid painted bottom-up: waterline, open water, seabed, then the data
# row. Open water is deliberately unpainted so the terminal's own translucent
# tint shows through. Every position, frame and bubble is a pure function of
# SL_NOW, so two renders of the same second are identical.

REEF_CYCLE_SECONDS=153
REEF_BUBBLE_PERIOD=3
REEF_BUBBLE_LIFE=17
REEF_BUBBLE_DRAG=72
REEF_SWAY_SECONDS=13
REEF_SURFACE_SECONDS=29
REEF_JELLY_SECONDS=6
REEF_MIN_SCENE_COLUMNS=36
REEF_MIN_JELLY_COLUMNS=70
REEF_KELP_DENSITY=30
REEF_KELP_SPACING=9

REEF_RUNS=(
  '0|34|0|grouper|1' '37|18|1|minnow|1' '57|22|0|snapper|1'
  '81|18|1|minnow|3' '101|26|0|squid|1' '129|22|1|manta|2'
)

REEF_CLOWN_BODY=('...ddFFFFFF.........' 'ddddwwkdddwwkdd.....' '.ddowwkooowwkooked..' 'dooowwkooowwkooopodm' 'looowwkooowwkooooomm' 'lllowwkooowwkfflll..' 'llllwwklllwwffl.....' '...FFFFFFF..........')
REEF_CLOWN_TAIL0=('tttt' '.ttt' '..tt' '...t' '...t' '..tt' '.ttt' 'tttt')
REEF_CLOWN_TAIL1=('....' 'tttt' '.ttt' '..tt' '..tt' '.ttt' 'tttt' '....')
REEF_CLOWN_TAIL2=('.ttt' '..tt' '...t' '...t' '...t' '...t' '..tt' '.ttt')

REEF_SNAPPER_BODY=(
  '...ddwkdddd....'
  '.ddoowkooooddd.'
  'doooowkoookeoom'
  'loooowkoooopoom'
  '.lloowkoooolll.'
  '...llwkllll....'
)
REEF_SNAPPER_TAIL0=('ttt' '.tt' '..t' '..t' '.tt' 'ttt')
REEF_SNAPPER_TAIL1=('.tt' '.tt' 'ttt' 'ttt' '.tt' '.tt')
REEF_SNAPPER_TAIL2=('..t' 'ttt' '.tt' '.tt' 'ttt' '..t')

REEF_MINNOW_BODY=('..ddddd.' 'ddooooed' 'lloooopl' '..lllll.')
REEF_MINNOW_TAIL0=('tt.' '.tt' '.tt' 'tt.')
REEF_MINNOW_TAIL1=('.t.' 'tt.' 'tt.' '.t.')

REEF_SQUID_MANTLE=(
  '...FF.........'
  '..FFFdddd.....'
  '.FFFdoooodked.'
  'FFFdooooooopod'
  'FFFloooooooool'
  '.FFFloooollll.'
  '..FFFllll.....'
  '...FF.........'
)
REEF_SQUID_ARMS0=('....' '..A.' 'AA.A' 'AAAA' 'AAAA' 'AA.A' '.A.A' '..A.')
REEF_SQUID_ARMS1=('..A.' '.A.A' 'AAA.' 'AAAA' 'AAAA' 'AAA.' '.A.A' '..A.')
REEF_SQUID_ARMS2=('....' 'A..A' '.AA.' 'AAAA' 'AAAA' '.AA.' 'A..A' '.A..')

REEF_MANTA0=(
  '......dddddd..........'
  '...dddoooooodddd......'
  'ttttoooooooooooodkeddf'
  'ttttoooooooooooollpllf'
  '...llloooooollll......'
  '......llllll..........'
)
REEF_MANTA1=(
  '.......dddd...........'
  '....dddooooddd........'
  'ttttoooooooooodddkeddf'
  'ttttoooooooooollllpllf'
  '....llloooolll........'
  '.......llll...........'
)

REEF_JELLY_BELL0=('....BBBB....' '..BBBBBBBB..' '.BBBBBBBBBB.' '.BCCCCCCCCB.')
REEF_JELLY_BELL1=('.....BB.....' '...BBBBBB...' '..BBBBBBBB..' '..BCCCCCCB..')
REEF_JELLY_ARMS0=('..t..tt..t..' '..t..tt..t..' '.t...tt...t.' '.t...tt...t.')
REEF_JELLY_ARMS1=('..t..tt..t..' '..t..tt..t..' '..t..tt..t..' '..t..tt..t..')
REEF_JELLY_ARMS2=('..t..tt..t..' '..t..tt..t..' '...t.tt.t...' '...t.tt.t...')

REEF_KELP_A=(' █ ' ' █ ' ' █ ' ' ▀ ' '   ')
REEF_KELP_B=(' █ ' '▄█ ' ' █▄' ' ▀ ' '   ')
REEF_KELP_C=(' █ ' ' █▄' ' █ ' ' ▀ ' '   ')
REEF_KELP_D=(' █ ' '▄█ ' ' █ ' ' ▀ ' '   ')
REEF_KELP_E=(' █ ' ' █ ' '▄█▄' ' ▀ ' '   ')

declare -gA REEF_SGR_CACHE=()

reef_rgb() {
  case "$1" in
    clown_tail) REEF_RGB='255;146;46' ;;
    clown_fin) REEF_RGB='255;176;92' ;;
    clown_back) REEF_RGB='198;80;12' ;;
    clown_body) REEF_RGB='246;126;22' ;;
    clown_belly) REEF_RGB='255;178;104' ;;
    clown_band) REEF_RGB='250;250;244' ;;
    clown_edge) REEF_RGB='24;18;20' ;;
    clown_lip) REEF_RGB='255;208;150' ;;
    snapper_tail) REEF_RGB='255;104;158' ;;
    snapper_fin) REEF_RGB='255;150;192' ;;
    snapper_back) REEF_RGB='186;28;92' ;;
    snapper_body) REEF_RGB='238;66;132' ;;
    snapper_belly) REEF_RGB='255;158;196' ;;
    snapper_band) REEF_RGB='252;246;250' ;;
    snapper_edge) REEF_RGB='26;14;22' ;;
    snapper_lip) REEF_RGB='255;196;214' ;;
    minnow_tail) REEF_RGB='255;236;120' ;;
    minnow_back) REEF_RGB='202;170;22' ;;
    minnow_body) REEF_RGB='248;220;56' ;;
    minnow_belly) REEF_RGB='255;246;168' ;;
    squid_fin) REEF_RGB='236;178;255' ;;
    squid_arm) REEF_RGB='212;134;242' ;;
    squid_back) REEF_RGB='148;56;196' ;;
    squid_body) REEF_RGB='190;96;230' ;;
    squid_belly) REEF_RGB='226;162;250' ;;
    squid_edge) REEF_RGB='30;16;38' ;;
    manta_tail) REEF_RGB='150;168;204' ;;
    manta_fin) REEF_RGB='226;238;252' ;;
    manta_back) REEF_RGB='92;112;152' ;;
    manta_body) REEF_RGB='168;190;226' ;;
    manta_belly) REEF_RGB='236;244;255' ;;
    manta_edge) REEF_RGB='20;24;34' ;;
    eye_light) REEF_RGB='255;255;250' ;;
    eye_dark) REEF_RGB='12;10;14' ;;
    jelly_bell) REEF_RGB='255;168;214' ;;
    jelly_rim) REEF_RGB='255;214;238' ;;
    jelly_arm) REEF_RGB='244;154;206' ;;
    ink) REEF_RGB='58;66;92' ;;
    bubble_a) REEF_RGB='140;205;220' ;;
    bubble_b) REEF_RGB='170;225;238' ;;
    bubble_c) REEF_RGB='200;242;250' ;;
    bubble_d) REEF_RGB='228;252;255' ;;
    kelp_deep) REEF_RGB='26;104;74' ;;
    kelp) REEF_RGB='40;148;92' ;;
    kelp_light) REEF_RGB='92;192;116' ;;
    kelp_tip) REEF_RGB='158;220;128' ;;
    kelp_blade) REEF_RGB='58;150;104' ;;
    kelp_frond) REEF_RGB='120;200;132' ;;
    sand) REEF_RGB='74;104;104' ;;
    dune) REEF_RGB='96;126;122' ;;
    pebble) REEF_RGB='142;162;154' ;;
    surface) REEF_RGB='96;168;186' ;;
    surface_lit) REEF_RGB='150;220;232' ;;
    path) REEF_RGB='168;240;250' ;;
    branch) REEF_RGB='95;240;216' ;;
    value) REEF_RGB='208;250;255' ;;
    cost) REEF_RGB='255;206;138' ;;
    model) REEF_RGB='124;176;192' ;;
    faint) REEF_RGB='70;112;124' ;;
    warn) REEF_RGB='255;138;156' ;;
    caution) REEF_RGB='240;206;133' ;;
    good) REEF_RGB='106;226;176' ;;
    *) REEF_RGB='120;160;170' ;;
  esac
}

reef_sgr() {
  if [ "$SL_USE_COLOR" != "1" ]; then
    REEF_SGR=""
    return
  fi
  local key="$1:$2:${3:-}"
  if [ -n "${REEF_SGR_CACHE[$key]:-}" ]; then
    REEF_SGR="${REEF_SGR_CACHE[$key]}"
    return
  fi
  local weight='0' foreground background=''
  [ "$2" = "1" ] && weight='0;1'
  reef_rgb "$1"
  foreground="$REEF_RGB"
  if [ -n "${3:-}" ]; then
    reef_rgb "$3"
    background="$REEF_RGB"
  fi
  if [ -n "$background" ]; then
    printf -v REEF_SGR '%s[%s;38;2;%s;48;2;%sm' "$SL_ESC" "$weight" "$foreground" "$background"
  else
    printf -v REEF_SGR '%s[%s;38;2;%sm' "$SL_ESC" "$weight" "$foreground"
  fi
  REEF_SGR_CACHE["$key"]="$REEF_SGR"
}

reef_paint() {
  reef_sgr "$1" "${3:-0}"
  REEF_PAINT="$REEF_SGR$2$SL_RESET"
}

reef_hash() {
  local mixed=$(( ( ($1 + $2) * 2654435761 ) & 0xFFFFFFFF ))
  mixed=$(( (mixed ^ (mixed >> 13)) & 0xFFFFFFFF ))
  mixed=$(( (mixed * 1274126177) & 0xFFFFFFFF ))
  REEF_HASH=$(( (mixed ^ (mixed >> 16)) & 0xFFFF ))
}

reef_phase() {
  local cycle_seconds="$1"
  REEF_PHASE=$(( SL_NOW * 1024 / cycle_seconds % 1024 ))
}

reef_grid_reset() {
  local total=$(( REEF_W * REEF_H )) index
  REEF_G=()
  REEF_T=()
  REEF_O=()
  REEF_L=()
  REEF_B=()
  for (( index = 0; index < total; index++ )); do
    REEF_G[index]=' '
    REEF_T[index]='faint'
    REEF_O[index]='0'
    REEF_L[index]='0'
    REEF_B[index]=''
  done
}

reef_put() {
  local row="$1" column="$2" index
  [ "$row" -ge 0 ] && [ "$row" -lt "$REEF_H" ] || return 0
  [ "$column" -ge 0 ] && [ "$column" -lt "$REEF_W" ] || return 0
  index=$(( row * REEF_W + column ))
  REEF_G[index]="$4"
  REEF_T[index]="$3"
  REEF_O[index]="${5:-0}"
  REEF_L[index]="${6:-1}"
  REEF_B[index]="${7:-}"
}

reef_clear_creature() {
  local row="$1" column="$2" index
  [ "$row" -ge 0 ] && [ "$row" -lt "$REEF_H" ] || return 0
  [ "$column" -ge 0 ] && [ "$column" -lt "$REEF_W" ] || return 0
  index=$(( row * REEF_W + column ))
  [ "${REEF_L[index]}" = "2" ] || return 0
  REEF_G[index]=' '
  REEF_T[index]='faint'
  REEF_O[index]='0'
  REEF_L[index]='0'
  REEF_B[index]=''
}

reef_put_empty() {
  local row="$1" column="$2" index
  [ "$row" -ge 0 ] && [ "$row" -lt "$REEF_H" ] || return 0
  [ "$column" -ge 0 ] && [ "$column" -lt "$REEF_W" ] || return 0
  index=$(( row * REEF_W + column ))
  [ "${REEF_G[index]}" = " " ] || return 0
  REEF_G[index]="$4"
  REEF_T[index]="$3"
  REEF_O[index]="${5:-0}"
  REEF_B[index]=''
}

reef_species() {
  case "$1" in
    grouper) REEF_SW=24; REEF_SH=4; REEF_SLACK=0; REEF_SEQ='0 1 0 2'; REEF_VENTS=1 ;;
    snapper) REEF_SW=18; REEF_SH=3; REEF_SLACK=1; REEF_SEQ='0 1 0 2'; REEF_VENTS=1 ;;
    minnow) REEF_SW=11; REEF_SH=2; REEF_SLACK=1; REEF_SEQ='0 1'; REEF_VENTS=0 ;;
    squid) REEF_SW=18; REEF_SH=4; REEF_SLACK=0; REEF_SEQ='0 1 2'; REEF_VENTS=1 ;;
    *) REEF_SW=22; REEF_SH=3; REEF_SLACK=0; REEF_SEQ='0 1'; REEF_VENTS=0 ;;
  esac
}

reef_art() {
  local species="$1" frame="$2" row
  REEF_ART=()
  case "$species" in
    grouper)
      for (( row = 0; row < 8; row++ )); do
        case "$frame" in
          1) REEF_ART+=("${REEF_CLOWN_TAIL1[row]}${REEF_CLOWN_BODY[row]}") ;;
          2) REEF_ART+=("${REEF_CLOWN_TAIL2[row]}${REEF_CLOWN_BODY[row]}") ;;
          *) REEF_ART+=("${REEF_CLOWN_TAIL0[row]}${REEF_CLOWN_BODY[row]}") ;;
        esac
      done
      ;;
    snapper)
      for (( row = 0; row < 6; row++ )); do
        case "$frame" in
          1) REEF_ART+=("${REEF_SNAPPER_TAIL1[row]}${REEF_SNAPPER_BODY[row]}") ;;
          2) REEF_ART+=("${REEF_SNAPPER_TAIL2[row]}${REEF_SNAPPER_BODY[row]}") ;;
          *) REEF_ART+=("${REEF_SNAPPER_TAIL0[row]}${REEF_SNAPPER_BODY[row]}") ;;
        esac
      done
      ;;
    minnow)
      for (( row = 0; row < 4; row++ )); do
        if [ "$frame" = "1" ]; then
          REEF_ART+=("${REEF_MINNOW_TAIL1[row]}${REEF_MINNOW_BODY[row]}")
        else
          REEF_ART+=("${REEF_MINNOW_TAIL0[row]}${REEF_MINNOW_BODY[row]}")
        fi
      done
      ;;
    squid)
      for (( row = 0; row < 8; row++ )); do
        case "$frame" in
          1) REEF_ART+=("${REEF_SQUID_MANTLE[row]}${REEF_SQUID_ARMS1[row]}") ;;
          2) REEF_ART+=("${REEF_SQUID_MANTLE[row]}${REEF_SQUID_ARMS2[row]}") ;;
          *) REEF_ART+=("${REEF_SQUID_MANTLE[row]}${REEF_SQUID_ARMS0[row]}") ;;
        esac
      done
      ;;
    *)
      if [ "$frame" = "1" ]; then
        REEF_ART=("${REEF_MANTA1[@]}")
      else
        REEF_ART=("${REEF_MANTA0[@]}")
      fi
      ;;
  esac
}

reef_cell_tone() {
  local species="$1" code="$2"
  REEF_CELL_BOLD=0
  case "$species" in
    grouper)
      case "$code" in
        t) REEF_CELL_TONE=clown_tail ;;
        F) REEF_CELL_TONE=clown_fin ;;
        f) REEF_CELL_TONE=clown_fin ;;
        d) REEF_CELL_TONE=clown_back ;;
        l) REEF_CELL_TONE=clown_belly ;;
        w) REEF_CELL_TONE=clown_band; REEF_CELL_BOLD=1 ;;
        k) REEF_CELL_TONE=clown_edge ;;
        m) REEF_CELL_TONE=clown_lip ;;
        e) REEF_CELL_TONE=eye_light; REEF_CELL_BOLD=1 ;;
        p) REEF_CELL_TONE=eye_dark ;;
        *) REEF_CELL_TONE=clown_body ;;
      esac
      ;;
    snapper)
      case "$code" in
        t) REEF_CELL_TONE=snapper_tail ;;
        F) REEF_CELL_TONE=snapper_fin ;;
        f) REEF_CELL_TONE=snapper_fin ;;
        d) REEF_CELL_TONE=snapper_back ;;
        l) REEF_CELL_TONE=snapper_belly ;;
        w) REEF_CELL_TONE=snapper_band; REEF_CELL_BOLD=1 ;;
        k) REEF_CELL_TONE=snapper_edge ;;
        m) REEF_CELL_TONE=snapper_lip ;;
        e) REEF_CELL_TONE=eye_light; REEF_CELL_BOLD=1 ;;
        p) REEF_CELL_TONE=eye_dark ;;
        *) REEF_CELL_TONE=snapper_body ;;
      esac
      ;;
    minnow)
      case "$code" in
        t) REEF_CELL_TONE=minnow_tail ;;
        d) REEF_CELL_TONE=minnow_back ;;
        l) REEF_CELL_TONE=minnow_belly ;;
        e) REEF_CELL_TONE=eye_light; REEF_CELL_BOLD=1 ;;
        p) REEF_CELL_TONE=eye_dark ;;
        *) REEF_CELL_TONE=minnow_body ;;
      esac
      ;;
    squid)
      case "$code" in
        F) REEF_CELL_TONE=squid_fin ;;
        A) REEF_CELL_TONE=squid_arm ;;
        d) REEF_CELL_TONE=squid_back ;;
        l) REEF_CELL_TONE=squid_belly ;;
        k) REEF_CELL_TONE=squid_edge ;;
        e) REEF_CELL_TONE=eye_light; REEF_CELL_BOLD=1 ;;
        p) REEF_CELL_TONE=eye_dark ;;
        *) REEF_CELL_TONE=squid_body ;;
      esac
      ;;
    jelly)
      case "$code" in
        C) REEF_CELL_TONE=jelly_rim ;;
        t) REEF_CELL_TONE=jelly_arm ;;
        *) REEF_CELL_TONE=jelly_bell ;;
      esac
      ;;
    *)
      case "$code" in
        t) REEF_CELL_TONE=manta_tail ;;
        f) REEF_CELL_TONE=manta_fin ;;
        d) REEF_CELL_TONE=manta_back ;;
        l) REEF_CELL_TONE=manta_belly ;;
        k) REEF_CELL_TONE=manta_edge ;;
        e) REEF_CELL_TONE=eye_light; REEF_CELL_BOLD=1 ;;
        p) REEF_CELL_TONE=eye_dark ;;
        *) REEF_CELL_TONE=manta_body ;;
      esac
      ;;
  esac
}

reef_pack() {
  local species="$1" upper="$2" lower="$3"
  local top_tone='' top_bold=0 bottom_tone='' bottom_bold=0
  if [ -n "$upper" ] && [ "$upper" != "." ] && [ "$upper" != " " ]; then
    reef_cell_tone "$species" "$upper"
    top_tone="$REEF_CELL_TONE"
    top_bold="$REEF_CELL_BOLD"
  fi
  if [ -n "$lower" ] && [ "$lower" != "." ] && [ "$lower" != " " ]; then
    reef_cell_tone "$species" "$lower"
    bottom_tone="$REEF_CELL_TONE"
    bottom_bold="$REEF_CELL_BOLD"
  fi
  REEF_PACK_B=''
  if [ -z "$top_tone" ] && [ -z "$bottom_tone" ]; then
    REEF_PACK_G=' '
    REEF_PACK_T='faint'
    REEF_PACK_O='0'
    return
  fi
  if [ -z "$bottom_tone" ]; then
    REEF_PACK_G='▀'
    REEF_PACK_T="$top_tone"
    REEF_PACK_O="$top_bold"
    return
  fi
  if [ -z "$top_tone" ]; then
    REEF_PACK_G='▄'
    REEF_PACK_T="$bottom_tone"
    REEF_PACK_O="$bottom_bold"
    return
  fi
  if [ "$top_tone" = "$bottom_tone" ]; then
    REEF_PACK_G='█'
    REEF_PACK_T="$top_tone"
    REEF_PACK_O="$top_bold"
    return
  fi
  REEF_PACK_G='▀'
  REEF_PACK_T="$top_tone"
  REEF_PACK_O="$top_bold"
  REEF_PACK_B="$bottom_tone"
}

reef_compose() {
  local species="$1" frame="$2" mirrored="$3"
  local row column source upper lower top_code bottom_code
  reef_art "$species" "$frame"
  REEF_CG=()
  REEF_CT=()
  REEF_CO=()
  REEF_CB=()
  for (( row = 0; row < REEF_SH; row++ )); do
    upper="${REEF_ART[row * 2]}"
    lower="${REEF_ART[row * 2 + 1]}"
    for (( column = 0; column < REEF_SW; column++ )); do
      source=$column
      [ "$mirrored" = "1" ] && source=$(( REEF_SW - 1 - column ))
      top_code="${upper:source:1}"
      bottom_code="${lower:source:1}"
      reef_pack "$species" "$top_code" "$bottom_code"
      REEF_CG+=("$REEF_PACK_G")
      REEF_CT+=("$REEF_PACK_T")
      REEF_CO+=("$REEF_PACK_O")
      REEF_CB+=("$REEF_PACK_B")
    done
  done
}

reef_stamp_sprite() {
  local top="$1" left="$2" row column index
  for (( row = 0; row < REEF_SH; row++ )); do
    for (( column = 0; column < REEF_SW; column++ )); do
      index=$(( row * REEF_SW + column ))
      if [ "${REEF_CG[index]}" = " " ]; then
        reef_clear_creature $(( top + row )) $(( left + column ))
        continue
      fi
      reef_put $(( top + row )) $(( left + column )) "${REEF_CT[index]}" "${REEF_CG[index]}" \
        "${REEF_CO[index]}" 2 "${REEF_CB[index]}"
    done
  done
}

reef_band_top() {
  local band="$1" height="$2" slack="$3" left="$4" salt="$5" ceiling floor top
  local swing
  ceiling=$(( REEF_SAND_ROW - height + 1 ))
  [ "$ceiling" -lt 1 ] && ceiling=1
  floor="$band"
  if [ "$band" -ge 2 ]; then
    floor=$(( band - slack ))
    [ "$floor" -lt 2 ] && floor=2
  fi
  top="$band"
  if [ "$slack" -gt 0 ]; then
    swing="$left"
    [ "$swing" -lt 0 ] && swing=$(( -swing ))
    sl_cos $(( swing * 70 + salt * 131 ))
    top=$(( band + SL_COS * slack / 1000 ))
  fi
  [ "$top" -lt "$floor" ] && top="$floor"
  [ "$top" -gt "$ceiling" ] && top="$ceiling"
  [ "$top" -lt 1 ] && top=1
  REEF_TOP="$top"
}

reef_bubbles() {
  local start="$1" direction="$2" vent_column="$3" vent_row="$4" speed="$5" elapsed="$6"
  local slot first_slot last_slot released age row column sign tone glyph
  sign=1
  [ "$direction" = "1" ] && sign=-1
  first_slot=$(( (SL_NOW - REEF_BUBBLE_LIFE) / REEF_BUBBLE_PERIOD ))
  last_slot=$(( SL_NOW / REEF_BUBBLE_PERIOD ))
  for (( slot = first_slot; slot <= last_slot; slot++ )); do
    released=$(( slot * REEF_BUBBLE_PERIOD + start % REEF_BUBBLE_PERIOD ))
    age=$(( SL_NOW - released ))
    [ "$age" -ge 0 ] && [ "$age" -le "$REEF_BUBBLE_LIFE" ] || continue
    [ "$age" -le "$elapsed" ] || continue
    row=$(( vent_row - age / 3 ))
    [ "$row" -ge 0 ] || continue
    column=$(( vent_column - sign * speed * age * REEF_BUBBLE_DRAG / 10000 ))
    sl_cos $(( age * 150 + start * 64 ))
    column=$(( column + SL_COS / 650 ))
    if [ "$age" -le 2 ]; then
      tone=bubble_a
      glyph='.'
    elif [ "$age" -le 7 ]; then
      tone=bubble_b
      glyph='o'
    elif [ "$age" -le 13 ]; then
      tone=bubble_c
      glyph='○'
    else
      tone=bubble_d
      glyph='○'
    fi
    reef_put_empty "$row" "$column" "$tone" "$glyph"
  done
}

reef_ink() {
  local left="$1" direction="$2" top="$3" elapsed="$4" column row
  [ $(( (elapsed + SL_NOW) % 11 )) -lt 2 ] || return 0
  if [ "$direction" = "1" ]; then
    column=$(( left + REEF_SW ))
  else
    column=$(( left - 3 ))
  fi
  row=$(( top + 1 ))
  reef_put_empty "$row" "$column" ink '▄'
  reef_put_empty "$row" $(( column + 1 )) ink '█'
  reef_put_empty "$row" $(( column + 2 )) ink '▄'
  reef_put_empty $(( row + 1 )) "$column" ink '▀'
  reef_put_empty $(( row + 1 )) $(( column + 1 )) ink '▀'
}

reef_run_minnows() {
  local top="$1" left="$2" offsets=(0 -14 -27) rows=(0 1 -1) index target ceiling
  ceiling=$(( REEF_SAND_ROW - REEF_SH ))
  [ "$ceiling" -lt 1 ] && ceiling=1
  for (( index = 0; index < 3; index++ )); do
    target=$(( top + rows[index] ))
    [ "$target" -gt "$ceiling" ] && target="$ceiling"
    [ "$target" -lt 1 ] && target=1
    reef_stamp_sprite "$target" $(( left + offsets[index] ))
  done
}

reef_traffic() {
  local cycle_second run entry start duration direction species band
  local distance progress left frames frame elapsed speed vent_column vent_row
  local -a sequence=()
  cycle_second=$(( SL_NOW % REEF_CYCLE_SECONDS ))
  for run in "${REEF_RUNS[@]}"; do
    start="${run%%|*}"
    entry="${run#*|}"
    duration="${entry%%|*}"
    entry="${entry#*|}"
    direction="${entry%%|*}"
    entry="${entry#*|}"
    species="${entry%%|*}"
    band="${entry##*|}"
    [ "$cycle_second" -ge "$start" ] || continue
    [ "$cycle_second" -lt $(( start + duration )) ] || continue
    reef_species "$species"
    [ "$REEF_SH" -le "$REEF_SAND_ROW" ] || continue
    distance=$(( REEF_W + REEF_SW ))
    elapsed=$(( cycle_second - start ))
    progress=$(( elapsed * distance / duration ))
    if [ "$direction" = "0" ]; then
      left=$(( progress - REEF_SW ))
    else
      left=$(( REEF_W - progress ))
    fi
    read -ra sequence <<< "$REEF_SEQ"
    frames="${#sequence[@]}"
    frame="${sequence[(SL_NOW + start) % frames]}"
    reef_band_top "$band" "$REEF_SH" "$REEF_SLACK" "$left" "$start"
    reef_compose "$species" "$frame" "$direction"
    [ "$species" = "squid" ] && reef_ink "$left" "$direction" "$REEF_TOP" "$elapsed"
    if [ "$species" = "minnow" ]; then
      reef_run_minnows "$REEF_TOP" "$left"
    else
      reef_stamp_sprite "$REEF_TOP" "$left"
    fi
    [ "$REEF_VENTS" = "1" ] || continue
    speed=$(( distance * 100 / duration ))
    vent_row=$(( REEF_TOP + REEF_SH / 2 ))
    if [ "$direction" = "0" ]; then
      vent_column=$(( left + REEF_SW - 2 ))
    else
      vent_column=$(( left + 1 ))
    fi
    reef_bubbles "$start" "$direction" "$vent_column" "$vent_row" "$speed" "$elapsed"
  done
}

reef_jellyfish() {
  local step span top column row index pulse arms upper lower
  local -a lines=()
  [ "$REEF_W" -ge "$REEF_MIN_JELLY_COLUMNS" ] || return 0
  [ "$REEF_SAND_ROW" -ge 4 ] || return 0
  span=$(( REEF_SAND_ROW - 3 ))
  [ "$span" -ge 1 ] || return 0
  step=$(( SL_NOW / REEF_JELLY_SECONDS % span ))
  top=$(( REEF_SAND_ROW - 4 - step ))
  [ "$top" -lt 0 ] && top=0
  reef_phase 47
  sl_cos $(( REEF_PHASE + 200 ))
  column=$(( REEF_W * 3 / 4 + SL_COS * 3 / 1000 ))
  pulse=$(( SL_NOW % 2 ))
  arms=$(( SL_NOW % 3 ))
  if [ "$pulse" -eq 1 ]; then
    lines=("${REEF_JELLY_BELL1[@]}")
  else
    lines=("${REEF_JELLY_BELL0[@]}")
  fi
  case "$arms" in
    1) lines+=("${REEF_JELLY_ARMS1[@]}") ;;
    2) lines+=("${REEF_JELLY_ARMS2[@]}") ;;
    *) lines+=("${REEF_JELLY_ARMS0[@]}") ;;
  esac
  for (( row = 0; row < 4; row++ )); do
    upper="${lines[row * 2]}"
    lower="${lines[row * 2 + 1]}"
    for (( index = 0; index < 12; index++ )); do
      reef_pack jelly "${upper:index:1}" "${lower:index:1}"
      [ "$REEF_PACK_G" = " " ] && continue
      reef_put $(( top + row )) $(( column + index )) "$REEF_PACK_T" "$REEF_PACK_G" \
        "$REEF_PACK_O" 2 "$REEF_PACK_B"
    done
  done
}

reef_frond_tone() {
  local level="$1" is_stalk="$2"
  if [ "$is_stalk" = "1" ]; then
    case "$level" in
      0) REEF_FROND_TONE=kelp_deep ;;
      1|2) REEF_FROND_TONE=kelp ;;
      3) REEF_FROND_TONE=kelp_light ;;
      *) REEF_FROND_TONE=kelp_tip ;;
    esac
    return
  fi
  case "$level" in
    0) REEF_FROND_TONE=kelp_deep ;;
    1|2) REEF_FROND_TONE=kelp_blade ;;
    3) REEF_FROND_TONE=kelp_frond ;;
    *) REEF_FROND_TONE=kelp_tip ;;
  esac
}

reef_kelp() {
  local column last_column height level index variant anchor_phase bend offset row
  local glyph line
  reef_phase "$REEF_SWAY_SECONDS"
  last_column=-99
  for (( column = 1; column < REEF_W - 1; column++ )); do
    [ $(( column - last_column )) -ge "$REEF_KELP_SPACING" ] || continue
    reef_hash "$column" 101
    [ $(( REEF_HASH % 100 )) -lt "$REEF_KELP_DENSITY" ] || continue
    reef_hash "$column" 7
    height=$(( 2 + REEF_HASH % 3 ))
    variant=$(( REEF_HASH / 4 % 5 ))
    [ "$height" -gt "$REEF_SAND_ROW" ] && height="$REEF_SAND_ROW"
    [ "$height" -ge 2 ] || continue
    last_column="$column"
    reef_hash "$column" 19
    anchor_phase=$(( REEF_HASH % 1024 ))
    sl_cos $(( REEF_PHASE + anchor_phase ))
    bend="$SL_COS"
    for (( level = 0; level < height; level++ )); do
      row=$(( REEF_SAND_ROW - level ))
      [ "$row" -ge 0 ] || break
      offset=$(( bend * level * 3 / 4000 ))
      case "$variant" in
        0) line="${REEF_KELP_A[level]}" ;;
        1) line="${REEF_KELP_B[level]}" ;;
        2) line="${REEF_KELP_C[level]}" ;;
        3) line="${REEF_KELP_D[level]}" ;;
        *) line="${REEF_KELP_E[level]}" ;;
      esac
      for (( index = 0; index < 3; index++ )); do
        glyph="${line:index:1}"
        [ "$glyph" = " " ] && continue
        if [ "$index" -eq 1 ]; then
          reef_frond_tone "$level" 1
        else
          reef_frond_tone "$level" 0
        fi
        reef_put "$row" $(( column + offset + index - 1 )) "$REEF_FROND_TONE" "$glyph"
      done
    done
  done
}

reef_seabed() {
  local column tone glyph
  for (( column = 0; column < REEF_W; column++ )); do
    reef_hash "$column" 31
    case $(( REEF_HASH % 23 )) in
      0|1) tone=dune; glyph='▂' ;;
      2) tone=pebble; glyph='▖' ;;
      *) tone=sand; glyph='▁' ;;
    esac
    reef_put "$REEF_SAND_ROW" "$column" "$tone" "$glyph"
  done
}

reef_waterline() {
  local column
  reef_phase "$REEF_SURFACE_SECONDS"
  for (( column = 0; column < REEF_W; column++ )); do
    reef_hash "$column" 53
    [ $(( REEF_HASH % 4 )) -eq 0 ] && continue
    sl_cos $(( column * 97 + REEF_PHASE ))
    if [ "$SL_COS" -gt 760 ]; then
      reef_put 0 "$column" surface_lit '~'
    elif [ "$SL_COS" -lt -760 ]; then
      reef_put 0 "$column" surface '_'
    fi
  done
}

reef_row_render() {
  local row="$1" base last column index state="" output=""
  base=$(( row * REEF_W ))
  last=-1
  for (( column = 0; column < REEF_W; column++ )); do
    [ "${REEF_G[base + column]}" = " " ] || last="$column"
  done
  if [ "$last" -lt 0 ]; then
    REEF_ROW=""
    return
  fi
  for (( column = 0; column <= last; column++ )); do
    index=$(( base + column ))
    if [ "${REEF_G[index]}" = " " ]; then
      if [ -n "$state" ]; then
        output="$output$SL_RESET"
        state=""
      fi
      output="$output "
      continue
    fi
    reef_sgr "${REEF_T[index]}" "${REEF_O[index]}" "${REEF_B[index]}"
    if [ "$REEF_SGR" != "$state" ]; then
      output="$output$REEF_SGR"
      state="$REEF_SGR"
    fi
    output="$output${REEF_G[index]}"
  done
  REEF_ROW="$output$SL_RESET"
}

reef_context() {
  REEF_CONTEXT_TEXT=""
  REEF_CONTEXT_SHORT=""
  REEF_CONTEXT_TONE=good
  sl_is_number "${SL_CONTEXT_PERCENT:-}" || return 0
  REEF_CONTEXT_SHORT="ctx ${SL_CONTEXT_PERCENT}%"
  REEF_CONTEXT_TEXT="$REEF_CONTEXT_SHORT"
  if [ "${SL_CONTEXT_TOKENS:-0}" -gt 0 ]; then
    sl_abbrev "$SL_CONTEXT_TOKENS"
    REEF_CONTEXT_TEXT="${REEF_CONTEXT_TEXT} ${SL_ABBREV}"
  fi
  [ "$SL_CONTEXT_PERCENT" -ge 60 ] && REEF_CONTEXT_TONE=caution
  [ "$SL_CONTEXT_PERCENT" -ge 85 ] && REEF_CONTEXT_TONE=warn
  return 0
}

reef_append() {
  local width="$1" text="$2"
  if [ "$REEF_LINE_WIDTH" -gt 0 ]; then
    [ $(( REEF_LINE_WIDTH + width + 3 )) -le "$REEF_LINE_BUDGET" ] || return 1
    reef_paint faint ' · '
    REEF_LINE="$REEF_LINE$REEF_PAINT$text"
    REEF_LINE_WIDTH=$(( REEF_LINE_WIDTH + width + 3 ))
    return 0
  fi
  [ "$width" -le "$REEF_LINE_BUDGET" ] || return 1
  REEF_LINE="$REEF_LINE$text"
  REEF_LINE_WIDTH="$width"
  return 0
}

reef_data_plan() {
  local budget="$1" context_text="$2" tail=0
  REEF_PLAN_CONTEXT="$context_text"
  REEF_PLAN_MODEL=""
  REEF_PLAN_BRANCH=""
  REEF_PLAN_EFFORT=""
  [ -n "$context_text" ] && tail=$(( tail + ${#context_text} + 3 ))
  [ -n "$SL_COST_TEXT" ] && tail=$(( tail + ${#SL_COST_TEXT} + 3 ))

  if [ -n "$SL_MODEL_NAME" ]; then
    sl_width "$SL_MODEL_NAME"
    if [ $(( budget - tail - SL_W - 3 )) -ge 14 ]; then
      REEF_PLAN_MODEL="$SL_MODEL_NAME"
      tail=$(( tail + SL_W + 3 ))
    elif [ -n "$SL_MODEL_SHORT" ]; then
      sl_width "$SL_MODEL_SHORT"
      if [ $(( budget - tail - SL_W - 3 )) -ge 12 ]; then
        REEF_PLAN_MODEL="$SL_MODEL_SHORT"
        tail=$(( tail + SL_W + 3 ))
      fi
    fi
  fi

  if [ -n "$SL_EFFORT" ] && [ $(( budget - tail - ${#SL_EFFORT} - 4 )) -ge 16 ]; then
    REEF_PLAN_EFFORT="✦$SL_EFFORT"
    tail=$(( tail + ${#SL_EFFORT} + 4 ))
  fi

  REEF_PLAN_PATH_ROOM=$(( budget - tail ))
  if [ -n "$SL_GIT_BRANCH" ]; then
    local branch_room=$(( REEF_PLAN_PATH_ROOM - 14 ))
    [ "$branch_room" -gt 28 ] && branch_room=28
    if [ "$branch_room" -ge 6 ]; then
      sl_trunc "$SL_GIT_BRANCH" "$branch_room"
      REEF_PLAN_BRANCH="$SL_TRUNC"
      sl_width "$REEF_PLAN_BRANCH"
      REEF_PLAN_PATH_ROOM=$(( REEF_PLAN_PATH_ROOM - SL_W - 5 ))
    fi
  fi
}

reef_data_row() {
  local budget="$1" gutter="$2"
  REEF_LINE=""
  REEF_LINE_WIDTH=0
  REEF_LINE_BUDGET="$budget"

  reef_context
  reef_data_plan "$budget" "$REEF_CONTEXT_TEXT"
  if [ "$REEF_PLAN_PATH_ROOM" -lt 10 ] && [ -n "$REEF_CONTEXT_SHORT" ]; then
    reef_data_plan "$budget" "$REEF_CONTEXT_SHORT"
  fi

  [ "$REEF_PLAN_PATH_ROOM" -lt 6 ] && REEF_PLAN_PATH_ROOM=6
  sl_path_fit "$REEF_PLAN_PATH_ROOM"
  sl_width "$SL_PATH_FIT"
  reef_paint path "$SL_PATH_FIT" 1
  reef_append "$SL_W" "$REEF_PAINT"

  if [ -n "$REEF_PLAN_BRANCH" ]; then
    sl_width "$REEF_PLAN_BRANCH"
    reef_paint branch "⎇ $REEF_PLAN_BRANCH"
    reef_append $(( SL_W + 2 )) "$REEF_PAINT"
  fi

  if [ -n "$REEF_PLAN_CONTEXT" ]; then
    reef_paint "$REEF_CONTEXT_TONE" "$REEF_PLAN_CONTEXT" 1
    reef_append "${#REEF_PLAN_CONTEXT}" "$REEF_PAINT"
  fi

  if [ -n "$SL_COST_TEXT" ]; then
    reef_paint cost "$SL_COST_TEXT" 1
    reef_append "${#SL_COST_TEXT}" "$REEF_PAINT"
  fi

  if [ -n "$REEF_PLAN_MODEL" ]; then
    sl_width "$REEF_PLAN_MODEL"
    reef_paint model "$REEF_PLAN_MODEL"
    reef_append "$SL_W" "$REEF_PAINT"
  fi

  if [ -n "$REEF_PLAN_EFFORT" ]; then
    reef_paint surface_lit "$REEF_PLAN_EFFORT"
    reef_append $(( ${#SL_EFFORT} + 1 )) "$REEF_PAINT"
  fi

  if [ -n "$gutter" ]; then
    reef_paint surface_lit "$gutter"
    REEF_LINE="$REEF_PAINT$REEF_LINE"
  fi
}

reef_compact() {
  local budget="$1" tail=""
  sl_path_fit "$budget"
  reef_paint path "$SL_PATH_FIT" 1
  REEF_COMPACT_TOP="$REEF_PAINT"
  if [ -n "$SL_GIT_BRANCH" ]; then
    sl_width "$SL_PATH_FIT"
    if [ $(( budget - SL_W - 3 )) -ge 4 ]; then
      sl_trunc "$SL_GIT_BRANCH" $(( budget - SL_W - 3 ))
      reef_paint faint ' · '
      REEF_COMPACT_TOP="$REEF_COMPACT_TOP$REEF_PAINT"
      reef_paint branch "$SL_TRUNC"
      REEF_COMPACT_TOP="$REEF_COMPACT_TOP$REEF_PAINT"
    fi
  fi

  REEF_LINE=""
  REEF_LINE_WIDTH=0
  REEF_LINE_BUDGET="$budget"
  reef_context
  if [ -n "$REEF_CONTEXT_TEXT" ]; then
    reef_paint "$REEF_CONTEXT_TONE" "$REEF_CONTEXT_TEXT" 1
    reef_append "${#REEF_CONTEXT_TEXT}" "$REEF_PAINT"
  fi
  if [ -n "$SL_COST_TEXT" ]; then
    reef_paint cost "$SL_COST_TEXT" 1
    reef_append "${#SL_COST_TEXT}" "$REEF_PAINT"
  fi
  if [ -n "$SL_MODEL_SHORT" ]; then
    sl_width "$SL_MODEL_SHORT"
    reef_paint model "$SL_MODEL_SHORT"
    reef_append "$SL_W" "$REEF_PAINT"
  fi
  tail="$REEF_LINE"
  REEF_COMPACT_BOTTOM="$tail"
}

sl_render() {
  local row

  sl_git

  if [ "$SL_COLUMNS" -lt "$REEF_MIN_SCENE_COLUMNS" ]; then
    reef_compact "$SL_COLUMNS"
    sl_emit "$REEF_COMPACT_TOP"
    [ -n "$REEF_COMPACT_BOTTOM" ] && sl_emit "$REEF_COMPACT_BOTTOM"
    return
  fi

  REEF_W="$SL_COLUMNS"
  if [ "$REEF_W" -ge 76 ]; then
    REEF_H=6
  elif [ "$REEF_W" -ge 60 ]; then
    REEF_H=5
  elif [ "$REEF_W" -ge 46 ]; then
    REEF_H=4
  else
    REEF_H=3
  fi
  REEF_SAND_ROW=$(( REEF_H - 1 ))

  reef_grid_reset
  reef_waterline
  reef_seabed
  reef_kelp
  reef_jellyfish
  reef_traffic

  for (( row = 0; row < REEF_H; row++ )); do
    reef_row_render "$row"
    sl_emit "$REEF_ROW"
  done

  reef_data_row $(( SL_COLUMNS - 2 )) '▌ '
  sl_emit "$REEF_LINE"
}
