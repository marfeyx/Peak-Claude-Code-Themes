#!/usr/bin/env python3
"""Point the Windows Terminal profile at the look that matches a statusline theme.

Called by switch.sh on every theme activation. The underwater theme gets a
translucent cyan window and the animated water shader; sakura gets a pale sky,
a cherry blossom wallpaper and the matching Claude Code palette; meadow gets an
opaque window filled with the generated sky its grass panel is supposed to stand
in, since the panel paints no background of its own; every other theme gets an
opaque black window and the plain border-eraser shader.

NO SHADER ON A LOOK THAT WANTS A BACKGROUND IMAGE. Windows Terminal composites a
background image behind the text surface, and a pixel shader hands back that
surface's own pixels: on an opaque window the shader's output covers the image
completely, which is why meadow drew grass over a flat terminal background and no
sky at all. sakura, the background image that has always worked, is also the only
other look that asks for no shader. Nothing is lost by dropping it here -- the
eraser only replaces pixels matching a sentinel magenta, and neither meadow
palette paints its prompt border that colour.

Meadow is the only look that moves after it has been applied. Its sky runs on a
half-hour day cycle, and the band mode below exists so the image and the two
colour schemes can follow it:

    terminal-background.py band meadow <segment> <light|dark>

Band mode is deliberately the narrowest write in this file. It re-points the
background image, swaps the light or dark scheme, and swaps the Claude Code
palette that is read against that sky, and touches nothing else: no acrylic, no
opacity, no shader, no tab row, and above all no snapshot of any kind, since a
band change is not a transition and must never be mistaken for the values the
user started with. It refuses outright unless meadow is the recorded owner of
the background and snapshots of everything it is about to move already exist,
which is what makes the no-snapshot rule safe rather than merely stated.

The Claude Code palette is in that list because it is the one thing the sky can
make unreadable. Half the cycle is a pale blue sky and half is nearly black, and
a single palette cannot clear 4.5:1 against both, so the palette has to follow
the sky or be wrong for half an hour at a time. It is two writes per cycle, not
six: darkness is read at the segment's midpoint, so the scheme only ever changes
on a boundary the image is changing anyway.

Nothing here is specific to one machine. The Windows Terminal settings file is
discovered rather than hardcoded, the colour schemes are created if the profile
does not already define them, the shaders and wallpapers are referenced by their
real installed path translated through wslpath, and the settings are written to
profiles.defaults so the look applies whichever profile the session runs in.

A look may optionally carry three further things beyond colours and a shader: a
background image, a Windows Terminal tab-row theme, and a Claude Code
application palette installed into ~/.claude/themes. Each one remembers the
value it displaced under ~/.claude/statusline-state and hands it back the moment
a look that does not declare it is selected. The memory is written from the
document as it was read off disk, never from the copy this script has already
modified, and it keeps the first value it ever saw, so a second activation
cannot overwrite the user's own settings with this script's. A key that was
absent before is removed again on restore rather than being set to a default.
Looks that declare none of the three never touch anything outside Windows
Terminal's settings.

Writes are defensive on purpose: this file governs every Windows Terminal profile
the user has, so a corrupted write is far worse than a wrong colour. The script
takes a timestamped backup, writes to a temporary file, re-reads and re-parses it,
and only then replaces the original. Any surprise aborts without touching it. The
Claude Code settings file is rewritten the same way. The backup stamp carries the
writing process as well as the second, because two writes inside one second used
to overwrite each other and leave only the newest -- which is to say, leave the
state before the change this backup existed to undo. The copies are pruned to the
newest BACKUP_KEEP afterwards, so neither directory grows without bound.

Order matters on a switch: the terminal settings are validated and replaced
first, and only then the Claude Code palette. The terminal write is the one with
reasons to refuse -- a JSONC document with // comments in it, an unexpected
shape -- and doing it second left a refusal with the palette already changed and
nothing to change it back.

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
ASSET_DIR = os.path.join(HERE, "assets")
CLAUDE_DIR = os.path.dirname(HERE)
CLAUDE_SETTINGS = os.path.join(CLAUDE_DIR, "settings.json")
CLAUDE_THEME_DIR = os.path.join(CLAUDE_DIR, "themes")
STATE_DIR = os.path.join(CLAUDE_DIR, "statusline-state")
APP_THEME_MEMORY = os.path.join(STATE_DIR, "previous-app-theme")
TAB_THEME_MEMORY = os.path.join(STATE_DIR, "previous-tab-theme")
BACKGROUND_MEMORY = os.path.join(STATE_DIR, "previous-background.json")
BACKGROUND_OWNER = os.path.join(STATE_DIR, "background-owner")
IMAGE_MARKER = os.path.join(STATE_DIR, "wallpaper-installed")
SKY_STATE = os.path.join(STATE_DIR, "meadow-applied.json")
SKY_BUILD_LOCK = os.path.join(STATE_DIR, "meadow-build.lock")
SKY_APPLY_LOCK = os.path.join(STATE_DIR, "meadow-apply.lock")
SKY_BUILD_LOCK_TTL = 900.0
BACKUP_KEEP = 12

IMAGE_KEYS = ("backgroundImage", "backgroundImageOpacity",
              "backgroundImageStretchMode", "backgroundImageAlignment")

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
    "Sakura": {
        "name": "Sakura", "background": "#DCEEF8", "foreground": "#101C28",
        "cursorColor": "#741D48", "selectionBackground": "#E2CEDC",
        "black": "#1C242E", "red": "#801020", "green": "#0C4A2E",
        "yellow": "#5B3903", "blue": "#134369", "purple": "#562D74",
        "cyan": "#07474E", "white": "#3A424C",
        "brightBlack": "#394149", "brightRed": "#7A1C2C", "brightGreen": "#13492C",
        "brightYellow": "#533B09", "brightBlue": "#1A4361", "brightPurple": "#513269",
        "brightCyan": "#0E464B", "brightWhite": "#101C28",
    },
    "Meadow": {
        "name": "Meadow", "background": "#CFEAF2", "foreground": "#1C2E36",
        "cursorColor": "#6A2F0D", "selectionBackground": "#BFE6F2",
        "black": "#1C2E36", "red": "#A61A2E", "green": "#0E4A2C",
        "yellow": "#755407", "blue": "#16568C", "purple": "#6840A8",
        "cyan": "#0B4841", "white": "#2E434B",
        "brightBlack": "#3E5F6B", "brightRed": "#C22A40", "brightGreen": "#16673F",
        "brightYellow": "#8C6A0C", "brightBlue": "#1E6BAE", "brightPurple": "#7C51C0",
        "brightCyan": "#11635A", "brightWhite": "#0F1D24",
    },
    "Christmas Night": {
        "name": "Christmas Night", "background": "#0A1424", "foreground": "#F2E8DA",
        "cursorColor": "#FFD166", "selectionBackground": "#2A3A5E",
        "black": "#07101C", "red": "#FF6B7A", "green": "#4EC98A",
        "yellow": "#FFD166", "blue": "#74B6F0", "purple": "#C2A8F5",
        "cyan": "#6FD8CE", "white": "#E6DCCE",
        "brightBlack": "#4A5B75", "brightRed": "#FF93A0", "brightGreen": "#86E8AE",
        "brightYellow": "#FFE5A0", "brightBlue": "#A3D2F7", "brightPurple": "#D9C7FA",
        "brightCyan": "#9BEDE4", "brightWhite": "#FFF8EE",
    },
    "Workshop Night": {
        "name": "Workshop Night", "background": "#0C0A08", "foreground": "#F0E4D2",
        "cursorColor": "#FF8A72", "selectionBackground": "#4A3420",
        "black": "#0A0806", "red": "#FF6B5E", "green": "#8CCB8A",
        "yellow": "#F0C05A", "blue": "#7FB4DC", "purple": "#C0A0E8",
        "cyan": "#6FCFC4", "white": "#E2D3BE",
        "brightBlack": "#6E5A44", "brightRed": "#FF9384", "brightGreen": "#ABE0A6",
        "brightYellow": "#FFD98A", "brightBlue": "#A6D0EE", "brightPurple": "#D7C2F5",
        "brightCyan": "#9BE6DC", "brightWhite": "#FFF6E8",
    },
    "Meadow Night": {
        "name": "Meadow Night", "background": "#0A1020", "foreground": "#E6EEFB",
        "cursorColor": "#FFB472", "selectionBackground": "#25406E",
        "black": "#0A1020", "red": "#FF8A9C", "green": "#79E0A8",
        "yellow": "#F2D68A", "blue": "#7CC0F0", "purple": "#BBA6F0",
        "cyan": "#6FD6CE", "white": "#C9D8EE",
        "brightBlack": "#7C90AE", "brightRed": "#FFA8B6", "brightGreen": "#9BEEC2",
        "brightYellow": "#FAE7B4", "brightBlue": "#A8D8F8", "brightPurple": "#D2C2FA",
        "brightCyan": "#96E8E2", "brightWhite": "#F4F9FF",
    },
}

TAB_THEMES = {
    "Sakura": {
        "name": "Sakura",
        "window": {"applicationTheme": "light", "useMica": False},
        "tabRow": {"background": "#CFE6F4FF", "unfocusedBackground": "#BEDCEEFF"},
        "tab": {"background": "#E6F2FBFF", "unfocusedBackground": "#CFE6F4FF",
                "showCloseButton": "always"},
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
    "sakura": {
        "colorScheme": "Sakura",
        "useAcrylic": False,
        "opacity": 100,
        "shader": None,
        "unfocused": {"useAcrylic": False, "opacity": 100},
        "image": "sakura/sakura-blossom.gif",
        "imageOpacity": 0.7,
        "imageStretchMode": "uniformToFill",
        "imageAlignment": "center",
        "tabTheme": "Sakura",
        "appTheme": "sakura",
    },
    "meadow": {
        "colorScheme": "Meadow Night",
        "schemeVariants": {"light": "Meadow", "dark": "Meadow Night"},
        "useAcrylic": False,
        "opacity": 100,
        "shader": None,
        "unfocused": {"useAcrylic": False, "opacity": 100},
        "appTheme": "meadow-night",
        "appThemeVariants": {"light": "meadow", "dark": "meadow-night"},
        "sky": True,
        "imageOpacity": 1.0,
        "imageStretchMode": "fill",
        "imageAlignment": "center",
    },
    "christmas": {
        "colorScheme": "Christmas Night",
        "useAcrylic": True,
        "opacity": 72,
        "shader": "christmas.hlsl",
        "unfocused": {"useAcrylic": True, "opacity": 58},
    },
    "kugelbahn": {
        "colorScheme": "Workshop Night",
        "useAcrylic": True,
        "opacity": 76,
        "shader": "kugelbahn.hlsl",
        "unfocused": {"useAcrylic": True, "opacity": 60},
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
    if not name:
        return None
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


def image_reference(name, settings):
    """Install a bundled wallpaper beside settings.json and return its path.

    Windows Terminal resolves a bare shader filename relative to settings.json
    but gives no such guarantee for backgroundImage, so the copy is addressed by
    its full Windows path instead. Returns None when the asset is not bundled or
    cannot be expressed as a Windows path, which tells the caller to drop the
    setting rather than point at nothing.
    """
    if not name:
        return None
    local = os.path.join(ASSET_DIR, name)
    if not os.path.exists(local):
        return None
    beside = os.path.join(os.path.dirname(settings), os.path.basename(name))
    try:
        if not os.path.exists(beside) or os.path.getmtime(local) > os.path.getmtime(beside):
            shutil.copy2(local, beside)
    except Exception:
        return None
    translated = windows_path(beside)
    if translated == beside or translated.startswith("\\\\"):
        return None
    return translated


SKY_MODULE = []


def load_sky():
    """Import the sky image generator, or None when it is not installed.

    The file is loaded by path because its name carries a dash, and the result
    is kept, since importing it twice in one run would read the vendored
    generator twice for no gain.
    """
    if SKY_MODULE:
        return SKY_MODULE[0]
    path = os.path.join(HERE, "meadow-sky.py")
    if not os.path.exists(path):
        return None
    try:
        import importlib.util
        spec = importlib.util.spec_from_file_location("meadow_sky", path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
    except Exception:
        return None
    SKY_MODULE.append(module)
    return module


def phase_band():
    """Return the sky segment and darkness the day cycle is currently asking for.

    Falls back to the first segment after dark, because that is what the meadow
    look used to be fixed at, and a window that is too dark is readable while a
    window that is too light is not.
    """
    sky = load_sky()
    if sky is None:
        return 0, True
    try:
        return sky.current_segment()
    except Exception:
        return 0, True


def resolve_look(name, is_dark):
    """Return a look with its day or night variant of scheme and palette chosen.

    Only meadow declares variants. Every other look comes back exactly as it is
    written in the table, so this is transparent to them.
    """
    look = OrderedDict(LOOKS[name])
    variant = "dark" if is_dark else "light"
    schemes = look.pop("schemeVariants", None)
    if schemes:
        look["colorScheme"] = schemes[variant]
    palettes = look.pop("appThemeVariants", None)
    if palettes:
        look["appTheme"] = palettes[variant]
    return look


def is_inside(path, directory):
    """Report whether a path lies within a directory."""
    try:
        root = os.path.abspath(directory) + os.sep
        return os.path.abspath(path).startswith(root)
    except Exception:
        return False


def external_reference(local, settings):
    """Return the Windows path of a generated, rather than bundled, image.

    A generated sky is already written into Windows Terminal's own package data,
    beside settings.json, so it is addressed where it lies. An image from
    anywhere else is copied in there first rather than being pointed at where it
    stands: a drive-letter path under %LOCALAPPDATA% looks reachable and is not,
    because the MSIX runtime gives a packaged app a private redirected copy of
    that one folder. A path that still comes back as a UNC share is refused
    rather than written: those are slow to read and not reliably accepted.
    """
    if not local or not os.path.exists(local):
        return None
    package = os.path.dirname(os.path.abspath(settings))
    if is_inside(local, package):
        translated = windows_path(local)
        if translated != local and not translated.startswith("\\\\"):
            return translated
        return None
    beside = os.path.join(package, os.path.basename(local))
    try:
        if not os.path.exists(beside) or os.path.getmtime(local) > os.path.getmtime(beside):
            shutil.copy2(local, beside)
    except Exception:
        return None
    translated = windows_path(beside)
    if translated == beside or translated.startswith("\\\\"):
        return None
    return translated


def sky_reference(settings, segment, is_allowed_to_build=True):
    """Return the Windows path of the sky image for one segment of the cycle.

    Prefers the segment the clock asked for, falls back to the static midday sky
    and, on a first activation where neither exists yet, renders that fallback.
    Reports None rather than naming a file Windows Terminal cannot open.
    """
    sky = load_sky()
    if sky is None:
        return None
    try:
        images = sky.cache_dir(settings)
        if is_allowed_to_build:
            local = sky.ensure_image(images, segment)
        else:
            local = sky.segment_image(images, segment)
    except Exception:
        return None
    return external_reference(local, settings)


def spawn_sky_build(settings):
    """Render the full segment set in a process this one does not wait for.

    The static fallback is already applied by the time this runs, so the only
    thing at stake is how soon the sky starts moving. A crude mtime lock keeps
    several sessions activating meadow at once from each rendering the same
    thirteen megabytes.
    """
    sky = load_sky()
    if sky is None:
        return False
    try:
        images = sky.cache_dir(settings)
        if not images or not sky.is_stale(images):
            return False
    except Exception:
        return False

    try:
        age = time.time() - os.path.getmtime(SKY_BUILD_LOCK)
        if age < SKY_BUILD_LOCK_TTL:
            return False
    except OSError:
        pass

    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        with open(SKY_BUILD_LOCK, "w", encoding="utf-8") as handle:
            handle.write(str(os.getpid()))
        with open(os.devnull, "wb") as quiet:
            subprocess.Popen([sys.executable, os.path.join(HERE, "meadow-sky.py"), "build"],
                             stdin=quiet, stdout=quiet, stderr=quiet,
                             start_new_session=True, close_fds=True)
    except Exception:
        return False
    return True


def read_background_memory():
    """Return the background keys a look displaced, or None when none are stored."""
    try:
        with open(BACKGROUND_MEMORY, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return None


def write_background_memory(value):
    """Record the background keys a look is about to displace, keeping the first.

    Nothing is written once a snapshot exists, which is what stops a second
    activation from recording this script's own values as the user's.
    """
    if value is None or os.path.exists(BACKGROUND_MEMORY):
        return
    os.makedirs(STATE_DIR, exist_ok=True)
    with open(BACKGROUND_MEMORY, "w", encoding="utf-8") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def text_background(text):
    """Read the background keys out of the settings document as it was on disk."""
    try:
        data = json.loads(text)
    except Exception:
        return None
    profiles = data.get("profiles")
    if not isinstance(profiles, dict):
        return None
    defaults = profiles.get("defaults")
    defaults = defaults if isinstance(defaults, dict) else {}
    entries = OrderedDict()
    for entry in profiles.get("list") or []:
        if not isinstance(entry, dict):
            continue
        present = OrderedDict((key, entry[key]) for key in IMAGE_KEYS if key in entry)
        if present:
            entries[str(entry.get("guid"))] = present
    return OrderedDict((
        ("defaults", OrderedDict((key, defaults[key])
                                 for key in IMAGE_KEYS if key in defaults)),
        ("list", entries),
    ))


def restore_background(profiles, remembered):
    """Strip the background keys a look installed and replay what they displaced.

    A key the snapshot does not mention was absent before, so it is removed
    rather than set to a default: that is the whole reason the snapshot records
    which keys were present instead of their values alone.
    """
    changes = []
    wanted = (remembered or {}).get("defaults") or {}
    defaults = profiles["defaults"]
    for key in IMAGE_KEYS:
        if key in wanted:
            if defaults.get(key) != wanted[key]:
                changes.append(f"defaults.{key}: {defaults.get(key)!r} -> {wanted[key]!r}")
                defaults[key] = wanted[key]
        elif defaults.pop(key, None) is not None:
            changes.append(f"defaults.{key} removed")

    entries = (remembered or {}).get("list") or {}
    for entry in profiles["list"]:
        if not isinstance(entry, dict):
            continue
        wanted_entry = entries.get(str(entry.get("guid"))) or {}
        for key in IMAGE_KEYS:
            if key in wanted_entry:
                if entry.get(key) != wanted_entry[key]:
                    changes.append(f"{entry.get('name')}.{key} -> {wanted_entry[key]!r}")
                    entry[key] = wanted_entry[key]
            elif entry.pop(key, None) is not None:
                changes.append(f"{entry.get('name')}.{key} removed")
    return changes


def write_sky_state(segment, is_dark):
    """Record which band is on screen, so a render can tell when it has moved on."""
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        temporary = f"{SKY_STATE}.{os.getpid()}"
        with open(temporary, "w", encoding="utf-8") as handle:
            json.dump({"segment": int(segment), "dark": bool(is_dark),
                       "at": int(time.time())}, handle)
        os.replace(temporary, SKY_STATE)
    except OSError:
        pass


def write_owner(name):
    """Record which theme the terminal background currently belongs to."""
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        temporary = f"{BACKGROUND_OWNER}.{os.getpid()}"
        with open(temporary, "w", encoding="utf-8") as handle:
            handle.write(name)
        os.replace(temporary, BACKGROUND_OWNER)
    except OSError:
        pass


def read_memory(path):
    """Return the value a look displaced here, or None when nothing is stored."""
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read().strip()
    except OSError:
        return None


def write_memory(path, value):
    """Record the value a look is about to displace, keeping the first one seen."""
    if os.path.exists(path):
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("" if value is None else str(value))


def clear_memory(path):
    """Forget a displaced value once it has been handed back."""
    try:
        os.unlink(path)
    except OSError:
        pass


def _discard(path):
    try:
        os.unlink(path)
    except OSError:
        pass


def prune_backups(path, keep=BACKUP_KEEP):
    """Delete all but the newest few backups of a settings file."""
    try:
        existing = sorted(glob.glob(f"{path}.bak-*"), key=os.path.getmtime)
    except OSError:
        return []
    removed = []
    for stale in existing[:max(0, len(existing) - max(1, keep))]:
        try:
            os.unlink(stale)
            removed.append(stale)
        except OSError:
            pass
    return removed


def save_json(path, data, indent, is_backup_wanted=True):
    """Replace a settings file only once its rewritten copy has re-parsed.

    Takes a timestamped backup first, writes to a temporary file beside the
    original, re-reads it, and only then swaps it in. Anything unexpected leaves
    the original exactly where it was, and leaves nothing behind either: a
    serialisation that raises mid-write takes its own temporary file with it.

    The stamp carries the writing process as well as the second. Several Claude
    Code sessions share one profile and cross a band boundary together, and two
    copies named for the same second meant the second write overwrote the
    backup of the first -- destroying exactly the state worth keeping. The
    copies are pruned to the newest BACKUP_KEEP once the swap has succeeded.
    """
    if is_backup_wanted:
        stamp = time.strftime("%Y%m%d-%H%M%S")
        shutil.copy2(path, f"{path}.bak-{stamp}-{os.getpid()}")

    temporary = f"{path}.tmp.{os.getpid()}"
    try:
        with open(temporary, "w", encoding="utf-8") as handle:
            json.dump(data, handle, indent=indent, ensure_ascii=False)
            handle.write("\n")
    except Exception:
        _discard(temporary)
        raise

    try:
        with open(temporary, encoding="utf-8") as handle:
            json.load(handle)
    except Exception:
        _discard(temporary)
        raise SystemExit(f"rewritten {os.path.basename(path)} did not parse; "
                         "original left untouched")

    os.replace(temporary, path)
    if is_backup_wanted:
        prune_backups(path)


def install_app_theme(name):
    """Copy a bundled Claude Code palette into ~/.claude/themes and report it."""
    local = os.path.join(ASSET_DIR, name, f"{name}.json")
    if not os.path.exists(local):
        return None
    installed = os.path.join(CLAUDE_THEME_DIR, f"{name}.json")
    try:
        if not os.path.exists(installed) or os.path.getmtime(local) > os.path.getmtime(installed):
            os.makedirs(CLAUDE_THEME_DIR, exist_ok=True)
            shutil.copy2(local, installed)
    except Exception:
        return None
    return installed


def apply_app_theme(look, is_snapshot_allowed=True):
    """Set, or hand back, the Claude Code palette this look owns.

    A look that names a palette installs it and remembers whatever was selected
    before. A look that names none restores the remembered selection and forgets
    it, so a theme that never touches the palette cannot leave one behind.

    A band change passes is_snapshot_allowed False. It is not a transition, and
    the palette it is moving from is this script's own: recording that as the
    value the user started with is how leaving meadow used to restore meadow.
    """
    wanted = look.get("appTheme")
    changes = []

    if not os.path.exists(CLAUDE_SETTINGS):
        return changes

    if wanted:
        if install_app_theme(wanted) is None:
            return [f"Claude Code palette {wanted!r} is not bundled; left alone"]
        target = f"custom:{wanted}"
    else:
        remembered = read_memory(APP_THEME_MEMORY)
        if remembered is None:
            return changes
        target = remembered

    with open(CLAUDE_SETTINGS, encoding="utf-8-sig") as handle:
        text = handle.read()
    data = json.loads(text, object_pairs_hook=OrderedDict)
    current = data.get("theme")

    if wanted and is_snapshot_allowed:
        write_memory(APP_THEME_MEMORY, current)

    if current == target or (not target and "theme" not in data):
        if not wanted:
            clear_memory(APP_THEME_MEMORY)
        return changes

    if target:
        data["theme"] = target
    else:
        data.pop("theme", None)
    changes.append(f"claude settings theme: {current!r} -> {target or None!r}")

    save_json(CLAUDE_SETTINGS, data, 2)
    if not wanted:
        clear_memory(APP_THEME_MEMORY)
    return changes


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


def ensure_tab_theme(data, name):
    """Add the named tab-row theme to the settings if it is not defined yet."""
    themes = data.setdefault("themes", [])
    if any(isinstance(entry, dict) and entry.get("name") == name for entry in themes):
        return False
    themes.append(json.loads(json.dumps(TAB_THEMES[name]), object_pairs_hook=OrderedDict))
    return True


def settle_background(name, look, band, image, installed_image):
    """Hand back or take over ownership of the background once a look is applied.

    A look with no image gives the background up and forgets everything it was
    remembering about it, so returning to a look that has one starts from the
    user's own values again rather than from this script's.
    """
    if image is None:
        if installed_image:
            clear_memory(IMAGE_MARKER)
            clear_memory(BACKGROUND_MEMORY)
            clear_memory(BACKGROUND_OWNER)
            clear_memory(SKY_STATE)
            clear_memory(SKY_APPLY_LOCK)
        return
    write_memory(IMAGE_MARKER, "1")
    write_owner(name)
    if look.get("sky"):
        write_sky_state(band[0], band[1])


def apply_look(settings, name, band):
    """Rewrite the terminal profile for the named look and report what changed."""
    look = resolve_look(name, band[1])

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
        reason = "look wants none" if not look["shader"] else "shader not installed"
        if defaults.pop(shader_key, None) is not None:
            changes.append(f"defaults.{shader_key} removed ({reason})")
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

    if look.get("sky"):
        image = sky_reference(settings, band[0])
    else:
        image = image_reference(look.get("image"), settings)
    remembered_background = read_background_memory()
    installed_image = os.path.exists(IMAGE_MARKER) or remembered_background is not None
    if image is None:
        if installed_image:
            changes.extend(restore_background(profiles, remembered_background))
    else:
        write_background_memory(text_background(text))
        wallpaper = OrderedDict((
            ("backgroundImage", image),
            ("backgroundImageOpacity", look["imageOpacity"]),
            ("backgroundImageStretchMode", look["imageStretchMode"]),
            ("backgroundImageAlignment", look["imageAlignment"]),
        ))
        for key, wanted in wallpaper.items():
            if defaults.get(key) != wanted:
                changes.append(f"defaults.{key}: {defaults.get(key)!r} -> {wanted!r}")
                defaults[key] = wanted
            for entry in profiles["list"]:
                if key in entry and entry[key] != wanted:
                    changes.append(f"{entry.get('name')}.{key} -> {wanted!r}")
                    entry[key] = wanted

    tab_theme = look.get("tabTheme")
    remembered_tab = read_memory(TAB_THEME_MEMORY)
    if tab_theme:
        if ensure_tab_theme(data, tab_theme):
            changes.append(f"added tab theme {tab_theme!r}")
        if data.get("theme") != tab_theme:
            changes.append(f"theme: {data.get('theme')!r} -> {tab_theme!r}")
            data["theme"] = tab_theme
    elif remembered_tab is not None:
        if remembered_tab:
            if data.get("theme") != remembered_tab:
                changes.append(f"theme: {data.get('theme')!r} -> {remembered_tab!r}")
                data["theme"] = remembered_tab
        elif data.pop("theme", None) is not None:
            changes.append("theme removed")

    if not changes:
        if not tab_theme and remembered_tab is not None:
            clear_memory(TAB_THEME_MEMORY)
        settle_background(name, look, band, image, installed_image)
        return []

    if tab_theme:
        write_memory(TAB_THEME_MEMORY, text_tab_theme(text))

    save_json(settings, data, 4)

    if not tab_theme and remembered_tab is not None:
        clear_memory(TAB_THEME_MEMORY)
    settle_background(name, look, band, image, installed_image)
    return changes


def text_tab_theme(text):
    """Read the tab-row theme out of the settings document as it was on disk."""
    try:
        return json.loads(text).get("theme")
    except Exception:
        return None


def apply_band(settings, name, segment, is_dark):
    """Move one look's background image and scheme to a new band of its day cycle.

    This is the only write in this file that happens away from a theme switch, so
    it is the narrowest. It refuses unless the look already owns the background
    and a snapshot of everything it is about to move exists, it takes no snapshot
    of its own, and it leaves acrylic, opacity, the shader and the tab row
    exactly as the switch left them.
    """
    look = resolve_look(name, is_dark)
    if not look.get("sky"):
        raise SystemExit(f"{name} has no day cycle; nothing to move")
    if read_memory(BACKGROUND_OWNER) != name:
        raise SystemExit(f"{name} does not own the terminal background; band ignored")
    if read_background_memory() is None:
        raise SystemExit("no background snapshot; refusing to move the band")
    if look.get("appTheme") and read_memory(APP_THEME_MEMORY) is None:
        raise SystemExit("no Claude Code palette snapshot; refusing to move the band")

    image = sky_reference(settings, segment)
    if image is None:
        raise SystemExit("no sky image for this band; nothing applied")

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
    for key, wanted in (("backgroundImage", image), ("colorScheme", look["colorScheme"])):
        if defaults.get(key) != wanted:
            changes.append(f"defaults.{key}: {defaults.get(key)!r} -> {wanted!r}")
            defaults[key] = wanted
        for entry in profiles["list"]:
            if key in entry and entry[key] != wanted:
                changes.append(f"{entry.get('name')}.{key} -> {wanted!r}")
                entry[key] = wanted

    if changes:
        save_json(settings, data, 4)
    changes.extend(apply_app_theme(look, is_snapshot_allowed=False))
    write_sky_state(segment, is_dark)
    clear_memory(SKY_APPLY_LOCK)
    return changes


def main():
    """Apply the look matching the theme named on the command line."""
    arguments = sys.argv[1:]

    if arguments and arguments[0] == "band":
        if len(arguments) < 4:
            raise SystemExit("usage: terminal-background.py band <theme> <segment> "
                             "<light|dark>")
        name = arguments[1]
        if name not in LOOKS:
            raise SystemExit(f"no look named {name!r}")
        try:
            segment = int(arguments[2])
        except ValueError:
            raise SystemExit("segment must be a whole number")
        is_dark = arguments[3] == "dark"

        settings = find_settings()
        if not settings:
            raise SystemExit("no Windows Terminal settings found; band unchanged")

        for change in apply_band(settings, name, segment, is_dark):
            print(change)
        return

    theme = arguments[0] if arguments else ""
    name = theme if theme in LOOKS else "plain"
    band = phase_band()
    look = resolve_look(name, band[1])

    settings = find_settings()
    if not settings:
        raise SystemExit("no Windows Terminal settings found; terminal look unchanged")

    for change in apply_look(settings, name, band):
        print(change)

    for change in apply_app_theme(look):
        print(change)

    if look.get("sky") and spawn_sky_build(settings):
        print("rendering the full sky in the background")


if __name__ == "__main__":
    main()
