#!/usr/bin/env bash
# @name: underwater
# @description: Reef scene — fish, squid, jellyfish and kelp over the readout
# @order: 18

# A cell grid painted bottom-up: waterline, open water, seabed, then the data
# row. Open water is deliberately unpainted so the terminal's own translucent
# tint shows through. Every position, frame and bubble is a pure function of
# SL_NOW, so two renders of the same second are identical.
#
# Creatures and plants are bitmaps at twice the vertical resolution of the cell
# grid: each pair of pixel rows is packed into one cell as a half block with a
# foreground and a background colour, so a cell can carry two different tones.
# A bitmap is a frame array of 2 x REEF_SH strings, each REEF_SW characters
# wide, drawn facing right; the renderer mirrors it when the creature swims
# left. Each character is a tone code resolved through REEF_ROLE into a
# "<species>_<role>" entry of REEF_PALETTE, and '.' is transparent.

REEF_CYCLE_SECONDS=153
REEF_BUBBLE_PERIOD=3
REEF_BUBBLE_LIFE=17
REEF_BUBBLE_DRAG=72
REEF_SWAY_SECONDS=13
REEF_SURFACE_SECONDS=29
REEF_JELLY_SECONDS=6
REEF_MIN_SCENE_COLUMNS=36
REEF_MIN_JELLY_COLUMNS=70
REEF_FLORA_SPACING=5
REEF_FLORA_DENSITY=58
REEF_FLORA_SWAY=3
REEF_MOTE_DENSITY=28
REEF_MOTE_SECONDS=11

REEF_RUNS=(
  '0|34|0|clownfish|1' '37|18|1|minnow|1' '57|22|0|snapper|1'
  '81|18|1|minnow|3' '101|26|0|squid|1' '129|22|1|shark|2'
)

REEF_FLORA_SET=(kelptall kelp kelpb kelptallb kelp kelpb grass grass tuft tuft turf anemone)

