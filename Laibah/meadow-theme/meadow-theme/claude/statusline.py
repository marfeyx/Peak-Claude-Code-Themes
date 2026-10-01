#!/usr/bin/env python3
"""Custom Claude Code status line — theme dispatcher.

Reads the status line JSON on stdin (see https://code.claude.com/docs/en/statusline)
and hands it to the theme named in ~/.claude/statusline-theme. Themes live in
~/.claude/statuslines/<name>.py and expose `render(data) -> list[str]`.

Switch themes with /sl, or by writing a name into the state file directly.
Pure stdlib, no jq/node required.
"""

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
THEMES_DIR = os.path.join(HERE, "statuslines")
STATE_FILE = os.path.join(HERE, "statusline-theme")
DEFAULT_THEME = "meadow"

sys.path.insert(0, THEMES_DIR)


def is_theme(name):
    """A theme declares a DESCRIPTION; everything else in there is a helper."""
    try:
        with open(os.path.join(THEMES_DIR, name + ".py")) as fh:
            return "\nDESCRIPTION = " in fh.read(4096)
    except OSError:
        return False


def available():
    try:
        names = sorted(f[:-3] for f in os.listdir(THEMES_DIR)
                       if f.endswith(".py") and f != "__init__.py")
    except OSError:
        return []
    return [name for name in names if is_theme(name)]


def active():
    name = os.environ.get("SL_THEME", "").strip()
    if not name:
        try:
            with open(STATE_FILE) as fh:
                name = fh.read().strip()
        except OSError:
            name = ""
    if name not in available():
        name = DEFAULT_THEME
    return name


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        data = {}

    name = active()
    try:
        theme = __import__(name)
        rows = theme.render(data)
    except Exception as exc:  # never blank the status line on a theme bug
        if os.environ.get("SL_DEBUG"):
            raise
        rows = [f"\033[38;5;167mstatus line theme '{name}' failed: "
                f"{type(exc).__name__}: {exc}\033[0m"]

    print("\n".join(str(r) for r in rows))


if __name__ == "__main__":
    main()
