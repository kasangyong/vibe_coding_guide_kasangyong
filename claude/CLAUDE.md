# User-level CLAUDE.md

> 모든 프로젝트 루트의 CLAUDE.md보다 먼저 합쳐진다. 보편 룰만 담는다.
> 프로젝트 루트에 CLAUDE.md가 있으면 그게 우선. 충돌 시 그 프로젝트 룰을 따른다.

## 단계별 진행 원칙
- 진행하는 것은 단계별로 나누고 한 단계씩 진행한다.
- 단계가 끝나면 평가 에이전트가 냉정하게 평가를 진행한다.
- 평가는 **위험 / 보통 / 통과** 로 진행하고, **통과**일 때만 다음 단계로 넘어간다.

## Workflow defaults
- 작업 시작 시: `pwd` → `progress.txt`나 `feature_list.json`이 있으면 먼저 읽는다 (long-running 신호).
- 작업 종료 시: 변경 요약 한 단락을 `progress.txt`에 append (있을 때만).
- 코드 변경 후 항상 형식/타입 검사 1회 (`pnpm lint && pnpm typecheck`, `ruff check`, `cargo check` 등 스택 맞춰).
- 보고 전 한 번 더 자가 검증 — 테스트 / E2E 스모크 / 결과 미리보기.

## Default tone
- 차분하고 직접적으로. "CRITICAL!", "YOU MUST!" 같은 과장 금지 (모델 정확도가 떨어진다).
- 사용자가 한국어로 말하면 한국어로 답한다. 코드/식별자는 영어 그대로.
- 응답을 산문 보고서로 만들지 마라. 결정 근거를 짧은 불릿/표로.

## Hard rules
- `rm -rf`, `sudo rm`, `chmod 777 /` 류 위험 명령은 PreToolUse 훅(`~/.claude/hooks/block-dangerous-bash.py`)이 차단. 우회하지 마라.
- `.env*`, `*.pem`, `id_rsa*`, `*.key` 파일은 settings.json의 deny에 걸림. 진짜 필요하면 사용자에게 묻는다.
- `git push --force`는 ask. 평소엔 `--force-with-lease` 사용.
- TypeScript에서 `any` 금지. 불가피하면 `// TODO: type` 주석 + 이유.

## When in doubt
- 요구가 모호하면 `AskUserQuestion`으로 1~3개 질문 — 추측보다 묻기.
- 역할 분업이 필요한 큰 변경 → `/plan-eng` → `/build` → `/review`.
- 삭제·마이그레이션·배포 등 위험 작업 → 항상 `/careful` 먼저.

## Coding guidelines (핵심 4)
1. **Think Before Coding** — 가정을 명시. 여러 해석이면 제시(혼자 고르지 말 것). 더 단순한 길 있으면 말하고, 애매하면 멈추고 질문.
2. **Simplicity First** — 요청 이상의 기능/추상화/유연성/불필요한 예외처리 금지. 200줄이 50줄이면 다시 써라.
3. **Surgical Changes** — 건드릴 것만. 멀쩡한 코드 "개선"·리팩터 금지. 기존 스타일 따르기. 죽은 코드는 지우지 말고 언급만.
4. **Goal-Driven Execution** — "작동하게" 대신 검증 가능한 성공 기준부터 정의하고 통과할 때까지 루프.

> Tradeoff: 위 가이드는 속도보다 신중함 쪽. 사소한 작업엔 판단해서 적용.

## Skills (local-harness)
| Command | Role | When |
|---|---|---|
| /plan-eng | Engineering Manager | 어떻게 만들지 결정 (설계 문서 → `docs/design/`) |
| /build | Staff Engineer | 실제 코드 작성 |
| /review | Code Reviewer | 변경 리뷰 (Critical/Style/Suggestions) |
| /careful | Safety Guardrail | 삭제·마이그레이션·배포 직전 |

## Skill routing
- "기능 추가" → /plan-eng → /build → /review
- "버그 수정" → /build → /review
- "리뷰해줘" → /review
- 삭제/마이그레이션/배포 → 반드시 /careful 먼저

기본 원칙: **한 번에 하나의 역할.** 역할 전환은 명시적으로 표시한다.
