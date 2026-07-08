# 🛠️ 내 Claude Code 환경 재현 가이드

> 이 문서 하나로 **새 컴퓨터에 지금 내 Claude Code 세팅을 똑같이** 복원할 수 있다.
> 구성: ① 플러그인 5종 ② 훅(자동화) 5종 ③ 옵시디언 자동저널 시스템.
> **가장 쉬운 방법은 맨 아래 [§7 "클로드한테 시키기"](#7-클로드한테-시키기-가장-쉬움)** — 이 파일을 새 PC에 복사하고 그 프롬프트만 붙여넣으면 끝.

작성일: 2026-07-08 / 원본 사용자 경로: `C:\Users\82102`
> ⚠️ 새 PC에선 사용자명이 다르다. 아래 경로의 `82102`(=`C:\Users\<사용자명>`)를 **본인 것으로 바꿔라.** 확인: 터미널에서 `echo %USERPROFILE%` (또는 bash `echo $HOME`).

---

## 0. 사전 준비물 (Prerequisites)

| 프로그램 | 확인 명령 | 비고 |
|---|---|---|
| **Claude Code** | `claude --version` | 없으면 먼저 설치. 보통 `C:\Users\<사용자명>\.local\bin\claude.exe` |
| **Git Bash** | `bash --version` | 훅이 bash로 실행됨(윈도우 필수). Git for Windows에 포함 |
| **Python 3** | `python --version` | 일부 유틸/플러그인용 |
| **Obsidian** | 앱 실행 | 자동저널 **보기**용. 없어도 기록은 폴더에 쌓임 |
| **Node/npx** | `npx --version` | prettier 훅용(선택) |

> 💡 훅 실행 환경엔 **`jq`가 없다**(중요). 그래서 자동저널 훅은 jq 없이 순수 bash로 파싱하게 짜여 있음.

---

## 1. 전체 구성 요약

```
C:\Users\<사용자명>\
├── .claude\
│   ├── settings.json          ← 핵심 설정(훅·플러그인·모델·권한)
│   ├── journal-hook.sh        ← 세션종료 시 자동저널 훅 스크립트
│   ├── journal-prompt.md      ← 자동저널 큐레이션 지침
│   └── plugins\               ← 플러그인 캐시(명령어로 재설치되므로 복사 불필요)
└── Documents\ObsidianVault\   ← 옵시디언 볼트(노트 저장소)
    ├── 00_Journal/  10_Projects/  20_Learnings/  90_Career/  _templates/
    ├── 🧠 INDEX.md   README.md
```

---

## 2. 플러그인 5종 설치

각각 **마켓플레이스 추가 → 설치** 순서. 터미널(PowerShell/bash 아무거나)에서 실행:

```bash
# 1) 공식 마켓플레이스 + superpowers (개발 워크플로 14종 스킬)
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

설치 후 적용: 실행 중인 claude 세션에서 `/reload-plugins` 또는 claude 재시작.
확인: `claude plugin list`

| 플러그인 | repo | 제공 |
|---|---|---|
| superpowers | anthropics/claude-plugins-official | 스킬 14종(brainstorming, TDD, systematic-debugging …) |
| andrej-karpathy-skills | forrestchang/andrej-karpathy-skills | karpathy-guidelines 스킬 |
| watch (claude-video) | bradautomates/claude-video | watch, remotion-best-practices |
| understand-anything | Lum1104/Understand-Anything | understand 계열 8종 |
| humanize-korean | epoko77-ai/im-not-ai | humanize-korean 스킬 + 에이전트 13종 |

---

## 3. settings.json (훅·모델·설정)

위치: `C:\Users\<사용자명>\.claude\settings.json`
플러그인을 위 명령으로 설치하면 `enabledPlugins`/`extraKnownMarketplaces`는 **자동으로 채워진다.**
**직접 넣어야 하는 건 `hooks` 블록과 기본 옵션들**이다. 아래를 `settings.json`에 병합하라(이미 있으면 `hooks`만 추가):

```jsonc
{
  "model": "opus",
  "effortLevel": "high",
  "autoUpdatesChannel": "latest",
  "hooks": {
    "PostToolUse": [
      { "matcher": "Write|Edit", "hooks": [
        { "type": "command",
          "command": "jq -r '.tool_input.file_path // .tool_response.filePath // \"\"' | { read -r f; [ -n \"$f\" ] && npx prettier --write \"$f\" --ignore-unknown; } 2>/dev/null || true",
          "statusMessage": "prettier 포맷 적용 중..." } ] }
    ],
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [
        { "type": "command",
          "command": "jq -r '\"[\" + (now | strftime(\"%Y-%m-%d %H:%M:%S\")) + \"] \" + .tool_input.command' >> ~/.claude/bash-log.txt 2>/dev/null || true" } ] }
    ],
    "Stop": [
      { "hooks": [ { "type": "command",
        "command": "printf '{\"systemMessage\": \"Claude 작업이 완료되었습니다.\"}'" } ] }
    ],
    "SessionStart": [
      { "hooks": [ { "type": "command",
        "command": "printf '{\"systemMessage\": \"Claude 세션이 시작되었습니다. 무엇을 도와드릴까요?\"}'" } ] }
    ],
    "SessionEnd": [
      { "hooks": [ { "type": "command",
        "command": "bash ~/.claude/journal-hook.sh" } ] }
    ]
  }
}
```

**훅 5종 설명:**
- **PostToolUse(prettier)**: 파일 편집할 때마다 자동 포맷 (jq·npx 필요, 없으면 조용히 스킵)
- **PreToolUse(bash-log)**: 실행한 bash 명령을 `~/.claude/bash-log.txt`에 기록 (jq 필요)
- **Stop / SessionStart**: 상태 메시지 표시
- **SessionEnd(자동저널)**: ⭐ 핵심 — 세션 끝나면 옵시디언에 자동 기록 (다음 섹션)

> 참고: PostToolUse·PreToolUse 훅은 **jq가 있어야** 동작. jq 없으면 무해하게 스킵됨. 원하면 `winget install jqlang.jq`로 설치.

---

## 4. 옵시디언 자동저널 시스템 ⭐

**핵심 아이디어:** Claude와 Obsidian은 "연결"되지 않는다. 둘 다 **같은 폴더**를 쓸 뿐.
Claude(훅)가 세션 끝날 때 그 폴더에 `.md`를 **쓰고**, Obsidian은 그 폴더를 **보여준다.**

### 4-1. 볼트 폴더 만들기
```bash
VAULT="C:/Users/<사용자명>/Documents/ObsidianVault"
mkdir -p "$VAULT/00_Journal" "$VAULT/10_Projects" "$VAULT/20_Learnings" "$VAULT/90_Career" "$VAULT/_templates"
```

### 4-2. `~/.claude/journal-hook.sh` (그대로 생성 — 경로 3곳만 본인 것으로)

```bash
#!/usr/bin/env bash
# SessionEnd 훅: 끝난 세션을 큐레이션해서 옵시디언 볼트에 자동 기록.
# 백그라운드 claude를 띄워 처리하며, 그 claude가 또 SessionEnd를 유발하지 않도록 재귀를 막는다.
# 주의: 이 훅 실행 환경엔 jq가 없다 → 순수 bash로 JSON을 파싱한다.

