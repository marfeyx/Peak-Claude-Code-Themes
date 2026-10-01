---
description: Apply the sakura terminal + Claude Code theme
argument-hint: "[sakura | status]"
allowed-tools: Bash(sh -c:*)
disable-model-invocation: true
---

The theme switcher has already run — this is its output. No argument means
`sakura`, which applies the theme; `status` just reports what is active.

!`sh -c '~/.claude/theme.sh "${1:-sakura}"' _ $ARGUMENTS`

Report that output in one or two lines: which theme is active now, plus the
restart caveat only if the script actually printed one. Do not re-run the
script, do not read any config files, and do not offer follow-up work.
