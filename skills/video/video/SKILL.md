---
name: video
description: "Video Producer. 프로젝트 폴더, 글, README 같은 자료를 읽고 소개 영상을 기획서부터 렌더, 소리, 인코딩, 썸네일 루프, 자체 검사까지 만들 때 사용. 트리거: 영상 만들어줘, 소개 영상, 인트로 영상, 프로젝트 영상, 썸네일 영상."
role: Video Producer
triggers:
  - "영상 만들어줘"
  - "소개 영상"
  - "인트로 영상"
  - "썸네일 영상"
inputs:
  - 자료 경로 (프로젝트 폴더, 글, README)
  - (있으면) <작업 루트>/feedback.md
outputs:
  - treatment.md (기획서)
  - intro.src.html, intro.html
  - intro.mp4, intro-poster.jpg, thumb.mp4, thumb-poster.jpg
chains_to:
  - video-review
guardrails:
  - "단계마다 검사를 통과해야 다음 단계로 간다."
  - "자료 원본과 저장소는 읽기만 하고, 작업 폴더는 그 바깥에 둔다."
  - "평가는 다른 세션에 맡긴다. 자기 평가로 대신하지 않는다."
  - "자기가 띄운 프로세스 PID만 종료한다."
---

# Video Producer

`$V`는 이 SKILL.md가 있는 폴더다(Claude: `~/.claude/skills/video`, Codex: `~/.agents/skills/video`).
명령마다 셸 상태가 이어지지 않는 환경에서는 매 명령 앞에 `V=~/.claude/skills/video;`(Codex는 `V=~/.agents/skills/video;`)를 붙인다.

## 폴더
- 작업 루트: 영상 작업 폴더들을 담는 상위 폴더. 자료 저장소 바깥에 둔다. 영상이 하나여도 `<작업 루트>/<영상 이름>/` 구조로 만든다.
- 작업 루트에는 `feedback.md`(`templates/feedback.md` 양식)를 둔다. 시작할 때 읽고, 새 피드백을 거기 쌓는다.

## 먼저 읽을 것
1. `references/principles.md`: 피드백에서 나온 원칙 67개. 모든 단계의 기준이다.
2. `references/copy.md`: 헤드라인과 설명 문장, 머무는 시간, 속도 규칙.
3. `references/styles.md`: 설명 모양 목록과 글꼴 표.
4. `references/production.md`: 명령과 절차 전체.
5. `<작업 루트>/feedback.md`.
6. 기준 예제 `templates/intro.src.html`: 규약과 원칙을 지키는 방식의 모범이다. 겉모습의 모범은 아니다.
   - 따를 것: `seek(v)` 규약, 속도 곡선(`KN`, `Vt`, `Wv`), 설명의 머무는 시간 계산, 루프 구간의 주기 맞추기와 경계 속도 잇기, `blurAt`, `window.THUMB`/`POSTER`, 소리의 샘플 반올림과 여유 게인.
   - 따르지 말 것(매번 새로 고른다): 형식, 구도, 바탕 톤, 색, 글꼴, 설명 모양, 엔딩(P23~P26, styles.md). 예제의 점·선반·원 그림, 어두운 설명 상자, 원으로 밀려 들어가는 엔딩을 그대로 쓰지 않는다.

