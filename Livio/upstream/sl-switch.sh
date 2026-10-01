#!/usr/bin/env bash
# Switch the Claude Code status line theme. Backs the /sl slash command.
#
#   sl-switch.sh             show the active theme and the available ones
#   sl-switch.sh water       switch to the "water" theme
#   sl-switch.sh water 18    switch, and make the tank 18 rows tall
#   sl-switch.sh water full  switch, and let the tank fill the terminal
set -u

CLAUDE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEMES_DIR="$CLAUDE_DIR/statuslines"
STATE_FILE="$CLAUDE_DIR/statusline-theme"
HEIGHT_FILE="$CLAUDE_DIR/statusline-water-height"
DEFAULT_THEME="rgb"

# A theme is a module with a DESCRIPTION; common.py and the GIF writers are not.
themes() {
    local name
    while read -r name; do
        [ -n "$(describe "$name")" ] && printf '%s\n' "$name"
    done < <(find "$THEMES_DIR" -maxdepth 1 -name '*.py' -printf '%f\n' 2>/dev/null \
             | sed 's/\.py$//' | sort)
    return 0
}

describe() {
    sed -n 's/^DESCRIPTION = "\(.*\)"$/\1/p' "$THEMES_DIR/$1.py" 2>/dev/null | head -1
}

current() {
    local name=""
    [ -r "$STATE_FILE" ] && name="$(tr -d '[:space:]' < "$STATE_FILE")"
    themes | grep -qx -- "$name" 2>/dev/null || name="$DEFAULT_THEME"
    printf '%s' "$name"
}

listing() {
    local active="$1" name desc mark
    while read -r name; do
        [ -n "$name" ] || continue
        desc="$(describe "$name")"
        mark="  "
        [ "$name" = "$active" ] && mark="* "
        printf '%s%-8s %s\n' "$mark" "$name" "${desc:-}"
    done < <(themes)
}

# The slash command passes every argument as one string, so split it here.
read -r want size _rest <<< "${1:-}"
want="${want:-}"
size="${size:-}"
active="$(current)"

if [ -z "$want" ]; then
    printf 'Active status line theme: %s\n\n' "$active"
    listing "$active"
    printf '\nSwitch with: /sl <name>'
    printf '\nTank height: /sl water <rows|full|auto>   (currently %s)\n' \
        "$( [ -r "$HEIGHT_FILE" ] && cat "$HEIGHT_FILE" || echo auto )"
    exit 0
fi

case "$want" in
    *[!a-zA-Z0-9_-]*)
        printf 'Invalid theme name.\n' >&2
        exit 1
        ;;
esac

if ! themes | grep -qx -- "$want"; then
    printf 'No such theme: %s\n\nAvailable:\n' "$want" >&2
    listing "$active" >&2
    exit 1
fi

if [ -n "$size" ]; then
    case "$size" in
        full|auto|[1-9]|[1-9][0-9]) printf '%s\n' "$size" > "$HEIGHT_FILE" ;;
        *) printf 'Ignoring height "%s": use a row count, "full" or "auto".\n' "$size" >&2 ;;
    esac
fi

printf '%s\n' "$want" > "$STATE_FILE"
printf 'Status line theme switched to "%s" — %s\n' "$want" "$(describe "$want")"
if [ "$want" = "$active" ]; then
    printf '(it was already active)\n'
fi

case "$want" in water|water2) is_water=1 ;; *) is_water=0 ;; esac
case "$want" in vice) is_vice=1 ;; *) is_vice=0 ;; esac
case "$want" in kyoto) is_kyoto=1 ;; *) is_kyoto=0 ;; esac

if [ "$is_water" = 1 ]; then
    printf 'Tank height: %s\n' "$( [ -r "$HEIGHT_FILE" ] && cat "$HEIGHT_FILE" || echo auto )"
    if [ "$want" = "water2" ]; then
        printf 'Needs a font with Unicode 16 octants (CaskaydiaMono NF has them).\n'
        printf 'If the scenery comes out as empty boxes, fall back with: /sl water\n'
    fi
    if [ -n "${WT_SESSION:-}" ]; then
        GIFS="$(python3 "$CLAUDE_DIR/sl-water-bg.py" status 2>/dev/null \
                | sed -n 's/^gif dir  : //p')"
        if [ -n "$GIFS" ] && [ ! -e "$GIFS/water-000.gif" ]; then
            printf 'Rendering the background GIFs (one-off, ~15s)...\n'
            python3 -c "
import sys; sys.path.insert(0, '$THEMES_DIR')
import watergif; watergif.build_all('$GIFS')" || printf 'GIF render failed.\n' >&2
        fi
        python3 "$CLAUDE_DIR/sl-water-bg.py" apply 0 >/dev/null 2>&1 \
            && printf 'Full-screen water enabled in Windows Terminal.\n' \
            || printf 'Could not set the terminal background; the panel still works.\n'
    else
        printf 'Not running in Windows Terminal — panel only, no full-screen water.\n'
    fi
elif [ "$is_vice" = 1 ]; then
    if [ -n "${WT_SESSION:-}" ]; then
        GIFS="$(python3 "$CLAUDE_DIR/sl-water-bg.py" status 2>/dev/null \
                | sed -n 's/^gif dir  : //p')"
        if [ -n "$GIFS" ] && [ ! -e "$GIFS/vice-000.gif" ]; then
            printf 'Rendering the 144 ten-minute backgrounds (one-off, ~9min)...\n'
            python3 -c "
import sys; sys.path.insert(0, '$THEMES_DIR')
import vicegif; vicegif.build_all('$GIFS')" || printf 'GIF render failed.\n' >&2
        fi
        BAND=$(( $(date +%-H) * 6 + $(date +%-M) / 10 ))
        python3 "$CLAUDE_DIR/sl-water-bg.py" apply "$BAND" --set vice >/dev/null 2>&1 \
            && printf 'Full-screen Vice City enabled (band %s of 144, %s).\n' \
               "$BAND" "$(date +%H:%M)" \
            || printf 'Could not set the terminal background; the panel still works.\n'
    else
        printf 'Not running in Windows Terminal - panel only, no full-screen panorama.\n'
    fi
elif [ "$is_kyoto" = 1 ]; then
    if [ -n "${WT_SESSION:-}" ]; then
        GIFS="$(python3 "$CLAUDE_DIR/sl-water-bg.py" status 2>/dev/null \
                | sed -n 's/^gif dir  : //p')"
        if [ -n "$GIFS" ] && [ ! -e "$GIFS/kyoto-000.gif" ]; then
            printf 'Rendering the valley (one-off, ~10s)...\n'
            python3 -c "
import sys; sys.path.insert(0, '$THEMES_DIR')
import kyotogif; kyotogif.build_all('$GIFS')" || printf 'GIF render failed.\n' >&2
        fi
        python3 "$CLAUDE_DIR/sl-water-bg.py" apply 0 --set kyoto >/dev/null 2>&1 \
            && printf 'Full-screen Kyoto enabled in Windows Terminal.\n' \
            || printf 'Could not set the terminal background; the panel still works.\n'
    else
        printf 'Not running in Windows Terminal - panel only, no full-screen valley.\n'
    fi
else
    python3 "$CLAUDE_DIR/sl-water-bg.py" restore 2>/dev/null \
        | grep -q restored && printf 'Windows Terminal background removed.\n'
fi
