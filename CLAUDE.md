# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo ships

`claude-export` is a tiny distribution wrapper around three artifacts that get installed into the user's `~/.claude/` directory:

1. `hooks/export-last-response.sh` — the actual work (a `Stop` hook).
2. `commands/export.md` — the `/export on|off|status` slash command users invoke per-project.
3. `install.sh` — fetches the above from GitHub raw, drops them into `~/.claude/`, and patches `~/.claude/settings.json` to register the hook.

There is no build system, no package manager, no test suite, and no application runtime. Every change to this repo eventually reaches users via `curl | bash` of `install.sh`, which pulls the latest `main` of these files from `raw.githubusercontent.com/Hyunsang-coder/claude-export/main/...`.

## Architecture notes that aren't obvious from one file

**The transcript extraction is the whole product.** `hooks/export-last-response.sh` runs after every Claude turn. Its job is to isolate *only the assistant text blocks from the current turn* out of the full session JSONL transcript and append them to `claude-exports/{session_id}.md`. The non-obvious parts:

- A turn boundary is defined as the last *real* user prompt — meaning a `user` line whose `message.content` is either a plain string, or an array containing at least one block that is **not** a `tool_result`. Tool-result `user` lines must be skipped, otherwise every tool round-trip would look like a new turn and the export would only contain the trailing fragment.
- After locating that boundary, only `assistant` lines after it are kept, and only their `text`-typed content blocks (tool calls are intentionally excluded). The `jq` pipeline at `hooks/export-last-response.sh:38-49` encodes this — preserve its semantics when editing.
- The script has two invocation modes: bare (Stop hook, gated by `$cwd/.claude/export-enabled`) and `force` (slash-command path, ignores the flag). Both read the same `{transcript_path, cwd, session_id}` JSON from stdin.
- Empty extractions must exit without writing — otherwise the per-session file accumulates dated headers with no body.

**Installer must be idempotent and reversible.** `install.sh` tags its `hooks.Stop` entry in `~/.claude/settings.json` with `__tag: "claude-export:v1"` so `do_uninstall` can remove exactly that entry and leave any user-authored hooks intact. Always back up `settings.json` (timestamped) before mutating it, and use `jq` to merge — never overwrite the file. The hook-add `jq` filter at `install.sh:38-53` skips adding a duplicate when the tag already exists; preserve that guard.

**Per-project opt-in is a flag file, not config.** Enablement lives at `<project>/.claude/export-enabled` (an empty file). The slash command at `commands/export.md` just toggles its presence via `touch`/`rm`. There is no JSON, no parsing — keep it that way.

## Release flow

There is no versioned release. `main` *is* the release channel:

1. Edit `hooks/export-last-response.sh`, `commands/export.md`, or `install.sh`.
2. Commit and push to `main`.
3. Existing users keep running whatever they installed; new users get the new version on next `curl | bash`.

Because the installer references `main` by URL, breaking changes to the hook script ship instantly to anyone re-installing. If the hook's stdin contract or output format changes incompatibly, bump `HOOK_MARK` in `install.sh` (e.g. `claude-export:v2`) so old entries can be detected and migrated.

## Conventions specific to this repo

- The hook script is intentionally pure `bash` + `jq` — no Node, Python, or LLM calls. Don't introduce dependencies.
- Korean comments in `hooks/export-last-response.sh` are intentional (the author's working language). Don't translate them on incidental edits.
- The README's "What gets installed" / "Uninstall" sections are the user-facing contract for `install.sh`. If you change what the installer touches, update both blocks in `README.md`.