## 흐름
| 단계 | 하는 일 | 넘어가는 조건 |
|---|---|---|
| 0 준비 | `bash "$V/scripts/doctor.sh"` | "준비 완료" |
| 1 기획 | 자료를 끝까지 읽고 `templates/treatment.md`로 기획서 작성 | 자체 검사와 평가 통과 |
| 2 페이지 | 기준 예제를 바탕으로 장면 구현, `fonts.py embed`, `render.mjs --stills`로 장면마다 확인 | 겹침, 잘림, 폴백, 빈 화면 없음 |
| 3 렌더 | 초안(서브프레임 1) → 타일 확인 → 마스터(서브프레임 12~16) | 초안 타일에서 결함 없음 |
| 4 소리 | `buildAudio(ctx)` 합성, `audio.mjs`와 `declick.py`로 확인 | 잘림 없음, 클릭 0 |
| 5 마무리 | `node "$V/scripts/render.mjs" intro.html --info`로 썸네일 구간을 spec 블록에 옮기고 `VS_SPEC=treatment.md bash "$V/scripts/finish.sh" work/master.mp4 intro.html .` | check.sh 전 항목 통과 |
| 6 검사 | 타일 전체, 원본 크기 프레임, 이음새, "쓰지 않을 것" 대조 | 자체 판정 통과 |
| 7 평가 | 다른 세션의 `video-review` (아래) | "통과"일 때만 사용자에게 보고 |
| 8 피드백 반영 | 사용자 피드백을 feedback.md에 쌓고, 두 번 이상 반복된 것을 원칙으로 올린다(production.md "피드백 반영") | 기록 완료 |

평가가 "위험"이나 "보통"이면 지적을 고치고 그 단계부터 다시 검사한다.

0단계에서 bash가 `CreateFileMapping ... Win32 error 5`로 죽으면 Windows Codex 샌드박스 때문이다. 우회하지 말고 멈춘 뒤, 사용자에게 `codex -p video`(README "Windows에서 Codex로 쓸 때")로 다시 실행해 달라고 요청한다.

## 멈추는 곳
- 기획서: 기본은 기획서를 사용자에게 보여 주고(경로와 요약) 질문 없이 계속 진행한다. 사용자가 "기획서 보고 정하자"처럼 확인을 요청했을 때만 승인을 기다린다.
- 평가: 반드시 다른 세션이 한다. 자기 평가로 대신하지 않는다.
  - Claude: 별도 에이전트를 띄워 `video-review` 스킬로 평가를 맡긴다. 작업 폴더와 기획서 경로만 넘기고 만든 쪽의 판단은 넘기지 않는다.
  - Codex: `codex` CLI가 있으면 새 세션을 띄운다. Codex 세션 안의 샌드박스(네트워크 꺼짐, `~/.codex` 쓰기 제한)에서는 실패할 수 있으므로 샌드박스 밖 실행 승인을 요청해(escalation) 돌린다.
    ```bash
    codex exec --ephemeral -C "<작업 폴더>" -s workspace-write --skip-git-repo-check -o "<작업 폴더>/work/review.md" '$video-review .'
    ```
    Windows에서는 `-s workspace-write` 대신 `-p video`를 쓴다(그 샌드박스에서는 check.sh가 돌지 않는다).
    `review.md` 첫 줄의 판정을 읽는다. `codex`가 없거나 실행이 실패하면 멈추고, 사용자에게 새 세션에서 `$video-review <작업 폴더>`를 실행해 달라고 요청한다. 자기 평가로 대신하지 않는다.

## 사양 기본값
본편 intro.mp4 1280×720 30fps, 분당 8MB 이하, faststart, AAC 48kHz, -16 LUFS, -1 dBTP 이하, 2초 넘는 멈춤 0건.
썸네일 thumb.mp4 1200×630 무음 루프(본편과 같은 fps), 400KB 이하, -g 30, 이음새 끊김 없음. 포스터 1280×720 150KB, 1200×630 100KB 이하.
기획서의 `spec` 블록(`VS_SPEC=treatment.md`)이나 `VS_` 접두사 환경 변수(예: `VS_FPS=60`)로 바꾼다(`scripts/spec.sh`).

## 하지 않을 것
- 기획서 없이 바로 렌더
- 제작 중에 확정된 화면 문구 바꾸기(바꿔야 하면 이유를 보고, P67)
- 프레임 단위 지시(몇 초에 몇 px)로 기획서 채우기
- 평가를 거치지 않은 결과를 사용자에게 보여 주기
- 이름으로 node, chrome, ffmpeg 프로세스를 한꺼번에 끄기
