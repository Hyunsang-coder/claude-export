#!/usr/bin/env bash
# Stop hook: Claude의 마지막 assistant 응답에서 text 블록만 추출해
# $cwd/claude-exports/{session_id}.md 에 append 한다. LLM 호출 없음, jq만 사용.
#
# 한 세션 = 한 파일. 매 응답마다 "## YYYY-MM-DD HH:MM:SS" 헤더 + 본문이 누적됨.
#
# 동작 모드:
#   - 인자 없이 호출 (Stop hook): stdin JSON 읽고, ./.claude/export-enabled 가 있을 때만 저장
#   - "force" (Stop hook + 플래그 무시): stdin JSON 읽고 무조건 저장
#   - "force --slash --cwd <path>" (/export-response 슬래시 커맨드): stdin 없이,
#       <path> 기준 ~/.claude/projects/<encoded>/ 에서 가장 최근 .jsonl 을 찾아 저장
#
# Hook stdin JSON: { transcript_path, cwd, session_id, ... }

set -euo pipefail

MODE="${1:-auto}"
SOURCE="hook"
SLASH_CWD=""

# 두 번째 이후 인자 파싱 (슬래시 커맨드 경로)
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --slash) SOURCE="slash"; shift ;;
    --cwd)   SLASH_CWD="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

# Claude Code 의 projects/ 디렉터리 인코딩과 동일 규칙:
# 영숫자가 아닌 모든 문자(/, ., 공백, _ 등)를 '-' 로 치환.
# 예: /Users/joo/Documents/GitHub/Raon-OpenTTS-0.3B
#  -> -Users-joo-Documents-GitHub-Raon-OpenTTS-0-3B
encode_cwd() {
  local s="$1"
  # bash 의 변수 확장만으로는 character class 치환이 안 되므로 sed 사용
  printf '%s' "$s" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g'
}

# 후보 transcript 들 중 내부 cwd 가 정확히 일치하는 것만 선택 (인코딩 충돌 회피).
# 일치하는 것이 여러 개면 mtime 이 가장 최근인 것.
find_transcript_for_cwd() {
  local target_cwd="$1"
  local encoded
  encoded=$(encode_cwd "$target_cwd")
  local proj_dir="${HOME}/.claude/projects/${encoded}"
  [[ -d "$proj_dir" ]] || return 1

  local best=""
  local best_mtime=0
  local f mtime real_cwd
  # null-byte 구분으로 안전하게 순회
  while IFS= read -r -d '' f; do
    # 각 .jsonl 의 첫 cwd 필드를 읽어 실제 프로젝트 경로 확인
    real_cwd=$(jq -r 'select(.cwd != null) | .cwd' "$f" 2>/dev/null | head -n 1 || true)
    # cwd 필드가 없는 오래된 transcript 는 인코딩만 일치하면 일단 후보로 둠
    if [[ -z "$real_cwd" || "$real_cwd" == "$target_cwd" ]]; then
      mtime=$(stat -f '%m' "$f" 2>/dev/null || stat -c '%Y' "$f" 2>/dev/null || echo 0)
      if (( mtime > best_mtime )); then
        best_mtime=$mtime
        best="$f"
      fi
    fi
  done < <(find "$proj_dir" -maxdepth 1 -type f -name '*.jsonl' -print0 2>/dev/null)

  [[ -n "$best" ]] || return 1
  printf '%s\n' "$best"
}

if [[ "$SOURCE" == "slash" ]]; then
  # 슬래시 커맨드 컨텍스트: stdin JSON이 없음. cwd로부터 transcript를 추론.
  cwd="$SLASH_CWD"
  if [[ -z "$cwd" || ! -d "$cwd" ]]; then
    echo "export-response: --cwd is required and must exist" >&2
    exit 1
  fi
  # newline 등 비정상 문자가 들어 있으면 거부 (방어적)
  if [[ "$cwd" == *$'\n'* ]]; then
    echo "export-response: cwd contains newline; refusing" >&2
    exit 1
  fi
  transcript=$(find_transcript_for_cwd "$cwd" || true)
  if [[ -z "$transcript" || ! -f "$transcript" ]]; then
    echo "No completed response found to export."
    exit 0
  fi
  # session_id = transcript 파일 basename에서 .jsonl 제거
  session_id=$(basename "$transcript" .jsonl)
else
  # Stop hook 컨텍스트: stdin JSON 파싱
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
fi

# 이번 턴의 모든 assistant text 블록을 합침.
# 한 턴의 assistant 응답은 여러 JSONL 라인(text/tool_use 섞임)으로 쪼개진다.
# "진짜 user prompt" 는 content가 문자열이거나 tool_result가 아닌 user 라인.
# 그 마지막 진짜 user prompt 이후의 모든 assistant.text 블록을 시간순으로 잇는다.
#
# 슬래시 컨텍스트에서는 transcript 끝에 "/export-response" user 라인이
# 이미 추가된 상태이므로, 그 라인 자체는 건너뛰고 그 *직전* 실제 user prompt
# 이후의 assistant.text 를 추출하기 위해 skip_last=1 을 넘긴다.
# 단, user prompt 가 단 1개뿐인 세션이면 fallback 으로 그 1개부터 추출.
skip_last=0
[[ "$SOURCE" == "slash" ]] && skip_last=1

content=$(jq -rs --argjson skip_last "$skip_last" '
  def is_real_user:
    .type=="user"
    and ((.message.content | type == "string")
         or (.message.content | type == "array"
             and any(.[]; .type != "tool_result")));
  [range(0; length) as $i | select(.[$i] | is_real_user) | $i] as $user_idxs
  | (if ($user_idxs | length) == 0 then null
     elif $skip_last == 1 and ($user_idxs | length) >= 2 then $user_idxs[-2]
     else $user_idxs[-1] end) as $start
  | if $start == null then []
    else .[$start:]
         | map(select(.type=="assistant"))
         | map(.message.content[]? | select(.type=="text") | .text)
    end
  | join("\n\n")
' "$transcript" 2>/dev/null || true)

# 추출 결과가 비어있으면 저장하지 않음
if [[ -z "${content// }" ]]; then
  if [[ "$SOURCE" == "slash" ]]; then
    echo "No completed response found to export."
  fi
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
  printf '# Claude session %s\n\n---\n\n' "$session_id" > "$out"
fi

# 응답 1건을 한 번의 write 로 append (동시 Stop hook 간 인터리브 방지).
# 페이로드 전체를 변수에 만든 뒤 단일 printf 호출로 append 하면
# 짧은 경우엔 사실상 atomic 하다 (PIPE_BUF 이하).
payload="$(printf '## %s\n\n%s\n\n---\n\n' "$ts" "$content")"
printf '%s' "$payload" >> "$out"

if [[ "$SOURCE" == "slash" ]]; then
  echo "Exported last response → $out"
fi

exit 0
