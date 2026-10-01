#!/usr/bin/env python3
"""Render a statusline theme's Canvas to a PNG so it can be inspected as an image.

There is no PIL on this box, so the PNG is written by hand: IHDR, one deflated
IDAT of filter-0 scanlines, IEND, with a CRC per chunk. The same approach the
old make_water.py used.

Each text cell becomes a CELL_W x CELL_H block. Only the three glyphs the scene
layers actually emit are handled -- " ", "▀" and "▄" -- because that is all
Canvas/Pixels can produce for a pixel-art theme. Anything else is drawn as a
solid foreground block, which is enough to spot it.

  ./preview_png.py meadow /tmp/meadow.png [cols] [lines] [t]
"""
import binascii
import struct
import sys
import os
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

CELL_W = 6
CELL_H = 12


def chunk(tag, data):
    return (struct.pack(">I", len(data)) + tag + data
            + struct.pack(">I", binascii.crc32(tag + data) & 0xFFFFFFFF))


def write_png(path, width, height, pixels):
    """pixels: list of rows, each a list of (r, g, b)."""
    raw = bytearray()
    for row in pixels:
        raw.append(0)                       # filter type 0
        for r, g, b in row:
            raw += bytes((r, g, b))
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
           + chunk(b"IEND", b""))
    with open(path, "wb") as fh:
        fh.write(png)
    return len(png)


def canvas_to_png(canvas, path, default_bg=(12, 12, 12)):
    W, H = canvas.width * CELL_W, canvas.height * CELL_H
    img = [[default_bg] * W for _ in range(H)]

    for cy, row in enumerate(canvas.cells):
        for cx, (ch, fg, bg) in enumerate(row):
            back = bg or default_bg
            fore = fg or (220, 220, 220)
            x0, y0 = cx * CELL_W, cy * CELL_H
            half = CELL_H // 2
            for dy in range(CELL_H):
                if ch == "▀":
                    col = fore if dy < half else back
                elif ch == "▄":
                    col = back if dy < half else fore
                elif ch == " ":
                    col = back
                else:
                    col = fore
                for dx in range(CELL_W):
                    img[y0 + dy][x0 + dx] = col
    return write_png(path, W, H, img)


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else "meadow"
    out = sys.argv[2] if len(sys.argv) > 2 else "/tmp/%s.png" % name
    cols = int(sys.argv[3]) if len(sys.argv) > 3 else 100
    lines = int(sys.argv[4]) if len(sys.argv) > 4 else 28
    t = float(sys.argv[5]) if len(sys.argv) > 5 else 1000.0

    os.environ["COLUMNS"], os.environ["LINES"] = str(cols), str(lines)
    mod = __import__(name)
    width = max(20, cols - 2)
    canvas = mod.scene(width, mod.panel_height(lines), t)
    size = canvas_to_png(canvas, out)
    print("%s  %dx%d cells  -> %s (%d KB)"
          % (name, canvas.width, canvas.height, out, size // 1024))


if __name__ == "__main__":
    main()