REEF_CLOWNFISH_F0=('.............ffFFff.......' '.TT........WddkWWddkW.....' '.TttT....kWWDDkWWDDkWWDD..' '...TttTookwwookwwoogwwepo.' '...TttTOOOkwwOOkwwfgkwwkDm' '.TttT....lkwwllkwFFlkwwll.' '.TT........wwLLkwwLLk.....' '.............fffff........')
REEF_CLOWNFISH_F1=('.............ffFFff.......' '...........WddkWWddkW.....' '.TT......kWWDDkWWDDkWWDD..' '.TttTtTookwwookwwoogwwepo.' '...TttTOOOkwwOOkwFFgkwwkDm' '...TttT..lkwwllkwfllkwwll.' '.TttT......wwLLkwwLLk.....' '.TT..........fffff........')
REEF_CLOWNFISH_F2=('.TT..........ffFFff.......' '.TttT......WddkWWddkW.....' '...TttT..kWWDDkWWDDkWWDD..' '...TttTookwwookwwoogwwepo.' '.TttTtTOOOkwwOOkwwOgkwwkDm' '.TT......lkwwllkwfflkwwll.' '...........wwLLkFFLLk.....' '.............fffff........')
REEF_SNAPPER_F0=('Ttt......kFkFkFkFk....' '.ttt...kkddddddddddk..' '...tttwDDsDosoosgoepOk' '...tttwoOOsOOsOOgOllmm' '.ttt...kllLlLlfFlllk..' 'Ttt......kffFf..fF....')
REEF_SNAPPER_F1=('TTtt.....kFkFkFkFk....' '.Tttt..kkddddddddddk..' '.tttttwDDsDosoosgoepOk' '....ttwoOOsOOsOOgOllmm' '.......kllLlLlffFllk..' '.........kfFff..fF....')
REEF_SNAPPER_F2=('.........kFkFkFkFk....' '.......kkddddddddddk..' '....ttwDDsDosoosgoepOk' '.tttttwoOOsOOsOOgOllmm' '.tttt..kllLlLlFflllk..' 'TTtt.....kfffF..fF....')
REEF_MINNOW_F0=('T..kkkkk..' '.TtOOOOOep' '.TtlLLLLgm' 'T..kkffk..')
REEF_MINNOW_F1=('.T.kkkkk..' 'TTtOOOOOep' 'TTtlLLLLgm' '.T.kkffk..')
REEF_SQUID_F0=('....kTTk............' '..kTTTtttk..........' '...tddswddkkkFk.....' '.kdDosowOgepkFFfkFFk' '.kDollswlgepmfffkFFk' '...tLLLwllkkkfk.....' '..kttttttk..........' '....kttk............')
REEF_SQUID_F1=('...kTTk...........Fk' '..kTTTtttk...fk.fFFk' '...tddswddkkkFFffk..' '.kdDosowOgepkFFfk...' '.kDollswlgepmfffk...' '...tLLLwllkkkfffk...' '..kttttttk...fk.fFFk' '...kttk...........Fk')
REEF_SQUID_F2=('.....kTTk...........' '..kTTTtttk..........' '...tddswddkkkFk.....' '.kdDosowOgepkFffk...' '.kDollswlgepmfffffk.' '...tLLLwllkkkfffkFFk' '..kttttttk.....fFFk.' '.....kttk...........')
REEF_SHARK_F0=('..TT.........FFF..........' '..TT........kdFFd.........' '.TTT......kddddddddk......' '.ttT....kdddDDDDDDDDdd....' 'ttttkkkDDDOOOOOOOOOOODdke.' '.ttTkkklllLLLLLLLLLLLldkpm' '..tt..kFFllLLLLLlkFFk.....' '......kFF.......kFk.......')
REEF_SHARK_F1=('.............FFF..........' '..TT........kdFFd.........' '..TT......kddddddddk......' '.TTT....kdddDDDDDDDDdd....' '.tttkkkDDDOOOOOOOOOOODdke.' 'ttttkkklllLLLLLLLLLLLldkpm' '.ttTk.kFFllLLLLLlkFFk.....' '..tt..kFF.......kFk.......')
REEF_SHARK_F2=('..TT.........FFF..........' '.TTT........kdFFd.........' '.ttT......kddddddddk......' 'ttttk...kdddDDDDDDDDdd....' '.tttkkkDDDOOOOOOOOOOODdke.' '..tt.kklllLLLLLLLLLLLldkpm' '......kfFllLLLLLlkFFk.....' '......FFF.......kFk.......')
REEF_JELLY_F0=('....wwwwww....' '..wOOooooOOw..' '.wOollllllOOw.' '.WOlLLLLLLlOW.' '..tt.tTT.tt...' '...t.tTT.t.t..' '..f.t.ff.t.f..' '..f.f.ff.f.f..')
REEF_JELLY_F1=('...wwwwwwww...' '..wOoooooooOw.' '.wOolllllloOw.' '..WOlLLLLlOW..' '...ttTTTTtt...' '...t.tTT.t....' '...t.tff.t.t..' '....f.ff.f....')
REEF_JELLY_F2=('....wwwwww....' '..wOOooooOOw..' '.wOollllllOOw.' '.WOlLLLLLLlOW.' '.ttt.tTT.ttt..' '..t...tt...t..' '.f.t.ffff.t.f.' 'f..f.f..f.f..f')

REEF_FLORA_KELPTALL=('..L' '.fO' '..O' 'f.O' '..o' 'f.o' '..o' '..k')
REEF_FLORA_KELPTALLB=('L..' 'Of.' 'O..' 'O.f' 'o..' 'o.f' 'o..' 'k..')
REEF_FLORA_KELP=('..L' '.fO' '..O' 'f.O' '..o' '..k')
REEF_FLORA_KELPB=('L..' 'Of.' 'O..' 'O.f' 'o..' 'k..')
REEF_FLORA_GRASS=('L..L' 'OL.O' '.OoO' '.ooo' '.ddd' '..k.')
REEF_FLORA_TUFT=('.L.' 'LOL' 'ooo' 'Dod' '.k.')
REEF_FLORA_TURF=('W.W' 'ooo' 'DoD' '.k.')
REEF_FLORA_ANEMONE=('TtT' 'ooo' 'DoD' '.k.')

declare -gA REEF_ROLE=([k]=ink [d]=deep [D]=shade [o]=body [O]=light [l]=belly [L]=belly_light
  [f]=fin [F]=fin_light [t]=tail [T]=tail_light [w]=mark [W]=mark_light
  [m]=mouth [g]=seam [s]=accent
)

