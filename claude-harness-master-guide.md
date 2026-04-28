# Claude 하네스 마스터 가이드 (2026 Edition)

> **이 파일의 사용법**
> 다른 컴퓨터에서 Claude Code / Claude Agent SDK / Claude API 기반의 에이전트를 새로 구성할 때, 이 파일을 참고 자료로 첨부하고
> "이 마크다운 파일을 SKILL.md 격으로 깊이 읽고, 내 환경에 맞게 하네스를 구성해줘"
> 라고 지시하면 된다. 이 문서는 **단일 파일 카피-페이스트 가능한 템플릿**과 **출처가 명시된 원칙**, 그리고 **AI 티 안 나는 웹 디자인 챕터**를 포함한다. 이 가이드의 권고는 모두 Anthropic 공식 엔지니어링 블로그·Claude Code/Agent SDK 문서·실전 회고를 1차 출처로 한다 (부록 A 참조).

---

## 목차

1. [멘탈 모델 — 하네스란 무엇인가](#1-멘탈-모델--하네스란-무엇인가)
2. [에이전트 루프 — Gather / Act / Verify](#2-에이전트-루프--gather--act--verify)
3. [컨텍스트 엔지니어링](#3-컨텍스트-엔지니어링)
4. [시스템 프롬프트와 CLAUDE.md](#4-시스템-프롬프트와-claudemd)
5. [도구(Tool) 설계 — Anthropic의 5원칙](#5-도구tool-설계--anthropic의-5원칙)
6. [Agent Skills (SKILL.md)](#6-agent-skills-skillmd)
7. [Subagents — 컨텍스트 격리의 도구](#7-subagents--컨텍스트-격리의-도구)
8. [Hooks — 결정론적 가드레일](#8-hooks--결정론적-가드레일)
9. [Slash Commands](#9-slash-commands)
10. [MCP 서버](#10-mcp-서버)
11. [플러그인 & 마켓플레이스](#11-플러그인--마켓플레이스)
12. [장시간 작업 하네스 (Long-running Agents)](#12-장시간-작업-하네스-long-running-agents)
13. [Claude Agent SDK 로컬 셋업](#13-claude-agent-sdk-로컬-셋업)
14. [프로젝트 구조 템플릿](#14-프로젝트-구조-템플릿)
15. [평가(Eval) & 검증](#15-평가eval--검증)
16. [AI 티 안 나는 웹 디자인 — 본격 챕터](#16-ai-티-안-나는-웹-디자인--본격-챕터)
17. [통합 스타터 킷 — 한 번에 복사](#17-통합-스타터-킷--한-번에-복사)
18. [다른 컴퓨터에서 0부터 시작하는 법](#18-다른-컴퓨터에서-0부터-시작하는-법)
19. [부록 A — 출처 & 참고 자료](#부록-a--출처--참고-자료)

---

## 1. 멘탈 모델 — 하네스란 무엇인가

**"하네스(harness)"는 모델 자체가 아니라, 모델이 일하게 만드는 모든 것이다.** 시스템 프롬프트, 도구 세트, 컨텍스트 관리 정책, 권한 규칙, 후처리 코드, 외부 도구 통합, 메모리/노트 시스템 — 이 전부의 합이 하네스다.

Anthropic의 정의를 빌리면 다음 한 줄이 가장 정확하다.

> "에이전트를 만든다는 건 5%가 'loop 안에서 모델 호출'이고 95%는 컨텍스트 관리, 도구 실행, 샌드박싱, 에러 처리다." — Anthropic, *Effective harnesses for long-running agents* (2025-11-26)

이 비율은 진심이다. **모델이 아무리 좋아져도 형편없는 하네스 위에서는 형편없게 동작한다.** 반대로 평범한 하네스라도 잘 짜여 있으면 모델 한 단계 더 큰 모델 같은 결과를 낸다.

### 1.1 하네스의 4축

좋은 하네스는 다음 네 축을 명시적으로 설계한다.

1. **Context (무엇을 보여줄까)** — 시스템 프롬프트, 메시지 히스토리, 도구 설명, 외부 자료
2. **Action (무엇을 시킬까)** — 도구, 권한 모드, 슬래시 커맨드, 서브에이전트
3. **Verification (어떻게 검증할까)** — 테스트, 린트, 브라우저 자동화, 사람 인-더-루프
4. **Persistence (무엇을 남길까)** — 진행 노트, 커밋, feature list, 메모리 파일

이 네 축이 균형 잡혀 있을 때만 에이전트가 한 컨텍스트 윈도를 넘어 일관되게 진척된다.

### 1.2 결정론적 시스템 vs 비결정론적 시스템

에이전트용 도구를 설계할 때 가장 흔히 빠지는 함정은, 다른 개발자/시스템에게 주는 API처럼 도구를 만드는 것이다. 그러나 에이전트는 **비결정론적 호출자**다. 같은 입력에도 다른 행동을 한다. 따라서:

- 함수가 아니라 **계약(contract)** 으로 설계하라.
- 출력은 깔끔한 자료구조가 아니라 **모델이 읽고 다음 결정을 잘 내릴 수 있는 형태**여야 한다.
- 모든 이름·설명·파라미터 이름이 **프롬프트의 일부**다. 한 단어 바꾸는 것이 정확도를 흔들 수 있다.

이 한 줄을 마음에 새겨라.

> "툴의 이름·설명·파라미터 문서의 모든 단어가 에이전트가 그 도구를 어떻게 이해할지 만든다." — Anthropic, *Writing effective tools for AI agents* (2025-09-11)

---

## 2. 에이전트 루프 — Gather / Act / Verify

Claude Agent SDK가 권장하는, 그리고 Claude Code 내부가 실제로 도는 루프 구조는 단순하다.

```
loop {
    1) Gather context  — 파일 읽기, 검색, 도구로 정보 모으기
    2) Take action     — 코드 작성, 명령 실행, 외부 API 호출
    3) Verify work     — 테스트, 린트, 브라우저, 사람 검증
    4) Repeat / Stop   — 충분하면 종료, 아니면 다시
}
```

이 루프를 신뢰성 있게 만드는 핵심은 **3단계(Verify)** 다. Claude는 작업을 끝냈다고 자체 선언하기 쉬운 모델이라, 명시적 검증 단계를 강제하지 않으면 "마쳤음" 환각이 발생한다.

### 2.1 자체 검증을 잘 시키는 법

Anthropic이 반복적으로 강조하는 패턴:

- **규칙 기반 피드백을 주어라.** Linter, 단위 테스트, 타입체커, 스키마 검증 — 모델이 스스로 결과를 점수 매길 수 있게 한다.
- **명확한 실패 사유를 보여줘라.** "FAIL"만으론 부족하다. 어떤 규칙이 왜 깨졌는지를 텍스트로 돌려준다.
- **End-to-End를 사람처럼 시켜라.** 단위 테스트만 통과해도 실제 동작은 망가진 경우가 흔하다. 웹 앱이라면 Puppeteer/Playwright MCP로 사람처럼 클릭·스크린샷을 시켜라.

### 2.2 자기 정정 루프

가장 강력한 패턴은 **검증 결과를 같은 컨텍스트로 다시 흘려보내는 것**이다.

```
write code → run tests →
  if fail: feed test output back → fix code → run tests → ...
  if pass: commit & write progress note
```

이게 단순해 보이지만, 많은 하네스가 "테스트 결과를 다시 모델에 안 넘기는" 실수를 한다. 도구의 응답이 길면 잘라야 하지만, **에러 메시지의 핵심 라인은 절대 자르지 마라.**

---

## 3. 컨텍스트 엔지니어링

> "프롬프트 엔지니어링은 단발성. 컨텍스트 엔지니어링은 매 턴 반복되는 큐레이션이다." — Anthropic, *Effective context engineering for AI agents* (2025-09-29)

### 3.1 Context Rot — 컨텍스트는 길수록 망가진다

needle-in-a-haystack 벤치마크들이 일관되게 보여주는 것: **컨텍스트가 길어질수록 모델은 정확도를 잃는다(context rot)**. 이건 모든 모델에 정도의 차이만 있을 뿐 보편적이다. 원인은 트랜스포머 구조 자체다 — 토큰 수가 늘면 n² pairwise attention이 얇게 분산된다.

따라서 컨텍스트는 **무한 자원이 아니라 한정된 attention budget**이다. 매 토큰이 예산을 깎는다. 좋은 하네스의 목표는 한 줄로:

> 원하는 행동을 끌어낼 가능성이 가장 큰, **가장 작은 고신호 토큰 집합**을 찾는다.

### 3.2 Goldilocks Zone — 시스템 프롬프트의 적정 고도

시스템 프롬프트는 두 극단 사이에서 줄을 탄다.

**나쁨 ①: 모든 if/else를 프롬프트에 박아넣기**
```
"만약 사용자가 X를 물으면 Y를 답해라. 단, Z일 때는 W로... (수십 개)"
```
→ 모델이 이걸 일일이 따르려다 다른 일에 집중을 잃는다. 유지보수도 지옥.

**나쁨 ②: 추상적이고 모호한 지시**
```
"좋은 코드를 작성해주세요."
```
→ 모델이 "좋다"의 정의를 추측해야 한다. 평균값으로 수렴한다.

**좋음: 적정 고도(right altitude)**
- 행동의 **방향**과 **휴리스틱**을 준다.
- 구체적 예제를 2~5개 보여준다.
- 디테일은 도구·스킬·노트로 빼서 필요할 때만 로드.

### 3.3 Just-in-Time Retrieval

오래된 패턴: 모든 관련 자료를 임베딩 검색으로 미리 컨텍스트에 박는다.
새 패턴: **가벼운 식별자(파일 경로, URL, 쿼리)** 만 들고 있다가, 필요할 때 도구로 끌어온다.

Claude Code의 동작이 이 방식의 정수다.
- `CLAUDE.md` 만 미리 컨텍스트에 들어간다.
- 나머지는 `Glob`, `Grep`, `Read` 로 그때그때 끌어온다.
- 파일 이름·경로·타임스탬프 자체가 **메타데이터 신호**다.

이걸 흉내 내려면 자기 환경에서도 똑같이 하라:
- 큰 데이터는 임베딩보다 **인덱스/검색 도구**로.
- 모델에 raw blob 대신 **요약 + 식별자** 를 주고, 필요시 더 끌어오게.
- 폴더 구조와 명명 규칙을 의미 있게 — `tests/test_utils.py` 와 `src/core_logic/utils.py` 는 다른 의도라는 걸 모델이 즉시 안다.

### 3.4 장기 작업의 3대 무기 — Compaction / Notes / Sub-agents

컨텍스트 윈도 한계를 넘는 작업에서 쓰는 표준 도구.

#### Compaction (압축 요약)
컨텍스트가 가득 차기 직전, 지금까지의 대화·도구 호출·결과를 모델 자체에게 요약시키고 새 윈도로 이어 붙인다. Claude Code가 기본 제공하는 동작.

압축 프롬프트 작성 팁:
1. 처음에는 **recall(놓치지 않기)** 을 최대화하게 적어라. 핵심 결정·미해결 버그·아키텍처는 무조건 남겨라.
2. 그 다음 **precision(쓸데없는 것 빼기)** 을 올려라. 한참 전 도구 호출의 raw 결과 같은 건 지운다.
3. 가장 안전한 첫 컷: **tool_result 블록부터 정리**. Anthropic은 Developer Platform에 이 기능을 정식 도입했다.

#### Structured Note-taking (구조화된 메모)
모델이 컨텍스트 밖에 직접 글을 남기게 한다.
- `claude-progress.txt` (진행 노트)
- `NOTES.md` (자유 메모)
- `feature_list.json` (해야 할 일 / 끝낸 일)

새 세션 시작 시 이 파일들을 첫 도구 호출로 읽게 하면, 컨텍스트 리셋을 넘어 일관되게 일한다. Claude가 Pokémon을 플레이할 때 수천 스텝의 학습 진척을 유지할 수 있던 것도 이 메모 시스템 덕분이다.

#### Sub-agent Architectures (서브에이전트 분기)
거대한 한 명의 에이전트 대신, 작은 컨텍스트의 전문가 여러 명에게 분기.
- 메인 에이전트: 계획, 통합, 사용자 응답
- 서브 에이전트: 깊은 탐색, 거대 grep, 무거운 도구 호출
- 서브가 수만 토큰을 쓰더라도 **메인에는 1~2K 토큰의 요약만** 돌아온다.

언제 무엇을 쓸지:
- **Compaction** — 대화 흐름이 끊기면 안 되는 작업.
- **Notes** — 명확한 마일스톤이 있는 반복 작업.
- **Sub-agents** — 병렬 탐색이 이득인 리서치/분석.

### 3.5 컨텍스트 엔지니어링 체크리스트

작업 시작 전 자문하라.

- [ ] 시스템 프롬프트가 250~500단어를 넘는가? 그러면 SKILL/노트로 빼라.
- [ ] 도구 설명이 모순되거나 겹치는가? 합쳐라.
- [ ] 큰 파일을 무조건 통째로 읽고 있는가? `head`/`tail`/검색으로 바꿔라.
- [ ] 압축이 켜져 있는가? 한계 80% 도달 전에 트리거되는가?
- [ ] 진행 메모를 매 세션 끝 / 시작에 쓰고 읽는가?

---

## 4. 시스템 프롬프트와 CLAUDE.md

`CLAUDE.md` 는 Claude Code가 프로젝트 디렉토리에서 자동으로 첫 컨텍스트에 끼워 넣는 영구 지시 파일이다. Agent SDK에서도 system prompt에 합쳐 쓸 수 있다. 한 마디로 **프로젝트의 헌법**이다.

### 4.1 CLAUDE.md 작성 원칙 — Minimalism이 핵심

LLM은 프롬프트 주변부 지시에 편향되고, 지시 개수가 늘수록 *전반적인* 지시 준수율이 떨어진다는 것이 반복 보고된다. Claude Code 내장 시스템 프롬프트만 해도 ~50개 지시를 가지고 있으므로, **당신의 CLAUDE.md는 정말로 보편적이고 자주 어겨질 만한 것**만 담아라.

좋은 CLAUDE.md의 기준:
- 🎯 **이 줄이 없으면 모델이 자주 틀리는가?** YES만 남겨라.
- 🎯 **모든 작업에 적용되는가?** 특정 기능/특정 페이지 한정 룰은 SKILL이나 노트로.
- 🎯 **명령형으로 짧게.** "do X" / "never Y" / "prefer Z over W".

### 4.2 좋은 CLAUDE.md 예시 (Next.js + TypeScript)

```markdown
# Project: my-app

## Stack
- Next.js 15 (App Router), TypeScript strict, Tailwind v4, shadcn/ui base.
- Postgres via Prisma, NextAuth, Vitest + Playwright.

## Commands
- dev:    pnpm dev
- test:   pnpm test
- e2e:    pnpm e2e
- lint:   pnpm lint && pnpm typecheck

## Workflow
- After every code change, run `pnpm lint && pnpm typecheck` before reporting done.
- Never commit without running `pnpm test`.
- For UI work, take a Playwright screenshot and inline-attach it.

## Code style
- Prefer server components. Use "use client" only when truly needed.
- No `any`. If unavoidable, add `// TODO: type` and a reason.
- Tailwind: no inline styles, no arbitrary values unless documented.

## Structure
- Routes:    src/app/**
- UI:        src/components/**  (kebab-case files, PascalCase exports)
- Server:    src/server/**       (db, auth, queues)
- Skills:    .claude/skills/**

## What NOT to do
- Don't add new dependencies without writing a 1-line rationale in PR body.
- Don't generate generic "AI-looking" landing pages — see .claude/skills/web-design/SKILL.md.
```

길이의 감각은 위 정도까지가 한계다. 그 이상으로 늘어나면 거의 항상 신호 대 잡음비가 떨어진다.

### 4.3 모노레포에서의 CLAUDE.md

루트에 모든 걸 박아넣지 마라. **각 패키지마다 자기 CLAUDE.md**.

```
my-monorepo/
├── CLAUDE.md                # 전사 컨벤션, 워크플로
├── apps/
│   ├── web/CLAUDE.md         # web 전용 룰
│   └── admin/CLAUDE.md       # admin 전용 룰
├── packages/
│   ├── ui/CLAUDE.md
│   └── db/CLAUDE.md
```

Claude Code는 작업 디렉토리에서 위로 올라가며 CLAUDE.md를 합친다. 각 파일은 자기 패키지에 진짜로만 적용되는 것만 담는다.

### 4.4 강한 어휘는 역효과

이건 직관에 반하지만 데이터로 반복 확인된 것:
- **"CRITICAL!"**, **"YOU MUST!"**, **"NEVER EVER!"** 같은 과격한 어휘는 Claude 4.x 계열에서 오히려 결과를 나쁘게 한다.
- **차분하고 직접적인** 명령형이 잘 먹는다.
- 진짜 위험한 룰만 따로 묶어 `## Hard rules` 섹션으로.

좋은 톤:
```
Run `pnpm lint` after every edit. Don't proceed if it fails.
```

나쁜 톤:
```
🚨 CRITICAL!! YOU MUST ABSOLUTELY ALWAYS RUN LINT!!! NEVER SKIP THIS!!! 🚨
```

### 4.5 XML/Markdown 구획화

긴 시스템 프롬프트는 섹션 구분이 결정적이다. 권장:
- 긴 자유 텍스트(예: 명세서, 예제) → `<background_information>...</background_information>` 같은 XML 태그.
- 짧은 명령형 룰 → Markdown 헤더(`## Commands`, `## Workflow`).
- 예제 → `<example>...</example>` 태그.

XML이 Markdown보다 잘 먹는다는 건 Anthropic 공식 가이드의 일관된 입장이다.

### 4.6 인터뷰 패턴 — `/init`을 신뢰하지 마라

Claude Code의 `/init`은 빠른 시작 CLAUDE.md를 만들지만, 작은 토이 프로젝트가 아니면 한 번에 좋은 결과를 못 낸다. 대신:

```
"이 프로젝트의 CLAUDE.md를 같이 만들자.
나에게 AskUserQuestion으로 5~10개 질문을 던져서, 내가 평소 어떤 실수를 자주 잡아주길 원하는지,
어떤 명령으로 빌드/테스트/배포하는지, 어떤 컨벤션을 강하게 지켜야 하는지를 끌어내라.
질문이 끝나면 그 답을 바탕으로 CLAUDE.md 초안을 보여줘."
```

이게 훨씬 좋은 결과를 낸다.

---

## 5. 도구(Tool) 설계 — Anthropic의 5원칙

Anthropic의 *Writing effective tools for AI agents* (2025-09)는 도구 디자인에 대해 가장 권위 있는 단일 문서다. 핵심 5원칙을 다음과 같이 정리한다.

### 원칙 1 — 옳은 도구를 선택하라 (Choose, don't wrap)

흔한 실수: 기존 API를 1:1로 도구 함수로 감싸기.
- `list_users()`, `list_events()`, `create_event()` 세 개를 따로 만드는 것보다
- `schedule_event(participants, prefer_window)` 하나로 합치는 게 낫다.

**도구는 "하위 작업의 자연스러운 단위"** 여야 한다. 모델이 머릿속으로 "이건 어떤 도구를 부를까?" 망설이는 순간이 있으면, 두 도구가 너무 가깝거나 한 도구가 너무 큰 것이다.

또 하나의 강한 패턴: **컨텍스트 결합형 도구**.
```
get_customer_context(customer_id) → {profile, recent_orders, open_tickets, notes}
```
한 번에 의미 있는 묶음을 돌려준다. 모델은 이 한 호출로 "이 고객은 누구인가"를 안다.

### 원칙 2 — 네임스페이싱 (Namespacing)

수십 개 MCP 서버에서 수백 개 도구가 등록될 수 있는 시대다. 이름 충돌과 모호함은 항상 발생한다.

권장:
- 서비스별 prefix: `asana_*`, `jira_*`, `slack_*`
- 자원별 prefix까지: `asana_projects_search`, `asana_users_search`

prefix vs suffix 어느 쪽이 나은가는 모델에 따라 다르다 — 본인 환경에서 평가하라. 단순한 평가만으로도 정확도가 눈에 띄게 흔들린다.

### 원칙 3 — 의미 있는 컨텍스트만 돌려줘라

도구 응답에서 잘라내야 할 것:
- raw UUID, mime type, 256px URL, internal id 등 모델이 다음 행동에 못 쓰는 것.

채워야 할 것:
- `name`, `image_url`, `file_type`, `summary`, `tags` 같은 **모델이 자연어로 다룰 수 있는 필드**.

UUID 같은 게 꼭 필요하면(다음 도구 호출 인자가 ID일 때), `response_format: "concise" | "detailed"` enum으로 토글 가능하게 만들어라. 평소엔 concise, 실제로 ID가 필요할 때만 detailed.

```typescript
enum ResponseFormat {
  CONCISE = "concise",     // names, summaries
  DETAILED = "detailed",   // + ids, ts, raw fields
}
```

이 단순한 토글이 **토큰 사용량을 1/3로 줄이고 정확도를 올린다**.

### 원칙 4 — 토큰 효율성

모든 도구는 응답 크기 정책을 가져야 한다.
- **Pagination** — `page`, `cursor`, `limit`
- **Range** — `start`, `end`
- **Filtering** — `query`, `tags`, `since`
- **Truncation** — 기본 25,000 토큰 한계 (Claude Code 기준)

잘려도 그냥 `... [truncated]` 만 두지 말고, **모델이 다음에 뭘 해야 할지 알려주는 메시지**를 함께 둬라.

```
Result truncated at 100 of 2,341 rows.
Refine with `query=` (regex) or `since=` (ISO date) to narrow.
```

에러 응답도 같다.
- 나쁨: `400 Bad Request: validation_error_473`
- 좋음: `Invalid argument: 'date' must be ISO8601 (e.g. "2026-04-28"). You sent "April 28th, 2026".`

### 원칙 5 — 도구 설명을 프롬프트로 취급하라

도구 설명·파라미터 doc은 **시스템 프롬프트의 일부로 매 호출 비용이 든다.** 그 한 줄 한 줄이:
- 새로 입사한 사람에게 설명하듯,
- 도메인 용어 정의를 명시적으로,
- 입출력의 모호함을 제거하고,
- 흔한 실수의 가이드를 짧게 포함.

파라미터 이름은 절대 `user`/`id`/`data` 같은 모호한 것 쓰지 마라. `user_id`, `event_id`, `markdown_body` 처럼 자기 설명적이어야 한다.

> Claude Sonnet 3.5는 SWE-bench에서 도구 설명만 다듬고도 SOTA를 갱신했다. 한 단어가 정말로 차이를 만든다.

### 5.6 평가-주도 개발

이 원칙들을 손으로 적용하지 말고, **eval을 만들어 측정하라**. 절차:
1. 30~100개의 현실적 prompt-response 쌍을 만든다(가능하면 Claude로 자동 생성 후 다듬기).
2. 정답은 정확 매칭이 어려우면 LLM-judge로 평가.
3. 도구를 손볼 때마다 eval을 돌리고, **별도 held-out 세트에서도 향상되는지** 확인.
4. 평가 transcripts를 그대로 Claude Code에 붙여넣으면, Claude가 도구 코드와 설명을 자동으로 개선하기도 한다.

---

## 6. Agent Skills (SKILL.md)

> Skills는 organized folders of instructions, scripts, and resources — 디렉토리 단위로 묶인 절차 지식이다.
> *Equipping agents for the real world with Agent Skills* (2025-10-16)

### 6.1 Progressive Disclosure — 스킬의 핵심 설계 원칙

스킬은 3단계로 점진적으로 펼쳐진다.

| 단계 | 적재 시점 | 내용 |
|---|---|---|
| L1 | 시작 시 항상 | YAML frontmatter (name + description) — 30~50 토큰 |
| L2 | Claude가 관련 판단 시 | SKILL.md 본문 — 수백~수천 토큰 |
| L3 | 본문이 참조 시 | 추가 파일 (reference.md, scripts/, assets/) — 사실상 무한 |

20~50개 스킬을 등록해도 시작 오버헤드가 미미한 것이 이 구조 덕분이다. **"필요할 때만 펼쳐지는 매뉴얼"** 같은 것.

### 6.2 SKILL.md 형식

최소 형식:

```markdown
---
name: web-design-anti-ai
description: |
  Use this skill whenever the user asks to design or generate a web page,
  landing page, marketing site, or UI mockup, OR when generating any HTML/CSS
  that will be seen by end users. Especially trigger when the user mentions
  "AI 티 안 나게", "look professional", "vibe coding", or shows dissatisfaction
  with a generated design.
---

# Web Design — Anti-AI Look

## When to use
- The user asked for a website/landing/dashboard/UI.
- You're about to write HTML/Tailwind/CSS that a user will see.

## Decision flow
1. Read references.md before writing any code.
2. If the user did not provide a Design Identity, ASK three questions
   (audience, mood word, accent color). Use AskUserQuestion if available.
3. Apply the rules in rules.md.
4. Self-critique against checklist.md.

## Bundled files
- references.md — what good non-AI sites look like
- rules.md      — color, type, spacing, layout rules
- checklist.md  — 12-point self-review before declaring done
- scripts/critique.py — runs an automated lint over the generated HTML
```

### 6.3 Description은 **트리거 단서**다

`description` 필드는 Claude가 매 턴마다 보면서 "이 스킬을 펼쳐서 읽을까?" 결정하는 핵심이다. 좋은 description은:

- **언제 쓰는지** (When)
- **어떤 키워드/맥락에서 트리거되는지**
- **언제 *안* 쓰는지** (Don't trigger when...)

길어도 된다. 200~400자가 적당하다. 약 200자면 거의 항상 잘 트리거된다.

### 6.4 코드와 매뉴얼의 분리

스킬에 스크립트를 넣을 때는 **이 스크립트를 Claude가 실행해야 하는지, 읽기만 해야 하는지**를 SKILL.md에 명시.

```markdown
## Scripts
- `scripts/critique.py` — RUN this after generating HTML. It exits 0 if clean.
- `scripts/example.py`  — REFERENCE only. Do not execute.
```

코드는 결정론적이고 토큰을 안 먹는다. 정렬·검증·반복 변환 같은 작업은 스킬 코드로 넘기면 안정성과 비용이 동시에 좋아진다.

### 6.5 스킬 만드는 워크플로

좋은 스킬은 한 번에 안 나온다. 다음 사이클을 따른다.

1. **관찰** — Claude가 같은 작업을 반복해 실수하는 패턴을 본다.
2. **수렴** — Claude에게 직접 묻는다: "이 작업에서 자주 실수하는 패턴이 뭐고, 어떤 사전 지시가 있으면 좋겠어?" 그 답을 SKILL.md 초안으로.
3. **분리** — 본문이 너무 길면 references/checklist/scripts로 쪼갠다.
4. **테스트** — 같은 종류 작업 5~10개로 회귀 평가.
5. **반복** — Claude가 스킬을 잘 안 트리거하면 description을 손봐라.

### 6.6 스킬 보안

스킬은 **외부에서 받은 경우 항상 감사하라**.
- bundled scripts가 외부 네트워크를 호출하지 않는지.
- assets/ 안의 파일이 의심스러운 매크로를 가지지 않는지.
- 권한 요구가 합당한지.

신뢰하지 못할 출처라면 격리된 디렉토리에서 dry-run.

---

## 7. Subagents — 컨텍스트 격리의 도구

Subagent는 **자기 컨텍스트 윈도를 따로 가진 작은 Claude**다. 호출자에게는 마지막 요약 한 덩어리만 돌아온다.

### 7.1 언제 서브에이전트를 쓸까

- 메인 컨텍스트를 더럽히기 싫은 큰 탐색(예: grep 수만 매치, 거대 PDF 분석).
- 주제가 바뀌어 새 컨텍스트가 더 깔끔할 때.
- 병렬 가능한 작업.
- 권한·도구 세트를 좁혀서 안전하게 돌리고 싶을 때.

언제 안 쓸까:
- 대화 흐름이 중요한 작업(서브로 빼면 맥락 끊김).
- 크기가 작아 메인에서 그냥 처리하면 되는 일.
- 호출 비용이 결과 가치보다 큰 일.

### 7.2 정의 형식 (Markdown + YAML frontmatter)

`.claude/agents/code-reviewer.md`:

```markdown
---
name: code-reviewer
description: >
  Reviews code diffs for security, style, and bug risk. Trigger when the user
  asks for code review, second opinion, or before merging. Returns a structured
  punch list under 200 words.
tools: Read, Grep, Glob
model: sonnet
---

You are a senior code reviewer. Read the diff, find concrete issues, and return:

## Critical
- ...

## Style
- ...

## Suggestions
- ...

Keep total response under 200 words. Cite file:line for each item.
```

`tools` 를 생략하면 부모 권한을 그대로 상속한다. 명시하면 **최소 권한 원칙**을 강제할 수 있다 — 보안 관점에서는 명시 권장.

`model: inherit` 로 부모와 같은 모델을 쓰거나, 비싼 작업엔 `opus`, 가벼운 분기엔 `haiku`.

### 7.3 저장 위치

- `.claude/agents/` — 프로젝트 단위 (팀 공유, 우선순위 높음)
- `~/.claude/agents/` — 개인 단위 (모든 프로젝트)

### 7.4 잘 짜는 규칙

- **트리거 description은 잘 동작하는 단서를 넣어라.** "Use proactively when..." 같은 문구는 자동 호출을 늘린다.
- **출력 형식을 강제하라.** "report under 200 words / 5 bullet items / table format". 안 그러면 서브에이전트가 한 페이지짜리 산문을 돌려준다 — 메인 컨텍스트가 다시 더러워진다.
- **자기 컨텍스트는 다 쓰고 와도 된다.** 어차피 메인엔 요약만 온다. 서브 안에서는 마음껏 grep/탐색.

---

## 8. Hooks — 결정론적 가드레일

Hooks는 **모델 해석 없이 동작하는 결정론 코드**다. 모델이 환각을 일으키든 말든, 약속된 라이프사이클 이벤트에 무조건 실행된다.

### 8.1 라이프사이클 이벤트 (12종 중 핵심)

| 이벤트 | 시점 | 주 용도 |
|---|---|---|
| `SessionStart` | 세션 시작 | 환경 진단, 노트 로딩 |
| `UserPromptSubmit` | 사용자 입력 직후 | 입력 검증, 컨텍스트 주입 |
| `PreToolUse` | 도구 실행 직전 | 권한 결정, 인자 수정, 차단 |
| `PostToolUse` | 도구 실행 직후 | 로그, 자동 포맷, 검증 |
| `Notification` | 알림 시점 | 사운드/슬랙 |
| `Stop` | 응답 종료 | 진행노트 자동 저장 |
| `SubagentStop` | 서브 종료 | 서브 결과 검증 |

### 8.2 PreToolUse — 가장 강력

`PreToolUse` 가 `permissionDecision: "deny"` 를 돌려주면, 그 도구는 **`bypassPermissions` 모드든 `--dangerously-skip-permissions` 든 무조건 차단된다.** 사용자가 권한 모드를 바꿔도 못 우회한다. 정책을 코드로 강제하는 유일한 길이다.

또한 `updatedInput` 으로 도구 인자를 **수정해서** 통과시킬 수도 있다. 예: `git push` 명령에서 `--force` 가 보이면 `--force-with-lease` 로 바꿔서 통과.

주의: PreToolUse는 병렬 실행되므로 같은 도구 입력을 여러 훅이 수정하면 마지막이 이긴다. 한 도구의 입력은 한 훅만 수정하게 설계.

### 8.3 PostToolUse — 사후 가드

이미 실행된 건 못 되돌린다. 그러나 결과를 검증해서 **Claude에게 피드백을 줄 수 있다.**

```bash
#!/bin/bash
# .claude/hooks/post-edit-lint.sh
# After a file edit, run linter and feed errors back as system reminder.

if pnpm --silent lint; then
  exit 0
else
  echo "Lint failed. Fix errors before continuing." >&2
  exit 2
fi
```

종료 코드 의미:
- `0` — 통과, 조용히 진행
- `2` — 차단(PreToolUse 한정) / 또는 stderr를 Claude에게 system reminder로 전달
- 기타 non-zero — 사용자에게 비차단 에러 표시

### 8.4 settings.json 등록

`.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": ".claude/hooks/block-rm-rf.sh" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": ".claude/hooks/post-edit-lint.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": ".claude/hooks/save-progress.sh" }
        ]
      }
    ]
  }
}
```

### 8.5 흔한 훅 레시피

- **`block-rm-rf.sh`** — `rm -rf /`, `rm -rf ~`, `:( ){ :|:& };:` 같은 위험 패턴 차단.
- **`auto-format.sh`** — `Edit/Write` 후 prettier/black/gofmt 자동 실행.
- **`save-progress.sh`** — `Stop` 시 git diff/status를 `claude-progress.txt`에 append.
- **`prevent-prod-secrets.sh`** — 출력에 API 키 정규식 매칭 시 차단.
- **`require-tests.sh`** — 코드 수정 후 테스트 실행 안 하고 종료 시 재실행 권유.

### 8.6 모든 훅 끄기

`"disableAllHooks": true` 로 일괄 차단. 디버깅용.

---

## 9. Slash Commands

슬래시 커맨드는 **재사용 가능한 프롬프트 매크로**다.

### 9.1 정의

`.claude/commands/review.md`:

```markdown
---
description: Review the current branch's diff for bugs and security issues
---

You are reviewing the diff between $1 (default: main) and HEAD.

Steps:
1. Run `git diff $1...HEAD --stat` to see scope.
2. Use the code-reviewer subagent on the diff.
3. Print: a) blockers, b) suggestions, c) test gaps.

Keep total under 250 words. Cite file:line.
```

호출: `/review` 또는 `/review develop`.

### 9.2 자동 호출

description이 작업과 매칭되면 사용자가 명시적으로 안 쳐도 Claude가 해당 커맨드를 자동 실행할 수 있다. 그래서 description을 좋은 트리거로 적는 게 중요.

### 9.3 슬래시 커맨드 안에서 서브에이전트 / 스킬 부르기

명시적으로 "use the X subagent" / "follow .claude/skills/Y" 같이 써도 된다. 슬래시 커맨드를 **파이프라인**으로 쓰는 패턴.

### 9.4 흔한 슬래시 커맨드

- `/review` — 코드 리뷰 파이프라인.
- `/security-review` — security-reviewer 서브에이전트 호출.
- `/refactor` — 의존성 그래프 분석 후 안전 리팩토링.
- `/triage-bug` — bug ticket을 받아 재현 단계, 원인 후보, 픽스 PR을 묶어 출력.
- `/release-notes` — 마지막 태그 이후 커밋으로 릴리즈 노트 생성.

---

## 10. MCP 서버

**Model Context Protocol (MCP)** 는 모델 ↔ 외부 도구·데이터 간 표준 프로토콜이다. "AI를 위한 USB-C" 라는 비유가 가장 정확하다.

### 10.1 3가지 1차 개념

| 개념 | 비유 | 예 |
|---|---|---|
| **Tools** | POST endpoint | `slack_post_message`, `pagerduty_ack` |
| **Resources** | GET endpoint | `file://path`, `db://table/row` |
| **Prompts** | 매크로 템플릿 | `summarize_pr_template`, `bug_report_template` |

도구는 행동, 리소스는 읽기, 프롬프트는 호출자에게 제공되는 정형 매크로.

### 10.2 로컬 MCP 추가

Claude Code:
```bash
claude mcp add my-local-mcp /path/to/server --transport stdio
claude mcp add my-remote-mcp https://example.com/mcp --transport http
```

Claude Desktop / Cowork:
- 설정 → Developer / Extensions → DXT 또는 stdio 서버 등록.

### 10.3 직접 만들기 (Python 예시)

```python
# server.py
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("my-tools")

@mcp.tool()
def search_docs(query: str, limit: int = 10) -> list[dict]:
    """Search internal docs. Returns up to `limit` items with title, url, snippet."""
    # ... 실제 구현
    return [{"title": "...", "url": "...", "snippet": "..."}]

if __name__ == "__main__":
    mcp.run(transport="stdio")
```

`pip install mcp` 후 stdio로 등록하면 끝. **도구 설명을 시스템 프롬프트처럼 다뤄라** — 한 줄이 정확도를 흔든다.

### 10.4 MCP 어노테이션

도구 메타에 `readOnlyHint`, `destructiveHint`, `openWorldHint` 어노테이션을 붙이면 클라이언트가 적절한 권한 UI를 띄운다. **`destructiveHint: true`** 인 도구는 사용자 확인을 받아라.

### 10.5 설계 팁 재확인

MCP 서버를 만들 때도 §5의 5원칙이 그대로 적용된다.
- 의미 있는 도구로 합치기 (`get_customer_context` 패턴).
- 네임스페이싱 (`acme_*`).
- concise/detailed 응답 토글.
- 토큰 효율(페이지네이션).
- 설명을 프롬프트로 정성껏.

---

## 11. 플러그인 & 마켓플레이스

플러그인 = **Slash commands + Subagents + MCP servers + Hooks + Skills 의 묶음**, 한 명령으로 설치되는 단위.

### 11.1 설치

```bash
# 마켓플레이스 등록
/plugin marketplace add anthropics/claude-plugins-official
# 플러그인 설치
/plugin install <plugin-name>
```

스코프:
- **user** (기본) — 개인 글로벌
- **project** — `.claude/settings.json` 에 추가, 협업자 공유
- **local** — 개인 프로젝트 한정

### 11.2 자작 플러그인 구조

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json        # 메타
├── commands/
│   └── my-cmd.md
├── agents/
│   └── my-agent.md
├── skills/
│   └── my-skill/SKILL.md
├── hooks/
│   └── settings.json
└── README.md
```

마켓플레이스로 배포하려면 `.claude-plugin/marketplace.json` 을 가진 git 저장소면 된다.

---

## 12. 장시간 작업 하네스 (Long-running Agents)

장시간(수 시간~수일) 작업의 핵심 문제: **각 컨텍스트 윈도가 독립이라, 다음 세션은 이전을 기억하지 못한다.** Anthropic이 정리한 표준 해법은 "두 종류 에이전트" 패턴이다.

### 12.1 Initializer + Coding 패턴

#### Initializer (첫 세션만 실행)
- 초기 프롬프트 분석, 명세 풀어쓰기.
- `feature_list.json` 생성 — 200+ 기능을 모두 `passes: false` 로.
- `init.sh` 생성 — 개발 서버 한 줄 실행.
- `claude-progress.txt` 생성 — 빈 진행 노트.
- 첫 git commit.

#### Coding agent (이후 모든 세션)
- 시작 시 의무 절차:
  1. `pwd`
  2. `cat claude-progress.txt`
  3. `git log --oneline -20`
  4. `cat feature_list.json` → 가장 우선순위 높은 미완 기능 선택
  5. `bash init.sh` → 기본 동작 확인 (Puppeteer/Playwright 스모크 테스트)
- 한 세션 = **하나의 기능만** 진행.
- 끝낼 때 의무 절차:
  1. 코드 변경 + 테스트 통과 확인.
  2. `feature_list.json` 의 해당 항목 `passes: true` 로 토글.
  3. git commit (서술적 메시지).
  4. `claude-progress.txt` 에 한 단락 append.

### 12.2 왜 이렇게 하는가

이 구조가 4가지 흔한 실패를 동시에 해결한다.

| 실패 모드 | 해결 |
|---|---|
| 한 세션에서 전부 끝내려다 컨텍스트 폭발 | 한 세션 한 기능 |
| 세션 시작 시 환경 파악에 토큰 낭비 | `init.sh` + 진행 노트 |
| 진척이 있다고 "끝났다" 선언 | `feature_list.json` 의 false 항목 잔존 → 모델이 보고 더 일함 |
| 검증 없이 done 선언 | end-to-end 스모크(Puppeteer)로 강제 |

### 12.3 feature_list.json 형식 (JSON 권장)

```json
[
  {
    "category": "functional",
    "description": "User can open a new chat and receive an AI response",
    "steps": [
      "Click 'New Chat'",
      "Type 'hello'",
      "Press Enter",
      "Verify a response renders within 5s"
    ],
    "passes": false
  }
]
```

Anthropic의 핵심 통찰: **JSON이 Markdown보다 잘 보호된다.** 모델이 JSON 파일은 "함부로 편집하면 안 되는 데이터"로 취급한다. Markdown으로 두면 무심코 항목을 지우거나 문장을 고친다.

### 12.4 End-to-End 검증의 중요성

Claude는 단위 테스트와 curl 만으로 "끝났다" 선언하는 경향이 있다. 사람처럼 클릭하게 강제하라:
- 웹: Playwright/Puppeteer MCP.
- CLI: pty 시뮬레이션.
- API: 실제 호출 + 응답 스키마 검증.

이게 빠진 하네스는 신뢰할 수 없다.

### 12.5 진행 노트 템플릿

`claude-progress.txt`:
```
## Session 2026-04-28 14:32 (#12)
- Worked on: feature 47 (chat sidebar conversation list)
- Done: rendering, click-to-load, deletion. Tests: 5/5 pass.
- Open: hover preview not yet implemented (feature 48).
- Notes: API endpoint /chats returns sorted by `updated_at` desc.

## Session 2026-04-28 09:10 (#11)
...
```

매 세션 끝에 한 단락. 새 세션은 이걸 첫 도구 호출로 읽는다.

---

## 13. Claude Agent SDK 로컬 셋업

### 13.1 시스템 요구사항

- Python ≥ 3.10 (Python SDK)
- Node ≥ 18 (Claude Code CLI; 자동 번들이지만 시스템 노드 권장)
- Anthropic API 키: 환경변수 `ANTHROPIC_API_KEY`

### 13.2 Python 설치

```bash
pip install claude-agent-sdk
# 또는 uv 권장
uv pip install claude-agent-sdk
```

CLI는 패키지에 자동 번들 — 별도 설치 불필요.

### 13.3 Python 최소 예제

```python
# agent.py
import asyncio
from claude_agent_sdk import query, AgentOptions

async def main():
    options = AgentOptions(
        system_prompt="You are a careful Python coder. Always run tests after edits.",
        allowed_tools=["Read", "Write", "Edit", "Bash", "Grep", "Glob"],
        permission_mode="acceptEdits",   # 파일 변경 자동 승인 (개발용)
        cwd="./my-project",
    )
    async for msg in query(
        prompt="Find the bug in src/main.py and fix it. Run pytest after.",
        options=options,
    ):
        print(msg)

asyncio.run(main())
```

스트리밍 텍스트만 받으려면 `include_partial_messages=True` 후 `content_block_delta` 의 `text_delta` 만 모으면 된다.

### 13.4 TypeScript 설치

```bash
npm install @anthropic-ai/claude-agent-sdk
```

```typescript
// agent.ts
import { query } from "@anthropic-ai/claude-agent-sdk";

const stream = query({
  prompt: "Refactor src/auth.ts to use the new tokens API.",
  options: {
    systemPrompt: "You are a careful TypeScript engineer.",
    allowedTools: ["Read", "Write", "Edit", "Bash", "Grep"],
    permissionMode: "acceptEdits",
    cwd: "./my-project",
  },
});

for await (const msg of stream) {
  console.log(msg);
}
```

### 13.5 권한 모드

| 모드 | 동작 | 권장 사용 |
|---|---|---|
| `default` | 위험 도구마다 사용자 승인 | 새 프로젝트, 익숙해질 때까지 |
| `acceptEdits` | 파일 편집 자동 승인 | 신뢰할 수 있는 워크플로 |
| `bypassPermissions` | 모두 자동 | 컨테이너 안 등 격리 환경만 |
| `plan` | 도구 호출 안 함, 계획만 출력 | 검토 단계 |

### 13.6 시스템 프롬프트 합치기

기본은 Claude Code의 거대 시스템 프롬프트가 켜진다. 직접 만들려면:
```python
options = AgentOptions(
    system_prompt={
        "type": "preset",
        "preset": "claude_code",      # Claude Code 기본 + 커스텀 append
        "append": "Project-specific: always prefer pnpm over npm.",
    },
)
```

또는 `"type": "custom"` 으로 완전히 갈아엎을 수도 있다.

### 13.7 도구 직접 추가

Python:
```python
from claude_agent_sdk import tool

@tool(name="get_weather", description="Get current weather for a city.")
def get_weather(city: str) -> dict:
    # ...
    return {"city": city, "tempC": 21, "summary": "Clear"}

options = AgentOptions(tools=[get_weather])
```

§5의 원칙 — 자기 설명적 이름, concise/detailed 토글, 토큰 캡 — 그대로 적용.

### 13.8 MCP 서버를 SDK로 부르기

```python
from claude_agent_sdk import McpStdioServerConfig

options = AgentOptions(
    mcp_servers={
        "fs": McpStdioServerConfig(
            command="npx",
            args=["-y", "@modelcontextprotocol/server-filesystem", "/data"],
        ),
    },
)
```

### 13.9 Hooks SDK에서

훅도 SDK에서 등록 가능:
```python
options = AgentOptions(
    hooks={
        "PreToolUse": [pre_tool_hook_fn],
        "PostToolUse": [post_tool_hook_fn],
    },
)
```

이 함수들은 결정 객체(`{"permissionDecision": "deny", "reason": "..."}` 등)를 반환한다.

---

## 14. 프로젝트 구조 템플릿

다음 구조는 모두 카피-페이스트 가능하며, 크기가 커질수록 자연스럽게 진화시킬 수 있도록 짜였다.

### 14.1 단일 앱 (Generic)

```
my-app/
├── CLAUDE.md
├── .claude/
│   ├── settings.json
│   ├── agents/
│   │   ├── code-reviewer.md
│   │   └── test-writer.md
│   ├── commands/
│   │   ├── review.md
│   │   └── triage.md
│   ├── skills/
│   │   └── web-design/
│   │       ├── SKILL.md
│   │       ├── rules.md
│   │       ├── references.md
│   │       └── checklist.md
│   ├── hooks/
│   │   ├── post-edit-lint.sh
│   │   └── save-progress.sh
│   └── memory/
│       └── notes.md
├── claude-progress.txt
├── feature_list.json     # 장시간 프로젝트 한정
├── init.sh
└── src/
    └── ...
```

### 14.2 Next.js + TypeScript

```
my-next/
├── CLAUDE.md
├── .claude/
│   ├── agents/
│   │   ├── ui-reviewer.md
│   │   └── api-route-writer.md
│   ├── commands/
│   │   ├── new-route.md
│   │   └── new-component.md
│   ├── skills/
│   │   ├── web-design/   # §16 디자인 스킬
│   │   └── tailwind/
│   └── hooks/
│       └── post-edit-typecheck.sh
├── prisma/
├── src/
│   ├── app/
│   ├── components/
│   ├── server/
│   └── lib/
├── tests/
└── e2e/
```

### 14.3 Python API (FastAPI)

```
my-api/
├── CLAUDE.md
├── pyproject.toml
├── .claude/
│   ├── agents/
│   │   └── pytest-runner.md
│   └── skills/
│       └── fastapi-conventions/
├── src/
│   ├── api/
│   ├── domain/
│   ├── infra/
│   └── main.py
└── tests/
```

### 14.4 모노레포

```
my-monorepo/
├── CLAUDE.md                    # 전사
├── .claude/
│   └── ...                      # 전사 스킬/훅
├── apps/
│   ├── web/
│   │   ├── CLAUDE.md            # web 전용
│   │   └── .claude/
│   │       └── ...              # web 전용 스킬
│   └── admin/
│       ├── CLAUDE.md
│       └── .claude/
└── packages/
    ├── ui/
    │   └── CLAUDE.md
    └── db/
        └── CLAUDE.md
```

Claude Code는 작업 디렉토리에서 위로 올라가며 모든 CLAUDE.md를 합쳐 읽는다.

---

## 15. 평가(Eval) & 검증

### 15.1 왜 eval을 만드는가

도구 설명 한 줄, 시스템 프롬프트 두 줄을 바꿨을 때 **정확도가 올랐는지 떨어졌는지 사람 눈으로는 못 본다.** Anthropic이 반복해서 강조하는 것 — "직관 → 평가" 로 갈아탈 수 있어야 진짜 하네스다.

### 15.2 최소 eval 구조

```python
# evals/run_eval.py
import asyncio, json
from claude_agent_sdk import query, AgentOptions

TASKS = [
    {
        "id": "schedule-001",
        "prompt": "Schedule a meeting with Jane next Tuesday 2pm and attach last meeting's notes.",
        "expected_tools": ["search_contact", "schedule_event", "attach_file"],
        "judge": "structured",
    },
    # ...
]

async def run_one(task):
    transcript = []
    async for msg in query(task["prompt"], AgentOptions(...)):
        transcript.append(msg)
    return judge(task, transcript)

async def main():
    results = await asyncio.gather(*[run_one(t) for t in TASKS])
    print(json.dumps(results, indent=2))

asyncio.run(main())
```

### 15.3 Judge 전략

- **String 비교** — 답이 정형이면 가장 단순.
- **LLM judge** — 자유 응답이면 다른 모델/같은 모델에 채점 시킨다.
- **Tool trace 비교** — 어떤 도구를 어떤 순서로 불렀나.
- **금지 위반 여부** — `assert "PASSWORD" not in response`.

### 15.4 메트릭

각 작업마다 수집:
- 정확도 (pass/fail)
- 도구 호출 수
- 토큰 소비
- 총 시간
- 도구 에러 수
- (선택) 비용

### 15.5 Held-out 세트

평가 작업으로 도구를 튜닝하다 보면 항상 거기에 과적합된다. **별도 held-out 30~50개 작업** 을 만들어 두고 거기서도 향상되는지 확인.

### 15.6 Transcript 후분석

각 작업의 transcript(도구 호출+결과+추론)를 그대로 Claude Code에 붙여넣고 묻는다:
- "어디서 헷갈렸는가?"
- "어떤 도구가 빠졌는가?"
- "어떤 설명이 모호했는가?"

이 회고가 다음 라운드의 개선 포인트다.

---

## 16. AI 티 안 나는 웹 디자인 — 본격 챕터

이 챕터는 **바이브 코딩 결과물이 다 똑같이 생기는 문제** 를 정면으로 다룬다. 단순한 "디자인 팁"이 아니라, **하네스 안에 어떻게 디자인 정책을 박아 넣어** Claude/v0/Bolt/Lovable이 항상 일관된 비-AI 룩을 내게 할지의 가이드다.

### 16.1 진단 — 왜 AI 사이트는 다 똑같이 생겼는가

거의 모든 AI 빌더는 같은 학습 분포(shadcn/ui + Tailwind defaults + 흔한 SaaS 레이아웃)를 빨아들였다. 따라서 **명시적 제약이 없으면 통계적 평균값으로 수렴한다**. 실제 분석들이 반복적으로 보고하는 AI-룩 마커:

1. **보라색 계열 그라디언트** (특히 `from-purple-500 to-blue-500` 같은 변종)
2. **이모지 중심 헤더** (🚀, ⚡, 🎯 — 슬랙 부정적 어휘로 "이모지 도배")
3. **3-카드 피처 그리드** + 좌측 아이콘
4. **Hero → Features → Testimonials → Pricing → CTA** 의 스크롤 패턴
5. **`text-center` 도배 영웅 섹션** (모든 게 정중앙)
6. **Inter / Geist / Cal Sans** 같은 흔한 sans-serif 단일 폰트
7. **`rounded-xl` + `shadow-lg` + `bg-gradient-to-br`** 의 카드
8. **Lucide 아이콘** 단일 라이브러리, 단일 굵기
9. **둥근 글래스모피즘** 백그라운드 블러
10. **"AI-powered", "supercharge your workflow"** 같은 카피

**한 가지라도 들어가면 즉시 AI 티가 난다는 게 아니다. 모두 들어갈 때 누적적으로 감지된다.** 이걸 깨려면 일관된 반대 신호를 줘야 한다.

또 자주 빠지는 기술 함정:
- 모바일 viewport meta 태그 누락
- 너무 작거나 큰 터치 타겟
- 가상 페이로드만 채우고 실제 인터랙션 깨진 상태
- 시드 이미지 누락 — Unsplash placeholder URL 그대로

### 16.2 Identity Anchor — 디자인 아이덴티티 도큐먼트

> "AI를 창의적인 두뇌로 쓰지 말고, **실행 엔진** 으로 쓰라. 결정은 생성 *전* 에 내려둬야 한다."

이 한 줄이 핵심이다. 빌더에게 던지기 전에 다음 6항목으로 **Identity Anchor** 한 페이지를 먼저 적어라. 없으면 AI는 15턴 안에 평균값으로 회귀한다.

```yaml
# .claude/skills/web-design/identity.yaml
project: my-app
target_audience:
  primary: "독립 개발자, 25~40세, 이미 도구 많은 사람"
  secondary: "디자인 의식 있는 PM"
mood:
  three_words: ["editorial", "calm", "honest"]
  contrast_to: ["playful", "neon", "techy", "AI-corporate"]
inspiration_urls:
  - https://linear.app
  - https://vercel.com
  - https://stripe.com/press
  - https://tailwindcss.com
brand_voice:
  do: ["concrete numbers", "specific verbs", "first person plural"]
  dont: ["AI-powered", "supercharge", "revolutionize", "🚀"]
constraints:
  fonts: ["IBM Plex Serif (display)", "Inter (body)", "JetBrains Mono (code)"]
  accent_color: "#7C5CFF"      # 단 하나
  forbid_colors: ["purple gradient", "blue→purple gradient"]
  border_radius: "4px (default), never > 12px"
  shadows: "subtle 1px borders, NOT shadow-lg"
  imagery: "duotone illustrations OR real screenshots, NEVER stock photos with people pointing at laptops"
motion:
  default_duration_ms: 150
  easing: "cubic-bezier(0.2, 0, 0, 1)"
  rule: "motion conveys causality, never decoration"
```

이 파일이 SKILL.md의 reference 자료로 들어가면, Claude가 매 디자인 작업 시 항상 이 제약을 먼저 본다. **15턴 회귀 문제가 즉시 사라진다.**

### 16.3 컬러 — 60/30/10과 단일 액센트

#### 60/30/10 법칙
- 60% — primary background/surface (보통 white/near-white 또는 deep neutral)
- 30% — secondary surface (subtle tinted neutral)
- 10% — accent (단 하나)

#### 보라색 회피
> 보라색이 나쁜 색이라서가 아니다. **AI 빌더 학습 데이터에 너무 많아서**, 보라색을 쓰는 순간 카테고리 매칭이 일어난다.

대안 액센트 추천:
- 차분한 인디고 `#3D5AFE`
- 따뜻한 테라코타 `#C75D45`
- 짙은 올리브 `#5C6B3F`
- 깊은 머스타드 `#B8852C`
- 차가운 청록 `#1F8B7E`

흰색·검정·회색 외에는 **단 하나의 액센트만**. 두 번째 색을 추가하는 순간 디자인이 평균으로 무너진다. CTA·링크·강조 요소 모두 같은 액센트를 쓴다 — 그래서 "강조"가 진짜로 시선을 끈다.

#### 그라디언트
거의 항상 빼라. 굳이 쓴다면:
- 같은 색의 명도 그라디언트만 (예: 액센트 → 액센트의 어두운 톤).
- 두 색 그라디언트는 `mix-blend-mode: multiply` 같은 특수 케이스로만.
- **다중 색 그라디언트는 절대 금지.**

#### 다크모드
별도의 톤·채도를 쓴다. 단순히 색을 invert하지 마라. 액센트는 다크에서 한 단계 더 밝게(채도 보존, 명도 +10%).

### 16.4 타이포그래피 — 페어링과 대비

흔한 AI 디자인의 타이포 약점:
- 한 폰트만 쓴다 (Inter).
- 모든 텍스트가 같은 weight, 같은 색.
- 헤딩과 바디 사이즈 차이가 너무 작다.
- 줄높이가 1.5로 어디든 똑같다.

#### 추천 페어링

| 용도 | 권장 |
|---|---|
| 에디토리얼/신뢰 | IBM Plex Serif (h1) + Inter (body) + JetBrains Mono (caption/code) |
| 제품/엔지니어링 | Geist (display) + Geist Mono (label) + 본문은 그대로 Geist |
| 따뜻함/브랜드 | Fraunces (display, italic 큰 표제) + Söhne 또는 Manrope (body) |
| 미니멀/스칸디 | Söhne / Founders Grotesk (전부) — but 굵기·기울기 대비 강하게 |

핵심 룰:
- **3종을 넘지 마라.** 표제 / 본문 / 모노. 끝.
- **x-height 가 비슷한 페어링** 을 골라라(IBM Plex 시리즈, Source 시리즈, Geist 시리즈는 가족이라 안전).
- **굵기 대비를 크게**: h1은 600~700, body는 400. 중간은 거의 안 쓴다.
- **대문자/스몰캡스**: 라벨에만, body에 쓰지 마라.

#### 사이즈 스케일
- 1.250 (Major Third) — 차분한 에디토리얼.
- 1.333 (Perfect Fourth) — 균형.
- 1.500 (Perfect Fifth) — 강한 위계.

CSS 변수로:
```css
:root {
  --step--2: 0.694rem;
  --step--1: 0.833rem;
  --step-0:  1.000rem;
  --step-1:  1.200rem;
  --step-2:  1.440rem;
  --step-3:  1.728rem;
  --step-4:  2.074rem;
  --step-5:  2.488rem;
  --step-6:  2.986rem;
}
```
fluid를 원하면 `clamp()` 로:
```css
--step-6: clamp(2rem, 1.5rem + 2.5vw, 2.986rem);
```

#### 줄높이
- 본문 1.55~1.65 (긴 글) / 1.45~1.5 (UI)
- 헤딩 1.05~1.2 (큰 헤딩일수록 줄임)
- 코드/라벨 1.4~1.5

#### 자간
- 큰 헤딩에 살짝 negative tracking (`-0.02em`).
- 라벨/스몰캡스에 positive (`+0.06em`).
- 본문은 그냥 0.

### 16.5 스페이싱 & 그리드 — 8pt + 비대칭

#### 8pt 그리드
모든 간격·패딩·마진은 4 또는 8의 배수. CSS 변수로 박아둬라:
```css
:root {
  --s-1:  4px;
  --s-2:  8px;
  --s-3:  12px;
  --s-4:  16px;
  --s-5:  24px;
  --s-6:  32px;
  --s-7:  48px;
  --s-8:  64px;
  --s-9:  96px;
  --s-10: 128px;
}
```
Tailwind 기본 스케일도 같은 철학. 임의 값(`p-[13px]`)은 금지.

#### Internal ≤ External 룰
요소 안쪽 padding 보다 요소 사이 margin/gap 이 크거나 같아야 그룹이 시각적으로 뭉친다.
- 카드 내부 padding 24px → 카드 사이 gap ≥ 24px.
- 어기면 카드들이 한 덩어리로 들러붙어 보인다.

#### 비대칭의 힘
모든 게 `text-center`/대칭이면 즉시 AI 룩이다. 의식적으로 비대칭을 넣어라:
- 영웅 섹션: 좌측 텍스트(2/3) + 우측 비주얼(1/3).
- 큰 인용은 본문 그리드 밖으로 부분 break.
- 사이드 마진을 의도적으로 비균등 (왼쪽 마진 96px, 오른쪽 마진 64px).

#### 큰 호흡
AI 디자인의 큰 약점은 **호흡 부족**이다. 섹션 사이 vertical spacing을 의도적으로 크게 — 96~160px. "넓다"는 인상이 즉시 전문가 느낌을 만든다.

### 16.6 레이아웃 — 흔한 AI 패턴 회피

피해야 할 슬롯들:
- ❌ Hero(중앙) → 3-card features → testimonials → pricing → CTA
- ❌ 모든 섹션이 `max-w-7xl mx-auto`
- ❌ 좌측 사이드바 + 카드 그리드의 SaaS 대시보드 클리셰

대안:
- ✅ **Editorial column** — 본문 60~75ch 폭의 단일 컬럼, 중간중간 큰 figure로 break.
- ✅ **2-column asymmetric** — 좌측 narrative, 우측 sticky figure.
- ✅ **Bento grid** — 다양한 비율의 박스 (단, 박스 안 콘텐츠도 다양해야 진짜 bento. 3개 같은 카드 + 1개 큰 카드는 가짜).
- ✅ **Magazine feature** — 큰 헤드라인, dropcap, 좌측 메타데이터(저자/날짜/읽는 시간).
- ✅ **Hero as text only** — 이미지/일러스트 없이 잘 짜인 타이포만.

### 16.7 비주얼 디테일

#### 보더 vs 그림자
AI 디자인은 `shadow-lg`/`shadow-xl` 을 남발한다. 대안:
- 1px hairline border (`hsl(0 0% 90%)`).
- 미세한 inset shadow (`inset 0 0 0 1px ...`).
- 박스 자체보다 **박스 *안* 의 콘텐츠 위계** 로 분리.

#### Border-radius
- 0px (브루탈리즘/에디토리얼)
- 4px (기본)
- 6~8px (부드러움)
- 12px+ 거의 안 씀
- `rounded-full` 은 아바타·아이콘·뱃지 한정

#### 아이콘
- 한 라이브러리 한 굵기. Lucide만 쓰면 즉시 AI 티.
- **Phosphor (Duotone), Tabler, Iconoir, Heroicons, Material Symbols (variable)** 중 하나를 골라라.
- 아이콘 비주얼 메인이 되는 디자인을 피해라 — 텍스트가 메인.

#### 이미지
- **사람이 노트북 가리키는 스톡 사진 절대 금지.**
- 듀오톤 처리 사진(액센트 톤으로).
- 실제 제품 스크린샷 + 살짝 큰 그림자 + 약간 비스듬히 (15~25도 perspective) 보다 정직한 정면.
- 일러스트는 한 사람이 그린 듯한 일관된 스타일만.

#### 모션
- duration 100~200ms.
- easing: `cubic-bezier(0.2, 0, 0, 1)` (Material 표준) 또는 `ease-out`.
- **인과를 표현할 때만** — 클릭 → 변화. 등장 애니메이션 (fade-in-up) 은 거의 항상 빼라.
- prefers-reduced-motion 항상 존중.

### 16.8 카피라이팅 — AI 티 나는 말 회피

다음 표현은 즉시 AI 티가 난다.

| AI 티 | 대신 |
|---|---|
| "supercharge your workflow" | "save 18 minutes per PR review" |
| "AI-powered" | "uses GPT-4 / Claude / Llama-3" (구체) 또는 그냥 빼기 |
| "revolutionize" | "we made X 3x faster" |
| "unleash your potential" | (그냥 무엇을 하는지) |
| "in just one click" | "one click" |
| "seamlessly integrate" | "works with GitHub, Slack, Linear" |
| "🚀 / ⚡ / 🎯" 가 헤더에 | 빼라. 본문 안 1~2개는 OK |
| 부사 도배 | 동사로 |

룰:
- **숫자가 있으면 숫자.** "Fast" 보다 "ships in 90s".
- **고유명사가 있으면 고유명사.** "Integrates with tools" 보다 "Connects Slack, Linear, Github".
- **"우리"라고 말해도 된다.** 일인칭 복수가 인간미를 만든다.
- **2인칭 너무 많이는 빼라.** "Your perfect..." 는 카피라이팅 슬롭 신호.

### 16.9 컴포넌트 라이브러리 — shadcn 너머

shadcn/ui 자체는 좋다. 문제는 **defaults 그대로** 쓰는 것이다. 탈출 전략 셋:

**A. shadcn/ui 깊게 커스텀** — `components.json` 의 `baseColor`, `radius`, `cssVars` 를 첫날부터 자기 디자인 토큰으로 갈고, 모든 컴포넌트의 1줄 클래스를 자기 스타일로 덮는다. 95%의 사람들은 이걸 안 하는 게 문제일 뿐, 잘 하면 흔적이 안 남는다.

**B. shadcn/ui 외 라이브러리** — DaisyUI(63 컴포넌트, theme-based), Headless UI(완전 unstyled), Park UI, Radix UI(low-level), Aceternity UI(애니메이션 강함), Magic UI(framer-motion 마이크로인터랙션), Mantine, Park UI.

**C. 직접 짜기** — 5~10개 핵심 컴포넌트(Button, Input, Card, Dialog, Tabs, Toast)는 직접 만들고 자기 토큰에 묶는다. 시간은 1~2일 추가지만 디자인이 즉시 자기 것이 된다.

권장: **A + C** — shadcn 베이스 + 핵심은 직접.

### 16.10 레퍼런스 주입 워크플로

> 2026년의 결정적 변화: **"더 예쁘게 해줘" 대신, 스크린샷을 붙여 "이 박스의 정렬을 이 레퍼런스처럼 맞춰줘"** 로 5배 빠르게 수렴한다.

레퍼런스 워크플로:
1. **수집** — 좋아하는 사이트 30~50개 스크린샷을 한 폴더에. Linear, Vercel, Stripe, Apple, Notion, Frame.io, Mercury, Plain, Granola, Cal.com, …
2. **분류** — 헤더 / 영웅 / 피처 / 가격 / 푸터별 폴더.
3. **주석 달기** — 각 스크린샷 옆에 `notes.md`: "왜 이게 좋은가" 한 줄.
4. **첫 컨텍스트에 주입** — `.claude/skills/web-design/references/` 안에 두고, SKILL.md가 "디자인 작업 시 이 폴더의 이미지들을 먼저 둘러봐라" 라고 지시.
5. **진단형 프롬프트** — "여기 있는 5개 사이트가 공통으로 잘하는 것 3가지를 추출해서 그 3가지를 이 프로젝트에 적용해줘".

#### 한 발 더 — 스크린샷 진단 루프
Playwright/Puppeteer MCP로 본인 사이트의 스크린샷을 찍고, 레퍼런스와 함께 보여주며 "이 두 이미지의 차이를 좁혀라"라고 시킨다. 이게 가장 강력한 디자인 정정 루프다.

### 16.11 Web Design SKILL.md — 카피-페이스트 템플릿

`.claude/skills/web-design/SKILL.md`:

```markdown
---
name: web-design-anti-ai
description: |
  Use this skill whenever generating any HTML, CSS, Tailwind, React, Vue, or
  Svelte that will produce visible UI for a real user — landing pages, marketing
  sites, dashboards, mockups, components. Especially trigger when the user says
  "looks AI-generated", "make it less generic", "vibe coding", or shows
  dissatisfaction with a previous design. Do NOT trigger for purely backend or
  CLI work.
---

# Web Design — Anti-AI Look

## Hard rules (never break)

1. Read references/identity.yaml BEFORE writing code.
2. Use exactly ONE accent color from identity.yaml. No new colors mid-project.
3. Use ONLY the fonts in identity.yaml. No "let me suggest a Google Font...".
4. NEVER use:
   - purple-to-blue gradients
   - emoji headers (🚀 ⚡ 🎯)
   - shadow-lg/xl on cards
   - text-center hero with 3-card grid below
   - "AI-powered", "supercharge", "revolutionize", "unleash" copy
   - stock photos of people pointing at laptops
5. ALWAYS use:
   - 8pt spacing scale (variables --s-1..--s-10 from rules.md)
   - 1px hairline borders OR subtle inset shadows, not box-shadows
   - Modular type scale (1.250–1.500), see rules.md
   - prefers-reduced-motion guards on every animation
6. After generating, run: `python .claude/skills/web-design/scripts/critique.py <file>`
   and fix anything it flags.

## Decision flow

When asked to design or generate UI:

1. Did the user supply a Design Identity? If not, use AskUserQuestion to get:
   - Audience in one sentence
   - Three mood words (and three they want to AVOID)
   - Accent color (or "you decide" + reason)
   - Two reference URLs they like
2. Save answers into references/identity.yaml.
3. Open references/library/ and skim 5 screenshots that match the mood words.
4. Read rules.md for the active section (color/type/spacing/layout).
5. Draft. Self-critique using checklist.md. Iterate before showing.
6. After showing: take a Playwright screenshot, compare to one reference,
   list 3 differences and propose fixes.

## Bundled files (read on demand)

- references/identity.yaml — current project identity
- references/library/      — 30–50 screenshots of good non-AI sites
- rules.md                 — concrete CSS rules (color, type, spacing, layout)
- checklist.md             — 12-point self-review
- copy.md                  — anti-AI copywriting rules
- scripts/critique.py      — automated lint over generated HTML
- scripts/screenshot.sh    — Playwright screenshot helper

## When the user pushes back ("make it more dynamic")

DO NOT respond by adding gradients, emojis, animations, or extra colors.
Instead:
- Ask "more dynamic in what way? typography weight? layout asymmetry? motion on interaction?"
- Offer 3 options framed as trade-offs.
- After they choose, change ONE axis at a time. Show before/after.
```

`rules.md`, `checklist.md`, `copy.md`, `scripts/critique.py` 의 내용은 §17 통합 스타터 킷에 그대로 들어 있다.

### 16.12 자체 검증 체크리스트 (12-point)

`checklist.md`:

```markdown
Before declaring a design done, verify each:

1. [ ] Page works at 360px width (mobile) — no horizontal scroll.
2. [ ] Tap targets ≥ 44×44px on mobile.
3. [ ] All text-on-background contrast ≥ 4.5:1 (large text 3:1).
4. [ ] At most ONE accent color used in the page.
5. [ ] At most THREE typefaces (display / body / mono).
6. [ ] No purple-to-X gradient. No emoji in headers.
7. [ ] Spacing only uses --s-* tokens. No arbitrary px values.
8. [ ] No `shadow-lg` or `shadow-xl` on cards.
9. [ ] No "supercharge / AI-powered / revolutionize" in copy.
10. [ ] At least one intentional asymmetry in layout.
11. [ ] All animations honor prefers-reduced-motion.
12. [ ] Compared the result side-by-side to one reference screenshot.
```

12개 모두 통과 안 하면 done 선언 금지. Hook으로 강제 가능 (PostToolUse).

### 16.13 프롬프트 패턴 모음

같은 시작 멘트라도 결과가 달라지는 핵심 프롬프트 패턴.

#### 좋은 시작 프롬프트
```
Design the landing page for {project}.

Identity:
- Audience: {one sentence}
- Mood: {three words}, contrast to: {three words to avoid}
- Accent: {hex}, 60/30/10 rule strictly
- Fonts: {display}, {body}, {mono}

Constraints:
- No gradients except single-hue accent darkening.
- No shadows; use 1px borders.
- 8pt spacing scale only.
- One asymmetric break per major section.
- Hero is text-only, max 60ch wide, with one secondary line.

References (look at these BEFORE coding):
- {url 1}
- {url 2}
- {local screenshot 1}
- {local screenshot 2}

Output:
- Single self-contained HTML file with <style> using CSS vars from rules.md.
- After generating, take a Playwright screenshot and compare against reference 1.
- List 3 specific differences and propose pixel-level fixes.
```

#### 정정 프롬프트 (이미 결과가 있을 때)
```
Here's the current screenshot: {file}.
Here's reference: {file}.

Look at both. Identify exactly 3 places where mine looks more generic / AI-like.
For each, propose a specific change (token name + value, or class name + replacement).
Do NOT change anything else.
```

#### 카피 정정 프롬프트
```
Rewrite all copy on this page to remove AI-marketing tone.
Apply rules from .claude/skills/web-design/copy.md.
For each replacement, show: BEFORE → AFTER, in a table.
```

---

## 17. 통합 스타터 킷 — 한 번에 복사

이 섹션은 **즉시 사용 가능한 모든 파일** 을 한 곳에 모은 것이다. 새 프로젝트에서 다음 디렉토리 구조를 만들고, 각 파일을 그대로 붙여넣으면 시작 셋업 끝.

### 17.1 디렉토리

```
your-project/
├── CLAUDE.md
├── .claude/
│   ├── settings.json
│   ├── agents/
│   │   ├── code-reviewer.md
│   │   └── design-critic.md
│   ├── commands/
│   │   ├── review.md
│   │   ├── design-critique.md
│   │   └── progress.md
│   ├── hooks/
│   │   ├── post-edit-lint.sh
│   │   ├── block-dangerous-bash.sh
│   │   └── save-progress.sh
│   └── skills/
│       └── web-design/
│           ├── SKILL.md          # §16.11 그대로
│           ├── rules.md
│           ├── checklist.md      # §16.12 그대로
│           ├── copy.md
│           ├── references/
│           │   ├── identity.yaml # §16.2 그대로
│           │   └── library/      # 사용자가 채울 폴더
│           └── scripts/
│               ├── critique.py
│               └── screenshot.sh
├── claude-progress.txt
├── feature_list.json             # 장시간 프로젝트만
└── init.sh
```

### 17.2 `CLAUDE.md` (시작 템플릿)

```markdown
# {Project Name}

## Stack
- (예: Next.js 15 / TypeScript strict / Tailwind v4 / Postgres + Prisma)

## Commands
- dev:    pnpm dev
- test:   pnpm test
- e2e:    pnpm e2e
- lint:   pnpm lint && pnpm typecheck

## Workflow
- After every code change, run `pnpm lint && pnpm typecheck` before reporting done.
- For UI work, follow .claude/skills/web-design/SKILL.md without exception.
- After UI changes, take a Playwright screenshot and compare to one reference.
- End every session by appending one paragraph to claude-progress.txt.

## Hard rules
- Don't add new dependencies without writing a 1-line rationale in PR body.
- Never use `--force` git commands. Use `--force-with-lease`.
- No `any` in TypeScript. If unavoidable, add `// TODO: type` and reason.

## Project structure
- Routes:       src/app/**
- UI:           src/components/**
- Server:       src/server/**
- Skills:       .claude/skills/**
- Memory:       .claude/memory/**
```

### 17.3 `.claude/settings.json`

```json
{
  "permissions": {
    "allow": [
      "Read(./**)",
      "Write(./src/**)",
      "Edit(./src/**)",
      "Bash(pnpm *)",
      "Bash(git status)",
      "Bash(git diff*)",
      "Bash(git log*)",
      "Bash(git add *)",
      "Bash(git commit *)"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Bash(sudo *)",
      "Bash(curl *)",
      "Write(./.env*)",
      "Edit(./.env*)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": ".claude/hooks/block-dangerous-bash.sh" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": ".claude/hooks/post-edit-lint.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": ".claude/hooks/save-progress.sh" }
        ]
      }
    ]
  }
}
```

### 17.4 Hooks 스크립트

`.claude/hooks/block-dangerous-bash.sh`:
```bash
#!/usr/bin/env bash
# PreToolUse hook for Bash. Reads JSON from stdin, decides to allow/deny.
input="$(cat)"
cmd="$(echo "$input" | python3 -c 'import sys,json; print(json.load(sys.stdin)["tool_input"].get("command",""))')"

deny_patterns=(
  'rm -rf /'
  'rm -rf ~'
  ':(){ :|:& };:'
  'mkfs'
  'dd if=.* of=/dev/'
  'sudo rm'
  'chmod -R 777 /'
)

for p in "${deny_patterns[@]}"; do
  if echo "$cmd" | grep -Eq "$p"; then
    echo "DENIED: dangerous pattern matched: $p" >&2
    exit 2
  fi
done
exit 0
```

`.claude/hooks/post-edit-lint.sh`:
```bash
#!/usr/bin/env bash
# PostToolUse: feed lint errors back to Claude
if pnpm --silent lint 2>&1 | tee /tmp/lint.out | grep -q "error"; then
  echo "Lint failed:" >&2
  cat /tmp/lint.out >&2
  exit 2
fi
exit 0
```

`.claude/hooks/save-progress.sh`:
```bash
#!/usr/bin/env bash
# Stop hook: append a session summary line to claude-progress.txt
ts="$(date -Iseconds)"
files_changed="$(git diff --name-only 2>/dev/null | wc -l | xargs)"
echo "## Session $ts (files changed: $files_changed)" >> claude-progress.txt
git diff --stat >> claude-progress.txt 2>/dev/null
echo "" >> claude-progress.txt
exit 0
```

세 스크립트 모두 `chmod +x` 해두기.

### 17.5 Subagent 예시

`.claude/agents/code-reviewer.md`:
```markdown
---
name: code-reviewer
description: >
  Reviews code diffs for security, style, and bug risk. Trigger when the user
  asks for review, second opinion, or before merging. Output a punch list under
  200 words with file:line cites.
tools: Read, Grep, Glob, Bash
model: sonnet
---

You are a senior reviewer. Read the diff and return:

## Critical
- file:line — concrete bug/security issue and 1-line fix.

## Style
- file:line — concrete style issue.

## Suggestions
- file:line — optional improvements.

Total under 200 words. Don't repeat the diff.
```

`.claude/agents/design-critic.md`:
```markdown
---
name: design-critic
description: >
  Compares the current page screenshot to one reference and lists exactly 3
  generic-looking weaknesses with concrete CSS-token-level fixes. Trigger after
  UI changes or when user says "make it less AI-looking".
tools: Read, Bash
model: sonnet
---

Given <screenshot_current> and <screenshot_reference>:

1. Find exactly 3 places where current looks more generic than reference.
2. For each, output:
   - WHAT (1 sentence)
   - WHERE (selector or section)
   - FIX (CSS variable change, class swap, or layout move)

Cite identity.yaml tokens by name when proposing changes. Under 250 words.
```

### 17.6 Slash Commands

`.claude/commands/design-critique.md`:
```markdown
---
description: Critique current UI against a reference screenshot
---

Take a Playwright screenshot of the current page (use scripts/screenshot.sh).
Then invoke the design-critic subagent with:
  - current screenshot path
  - one reference from .claude/skills/web-design/references/library/
Apply the proposed fixes one at a time, taking a new screenshot between each.
```

`.claude/commands/progress.md`:
```markdown
---
description: Print last 5 sessions from claude-progress.txt
---
Read claude-progress.txt and print the last 5 session entries.
Then summarize what's done vs what's open in 5 bullets.
```

### 17.7 Web design `rules.md`

```markdown
# Web Design Rules — Concrete CSS Tokens

## Color
- 60% surface: var(--c-bg)
- 30% subtle:  var(--c-bg-muted)
- 10% accent:  var(--c-accent) — single hex, from identity.yaml
- Borders: var(--c-line)
- Text: var(--c-fg) primary, var(--c-fg-muted) secondary

```css
:root {
  --c-bg:        #FAFAF7;
  --c-bg-muted:  #F0EFE9;
  --c-line:      #E2E0D6;
  --c-fg:        #1A1A1A;
  --c-fg-muted:  #5C5C57;
  --c-accent:    #C75D45;   /* terracotta — replace per identity.yaml */
}
@media (prefers-color-scheme: dark) {
  :root {
    --c-bg:        #16160E;
    --c-bg-muted:  #1F1F18;
    --c-line:      #2E2E26;
    --c-fg:        #F2F0E8;
    --c-fg-muted:  #A6A39A;
    --c-accent:    #E07A60;
  }
}
```

## Spacing (8pt scale)

```css
:root {
  --s-1: 4px;  --s-2: 8px;  --s-3: 12px; --s-4: 16px;
  --s-5: 24px; --s-6: 32px; --s-7: 48px; --s-8: 64px;
  --s-9: 96px; --s-10: 128px;
}
```
- Internal padding ≤ External margin.
- Section vertical spacing min 96px on desktop (var(--s-9)).

## Type scale (Major Third 1.250)

```css
:root {
  --t--1: 0.833rem;
  --t-0:  1.000rem;
  --t-1:  1.250rem;
  --t-2:  1.563rem;
  --t-3:  1.953rem;
  --t-4:  2.441rem;
  --t-5:  3.052rem;
  --t-6:  3.815rem;
}
```
- h1: var(--t-5) or fluid clamp.
- body: var(--t-0), 1.6 line-height.

## Borders & radius
- Default border: 1px solid var(--c-line).
- Radius scale: 0, 4, 6, 8. Never above 12.
- No box-shadow. Use inset hairline if depth needed:
  `box-shadow: inset 0 0 0 1px var(--c-line);`

## Motion
- Duration: 150ms default, 300ms for full-page transitions.
- Easing: cubic-bezier(0.2, 0, 0, 1).
- Always wrap in `@media (prefers-reduced-motion: no-preference)`.
```

### 17.8 Web design `copy.md`

```markdown
# Anti-AI Copywriting Rules

## Replace these phrases on sight

| Banned | Replacement strategy |
|---|---|
| supercharge | a concrete number ("ships in 90s") |
| AI-powered | name the model OR drop the phrase |
| revolutionize | "we reduced X by Y" |
| unleash, unlock | drop |
| seamlessly integrate | name the integrations |
| in just one click | "one click" |
| your perfect... | drop "perfect" |
| game-changing | a concrete claim |
| cutting-edge, state-of-the-art | a specific capability |
| effortless, intuitive | show, don't tell |
| 🚀 ⚡ 🎯 in headers | remove |

## Voice rules

- First-person plural ("we") is welcome. It's human.
- Specific verbs > abstract nouns. "Ship" > "deliver solutions".
- Numbers and proper nouns wherever possible.
- Sentences mostly under 20 words.
- One adjective per noun, max.
- No exclamation marks except in error/empty states (and even then, sparingly).

## Headline framework

A good headline answers ONE of:
1. What is it? (Mercury: "Banking for ambitious companies")
2. Who is it for? (Linear: "Linear is the issue tracker you'll enjoy using")
3. What changes? (Notion: "The AI workspace that works for you")

Avoid headlines that answer "How great is it?".
```

### 17.9 Critique 스크립트

`.claude/skills/web-design/scripts/critique.py`:

```python
#!/usr/bin/env python3
"""
Lints a generated HTML/CSS file for common AI-generated design markers.
Exits non-zero with a list of issues. Read .claude/skills/web-design/rules.md
to fix them.
"""
import sys, re, pathlib

if len(sys.argv) < 2:
    print("usage: critique.py <file.html>", file=sys.stderr); sys.exit(1)

path = pathlib.Path(sys.argv[1])
src = path.read_text()
issues = []

# Banned color patterns
banned_color_patterns = [
    (r'from-purple-\d+\s+to-(blue|pink|indigo)-\d+',
     'purple-to-X gradient — use single-hue accent or remove'),
    (r'bg-gradient-to-(br|bl|r)\s+from-(blue|indigo|pink|fuchsia)-',
     'multi-hue gradient — replace with solid var(--c-accent) or single-hue'),
]
for pat, msg in banned_color_patterns:
    for m in re.finditer(pat, src):
        issues.append(f"COLOR: {msg} (matched: {m.group(0)})")

# Banned shadows
if re.search(r'\bshadow-(lg|xl|2xl)\b', src):
    issues.append("SHADOW: shadow-lg/xl/2xl found — use 1px hairline border or inset shadow")

# Banned copy phrases
banned_copy = [
    "supercharge", "AI-powered", "revolutionize", "unleash",
    "seamlessly integrate", "game-changing", "cutting-edge",
    "state-of-the-art", "in just one click",
]
for phrase in banned_copy:
    if re.search(phrase, src, re.IGNORECASE):
        issues.append(f"COPY: '{phrase}' found — see copy.md for replacements")

# Emoji in <h1>/<h2>
for m in re.finditer(r'<(h1|h2)[^>]*>(.*?)</\1>', src, re.DOTALL):
    if re.search(r'[\U0001F300-\U0001FAFF]', m.group(2)):
        issues.append(f"EMOJI: emoji in {m.group(1)} — remove from headers")

# 3-card pattern (very rough)
if src.count('grid-cols-3') >= 1 and src.count('feature') >= 3:
    issues.append("LAYOUT: 3-card feature grid detected — consider asymmetric bento or editorial column")

# text-center hero
if re.search(r'<section[^>]*hero[^>]*>.*?text-center', src, re.DOTALL | re.IGNORECASE):
    issues.append("LAYOUT: text-center hero — try asymmetric 2/3 + 1/3 split")

# Arbitrary px values (Tailwind arbitrary)
arbs = re.findall(r'\[(\d+px)\]', src)
if arbs:
    issues.append(f"SPACING: arbitrary px values used: {set(arbs)} — use --s-* tokens")

if not issues:
    print("Clean.")
    sys.exit(0)

print(f"\n❌ {len(issues)} issue(s):\n")
for i, x in enumerate(issues, 1):
    print(f"  {i}. {x}")
print("\nFix above before declaring the design done.")
sys.exit(2)
```

### 17.10 Screenshot helper

`.claude/skills/web-design/scripts/screenshot.sh`:

```bash
#!/usr/bin/env bash
# usage: screenshot.sh <url> <out.png>
url="${1:-http://localhost:3000}"
out="${2:-./screenshot.png}"

npx --yes playwright install chromium >/dev/null 2>&1
node -e "
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage();
  await p.setViewportSize({ width: 1440, height: 900 });
  await p.goto('$url', { waitUntil: 'networkidle' });
  await p.screenshot({ path: '$out', fullPage: true });
  await b.close();
  console.log('saved $out');
})();
"
```

### 17.11 `init.sh` (장시간 프로젝트용)

```bash
#!/usr/bin/env bash
# Restart dev server. Used at start of every coding agent session.
set -e
echo "[init] killing old dev server"
pkill -f "next dev" || true
echo "[init] starting dev server in background"
nohup pnpm dev > /tmp/dev.log 2>&1 &
sleep 5
curl -sf http://localhost:3000 > /dev/null && echo "[init] up" || echo "[init] not up yet"
```

### 17.12 `feature_list.json` 시작 (장시간 프로젝트)

```json
[
  {
    "category": "infra",
    "description": "Project boots with `pnpm dev`",
    "steps": ["pnpm install", "pnpm dev", "verify http://localhost:3000 returns 200"],
    "passes": false
  },
  {
    "category": "infra",
    "description": "CI runs lint, typecheck, test",
    "steps": ["push branch", "verify GitHub Actions pass"],
    "passes": false
  }
]
```

---

## 18. 다른 컴퓨터에서 0부터 시작하는 법

이 가이드를 새 컴퓨터에 가져와 처음부터 셋업하는 절차.

### 18.1 사전 설치

```bash
# Node 18+
node -v

# Python 3.10+
python3 --version

# Claude Code CLI (Mac/Linux)
curl -fsSL https://claude.ai/install.sh | bash
# Windows: https://docs.claude.com/en/docs/claude-code/install

# 또는 SDK만
pip install claude-agent-sdk
# 또는
npm install -g @anthropic-ai/claude-agent-sdk

# API key
export ANTHROPIC_API_KEY="sk-ant-..."   # ~/.zshrc 또는 ~/.bashrc 에
```

### 18.2 새 프로젝트 부트스트랩

```bash
mkdir my-new-project && cd my-new-project
git init
mkdir -p .claude/{agents,commands,hooks,skills,memory}
mkdir -p .claude/skills/web-design/{references/library,scripts}
chmod +x .claude/hooks/*.sh   # 만든 후
touch CLAUDE.md claude-progress.txt
```

그 다음 §17의 각 파일을 그대로 복사한다.

### 18.3 첫 Claude 세션

```bash
claude
```

또는 Cowork/Desktop 앱에서 폴더를 마운트한 뒤 다음 한 줄을 던진다.

```
이 디렉토리의 CLAUDE.md / .claude/skills / .claude/agents / .claude/commands 를 모두 읽어서
프로젝트의 컨벤션을 이해해. 그리고 이 가이드 파일(claude-harness-master-guide.md)을
보조 참조 자료로 둬. 이 셋업이 빠진 부분이 있다면 AskUserQuestion으로 3개 이내 질문하고,
없다면 첫 작업을 시작할 준비됐다고 알려줘.
```

### 18.4 장시간 프로젝트라면

추가로:
```bash
touch feature_list.json init.sh
chmod +x init.sh
```
그리고 첫 세션에 "이 프로젝트는 long-running 모드. 명세를 확장한 feature_list.json을 작성하고 init.sh를 채우는 initializer 작업을 먼저 해줘" 라고 명시.

### 18.5 권한 워크플로 권장

처음 하루 이틀은 `default` 권한 모드. 어느 도구를 신뢰할 수 있는지 보면서:
- 안전한 도구 (Read, Grep, Glob, 일부 Bash 명령) → `permissions.allow` 에 추가.
- 위험한 도구 (rm, sudo, .env 편집) → `permissions.deny` 에 추가.
- 충분히 신뢰가 쌓이면 `acceptEdits` 모드로.

---

## 19. 빠른 참고 — 1쪽 요약

> 다른 컴퓨터에서 이 한 페이지만 봐도 80% 갖춰진다.

```
1. CLAUDE.md = 헌법. 짧게. 보편 룰만. 강한 어휘 금지.
2. 도구 = 계약(에이전트용). 자기 설명적 이름, concise/detailed 토글, 토큰 캡, 의미 있는 응답.
3. 컨텍스트 = 한정 자원. just-in-time retrieval. compaction / notes / sub-agents.
4. SKILL.md = 점진적 펼침. frontmatter→본문→번들 파일. description이 트리거.
5. Subagent = 컨텍스트 분리. 출력 형식 강제. 최소 권한.
6. Hooks = 결정론적 가드. PreToolUse가 가장 강력. PostToolUse는 피드백.
7. MCP = 외부 통합 표준. Tools/Resources/Prompts. 같은 5원칙 적용.
8. 장시간 = Initializer + Coding. feature_list.json + claude-progress.txt + init.sh + E2E 검증.
9. Agent SDK = pip/npm 설치 → query() 한 함수. permission_mode 신중히.
10. 디자인 = Identity Anchor 먼저. 60/30/10. 단일 액센트. 8pt. 1px hairline. critique.py로 자동 린트.
```

---

## 부록 A — 출처 & 참고 자료

### A.1 Anthropic 1차 자료 (가장 권위 있는 출처)

**Engineering blog (가장 자주 인용)**
- [Effective harnesses for long-running agents (2025-11-26)](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) — initializer + coding 패턴, feature_list.json, e2e 검증.
- [Writing effective tools for AI agents — with agents (2025-09-11)](https://www.anthropic.com/engineering/writing-tools-for-agents) — 도구 5원칙, eval-driven 개발.
- [Effective context engineering for AI agents (2025-09-29)](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) — context rot, just-in-time, compaction/notes/sub-agents.
- [Equipping agents for the real world with Agent Skills (2025-10-16)](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills) — SKILL.md, progressive disclosure.
- [Building effective AI agents](https://www.anthropic.com/research/building-effective-agents) — 에이전트 vs 워크플로 정의.
- [Advanced tool use](https://www.anthropic.com/engineering/advanced-tool-use)

**Claude Code & SDK 공식 문서**
- [Best Practices for Claude Code](https://code.claude.com/docs/en/best-practices)
- [Hooks reference](https://code.claude.com/docs/en/hooks)
- [Hooks guide](https://code.claude.com/docs/en/hooks-guide)
- [Sub-agents](https://code.claude.com/docs/en/sub-agents)
- [Discover plugins](https://code.claude.com/docs/en/discover-plugins)
- [Agent SDK overview](https://platform.claude.com/docs/en/agent-sdk/overview)
- [Agent loop](https://platform.claude.com/docs/en/agent-sdk/agent-loop)
- [Agent SDK quickstart](https://platform.claude.com/docs/en/agent-sdk/quickstart)
- [Agent SDK Python reference](https://platform.claude.com/docs/en/agent-sdk/python)
- [Agent SDK TypeScript reference](https://platform.claude.com/docs/en/agent-sdk/typescript)
- [Streaming output](https://platform.claude.com/docs/en/agent-sdk/streaming-output)
- [Slash commands in the SDK](https://platform.claude.com/docs/en/agent-sdk/slash-commands)
- [Modifying system prompts](https://platform.claude.com/docs/en/agent-sdk/modifying-system-prompts)
- [Agent SDK hooks](https://platform.claude.com/docs/en/agent-sdk/hooks)
- [Agent Skills overview](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview)
- [Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- [Tool use overview](https://docs.claude.com/en/docs/agents-and-tools/tool-use/overview)
- [Implement tool use](https://platform.claude.com/docs/en/agents-and-tools/tool-use/implement-tool-use)
- [Parallel tool use](https://platform.claude.com/docs/en/agents-and-tools/tool-use/parallel-tool-use)
- [Programmatic tool calling](https://platform.claude.com/docs/en/agents-and-tools/tool-use/programmatic-tool-calling)
- [Build a tool-using agent (tutorial)](https://platform.claude.com/docs/en/agents-and-tools/tool-use/build-a-tool-using-agent)
- [Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)
- [Use XML tags](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/use-xml-tags)
- [Prompt engineering overview](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/overview)

**Claude blog & 발표**
- [Building agents with the Claude Agent SDK](https://claude.com/blog/building-agents-with-the-claude-agent-sdk)
- [Customize Claude Code with plugins](https://claude.com/blog/claude-code-plugins)
- [Best practices for prompt engineering](https://claude.com/blog/best-practices-for-prompt-engineering)
- [Introducing the Model Context Protocol](https://www.anthropic.com/news/model-context-protocol)

**MCP 공식**
- [MCP — Build a server](https://modelcontextprotocol.io/docs/develop/build-server)
- [MCP server reference repo](https://github.com/modelcontextprotocol/servers)
- [Local MCP servers on Claude Desktop](https://support.claude.com/en/articles/10949351-getting-started-with-local-mcp-servers-on-claude-desktop)

**Anthropic 공식 스킬 저장소**
- [anthropics/skills (skill-creator 등)](https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md)
- [Anthropic Skilljar — Introduction to Agent Skills](https://anthropic.skilljar.com/introduction-to-agent-skills)
- [Anthropic Skilljar — Introduction to MCP](https://anthropic.skilljar.com/introduction-to-model-context-protocol)

### A.2 커뮤니티 베스트 프랙티스

- [Writing a good CLAUDE.md — HumanLayer](https://www.humanlayer.dev/blog/writing-a-good-claude-md)
- [How Claude Code Builds a System Prompt — dbreunig](https://www.dbreunig.com/2026/04/04/how-claude-code-builds-a-system-prompt.html)
- [Claude Code system prompts repo (Piebald-AI)](https://github.com/Piebald-AI/claude-code-system-prompts)
- [How to Write a Good CLAUDE.md File — builder.io](https://www.builder.io/blog/claude-md-guide)
- [The Ideal Project Structure for Claude Code](https://sidsaladi.substack.com/p/the-ideal-project-structure-for-claude)
- [Claude Code in a Monorepo: The Complete Setup Guide](https://thepromptshelf.dev/blog/claude-code-monorepo-setup/)
- [How I use Claude Code (+ best tips) — Steve Sewell, builder.io](https://www.builder.io/blog/claude-code)
- [Claude Code Hooks Mastery (disler)](https://github.com/disler/claude-code-hooks-mastery)
- [Awesome Claude Code](https://github.com/hesreallyhim/awesome-claude-code)
- [Awesome Claude Skills](https://github.com/travisvn/awesome-claude-skills)
- [Claude Plugins Marketplace directory](https://claudemarketplaces.com/)
- [The Complete Guide to Building Agents with the Claude Agent SDK — nader.substack](https://nader.substack.com/p/the-complete-guide-to-building-agents)
- [Inside the Agent Harness: How Codex and Claude Code Actually Work — Jonathan Fulton](https://medium.com/jonathans-musings/inside-the-agent-harness-how-codex-and-claude-code-actually-work-63593e26c176)
- [Claude Code Subagents: The Complete Guide](https://medium.com/@sathishkraju/claude-code-subagents-the-complete-guide-to-ai-agent-delegation-d0a9aba419d0)

### A.3 디자인·웹 디자인

**AI-look 진단 & 회피**
- [Why Do Most AI-Generated Websites Look the Same? — Shuffle](https://shuffle.dev/blog/2026/01/why-do-most-ai-generated-websites-look-the-same/)
- [Building Premium AI-Built Websites: 2026 Design Guide — AIFire](https://www.aifire.co/p/building-premium-ai-built-websites-2026-design-guide)
- [Building a Site That Doesn't Look AI-Generated (Using AI) — Porter Intelligent](https://www.porterintelligent.com/blog/building-a-site-that-doesnt-look-ai-generated)
- [How to avoid AI-generated UIs that look the same (Ashok Naik)](https://www.linkedin.com/posts/ashok-naik-82513b111_how-to-break-the-ai-generated-ui-curse-your-activity-7361680462559272960-Yh_8)
- [Cooking with Constraints: A Designer's Framework for Better AI Prompts — Figma](https://www.figma.com/blog/designer-framework-for-better-ai-prompts/)
- [The Best (and Worst) Prompts for Web Design in AI Builders — CrazyEgg](https://www.crazyegg.com/blog/ai-web-design-prompts/)

**디자인 트렌드 (2026)**
- [Web Design Trends 2026 — Figma](https://www.figma.com/resource-library/web-design-trends/)
- [Web Design Trends 2026: The Definitive Guide — Line25](https://line25.com/articles/web-design-trends-2026/)
- [Typography Trends 2026 — DesignMonks](https://www.designmonks.co/blog/typography-trends-2026)
- [Neo Brutalism Web Design — Medium](https://medium.com/@designstudiouiux/neo-brutalism-web-design-what-it-is-why-it-works-and-when-to-use-it-f5d7932fa8ec)
- [Neubrutalism — Bejamas](https://bejamas.com/blog/neubrutalism-web-design-trend)

**디자인 시스템 & 토큰**
- [USWDS Design tokens](https://designsystem.digital.gov/design-tokens/)
- [USWDS System color tokens](https://designsystem.digital.gov/design-tokens/color/system-tokens/)
- [Design tokens explained — Contentful](https://www.contentful.com/blog/design-token-system/)
- [A Guide to Colors in Design Systems — Supercharge](https://supercharge.design/blog/a-guide-to-colors-in-design-systems)
- [Web design color theory — Penpot](https://penpot.app/blog/web-design-color-theory-how-to-build-brands-and-improve-ux-with-color/)

**타이포그래피**
- [Font pairing guide — Figma](https://www.figma.com/resource-library/font-pairings/)
- [The Dos and Don'ts of Pairing Typefaces — NN/g](https://www.nngroup.com/articles/pairing-typefaces/)
- [Font Pairing & Web Typography Guide 2026 — UDT](https://ultimatedesigntools.com/blog/font-pairing-guide/)
- [8 top font pairing examples — Webflow](https://webflow.com/blog/font-pairing)

**스페이싱·그리드**
- [Spacing best practices — Cieden](https://cieden.com/book/sub-atomic/spacing/spacing-best-practices)
- [The 8pt grid system — UX Planet](https://uxplanet.org/everything-you-should-know-about-8-point-grid-system-in-ux-design-b69cb945b18d)
- [8-Point Grid: Vertical Rhythm — Built to Adapt](https://medium.com/built-to-adapt/8-point-grid-vertical-rhythm-90d05ad95032)
- [Spacing, grids, and layouts — designsystems.com](https://www.designsystems.com/space-grids-and-layouts/)

**컴포넌트 라이브러리 (shadcn 너머)**
- [DaisyUI vs shadcn](https://daisyui.com/alternative/shadcn/)
- [Top Shadcn Alternatives — Shadcn Studio](https://shadcnstudio.com/blog/shadcn-alternatives)
- [Best React UI Component Libraries 2026 — Untitled UI](https://www.untitledui.com/blog/react-component-libraries)
- [The 10 Best Alternatives to shadcn — Subframe](https://www.subframe.com/tips/shadcn-alternatives)

**AI 빌더 비교 (v0/Lovable/Bolt 등)**
- [AI-Driven Prototyping: v0, Bolt, and Lovable Compared — Addy Osmani](https://addyo.substack.com/p/ai-driven-prototyping-v0-bolt-and)
- [V0 vs Bolt.new vs Lovable: Best AI App Builder 2026 — NxCode](https://www.nxcode.io/resources/news/v0-vs-bolt-vs-lovable-ai-app-builder-comparison-2025)
- [Design Systems ♡ Lovable, Bolt, V0 and Replit](https://www.designsystemscollective.com/design-systems-lovable-bolt-v0-and-replit-50a0a197bc35)

---

*문서 버전: 2026-04 / 작성: Claude (Cowork) for ka. 이 가이드는 Anthropic 1차 자료를 토대로 한 종합 정리이며, Anthropic 공식 문서와 최신 권고가 우선한다. 의심스러우면 부록 A의 Anthropic 링크를 1차로 참고하라.*
