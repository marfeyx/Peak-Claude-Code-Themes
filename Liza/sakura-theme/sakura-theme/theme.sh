#!/usr/bin/env python3
"""Apply the sakura terminal theme: wallpaper, colours, tab bar and the Claude
Code palette, all in one move.

    ./theme.sh sakura       apply it
    ./theme.sh status       what is active right now
    ./theme.sh --localstate print the Windows Terminal folder that was detected

A theme is five separate settings across two config files, which is why this
exists -- setting any one of them on its own leaves the terminal half-dressed:

  ~/.claude/settings.json   theme                       (Claude Code palette)
  Windows Terminal          profiles.defaults.colorScheme
                            profiles.defaults.backgroundImage + opacity
                            theme                       (tab row and title bar)

Both config files are backed up to ~/.claude/backups/ before anything is
written. The Windows Terminal scheme and tab theme are created on first use and
updated in place afterwards, so this is safe to re-run.

Needs WSL with Windows Terminal. The Windows side is found automatically; set
WT_LOCALSTATE to point at the folder holding Windows Terminal's settings.json
if the search comes up empty.
"""

import datetime
import glob
import json
import os
import re
import shutil
import subprocess
import sys

CC_SETTINGS = os.path.expanduser("~/.claude/settings.json")
BACKUPS = os.path.expanduser("~/.claude/backups")

# Store package names. Stable and Preview install side by side under different
# ids; the unpackaged build keeps its settings somewhere else entirely.
WT_PACKAGES = ("Microsoft.WindowsTerminal_8wekyb3d8bbwe",
               "Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe")

THEME = {
    "cc": "custom:sakura",
    "scheme": "Sakura",
    "wt_theme": "sakura",
    # If you regenerate the art, save it under a NEW filename and change this to
    # match. Windows Terminal caches the decoded wallpaper per path, so
    # overwriting a GIF in place leaves it drawing the old frames.
    "image": "sakura-blossom.gif",
    # the blossom scene is detailed; blending it back toward the pale sky keeps
    # dark text readable where it crosses the trunk and the grass. Raise toward
    # 1.0 for more picture, drop toward 0.4 for more contrast.
    "opacity": 0.70,
    "blurb": "sakura - cherry blossom, light",
}
ALIASES = {"blossom": "sakura", "cherry": "sakura", "day": "sakura"}

# Background stays the pale sky. Everything that draws *text* is pitched dark
# enough to hold up over the wallpaper at 0.7 opacity -- including the "bright"
# ANSI slots, which on a light scheme are foreground colours too, not highlights.
SAKURA_SCHEME = {
    "name": "Sakura",
    "background": "#DCEEF8",
    "foreground": "#101C28",
    "cursorColor": "#741D48",
    "selectionBackground": "#E2CEDC",
    "black": "#1C242E",
    "red": "#801020",
    "green": "#0C4A2E",
    "yellow": "#5B3903",
    "blue": "#134369",
    "purple": "#562D74",
    "cyan": "#07474E",
    "white": "#3A424C",
    # On a light scheme the "bright" slots are not highlights, they are ordinary
    # foreground colours -- so they are darker than their base here, not lighter.
    # Left at their usual brightness they were the least readable thing on screen.
    "brightBlack": "#394149",
    "brightRed": "#7A1C2C",
    "brightGreen": "#13492C",
    "brightYellow": "#533B09",
    "brightBlue": "#1A4361",
    "brightPurple": "#513269",
    "brightCyan": "#0E464B",
    "brightWhite": "#101C28",
}

SAKURA_WT_THEME = {
    "name": "sakura",
    "window": {"applicationTheme": "light", "useMica": False},
    "tabRow": {"background": "#CFE6F4FF", "unfocusedBackground": "#BEDCEEFF"},
    "tab": {"background": "#E6F2FBFF", "unfocusedBackground": "#CFE6F4FF",
            "showCloseButton": "always"},
}


# ---- locating the Windows side -----------------------------------------------


def win_username():
    """Ask Windows for its own username. cwd is forced onto the C: drive because
    cmd.exe refuses to start in a UNC path and prints a warning that would end up
    in stdout."""
    try:
        out = subprocess.run(["cmd.exe", "/c", "echo %USERNAME%"],
                             capture_output=True, text=True, timeout=10,
                             cwd="/mnt/c")
    except (OSError, subprocess.SubprocessError):
        return None
    name = out.stdout.strip()
    # an unexpanded %USERNAME% means cmd.exe ran but the variable was not set
    return name if name and "%" not in name else None


def candidate_dirs():
    """Every plausible LocalState folder, best guess first."""
    homes = []
    user = win_username()
    if user:
        homes.append("/mnt/c/Users/%s" % user)
    homes.extend(sorted(glob.glob("/mnt/?/Users/*")))

    for home in homes:
        for pkg in WT_PACKAGES:
            yield os.path.join(home, "AppData/Local/Packages", pkg, "LocalState")
        # unpackaged / Scoop / Chocolatey builds
        yield os.path.join(home, "AppData/Local/Microsoft/Windows Terminal")


def find_localstate():
    forced = os.environ.get("WT_LOCALSTATE")
    if forced:
        return forced if os.path.isfile(os.path.join(forced, "settings.json")) else None
    seen = set()
    for d in candidate_dirs():
        if d in seen:
            continue
        seen.add(d)
        if os.path.isfile(os.path.join(d, "settings.json")):
            return d
    return None


