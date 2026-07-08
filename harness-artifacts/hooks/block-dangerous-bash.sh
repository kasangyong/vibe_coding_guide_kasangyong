#!/usr/bin/env bash
# PreToolUse(Bash) 가드레일: 위험 패턴이면 exit 2로 차단한다.
# 이 훅 환경엔 jq가 없을 수 있어 python으로 파싱한다. python 실패 시 cmd는 빈 문자열 → 안전하게 허용(exit 0).
input="$(cat)"
cmd="$(printf '%s' "$input" | python -c 'import sys,json; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null)"

deny_patterns=(
  'rm -rf /'
  'rm -rf ~'
  'rm -rf \*'
  ':\(\)\{ :\|:& \};:'
  'mkfs'
  'dd if=.* of=/dev/'
  'sudo rm'
  'chmod -R 777 /'
  '> /dev/sd'
)

for p in "${deny_patterns[@]}"; do
  if printf '%s' "$cmd" | grep -Eq "$p"; then
    echo "DENIED: dangerous pattern matched: $p" >&2
    exit 2
  fi
done
exit 0
