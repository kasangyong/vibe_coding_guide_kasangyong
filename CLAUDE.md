# User-level CLAUDE.md (ka)

> 이 파일은 모든 프로젝트 루트의 `CLAUDE.md` 보다 먼저 합쳐져 들어간다.
> 모든 작업에 보편적으로 적용되는 룰만 담는다. 프로젝트 한정 룰은 그 프로젝트의
> CLAUDE.md에 둔다.

## Workflow defaults
- 프로젝트 루트에 `CLAUDE.md`가 있으면 그게 우선. 충돌 시 그 프로젝트 룰을 따른다.
- 작업 시작 시: `pwd` → `claude-progress.txt`나 `feature_list.json`이 있으면 먼저 읽는다 (long-running 모드 신호).
- 작업 종료 시: 변경 요약 한 단락을 `claude-progress.txt`에 append (있을 때만). Stop hook이 자동 실행하지만, 수동으로도 챙겨라.
- 코드 변경 후 항상 형식/타입 검사를 한 번 돌린다 (`pnpm lint && pnpm typecheck`, `ruff check`, `cargo check` 등 스택 맞춰).
- 보고하기 전에 한 번 더 자가 검증 — 테스트 실행 / E2E 스모크 / 결과 미리보기.

## Default tone
- 차분하고 직접적으로. "CRITICAL!", "YOU MUST!" 같은 과장 금지 (모델 정확도가 떨어진다).
- 사용자가 한국어로 말하면 한국어로 답한다. 코드/식별자는 영어 그대로.
- 응답을 산문 보고서로 만들지 마라. 결정 근거를 짧은 불릿/표로.

## Hard rules (보편)
- `rm -rf`, `sudo rm`, `chmod 777 /` 류 위험 명령은 PreToolUse 훅이 차단. 우회하려 하지 마라.
- `.env*`, `*.pem`, `id_rsa*`, `*.key` 파일은 settings.json의 deny에 걸림. 진짜 필요하면 사용자에게 묻는다.
- `git push --force` 는 ask. 평소엔 `--force-with-lease` 사용.
- TypeScript에서 `any` 금지. 불가피하면 `// TODO: type` 주석 + 이유.

## What I have available globally

### Subagents (`~/.claude/agents/`)
- `code-reviewer` — diff 리뷰. file:line 단위로 critical/style/suggestions.
- `design-critic` — 현재 UI 스크린샷과 레퍼런스 비교, 정확히 3개 차이점.

### Slash commands (`~/.claude/commands/`)
- `/review` — 현재 브랜치 diff를 code-reviewer에게.
- `/design-critique` — Playwright 스크린샷 + design-critic 호출.
- `/anti-ai-design` — 디자인 룰을 컨텍스트에 적재 (web-design 스킬 매뉴얼 발동).
- `/progress` — `claude-progress.txt` 마지막 5세션 요약.
- `/init-long-running` — 현재 디렉토리에 long-running 템플릿 부트스트랩.

### Custom skill content (`~/.claude/user-skills/`)
- `web-design/` — AI 티 안 나는 디자인 룰. `/anti-ai-design` 으로 발동.
- `long-running/` — 장시간 작업 템플릿. `/init-long-running` 이 여기서 복사.

> Note: `~/.claude/skills/`는 Anthropic 기본 스킬 영역이라 사용자 커스텀 스킬은 `user-skills/`에 두고 슬래시 커맨드로 명시적 발동한다. 프로젝트별 자동 로딩 스킬을 만들고 싶으면 그 프로젝트의 `.claude/skills/` 안에 SKILL.md를 둬라.

## When in doubt
- 디자인 작업 (HTML/CSS/Tailwind/React UI) → 시작 전에 `/anti-ai-design` 또는 `cat ~/.claude/user-skills/web-design/SKILL.md` 후 진행.
- 장시간 작업 → 첫 세션이면 `/init-long-running` → `feature_list.json` 채우기.
- 요구가 모호하면 `AskUserQuestion`으로 1~3개 질문 — 추측보다 묻기.

## Master reference
더 자세한 하네스 작성 가이드는 `~/Desktop/claude-harness-master-guide.md`. 새 환경에 셋업할 때 1차 자료.

---

## Coding guidelines

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

### 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.
