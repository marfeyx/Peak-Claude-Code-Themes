#!/usr/bin/env python3
"""Drive the Windows Terminal background image for the "water" status line theme.

Windows Terminal has no escape sequence for the background, so the only way to
make the water level follow context usage is to point the profile at a different
pre-rendered GIF and let WT hot-reload its settings. That is what this does, once
per 10% band rather than once per second.

    sl-water-bg.py apply <band>   point the active profile at the band's GIF
    sl-water-bg.py restore        put the profile back exactly as it was
    sl-water-bg.py status         report what is currently applied

The profile's original values are saved on first apply and replayed verbatim on
restore, including keys that were absent (they get removed again).
"""

import json
import os
import shutil
import subprocess
import sys
import time

CLAUDE_DIR = os.path.dirname(os.path.abspath(__file__))
GIF_DIR_WSL = "/mnt/c/Users/%s/AppData/Local/claude-statusline"
BACKUP_FILE = os.path.join(CLAUDE_DIR, "statusline-wt-backup.json")
APPLIED_FILE = os.path.join(CLAUDE_DIR, "statusline-wt-applied")

# colorScheme is managed too, because the meadow theme needs a LIGHT scheme
# behind its bright sky and water needs the dark one back afterwards. It is in
# this list purely so `restore()` puts the original back -- `apply()` (water)
# never touches it.
MANAGED_KEYS = ("backgroundImage", "backgroundImageOpacity",
                "backgroundImageStretchMode", "backgroundImageAlignment",
                "useAcrylic", "opacity", "colorScheme")

OPACITY = 0.30            # "subtle, text-first"
STRETCH = "fill"


def _real_settings():
    import glob
    hits = glob.glob("/mnt/c/Users/*/AppData/Local/Packages/"
                     "Microsoft.WindowsTerminal*/LocalState/settings.json")
    hits += glob.glob("/mnt/c/Users/*/AppData/Local/Microsoft/"
                      "Windows Terminal/settings.json")
    return sorted(hits, key=os.path.getmtime)[-1] if hits else None


def settings_path():
    override = os.environ.get("SL_WT_SETTINGS")
    if override:
        return override
    real = _real_settings()
    if not real:
        raise SystemExit("Windows Terminal settings.json not found")
    return real


def gif_dir():
    """Where the band GIFs live, on the Windows side so WT can read them.

    Derived from the real Windows Terminal install rather than from
    `settings_path()`, which a test may have pointed somewhere else entirely.
    """
    override = os.environ.get("SL_WATER_GIF_DIR")
    if override:
        return override
    real = _real_settings()
    if real:
        parts = real.split("/")
        if "Users" in parts:
            return GIF_DIR_WSL % parts[parts.index("Users") + 1]
    raise SystemExit("cannot locate the Windows user directory for the GIFs")


def to_windows(p):
    try:
        return subprocess.run(["wslpath", "-w", p], capture_output=True,
                              text=True, timeout=5).stdout.strip()
    except Exception:
        return p


def load(path):
    with open(path, encoding="utf-8-sig") as fh:
        return json.load(fh)


def save(path, data):
    """Atomic-ish write that keeps WT's formatting conventions (2 spaces, CRLF)."""
    text = json.dumps(data, indent=2, ensure_ascii=False)
    text = text.replace("\n", "\r\n") + "\r\n"
    tmp = path + ".cc-tmp"
    with open(tmp, "w", encoding="utf-8", newline="") as fh:
        fh.write(text)
    os.replace(tmp, path)


def target_profile(data):
    """The profile this session is running in, falling back to the default."""
    profiles = (data.get("profiles") or {}).get("list") or []
    guid = os.environ.get("WT_PROFILE_ID") or data.get("defaultProfile")
    for p in profiles:
        if p.get("guid") == guid:
            return p
    return profiles[0] if profiles else None


def snapshot(profile):
    return {k: profile[k] for k in MANAGED_KEYS if k in profile}


