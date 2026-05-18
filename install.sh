#!/usr/bin/env bash
# claude-export installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Hyunsang-coder/claude-export/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/Hyunsang-coder/claude-export/main/install.sh | bash -s -- uninstall

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/Hyunsang-coder/claude-export/main"
CLAUDE_DIR="${HOME}/.claude"
HOOK_DST="${CLAUDE_DIR}/hooks/export-last-response.sh"
CMD_DST="${CLAUDE_DIR}/commands/export.md"
CMD_RESP_DST="${CLAUDE_DIR}/commands/export-response.md"
CMD_ALL_DST="${CLAUDE_DIR}/commands/export-all-responses.md"
CMD_UPDATE_DST="${CLAUDE_DIR}/commands/update-claude-export.md"
SETTINGS="${CLAUDE_DIR}/settings.json"
HOOK_MARK="claude-export:v1"

red()   { printf '\033[31m%s\033[0m\n' "$*" >&2; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
info()  { printf '  %s\n' "$*"; }

require() {
  command -v "$1" >/dev/null 2>&1 || { red "Missing required tool: $1"; exit 1; }
}

require bash
require jq
require curl

ACTION="${1:-install}"

backup_settings() {
  if [[ -f "$SETTINGS" ]]; then
    local bk="${SETTINGS}.claude-export.bak.$(date +%s)"
    cp "$SETTINGS" "$bk"
    info "Settings backup: $bk"
    # 기존 파일이 invalid JSON 이면 jq 가 뒤에서 실패하므로 미리 감지해서 명확히 안내
    if ! jq -e . "$SETTINGS" >/dev/null 2>&1; then
      red "Existing $SETTINGS is not valid JSON. Original is backed up at $bk. Aborting."
      exit 1
    fi
  else
    echo '{}' > "$SETTINGS"
  fi
}

add_hook_entry() {
  local tmp
  tmp=$(mktemp)
  jq --arg cmd "$HOOK_DST" --arg mark "$HOOK_MARK" '
    .hooks //= {}
    | .hooks.Stop //= []
    | if any(.hooks.Stop[]?; .__tag == $mark) then .
      else .hooks.Stop += [{
        "__tag": $mark,
        "matcher": "",
        "hooks": [{"type":"command","command": $cmd}]
      }]
      end
  ' "$SETTINGS" > "$tmp"
  mv "$tmp" "$SETTINGS"
}

remove_hook_entry() {
  [[ -f "$SETTINGS" ]] || return 0
  local tmp
  tmp=$(mktemp)
  jq --arg mark "$HOOK_MARK" '
    if (.hooks.Stop // []) | length == 0 then .
    else .hooks.Stop |= map(select(.__tag != $mark))
         | if .hooks.Stop | length == 0 then del(.hooks.Stop) else . end
    end
  ' "$SETTINGS" > "$tmp"
  mv "$tmp" "$SETTINGS"
}

fetch() {
  local url="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  curl -fsSL "$url" -o "$dst"
}

do_install() {
  green "Installing claude-export to $CLAUDE_DIR"

  fetch "${REPO_RAW}/hooks/export-last-response.sh" "$HOOK_DST"
  chmod +x "$HOOK_DST"
  info "Installed: $HOOK_DST"

  fetch "${REPO_RAW}/commands/export.md" "$CMD_DST"
  info "Installed: $CMD_DST"

  fetch "${REPO_RAW}/commands/export-response.md" "$CMD_RESP_DST"
  info "Installed: $CMD_RESP_DST"

  fetch "${REPO_RAW}/commands/export-all-responses.md" "$CMD_ALL_DST"
  info "Installed: $CMD_ALL_DST"

  fetch "${REPO_RAW}/commands/update-claude-export.md" "$CMD_UPDATE_DST"
  info "Installed: $CMD_UPDATE_DST"

  backup_settings
  add_hook_entry
  info "Registered Stop hook in $SETTINGS"

  green "Done."
  cat <<EOF

Next steps:
  1) In any project you want auto-exports for, run:
       /export on
  2) Each response after that is appended to:
       <project>/claude-exports/<session_id>.md
  3) Turn it off any time with:
       /export off

Add to .gitignore in projects that use it:
  .claude/export-enabled
  claude-exports/

Uninstall:
  curl -fsSL ${REPO_RAW}/install.sh | bash -s -- uninstall
EOF
}

do_uninstall() {
  green "Uninstalling claude-export"
  backup_settings
  remove_hook_entry
  info "Removed Stop hook entry from $SETTINGS"

  [[ -f "$HOOK_DST" ]]       && { rm -f "$HOOK_DST";       info "Deleted: $HOOK_DST"; }       || true
  [[ -f "$CMD_DST" ]]        && { rm -f "$CMD_DST";        info "Deleted: $CMD_DST"; }        || true
  [[ -f "$CMD_RESP_DST" ]]   && { rm -f "$CMD_RESP_DST";   info "Deleted: $CMD_RESP_DST"; }   || true
  [[ -f "$CMD_ALL_DST" ]]    && { rm -f "$CMD_ALL_DST";    info "Deleted: $CMD_ALL_DST"; }    || true
  [[ -f "$CMD_UPDATE_DST" ]] && { rm -f "$CMD_UPDATE_DST"; info "Deleted: $CMD_UPDATE_DST"; } || true

  green "Done. Per-project flags (.claude/export-enabled) and exported files (claude-exports/) are left alone."
}

case "$ACTION" in
  install)   do_install ;;
  uninstall) do_uninstall ;;
  *) red "Unknown action: $ACTION (use 'install' or 'uninstall')"; exit 2 ;;
esac
