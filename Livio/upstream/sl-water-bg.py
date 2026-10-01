#!/usr/bin/env python3
"""Drive the Windows Terminal background image for the "water" status line theme.

Windows Terminal has no escape sequence for the background, so the only way to
make the water level follow context usage is to point the profile at a different
pre-rendered GIF and let WT hot-reload its settings. That is what this does, once
per 10% band rather than once per second.

    sl-water-bg.py apply <band>              point the profile at the band's GIF
    sl-water-bg.py apply <band> --set vice   ... from a different GIF set
    sl-water-bg.py restore                   put the profile back as it was
    sl-water-bg.py status                    report what is currently applied

A "set" is just a filename prefix: water-050.gif, vice-19.gif. Both themes
share this one driver so there is exactly one backup file and one restore
path — a second driver would mean a theme switch could leave a background
applied with nobody left holding the backup.

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

MANAGED_KEYS = ("backgroundImage", "backgroundImageOpacity",
                "backgroundImageStretchMode", "backgroundImageAlignment",
                "useAcrylic", "opacity", "background")

OPACITY = 0.30            # "subtle, text-first"
STRETCH = "fill"

# Per-set overrides. Vice is a lit panorama rather than a flat wash, so it can
# carry a little more opacity, and it wants a near-black profile colour under
# it instead of water's navy.
SETS = {
    "water": {"pattern": "water-%03d.gif", "opacity": 0.30, "background": "#061428"},
    "vice": {"pattern": "vice-%03d.gif", "opacity": 0.70, "background": "#0B0A1E"},
    # Kyoto is a bright daytime scene, so it wants *less* opacity than the
    # night-capable one: enough to read as a soft backdrop, not so much that
    # light terminal text loses the wall behind it.
    "kyoto": {"pattern": "kyoto-%03d.gif", "opacity": 0.78, "background": "#0A0E16"},
}

# The GIF is only 30% opaque and its air is fully transparent, so the profile's
# own background is what both the water and the sky are really tinted with. The
# Ubuntu scheme's #300A24 turns the whole tank purple, hence: deep ocean navy,
# a shade under the GIF's own DEEP_RGB so the water still reads as lighter.
BACKGROUND = "#061428"


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


def apply(band, sub=False, which="water"):
    spec = SETS.get(which, SETS["water"])
    path = settings_path()
    data = load(path)
    profile = target_profile(data)
    if profile is None:
        raise SystemExit("no Windows Terminal profile to update")

    gif = os.path.join(gif_dir(), spec["pattern"] % band)
    if sub and which == "water":
        # Fall back to the plain sea rather than failing: a set of GIFs rendered
        # before the submarine existed has no sub variants.
        passing = os.path.join(gif_dir(), "water-%03d-sub.gif" % band)
        sub = os.path.exists(passing)
        if sub:
            gif = passing
    if not os.path.exists(gif):
        raise SystemExit("missing %s - run the generator first" % gif)

    if not os.path.exists(BACKUP_FILE):
        shutil.copy2(path, path + ".before-claude-water.bak")
        with open(BACKUP_FILE, "w", encoding="utf-8") as fh:
            json.dump({"guid": profile.get("guid"), "values": snapshot(profile)},
                      fh, indent=2)

    profile["backgroundImage"] = to_windows(gif)
    profile["backgroundImageOpacity"] = spec["opacity"]
    profile["backgroundImageStretchMode"] = STRETCH
    profile["background"] = spec["background"]
    # Acrylic composites the desktop over the image and washes it out.
    profile["useAcrylic"] = False
    profile["opacity"] = 100

    save(path, data)
    # The variant goes in the state file too: the status line has to know that a
    # submarine is currently on screen, and when it asked for one and did not
    # get it, so that it does not respawn this script once a second.
    with open(APPLIED_FILE, "w", encoding="utf-8") as fh:
        fh.write("%d %s%s\n" % (band, which, " sub" if sub else ""))
    return band, gif


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


def applied_state():
    """(band, sub) currently pointed at, or (None, False)."""
    try:
        with open(APPLIED_FILE) as fh:
            parts = fh.read().split()
        return int(parts[0]), "sub" in parts[1:]
    except (OSError, ValueError, IndexError):
        return None, False


def applied_set():
    """Which GIF set is on screen, or None."""
    try:
        with open(APPLIED_FILE) as fh:
            parts = fh.read().split()
        for name in SETS:
            if name in parts[1:]:
                return name
        return "water" if parts else None
    except (OSError, IndexError):
        return None


def applied_band():
    return applied_state()[0]


def main():
    args = sys.argv[1:]
    cmd = args[0] if args else "status"

    if cmd == "apply":
        which = args[args.index("--set") + 1] if "--set" in args else "water"
        band = int(args[1]) if len(args) > 1 else 0
        if which == "water":
            band = max(0, min(100, round(band / 10) * 10))
        elif which == "kyoto":
            band = 0                      # the light never changes: one band
        else:
            band = max(0, min(143, band))
        applied, gif = apply(band, sub="sub" in args[2:], which=which)
        print("background -> %s %s" % (which, os.path.basename(gif)))
    elif cmd == "sub":
        # Send one past now, rather than waiting for the lottery to call one.
        band = int(args[1]) if len(args) > 1 else (applied_band() or 0)
        applied, gif = apply(max(0, min(100, round(band / 10) * 10)), sub=True)
        print("background -> band %d%% (%s)" % (applied, os.path.basename(gif)))
    elif cmd == "restore":
        print("Windows Terminal profile restored" if restore()
              else "nothing to restore")
    else:
        band, sub = applied_state()
        path = settings_path()
        print("settings : %s" % path)
        print("gif dir  : %s" % gif_dir())
        print("set      : %s" % (applied_set() or "none"))
        print("applied  : %s" % ("band %d%%%s" % (band, " + submarine" if sub else "")
                                 if band is not None else "none"))
        print("backup   : %s" % ("present" if os.path.exists(BACKUP_FILE) else "none"))


if __name__ == "__main__":
    main()