def to_windows_path(wsl_path):
    """/mnt/c/Users/x/y -> C:\\Users\\x\\y. Windows Terminal is a Windows process,
    so backgroundImage has to be written in its own path dialect."""
    m = re.match(r"^/mnt/([a-zA-Z])/(.*)$", wsl_path.rstrip("/"))
    if not m:
        return None
    return "%s:\\%s" % (m.group(1).upper(), m.group(2).replace("/", "\\"))


# ---- config plumbing ---------------------------------------------------------


def load(path):
    with open(path, encoding="utf-8-sig") as fh:
        return json.load(fh)


def save(path, data, indent):
    """Write via a temp file in the same directory so a crash mid-write cannot
    leave Windows Terminal with a truncated settings.json."""
    tmp = path + ".tmp-theme"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=indent, ensure_ascii=False)
        fh.write("\n")
    try:
        os.replace(tmp, path)
    except OSError:
        shutil.copyfile(tmp, path)      # DrvFs can refuse rename; copy instead
        os.unlink(tmp)


def backup(path, tag):
    os.makedirs(BACKUPS, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y%m%dT%H%M%S")
    dest = os.path.join(BACKUPS, "%s.%s.bak" % (tag, stamp))
    shutil.copyfile(path, dest)
    return dest


def upsert(items, entry):
    """Replace the entry with a matching name, or append it. Keeps this script
    idempotent and keeps any hand-edits to your *other* themes intact."""
    for i, it in enumerate(items):
        if isinstance(it, dict) and it.get("name") == entry["name"]:
            items[i] = entry
            return
    items.append(entry)


def current():
    try:
        name = (load(CC_SETTINGS).get("theme") or "").split(":")[-1]
    except (OSError, ValueError):
        return None
    return name


def apply():
    touched = []

    os.makedirs(os.path.dirname(CC_SETTINGS), exist_ok=True)
    try:
        cc = load(CC_SETTINGS)
    except OSError:
        cc = {}                          # first run, no Claude Code config yet
    if cc.get("theme") != THEME["cc"]:
        if os.path.exists(CC_SETTINGS):
            touched.append(backup(CC_SETTINGS, "claude-settings"))
        cc["theme"] = THEME["cc"]
        save(CC_SETTINGS, cc, 2)

    localstate = find_localstate()
    if not localstate:
        print("! Could not find Windows Terminal's settings.json.")
        print("  Claude Code theme set to sakura; terminal left alone.")
        print("  Set WT_LOCALSTATE to the folder that holds it and re-run.")
        return touched, False

    wt_settings = os.path.join(localstate, "settings.json")
    wt = load(wt_settings)
    touched.append(backup(wt_settings, "windows-terminal-settings"))

    upsert(wt.setdefault("schemes", []), SAKURA_SCHEME)
    upsert(wt.setdefault("themes", []), SAKURA_WT_THEME)

    win_dir = to_windows_path(localstate)
    if win_dir is None:
        print("! %s is not under /mnt/<drive>, so the wallpaper path cannot be"
              % localstate)
        print("  expressed for Windows. Colours applied; wallpaper skipped.")
    else:
        defaults = wt.setdefault("profiles", {}).setdefault("defaults", {})
        defaults["backgroundImage"] = win_dir + "\\" + THEME["image"]
        defaults["backgroundImageOpacity"] = THEME["opacity"]
        defaults["backgroundImageStretchMode"] = "uniformToFill"
        defaults["backgroundImageAlignment"] = "center"
        defaults["colorScheme"] = THEME["scheme"]
        defaults["useAcrylic"] = False
        if not os.path.exists(os.path.join(localstate, THEME["image"])):
            print("! %s is not in %s yet -- copy it there or the background"
                  % (THEME["image"], localstate))
            print("  will come up blank. install.sh does this for you.")

    wt["theme"] = THEME["wt_theme"]
    save(wt_settings, wt, 4)
    return touched, True


def main():
    arg = (sys.argv[1] if len(sys.argv) > 1 else "status").lower()
    arg = ALIASES.get(arg, arg)

    if arg == "--localstate":
        found = find_localstate()
        print(found or "")
        sys.exit(0 if found else 1)

    if arg in ("-h", "--help"):
        print(__doc__)
        return

    if arg == "status":
        now = current()
        star = "*" if now == "sakura" else " "
        print(" %s sakura       %s" % (star, THEME["blurb"]))
        if now and now != "sakura":
            print("\n   (Claude Code is currently on %r)" % now)
        found = find_localstate()
        print("\nwindows terminal: %s" % (found or "not found"))
        print("apply with: %s sakura" % sys.argv[0])
        return

    if arg != "sakura":
        print("unknown theme %r; try: sakura, status" % arg)
        sys.exit(1)

    touched, wt_ok = apply()
    for b in touched:
        print("backed up -> %s" % b)
    print("\nswitched to %s" % THEME["blurb"])
    if wt_ok:
        print("  Windows Terminal reloads on save - the wallpaper should already")
        print("  have changed. If Claude Code is still showing the old palette,")
        print("  run /config and reselect the theme, or restart it.")
    else:
        print("  If Claude Code is still showing the old palette, run /config")
        print("  and reselect the theme, or restart it.")


if __name__ == "__main__":
    main()
