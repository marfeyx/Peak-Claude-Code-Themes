#!/usr/bin/env python3
"""Point the Windows Terminal profile at the look that matches a statusline theme.

Called by switch.sh on every theme activation. The underwater theme gets a
translucent cyan window and the animated water shader; every other theme gets an
opaque black window and the plain border-eraser shader.

Nothing here is specific to one machine. The Windows Terminal settings file is
discovered rather than hardcoded, the colour schemes are created if the profile
does not already define them, the shaders are referenced by their real installed
path translated through wslpath, and the settings are written to
profiles.defaults so the look applies whichever profile the session runs in.

Writes are defensive on purpose: this file governs every Windows Terminal profile
the user has, so a corrupted write is far worse than a wrong colour. The script
takes a timestamped backup, writes to a temporary file, re-reads and re-parses it,
and only then replaces the original. Any surprise aborts without touching it.

Outside WSL, or with no Windows Terminal installed, it reports that and exits
without changing anything.
"""

import glob
import json
import os
import shutil
import subprocess
import sys
import time
from collections import OrderedDict

HERE = os.path.dirname(os.path.abspath(__file__))
SHADER_DIR = os.path.join(HERE, "shaders")

SETTINGS_GLOB = (
    "/mnt/c/Users/*/AppData/Local/Packages"
    "/Microsoft.WindowsTerminal*/LocalState/settings.json"
)

SCHEMES = {
    "Deep Water": {
        "name": "Deep Water", "background": "#072F3A", "foreground": "#D7F4FF",
        "cursorColor": "#7FE9FF", "selectionBackground": "#1B5E73",
        "black": "#04212A", "red": "#FF6B81", "green": "#4EE59B",
        "yellow": "#FFD166", "blue": "#56B6F2", "purple": "#B39DFF",
        "cyan": "#5FE3E3", "white": "#D7F4FF",
        "brightBlack": "#2C6B7E", "brightRed": "#FF8FA0", "brightGreen": "#7CF2B8",
        "brightYellow": "#FFE39B", "brightBlue": "#8ACFF7", "brightPurple": "#CDBCFF",
        "brightCyan": "#9BF2F2", "brightWhite": "#F2FCFF",
    },
    "Liquid Glass": {
        "name": "Liquid Glass", "background": "#000000", "foreground": "#E6E6E6",
        "cursorColor": "#FFFFFF", "selectionBackground": "#264F78",
        "black": "#000000", "red": "#FF6B80", "green": "#4EBA65",
        "yellow": "#FFC107", "blue": "#6A9BCC", "purple": "#AF87FF",
        "cyan": "#0891B2", "white": "#E6E6E6",
        "brightBlack": "#505050", "brightRed": "#FF8F9F", "brightGreen": "#7CD68F",
        "brightYellow": "#FFDF39", "brightBlue": "#8EB9E0", "brightPurple": "#CBB4FF",
        "brightCyan": "#22D3EE", "brightWhite": "#FFFFFF",
    },
}

LOOKS = {
    "underwater": {
        "colorScheme": "Deep Water",
        "useAcrylic": True,
        "opacity": 60,
        "shader": "underwater.hlsl",
        "unfocused": {"useAcrylic": True, "opacity": 45},
    },
    "plain": {
        "colorScheme": "Liquid Glass",
        "useAcrylic": False,
        "opacity": 100,
        "shader": "erase-prompt-border.hlsl",
        "unfocused": {"useAcrylic": False, "opacity": 100},
    },
}


def find_settings():
    """Locate the Windows Terminal settings file, or None if there is not one."""
    override = os.environ.get("SL_WT_SETTINGS")
    if override:
        return override if os.path.exists(override) else None

    candidates = sorted(glob.glob(SETTINGS_GLOB))
    if not candidates:
        return None
    if len(candidates) == 1:
        return candidates[0]

    user = (os.environ.get("WT_USERNAME") or "").strip()
    if not user:
        try:
            user = subprocess.run(["cmd.exe", "/c", "echo %USERNAME%"], timeout=10,
                                  capture_output=True, text=True).stdout.strip()
        except Exception:
            user = ""
    if user:
        for candidate in candidates:
            if f"/Users/{user}/" in candidate:
                return candidate
    return max(candidates, key=lambda path: os.path.getmtime(path))


def windows_path(path):
    """Translate a WSL path into the Windows form Windows Terminal needs."""
    try:
        result = subprocess.run(["wslpath", "-w", path], timeout=10,
                                capture_output=True, text=True)
        translated = result.stdout.strip()
        if translated:
            return translated
    except Exception:
        pass
    return path


