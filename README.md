# claude-export

Append every Claude Code assistant response to `claude-exports/{session_id}.md` in the project root. No LLM calls — pure `bash` + `jq`.

One session = one markdown file, with each response as a timestamped `## YYYY-MM-DD HH:MM:SS` section.

## Install

```
/plugin marketplace add Hyunsang-coder/claude-export
/plugin install claude-export@claude-export
```

Then enable for the project you're in:

```
/export on
```

## Commands

| Command | Effect |
|---|---|
| `/export on` | Create `.claude/export-enabled` flag in the current project. Subsequent responses are auto-saved. |
| `/export off` | Remove the flag. Auto-export stops. |
| `/export status` | Report ON/OFF for the current project. |

The flag is project-scoped (`./.claude/export-enabled`). Enabling in one repo doesn't affect others.

## Output format

`claude-exports/{session_id}.md`:

```markdown
# Claude session 1fa310da-5bd5-4f34-8d8c-bb9c9400d3e5

---

## 2026-05-18 10:34:00

(assistant response text — tool calls and tool results are excluded)

---

## 2026-05-18 10:37:46

...
```

## How it works

A `Stop` hook fires when Claude finishes a turn. The bundled `hooks/export-last-response.sh`:

1. Reads `transcript_path`, `cwd`, `session_id` from the hook's stdin JSON.
2. If `$cwd/.claude/export-enabled` doesn't exist → exit silently.
3. Otherwise, runs `jq` over the JSONL transcript to extract every `assistant.text` block that came after the last *real* user prompt (skipping `tool_result` lines).
4. Appends to `$cwd/claude-exports/{session_id}.md` with a timestamp header.

## Requirements

- `jq` (preinstalled on macOS via `brew install jq`, or `apt install jq` on Linux)
- `bash`

## Suggested .gitignore

Add to your project:

```
.claude/export-enabled
claude-exports/
```

## License

MIT
