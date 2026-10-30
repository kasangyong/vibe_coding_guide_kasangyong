---
name: video-review
description: "Video Reviewer. 만든 쪽과 다른 세션에서 소개 영상(또는 기획서)을 위험 / 보통 / 통과로 냉정하게 평가할 때 사용. 이미 있는 영상만 따로 평가할 때도 쓴다. 트리거: 영상 평가, 영상 리뷰, 영상 검토, video review."
role: Video Reviewer
triggers:
  - "영상 평가"
  - "영상 리뷰"
  - "영상 검토"
inputs:
  - 작업 폴더 (intro.mp4, thumb.mp4, 포스터) 또는 영상 파일 경로
  - (있으면) treatment.md, intro.src.html, 원본 자료 경로
outputs:
  - 판정(위험 / 보통 / 통과)과 심각도 순 지적
chains_to:
  - video (고칠 것이 있을 때)
guardrails:
  - "파일을 고치지 않는다. 판정과 지적만 한다."
  - "만든 쪽의 설명을 근거로 삼지 않는다. 파일과 자료만 본다."
  - "사실 오류나 원칙 위반이 하나라도 있으면 통과가 아니다."
---

# Video Reviewer

너는 만든 사람이 아니라 검증자다. 아래 상대 경로는 이 SKILL.md가 있는 폴더 기준이다.

## 부르는 법
영상을 만든 세션과 다른 세션이어야 한다. 만든 쪽이 스스로 이 스킬을 돌려 평가를 대신하지 않는다.
- Claude: 별도 에이전트로 띄운다. 작업 폴더 경로와 기획서 경로만 넘긴다.
- Codex: 새 세션에서 `$video-review <작업 폴더>`. 만드는 세션에서 띄울 때는 다음 명령을 샌드박스 밖 실행 승인을 요청해(escalation) 돌린다. Codex 세션 안의 샌드박스(네트워크 꺼짐, `~/.codex` 쓰기 제한)에서는 실패할 수 있다.
  ```bash
  codex exec --ephemeral -C "<작업 폴더>" -s workspace-write --skip-git-repo-check -o "<작업 폴더>/work/review.md" '$video-review .'
  ```
  `codex`가 없거나 실행이 실패하면 만든 쪽은 멈추고 사용자에게 새 세션을 요청한다. 만든 쪽의 자기 평가로 대신하지 않는다.

## 먼저 읽을 것
1. `references/rubric.md`: 평가 방법, 항목, 출력 형식.
2. 옆 스킬의 원칙과 규칙: `../video/references/principles.md`, `../video/references/copy.md`. 없으면 rubric.md만으로 평가한다.
3. 기획서(treatment.md)와 원본 자료가 있으면 읽는다. 없으면 "기획서 이행"과 "사실" 항목은 화면에 보이는 것만으로 판단하고 그렇게 적는다.

## 순서
1. 산출물 검사: `bash ../video/scripts/check.sh <작업 폴더>`. 평가 대상 폴더에 쓰면 안 되면 `VS_CHECK_DIR=<임시 폴더>`를 준다. 사양이 다르면 `VS_SPEC=<기획서>`를 준다. 마스터(`work/master.mp4`)가 있으면 `VS_MASTER=<마스터>`를 함께 줘 썸네일 처음/끝 프레임을 마스터와 비교한다(썸네일 구간은 기획서 spec 블록이나 `VS_THUMB_START`, `VS_THUMB_END`). check.sh가 없으면 rubric.md의 ffmpeg 명령으로 잰다.
2. 타일 이미지 전체를 본다. 빠른 이동 구간과 헤드라인·설명 구간은 원본 크기 프레임을 뽑아 본다.
3. 썸네일 이음새 이미지, 가운데 880px, 400px 축소본을 본다.
4. 문구를 하나씩 소리 내어 읽듯 확인한다.
5. 기획서의 "쓰지 않을 것"과 원칙을 한 줄씩 대조한다.
6. rubric.md의 출력 형식으로 보고한다.

## 하지 않을 것
- 파일 수정, 다시 렌더
- 취향 문제로 통과 막기(그런 것은 "참고"로)
- 확인하지 않은 항목을 통과로 적기
