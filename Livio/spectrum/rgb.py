"""The "rgb" theme: three information rows under a drifting rainbow rule.

  0) full-width rainbow rule
  1) cwd | git branch | lines added/removed
  2) context bar | weekly gateway spend | session cost | wasted tokens | duration
  3) fast-mode / reasoning effort | model | agent | PR
"""

import os
import time

from common import (DIM, RESET, c, dig, git_branch, human_duration, hsv, money,
                    short_path, thousands, weekly_spend)

DESCRIPTION = "three info rows under a drifting rainbow rule"

SEP = c(DIM, "  │  ")

RULE_CHAR = "━"
RULE_CYCLE = 30.0   # seconds for the gradient to travel a full colour wheel
# Columns the interface reserves around the status line. Too small and the row
# overflows, and Claude Code truncates it with a "..." tail; too large and the
# rule stops short. Override with STATUSLINE_RULE_PAD if the fit is off.
RULE_PAD = 2
RULE_SPREAD = 1.0   # turns of the wheel spanned end-to-end
RULE_SAT = 0.68
RULE_VAL = 0.95


def context_bar(pct, width=12):
    """Context-window meter: fill length is usage, colour is severity."""
    pct = max(0.0, min(100.0, float(pct)))
    filled = int(round(pct / 100 * width))
    sev = 71 if pct < 50 else (179 if pct < 75 else 167)
    bar = c(sev, "█" * filled) + c(237, "░" * (width - filled))
    return c(DIM, "ctx ") + bar + " " + c(sev, f"{pct:.0f}%")


def rainbow_rule():
    """Full-width gradient rule, hue slowly drifting with wall-clock time."""
    try:
        width = int(os.environ.get("COLUMNS") or 0)
    except ValueError:
        width = 0
    try:
        pad = int(os.environ.get("STATUSLINE_RULE_PAD") or RULE_PAD)
    except ValueError:
        pad = RULE_PAD
    width = max(20, (width or 80) - pad)

    if os.environ.get("STATUSLINE_NO_TRUECOLOR"):
        return c(DIM, RULE_CHAR * width)

    phase = (time.time() / RULE_CYCLE) % 1.0
    out = []
    prev = None
    for i in range(width):
        h = (phase + i * RULE_SPREAD / width) % 1.0
        col = hsv(h, RULE_SAT, RULE_VAL)
        if col != prev:  # only emit an escape when the colour actually changes
            out.append("\033[38;2;%d;%d;%dm" % col)
            prev = col
        out.append(RULE_CHAR)
    out.append(RESET)
    return "".join(out)


def render(d):
    rows = [rainbow_rule()]

    # --- row 1: location -------------------------------------------------
    cwd = dig(d, "workspace", "current_dir") or d.get("cwd") or os.getcwd()
    seg = [c(114, short_path(cwd))]

    branch = dig(d, "worktree", "branch") or git_branch(cwd)
    if branch:
        seg.append(c(252, branch))

    added = dig(d, "cost", "total_lines_added", default=0) or 0
    removed = dig(d, "cost", "total_lines_removed", default=0) or 0
    if added or removed:
        seg.append(c(71, f"+{added}") + c(DIM, "/") + c(167, f"-{removed}"))
    rows.append(SEP.join(seg))

    # --- row 2: budget & burn --------------------------------------------
    seg = []
    pct = dig(d, "context_window", "used_percentage")
    if pct is not None:
        seg.append(context_bar(pct))

    wk = weekly_spend()
    if wk:
        spend, budget = wk
        share = (spend / budget * 100) if budget else 0.0
        seg.append(
            c(179, money(spend)) + c(DIM, " / ") + c(244, money(budget))
            + c(DIM, " · ") + c(179, f"{share:.1f}% weekly")
        )

    session_cost = dig(d, "cost", "total_cost_usd")
    if session_cost is not None:
        seg.append(c(215, money(session_cost)))

    wasted = dig(d, "prompt_cache", "miss_recache_tokens", default=0) or 0
    if wasted:
        seg.append(c(DIM, "tokens wasted: ") + c(244, thousands(wasted)))

    dur = dig(d, "cost", "total_duration_ms")
    if dur:
        seg.append(c(244, human_duration(dur)))
    if seg:
        rows.append(SEP.join(seg))

    # --- row 3: model & effort -------------------------------------------
    seg = []
    effort = dig(d, "effort", "level")
    bits = []
    if d.get("fast_mode"):
        bits.append("⚡ fast")
    if effort:
        bits.append(f"{effort} effort")
    if dig(d, "thinking", "enabled") and not effort:
        bits.append("thinking")
    if bits:
        seg.append(c(DIM, " · ").join(c(221, b) for b in bits))

    model = dig(d, "model", "display_name") or dig(d, "model", "id") or ""
    if model:
        size = dig(d, "context_window", "context_window_size", default=0) or 0
        if size >= 1_000_000 and "1M" not in model:
            model = f"{model} (1M context)"
        seg.append(c(110, model))

    agent = dig(d, "agent", "name")
    if agent:
        seg.append(c(140, f"agent: {agent}"))

    pr = dig(d, "pr", "number")
    if pr:
        state = dig(d, "pr", "review_state") or ""
        kind = "MR" if dig(d, "pr", "kind") == "mr" else "PR"
        label = f"{kind} !{pr}" if kind == "MR" else f"{kind} #{pr}"
        colour = {"approved": 71, "changes_requested": 167, "draft": DIM}.get(state, 179)
        seg.append(c(colour, label))

    if seg:
        rows.append(SEP.join(seg))

    return rows