declare -gA REEF_PALETTE=(
  [anemone_accent]='255;160;200' [anemone_belly]='130;204;190'
  [anemone_belly_light]='178;230;216' [anemone_body]='50;136;132' [anemone_deep]='24;82;84'
  [anemone_fin]='44;122;118' [anemone_fin_light]='110;190;178' [anemone_ink]='10;44;46'
  [anemone_light]='84;172;162' [anemone_mark]='255;206;232' [anemone_seam]='20;72;74'
  [anemone_shade]='36;108;106' [anemone_tail]='236;120;176' [anemone_tail_light]='255;178;212'
  [bed_accent]='142;162;154' [bed_belly]='140;168;158' [bed_belly_light]='176;196;184'
  [bed_body]='80;110;108' [bed_deep]='56;80;82' [bed_fin]='96;124;120'
  [bed_fin_light]='150;176;168' [bed_ink]='38;52;54' [bed_light]='112;142;136'
  [bed_mark]='214;198;178' [bed_mark_light]='240;230;212' [bed_mouth]='198;184;166'
  [bed_seam]='60;84;86' [bed_shade]='66;94;94' [bed_tail]='108;134;130'
  [bed_tail_light]='162;186;176' [brain_accent]='255;238;190' [brain_belly]='238;216;162'
  [brain_belly_light]='252;238;198' [brain_body]='182;150;80' [brain_deep]='116;90;44'
  [brain_fin]='162;132;68' [brain_fin_light]='228;204;146' [brain_ink]='56;42;18'
  [brain_light]='214;186;118' [brain_mark]='255;246;214' [brain_seam]='92;70;32'
  [brain_shade]='150;120;60' [branch]='95;240;216' [bubble_a]='140;205;220'
  [bubble_b]='170;225;238' [bubble_c]='200;242;250' [bubble_d]='228;252;255'
  [caution]='240;206;133' [clownfish_accent]='255;208;142' [clownfish_belly]='255;188;118'
  [clownfish_belly_light]='255;218;168' [clownfish_body]='240;116;24'
  [clownfish_deep]='164;58;8' [clownfish_fin]='228;106;28' [clownfish_fin_light]='255;172;98'
  [clownfish_ink]='38;16;10' [clownfish_light]='255;150;50' [clownfish_mark]='250;248;240'
  [clownfish_mark_light]='255;255;255' [clownfish_mouth]='255;196;150'
  [clownfish_seam]='196;80;20' [clownfish_shade]='204;84;12' [clownfish_tail]='255;148;52'
  [clownfish_tail_light]='255;198;132' [cost]='255;206;138' [dune]='96;126;122'
  [eye_dark]='12;10;14' [eye_light]='255;255;250' [faint]='70;112;124'
  [fan_accent]='236;168;212' [fan_belly]='228;146;196' [fan_belly_light]='248;188;222'
  [fan_body]='162;62;132' [fan_deep]='94;34;84' [fan_fin]='146;54;122'
  [fan_fin_light]='214;126;184' [fan_ink]='44;14;40' [fan_light]='200;104;170'
  [fan_mark]='250;198;228' [fan_seam]='78;26;70' [fan_shade]='130;48;112' [good]='106;226;176'
  [grass_accent]='180;230;132' [grass_belly]='164;222;120' [grass_belly_light]='204;240;154'
  [grass_body]='86;168;74' [grass_deep]='34;100;44' [grass_fin]='70;150;64'
  [grass_fin_light]='146;212;108' [grass_ink]='16;56;26' [grass_light]='126;200;96'
  [grass_mark]='214;244;160' [grass_seam]='30;88;38' [grass_shade]='52;130;58' [ink]='58;66;92'
  [jelly_accent]='255;206;236' [jelly_belly]='255;214;238' [jelly_belly_light]='255;238;248'
  [jelly_body]='250;150;200' [jelly_deep]='204;84;148' [jelly_fin]='236;130;188'
  [jelly_fin_light]='255;200;230' [jelly_ink]='126;36;90' [jelly_light]='255;184;222'
  [jelly_mark]='255;240;250' [jelly_mark_light]='255;255;255' [jelly_mouth]='255;206;236'
  [jelly_seam]='192;70;138' [jelly_shade]='230;114;174' [jelly_tail]='244;144;198'
  [jelly_tail_light]='255;210;236' [kelp_accent]='150;216;140' [kelp_belly]='120;206;134'
  [kelp_belly_light]='168;228;150' [kelp_body]='40;142;92' [kelp_deep]='18;78;56'
  [kelp_fin]='48;150;100' [kelp_fin_light]='108;196;128' [kelp_ink]='10;44;32'
  [kelp_light]='74;176;108' [kelp_mark]='206;240;160' [kelp_mark_light]='232;250;190'
  [kelp_seam]='22;92;64' [kelp_shade]='26;104;74' [kelp_tail]='64;166;104'
  [kelp_tail_light]='128;208;140' [manta_accent]='204;222;246' [manta_belly]='224;236;250'
  [manta_belly_light]='246;250;255' [manta_body]='124;150;194' [manta_deep]='54;72;108'
  [manta_fin]='98;124;166' [manta_fin_light]='186;208;238' [manta_ink]='14;20;32'
  [manta_light]='164;190;228' [manta_mark]='236;244;255' [manta_mark_light]='255;255;255'
  [manta_mouth]='196;212;234' [manta_seam]='60;80;116' [manta_shade]='86;110;152'
  [manta_tail]='76;98;136' [manta_tail_light]='150;176;212' [minnow_accent]='255;244;150'
  [minnow_belly]='255;248;196' [minnow_belly_light]='255;255;232' [minnow_body]='236;206;46'
  [minnow_deep]='148;118;16' [minnow_fin]='214;184;40' [minnow_fin_light]='255;238;140'
  [minnow_ink]='44;36;8' [minnow_light]='252;230;96' [minnow_mark]='255;255;240'
  [minnow_mark_light]='255;255;255' [minnow_mouth]='255;240;190' [minnow_seam]='168;136;20'
  [minnow_shade]='196;164;26' [minnow_tail]='246;222;84' [minnow_tail_light]='255;246;170'
  [model]='124;176;192' [mote]='162;224;228' [path]='168;240;250' [pebble]='142;162;154'
  [plankton]='126;198;206' [rubble]='120;136;130' [sand]='74;104;104'
  [shark_accent]='196;212;222' [shark_belly]='214;226;232' [shark_belly_light]='242;248;250'
  [shark_body]='126;148;164' [shark_deep]='62;80;96' [shark_fin]='104;126;142'
  [shark_fin_light]='176;196;208' [shark_ink]='18;26;36' [shark_light]='160;182;196'
  [shark_mark]='240;246;250' [shark_mouth]='206;170;172' [shark_seam]='58;76;92'
  [shark_shade]='92;112;128' [shark_tail]='110;132;148' [shark_tail_light]='168;190;204'
  [shell]='214;198;178' [snapper_accent]='255;198;224' [snapper_belly]='255;168;200'
  [snapper_belly_light]='255;216;234' [snapper_body]='232;62;124' [snapper_deep]='148;20;70'
  [snapper_fin]='212;48;110' [snapper_fin_light]='255;142;186' [snapper_ink]='40;10;24'
  [snapper_light]='252;102;158' [snapper_mark]='255;236;246' [snapper_mark_light]='255;255;255'
  [snapper_mouth]='255;190;210' [snapper_seam]='168;28;80' [snapper_shade]='194;36;96'
  [snapper_tail]='240;76;136' [snapper_tail_light]='255;172;206' [sponge_accent]='246;196;140'
  [sponge_belly]='238;174;108' [sponge_belly_light]='252;208;156' [sponge_body]='182;102;44'
  [sponge_deep]='116;58;24' [sponge_fin]='164;88;36' [sponge_fin_light]='228;160;92'
  [sponge_ink]='52;24;10' [sponge_light]='214;138;68' [sponge_mark]='255;224;178'
  [sponge_seam]='88;42;16' [sponge_shade]='150;80;34' [squid_accent]='246;170;255'
  [squid_belly]='232;180;252' [squid_belly_light]='248;222;255' [squid_body]='184;90;226'
  [squid_deep]='106;36;150' [squid_fin]='162;72;210' [squid_fin_light]='222;160;252'
  [squid_ink]='30;12;40' [squid_light]='212;130;246' [squid_mark]='255;240;255'
  [squid_mark_light]='255;255;255' [squid_mouth]='255;200;236' [squid_seam]='126;44;170'
  [squid_shade]='148;58;194' [squid_tail]='196;106;236' [squid_tail_light]='236;190;255'
  [staghorn_accent]='226;220;244' [staghorn_belly]='214;206;232'
  [staghorn_belly_light]='240;236;250' [staghorn_body]='146;134;176' [staghorn_deep]='86;78;116'
  [staghorn_fin]='128;118;158' [staghorn_fin_light]='200;190;224' [staghorn_ink]='40;36;56'
  [staghorn_light]='184;172;208' [staghorn_mark]='250;248;255' [staghorn_seam]='70;64;98'
  [staghorn_shade]='116;106;146' [star]='226;138;112' [surface]='96;168;186'
  [surface_lit]='150;220;232' [turf_accent]='248;160;172' [turf_belly]='236;128;146'
  [turf_belly_light]='255;176;186' [turf_body]='164;46;78' [turf_deep]='92;24;48'
  [turf_fin]='146;40;70' [turf_fin_light]='222;104;126' [turf_ink]='48;10;26'
  [turf_light]='206;76;104' [turf_mark]='255;196;200' [turf_seam]='78;18;40'
  [turf_shade]='130;34;62' [value]='208;250;255' [warn]='255;138;156'
 [kelpb_ink]='10;44;32' [kelpb_deep]='18;78;56' [kelpb_shade]='26;104;74' [kelpb_body]='40;142;92' [kelpb_light]='74;176;108' [kelpb_belly]='120;206;134' [kelpb_belly_light]='168;228;150' [kelpb_fin]='48;150;100' [kelpb_fin_light]='108;196;128' [kelpb_seam]='22;92;64' [kelpb_mark]='206;240;160' [kelpb_accent]='150;216;140' [kelpb_tail]='64;166;104' [kelpb_tail_light]='128;208;140' [tuft_ink]='16;56;26' [tuft_deep]='34;100;44' [tuft_shade]='52;130;58' [tuft_body]='70;156;70' [tuft_light]='112;192;92' [tuft_belly]='152;216;116' [tuft_belly_light]='196;238;150' [tuft_fin]='60;140;60' [tuft_fin_light]='134;206;104' [tuft_seam]='26;84;34' [tuft_mark]='210;242;158' [tuft_accent]='176;226;128'
 [kelptall_ink]='10;44;32' [kelptall_deep]='18;78;56' [kelptall_shade]='26;104;74' [kelptall_body]='40;142;92' [kelptall_light]='74;176;108' [kelptall_belly]='120;206;134' [kelptall_belly_light]='168;228;150' [kelptall_fin]='48;150;100' [kelptall_fin_light]='108;196;128' [kelptall_seam]='22;92;64' [kelptall_mark]='206;240;160' [kelptall_accent]='150;216;140' [kelptall_tail]='64;166;104' [kelptall_tail_light]='128;208;140' [kelptallb_ink]='10;44;32' [kelptallb_deep]='18;78;56' [kelptallb_shade]='26;104;74' [kelptallb_body]='40;142;92' [kelptallb_light]='74;176;108' [kelptallb_belly]='120;206;134' [kelptallb_belly_light]='168;228;150' [kelptallb_fin]='48;150;100' [kelptallb_fin_light]='108;196;128' [kelptallb_seam]='22;92;64' [kelptallb_mark]='206;240;160' [kelptallb_accent]='150;216;140' [kelptallb_tail]='64;166;104' [kelptallb_tail_light]='128;208;140'
)
declare -gA REEF_SGR_CACHE=()

