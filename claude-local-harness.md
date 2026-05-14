# Claude 로컬 하네스 구성 가이드

> gstack ([garrytan/gstack](https://github.com/garrytan/gstack)) 구조를 참고한,
> 내 워크스테이션에서 돌아가는 "1인 엔지니어링 팀" 하네스 설계 문서.

---

## 1. 왜 하네스인가

Claude Code(또는 다른 에이전트)는 단독으로 강력하지만, 매번 "어떤 역할로,
어떤 순서로, 어떤 결과물을 남기며 일할지"를 사람이 매번 손으로 지시해야 한다.

**하네스(harness)** 는 그 지시 패턴 자체를 파일로 굳혀 둔 레이어다.

- 역할(role)별 markdown 파일 = 한 명의 가상 전문가
- 슬래시 커맨드 = 그 전문가를 호출하는 방법
- 산출물(artifact) = 다음 단계 전문가의 입력
- `CLAUDE.md` = 어떤 전문가가 있고 언제 부르는지를 적은 인덱스

gstack은 이걸 23개 역할 + 8개 도구로 구성한 레퍼런스 구현이다.
아래는 그 구조를 **개인 워크스테이션 규모**로 축소한 최소 하네스 설계다.

---

## 2. 설계 원칙 (gstack에서 가져옴)

| 원칙 | 의미 |
|---|---|
| **Process > Tools** | 도구 모음이 아니라 *워크플로우*다. Think → Plan → Build → Review → Test → Ship → Reflect 순서를 강제한다. |
| **Role-named, not action-named** | `/refactor` 가 아니라 `/eng-manager`. "누가 하는가"가 "무엇을 하는가"보다 라우팅에 유리하다. |
| **Outputs are inputs** | 각 스킬은 다음 스킬이 읽을 수 있는 구조화된 파일(설계 문서, 계획, 테스트 매트릭스)을 남긴다. |
| **CLAUDE.md = registry** | 프로젝트 루트의 `CLAUDE.md` 안에 `## Skills` / `## Skill routing` 섹션을 두고, 거기서 어떤 슬래시 커맨드가 있는지를 모델에게 알려준다. |
| **Single setup entry** | `./setup` 한 줄로 심볼릭 링크 + 레지스트리 작성까지 끝낸다. |
| **Safety rails** | `/careful`(가드레일), `/freeze`(스코프 락) 같은 메타 스킬을 둔다. |
| **Cross-model check** | 중요한 결정은 다른 모델/에이전트로 한 번 더 검증한다. |

---

## 3. 디렉토리 레이아웃

```
~/.claude/skills/local-harness/
├── README.md                  # 이 문서의 축약본
├── CLAUDE.md.snippet          # 프로젝트 CLAUDE.md에 붙여넣을 라우팅 섹션
├── setup                      # 설치 스크립트 (bash)
├── VERSION
│
├── plan-ceo/                  # 제품/우선순위 결정자
│   └── SKILL.md
├── plan-eng/                  # 아키텍처 결정자
│   └── SKILL.md
├── design/                    # UI/UX 검토
│   └── SKILL.md
├── build/                     # 실제 코드 작성
│   └── SKILL.md
├── review/                    # 코드 리뷰어
│   └── SKILL.md
├── qa/                        # 브라우저로 직접 테스트
│   └── SKILL.md
├── security/                  # OWASP/STRIDE 점검
│   └── SKILL.md
├── ship/                      # PR 작성 + 배포
│   └── SKILL.md
├── retro/                     # 회고 + learnings 갱신
│   └── SKILL.md
│
├── careful/                   # 가드레일 메타 스킬
│   └── SKILL.md
├── freeze/                    # 스코프 락 메타 스킬
│   └── SKILL.md
│
├── context-save/              # 세션 체크포인트 저장
│   └── SKILL.md
├── context-restore/           # 세션 복원
│   └── SKILL.md
├── learn/                     # 프로젝트별 영구 학습 저장소
│   └── SKILL.md
│
└── bin/
    ├── benchmark              # 같은 프롬프트를 여러 모델에 돌려 비교
    └── cross-check            # 다른 에이전트로 2차 의견
```

핵심은 **각 폴더 = 슬래시 커맨드 1개 = 역할 1개**라는 1:1:1 매핑이다.

---

## 4. SKILL.md 표준 템플릿

모든 역할 폴더 안의 `SKILL.md`는 동일한 frontmatter + 섹션 구조를 따른다.

```markdown
---
name: plan-eng
role: Engineering Manager
triggers:
  - "아키텍처 짜줘"
  - "기술 결정"
  - "design doc"
inputs:
  - docs/product-brief.md          # plan-ceo가 남긴 결과물
outputs:
  - docs/design/{feature}-arch.md
chains_to:
  - build
guardrails:
  - "코드를 직접 쓰지 않는다. 결정과 근거만 남긴다."
  - "외부 의존성 추가 시 trade-off 표를 반드시 포함한다."
---

# Engineering Manager

## When to use
사용자가 "어떻게 구현할지 정해줘"라고 요청했을 때.
구현 자체가 아니라 **결정**이 필요한 단계.

## Process
1. `docs/product-brief.md`를 읽는다. 없으면 사용자에게 `/plan-ceo` 먼저 돌리라고 안내.
2. 핵심 결정 포인트 3~7개를 추출한다 (데이터 모델, API 경계, 상태 관리, 의존성).
3. 각 결정에 대해 옵션 2~3개 + trade-off + 추천을 적는다.
4. 결과를 `docs/design/{feature}-arch.md`로 저장한다.
5. 다음 단계로 `/build`를 호출하도록 안내한다.

## Output format
- 헤더: 기능명, 작성일, 관련 brief 링크
- 섹션: 결정 1..N (각각 옵션/trade-off/추천/예상 리스크)
- 마지막: "Open questions" — 사용자 확인이 필요한 항목

## What NOT to do
- 실제 코드 작성 (그건 `/build`의 일)
- 한 가지 옵션만 적기 (반드시 비교 필요)
- "그때 가서 보자" — 결정을 미루는 표현
```

이 템플릿이 통일되어 있으면 모델이 어떤 역할에서든 같은 인터페이스로 일한다.

---

## 5. CLAUDE.md 레지스트리 섹션

프로젝트 루트의 `CLAUDE.md`에 아래 섹션을 추가한다.
gstack은 `./setup` 실행 시 이 섹션을 자동으로 써넣는다.

```markdown
## Skills (local-harness v0.1)

이 프로젝트에서는 다음 슬래시 커맨드가 활성화되어 있다:

| Command       | Role                | When to call                                  |
|---------------|---------------------|-----------------------------------------------|
| /plan-ceo     | Product owner       | 무엇을 만들지 결정                            |
| /plan-eng     | Eng Manager         | 어떻게 만들지 결정                            |
| /design       | Designer            | UI/UX 검토                                    |
| /build        | Staff Engineer      | 실제 코드 작성                                |
| /review       | Code Reviewer       | 변경사항 자체 리뷰                            |
| /qa           | QA Lead             | 실제 브라우저로 동작 확인                     |
| /security    | Security Officer    | OWASP/STRIDE 빠른 점검                        |
| /ship         | Release Engineer    | 커밋 + PR 작성                                |
| /retro        | Reflection          | 끝난 후 learnings 정리                        |
| /careful      | Guardrail           | 위험 작업 전 안전 모드                        |
| /freeze       | Scope lock          | 추가 변경 금지 모드                           |

## Skill routing

- 사용자가 "기능 추가" 요청 → `/plan-ceo` → `/plan-eng` → `/build`
- 사용자가 "리뷰해줘" → `/review` (build 결과물 있을 때) 또는 `/design`
- 사용자가 "버그" → `/qa`로 재현 먼저, 그 다음 `/build`
- 위험한 마이그레이션/삭제/리팩토링 → 항상 `/careful` 먼저
- 세션이 길어졌다 싶으면 `/context-save` 호출 권장

기본 원칙: **한 번에 하나의 역할.** 역할 전환은 명시적으로 표시한다.
```

---

## 6. 워크플로우 (Sprint Loop)

```
   [사용자 요청]
        │
        ▼
   /plan-ceo  ──▶  docs/product-brief.md
        │
        ▼
   /plan-eng  ──▶  docs/design/*-arch.md
        │
        ▼
   /design (optional, UI 변경 시)
        │
        ▼
   /build     ──▶  실제 코드 + 테스트
        │
        ▼
   /review    ──▶  inline 코멘트 + 수정
        │
        ▼
   /qa        ──▶  실제 동작 확인
        │
        ▼
   /security (변경이 신뢰 경계에 닿을 때만)
        │
        ▼
   /ship      ──▶  커밋 + PR
        │
        ▼
   /retro     ──▶  .claude/learnings.md 업데이트
```

중요한 건 **각 화살표가 파일 산출물**이라는 점이다.
모델이 어디서 멈춰도 다음 사람(또는 다음 세션)이 이어받을 수 있다.

---

## 7. 설치 스크립트 (`setup`)

```bash
#!/usr/bin/env bash
set -euo pipefail

HARNESS_ROOT="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_SKILLS_DIR="${HOME}/.claude/skills"

mkdir -p "${CLAUDE_SKILLS_DIR}"

# 각 역할 폴더를 ~/.claude/skills/ 아래로 심볼릭 링크
for skill in "${HARNESS_ROOT}"/*/; do
  name="$(basename "${skill}")"
  [[ "${name}" == "bin" ]] && continue
  [[ "${name}" == "docs" ]] && continue
  ln -sfn "${skill%/}" "${CLAUDE_SKILLS_DIR}/${name}"
  echo "linked: ${name}"
done

# 프로젝트 CLAUDE.md에 라우팅 섹션 삽입(있으면 갱신)
PROJECT_CLAUDE="${PWD}/CLAUDE.md"
SNIPPET="${HARNESS_ROOT}/CLAUDE.md.snippet"

if [[ -f "${PROJECT_CLAUDE}" ]]; then
  if grep -q "## Skills (local-harness" "${PROJECT_CLAUDE}"; then
    echo "CLAUDE.md already has harness section, skipping"
  else
    printf "\n\n" >> "${PROJECT_CLAUDE}"
    cat "${SNIPPET}" >> "${PROJECT_CLAUDE}"
    echo "appended harness section to ${PROJECT_CLAUDE}"
  fi
else
  cp "${SNIPPET}" "${PROJECT_CLAUDE}"
  echo "created ${PROJECT_CLAUDE}"
fi

echo "done. start Claude Code in this directory and try /plan-ceo"
```

사용법:

```bash
git clone <your-repo> ~/.claude/skills/local-harness
cd ~/.claude/skills/local-harness
./setup
```

---

## 8. 안전장치 (Safety rails)

gstack의 `/careful`, `/freeze`, `/guard` 패턴을 최소한으로 도입한다.

- `/careful` — 다음 작업이 *위험* 카테고리(DB 마이그레이션, 파일 대량 삭제,
  외부 API 호출, 결제, 권한 변경)에 속하면 자동으로 호출. dry-run + diff 미리보기 + 사용자 확인 필수.
- `/freeze` — "여기서 멈춰. 다른 거 손대지 마." 모드. 다음 요청이
  스코프를 벗어나면 모델은 "scope frozen — confirm to override"라고 응답.
- `/context-save` — 현재 세션의 결정/남은 작업/시도해서 실패한 것들을
  `.claude/checkpoints/{timestamp}.md`에 저장. gstack은 이걸 `WIP:` 커밋 본문에 넣는다.

---

## 9. 크로스체크 (선택)

신뢰가 필요한 결정에만 사용한다 (모든 작업에 X).

```bash
# bin/cross-check
# 같은 변경에 대해 두 번째 의견을 받는다.
# Codex CLI 또는 다른 로컬 에이전트가 설치되어 있다고 가정.

codex review --diff "$(git diff main)" --output reviews/codex-$(date +%s).md
```

겹치는 지적 = 높은 확신. 한쪽만 잡은 지적 = 사람이 판단.

---

## 10. 최소 구현 순서

처음부터 23개 역할을 만들 필요는 없다. 이 순서를 권장한다:

1. **`/plan-eng` + `/build` + `/review` 3개만** 먼저. 가장 자주 쓰는 루프다.
2. `CLAUDE.md` 라우팅 섹션을 직접 손으로 써본다. 모델이 실제로 그걸 따라가는지 확인.
3. 1주 정도 써보고 *반복되는 실수*가 보이면 → `/careful` 추가.
4. UI를 자주 만지면 → `/design` + `/qa` 추가.
5. 팀에 공유할 일이 생기면 → `/retro` + `learn/` 도입해서 learnings를 누적.
6. 그 다음부터는 *필요할 때만* 새 역할 추가. 미리 만들지 않는다.

---

## 11. 참고

- 원본: [garrytan/gstack](https://github.com/garrytan/gstack) (MIT, 23 skills + 8 tools)
- gstack 핵심 인용:
  > "gstack is a process, not a collection of tools."
- 패턴 요약: **markdown 한 장 = 전문가 한 명**, **CLAUDE.md = 콜시트**,
  **산출물 = 다음 단계 입력**, **`/careful`+`/freeze` = 브레이크**.

---

*v0.1 — 초안. 실제로 1주 굴려보고 ETHOS.md / ARCHITECTURE.md 분리 여부 결정.*
