# 🛠️ Claude Code 환경 재현 & 하네스 엔지니어링 가이드

> **이 문서 하나로 새 컴퓨터에 내 Claude Code 세팅을 재현**하고, 왜 그렇게 구성하는지(하네스 엔지니어링)까지 이해한다.
> 가장 빠른 길은 [§PART D — 클로드한테 시키기](#part-d--실행-가이드--클로드한테-시키기). 이 파일을 새 PC에 두고 프롬프트만 붙여넣으면 끝.
>
> **깊은 이론 레퍼런스**(같은 레포): `claude-harness-unified.md`(통합), `claude-harness-master-guide.md`(마스터), `claude-local-harness.md`(역할 하네스), `design_guide.md`, `prompt.md`. 이 문서는 그걸 **실전 재현용으로 압축·병합**한 것이다.

작성 갱신: 2026-07-08 / 원본 사용자 경로: `C:\Users\82102`
> ⚠️ 새 PC에선 사용자명이 다르다. 경로의 `82102`(=`C:\Users\<사용자명>`)를 본인 것으로 바꿔라. 확인: `echo $HOME` (bash) / `echo %USERPROFILE%` (cmd).

---

# PART A — 빠른 재현 (다른 컴퓨터에 그대로)

## A0. 사전 준비물

| 프로그램 | 확인 | 비고 |
|---|---|---|
| **Claude Code** | `claude --version` | 보통 `~/.local/bin/claude.exe`. `where claude`로 확인 |
| **Git Bash** | `bash --version` | 훅이 bash로 실행됨(윈도우 필수). Git for Windows 포함 |
| **Python 3** | `python --version` | 안전 훅·일부 유틸용 |
| **Node/npx** | `npx --version` | prettier 훅용(선택) |

> 함정 메모: 이 환경의 **훅 실행 bash엔 `jq`가 없다.** jq에 의존하는 훅은 조용히 스킵된다. 필요하면 `winget install jqlang.jq`.

## A1. 플러그인 5종 설치

```bash
# 1) 공식 마켓 + superpowers (개발 워크플로 스킬 14종)
claude plugin marketplace add anthropics/claude-plugins-official
claude plugin install superpowers@claude-plugins-official

# 2) andrej-karpathy-skills (LLM 코딩 실수 줄이는 가이드)
claude plugin marketplace add forrestchang/andrej-karpathy-skills
claude plugin install andrej-karpathy-skills@karpathy-skills

# 3) claude-video / watch (영상 보고 질문 답변)
claude plugin marketplace add bradautomates/claude-video
claude plugin install watch@claude-video

# 4) understand-anything (코드베이스 지식그래프)
claude plugin marketplace add Lum1104/Understand-Anything
claude plugin install understand-anything@understand-anything

# 5) humanize-korean (한글 AI 티 제거 윤문)
claude plugin marketplace add epoko77-ai/im-not-ai
claude plugin install humanize-korean@im-not-ai
```

적용: `/reload-plugins` 또는 claude 재시작 · 확인: `claude plugin list`

| 플러그인 | repo | 제공 |
|---|---|---|
| superpowers | anthropics/claude-plugins-official | brainstorming, TDD, systematic-debugging … 14종 |
| andrej-karpathy-skills | forrestchang/andrej-karpathy-skills | karpathy-guidelines |
| watch | bradautomates/claude-video | watch, remotion-best-practices |
| understand-anything | Lum1104/Understand-Anything | understand 계열 8종 |
| humanize-korean | epoko77-ai/im-not-ai | humanize-korean 스킬 + 에이전트 13종 |

## A2. 유저 `settings.json` (모델·권한·훅)

위치: `~/.claude/settings.json`. 플러그인 설치 시 `enabledPlugins`/`extraKnownMarketplaces`는 자동으로 채워진다. **직접 넣는 건 아래 골격.** (기존 파일 있으면 백업 후 병합, JSON 검증 필수.)

```jsonc
{
  "model": "opus",
  "effortLevel": "high",
  "autoUpdatesChannel": "latest",
  "permissions": {
    "deny": [
      "Bash(rm -rf *)", "Bash(sudo *)",
      "Read(./.env*)", "Write(./.env*)", "Edit(./.env*)",
      "Read(./**/*.pem)", "Read(./**/id_rsa*)", "Read(./**/*.key)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [
        { "type": "command", "command": "bash ~/.claude/hooks/block-dangerous-bash.sh" } ] },
      { "matcher": "Bash", "hooks": [
        { "type": "command",
          "command": "jq -r '\"[\" + (now | strftime(\"%Y-%m-%d %H:%M:%S\")) + \"] \" + .tool_input.command' >> ~/.claude/bash-log.txt 2>/dev/null || true" } ] }
    ],
    "PostToolUse": [
      { "matcher": "Write|Edit", "hooks": [
        { "type": "command",
          "command": "jq -r '.tool_input.file_path // .tool_response.filePath // \"\"' | { read -r f; [ -n \"$f\" ] && npx prettier --write \"$f\" --ignore-unknown; } 2>/dev/null || true",
          "statusMessage": "prettier 포맷 적용 중..." } ] }
    ],
    "Stop": [
      { "hooks": [ { "type": "command",
        "command": "printf '{\"systemMessage\": \"작업 완료.\"}'" } ] }
    ]
  }
}
```

**훅 설명**
- **PreToolUse `block-dangerous-bash`**: `rm -rf /`, `mkfs`, fork bomb 등 위험 명령을 **exit 2로 차단**(결정론적 가드레일). A3 스크립트.
- **PreToolUse bash-log**: 실행한 bash를 `~/.claude/bash-log.txt`에 로깅 (jq 필요, 없으면 스킵).
- **PostToolUse prettier**: 편집 파일 자동 포맷 (jq·npx 필요).
- **Stop**: 완료 메시지.
- 권한 `deny`: 비밀키·`.env`·위험 명령을 원천 차단. `git push --force`는 습관적으로 `--force-with-lease` 사용.

> 참고: 내 원래 세팅엔 옵시디언 자동저널용 `SessionEnd` 훅도 있었지만 **다른 컴퓨터에선 안 쓰므로 제외**했다. 필요하면 §부록-옵시디언 참고.

## A3. 안전 훅 스크립트

`~/.claude/hooks/block-dangerous-bash.sh` (생성 후 `chmod +x`):
```bash
#!/usr/bin/env bash
# PreToolUse(Bash) 가드레일: 위험 패턴이면 exit 2로 차단.
input="$(cat)"
cmd="$(printf '%s' "$input" | python -c 'import sys,json; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null)"
deny_patterns=( 'rm -rf /' 'rm -rf ~' ':(){ :|:& };:' 'mkfs' 'dd if=.* of=/dev/' 'sudo rm' 'chmod -R 777 /' )
for p in "${deny_patterns[@]}"; do
  if printf '%s' "$cmd" | grep -Eq "$p"; then
    echo "DENIED: dangerous pattern: $p" >&2
    exit 2
  fi
done
exit 0
```

(선택) 프로젝트 스택이 정해지면 `post-edit-lint.sh`(린트 결과 되먹임), `save-progress.sh`(Stop 시 진행요약 append)도 추가 — 원문은 레포 `claude-harness-unified.md §17.4`.

## A4. 글로벌 `CLAUDE.md` (모든 프로젝트 공통 룰)

위치: `~/.claude/CLAUDE.md`. 모든 프로젝트 루트 CLAUDE.md보다 먼저 합쳐진다. **보편 룰만.**

```markdown
# User-level CLAUDE.md

## Workflow defaults
- 작업 시작: `pwd` → `claude-progress.txt`/`feature_list.json` 있으면 먼저 읽기(long-running 신호).
- 작업 종료: 변경 요약 한 단락을 `claude-progress.txt`에 append(있을 때만).
- 코드 변경 후 항상 형식/타입 검사 1회(`pnpm lint && typecheck`, `ruff check`, `cargo check`…).
- 보고 전 한 번 더 자가 검증(테스트/스모크/미리보기).

## Default tone
- 차분·직접적으로. "CRITICAL!", "YOU MUST!" 같은 과장 금지(정확도 하락).
- 한국어로 말하면 한국어로. 코드/식별자는 영어.
- 산문 보고서 금지 — 근거는 짧은 불릿/표로.

## Hard rules
- `rm -rf`,`sudo rm`,`chmod 777 /`류는 PreToolUse 훅이 차단. 우회 금지.
- `.env*`,`*.pem`,`id_rsa*`,`*.key`는 deny. 진짜 필요하면 사용자에게 물어라.
- `git push --force`는 ask. 평소 `--force-with-lease`.
- TypeScript `any` 금지. 불가피하면 `// TODO: type` + 이유.

## When in doubt
- 요구가 모호하면 AskUserQuestion으로 1~3개 질문 — 추측보다 묻기.
- 역할 분업이 필요한 큰 변경 → `/plan-eng` → `/build` → `/review`(A5).

## Coding guidelines (핵심 4)
1. Think Before Coding — 가정을 명시, 애매하면 멈추고 질문, 더 단순한 길 있으면 제안.
2. Simplicity First — 요청 이상 금지. 200줄이 50줄이면 다시 써라.
3. Surgical Changes — 건드릴 것만. 멀쩡한 코드 리팩터 금지. 기존 스타일 따르기.
4. Goal-Driven — "작동하게" 대신 검증 가능한 성공 기준부터 정의.
```
> 이 4개 코딩 가이드는 karpathy-skills 플러그인과 동일 철학. 플러그인을 깔면 자동 적용되므로 CLAUDE.md엔 요약만 둬도 된다.

## A5. 역할 기반 로컬 하네스 (선택, 강력) — gstack 축소판

**아이디어:** `마크다운 1장 = 전문가 1명 = 슬래시 커맨드 1개`. 산출물(파일)이 다음 역할의 입력이 된다.
처음엔 **`/plan-eng` + `/build` + `/review` + `/careful` 4개만** 만들면 충분.

디렉토리:
```
~/.claude/skills/local-harness/
├── plan-eng/SKILL.md   (Eng Manager — 어떻게 만들지 결정, docs/design/*-arch.md)
├── build/SKILL.md      (Staff Eng — 실제 코드, lint/typecheck)
├── review/SKILL.md     (Reviewer — Critical/Style/Suggestions)
├── careful/SKILL.md    (Safety — 삭제·마이그레이션·배포 직전 dry-run+승인)
└── setup               (심볼릭 링크 + CLAUDE.md 라우팅 삽입)
```

SKILL.md 표준 형식(frontmatter로 triggers·inputs·outputs·chains_to·guardrails):
```markdown
---
name: plan-eng
role: Engineering Manager
triggers: ["아키텍처 짜줘", "기술 결정", "설계", "어떻게 만들지"]
inputs:  [docs/product-brief.md]
outputs: [docs/design/{feature}-arch.md]
chains_to: [build]
guardrails:
  - "코드 직접 작성 금지. 결정과 근거만."
  - "외부 의존성 추가 시 trade-off 표 필수. 단일 옵션 금지."
---
# Engineering Manager
## When to use
"어떻게 구현할지 정해줘" — 구현이 아니라 **결정**이 필요한 단계.
## Process
1. brief 읽기(없으면 의도부터 확인) 2. 결정 포인트 3~7개 추출(데이터모델/API경계/상태/의존성)
3. 각 결정 옵션 2~3 + trade-off + 추천 4. `docs/design/{feature}-arch.md` 저장 5. `/build` 안내
## What NOT to do
- 실제 코드 작성 · 단일 옵션만 · "그때 가서 보자"
```
(build/review/careful SKILL.md 전문은 레포 `.claude/skills/*/SKILL.md` 참고.)

프로젝트 `CLAUDE.md`에 라우팅 섹션 추가:
```markdown
## Skills (local-harness)
| Command | Role | When |
|---|---|---|
| /plan-eng | Eng Manager | 어떻게 만들지 결정 |
| /build | Staff Engineer | 실제 코드 작성 |
| /review | Code Reviewer | 변경 리뷰 |
| /careful | Safety Guardrail | 삭제·마이그레이션·배포 직전 |
## Skill routing
- "기능 추가" → /plan-eng → /build → /review
- "버그" → /build → /review · "삭제/마이그레이션/배포" → 반드시 /careful 먼저
기본 원칙: 한 번에 하나의 역할.
```

setup 스크립트(심볼릭 링크 + 라우팅 삽입)는 레포 `claude-local-harness.md §7` 참고.

---

# PART B — 하네스 엔지니어링 원리 (왜 이렇게 하나)

> 전체 이론은 레포 `claude-harness-unified.md`. 여기선 실전에 꼭 필요한 뼈대만.

## B1. 멘탈 모델 — "하네스 = 모델을 일하게 만드는 모든 것"
시스템 프롬프트 + 도구 + 컨텍스트 정책 + 권한 + 후처리 + 메모리의 총합.
> "에이전트의 5%만 loop 안 모델 호출, 95%는 컨텍스트 관리·도구 실행·샌드박싱·에러 처리." — Anthropic

**좋은 하네스의 4축:** ① Context(뭘 보여줄까) ② Action(뭘 시킬까) ③ Verification(어떻게 검증) ④ Persistence(뭘 남길까). 이 4축이 균형 잡혀야 컨텍스트 윈도를 넘어 일관되게 진척된다.

## B2. 에이전트 루프 — Gather → Act → Verify → Repeat
핵심은 **Verify**. Claude는 "다 했음"이라 선언하기 쉬워서, 검증 단계를 강제하지 않으면 완료 환각이 난다.
- 규칙 기반 피드백(린트·테스트·타입체커)으로 스스로 점수 매기게.
- 실패 사유를 텍스트로 되돌려줘라("FAIL"만으론 부족).
- 웹앱은 Playwright/Puppeteer로 사람처럼 클릭·스크린샷(E2E).

## B3. 컨텍스트 엔지니어링
- **Context Rot**: 컨텍스트는 길수록 정확도가 떨어진다. 다 채우지 마라.
- **Goldilocks 고도**: 시스템 프롬프트는 너무 구체적(취약)도, 너무 추상(모호)도 아닌 중간.
- **Just-in-Time**: 전부 미리 넣지 말고 필요할 때 검색/로딩(스킬의 progressive disclosure).
- **장기작업 3무기**: Compaction(압축) · Notes(외부 메모 파일) · Sub-agents(컨텍스트 격리).

## B4. 빌딩 블록 6종 (언제 뭘 쓰나)

| 블록 | 위치 | 쓰임 | 자동성 |
|---|---|---|---|
| **CLAUDE.md** | `~/.claude/` , 프로젝트 루트 | 항상 적용되는 룰·컨텍스트 | 자동 로드 |
| **Skills** (SKILL.md) | 플러그인 / `.claude/skills/` | 특정 작업 절차·지식 | description 트리거 or `/명령` |
| **Subagents** | `~/.claude/agents/` | 컨텍스트 격리한 위임(리뷰 등) | 위임 호출 |
| **Hooks** | `settings.json` | 결정론적 가드레일·자동화 | 이벤트 자동 |
| **Slash cmds** | `~/.claude/commands/` | 자주 쓰는 프롬프트 단축 | `/명령` |
| **MCP** | `claude mcp add` | 외부 도구/데이터 연결 | 도구로 노출 |

**설계 원칙 요약**
- **CLAUDE.md = 미니멀리즘.** 길수록 나쁘다. 강한 어휘("반드시!!")는 역효과.
- **도구 5원칙**(Anthropic): 옳은 도구 선택(래핑 말고) · 네임스페이싱 · 의미 있는 컨텍스트만 반환 · 토큰 효율 · **설명을 프롬프트처럼** 작성(모든 단어가 정확도에 영향).
- **스킬 = Progressive Disclosure.** description은 "언제 발동할지"의 트리거 단서. 코드/매뉴얼은 분리해 필요 시 로드.
- **훅 = 결정론.** 모델의 선의에 맡기지 말고, 위험은 훅으로 물리적으로 막아라(PreToolUse가 가장 강력).

---

# PART C — 워크플로 & 프롬프트 패턴

> 원문: 레포 `prompt.md`.

## C1. 바이브코딩 4단계
```
PHASE 0 리서치  → research.md   ("상세히, 깊이 읽고 정리해줘" — 안 그러면 요약만 나온다)
PHASE 1 계획    → plan.md       (코드 스니펫 포함, 소스 읽고 실제 코드베이스 기반)
                 └ 메모 반영 루프: "메모 반영하고 업데이트해. 아직 구현하지마." (안정될 때까지)
PHASE 2 구현    → 코드          ("전부 구현. 멈추지 마. any/unknown 금지. typecheck 상시.")
PHASE 3 (복잡)  → PLANNER → EVALUATOR → DEVELOPER 역할 분리
```
핵심: **코드 한 줄 쓰기 전에 계획을 문서로 굳힌다.** 각 단계 완료 시 계획 문서에 체크 표시(진행 추적).

## C2. 자주 쓰는 프롬프트

| 상황 | 패턴 |
|---|---|
| 리서치 | "상세히·깊이 읽고 research.md 만들어줘" |
| 계획 수정 | "메모 반영하고 업데이트해. 아직 구현하지마." |
| 구현 | "전부 구현해라. 멈추지 마라." |
| 타입 안전 | "any/unknown 금지. typecheck 지속 실행." |
| 계획 검토 | "PLANNER → EVALUATOR → DEVELOPER 구조로" |
| 진행 추적 | "완료 단계는 계획 문서에 체크 표시" |

---

# PART D — 실행 가이드 & 클로드한테 시키기

## D1. 0부터 시작하는 순서 (요약)
1. 사전 준비물 설치·확인(A0) → `where claude`, `bash/python --version`
2. 플러그인 5종 설치(A1) → `/reload-plugins`
3. `~/.claude/settings.json` 병합(A2) + `~/.claude/hooks/block-dangerous-bash.sh` 생성·`chmod +x`(A3)
4. `~/.claude/CLAUDE.md` 작성(A4)
5. (선택) 역할 하네스 4스킬 + 라우팅(A5)
6. 검증: 아무 프로젝트에서 `claude` 실행 → `/review` 등 동작 확인, 위험 명령이 차단되는지 테스트

## D2. ⭐ 클로드한테 통째로 시키기
새 PC에 이 `SETUP_GUIDE.md`(+ 같은 레포 파일들)를 두고, 그 폴더에서 `claude` 실행 후 붙여넣기:

```
이 폴더의 SETUP_GUIDE.md 를 읽고, 내 Claude Code 환경을 이 문서대로 이 컴퓨터에 재현해줘.

1. 먼저 where claude / bash --version / python --version 으로 준비물을 점검하고 내 홈 경로(사용자명)를 확인해줘.
2. PART A1의 플러그인 5종을 marketplace add → install 로 전부 설치해줘.
3. A2의 settings.json 골격을 내 ~/.claude/settings.json 에 병합해줘. 기존 파일 있으면 백업 먼저, JSON 검증 필수, enabledPlugins 같은 기존 값은 보존.
4. A3의 block-dangerous-bash.sh 를 만들고 실행권한을 줘. (경로의 <사용자명>은 내 실제 값으로.)
5. A4의 글로벌 CLAUDE.md 를 만들어줘.
6. (원하면) A5의 역할 하네스 4스킬(plan-eng/build/review/careful)과 라우팅 섹션도 세팅해줘. 자세한 SKILL.md 전문은 같은 레포의 .claude/skills/ 를 참고.
7. 각 단계 끝나면 뭘 했는지 보고하고, 위험 명령 차단 훅이 실제로 막는지 한 번 테스트해서 결과를 보여줘.

실패하면 멈추고 물어봐. 옵시디언 자동저널은 이 컴퓨터에선 안 하니까 건너뛰어.
```

---

## 부록

### 부록 1 — 디자인 가이드 요약 (웹 UI 만들 때, 원문 `design_guide.md`)
- **3색 이내**(흑백 모노 + 강조 1). 장식 아이콘·그림자·그라디언트·테두리 제거 → 여백으로 구분.
- 레퍼런스(Dribbble/Awwwards/21st.dev) 캡처 → 프롬프트에 첨부해서 시작.
- Hero: 애플식 카피(기능 나열 X, 변화·결과를 10단어 이내). 폰트 2종 이내.
- Navbar: 투명 → 스크롤 시 `backdrop-filter: blur()` + 불투명.
- 배포 전 체크: "전체 색상 뽑아서 3개 초과분 제거."

### 부록 2 — (선택) 옵시디언 세션 자동저널
이 컴퓨터에선 안 쓰기로 했지만, 원할 경우: `SessionEnd` 훅으로 세션 종료 시 대화를 큐레이션해 옵시디언 볼트(`00_Journal`/`10_Projects`/`90_Career`)에 자동 기록하는 시스템. 구성 파일은 원본 PC의 `~/.claude/journal-hook.sh` + `~/.claude/journal-prompt.md`.

### 부록 3 — 현재 버전 스냅샷 (2026-07-08)
superpowers 6.1.1 · andrej-karpathy-skills 1.0.0 · watch 0.1.3 · understand-anything 2.7.6 · humanize-korean 1.5.0 · model opus · effortLevel high

### 부록 4 — 출처
- 같은 레포: `claude-harness-unified.md`(통합 이론), `claude-harness-master-guide.md`(마스터), `claude-local-harness.md`(gstack 역할 하네스), `prompt.md`(워크플로), `design_guide.md`(디자인)
- 원저: Anthropic *Effective harnesses for long-running agents*, *Writing effective tools for AI agents* / [garrytan/gstack](https://github.com/garrytan/gstack)
```