def restore_scheme(profile):
    """Put colorScheme back to whatever the profile had before we touched it.

    Only meadow sets a scheme (its light one, for the bright sky). Water must
    undo that, and it cannot simply leave the key alone: switching meadow ->
    water calls apply(), not restore(), so without this the dark water GIF ran
    underneath meadow's LIGHT scheme -- which is exactly the state this fixes.

    Reads the same backup restore() uses, so "before we touched it" means the
    user's original value, not whichever theme ran last. If the backup records
    no scheme, the profile had none and the override is removed entirely.
    """
    try:
        with open(BACKUP_FILE, encoding="utf-8") as fh:
            saved = (json.load(fh).get("values") or {})
    except (OSError, ValueError):
        return
    if "colorScheme" in saved:
        profile["colorScheme"] = saved["colorScheme"]
    else:
        profile.pop("colorScheme", None)


def apply(band):
    path = settings_path()
    data = load(path)
    profile = target_profile(data)
    if profile is None:
        raise SystemExit("no Windows Terminal profile to update")

    gif = os.path.join(gif_dir(), "water-%03d.gif" % band)
    if not os.path.exists(gif):
        raise SystemExit("missing %s - run the generator first" % gif)

    if not os.path.exists(BACKUP_FILE):
        shutil.copy2(path, path + ".before-claude-water.bak")
        with open(BACKUP_FILE, "w", encoding="utf-8") as fh:
            json.dump({"guid": profile.get("guid"), "values": snapshot(profile)},
                      fh, indent=2)

    profile["backgroundImage"] = to_windows(gif)
    profile["backgroundImageOpacity"] = OPACITY
    profile["backgroundImageStretchMode"] = STRETCH
    # Acrylic composites the desktop over the image and washes it out.
    profile["useAcrylic"] = False
    profile["opacity"] = 100
    restore_scheme(profile)

    save(path, data)
    with open(APPLIED_FILE, "w", encoding="utf-8") as fh:
        fh.write("%d\n" % band)
    return band, gif


# A light Windows Terminal scheme for the meadow sky. The background image
# covers the window, so `background` only shows before the image loads -- but
# `foreground` and the ANSI slots are what any text Claude Code does NOT colour
# explicitly falls back to, and those have to be dark to survive a bright sky.
MEADOW_SCHEME = {
    "name": "Meadow",
    "background": "#CFEAF2", "foreground": "#1C2E36",
    "cursorColor": "#6A2F0D", "selectionBackground": "#BFE6F2",
    "black": "#1C2E36", "red": "#A61A2E", "green": "#0E4A2C",
    "yellow": "#755407", "blue": "#16568C", "purple": "#6840A8",
    "cyan": "#0B4841", "white": "#2E434B",
    "brightBlack": "#3E5F6B", "brightRed": "#C22A40", "brightGreen": "#16673F",
    "brightYellow": "#8C6A0C", "brightBlue": "#1E6BAE", "brightPurple": "#7C51C0",
    "brightCyan": "#11635A", "brightWhite": "#0F1D24",
}


# The same profile, after dark. The meadow sky now runs a day cycle, and a
# light scheme under a midnight-blue sky is exactly as unreadable as the dark
# one was under a bright sky -- 0 of 36 tokens cleared 4.5:1 in that direction
# too. The two schemes swap at dusk and dawn (see `daylight.is_dark`), which is
# the only surface of the theme that cannot be blended: a light scheme halfway
# to a dark one is a grey scheme that fails against both.
MEADOW_NIGHT_SCHEME = {
    "name": "Meadow Night",
    "background": "#0A1020", "foreground": "#E6EEFB",
    "cursorColor": "#FFB472", "selectionBackground": "#25406E",
    "black": "#0A1020", "red": "#FF8A9C", "green": "#79E0A8",
    "yellow": "#F2D68A", "blue": "#7CC0F0", "purple": "#BBA6F0",
    "cyan": "#6FD6CE", "white": "#C9D8EE",
    "brightBlack": "#7C90AE", "brightRed": "#FFA8B6", "brightGreen": "#9BEEC2",
    "brightYellow": "#FAE7B4", "brightBlue": "#A8D8F8", "brightPurple": "#D2C2FA",
    "brightCyan": "#96E8E2", "brightWhite": "#F4F9FF",
}

SCHEMES = {"light": MEADOW_SCHEME, "night": MEADOW_NIGHT_SCHEME}