reef_rgb() {
  REEF_RGB="${REEF_PALETTE[$1]:-120;160;170}"
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
  REEF_PHASE=$(( SL_NOW * 1024 / $1 % 1024 ))
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
    clownfish) REEF_SW=26; REEF_SH=4; REEF_SLACK=0; REEF_SEQ='0 1 0 2'; REEF_VENTS=1 ;;
    snapper) REEF_SW=22; REEF_SH=3; REEF_SLACK=1; REEF_SEQ='0 1 0 2'; REEF_VENTS=1 ;;
    minnow) REEF_SW=10; REEF_SH=2; REEF_SLACK=1; REEF_SEQ='0 1'; REEF_VENTS=0 ;;
    squid) REEF_SW=20; REEF_SH=4; REEF_SLACK=0; REEF_SEQ='0 1 2 1'; REEF_VENTS=1 ;;
    jelly) REEF_SW=14; REEF_SH=4; REEF_SLACK=0; REEF_SEQ='0 1 2'; REEF_VENTS=0 ;;
    *) REEF_SW=26; REEF_SH=4; REEF_SLACK=0; REEF_SEQ='0 1 0 2'; REEF_VENTS=0 ;;
  esac
}

reef_art() {
  local reference="REEF_${1^^}_F${2}[@]"
  REEF_ART=("${!reference}")
  [ "${#REEF_ART[@]}" -gt 0 ] && return 0
  reference="REEF_${1^^}_F0[@]"
  REEF_ART=("${!reference}")
}

