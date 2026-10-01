"""Inert replacement for Livio's GIF89a writer.

watergif.py and kyotogif.py import this module at the top because their
build_all() generators write animation frames to disk. Those generators are
never reached from a render -- the themes only pull art constants and two
timing values out of them -- so the real writer is deliberately not vendored.
Anything that does try to produce a file gets a loud failure instead of a
surprise write into the user's AppData directory.
"""


def write_gif(*args, **kwargs):
    """Raise, because this vendored tree is a renderer and never writes images."""
    raise RuntimeError(
        "gifwriter is stubbed out in vendor/livio: a status line render never "
        "writes files. Use Livio's own bundle to regenerate artwork."
    )
