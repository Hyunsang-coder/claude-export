# claude-export

Claude Code의 모든 응답을 프로젝트별 마크다운 파일로 자동 저장합니다. **LLM 호출 없음** — 순수 `bash` + `jq`.

세션 하나 = 마크다운 파일 하나. 각 응답이 타임스탬프가 붙은 섹션으로 누적됩니다.

## 설치

```bash
curl -fsSL https://raw.githubusercontent.com/Hyunsang-coder/claude-export/main/install.sh | bash
```

끝입니다. 그런 다음 export를 켜고 싶은 프로젝트에서 다음을 실행하세요:

```
/export on
```

## 사용법

| 명령어 | 동작 |
|---|---|
| `/export on` | **현재 프로젝트**에서 자동 export 활성화. `./.claude/export-enabled` 생성. |
| `/export off` | 현재 프로젝트에서 비활성화. |
| `/export status` | ON/OFF 상태 표시. |
| `/export-response` | export off 상태에서도 **마지막 완료된 응답 1건만** 즉시 저장. 같은 세션이면 기존 파일에 append, 처음이면 새로 생성. |
| `/update-claude-export` | 최신 버전으로 업데이트 (install.sh 재실행). 변경 사항을 적용하려면 Claude Code 재시작 필요. |

출력은 `./claude-exports/{session_id}.md`에 저장되며 다음과 같은 형식입니다:

```markdown
# Claude session 1fa310da-5bd5-4f34-8d8c-bb9c9400d3e5

---

## 2026-05-18 10:34:00

(assistant 응답 텍스트 — tool call과 tool result는 제외됨)

---

## 2026-05-18 10:37:46

...
```

## `.gitignore` 권장 설정

```
.claude/export-enabled
claude-exports/
```

## 요구사항

- macOS 또는 Linux (Windows는 테스트되지 않음)
- `bash`, `jq`, `curl`

`jq` 설치: `brew install jq` (macOS) 또는 `apt install jq` (Debian/Ubuntu).

## 동작 원리

Claude가 한 턴을 마치면 `Stop` 훅이 실행됩니다. 번들된 `hooks/export-last-response.sh`는 다음을 수행합니다:

1. 훅의 stdin JSON에서 `transcript_path`, `cwd`, `session_id`를 읽음.
2. `$cwd/.claude/export-enabled`가 없으면 → 조용히 종료.
3. 있으면 JSONL transcript에 `jq`를 실행해 마지막 *실제* 사용자 프롬프트 이후의 모든 `assistant.text` 블록을 추출 (`tool_result` 라인은 건너뜀).
4. 타임스탬프 헤더와 함께 `$cwd/claude-exports/{session_id}.md`에 append.

## 설치되는 항목

- `~/.claude/hooks/export-last-response.sh` — 훅 스크립트
- `~/.claude/commands/export.md` — `/export` 슬래시 커맨드
- `~/.claude/commands/export-response.md` — `/export-response` 슬래시 커맨드
- `~/.claude/commands/update-claude-export.md` — `/update-claude-export` 슬래시 커맨드
- `~/.claude/settings.json`의 `hooks.Stop`에 항목 1개 추가 (`claude-export:v1` 태그가 붙어 있어 uninstall 시 깔끔하게 제거 가능). 기존 설정과 다른 훅들은 보존되며, 타임스탬프가 붙은 백업이 같은 위치에 생성됩니다.

## 제거

```bash
curl -fsSL https://raw.githubusercontent.com/Hyunsang-coder/claude-export/main/install.sh | bash -s -- uninstall
```

위 세 항목을 제거합니다. 프로젝트별 플래그(`.claude/export-enabled`)와 이미 export된 파일은 그대로 남겨둡니다.

## 라이선스

MIT
