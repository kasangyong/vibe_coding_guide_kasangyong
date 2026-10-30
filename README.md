# vibe_coding_guide

Claude Code / Codex 공용 로컬 하네스. 전역 규칙, 기본 스킬 4개, 위험 명령 차단 훅, MCP 등록 스크립트를 담는다.

## 구조

```
skills/core/     plan-eng · build · review · careful   (두 도구 공용 SKILL.md)
skills/video/    video · video-review                   (영상 제작 팩, core와 독립)
claude/          CLAUDE.md · settings.json · hooks/ · mcp.sh
codex/           AGENTS.md · hooks.json · hooks/ · mcp.sh
docs/            prompt.md (프롬프트 순서도) · design_guide.md (디자인 가이드)
install.sh       claude | codex 설치
```

## 설치

Git Bash(Windows) 또는 bash 에서 실행한다. 덮어쓰는 파일은 `.bak-<시각>` 으로 백업된다.
`settings.json` / `hooks.json` 은 기존 내용(플러그인, 모델 설정 등)을 유지한 채 훅과 deny 규칙만 병합한다.

```bash
git clone https://github.com/kasangyong/vibe_coding_guide_kasangyong
cd vibe_coding_guide_kasangyong
./install.sh codex     # 또는 ./install.sh claude
./codex/mcp.sh         # 또는 ./claude/mcp.sh
```

| | Claude | Codex |
|---|---|---|
| 전역 규칙 | `~/.claude/CLAUDE.md` | `~/.codex/AGENTS.md` |
| 훅 | `~/.claude/settings.json` | `~/.codex/hooks.json` |
| 스킬 | `~/.claude/skills/` | `~/.agents/skills/` |
| 스킬 호출 | `/plan-eng` | `$plan-eng` |
| MCP 저장 위치 | `~/.claude.json` | `~/.codex/config.toml` |

필요한 것: `python3` 또는 `python` (훅, 설치 시 실제 실행되는 쪽을 골라 넣는다), `node`/`npx` (playwright MCP).

## 영상 스킬 팩

자료(프로젝트 폴더, 글, README)를 읽고 소개 영상을 만든다. 기획서 작성, `seek(t)` HTML/Canvas 페이지, Playwright 프레임 렌더(서브프레임 모션 블러), 페이지에서 합성한 소리, ffmpeg 인코딩, 무음 썸네일 루프와 포스터, 자체 검사까지 한 흐름이다. 단계마다 검사를 통과해야 다음으로 간다. 평가는 만든 쪽과 다른 세션의 `video-review`가 위험 / 보통 / 통과로 한다.

| | Claude | Codex |
|---|---|---|
| 만들기 | `/video` | `$video` |
| 평가 | `/video-review` (별도 에이전트) | `$video-review` (새 세션, 또는 `codex exec`) |

필요한 것: `node` 20+, `ffmpeg`/`ffprobe` (libx264 포함 빌드), `python3` + `fonttools` `brotli`. 이동량으로 블러 구간을 고르는 `motion.py`를 쓰려면 `opencv-python-headless` `numpy`.

첫 설치 (`install.sh` 다음, 스킬 폴더에서. Windows Git Bash에서는 `python3` 대신 `python`이 맞을 수 있다):

```bash
cd ~/.claude/skills/video            # Codex는 ~/.agents/skills/video
npm ci && npx playwright install chromium          # Linux: npx playwright install --with-deps chromium
python3 -m venv ~/.venvs/video && . ~/.venvs/video/bin/activate   # Linux/macOS 권장 (Windows는 생략 가능)
python3 -m pip install fonttools brotli
python3 scripts/fonts.py get Pretendard 900 600    # 다른 글꼴은 references/styles.md
bash scripts/doctor.sh                             # 빠진 것과 설치 방법을 보여 준다
```

글꼴은 `~/.cache/video-skill/fonts`(또는 `VIDEO_FONTS`)에 받아 다시 설치해도 남는다. `install.sh`를 다시 돌리면 스킬 폴더가 백업으로 옮겨지므로 `npm ci`는 다시 한다. 두 팩에 같은 이름의 스킬이 있으면 `install.sh`는 아무것도 바꾸지 않고 멈춘다.

### Windows에서 Codex로 쓸 때

Codex의 기본 샌드박스(`workspace-write`)는 Windows에서 Git Bash 실행 자체를 막는다(`CreateFileMapping ... Win32 error 5`). 네트워크만 여는 설정으로는 풀리지 않는다. 영상 작업에서만 샌드박스를 끄는 프로필 파일 `~/.codex/video.config.toml`을 만든다. `-p video`를 주면 기본 설정 위에 이 파일을 덮어쓴다(codex-cli 0.164 기준).

```bash
printf 'sandbox_mode = "danger-full-access"\n' > ~/.codex/video.config.toml
```

```bash
codex -p video                       # 영상 작업 세션
codex exec -p video "..."            # 비대화 실행
```

샌드박스를 끄면 Codex가 PC 전체에 쓰고 명령을 실행할 수 있다. 전역 기본값으로 두지 않고 프로필로만 켠다. 대화 중에는 `/permissions`(버전에 따라 `/approvals`)에서 Full Access로 바꿔도 된다. Linux, macOS는 기본 샌드박스로 돈다(실행은 확인하지 않음).

## MCP 직접 등록

```bash
# Codex
codex mcp add <이름> -- <명령> [인자...]          # stdio
codex mcp add <이름> --env KEY=VALUE -- <명령>     # 환경변수
codex mcp add <이름> --url https://.../mcp        # HTTP
codex mcp login <이름>                             # OAuth
codex mcp list | get <이름> | remove <이름>

# Claude
claude mcp add -s user <이름> -- <명령> [인자...]
claude mcp add -s user -e KEY=VALUE <이름> -- <명령>
claude mcp add -s user -t http <이름> https://.../mcp
claude mcp list | remove <이름> -s user
```

Windows 에서 `npx` 를 못 찾으면 명령 앞에 `cmd /c` 를 붙인다.

## 이전 버전

이론 가이드(master-guide, unified, local-harness, setup-guide)는 삭제했다. 필요하면 git 히스토리에서 꺼낸다.
