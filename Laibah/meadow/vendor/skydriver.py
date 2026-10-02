"""Notice when the meadow sky has crossed into a new band of its day cycle.

This is the only part of the status line that is allowed to cause a
configuration write, and the licence is narrow. The sky is a Windows Terminal
background image on a half-hour cycle, and a status line frame is the only thing
in this system that runs once a second, so a frame is the only place the crossing
can be noticed. Noticing is all that happens here: nothing in this file opens a
settings file, let alone writes one.

The hot path is one open and one compare of two small integers against the band
already on screen. Equal, which is all but six frames per cycle, and this returns
immediately having touched nothing -- the comparison comes first precisely so the
common frame never pays for the checks below it. On a mismatch it takes a lock
and hands the work to terminal-background.py in a detached process, so the slow
part -- a settings rewrite on a Windows mount -- happens somewhere the frame is
not waiting for it, and a crash out there cannot corrupt a file this process had
half-written.

The lock exists because several Claude Code sessions share one terminal profile
and all of them cross the same boundary within the same second.

It refuses to hand anything over unless every one of these holds:

  - SL_MEADOW_DRIVE_SKY is not "0"
  - there is a Windows Terminal above this process to drive
  - meadow is the selected theme
  - meadow is the recorded owner of the terminal background, which means a
    switch has already run, taken the backup and snapshotted what it displaced

The last two are what keep a stray render from reaching into a profile that some
other theme currently owns.

WT_SESSION WAS THE WRONG QUESTION. Claude Code usually runs inside tmux, and
tmux passes WT_SESSION neither into its panes nor into its server, so reading
the variable answered False on every single frame: the sky never moved off
whatever the last theme switch applied, and a half-hour cycle that is stuck in
its darkest band looks exactly like a window with no background at all. The
variable was only ever standing in for "is there a Windows Terminal here to
drive", and there is a direct answer to that -- a settings file to write, under
a WSL kernel, with meadow recorded as the owner of the background it already
holds. The owner file is the stronger claim of the two: it is only written once
a switch has actually applied this look to that terminal. The environment
variable and the process tree above it are still believed when present, and all
of it sits behind the band comparison, so a frame that is not crossing a
boundary never asks any of it.
"""

import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
STATUSLINE_HOME = os.path.dirname(os.path.dirname(HERE))
CLAUDE_DIR = os.path.dirname(STATUSLINE_HOME)
STATE_DIR = os.path.join(CLAUDE_DIR, "statusline-state")
SELECTED_FILE = os.path.join(STATUSLINE_HOME, "selected")
OWNER_FILE = os.path.join(STATE_DIR, "background-owner")
STATE_FILE = os.path.join(STATE_DIR, "meadow-applied.json")
LOCK_FILE = os.path.join(STATE_DIR, "meadow-apply.lock")
HELPER = os.path.join(STATUSLINE_HOME, "terminal-background.py")

THEME_NAME = "meadow"
LOCK_TTL = 180.0
ANCESTOR_LIMIT = 12

SETTINGS_GLOB = (
    "/mnt/c/Users/*/AppData/Local/Packages"
    "/Microsoft.WindowsTerminal*/LocalState/settings.json"
)


def _read(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read().strip()
    except OSError:
        return ""


def _parent_of(pid):
    try:
        with open(f"/proc/{pid}/stat", encoding="utf-8") as handle:
            fields = handle.read().rsplit(")", 1)[1].split()
        return int(fields[1])
    except (OSError, IndexError, ValueError):
        return 0


def _has_variable(pid, name):
    try:
        with open(f"/proc/{pid}/environ", "rb") as handle:
            raw = handle.read()
    except OSError:
        return False
    needle = (name + "=").encode()
    return any(entry.startswith(needle) for entry in raw.split(b"\0"))


def _is_wsl():
    try:
        with open("/proc/version", encoding="utf-8", errors="replace") as handle:
            return "microsoft" in handle.read().lower()
    except OSError:
        return False


def has_settings():
    """Report whether a Windows Terminal settings file can be found to write."""
    override = os.environ.get("SL_WT_SETTINGS")
    if override:
        return os.path.exists(override)
    if not _is_wsl():
        return False
    import glob
    return bool(glob.glob(SETTINGS_GLOB))


def is_windows_terminal():
    """Report whether there is a Windows Terminal here for this sky to drive.

    WT_SESSION answers yes when it is there, and so does any process above this
    one, but tmux hands it on to neither so it is absent far more often than a
    Windows Terminal is. The fallback asks the question the variable was
    standing in for: a WSL kernel with a settings file to write. Nothing here
    names a user, a profile or a path, so it stays true on any machine.
    """
    if os.environ.get("WT_SESSION"):
        return True
    pid = os.getppid()
    for _ in range(ANCESTOR_LIMIT):
        if pid <= 1:
            break
        if _has_variable(pid, "WT_SESSION"):
            return True
        pid = _parent_of(pid)
    return has_settings()


def is_enabled():
    """Report whether this render is allowed to move the sky at all."""
    if os.environ.get("SL_MEADOW_DRIVE_SKY") == "0":
        return False
    if _read(SELECTED_FILE) != THEME_NAME:
        return False
    if _read(OWNER_FILE) != THEME_NAME:
        return False
    if not os.path.exists(HELPER):
        return False
    return is_windows_terminal()


def applied_band():
    """Return the band currently on screen, or None when nothing is recorded."""
    try:
        with open(STATE_FILE, encoding="utf-8") as handle:
            state = json.load(handle)
        return int(state["segment"]), bool(state["dark"])
    except (OSError, ValueError, KeyError, TypeError):
        return None


def _is_locked():
    try:
        return time.time() - os.path.getmtime(LOCK_FILE) < LOCK_TTL
    except OSError:
        return False


def _take_lock():
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        temporary = f"{LOCK_FILE}.{os.getpid()}"
        with open(temporary, "w", encoding="utf-8") as handle:
            handle.write(str(os.getpid()))
        os.replace(temporary, LOCK_FILE)
    except OSError:
        return False
    return True


def tick(when=None):
    """Hand the sky to a detached process when the clock has changed band.

    Returns True only when a process was actually started, so the caller can
    stay silent in the overwhelmingly common case where nothing happened.
    """
    if HERE not in sys.path:
        sys.path.insert(0, HERE)
    import skyband

    wanted = skyband.band(when)
    if applied_band() == wanted:
        return False
    if not is_enabled():
        return False
    if _is_locked() or not _take_lock():
        return False

    command = [sys.executable, HELPER, "band", THEME_NAME,
               str(wanted[0]), "dark" if wanted[1] else "light"]
    try:
        with open(os.devnull, "wb") as quiet:
            subprocess.Popen(command, stdin=quiet, stdout=quiet, stderr=quiet,
                             start_new_session=True, close_fds=True)
    except Exception:
        return False
    return True
