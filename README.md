# claude-export

Auto-save every Claude Code response to a per-session markdown file in your project. **Zero LLM calls** — pure `bash` + `jq`.

One session = one markdown file. Each response is appended as a timestamped section.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Hyunsang-coder/claude-export/main/install.sh | bash
```

That's it. Then, in any project you want to export:

```
/export on
```

## Usage

| Command | Effect |
|---|---|
| `/export on` | Enable auto-export **for the current project**. Creates `./.claude/export-enabled`. |
| `/export off` | Disable for the current project. |
| `/export status` | Show ON/OFF. |

Output lives at `./claude-exports/{session_id}.md`, looking like:

```markdown
# Claude session 1fa310da-5bd5-4f34-8d8c-bb9c9400d3e5

---

## 2026-05-18 10:34:00

(assistant response text — tool calls and tool results are excluded)

---

## 2026-05-18 10:37:46

...
```

## Suggested `.gitignore`

```
.claude/export-enabled
claude-exports/
```

## Requirements

- macOS or Linux (Windows untested)
- `bash`, `jq`, `curl`

Install `jq` via `brew install jq` (macOS) or `apt install jq` (Debian/Ubuntu).

## How it works

A `Stop` hook fires when Claude finishes a turn. The bundled `hooks/export-last-response.sh`:

1. Reads `transcript_path`, `cwd`, `session_id` from the hook's stdin JSON.
2. If `$cwd/.claude/export-enabled` doesn't exist → exit silently.
3. Otherwise runs `jq` over the JSONL transcript to extract every `assistant.text` block that came after the last *real* user prompt (skipping `tool_result` lines).
4. Appends to `$cwd/claude-exports/{session_id}.md` with a timestamp header.

## What gets installed

- `~/.claude/hooks/export-last-response.sh` — the hook script
- `~/.claude/commands/export.md` — the `/export` slash command
- One entry added to `~/.claude/settings.json` under `hooks.Stop` (tagged `claude-export:v1` so uninstall can remove it cleanly). Your existing settings and other hooks are preserved; a timestamped backup is written next to the file.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/Hyunsang-coder/claude-export/main/install.sh | bash -s -- uninstall
```

Removes the three things above. Per-project flags (`.claude/export-enabled`) and already-exported files are left alone.

## License

MIT
