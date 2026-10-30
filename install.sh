#!/usr/bin/env bash
# 사용법: ./install.sh claude|codex
# 덮어쓰기 전에 기존 파일은 <파일>.bak-<시각> 으로 백업한다.
# settings.json / hooks.json 은 덮어쓰지 않고 기존 내용에 병합한다.
set -euo pipefail

target="${1:-}"
repo="$(cd "$(dirname "$0")" && pwd)"
stamp="$(date +%Y%m%d-%H%M%S)"
# 훅 커맨드에 들어갈 홈 경로. Git Bash 에서는 C:/Users/... 형태로 바꾼다.
home_path="$(cygpath -m "$HOME" 2>/dev/null || echo "$HOME")"

# 실제로 실행되는 python 을 고른다 (Windows 의 python3 스토어 스텁, Linux 의 python 부재 대응).
py=""
for c in python3 python; do
  if "$c" -c 'import sys' >/dev/null 2>&1; then py="$c"; break; fi
done
if [ -z "$py" ]; then
  echo "python 을 찾을 수 없다. 훅이 python 으로 실행되므로 먼저 설치할 것." >&2
  exit 1
fi

backup() {
  if [ -e "$1" ]; then
    mv "$1" "$1.bak-$stamp"
    echo "  backup: $1.bak-$stamp"
  fi
}

install_file() {  # $1 원본, $2 대상
  mkdir -p "$(dirname "$2")"
  backup "$2"
  cp "$1" "$2"
  echo "  $2"
}

install_json() {  # $1 원본(템플릿), $2 대상. 기존 파일이 있으면 병합한다.
  mkdir -p "$(dirname "$2")"
  existing=""
  if [ -e "$2" ]; then
    # 병합이 실패해도 원본이 남도록 복사로 백업하고, 결과는 임시 파일에 쓴 뒤 교체한다.
    cp "$2" "$2.bak-$stamp"
    echo "  backup: $2.bak-$stamp"
    existing="$2.bak-$stamp"
  fi
  "$py" - "$1" "$2.tmp-$stamp" "$existing" "$home_path" "$py" <<'EOF'
import json, sys
src, dest, existing, home, py = sys.argv[1:]
new = json.loads(open(src, encoding="utf-8").read()
                 .replace("__HOME__", home).replace("__PYTHON__", py))

def drop_old_guard(data):
    # 이전에 설치된 block-dangerous-bash 훅은 새 항목으로 교체한다 (python/python3 차이로 중복 방지).
    for groups in data.get("hooks", {}).values():
        for g in groups:
            g["hooks"] = [h for h in g.get("hooks", [])
                          if "block-dangerous-bash" not in h.get("command", "")]
        groups[:] = [g for g in groups if g["hooks"]]

def merge(old, add):
    # dict 는 재귀 병합, list 는 없는 항목만 추가, 값은 기존 것을 유지한다.
    if isinstance(old, dict) and isinstance(add, dict):
        for k, v in add.items():
            old[k] = merge(old[k], v) if k in old else v
        return old
    if isinstance(old, list) and isinstance(add, list):
        return old + [x for x in add if x not in old]
    return old

if existing:
    old = json.load(open(existing, encoding="utf-8-sig"))
    drop_old_guard(old)
    data = merge(old, new)
else:
    data = new
with open(dest, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
EOF
  mv "$2.tmp-$stamp" "$2"
  echo "  $2${existing:+ (merged)}"
}

install_skills() {  # $1 스킬 설치 폴더
  mkdir -p "$1"
  # 스킬 폴더 안에 백업을 두면 같은 이름의 스킬이 중복 로드되므로 바깥에 둔다.
  backup_dir="$1/../skills-backup-$stamp"
  for skill in "$repo"/skills/core/*/; do
    name="$(basename "$skill")"
    if [ -e "$1/$name" ]; then
      mkdir -p "$backup_dir"
      mv "$1/$name" "$backup_dir/$name"
      echo "  backup: $backup_dir/$name"
    fi
    cp -r "$skill" "$1/$name"
    echo "  $1/$name"
  done
}

case "$target" in
  claude)
    dir="$HOME/.claude"
    install_file "$repo/claude/CLAUDE.md" "$dir/CLAUDE.md"
    install_json "$repo/claude/settings.json" "$dir/settings.json"
    install_file "$repo/claude/hooks/block-dangerous-bash.py" "$dir/hooks/block-dangerous-bash.py"
    install_skills "$dir/skills"
    ;;
  codex)
    dir="$HOME/.codex"
    install_file "$repo/codex/AGENTS.md" "$dir/AGENTS.md"
    install_json "$repo/codex/hooks.json" "$dir/hooks.json"
    install_file "$repo/codex/hooks/block-dangerous-bash.py" "$dir/hooks/block-dangerous-bash.py"
    install_skills "$HOME/.agents/skills"
    ;;
  *)
    echo "usage: $0 claude|codex" >&2
    exit 1
    ;;
esac

echo "done. MCP 등록은 $repo/$target/mcp.sh 실행"
