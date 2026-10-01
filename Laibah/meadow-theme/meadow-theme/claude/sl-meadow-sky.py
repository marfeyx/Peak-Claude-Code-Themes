#!/usr/bin/env python3
"""Move the meadow theme's sky, terminal scheme and UI theme to a phase.

    sl-meadow-sky.py build [--force]     render the segment GIFs
    sl-meadow-sky.py apply <seg> <light|dark>
    sl-meadow-sky.py now                 apply whatever the clock says
    sl-meadow-sky.py status

This is the slow half of the day cycle. `statuslines/skydriver.py` decides WHEN
from inside a status line frame; everything that touches a file on the Windows
side happens out here, in a process the status line has already stopped waiting
for. Two settings files get rewritten -- Windows Terminal's, for the background
image and the colour scheme, and Claude Code's, for its own UI theme -- and both
applications pick the change up by watching their file.

Writes are idempotent and are skipped when nothing would change, because several
Claude Code sessions share one Windows Terminal profile and all of them cross a
segment boundary at the same second.
"""

import json
import os
import subprocess
import sys
import time

CLAUDE_DIR = os.path.dirname(os.path.abspath(__file__))
THEMES_DIR = os.path.join(CLAUDE_DIR, "statuslines")
STATE_FILE = os.path.join(CLAUDE_DIR, "statusline-meadow-applied")
LOCK_FILE = os.path.join(CLAUDE_DIR, "statusline-meadow-apply.lock")
MANIFEST = "meadow-sky.json"
LEGACY = "meadow-sky.gif"

sys.path.insert(0, THEMES_DIR)


def _load(name, path):
    import importlib.util
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


wtbg = _load("sl_water_bg", os.path.join(CLAUDE_DIR, "sl-water-bg.py"))
cctheme = _load("sl_cc_theme", os.path.join(CLAUDE_DIR, "sl-cc-theme.py"))

import daylight            # noqa: E402  (needs THEMES_DIR on the path first)
import meadowsky           # noqa: E402

CC_THEME = {False: "custom:meadow", True: "custom:meadow-night"}


def segment_name(i):
    return "meadow-sky-%02d.gif" % i


def manifest_path(gifs):
    return os.path.join(gifs, MANIFEST)


def current_manifest(gifs):
    try:
        with open(manifest_path(gifs)) as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}


def wanted_manifest():
    return {
        "segments": daylight.segments(),
        "period": daylight.period(),
        "width": meadowsky.WIDTH,
        "height": meadowsky.HEIGHT,
        "delay_cs": meadowsky.DELAY_CS,
        "revision": meadowsky.REVISION,
    }


def stale(gifs):
    """True when the GIFs on disk do not match the settings in force."""
    want = wanted_manifest()
    if current_manifest(gifs) != want:
        return True
    return any(not os.path.exists(os.path.join(gifs, segment_name(i)))
               for i in range(want["segments"]))


def build(gifs, force=False, verbose=True):
    if not force and not stale(gifs):
        if verbose:
            print("sky is already built for this period and segment count")
        return []
    try:
        os.makedirs(gifs, exist_ok=True)
    except OSError:
        pass

    want = wanted_manifest()
    written = []
    # Written last, and only on success: a half-finished set must read as stale
    # so the next run starts over rather than applying a segment that is not
    # there.
    try:
        os.remove(manifest_path(gifs))
    except OSError:
        pass

    for i in range(want["segments"]):
        path = os.path.join(gifs, segment_name(i))
        size = meadowsky.build_segment(path, i, want["segments"])
        written.append((path, size))
        if verbose:
            print("  %s  %d KB" % (segment_name(i), size // 1024))

    with open(manifest_path(gifs), "w") as fh:
        json.dump(want, fh, indent=2)
    return written


def _write_state(segment, dark):
    try:
        tmp = "%s.%d" % (STATE_FILE, os.getpid())
        with open(tmp, "w") as fh:
            json.dump({"segment": int(segment), "dark": bool(dark),
                       "at": int(time.time())}, fh)
        os.replace(tmp, STATE_FILE)
    except OSError:
        pass


def apply(segment, dark, verbose=True):
    gifs = wtbg.gif_dir()
    image = os.path.join(gifs, segment_name(segment))
    if not os.path.exists(image):
        # Either the set was never built or the period changed under it. Build
        # it now: this is already a detached process that nothing is waiting on,
        # and half a minute of rendering beats a sky stuck at midday.
        try:
            build(gifs, verbose=verbose)
        except Exception as exc:
            if verbose:
                print("sky build failed: %s: %s" % (type(exc).__name__, exc))
    if not os.path.exists(image):
        # Still nothing. Fall back to the single static sky rather than leaving
        # the window with no background at all.
        image = os.path.join(gifs, LEGACY)
        if not os.path.exists(image):
            raise SystemExit("no sky to apply - run: sl-meadow-sky.py build")

    scheme = wtbg.MEADOW_NIGHT_SCHEME if dark else wtbg.MEADOW_SCHEME
    wtbg.apply_file(image, 1.0, scheme)
    cctheme.set_theme(CC_THEME[bool(dark)])
    _write_state(segment, dark)

    try:
        os.remove(LOCK_FILE)
    except OSError:
        pass

    if verbose:
        print("sky -> %s  scheme -> %s  ui -> %s"
              % (os.path.basename(image), scheme["name"], CC_THEME[bool(dark)]))
    return image


def status():
    gifs = wtbg.gif_dir()
    p = daylight.phase()
    print("phase    : %.4f  (%s)" % (p, daylight.look_name(p)))
    print("period   : %.0f s in %d segments" % (daylight.period(),
                                                daylight.segments()))
    print("wanted   : segment %d, %s"
          % (daylight.segment_of(p), "dark" if daylight.is_dark(p) else "light"))
    try:
        with open(STATE_FILE) as fh:
            print("applied  : %s" % json.load(fh))
    except (OSError, ValueError):
        print("applied  : none")
    print("gif dir  : %s" % gifs)
    print("built    : %s" % ("stale - run build" if stale(gifs) else "current"))


def main():
    args = sys.argv[1:]
    cmd = args[0] if args else "status"

    if cmd == "build":
        gifs = wtbg.gif_dir()
        t0 = time.time()
        written = build(gifs, force="--force" in args)
        if written:
            total = sum(size for _, size in written)
            print("%d segments, %.1f MB, %.0f s"
                  % (len(written), total / 1048576.0, time.time() - t0))
    elif cmd == "apply":
        if len(args) < 3:
            raise SystemExit("usage: apply <segment> <light|dark>")
        apply(int(args[1]), args[2] == "dark")
    elif cmd == "now":
        p = daylight.phase()
        apply(daylight.segment_of(p), daylight.is_dark(p))
    else:
        status()


if __name__ == "__main__":
    main()
