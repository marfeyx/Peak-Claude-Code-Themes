#!/usr/bin/env python3
"""Switch Claude Code's own UI theme, and put the previous one back.

This is a THIRD colour surface, independent of the status line palette and of
the Windows Terminal scheme. It matters for meadow because Claude Code draws
its own foreground colours: a bright sky behind the window does nothing about
the fact that `text`, `subtle`, `error` and the rest are authored light-on-dark
in the `abyss` theme. Measured, 0 of 36 of those tokens clear 4.5:1 over the
sky at 40% opacity -- so the sky and the light theme have to move together.

    sl-cc-theme.py set custom:meadow    remember the current theme, then switch
    sl-cc-theme.py restore              put the remembered one back
    sl-cc-theme.py status               report

The previous value is saved on first `set` and only cleared by `restore`, so
repeated `set` calls cannot lose the original.
"""
import json
import os
import sys

CLAUDE_DIR = os.path.dirname(os.path.abspath(__file__))
SETTINGS = os.path.join(CLAUDE_DIR, "settings.json")
BACKUP = os.path.join(CLAUDE_DIR, "statusline-cc-theme-backup.json")


def load():
    with open(SETTINGS, encoding="utf-8-sig") as fh:
        return json.load(fh)


def save(data):
    """Write via a temp file and os.replace.

    Claude Code watches this file and reloads it. A partial write is a corrupt
    settings.json for whatever window of time the write takes, and the failure
    mode is the whole CLI falling back to defaults -- so the rename has to be
    atomic rather than merely quick.
    """
    tmp = SETTINGS + ".cc-tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    os.replace(tmp, SETTINGS)


def set_theme(name):
    data = load()
    if not os.path.exists(BACKUP):
        with open(BACKUP, "w", encoding="utf-8") as fh:
            json.dump({"theme": data.get("theme")}, fh, indent=2)
    if data.get("theme") == name:
        # The meadow day cycle calls this on every segment boundary but only
        # changes the answer twice a loop, at dusk and at dawn. Claude Code
        # reloads this file when it changes, so rewriting it with identical
        # content would make the other ten crossings visible for nothing.
        return name
    data["theme"] = name
    save(data)
    return name


def restore():
    if not os.path.exists(BACKUP):
        return None
    with open(BACKUP, encoding="utf-8") as fh:
        saved = json.load(fh)
    data = load()
    previous = saved.get("theme")
    if previous is None:
        data.pop("theme", None)
    else:
        data["theme"] = previous
    save(data)
    os.remove(BACKUP)
    return previous or "(unset)"


def main():
    args = sys.argv[1:]
    cmd = args[0] if args else "status"
    if cmd == "set" and len(args) > 1:
        print("Claude Code theme -> %s" % set_theme(args[1]))
    elif cmd == "restore":
        was = restore()
        print("Claude Code theme -> %s" % was if was else "nothing to restore")
    else:
        data = load()
        print("theme    : %s" % data.get("theme", "(unset)"))
        print("backup   : %s" % ("present" if os.path.exists(BACKUP) else "none"))


if __name__ == "__main__":
    main()
