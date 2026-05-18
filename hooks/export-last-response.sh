#!/usr/bin/env bash
# Stop hook: Claude의 마지막 assistant 응답에서 text 블록만 추출해
# $cwd/claude-exports/{session_id}.md 에 append 한다. LLM 호출 없음, jq만 사용.
#
# 한 세션 = 한 파일. 매 응답마다 "## YYYY-MM-DD HH:MM:SS" 헤더 + 본문이 누적됨.
#
# 동작 모드:
#   - 인자 없이 호출 (Stop hook): ./.claude/export-enabled 가 있을 때만 저장
#   - "force" 인자로 호출 (/export 슬래시 커맨드): 플래그 무시하고 항상 저장
#
# Hook stdin JSON: { transcript_path, cwd, session_id, ... }

set -euo pipefail

MODE="${1:-auto}"

input=$(cat)
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty')
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty')

# transcript/cwd 없으면 조용히 종료 (Stop 외 컨텍스트에서 잘못 트리거된 경우)
if [[ -z "$transcript" || -z "$cwd" || ! -f "$transcript" ]]; then
  exit 0
fi

# auto 모드면 프로젝트 플래그 확인
if [[ "$MODE" != "force" ]]; then
  if [[ ! -f "$cwd/.claude/export-enabled" ]]; then
    exit 0
  fi
fi

# 이번 턴의 모든 assistant text 블록을 합침.
# 한 턴의 assistant 응답은 여러 JSONL 라인(text/tool_use 섞임)으로 쪼개진다.
# "진짜 user prompt" 는 content가 문자열이거나 tool_result가 아닌 user 라인.
# 그 마지막 진짜 user prompt 이후의 모든 assistant.text 블록을 시간순으로 잇는다.
content=$(jq -rs '
  def is_real_user:
    .type=="user"
    and ((.message.content | type == "string")
         or (.message.content | type == "array"
             and any(.[]; .type != "tool_result")));
  (map(is_real_user) | reverse | index(true)) as $rev_idx
  | if $rev_idx == null then [] else .[length - $rev_idx :] end
  | map(select(.type=="assistant"))
  | map(.message.content[]? | select(.type=="text") | .text)
  | join("\n\n")
' "$transcript" 2>/dev/null || true)

# 추출 결과가 비어있으면 저장하지 않음
if [[ -z "${content// }" ]]; then
  exit 0
fi

ts=$(date +"%Y-%m-%d %H:%M:%S")
out_dir="$cwd/claude-exports"
mkdir -p "$out_dir"

# session_id 없으면 fallback (오래된 Claude Code 버전 대비)
if [[ -z "$session_id" ]]; then
  session_id="nosession-$(date +%Y-%m-%d)"
fi
out="$out_dir/${session_id}.md"

# 새 파일이면 H1 헤더로 시작
if [[ ! -e "$out" ]]; then
  {
    printf '# Claude session %s\n\n' "$session_id"
    printf -- '---\n\n'
  } > "$out"
fi

# 응답 1건 append: H2 timestamp + 본문 + 구분선
{
  printf '## %s\n\n' "$ts"
  printf '%s\n\n' "$content"
  printf -- '---\n\n'
} >> "$out"

exit 0
