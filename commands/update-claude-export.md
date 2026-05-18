---
description: "Re-run the claude-export installer to pull the latest hook script and slash commands from GitHub"
allowed-tools: ["Bash(curl:*)"]
---

Re-run the upstream installer. This is safe to run repeatedly — `install.sh` is idempotent: it overwrites the bundled files (`hooks/export-last-response.sh`, `commands/export.md`, `commands/export-response.md`) with the latest `main`, and skips re-adding the `Stop` hook entry in `~/.claude/settings.json` if it's already present (matched by the `claude-export:v1` tag). A timestamped backup of `settings.json` is written before any mutation.

Execute exactly this command and report the trailing output verbatim:

```bash
curl -fsSL https://raw.githubusercontent.com/Hyunsang-coder/claude-export/main/install.sh | bash
```

Then reply with a single line: "claude-export updated. Restart Claude Code for command changes to take effect."

No other actions.
