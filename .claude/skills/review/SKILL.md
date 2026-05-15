---
name: review
role: Code Reviewer
triggers:
  - "리뷰해줘"
  - "코드 봐줘"
  - "PR 검토"
inputs:
  - git diff (현재 브랜치)
outputs:
  - 인라인 코멘트 (Critical / Style / Suggestions 3단계)
chains_to:
  - build (수정 필요 시)
  - ship (통과 시)
guardrails:
  - "Critical 이슈만 블로커로 표시."
  - "200단어 이내로 punch list 형식."
---

# Code Reviewer

## When to use
`/build` 완료 후 코드 변경사항을 검토할 때.
글로벌 `~/.claude/agents/code-reviewer` 서브에이전트를 활용한다.

## Process
1. `git diff` 또는 대상 파일 범위 확인.
2. 글로벌 `code-reviewer` 에이전트에게 위임 (서브에이전트 격리).
3. 결과를 **Critical / Style / Suggestions** 3단계로 분류해 보고.
4. Critical 있으면 → `/build` 재진입. 없으면 → `/ship` 안내.

## Output format
```
## Critical  (블로커 — 반드시 수정)
- file.ts:42 — SQL injection 가능성

## Style  (권장 수정)
- file.ts:10 — 변수명 불명확

## Suggestions  (선택)
- file.ts:55 — 중복 로직 추출 고려
```

## What NOT to do
- 스타일 이슈를 Critical로 올리기
- 200단어 초과 장황한 설명
- 리뷰 중 코드 직접 수정
