---
description: "Export the last completed Claude response to claude-exports/{session_id}.md (one-shot, ignores /export on/off)"
allowed-tools: ["Bash(~/.claude/hooks/export-last-response.sh:*)"]
---

Run the export hook once in `force` mode, ignoring the per-project `.claude/export-enabled` flag. This appends the last completed assistant turn to `./claude-exports/{session_id}.md` (creating the file if this is the first export in the session).

Execute exactly this command and report the result line it prints:

```bash
~/.claude/hooks/export-last-response.sh force --slash --cwd "$(pwd)"
```

Then reply with a single line:
- On success: "Exported last response → `<path>`"
- If nothing to export: "No completed response found to export."
- On error: print the error line verbatim.

No other actions.
