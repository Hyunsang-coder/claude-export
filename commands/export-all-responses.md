---
description: "Export all assistant text responses from the current session to claude-exports/{session_id}.md (overwrites the file)"
allowed-tools: ["Bash(~/.claude/hooks/export-last-response.sh:*)"]
---

Run the export hook once in `force --all` mode, ignoring the per-project `.claude/export-enabled` flag. This dumps every assistant text response from the current session into `./claude-exports/{session_id}.md`, overwriting whatever was there.

Execute exactly this command and report the result line it prints:

```bash
~/.claude/hooks/export-last-response.sh force --slash --all --cwd "$(pwd)"
```

Then reply with a single line:
- On success: "Exported full session → `<path>`"
- If nothing to export: "No completed response found to export."
- On error: print the error line verbatim.

No other actions.