def ensure_scheme(data, scheme):
    """Add or update a colour scheme in place, matched by name."""
    schemes = data.setdefault("schemes", [])
    for i, s in enumerate(schemes):
        if s.get("name") == scheme["name"]:
            schemes[i] = scheme
            return
    schemes.append(scheme)


def apply_file(image, opacity=None, scheme=None):
    """Point the profile at an arbitrary background image.

    Water swaps between eleven pre-rendered band GIFs; meadow has a single sky
    that never changes, so it needs a by-path entry point rather than a band
    number. Everything else -- the one-time backup, the managed key set and
    `restore()` -- is shared deliberately: two scripts each writing their own
    backup of the same profile would overwrite each other's idea of "original"
    and neither could put it back.
    """
    path = settings_path()
    data = load(path)
    profile = target_profile(data)
    if profile is None:
        raise SystemExit("no Windows Terminal profile to update")
    if not os.path.exists(image):
        raise SystemExit("missing %s - run the generator first" % image)

    if not os.path.exists(BACKUP_FILE):
        shutil.copy2(path, path + ".before-claude-water.bak")
        with open(BACKUP_FILE, "w", encoding="utf-8") as fh:
            json.dump({"guid": profile.get("guid"), "values": snapshot(profile)},
                      fh, indent=2)

    profile["backgroundImage"] = to_windows(image)
    profile["backgroundImageOpacity"] = OPACITY if opacity is None else opacity
    profile["backgroundImageStretchMode"] = STRETCH
    profile["useAcrylic"] = False
    profile["opacity"] = 100
    if scheme:
        ensure_scheme(data, scheme)
        profile["colorScheme"] = scheme["name"]

    save(path, data)
    # Not a band, so the marker records the image. `applied_band()` parses this
    # as an int and returns None, which is exactly what water's sync_band wants
    # to see -- it re-applies its own band the moment water is selected again.
    with open(APPLIED_FILE, "w", encoding="utf-8") as fh:
        fh.write(os.path.basename(image) + "\n")
    return image


def restore():
    if not os.path.exists(BACKUP_FILE):
        return False
    path = settings_path()
    data = load(path)
    with open(BACKUP_FILE, encoding="utf-8") as fh:
        saved = json.load(fh)

    profiles = (data.get("profiles") or {}).get("list") or []
    profile = next((p for p in profiles if p.get("guid") == saved.get("guid")), None)
    if profile is not None:
        for key in MANAGED_KEYS:
            profile.pop(key, None)
        profile.update(saved.get("values") or {})
        save(path, data)

    os.remove(BACKUP_FILE)
    if os.path.exists(APPLIED_FILE):
        os.remove(APPLIED_FILE)
    return True


def applied_band():
    try:
        with open(APPLIED_FILE) as fh:
            return int(fh.read().strip())
    except (OSError, ValueError):
        return None


def main():
    args = sys.argv[1:]
    cmd = args[0] if args else "status"

    if cmd == "apply":
        band = int(args[1]) if len(args) > 1 else 0
        band = max(0, min(100, round(band / 10) * 10))
        applied, gif = apply(band)
        print("background -> band %d%% (%s)" % (applied, os.path.basename(gif)))
    elif cmd == "apply-file":
        if len(args) < 2:
            raise SystemExit("usage: apply-file <image> [opacity] [--light|--night]")
        flags = ("--light", "--night")
        opacity = None
        if len(args) > 2 and args[2] not in flags:
            opacity = float(args[2])
        scheme = (MEADOW_NIGHT_SCHEME if "--night" in args
                  else MEADOW_SCHEME if "--light" in args else None)
        img = apply_file(args[1], opacity, scheme)
        print("background -> %s%s" % (os.path.basename(img),
                                      " (light scheme)" if scheme else ""))
    elif cmd == "restore":
        print("Windows Terminal profile restored" if restore()
              else "nothing to restore")
    else:
        path = settings_path()
        print("settings : %s" % path)
        print("gif dir  : %s" % gif_dir())
        print("applied  : %s" % ("band %d%%" % applied_band()
                                 if applied_band() is not None else "none"))
        print("backup   : %s" % ("present" if os.path.exists(BACKUP_FILE) else "none"))


if __name__ == "__main__":
    main()