reef_cell_tone() {
  REEF_CELL_BOLD=0
  case "$2" in
    e) REEF_CELL_TONE=eye_light; REEF_CELL_BOLD=1; return ;;
    p) REEF_CELL_TONE=eye_dark; return ;;
    L|W|T|F) REEF_CELL_BOLD=1 ;;
  esac
  REEF_CELL_TONE="$1_${REEF_ROLE[$2]:-body}"
  [ -n "${REEF_PALETTE[$REEF_CELL_TONE]:-}" ] || REEF_CELL_TONE="$1_body"
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
  ceiling=$(( REEF_SAND_ROW - height ))
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
      glyph='·'
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
  local top="$1" left="$2" index target ceiling other
  local offsets=(0 -16 -32 -8 -24) bands=(0 0 0 1 1)
  ceiling=$(( REEF_SAND_ROW - REEF_SH ))
  [ "$ceiling" -lt 1 ] && ceiling=1
  [ "$top" -gt "$ceiling" ] && top="$ceiling"
  [ "$top" -lt 1 ] && top=1
  other=$(( top + 2 ))
  if [ "$other" -gt "$ceiling" ]; then
    other=$(( top - 2 ))
  fi
  [ "$other" -lt 1 ] && other=1
  for (( index = 0; index < 5; index++ )); do
    if [ "${bands[index]}" = "1" ]; then
      target="$other"
    else
      target="$top"
    fi
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
    [ "$REEF_SH" -lt "$REEF_SAND_ROW" ] || continue
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
  local top column frame
  [ "$REEF_W" -ge "$REEF_MIN_JELLY_COLUMNS" ] || return 0
  reef_species jelly
  [ "$REEF_SH" -lt "$REEF_SAND_ROW" ] || return 0
  top=$(( REEF_SAND_ROW - REEF_SH ))
  [ "$top" -lt 1 ] && top=1
  reef_phase 97
  sl_cos $(( REEF_PHASE + 200 ))
  column=$(( REEF_W * 3 / 4 + SL_COS * 11 / 1000 ))
  frame=$(( SL_NOW % 3 ))
  reef_compose jelly "$frame" 0
  reef_stamp_sprite "$top" "$column"
}

