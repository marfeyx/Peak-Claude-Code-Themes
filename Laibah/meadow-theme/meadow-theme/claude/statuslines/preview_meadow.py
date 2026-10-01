#!/usr/bin/env python3
"""Render the meadow panel at several points of the day cycle, as one PNG.

The panel is transparent everywhere except the soil -- the sky behind it is the
terminal's background image, not something this module paints -- so a preview
that fills the gaps with a flat dark grey is not showing what you would see.
Each strip is therefore composited over its own phase's horizon colour, which
is what is actually behind the grass at that moment.

  ./preview_meadow.py /tmp/meadow-cycle.png [cols] [lines] [n]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import daylight
import preview_png

GAP = 6                      # blank pixel rows between strips


def strip(phase, cols, lines, payload, t):
    os.environ["COLUMNS"], os.environ["LINES"] = str(cols), str(lines)
    os.environ["SL_MEADOW_PHASE"] = "%.6f" % phase
    for mod in ("meadow", "daylight"):
        sys.modules.pop(mod, None)
    import meadow

    pal = daylight.palette(phase)
    canvas = meadow.scene(cols - 2, meadow.panel_height(lines), t, pal,
                          daylight.nightness(phase))
    meadow.draw_info(canvas, payload, 34.0, pal)
    return canvas, pal


def to_rows(canvas, bg):
    W = canvas.width * preview_png.CELL_W
    H = canvas.height * preview_png.CELL_H
    img = [[bg] * W for _ in range(H)]
    for cy, row in enumerate(canvas.cells):
        for cx, (ch, fg, back) in enumerate(row):
            b = back or bg
            f = fg or (220, 220, 220)
            x0, y0 = cx * preview_png.CELL_W, cy * preview_png.CELL_H
            half = preview_png.CELL_H // 2
            for dy in range(preview_png.CELL_H):
                if ch == "▀":
                    col = f if dy < half else b
                elif ch == "▄":
                    col = b if dy < half else f
                elif ch == " ":
                    col = b
                elif ch == "":
                    continue
                else:
                    col = f
                for dx in range(preview_png.CELL_W):
                    img[y0 + dy][x0 + dx] = col
    return img


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/meadow-cycle.png"
    cols = int(sys.argv[2]) if len(sys.argv) > 2 else 100
    lines = int(sys.argv[3]) if len(sys.argv) > 3 else 28
    n = int(sys.argv[4]) if len(sys.argv) > 4 else 6

    payload = {
        "workspace": {"current_dir": "/home/you/projects/demo"},
        "model": {"display_name": "Opus 5"},
        "cost": {"total_cost_usd": 2.10},
        "context_window": {"used_percentage": 34},
    }

    rows = []
    for i in range(n):
        phase = i / float(n)
        canvas, pal = strip(phase, cols, lines, payload, 1000.0 + i * 0.0)
        block = to_rows(canvas, pal["sky_horizon"])
        if rows:
            rows += [[(0, 0, 0)] * len(block[0]) for _ in range(GAP)]
        rows += block
        print("  p=%.3f %-6s" % (phase, daylight.look_name(phase)))

    size = preview_png.write_png(out, len(rows[0]), len(rows), rows)
    print("%s  %dx%d  (%d KB)" % (out, len(rows[0]), len(rows), size // 1024))


if __name__ == "__main__":
    main()
