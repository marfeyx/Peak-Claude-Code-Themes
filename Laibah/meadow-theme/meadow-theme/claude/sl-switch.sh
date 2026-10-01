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
DEFAULT_THEME="meadow"

# Per theme, because the themes read different files: water.py looks at
# statusline-water-height and meadow.py at statusline-meadow-height. One shared
# path meant `/sl meadow 14` wrote a number meadow never reads.
height_file() { printf '%s/statusline-%s-height' "$CLAUDE_DIR" "$1"; }

# A theme is a module with a DESCRIPTION; common.py and the GIF writers are not.
themes() {
    local name
    while read -r name; do
        [ -n "$(describe "$name")" ] && printf '%s\n' "$name"
    done < <(find "$THEMES_DIR" -maxdepth 1 -name '*.py' -exec basename {} .py \; 2>/dev/null \
             | sort)
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
    printf '\nPanel height: /sl <theme> <rows|full|auto>   (water %s, meadow %s)\n' \
        "$( [ -r "$(height_file water)" ] && cat "$(height_file water)" || echo auto )" \
        "$( [ -r "$(height_file meadow)" ] && cat "$(height_file meadow)" || echo auto )"
    if [ "$active" = "meadow" ]; then
        python3 "$CLAUDE_DIR/sl-meadow-sky.py" status 2>/dev/null \
            | sed -n 's/^/Day cycle: /p' | head -4
    fi
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
        full|auto|[1-9]|[1-9][0-9]) printf '%s\n' "$size" > "$(height_file "$want")" ;;
        *) printf 'Ignoring height "%s": use a row count, "full" or "auto".\n' "$size" >&2 ;;
    esac
fi

printf '%s\n' "$want" > "$STATE_FILE"
printf 'Status line theme switched to "%s" — %s\n' "$want" "$(describe "$want")"
if [ "$want" = "$active" ]; then
    printf '(it was already active)\n'
fi

# Each scene theme owns a terminal background. Switching to one applies it;
# switching to anything else puts the profile back. The Claude Code UI theme is
# restored unconditionally first, because only meadow changes it and leaving a
# light UI theme behind on a dark background is the one combination that is
# genuinely unreadable.
python3 "$CLAUDE_DIR/sl-cc-theme.py" restore >/dev/null 2>&1

if [ "$want" = "water" ]; then
    printf 'Tank height: %s\n' \
        "$( [ -r "$(height_file water)" ] && cat "$(height_file water)" || echo auto )"
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
elif [ "$want" = "meadow" ]; then
    if [ -n "${WT_SESSION:-}" ]; then
        GIFS="$(python3 "$CLAUDE_DIR/sl-water-bg.py" status 2>/dev/null \
                | sed -n 's/^gif dir  : //p')"
        SKY="$GIFS/meadow-sky.gif"
        # The static midday sky, kept as the fallback the applier reaches for
        # if the segment set is missing or half-written.
        if [ -n "$GIFS" ] && [ ! -e "$SKY" ]; then
            printf 'Rendering the fallback sky (one-off, ~1s)...\n'
            python3 -c "
import sys; sys.path.insert(0, '$THEMES_DIR')
import meadowsky; meadowsky.build('$SKY')" || printf 'Sky render failed.\n' >&2
        fi
        # The day cycle proper: one GIF per segment of the loop. Rebuilt only
        # when the period, the segment count or the art changes.
        if python3 "$CLAUDE_DIR/sl-meadow-sky.py" status 2>/dev/null \
           | grep -q 'stale'; then
            printf 'Rendering the day cycle (one-off, ~30s)...\n'
            python3 "$CLAUDE_DIR/sl-meadow-sky.py" build \
                || printf 'Sky render failed; falling back to the static sky.\n' >&2
        fi
        # Background image, terminal scheme and Claude Code theme move together.
        # Doing one without the others leaves the window unreadable either way:
        # a dark UI under a bright sky, or a light one under a midnight sky.
        if python3 "$CLAUDE_DIR/sl-meadow-sky.py" now >/dev/null 2>&1; then
            printf 'Sky enabled behind the whole terminal, on a %s cycle.\n' \
                "$(python3 -c "
import sys; sys.path.insert(0, '$THEMES_DIR')
import daylight; print('%g-minute' % (daylight.period() / 60.0))")"
        else
            printf 'Could not set the terminal background; the panel still works.\n'
        fi
    else
        printf 'Not running in Windows Terminal — grass panel only, no sky.\n'
    fi
else
    # Forget which segment was applied, so returning to meadow re-applies
    # rather than believing a state file that no longer describes the profile.
    rm -f "$CLAUDE_DIR/statusline-meadow-applied" "$CLAUDE_DIR/statusline-meadow-apply.lock"
    python3 "$CLAUDE_DIR/sl-water-bg.py" restore 2>/dev/null \
        | grep -q restored && printf 'Windows Terminal background removed.\n'
fi