reef_flora_art() {
  local reference="REEF_FLORA_${1^^}[@]"
  REEF_FLORA_ROWS=("${!reference}")
  REEF_FLORA_H="${#REEF_FLORA_ROWS[@]}"
  REEF_FLORA_W="${#REEF_FLORA_ROWS[0]}"
}

reef_flora_stamp() {
  local plant="$1" anchor="$2" bend="$3" trim="$4"
  local row pixel_top pixel_bottom column index shift_top shift_bottom
  local top_code bottom_code left height
  reef_flora_art "$plant"
  [ "$REEF_FLORA_H" -gt 0 ] || return 0
  height=$(( REEF_FLORA_H - trim ))
  [ "$height" -ge 3 ] || return 0
  left=$(( anchor - REEF_FLORA_W / 2 ))
  for (( row = REEF_SAND_ROW; row >= 1; row-- )); do
    pixel_top=$(( 2 * (REEF_SAND_ROW - row) ))
    pixel_bottom=$(( pixel_top - 1 ))
    [ "$pixel_top" -lt "$height" ] || break
    shift_top=$(( bend * pixel_top * REEF_FLORA_SWAY / 8000 ))
    if [ "$pixel_bottom" -ge 0 ]; then
      shift_bottom=$(( bend * pixel_bottom * REEF_FLORA_SWAY / 8000 ))
    else
      shift_bottom=0
    fi
    for (( index = -2; index < REEF_FLORA_W + 2; index++ )); do
      column=$(( left + index ))
      top_code='.'
      bottom_code='.'
      if [ $(( index - shift_top )) -ge 0 ] && [ $(( index - shift_top )) -lt "$REEF_FLORA_W" ]; then
        top_code="${REEF_FLORA_ROWS[REEF_FLORA_H - 1 - pixel_top]:index - shift_top:1}"
      fi
      if [ "$pixel_bottom" -ge 0 ] && [ $(( index - shift_bottom )) -ge 0 ] \
         && [ $(( index - shift_bottom )) -lt "$REEF_FLORA_W" ]; then
        bottom_code="${REEF_FLORA_ROWS[REEF_FLORA_H - 1 - pixel_bottom]:index - shift_bottom:1}"
      fi
      [ "$top_code" = "." ] && [ "$bottom_code" = "." ] && continue
      reef_pack "$plant" "$top_code" "$bottom_code"
      [ "$REEF_PACK_G" = " " ] && continue
      reef_put "$row" "$column" "$REEF_PACK_T" "$REEF_PACK_G" "$REEF_PACK_O" 1 "$REEF_PACK_B"
    done
  done
}

