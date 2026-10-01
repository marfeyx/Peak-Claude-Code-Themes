#!/usr/bin/env bash
# Install the "meadow" Claude Code status line theme.
#
#   ./install.sh            install, then build the sky and switch to it
#   ./install.sh --no-build skip the ~1 minute GIF render
#   ./install.sh --files    copy files only, change no settings
#
# Nothing here overwrites your settings.json wholesale. Two keys are merged in
# (statusLine, and theme only via the theme's own backup-aware switcher), and
# every file this would replace is backed up next to itself first.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/claude"
DEST="${CLAUDE_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BUILD=1
FILES_ONLY=0

for arg in "$@"; do
    case "$arg" in
        --no-build) BUILD=0 ;;
        --files)    FILES_ONLY=1; BUILD=0 ;;
        -h|--help)  sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$arg" >&2; exit 1 ;;
    esac
done

say()  { printf '  %s\n' "$*"; }
head2() { printf '\n%s\n' "$*"; }

# ---------------------------------------------------------------- prerequisites
head2 "Checking prerequisites"

if ! command -v python3 >/dev/null 2>&1; then
    printf 'python3 is required but not on PATH.\n' >&2
    exit 1
fi
PYV="$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
if ! python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)'; then
    printf 'Python 3.8+ required, found %s.\n' "$PYV" >&2
    exit 1
fi
say "python3 $PYV — ok (the theme is pure stdlib, nothing to pip install)"

if [ -n "${WT_SESSION:-}" ]; then
    say "Windows Terminal detected — the animated sky will be enabled"
    IN_WT=1
else
    IN_WT=0
    say "Not running in Windows Terminal — you'll get the grass panel only."
    say "  (The sky background and colour scheme need Windows Terminal.)"
fi

# ------------------------------------------------------------------ copy files
head2 "Installing files into $DEST"

mkdir -p "$DEST/statuslines" "$DEST/themes" "$DEST/commands" || exit 1

BACKED_UP=0
install_one() {
    # $1 = path relative to $SRC
    local rel="$1" src="$SRC/$1" dst="$DEST/$1"
    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ] && ! cmp -s "$src" "$dst"; then
        cp -p "$dst" "$dst.before-meadow-$STAMP.bak"
        BACKED_UP=$((BACKED_UP + 1))
        say "backed up existing $rel"
    fi
    cp -p "$src" "$dst"
}

while IFS= read -r rel; do
    [ "$rel" = "commands/sl.md.template" ] && continue
    install_one "$rel"
done < <(cd "$SRC" && find . -type f | sed 's|^\./||' | sort)

chmod +x "$DEST/sl-switch.sh" "$DEST/sl-meadow-sky.py" \
         "$DEST/sl-cc-theme.py" "$DEST/sl-water-bg.py" 2>/dev/null

# The slash command has to name an absolute path in allowed-tools, so it is
# generated here rather than shipped with somebody else's home directory in it.
sed "s|__CLAUDE_DIR__|$DEST|g" "$SRC/commands/sl.md.template" > "$DEST/commands/sl.md.new"
if [ -e "$DEST/commands/sl.md" ] && ! cmp -s "$DEST/commands/sl.md.new" "$DEST/commands/sl.md"; then
    cp -p "$DEST/commands/sl.md" "$DEST/commands/sl.md.before-meadow-$STAMP.bak"
    say "backed up existing commands/sl.md"
fi
mv "$DEST/commands/sl.md.new" "$DEST/commands/sl.md"

say "$(cd "$SRC" && find . -type f | wc -l) files installed, $BACKED_UP backed up"

if [ "$FILES_ONLY" = "1" ]; then
    head2 "Done (files only)"
    say "Nothing in your settings was changed. To finish by hand, point"
    say "statusLine.command at: python3 $DEST/statusline.py"
    exit 0
fi

# -------------------------------------------------------------- merge settings
head2 "Wiring up settings.json"

CLAUDE_SETTINGS="$DEST/settings.json" python3 - "$DEST" <<'PY'
import json, os, shutil, sys

dest = sys.argv[1]
path = os.environ["CLAUDE_SETTINGS"]
data = {}

if os.path.exists(path):
    try:
        with open(path, encoding="utf-8-sig") as fh:
            data = json.load(fh)
    except ValueError as exc:
        sys.exit("  settings.json is not valid JSON (%s) — fix it and re-run." % exc)
    shutil.copy2(path, path + ".before-meadow.bak")
    print("  backed up settings.json -> settings.json.before-meadow.bak")

want = {"type": "command",
        "command": "python3 %s/statusline.py" % dest,
        "refreshInterval": 1}

if data.get("statusLine") == want:
    print("  statusLine already correct")
else:
    if "statusLine" in data:
        print("  replacing your existing statusLine (the backup has the old one)")
    data["statusLine"] = want
    print("  statusLine -> python3 %s/statusline.py" % dest)

# NOTE: "theme" is deliberately NOT set here. sl-cc-theme.py records your
# current theme the first time it switches, and restores it on uninstall. If we
# set it now, that backup would record "meadow" as your original.
print("  theme      -> left alone for now; the switcher will back it up first")

tmp = path + ".meadow-tmp"
with open(tmp, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
os.replace(tmp, path)
PY
[ $? -ne 0 ] && exit 1

# ----------------------------------------------------------------- switch over
head2 "Activating"

if [ "$BUILD" = "1" ] && [ "$IN_WT" = "1" ]; then
    say "Rendering the day-cycle sky — about a minute, one time only..."
fi

if [ "$BUILD" = "0" ]; then
    printf 'meadow\n' > "$DEST/statusline-theme"
    say "theme set to meadow (sky not built; run '$DEST/sl-switch.sh meadow' when ready)"
else
    "$DEST/sl-switch.sh" meadow || {
        printf 'Switch failed. The files are installed; try: %s/sl-switch.sh meadow\n' "$DEST" >&2
        exit 1
    }
fi

head2 "Done"
say "Open a new Claude Code session — the meadow appears in the status line."
say "Switch themes with /sl. Preview the whole day cycle as a PNG with:"
say "  python3 $DEST/statuslines/preview_meadow.py /tmp/meadow-cycle.png"
say "To remove it all again: ./uninstall.sh"