def shader_reference(name, settings):
    """Install a bundled shader beside settings.json and return its reference.

    Windows Terminal resolves a bare filename relative to settings.json, which
    avoids pointing it at a \\wsl.localhost UNC path: those are slow to read and
    not reliably accepted. Returns None when the shader is not bundled, which
    tells the caller to drop the setting instead of pointing at nothing.
    """
    local = os.path.join(SHADER_DIR, name)
    if not os.path.exists(local):
        return None
    beside = os.path.join(os.path.dirname(settings), name)
    try:
        if not os.path.exists(beside) or os.path.getmtime(local) > os.path.getmtime(beside):
            shutil.copy2(local, beside)
    except Exception:
        return None
    return name


def has_real_comment(text):
    """Report whether the document contains a // comment outside of a string."""
    in_string = False
    escaped = False
    previous = ""
    for character in text:
        if in_string:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == '"':
                in_string = False
        elif character == '"':
            in_string = True
        elif character == "/" and previous == "/":
            return True
        previous = character
    return False


def ensure_scheme(data, name):
    """Add the named colour scheme to the settings if it is not defined yet."""
    schemes = data.setdefault("schemes", [])
    if any(entry.get("name") == name for entry in schemes):
        return False
    schemes.append(OrderedDict(SCHEMES[name]))
    return True


def apply_look(settings, name):
    """Rewrite the terminal profile for the named look and report what changed."""
    look = LOOKS[name]

    with open(settings, encoding="utf-8-sig") as handle:
        text = handle.read()

    if has_real_comment(text):
        raise SystemExit("settings.json contains // comments; refusing to rewrite it")

    data = json.loads(text, object_pairs_hook=OrderedDict)
    profiles = data.get("profiles")
    if not isinstance(profiles, dict) or "defaults" not in profiles or "list" not in profiles:
        raise SystemExit("settings.json has an unexpected shape; refusing to rewrite it")

    changes = []
    if ensure_scheme(data, look["colorScheme"]):
        changes.append(f"added colour scheme {look['colorScheme']!r}")

    defaults = profiles["defaults"]
    for key in ("colorScheme", "useAcrylic", "opacity"):
        wanted = look[key]
        if type(defaults.get(key)) is not type(wanted) or defaults.get(key) != wanted:
            changes.append(f"defaults.{key}: {defaults.get(key)!r} -> {wanted!r}")
            defaults[key] = wanted

    unfocused = defaults.setdefault("unfocusedAppearance", OrderedDict())
    for key, wanted in look["unfocused"].items():
        if type(unfocused.get(key)) is not type(wanted) or unfocused.get(key) != wanted:
            changes.append(f"unfocusedAppearance.{key}: {unfocused.get(key)!r} -> {wanted!r}")
            unfocused[key] = wanted

    shader_key = "experimental.pixelShaderPath"
    reference = shader_reference(look["shader"], settings)
    if reference is None:
        if defaults.pop(shader_key, None) is not None:
            changes.append(f"defaults.{shader_key} removed (shader not installed)")
        for entry in profiles["list"]:
            if entry.pop(shader_key, None) is not None:
                changes.append(f"{entry.get('name')}.{shader_key} removed")
    else:
        if defaults.get(shader_key) != reference:
            changes.append(f"defaults.{shader_key} -> {look['shader']}")
            defaults[shader_key] = reference
        for entry in profiles["list"]:
            if shader_key in entry and entry[shader_key] != reference:
                changes.append(f"{entry.get('name')}.{shader_key} -> {look['shader']}")
                entry[shader_key] = reference

    if not changes:
        return []

    stamp = time.strftime("%Y%m%d-%H%M%S")
    shutil.copy2(settings, f"{settings}.bak-{stamp}")

    temporary = f"{settings}.tmp.{os.getpid()}"
    with open(temporary, "w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=4, ensure_ascii=False)
        handle.write("\n")

    try:
        with open(temporary, encoding="utf-8") as handle:
            json.load(handle)
    except Exception:
        os.unlink(temporary)
        raise SystemExit("rewritten settings.json did not parse; original left untouched")

    os.replace(temporary, settings)
    return changes


def main():
    """Apply the look matching the theme named on the command line."""
    theme = sys.argv[1] if len(sys.argv) > 1 else ""
    name = "underwater" if theme == "underwater" else "plain"

    settings = find_settings()
    if not settings:
        raise SystemExit("no Windows Terminal settings found; terminal look unchanged")

    for change in apply_look(settings, name):
        print(change)


if __name__ == "__main__":
    main()
