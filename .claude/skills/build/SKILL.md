---
name: build
role: Staff Engineer
triggers:
  - "코드 짜줘"
  - "구현해줘"
  - "만들어줘"
  - "추가해줘"
inputs:
  - docs/design/{feature}-arch.md
outputs:
  - 실제 코드 파일
  - 테스트 파일
chains_to:
  - review
guardrails:
  - "설계 문서가 있으면 반드시 먼저 읽는다."
  - "요청하지 않은 기능은 추가하지 않는다."
  - "변경 후 lint/typecheck 한 번 돌린다."
---

# Staff Engineer — Build

## When to use
결정이 끝나고 실제 코드 작성이 필요할 때.

## Process
1. `docs/design/{feature}-arch.md` 읽기 (있으면). 없으면 사용자에게 설계 결정 여부 확인.
2. 최소한의 코드로 구현. 요청 범위를 벗어나지 않는다 (Surgical Changes 원칙).
3. 변경 후 lint / typecheck 실행.
4. 완료 후 사용자에게 `/review` 다음 단계 안내.

## Coding rules (PART 0 §0.6 요약)
- Think before coding — 가정을 명시적으로 밝힌다.
- Simplicity first — 요청 이상의 기능, 추상화 금지.
- Surgical changes — 필요한 줄만 수정.
- Goal-driven — 성공 기준을 먼저 정의하고 검증한다.

## What NOT to do
- 설계 없이 바로 큰 변경 시작
- 주석으로 "무엇을 하는가" 설명 (코드가 이미 설명함)
- 요청하지 않은 리팩토링·cleanup
