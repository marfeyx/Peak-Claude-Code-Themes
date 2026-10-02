#!/usr/bin/env python3
"""Generate and locate the meadow theme's full-window sky images.

The meadow panel paints grass, flowers and a cat across the bottom rows and is
transparent everywhere else, so the sky it is supposed to sit under is not drawn
by the status line at all: it is a Windows Terminal background image. This file
owns those images. Pointing the profile at one is terminal-background.py's job.

The sky is a half-hour loop cut into segments, one animated GIF each, because
Windows Terminal hands a background GIF to XAML and offers no way to read or
seek its playback position. Changing the image path is the only thing that
reliably restarts it, so each segment boundary re-anchors the sky to the same
wall clock the panel reads. The generator is vendored under vendor/meadow and is
pure standard library: the pixels are palette indices that never change and the
whole day cycle lives in a per-frame colour table, which is why thirty minutes
of sky fits in a few megabytes.

Nothing here is specific to one machine. The images have to live on the Windows
side for Windows Terminal to read them, and the directory is derived from the
discovered settings file rather than hardcoded; SL_MEADOW_SKY_DIR overrides it.

WHERE THEY LIVE, AND WHY IT IS NOT %LOCALAPPDATA%. The images go in a folder
beside settings.json, inside Windows Terminal's own package data, which is the
location Microsoft documents for custom images and the one the working sakura
wallpaper already uses. They used to be written to %LOCALAPPDATA% directly, and
that is the one folder in a Windows profile the MSIX runtime virtualises for a
packaged app: the terminal resolved the path into its own private redirection
layer, found nothing there, and drew no background at all.

    meadow-sky.py dir                 print the image directory
    meadow-sky.py build [--force]     render the segment set, then the fallback
    meadow-sky.py image               print the image for the current phase
    meadow-sky.py status              report phase, segment and build state

Only build renders anything. image and status are queries and stay queries even
when the directory is empty, so a diagnostic run cannot leave half a sky behind
in a directory that was only being looked at.

Building is slow by design, roughly a minute for the full set, and is never
done from inside a rendered frame. A manifest beside the images is deleted first
and written last, so a half-finished set reads as stale and is rebuilt rather
than applied.
"""

import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
VENDOR_DIR = os.path.join(HERE, "vendor", "meadow")
CACHE_LEAF = "claude-statusline-sky"
LEGACY_LEAF = os.path.join("AppData", "Local", "claude-statusline-sky")
MANIFEST_NAME = "meadow-sky.json"
STATIC_NAME = "meadow-sky.gif"

SETTINGS_GLOB = (
    "/mnt/c/Users/*/AppData/Local/Packages"
    "/Microsoft.WindowsTerminal*/LocalState/settings.json"
)


def _modules():
    if VENDOR_DIR not in sys.path:
        sys.path.insert(0, VENDOR_DIR)
    import daylight
    import meadowsky
    return daylight, meadowsky


def _skyband():
    if VENDOR_DIR not in sys.path:
        sys.path.insert(0, VENDOR_DIR)
    import skyband
    return skyband


def _user_root(settings):
    parts = os.path.abspath(settings).split(os.sep)
    try:
        index = parts.index("Users")
    except ValueError:
        return None
    if index + 1 >= len(parts):
        return None
    return os.sep.join(parts[:index + 2])


def cache_dir(settings=None):
    """Return the directory the sky images live in, or None if it is unknown.

    Windows Terminal reads the image, not WSL, so the directory has to be on
    the Windows side, and it has to be one the terminal can actually reach: a
    packaged app sees its own virtualised copy of %LOCALAPPDATA%, so the images
    sit beside settings.json instead, inside the package data the terminal owns.
    The location is derived from the discovered settings file, which keeps the
    username out of this file; SL_MEADOW_SKY_DIR replaces the whole derivation.
    """
    override = (os.environ.get("SL_MEADOW_SKY_DIR") or "").strip()
    if override:
        return override
    if not settings:
        return None
    return os.path.join(os.path.dirname(os.path.abspath(settings)), CACHE_LEAF)


def legacy_dir(settings=None):
    """Return the %LOCALAPPDATA% directory earlier builds wrote images to."""
    if (os.environ.get("SL_MEADOW_SKY_DIR") or "").strip() or not settings:
        return None
    root = _user_root(settings)
    if not root:
        return None
    return os.path.join(root, LEGACY_LEAF)


def discard_legacy(settings=None):
    """Delete the unreachable image set an earlier build left behind."""
    stale = legacy_dir(settings)
    if not stale or not os.path.isdir(stale):
        return False
    import shutil
    try:
        shutil.rmtree(stale)
    except OSError:
        return False
    return True


def segment_name(index):
    """Return the file name of one segment of the sky loop."""
    return "meadow-sky-%02d.gif" % int(index)


