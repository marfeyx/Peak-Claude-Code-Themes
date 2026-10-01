#!/usr/bin/env bash
# Installs the switchable statusline framework into $HOME/.claude (or $CLAUDE_DIR):
# the renderer and its helpers, the bundled purple theme, the /sl slash commands,
# and the statusLine.command entry in settings.json.
#
# Safe to re-run. settings.json is backed up with a timestamp before it is touched,
# and the new one is written to a temporary file and re-parsed before it replaces
# the original.

set -eu

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
STATUSLINE_DIR="$CLAUDE_DIR/statusline"
THEME_DIR="$STATUSLINE_DIR/themes"
COMMAND_DIR="$CLAUDE_DIR/commands"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
SELECTED_FILE="$STATUSLINE_DIR/selected"
DEFAULT_THEME="purple"
PLACEHOLDER="__CLAUDE_DIR__"

say() {
  printf '  %s\n' "$*"
}

command -v python3 >/dev/null 2>&1 || {
  printf 'python3 is required: the installer edits settings.json with it.\n' >&2
  exit 1
}

printf 'installing the statusline framework into %s\n' "$CLAUDE_DIR"

mkdir -p "$STATUSLINE_DIR" "$THEME_DIR" "$COMMAND_DIR"

for core_file in statusline.sh switch.sh check.sh; do
  install -m 0755 "$HERE/$core_file" "$STATUSLINE_DIR/$core_file"
  say "$core_file -> $STATUSLINE_DIR/$core_file"
done

install -m 0644 "$HERE/core.sh" "$STATUSLINE_DIR/core.sh"
say "core.sh -> $STATUSLINE_DIR/core.sh"

install -m 0755 "$HERE/terminal-background.py" "$STATUSLINE_DIR/terminal-background.py"
say "terminal-background.py -> $STATUSLINE_DIR/terminal-background.py"

if [ -d "$HERE/shaders" ]; then
    mkdir -p "$STATUSLINE_DIR/shaders"
    for shader in "$HERE"/shaders/*.hlsl; do
        [ -e "$shader" ] || continue
        install -m 0644 "$shader" "$STATUSLINE_DIR/shaders/$(basename "$shader")"
        say "shader $(basename "$shader") -> $STATUSLINE_DIR/shaders/"
    done
fi

install -m 0644 "$HERE/sample-payload.json" "$STATUSLINE_DIR/sample-payload.json"
say "sample-payload.json -> $STATUSLINE_DIR/sample-payload.json"

theme_count=0
for theme_file in "$HERE"/themes/*.sh; do
  [ -f "$theme_file" ] || continue
  install -m 0644 "$theme_file" "$THEME_DIR/${theme_file##*/}"
  theme_count=$(( theme_count + 1 ))
  say "theme ${theme_file##*/} -> $THEME_DIR/${theme_file##*/}"
done
[ "$theme_count" -gt 0 ] || say "no themes bundled; install one from a person folder in this repo"

for command_file in "$HERE"/commands/*.md; do
  [ -f "$command_file" ] || continue
  target="$COMMAND_DIR/${command_file##*/}"
  COMMAND_SOURCE="$command_file" COMMAND_TARGET="$target" PLACEHOLDER="$PLACEHOLDER" \
    CLAUDE_DIR="$CLAUDE_DIR" STATUSLINE_DIR="$STATUSLINE_DIR" python3 - <<'PY'
import os

source = os.environ["COMMAND_SOURCE"]
target = os.environ["COMMAND_TARGET"]
placeholder = os.environ["PLACEHOLDER"]
claude_dir = os.environ["CLAUDE_DIR"]

with open(source, "r", encoding="utf-8") as handle:
    text = handle.read()

text = text.replace(placeholder + "/statusline", os.environ["STATUSLINE_DIR"])
text = text.replace(placeholder, claude_dir)

with open(target, "w", encoding="utf-8") as handle:
    handle.write(text)
PY
  chmod 0644 "$target"
  say "command ${command_file##*/} -> $target"
done

if [ -f "$SELECTED_FILE" ]; then
  say "selected theme kept: $(cat "$SELECTED_FILE")"
else
  printf '%s\n' "$DEFAULT_THEME" > "$SELECTED_FILE"
  say "selected theme seeded: $DEFAULT_THEME"
fi

if [ -f "$SETTINGS_FILE" ]; then
  backup_file="$SETTINGS_FILE.backup.$(date +%Y%m%d-%H%M%S)"
  cp -- "$SETTINGS_FILE" "$backup_file"
  say "settings backup -> $backup_file"
fi

SETTINGS_FILE="$SETTINGS_FILE" STATUSLINE_COMMAND="$STATUSLINE_DIR/statusline.sh" python3 - <<'PY'
import json
import os
import sys

settings_path = os.environ["SETTINGS_FILE"]
command = os.environ["STATUSLINE_COMMAND"]
temporary_path = settings_path + ".tmp"

settings = {}
if os.path.exists(settings_path):
    with open(settings_path, "r", encoding="utf-8") as handle:
        raw = handle.read().strip()
    if raw:
        try:
            settings = json.loads(raw)
        except json.JSONDecodeError as error:
            sys.exit(f"{settings_path} is not valid JSON ({error}); fix it and re-run")
    if not isinstance(settings, dict):
        sys.exit(f"{settings_path} does not hold a JSON object; refusing to rewrite it")

status_line = settings.get("statusLine")
if not isinstance(status_line, dict):
    status_line = {}
status_line["type"] = "command"
status_line["command"] = command
status_line.setdefault("refreshInterval", 1)
settings["statusLine"] = status_line

with open(temporary_path, "w", encoding="utf-8") as handle:
    json.dump(settings, handle, indent=2)
    handle.write("\n")

with open(temporary_path, "r", encoding="utf-8") as handle:
    json.load(handle)

os.replace(temporary_path, settings_path)
print(f"  statusLine.command -> {command}")
PY

printf '\n'
printf 'done. Restart Claude Code, then run /sl to list the themes.\n'
