#!/usr/bin/env bash
# CLI behind the /sl and /statusline-theme slash commands. Lists, activates, previews and
# edits the theme files in themes/, reading their metadata header block.
#
#   switch.sh                         list the themes
#   switch.sh list [--color]          numbered table, active theme marked
#   switch.sh set <number|name>       activate a theme
#   switch.sh next | prev             step through the list, wrapping
#   switch.sh show                    report the active theme
#   switch.sh preview <ref> | --all   render against sample-payload.json
#   switch.sh path <ref>              absolute path of the theme file
#   switch.sh rename <ref> <name>     rename the file and its @name header
#   switch.sh describe <ref> <text>   rewrite the @description header
#   switch.sh clone <ref> <name>      copy a theme to the end of the list
#   switch.sh delete <ref> [--force]  remove a theme file
#   switch.sh help                    usage
#
# A theme's number is its rank once every theme is sorted by @order ascending
# and then by name, so it is derived from the files and never stored. Anything
# that takes a theme takes either the number or the name.
#
# Exit status: 0 success, 1 user error, 2 internal error.

set -u

SWITCH_HOME="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SWITCH_THEME_DIR="$SWITCH_HOME/themes"
SWITCH_SELECTED_FILE="$SWITCH_HOME/selected"
SWITCH_RENDERER="$SWITCH_HOME/statusline.sh"
SWITCH_PAYLOAD="$SWITCH_HOME/sample-payload.json"
SWITCH_DEFAULT_THEME="purple"
SWITCH_DEFAULT_ORDER=9999
SWITCH_MAX_ORDER=999999999
SWITCH_ORDER_STEP=10
SWITCH_MISSING_DESCRIPTION="(no description)"
SWITCH_HEADER_SCAN_LINES=40
SWITCH_DEFAULT_COLUMNS=100
SWITCH_MIN_COLUMNS=40
SWITCH_MAX_COLUMNS=1000
SWITCH_FIELD=$'\037'
SWITCH_ESC=$'\033'

SWITCH_NAMES=()
SWITCH_DESCRIPTIONS=()
SWITCH_ORDERS=()
SWITCH_ACTIVE=""
SWITCH_INDEX=-1
SWITCH_SUMMARY=""
SWITCH_RULE=""
SWITCH_PREVIEW_ERRORS=""

switch_fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

switch_abort() {
  printf 'internal error: %s\n' "$1" >&2
  exit 2
}

switch_valid_name() {
  case "${1:-}" in
    '' | -* | *[!a-zA-Z0-9_-]*) return 1 ;;
    *) return 0 ;;
  esac
}

switch_scan_headers() {
  awk -v limit="$SWITCH_HEADER_SCAN_LINES" -v separator="$SWITCH_FIELD" '
    function trim(value) {
      gsub(/\r/, "", value)
      gsub(separator, " ", value)
      sub(/^[ \t]+/, "", value)
      sub(/[ \t]+$/, "", value)
      return value
    }
    FNR == 1 { seen[FILENAME] = 1 }
    FNR > limit { next }
    /^#[ \t]*@order:/ {
      if (!(FILENAME in orders)) { orders[FILENAME] = trim(substr($0, index($0, ":") + 1)) }
    }
    /^#[ \t]*@description:/ {
      if (!(FILENAME in details)) { details[FILENAME] = trim(substr($0, index($0, ":") + 1)) }
    }
    END {
      for (file in seen) {
        order = (file in orders) ? orders[file] : ""
        if (order !~ /^[0-9]+$/ || length(order) > 9) {
          order = ""
        } else {
          order = sprintf("%d", order + 0)
        }
        printf "%s%s%s%s%s\n", file, separator, order, separator,
          (file in details) ? details[file] : ""
      }
    }
  ' "$@"
}