def wanted_manifest():
    """Describe the image set the settings currently in force would produce."""
    daylight, meadowsky = _modules()
    return {
        "segments": daylight.segments(),
        "period": daylight.period(),
        "width": meadowsky.WIDTH,
        "height": meadowsky.HEIGHT,
        "delay_cs": meadowsky.DELAY_CS,
        "revision": meadowsky.REVISION,
    }


def current_manifest(images):
    """Read the manifest describing the image set already on disk."""
    try:
        with open(os.path.join(images, MANIFEST_NAME), encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return {}


def is_stale(images):
    """Report whether the images on disk fail to match the wanted set."""
    wanted = wanted_manifest()
    if current_manifest(images) != wanted:
        return True
    return any(not os.path.exists(os.path.join(images, segment_name(index)))
               for index in range(int(wanted["segments"])))


def build_static(images):
    """Render the single fixed-palette midday sky and return its path.

    This is the fallback the first activation can afford to wait for. A window
    with a midday sky is a far better failure than a window with none.
    """
    daylight, meadowsky = _modules()
    os.makedirs(images, exist_ok=True)
    path = os.path.join(images, STATIC_NAME)
    meadowsky.build(path)
    return path


def build_segments(images, is_forced=False, is_verbose=True):
    """Render the segment set, skipping the work when it is already current."""
    if not is_forced and not is_stale(images):
        if is_verbose:
            print("sky is already built for this period and segment count")
        return []

    daylight, meadowsky = _modules()
    os.makedirs(images, exist_ok=True)
    wanted = wanted_manifest()
    manifest = os.path.join(images, MANIFEST_NAME)
    try:
        os.remove(manifest)
    except OSError:
        pass

    written = []
    count = int(wanted["segments"])
    for index in range(count):
        path = os.path.join(images, segment_name(index))
        size = meadowsky.build_segment(path, index, count)
        written.append((path, size))
        if is_verbose:
            print("  %s  %d KB" % (segment_name(index), size // 1024))

    with open(manifest, "w", encoding="utf-8") as handle:
        json.dump(wanted, handle, indent=2)
    return written


def current_segment():
    """Return the segment index and darkness the clock is asking for.

    The answer comes from skyband rather than from daylight directly, so the
    image and the colour scheme change on the same boundary and a pinned clock
    pins the sky as well as the grass panel.
    """
    return _skyband().band()


def segment_image(images, segment):
    """Return the best existing image for a segment, or None when there is none.

    Prefers the segment itself, falls back to the static midday sky, and
    reports nothing rather than naming a file Windows Terminal cannot open.
    """
    if not images:
        return None
    candidate = os.path.join(images, segment_name(segment))
    if os.path.exists(candidate):
        return candidate
    candidate = os.path.join(images, STATIC_NAME)
    if os.path.exists(candidate):
        return candidate
    return None


def ensure_image(images, segment):
    """Return an image for a segment, rendering the static fallback if needed."""
    existing = segment_image(images, segment)
    if existing:
        return existing
    if not images:
        return None
    try:
        return build_static(images)
    except Exception:
        return None


def _discover_settings():
    override = os.environ.get("SL_WT_SETTINGS")
    if override:
        return override if os.path.exists(override) else None
    import glob
    candidates = glob.glob(SETTINGS_GLOB)
    if not candidates:
        return None
    return max(candidates, key=os.path.getmtime)


def main():
    """Run the command named on the command line against the image set."""
    arguments = sys.argv[1:]
    command = arguments[0] if arguments else "status"
    settings = _discover_settings()
    images = cache_dir(settings)

    if not images:
        raise SystemExit("cannot locate a Windows directory for the sky images")

    if command == "dir":
        print(images)
        return

    if command == "build":
        started = time.time()
        written = build_segments(images, is_forced="--force" in arguments)
        if written:
            total = sum(size for _, size in written)
            print("%d segments, %.1f MB, %.0f s"
                  % (len(written), total / 1048576.0, time.time() - started))
        if not os.path.exists(os.path.join(images, STATIC_NAME)):
            build_static(images)
            print("static fallback %s" % STATIC_NAME)
        if discard_legacy(settings):
            print("removed the unreachable %%LOCALAPPDATA%% image set")
        return

    if command == "image":
        segment, _ = current_segment()
        path = segment_image(images, segment)
        if not path:
            raise SystemExit("no sky image available; run: meadow-sky.py build")
        print(path)
        return

    daylight, _ = _modules()
    skyband = _skyband()
    phase = skyband.phase()
    segment, is_dark = current_segment()
    print("phase    : %.4f  (%s)" % (phase, daylight.look_name(phase)))
    print("period   : %.0f s in %d segments"
          % (daylight.period(), daylight.segments()))
    print("wanted   : segment %d, %s" % (segment, "dark" if is_dark else "light"))
    print("images   : %s" % images)
    print("built    : %s" % ("stale" if is_stale(images) else "current"))
    print("image    : %s" % (segment_image(images, segment) or "none"))


if __name__ == "__main__":
    main()
