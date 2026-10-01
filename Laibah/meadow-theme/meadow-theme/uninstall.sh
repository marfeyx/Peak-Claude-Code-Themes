#!/usr/bin/env bash
# Remove the meadow theme and put everything back the way it was.
#
#   ./uninstall.sh           restore your terminal, colour scheme and UI theme
#   ./uninstall.sh --purge   also delete the installed files and the sky GIFs
#
# Without --purge this leaves the files on disk but inert, so you can switch
# back with /sl meadow. Your own settings.json backups are never deleted.
set -u

DEST="${CLAUDE_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}}"
PURGE=0
for arg in "$@"; do
    case "$arg" in
        --purge)   PURGE=1 ;;
        -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$arg" >&2; exit 1 ;;
    esac
done

say() { printf '  %s\n' "$*"; }
printf '\nRestoring\n'

# Order matters: the UI theme first, then the terminal. Leaving a light UI theme
# behind on a restored dark background is the one unreadable combination.
if [ -f "$DEST/sl-cc-theme.py" ]; then
    python3 "$DEST/sl-cc-theme.py" restore 2>/dev/null | sed 's/^/  /' \
        || say "no Claude Code theme to restore"
fi

if [ -f "$DEST/sl-water-bg.py" ]; then
    python3 "$DEST/sl-water-bg.py" restore 2>/dev/null | sed 's/^/  /' \
        || say "no Windows Terminal profile to restore"
fi

# Drop the statusLine key rather than restoring the whole file: the backup is
# from install time and you may have changed other settings since.
if [ -f "$DEST/settings.json" ]; then
    CLAUDE_SETTINGS="$DEST/settings.json" python3 - <<'PY'
import json, os, shutil
path = os.environ["CLAUDE_SETTINGS"]
try:
    with open(path, encoding="utf-8-sig") as fh:
        data = json.load(fh)
except (OSError, ValueError) as exc:
    raise SystemExit("  could not read settings.json (%s) — left alone" % exc)

cmd = (data.get("statusLine") or {}).get("command", "")
if "statusline.py" in cmd:
    shutil.copy2(path, path + ".before-meadow-uninstall.bak")
    del data["statusLine"]
    tmp = path + ".meadow-tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    os.replace(tmp, path)
    print("  removed the statusLine setting")
else:
    print("  statusLine is not ours — left alone")
PY
fi

# Runtime state this theme created. Not your data, safe to drop.
for f in statusline-theme statusline-meadow-applied statusline-meadow-apply.lock \
         statusline-meadow-height statusline-meadow-period statusline-wt-applied; do
    [ -e "$DEST/$f" ] && rm -f "$DEST/$f" && say "removed state file $f"
done

if [ "$PURGE" = "1" ]; then
    printf '\nPurging installed files\n'
    for f in statusline.py sl-meadow-sky.py sl-cc-theme.py sl-water-bg.py sl-switch.sh \
             commands/sl.md themes/meadow.json themes/meadow-night.json; do
        [ -e "$DEST/$f" ] && rm -f "$DEST/$f" && say "removed $f"
    done
    for m in meadow agentcount common daylight skydriver meadowsky gifwriter \
             preview_meadow preview_png; do
        [ -e "$DEST/statuslines/$m.py" ] && rm -f "$DEST/statuslines/$m.py" && say "removed statuslines/$m.py"
    done
    rm -rf "$DEST/statuslines/__pycache__" 2>/dev/null
    rmdir "$DEST/statuslines" 2>/dev/null && say "removed empty statuslines/"

    # The rendered sky, on the Windows side.
    GIFS="$(python3 -c "
import glob, os
hits = glob.glob('/mnt/c/Users/*/AppData/Local/claude-statusline')
print(hits[0] if hits else '')" 2>/dev/null)"
    if [ -n "$GIFS" ] && [ -d "$GIFS" ]; then
        rm -f "$GIFS"/meadow-sky-*.gif "$GIFS"/meadow-sky.gif "$GIFS"/meadow-sky.json 2>/dev/null
        say "removed the rendered sky from $GIFS"
        rmdir "$GIFS" 2>/dev/null
    fi
    say "your *.before-meadow*.bak backups were kept"
fi

printf '\nDone. Restart Claude Code and Windows Terminal to see it clean.\n'