switch_load() {
  SWITCH_NAMES=()
  SWITCH_DESCRIPTIONS=()
  SWITCH_ORDERS=()

  local -a files=()
  local file
  local name
  local order
  local description
  for file in "$SWITCH_THEME_DIR"/*.sh; do
    [ -f "$file" ] || continue
    name="${file##*/}"
    name="${name%.sh}"
    switch_valid_name "$name" || continue
    files+=("$file")
  done
  [ "${#files[@]}" -gt 0 ] || return 0

  local -A found_orders=()
  local -A found_descriptions=()
  local key
  while IFS="$SWITCH_FIELD" read -r key order description; do
    [ -n "$key" ] || continue
    found_orders["$key"]="$order"
    found_descriptions["$key"]="$description"
  done < <(switch_scan_headers "${files[@]}")

  while IFS="$SWITCH_FIELD" read -r order name description; do
    SWITCH_ORDERS+=("$order")
    SWITCH_NAMES+=("$name")
    SWITCH_DESCRIPTIONS+=("$description")
  done < <(
    for file in "${files[@]}"; do
      name="${file##*/}"
      name="${name%.sh}"
      order="${found_orders[$file]:-}"
      case "$order" in
        '' | *[!0-9]*) order="$SWITCH_DEFAULT_ORDER" ;;
      esac
      description="${found_descriptions[$file]:-}"
      [ -n "$description" ] || description="$SWITCH_MISSING_DESCRIPTION"
      printf '%s%s%s%s%s\n' "$order" "$SWITCH_FIELD" "$name" "$SWITCH_FIELD" "$description"
    done | LC_ALL=C sort -t "$SWITCH_FIELD" -k1,1n -k2,2
  )
}

switch_read_active() {
  SWITCH_ACTIVE=""
  if [ -f "$SWITCH_SELECTED_FILE" ]; then
    IFS= read -r SWITCH_ACTIVE < "$SWITCH_SELECTED_FILE" 2>/dev/null || :
    SWITCH_ACTIVE="${SWITCH_ACTIVE//[[:space:]]/}"
  fi
  switch_valid_name "$SWITCH_ACTIVE" || SWITCH_ACTIVE="$SWITCH_DEFAULT_THEME"
}