reef_flora() {
  local column last_column choice plant bend trim anchor_phase
  reef_phase "$REEF_SWAY_SECONDS"
  last_column=-99
  for (( column = 1; column < REEF_W - 1; column++ )); do
    [ $(( column - last_column )) -ge "$REEF_FLORA_SPACING" ] || continue
    reef_hash "$column" 101
    [ $(( REEF_HASH % 100 )) -lt "$REEF_FLORA_DENSITY" ] || continue
    reef_hash "$column" 7
    choice=$(( REEF_HASH % ${#REEF_FLORA_SET[@]} ))
    plant="${REEF_FLORA_SET[choice]}"
    trim=$(( REEF_HASH / 16 % 3 ))
    last_column="$column"
    reef_hash "$column" 19
    anchor_phase=$(( REEF_HASH % 1024 ))
    sl_cos $(( REEF_PHASE + anchor_phase ))
    bend="$SL_COS"
    reef_flora_stamp "$plant" "$column" "$bend" "$trim"
  done
}

reef_seabed() {
  local column crest top_code
  for (( column = 0; column < REEF_W; column++ )); do
    reef_hash "$column" 31
    sl_cos $(( column * 41 ))
    crest=0
    [ "$SL_COS" -gt 450 ] && [ $(( REEF_HASH % 100 )) -lt 40 ] && crest=1
    if [ "$crest" = "1" ]; then
      top_code='O'
    else
      case $(( REEF_HASH % 31 )) in
        0) top_code='w' ;;
        1) top_code='W' ;;
        2|3) top_code='s' ;;
        4|5) top_code='d' ;;
        *) top_code='.' ;;
      esac
    fi
    reef_pack bed "$top_code" 'o'
    reef_put "$REEF_SAND_ROW" "$column" "$REEF_PACK_T" "$REEF_PACK_G" "$REEF_PACK_O" 1 "$REEF_PACK_B"
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

reef_motes() {
  local column row drift phase span
  span=$(( REEF_SAND_ROW - 1 ))
  [ "$span" -ge 1 ] || return 0
  for (( column = 2; column < REEF_W - 2; column += 7 )); do
    reef_hash "$column" 67
    [ $(( REEF_HASH % 100 )) -lt "$REEF_MOTE_DENSITY" ] || continue
    phase=$(( REEF_HASH % 1024 ))
    sl_cos $(( SL_NOW * 1024 / REEF_MOTE_SECONDS + phase ))
    drift=$(( SL_COS * 3 / 1000 ))
    row=$(( 1 + (REEF_HASH / 16 + SL_NOW / REEF_MOTE_SECONDS) % span ))
    if [ $(( REEF_HASH % 3 )) -eq 0 ]; then
      reef_put_empty "$row" $(( column + drift )) mote '·'
    else
      reef_put_empty "$row" $(( column + drift )) plankton '·'
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
  REEF_ROW_WIDTH=$(( last + 1 ))
  if [ "$last" -lt 0 ]; then
    REEF_ROW=""
    REEF_ROW_WIDTH=0
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
  reef_flora
  reef_motes
  reef_jellyfish
  reef_traffic

  for (( row = 0; row < REEF_H; row++ )); do
    reef_row_render "$row"
    sl_emit_sized "$REEF_ROW" "$REEF_ROW_WIDTH"
  done

  reef_data_row $(( SL_COLUMNS - 2 )) '▌ '
  sl_emit "$REEF_LINE"
}
