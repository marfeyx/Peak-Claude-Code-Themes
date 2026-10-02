#!/usr/bin/env bash
# Objective renderer check for a statusline theme.
#
#   check.sh <theme> [more themes...]
#   check.sh --all
#
# Renders the theme against sample-payload.json at several terminal widths and
# with NO_COLOR, then reports anything a theme is not allowed to do: writing to
# stderr, exiting non-zero, overflowing the width budget, leaving a colour or
# background open at end of line, or emitting nothing at all.
#
# Exit status is the number of failing checks, so it is usable in a loop.

set -u

CHECK_HOME="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CHECK_PAYLOAD="$CHECK_HOME/sample-payload.json"
CHECK_WIDTHS=(30 40 50 60 80 100 160 220)
CHECK_FAILURES=0

check_theme() {
  local theme="$1" width variant no_color output stderr_text status report
  printf '\n\033[1m== %s ==\033[0m\n' "$theme"

  for width in "${CHECK_WIDTHS[@]}"; do
    for variant in color plain; do
      if [ "$variant" = "plain" ]; then
        [ "$width" = 100 ] || continue
        no_color=1
      else
        no_color=""
      fi

      stderr_text="$(mktemp)"
      output="$(SL_PREVIEW=1 COLUMNS="$width" NO_COLOR="$no_color" \
        "$CHECK_HOME/statusline.sh" --theme "$theme" < "$CHECK_PAYLOAD" 2>"$stderr_text")"
      status=$?

      report="$(CHECK_WIDTH="$width" CHECK_VARIANT="$variant" CHECK_THEME="$theme" \
        CHECK_STATUS="$status" CHECK_STDERR="$stderr_text" python3 - "$output" <<'PY'
import os, re, sys, unicodedata

text = sys.argv[1] if len(sys.argv) > 1 else ""
width = int(os.environ["CHECK_WIDTH"])
variant = os.environ["CHECK_VARIANT"]
status = os.environ["CHECK_STATUS"]
stderr_text = open(os.environ["CHECK_STDERR"]).read().strip()
budget = width - 4

sgr = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
problems = []

if status != "0":
    problems.append(f"exit status {status}")
if stderr_text:
    problems.append("stderr: " + stderr_text.replace("\n", " | ")[:300])
if not text.strip():
    problems.append("rendered nothing")

def cells(value):
    total = 0
    for character in value:
        if unicodedata.combining(character):
            continue
        total += 2 if unicodedata.east_asian_width(character) in ("W", "F") else 1
    return total

for number, line in enumerate(text.split("\n"), 1):
    plain = sgr.sub("", line)
    visible = cells(plain)
    if visible > budget:
        problems.append(f"line {number} is {visible} cells, budget {budget}")
    if "\x1b" in line:
        codes = sgr.findall(line)
        if codes and codes[-1] not in ("\x1b[0m", "\x1b[m"):
            problems.append(f"line {number} ends without a reset ({codes[-1]!r})")
    if variant == "plain" and "\x1b" in line:
        problems.append(f"line {number} emits escapes under NO_COLOR")
    if plain != plain.rstrip() and "48;" not in line and "\x1b[4" not in line:
        problems.append(f"line {number} has trailing whitespace")

label = f"{width:>3} {variant:<5}"
if problems:
    print(f"FAIL {label}")
    for problem in problems:
        print(f"       - {problem}")
    sys.exit(len(problems))
print(f"ok   {label}  {len(text.splitlines())} line(s)")
PY
)"
      printf '%s\n' "$report"
      [ -s "$stderr_text" ] && CHECK_FAILURES=$(( CHECK_FAILURES + 1 ))
      case "$report" in
        FAIL*) CHECK_FAILURES=$(( CHECK_FAILURES + 1 )) ;;
      esac
      rm -f "$stderr_text"
    done
  done

  printf '\n\033[2m  preview at 100 columns:\033[0m\n'
  SL_PREVIEW=1 COLUMNS=100 "$CHECK_HOME/statusline.sh" --theme "$theme" < "$CHECK_PAYLOAD" 2>/dev/null
  printf '\n'
}

if [ "$#" -eq 0 ] || [ "${1:-}" = "--all" ]; then
  for theme_file in "$CHECK_HOME"/themes/*.sh; do
    [ -f "$theme_file" ] || continue
    theme_name="${theme_file##*/}"
    check_theme "${theme_name%.sh}"
  done
else
  for theme_name in "$@"; do
    check_theme "$theme_name"
  done
fi

printf '\n\033[1m%s failing check(s)\033[0m\n' "$CHECK_FAILURES"
exit "$CHECK_FAILURES"