switch_active_index() {
  local index
  for (( index = 0; index < ${#SWITCH_NAMES[@]}; index++ )); do
    if [ "${SWITCH_NAMES[index]}" = "$SWITCH_ACTIVE" ]; then
      SWITCH_INDEX="$index"
      return 0
    fi
  done
  SWITCH_INDEX=-1
  return 1
}

switch_resolve() {
  local reference="${1:-}"
  local count="${#SWITCH_NAMES[@]}"
  local index
  SWITCH_INDEX=-1
  [ "$count" -gt 0 ] || return 1
  case "$reference" in
    '') return 1 ;;
    *[!0-9]*) ;;
    *)
      [ "${#reference}" -le 9 ] || return 1
      index=$(( 10#$reference ))
      [ "$index" -ge 1 ] && [ "$index" -le "$count" ] || return 1
      SWITCH_INDEX=$(( index - 1 ))
      return 0
      ;;
  esac
  switch_valid_name "$reference" || return 1
  for (( index = 0; index < count; index++ )); do
    if [ "${SWITCH_NAMES[index]}" = "$reference" ]; then
      SWITCH_INDEX="$index"
      return 0
    fi
  done
  local folded="${reference,,}"
  local matches=0
  local candidate=-1
  for (( index = 0; index < count; index++ )); do
    if [ "${SWITCH_NAMES[index],,}" = "$folded" ]; then
      matches=$(( matches + 1 ))
      candidate="$index"
    fi
  done
  if [ "$matches" -eq 1 ]; then
    SWITCH_INDEX="$candidate"
    return 0
  fi
  return 1
}

switch_reject_reference() {
  local reference="${1:-}"
  local options=""
  local index
  for (( index = 0; index < ${#SWITCH_NAMES[@]}; index++ )); do
    options="$options $(( index + 1 ))=${SWITCH_NAMES[index]}"
  done
  printf 'error: no such theme: %s\n' "${reference:-<empty>}" >&2
  if [ -n "$options" ]; then
    printf 'valid:%s\n' "$options" >&2
  else
    printf 'valid: none, %s holds no theme\n' "$SWITCH_THEME_DIR" >&2
  fi
  exit 1
}

switch_require_themes() {
  [ "${#SWITCH_NAMES[@]}" -gt 0 ] || switch_fail "no themes in $SWITCH_THEME_DIR"
}

switch_set_summary() {
  local index="$1"
  SWITCH_SUMMARY="$(( index + 1 )) ${SWITCH_NAMES[index]} - ${SWITCH_DESCRIPTIONS[index]}"
}

switch_write_selected() {
  local name="$1"
  local temporary="$SWITCH_SELECTED_FILE.tmp.$$"
  switch_valid_name "$name" || switch_abort "refusing to activate invalid name"
  printf '%s\n' "$name" > "$temporary" || switch_abort "cannot write $temporary"
  if ! mv -f -- "$temporary" "$SWITCH_SELECTED_FILE"; then
    rm -f -- "$temporary"
    switch_abort "cannot replace $SWITCH_SELECTED_FILE"
  fi
  SWITCH_ACTIVE="$name"
  switch_apply_background "$name"
}

switch_apply_background() {
  local helper="$SWITCH_HOME/terminal-background.py"
  [ -f "$helper" ] || return 0
  command -v python3 >/dev/null 2>&1 || {
    printf 'warning: python3 missing, terminal background unchanged\n' >&2
    return 0
  }
  python3 "$helper" "$1" >/dev/null 2>&1 || {
    printf 'warning: terminal background unchanged for %s\n' "$1" >&2
    return 0
  }
}

switch_rewrite_header() {
  local file="$1"
  local key="$2"
  local value="$3"
  local temporary="$file.tmp.$$"
  cp -p -- "$file" "$temporary" || return 1
  if ! SWITCH_HEADER_KEY="$key" SWITCH_HEADER_VALUE="$value" awk -v limit="$SWITCH_HEADER_SCAN_LINES" '
    BEGIN {
      key = ENVIRON["SWITCH_HEADER_KEY"]
      value = ENVIRON["SWITCH_HEADER_VALUE"]
      text = "# @" key ": " value
      target = 0
      last = 0
      insert = 0
    }
    { lines[NR] = $0 }
    NR <= limit && target == 0 && $0 ~ ("^#[ \t]*@" key ":") { target = NR }
    NR <= limit && /^#[ \t]*@[A-Za-z_]+:/ { last = NR }
    END {
      if (target > 0) {
        lines[target] = text
      } else if (NR > 0) {
        insert = (last > 0) ? last : 1
      }
      for (position = 1; position <= NR; position++) {
        print lines[position]
        if (insert > 0 && position == insert) { print text }
      }
      if (NR == 0) { print text }
    }
  ' "$file" > "$temporary"; then
    rm -f -- "$temporary"
    return 1
  fi
  mv -f -- "$temporary" "$file" || { rm -f -- "$temporary"; return 1; }
  return 0
}

switch_preview_columns() {
  local columns="${COLUMNS:-}"
  case "$columns" in
    '' | *[!0-9]*) columns="$SWITCH_DEFAULT_COLUMNS" ;;
  esac
  [ "${#columns}" -le 9 ] || columns="$SWITCH_MAX_COLUMNS"
  columns=$(( 10#$columns ))
  [ "$columns" -ge "$SWITCH_MIN_COLUMNS" ] || columns="$SWITCH_DEFAULT_COLUMNS"
  [ "$columns" -le "$SWITCH_MAX_COLUMNS" ] || columns="$SWITCH_MAX_COLUMNS"
  printf '%s' "$columns"
}

switch_set_rule() {
  local width="$1"
  local rule=""
  while [ "${#rule}" -lt "$width" ]; do
    rule="$rule------------------------------"
  done
  SWITCH_RULE="${rule:0:width}"
}

switch_command_list() {
  local use_color=0
  local argument
  for argument in "$@"; do
    case "$argument" in
      --color) use_color=1 ;;
      --no-color) use_color=0 ;;
      *) switch_fail "unknown option for list: $argument" ;;
    esac
  done
  [ -z "${NO_COLOR:-}" ] || use_color=0

  local count="${#SWITCH_NAMES[@]}"
  if [ "$count" -eq 0 ]; then
    printf 'no themes in %s\n' "$SWITCH_THEME_DIR"
    return 0
  fi

  local number_width="${#count}"
  local name_width=4
  local index
  for (( index = 0; index < count; index++ )); do
    [ "${#SWITCH_NAMES[index]}" -gt "$name_width" ] && name_width="${#SWITCH_NAMES[index]}"
  done

  local line
  local marker
  printf -v line '%s %*s  %-*s  %s' ' ' "$number_width" '#' "$name_width" 'theme' 'description'
  if [ "$use_color" = "1" ]; then
    printf '%s[2m%s%s[0m\n' "$SWITCH_ESC" "$line" "$SWITCH_ESC"
  else
    printf '%s\n' "$line"
  fi

  for (( index = 0; index < count; index++ )); do
    marker=' '
    [ "${SWITCH_NAMES[index]}" = "$SWITCH_ACTIVE" ] && marker='*'
    printf -v line '%s %*s  %-*s  %s' "$marker" "$number_width" "$(( index + 1 ))" \
      "$name_width" "${SWITCH_NAMES[index]}" "${SWITCH_DESCRIPTIONS[index]}"
    if [ "$use_color" = "1" ] && [ "$marker" = '*' ]; then
      printf '%s[1;38;5;141m%s%s[0m\n' "$SWITCH_ESC" "$line" "$SWITCH_ESC"
    else
      printf '%s\n' "$line"
    fi
  done

  if switch_active_index; then
    switch_set_summary "$SWITCH_INDEX"
    printf 'active: %s\n' "$SWITCH_SUMMARY"
  else
    printf 'active: %s - no file themes/%s.sh\n' "$SWITCH_ACTIVE" "$SWITCH_ACTIVE"
  fi
  return 0
}

switch_command_show() {
  [ "$#" -eq 0 ] || switch_fail "usage: switch.sh show"
  if ! switch_active_index; then
    switch_fail "active theme $SWITCH_ACTIVE has no file in $SWITCH_THEME_DIR"
  fi
  switch_set_summary "$SWITCH_INDEX"
  printf 'active: %s\n' "$SWITCH_SUMMARY"
  return 0
}

switch_command_set() {
  local reference="${1:-}"
  [ "$#" -eq 1 ] || switch_fail "usage: switch.sh set <number|name>"
  switch_require_themes
  switch_resolve "$reference" || switch_reject_reference "$reference"
  switch_write_selected "${SWITCH_NAMES[SWITCH_INDEX]}"
  switch_set_summary "$SWITCH_INDEX"
  printf 'active: %s\n' "$SWITCH_SUMMARY"
  return 0
}

switch_command_step() {
  local direction="$1"
  shift
  [ "$#" -eq 0 ] || switch_fail "usage: switch.sh $direction"
  switch_require_themes
  local count="${#SWITCH_NAMES[@]}"
  local index=0
  if switch_active_index; then
    index="$SWITCH_INDEX"
    if [ "$direction" = "next" ]; then
      index=$(( (index + 1) % count ))
    else
      index=$(( (index + count - 1) % count ))
    fi
  fi
  switch_write_selected "${SWITCH_NAMES[index]}"
  switch_set_summary "$index"
  printf 'active: %s\n' "$SWITCH_SUMMARY"
  return 0
}

switch_render_preview() {
  local index="$1"
  local columns="$2"
  local name="${SWITCH_NAMES[index]}"
  local file="$SWITCH_THEME_DIR/$name.sh"
  local output=""
  local status=0
  local problem=""

  switch_set_rule "$columns"
  switch_set_summary "$index"
  printf '%s\n' "$SWITCH_RULE"
  printf 'theme %s\n' "$SWITCH_SUMMARY"
  printf '%s\n' "$SWITCH_RULE"

  : > "$SWITCH_PREVIEW_ERRORS" || switch_abort "cannot write $SWITCH_PREVIEW_ERRORS"
  if [ ! -f "$file" ]; then
    problem="no file themes/$name.sh"
  elif ! bash -n -- "$file" 2>> "$SWITCH_PREVIEW_ERRORS"; then
    problem="the theme file does not parse"
  fi

  if [ -z "$problem" ]; then
    output="$(SL_PREVIEW=1 COLUMNS="$columns" "$SWITCH_RENDERER" --theme "$name" \
      < "$SWITCH_PAYLOAD" 2>> "$SWITCH_PREVIEW_ERRORS")" || status=$?
    [ -z "$output" ] || printf '%s\n' "$output"
  fi
  printf '\n'

  if [ -z "$problem" ]; then
    if [ "$status" -ne 0 ]; then
      problem="the renderer exited $status"
    elif [ -s "$SWITCH_PREVIEW_ERRORS" ]; then
      problem="the theme wrote to stderr"
    elif [ -z "${output//[[:space:]]/}" ]; then
      problem="the theme rendered nothing"
    fi
  fi

  [ -n "$problem" ] || return 0
  printf 'preview failed: %s (%s)\n' "$name" "$problem" >&2
  [ ! -s "$SWITCH_PREVIEW_ERRORS" ] || cat -- "$SWITCH_PREVIEW_ERRORS" >&2
  return 1
}

switch_command_preview() {
  local reference="${1:-}"
  [ "$#" -eq 1 ] || switch_fail "usage: switch.sh preview <number|name>|--all"
  switch_require_themes
  [ -f "$SWITCH_PAYLOAD" ] || switch_abort "no sample payload at $SWITCH_PAYLOAD"
  [ -r "$SWITCH_RENDERER" ] || switch_abort "no renderer at $SWITCH_RENDERER"

  local columns
  columns="$(switch_preview_columns)"
  local failures=0
  local index

  SWITCH_PREVIEW_ERRORS="${TMPDIR:-/tmp}/switch-preview.$$"
  trap 'rm -f -- "$SWITCH_PREVIEW_ERRORS"' EXIT

  if [ "$reference" = "--all" ]; then
    for (( index = 0; index < ${#SWITCH_NAMES[@]}; index++ )); do
      switch_render_preview "$index" "$columns" || failures=$(( failures + 1 ))
    done
  else
    switch_resolve "$reference" || switch_reject_reference "$reference"
    switch_render_preview "$SWITCH_INDEX" "$columns" || failures=$(( failures + 1 ))
  fi

  [ "$failures" -eq 0 ] || exit 2
  return 0
}

switch_command_path() {
  local reference="${1:-}"
  [ "$#" -eq 1 ] || switch_fail "usage: switch.sh path <number|name>"
  switch_require_themes
  switch_resolve "$reference" || switch_reject_reference "$reference"
  printf '%s/%s.sh\n' "$SWITCH_THEME_DIR" "${SWITCH_NAMES[SWITCH_INDEX]}"
  return 0
}

switch_command_rename() {
  local reference="${1:-}"
  local target="${2:-}"
  [ "$#" -eq 2 ] || switch_fail "usage: switch.sh rename <number|name> <new-name>"
  switch_require_themes
  switch_resolve "$reference" || switch_reject_reference "$reference"
  switch_valid_name "$target" || switch_fail "invalid theme name: '$target' (allowed: a-z A-Z 0-9 _ -, not starting with a dash)"

  local old_name="${SWITCH_NAMES[SWITCH_INDEX]}"
  [ "$target" != "$old_name" ] || switch_fail "already named $target"
  local old_file="$SWITCH_THEME_DIR/$old_name.sh"
  local new_file="$SWITCH_THEME_DIR/$target.sh"
  [ -e "$new_file" ] && switch_fail "name already taken: $target"
  [ -f "$old_file" ] || switch_abort "missing theme file $old_file"

  mv -- "$old_file" "$new_file" || switch_abort "cannot move $old_file to $new_file"
  switch_rewrite_header "$new_file" name "$target" || switch_abort "cannot rewrite @name in $new_file"
  printf 'renamed: themes/%s.sh -> themes/%s.sh (@name: %s)\n' "$old_name" "$target" "$target"

  if [ "$old_name" = "$SWITCH_ACTIVE" ]; then
    switch_write_selected "$target"
    printf 'active: %s\n' "$target"
  fi
  return 0
}

switch_command_describe() {
  local reference="${1:-}"
  [ "$#" -ge 2 ] || switch_fail "usage: switch.sh describe <number|name> <text>"
  shift
  switch_require_themes
  switch_resolve "$reference" || switch_reject_reference "$reference"

  local text="$*"
  text="${text//$'\n'/ }"
  text="${text//$'\r'/ }"
  text="${text//$'\t'/ }"
  text="${text//"$SWITCH_FIELD"/ }"
  [ -n "${text//[[:space:]]/}" ] || switch_fail "description must not be empty"

  local name="${SWITCH_NAMES[SWITCH_INDEX]}"
  local file="$SWITCH_THEME_DIR/$name.sh"
  [ -f "$file" ] || switch_abort "missing theme file $file"
  switch_rewrite_header "$file" description "$text" || switch_abort "cannot rewrite @description in $file"
  printf 'described: themes/%s.sh (@description: %s)\n' "$name" "$text"
  return 0
}

switch_command_clone() {
  local reference="${1:-}"
  local target="${2:-}"
  [ "$#" -eq 2 ] || switch_fail "usage: switch.sh clone <number|name> <new-name>"
  switch_require_themes
  switch_resolve "$reference" || switch_reject_reference "$reference"
  switch_valid_name "$target" || switch_fail "invalid theme name: '$target' (allowed: a-z A-Z 0-9 _ -, not starting with a dash)"

  local source_name="${SWITCH_NAMES[SWITCH_INDEX]}"
  local source_file="$SWITCH_THEME_DIR/$source_name.sh"
  local new_file="$SWITCH_THEME_DIR/$target.sh"
  [ -e "$new_file" ] && switch_fail "name already taken: $target"
  [ -f "$source_file" ] || switch_abort "missing theme file $source_file"

  local highest="${SWITCH_ORDERS[${#SWITCH_ORDERS[@]} - 1]}"
  case "$highest" in
    '' | *[!0-9]*) highest="$SWITCH_DEFAULT_ORDER" ;;
  esac
  [ "${#highest}" -le 9 ] || highest="$SWITCH_MAX_ORDER"
  local new_order
  new_order=$(( 10#$highest + SWITCH_ORDER_STEP ))
  [ "$new_order" -le "$SWITCH_MAX_ORDER" ] \
    || switch_fail "cannot clone: no @order left above $highest, the ceiling is $SWITCH_MAX_ORDER"

  cp -p -- "$source_file" "$new_file" || switch_abort "cannot copy $source_file to $new_file"
  if ! switch_rewrite_header "$new_file" name "$target" \
    || ! switch_rewrite_header "$new_file" order "$new_order"; then
    rm -f -- "$new_file"
    switch_abort "cannot rewrite the header of $new_file"
  fi
  printf 'cloned: themes/%s.sh -> themes/%s.sh (@name: %s, @order: %s)\n' \
    "$source_name" "$target" "$target" "$new_order"
  return 0
}

switch_command_delete() {
  local reference=""
  local is_forced=0
  local is_option_section=1
  local argument
  for argument in "$@"; do
    if [ "$is_option_section" = "1" ]; then
      case "$argument" in
        --) is_option_section=0; continue ;;
        --force) is_forced=1; continue ;;
        -*) switch_fail "unknown option for delete: $argument" ;;
      esac
    fi
    [ -z "$reference" ] || switch_fail "usage: switch.sh delete <number|name> [--force]"
    reference="$argument"
  done
  [ -n "$reference" ] || switch_fail "usage: switch.sh delete <number|name> [--force]"
  switch_require_themes
  switch_resolve "$reference" || switch_reject_reference "$reference"
  [ "${#SWITCH_NAMES[@]}" -gt 1 ] || switch_fail "refusing to delete the only theme"

  local victim="${SWITCH_NAMES[SWITCH_INDEX]}"
  local file="$SWITCH_THEME_DIR/$victim.sh"
  [ -f "$file" ] || switch_abort "missing theme file $file"

  local fallback=""
  if [ "$victim" = "$SWITCH_ACTIVE" ]; then
    [ "$is_forced" = "1" ] || switch_fail "$victim is the active theme; pass --force to delete it"
    local index
    for (( index = 0; index < ${#SWITCH_NAMES[@]}; index++ )); do
      if [ "$index" != "$SWITCH_INDEX" ]; then
        fallback="${SWITCH_NAMES[index]}"
        break
      fi
    done
    [ -n "$fallback" ] || switch_abort "no theme left to fall back to"
    switch_write_selected "$fallback"
  fi

  rm -f -- "$file" || switch_abort "cannot remove $file"
  printf 'deleted: themes/%s.sh\n' "$victim"
  [ -n "$fallback" ] && printf 'active: %s\n' "$fallback"
  return 0
}

switch_usage() {
  printf '%s\n' \
    'usage: switch.sh <command> [arguments]' \
    '' \
    '  list [--color]             numbered table of the themes, active one marked *' \
    '  set <number|name>          activate a theme' \
    '  next                       activate the next theme, wrapping at the end' \
    '  prev                       activate the previous theme, wrapping at the start' \
    '  show                       print the active number, name and description' \
    '  preview <number|name>      render one theme against the sample payload' \
    '  preview --all              render every theme in order' \
    '  path <number|name>         print the absolute path of the theme file' \
    '  rename <ref> <new-name>    rename the file and its @name header' \
    '  describe <ref> <text>      rewrite the @description header' \
    '  clone <ref> <new-name>     copy a theme to the end of the list' \
    '  delete <ref> [--force]     remove a theme file, --force if it is active' \
    '  apply-background           re-apply the terminal look for the active theme\n  help                       this text' \
    '' \
    'A theme is addressed by its number or its name. Numbers come from @order' \
    'in each file, so they shift when a theme is added, removed or reordered.' \
    'Names may contain letters, digits, underscore and dash only, and may not' \
    'start with a dash.' \
    '' \
    'Exit status: 0 success, 1 user error, 2 internal error.'
}

switch_main() {
  local command="list"
  if [ "$#" -gt 0 ]; then
    command="$1"
    shift
  fi

  [ -d "$SWITCH_THEME_DIR" ] || switch_abort "no theme directory at $SWITCH_THEME_DIR"
  switch_load
  switch_read_active

  case "$command" in
    list | ls) switch_command_list "$@" ;;
    set | use) switch_command_set "$@" ;;
    next) switch_command_step next "$@" ;;
    prev | previous) switch_command_step prev "$@" ;;
    show | current) switch_command_show "$@" ;;
    preview) switch_command_preview "$@" ;;
    path) switch_command_path "$@" ;;
    rename) switch_command_rename "$@" ;;
    describe) switch_command_describe "$@" ;;
    clone) switch_command_clone "$@" ;;
    delete | remove) switch_command_delete "$@" ;;
    apply-background)
      switch_apply_background "$SWITCH_ACTIVE"
      printf 'terminal background applied for %s\n' "$SWITCH_ACTIVE"
      ;;
    help | --help | -h) switch_usage ;;
    *)
      if [ "$#" -eq 0 ] && switch_resolve "$command"; then
        switch_command_set "$command"
      else
        printf 'error: unknown command: %s\n' "$command" >&2
        switch_usage >&2
        exit 1
      fi
      ;;
  esac
}

switch_main "$@"
