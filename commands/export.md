---
description: "Toggle auto-export of Claude responses to claude-exports/{session}.md for this project"
argument-hint: "on | off | status"
allowed-tools: ["Bash(mkdir:*)", "Bash(touch:*)", "Bash(rm:*)", "Bash(test:*)"]
---

User input: `$ARGUMENTS`

Behavior:
- `on` → run `mkdir -p .claude && touch .claude/export-enabled`, then reply: "Auto-export ON for this project. Each response will be appended to `claude-exports/{session_id}.md`."
- `off` → run `rm -f .claude/export-enabled`, then reply: "Auto-export OFF for this project."
- `status` or empty → run `test -f .claude/export-enabled && echo ON || echo OFF` and report ON/OFF.
- Anything else → one-line usage hint: "/export on | off | status".

Execute the matching shell command once and report briefly. No other actions.