# --- 재귀 방지: 저널링용 claude 안에서 이 훅이 다시 돌면 즉시 종료 ---
[ "$CLAUDE_JOURNALING" = "1" ] && exit 0

# --- stdin JSON 파싱 (jq 없이) ---
input=$(cat)
transcript=""
if [[ "$input" =~ \"transcript_path\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
  transcript="${BASH_REMATCH[1]}"
fi
# JSON 이스케이프 백슬래시를 슬래시로 정규화 (Windows 경로 대응)
transcript="${transcript//\\\\//}"
transcript="${transcript//\\//}"

[ -z "$transcript" ] && exit 0
[ ! -f "$transcript" ] && exit 0

# ▼▼▼ 새 PC에서 이 3줄 경로를 본인 것으로 바꿔라 ▼▼▼
VAULT="C:/Users/<사용자명>/Documents/ObsidianVault"
CLAUDE="C:/Users/<사용자명>/.local/bin/claude.exe"   # where claude 로 확인
PROMPT_GUIDE="C:/Users/<사용자명>/.claude/journal-prompt.md"
# ▲▲▲
LOG="C:/Users/<사용자명>/.claude/journal-hook.log"

PROMPT="너는 저널링 에이전트다. 먼저 ${PROMPT_GUIDE} 를 Read해서 지침을 읽어라.
세션 트랜스크립트 파일: ${transcript}
옵시디언 볼트 경로(\$VAULT): ${VAULT}
지침대로 이 세션을 큐레이션해서 볼트에 기록하라. 기록할 가치가 없으면 아무것도 하지 말고 종료하라."

echo "[$(date '+%Y-%m-%d %H:%M:%S')] journaling start (transcript=$transcript)" >> "$LOG"

# 세션 종료를 막지 않도록 백그라운드(detach)로 실행. 재귀 방지 플래그를 환경에 주입.
CLAUDE_JOURNALING=1 nohup "$CLAUDE" -p "$PROMPT" \
  --allowedTools "Read,Write,Edit,Glob,Grep" \
  --permission-mode acceptEdits \
  >> "$LOG" 2>&1 &

exit 0
```

### 4-3. `~/.claude/journal-prompt.md` (큐레이션 지침 — 경로 수정 불필요, 그대로 복사)

```markdown
# 작업 저널 큐레이션 지침

너는 방금 끝난 Claude Code 세션을 정리해 옵시디언 볼트에 기록하는 "저널링 에이전트"다.
목표: 사용자가 나중에 **자기소개서/이력서**를 쓸 때 "내가 뭘 했고 뭘 배웠지?"에 답할 근거를 쌓는 것.

## 입력
- 세션 트랜스크립트(JSONL) 경로가 프롬프트로 주어진다. 먼저 그 파일을 Read해서 세션 내용을 파악하라.
  - 파일이 크면 일부만 읽어도 된다. 사용자 메시지와 무엇을 했는지(편집한 파일, 해결한 문제)에 집중하라.
  - 트랜스크립트의 `cwd` 필드로 어떤 프로젝트/폴더에서 작업했는지 추론하라.
- 오늘 날짜는 시스템 기준으로 판단하라 (`YYYY-MM-DD`).

## 1단계: 기록할 가치가 있는가? (게이트)
다음이면 **아무것도 쓰지 말고 즉시 종료**하라:
- 단순 질문/답변만 오감 (코드·작업 산출물 없음)
- 사소한 설정 확인, 잡담, 1~2턴짜리 짧은 세션
- 이미 같은 날 같은 내용이 기록돼 있음 (중복 방지: 먼저 오늘 일일 로그를 확인하라)

의미 있는 작업(코드 작성/수정, 디버깅, 설계 결정, 새로 배운 것, 프로젝트 진전)이 있을 때만 다음으로 진행.

## 2단계: 큐레이션 (복붙 금지, 요약하라)
트랜스크립트를 그대로 옮기지 마라. **선별·압축**해서:
- 무엇을 했는가 (결과 중심, 1~4개 불릿)
- 무엇을 배웠는가 (재사용 가능한 지식, 왜 중요한지)
- 막혔다가 해결한 것 (문제 → 원인 → 해결)
- 자랑할 성과 (정량적이면 더 좋음: "백테스트 12종", "응답 0.3초로 단축" 등)
사실만 적어라. 트랜스크립트에 없는 내용을 지어내지 마라.

## 3단계: 기록 (볼트 경로는 프롬프트로 주어짐)
볼트 루트를 `$VAULT`라 하자.

### (a) 일일 로그 — 항상
`$VAULT/00_Journal/YYYY-MM-DD.md`
- 없으면 `_templates/daily.md` 양식으로 새로 만들고, 있으면 해당 섹션에 **append** (기존 내용 보존).
- 각 항목에 `[#project/이름]`, `[#skill/기술]` 태그를 달아라.

### (b) 프로젝트 노트 — 프로젝트성 작업이면
`$VAULT/10_Projects/<프로젝트>.md`
- 프로젝트명은 작업 폴더명에서 추론 (예: `binance_real` → 폴더명 기반 kebab-case).
- 없으면 `_templates/project.md` 양식으로 생성, 있으면 "진행 로그"에 날짜와 함께 append.

### (c) 배운 것 — 재사용 가능한 기술 지식이면
`$VAULT/20_Learnings/<주제>.md` 에 누적 (선택적, 일반적으로 쓸모 있는 지식일 때만).

### (d) 성과 — 자소서감이면
`$VAULT/90_Career/achievements.md` 하단에 STAR 형식(상황/과제/행동/결과/배운 점)으로 append.

## 4단계: 노트를 서로 연결하라 (그래프=두뇌의 핵심)
기록할 때 관련 노트를 반드시 `[[ ]]` 위키링크로 이어라. 이게 옵시디언 그래프를 "두뇌"처럼 만든다.
- **일일 로그**의 각 작업 항목에서 관련 프로젝트를 `[[프로젝트명]]`으로 링크.
- **프로젝트 노트**에서 그날 다룬 핵심 개념/기술을 `[[개념]]`으로 링크.
- **배운 것(20_Learnings)** 노트에서 상위 기술 허브를 `[[Python]]`, `[[백테스팅]]`처럼 링크.
- **성과(career)** 항목에서 근거가 된 `[[프로젝트명]]`을 링크.
- 중심 허브 노트 `[[🧠 INDEX]]`에 새 프로젝트/핵심기술 링크가 없으면 추가.
- 링크 대상이 아직 없어도 된다. **일관된 이름**으로 같은 개념이 한 노드로 모이게 하라.

## 원칙
- 기존 파일은 **append/수정만**, 통째로 덮어쓰지 마라.
- 한국어로 작성. 간결하게(일일 로그 한 세션 3~8줄).
- 확신 없으면 적게 적어라. 끝나면 무엇을 어디에 기록했는지 한 줄 보고.
```

### 4-4. 볼트 시드 파일(선택)
`_templates/daily.md`, `_templates/project.md`, `90_Career/achievements.md`, `🧠 INDEX.md`, `README.md`.
없어도 자동저널이 알아서 만들지만, 있으면 양식이 일정해진다. (없으면 클로드한테 "§7 프롬프트"로 만들라고 하면 됨.)

### 4-5. Obsidian에서 볼트 열기
Obsidian 실행 → **"보관함 폴더 열기(Open folder as vault)"** → `Documents\ObsidianVault` 선택.
그래프 보기: 노트 열고 `Ctrl+G`. 영역별 색칠: 그래프 우측 ⚙ → Groups → `path:10_Projects`=파랑 등.

---

## 5. 동작 원리 & 검증

- 자동저널은 **세션이 끝날 때(SessionEnd)** 딱 한 번 발동한다. 세션 진행 중엔 아무것도 안 생김(정상).
- **재귀 방지**: 저널링용 claude엔 `CLAUDE_JOURNALING=1`이 주입돼, 걔가 끝나며 훅을 또 불러도 즉시 종료.
- **비용**: 세션마다 헤드리스 claude 1회 호출 → 토큰 소모. 끄려면 settings.json의 `SessionEnd` 블록 삭제.

**바로 테스트(세션종료 흉내):**
```bash
# 최근 세션 트랜스크립트 하나로 훅을 수동 실행
ls -t ~/.claude/projects/*/*.jsonl | head -1   # 경로 확인 후 아래 T에 대입
printf '{"transcript_path":"<위 경로>","reason":"clear"}' | bash ~/.claude/journal-hook.sh
sleep 60; ls ~/../Documents/ObsidianVault/00_Journal/   # 파일 생기면 성공
cat ~/.claude/journal-hook.log                          # 로그 확인
```

---

## 6. MCP 커넥터(참고, 계정 단위)

Gmail·Google Calendar·Google Drive·Naver(PlayMCP) 등은 **claude.ai 계정에 연결된 커넥터**라 이 파일로 복사되지 않는다.
새 PC에서 같은 계정으로 로그인하면 따라오거나, claude.ai 설정에서 재연결하면 된다.

---

## 7. 클로드한테 시키기 (가장 쉬움)

새 PC에 **이 `SETUP_GUIDE.md` 파일을 복사**해두고, 그 폴더에서 `claude` 실행 후 아래를 붙여넣어라:

```
이 폴더의 SETUP_GUIDE.md 를 읽고, 내 Claude Code 환경을 이 문서대로 이 컴퓨터에 그대로 재현해줘. 순서:

1. 먼저 `where claude`, `bash --version`, `python --version` 으로 사전 준비물을 점검하고, 내 사용자명(홈 경로)을 확인해줘.
2. §2의 플러그인 5종을 marketplace add → install 명령으로 전부 설치해줘.
3. §3의 hooks 블록을 내 ~/.claude/settings.json 에 병합해줘. (기존 settings.json이 있으면 백업 먼저, JSON 깨지지 않게 검증.)
4. §4대로 옵시디언 볼트 폴더 구조를 만들고, journal-hook.sh 와 journal-prompt.md 를 생성해줘. **경로의 <사용자명>과 claude.exe 위치는 내 실제 값으로 바꿔서** 넣어줘.
5. 볼트 시드 파일(_templates, 🧠 INDEX.md, README.md, 90_Career/achievements.md)도 만들어줘.
6. §5의 테스트 방법으로 자동저널이 실제로 파일을 쓰는지 검증하고, 결과를 보여줘.

각 단계 끝나면 뭘 했는지 알려주고, 실패하면 멈추고 물어봐. 다 끝나면 마지막에 Obsidian에서 "보관함 폴더 열기"로 볼트 여는 법만 안내해줘.
```

이거면 클로드가 알아서 전부 세팅한다. 끝나고 Obsidian만 열어서 볼트 지정하면 완료.

---

## 부록: 현재 설치 버전 스냅샷 (2026-07-08)
- superpowers 6.1.1 · andrej-karpathy-skills 1.0.0 · watch(claude-video) 0.1.3 · understand-anything 2.7.6 · humanize-korean 1.5.0
- model: opus · effortLevel: high · autoUpdatesChannel: latest
