---
description: Switch, preview, rename or clone the statusline theme
argument-hint: "[number|name] | list | next | prev | preview <ref> | rename <ref> <name> | clone <ref> <name> | describe <ref> <text> | delete <ref>"
allowed-tools: Bash(__CLAUDE_DIR__/statusline/switch.sh), Bash(__CLAUDE_DIR__/statusline/switch.sh *)
disable-model-invocation: true
---

!`__CLAUDE_DIR__/statusline/switch.sh $ARGUMENTS`

The statusline switcher has already run; its output is above. Relay it in at most two short lines,
and if it was an error, say what the valid options are. Do not call any tool — the work is done.

If the line above is still the literal unexecuted command text rather than its output, the
injection was skipped. Only in that case, run that exact command yourself with Bash, then relay.
