# vibe_coding_guide

Claude Code / Codex 공용 로컬 하네스. 전역 규칙, 기본 스킬 4개, 위험 명령 차단 훅, MCP 등록 스크립트를 담는다.

## 구조

```
skills/core/     plan-eng · build · review · careful   (두 도구 공용 SKILL.md)
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
