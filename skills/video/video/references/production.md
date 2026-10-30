# 제작 절차

`$V`는 이 스킬 폴더다(Claude: `~/.claude/skills/video`, Codex: `~/.agents/skills/video`). 명령은 Git Bash(Windows) 또는 bash(Linux, macOS)에서 돌린다.
명령마다 셸 상태가 이어지지 않는 환경에서는 매 명령 앞에 `V=~/.claude/skills/video;`(Codex는 `V=~/.agents/skills/video;`)를 붙인다.
아래 `python`은 doctor.sh가 알려 주는 실제 실행 파일이다(Linux, macOS는 보통 `python3`).

## 0. 준비

```bash
bash "$V/scripts/doctor.sh"          # 빠진 것과 설치 방법을 알려 준다
```
- Windows의 Codex는 기본 샌드박스에서 Git Bash를 띄우지 못한다(`CreateFileMapping ... Win32 error 5`). 이 오류가 나면 멈추고 사용자에게 `codex -p video`로 다시 실행해 달라고 요청한다(하네스 README "Windows에서 Codex로 쓸 때").
- 처음 한 번
  - `cd "$V" && npm ci && npx playwright install chromium` (Linux는 `npx playwright install --with-deps chromium`. node 20 이상)
  - `python3 -m pip install fonttools brotli`. Linux, macOS는 가상환경을 권한다: `python3 -m venv ~/.venvs/video && . ~/.venvs/video/bin/activate`
  - (선택) `motion.py`를 쓰려면 `python3 -m pip install opencv-python-headless numpy`
  - `python3 "$V/scripts/fonts.py" get Pretendard 900 600`
- 스킬을 다시 설치하면 이전 폴더가 백업으로 옮겨지므로 `npm ci`를 다시 한다. 글꼴은 `~/.cache/video-skill/fonts`(또는 `VIDEO_FONTS`)에 저장되므로 그대로 남는다.
- 디스크 여유를 본다. 1분짜리 1080p 마스터와 중간 파일이 수 GB를 쓴다.

폴더
- 자료(프로젝트 폴더, 저장소)는 읽기만 한다. 작업 루트와 작업 폴더는 언제나 자료 바깥에 만든다.
- 작업 루트: 영상 작업 폴더들을 담는 상위 폴더. 영상이 하나여도 `<작업 루트>/<영상 이름>/`으로 만든다.
- 작업 루트에 `feedback.md`(`$V/templates/feedback.md` 복사)를 둔다.
```
<작업 루트>/
  feedback.md
<작업 루트>/<영상 이름>/            작업 폴더
  treatment.md       기획서 ($V/templates/treatment.md 복사)
  intro.src.html     페이지 소스 ($V/templates/intro.src.html 복사)
  intro.html         글꼴을 넣은 빌드본
  assets/            크롭과 가림을 끝낸 실물 자료
  work/              master.mp4, 소리 중간 파일, 확인용 이미지
  check/             check.sh가 만든 이미지
  intro.mp4  intro-poster.jpg  thumb.mp4  thumb-poster.jpg
```
시작 전에 feedback.md를 읽고, 새 피드백은 날짜와 함께 거기 쌓는다(P66).

## 1. 자료 읽기와 기획

- 자료(README, 글, 코드 폴더, 결과 이미지)를 처음부터 끝까지 읽는다. 원본은 읽기만 한다. 저장소에서 git pull, 커밋, 수정, 실행을 하지 않는다. GitHub 자료는 `gh api`로 받는다.
- 영상에 쓸 실물 자료(스크린샷, 렌더, 데모 화면)를 찾고, 가릴 것을 목록으로 만든다(P21, P22).
- `templates/treatment.md` 양식으로 기획서를 쓴다. 장면표의 화면 문구는 실제로 나갈 문구 그대로 쓴다(copy.md).
- 검사: 아래 "기획서 자체 검사"를 통과하고, 다른 세션의 `video-review`로 평가받는다(7절 "평가 맡기기").
- 통과한 기획서를 사용자에게 보여 준다(P62). 기본은 보여 주고 질문 없이 계속 진행한다. 사용자가 "기획서 보고 정하자"처럼 확인을 요청했을 때만 승인을 기다린다.

기획서 자체 검사
- 원칙 P1~P22를 한 줄씩 대조했는가(특히 지어낸 수치, 실명, 연속 카운터, 범위와 부딪치는 단어).
- 헤드라인 3~5개, 12자 안팎인가. 설명 문장이 copy.md 규칙을 지키는가.
- 썸네일 구간이 본편 시간과 맞고, 이음새 처리와 가운데 880px 안의 내용이 적혀 있는가.
- 형식, 엔딩, 바탕 톤이 같은 작업 루트의 다른 편과 겹치지 않는가.

## 2. 페이지 만들기 (intro.src.html)

`$V/templates/intro.src.html`은 기준 예제다(가상의 도구 소개, 약 24.6초, 장면 5개). 규약과 원칙을 지키는 방식의 모범이지 겉모습의 모범이 아니다. 화면 문구는 확정된 기획서 문구를 그대로 쓴다(P67).
- 따를 것: `seek(v)` 규약, 속도 곡선(`KN`, `Vt`, `Wv`), 설명의 머무는 시간 계산, 루프 구간의 주기 맞추기와 경계 속도 잇기, `blurAt`, `window.THUMB`/`POSTER`, 소리의 샘플 반올림과 여유 게인.
- 따르지 말 것(매번 새로 고른다): 형식, 구도, 바탕 톤, 색, 글꼴, 설명 모양, 엔딩(P23~P26, styles.md). 예제의 점·선반·원 그림, 어두운 설명 상자, 원으로 밀려 들어가는 엔딩을 그대로 쓰지 않는다.

규약(예제 머리 주석과 같다)
- 모든 프레임은 `seek(v)`의 순수 함수다. CSS transition·animation, setTimeout, Date.now, Math.random을 쓰지 않는다. 난수는 `rnd(i)`처럼 시드로 만든다.
- `window.VIDEO = { w, h, duration }`. 무대는 1920×1080을 권한다(720p 출력의 1.5배라 글자 크기 계산이 쉽다).
- 시간은 둘이다. 이야기 시간 t(장면표 기준)와 영상 시간 v. 속도 곡선 `KN`이 둘을 잇는다. 설명의 머무는 시간과 소리는 영상 시간으로 잡는다.
- 글꼴은 `@font-face`에 `/*FONT:이름-굵기*/` 자리를 두고 `fonts.py embed`로 넣는다. 글자를 바꾸면 다시 embed 한다(쓴 글자만 서브셋으로 들어간다).
- 실물 이미지는 `assets/...` 상대 경로로 쓴다. 렌더러는 `file://`로 연다.
- `window.blurAt(v)`(선택): 그 순간 화면이 프레임당 8px 넘게 움직이면 true. 템플릿은 카메라 속도로 계산한다.
- `window.buildAudio(ctx)`: 아래 4절.
- `window.THUMB = [시작, 끝]`, `window.POSTER`: 썸네일 루프 구간과 포스터 시각(영상 초). `node "$V/scripts/render.mjs" intro.html --info`가 길이와 함께 spec 줄로 출력하니 기획서 spec 블록에 옮긴다. 루프 구간의 주기 운동은 모두 구간 길이로 나누어떨어지게 하고(P54), 루프에 들어가고 나오는 카메라는 루프 경계의 속도와 같은 방향, 같은 속도로 잇는다(예제의 `herm`).

확인 루프(렌더 전)
```bash
python "$V/scripts/fonts.py" embed intro.src.html intro.html
node "$V/scripts/render.mjs" intro.html work/stills.jpg --stills 0.5,3,6.2,9,12   # 장면마다 한 장 이상
node "$V/scripts/render.mjs" intro.html work/full --frames 6.2,9                     # 원본 크기 PNG
```
- 장면마다, 헤드라인과 설명이 다 들어온 순간마다 한 장씩 직접 본다. 겹침, 잘림, 글꼴 폴백(render.mjs가 멈춘다), 빈 화면을 고친다.
- 브라우저로 `intro.html`을 열면 실시간 재생, `intro.html?t=6.2`는 그 시각에 멈춘다.

## 3. 렌더

```bash
# 초안: 서브프레임 없이 빠르게 전체를 보고 타일로 확인
node "$V/scripts/render.mjs" intro.html work/draft.mp4 30 1 2
# (선택) 이동량을 재서 블러 구간을 고른다(P46). opencv-python-headless, numpy 필요
python "$V/scripts/motion.py" work/draft.mp4 work/fast.json
# 마스터: 빠른 프레임만 서브프레임 12, 나머지는 한 장 재사용
VS_FAST=work/fast.json node "$V/scripts/render.mjs" intro.html work/master.mp4 30 12 2
```
- 인자: fps, 서브프레임, 워커 수. `VS_FAST`가 없으면 페이지의 `blurAt`, 그것도 없으면 모든 프레임에 블러를 준다.
- 같은 PC에서 다른 렌더가 돌면 워커를 2 이하로 둔다.
- 타이밍이 그대로이고 일부 장면만 바뀌었으면 그 구간만 다시 렌더해 이어 붙인다.
  ```bash
  VS_RANGE=300,420 node "$V/scripts/render.mjs" intro.html work/r_300_420.mp4 30 12 2
  # 마스터의 0..299, 새 300..419, 마스터의 420.. 을 trim + concat 필터로 잇는다
  ```
- 오래 걸리는 렌더는 백그라운드로 돌리고 끝날 때까지 기다린다. Claude는 가능하면 백그라운드 실행과 완료 알림을 쓰고, 그렇지 않은 환경에서는 로그 파일을 보며 기다린다. 기다리는 스크립트에는 시간 제한을 둔다.

## 4. 소리

`buildAudio(ctx)`는 OfflineAudioContext(48kHz, 길이 = VIDEO.duration)에 음악과 효과음을 예약한다.
- 모든 시작 시각을 `Math.round(t * sr) / sr`로 반올림한다(P58).
- 이야기 사건에 맞춘 효과음은 `Vt(t)`로 영상 시간에 옮긴다. 설명이 떠 있는 동안 음악을 조금 낮춘다(duck).
- 효과음 레벨을 고르게 잡고(P59), 마지막 출력 앞에 컴프레서와 여유 게인(0.6 안팎)을 둔다(P60).
- 설명 모양마다 그 모양다운 소리를 만든다(styles.md). 노이즈 버퍼, 필터, 짧은 사인·사각파로 대부분 된다.
- 확인: `node "$V/scripts/audio.mjs" intro.html work/mix.wav`(최대값이 1.0을 넘으면 경고), `python "$V/scripts/declick.py" work/mix.wav`(남은 클릭 수).

## 5. 마무리

기획서 끝의 `spec` 블록에 썸네일 구간(`render.mjs --info` 출력)과 바꿀 사양을 적고 돌린다.
```bash
node "$V/scripts/render.mjs" intro.html --info
VS_SPEC=treatment.md bash "$V/scripts/finish.sh" work/master.mp4 intro.html .
```
- 사양 값은 spec 블록에서는 접두사 없이(`FPS=60`), 환경 변수로는 `VS_` 접두사로(`VS_FPS=60`) 준다. 셸에 원래 있던 `W`, `CRF` 같은 변수는 쓰지 않는다. 우선순위는 환경 변수, spec 블록, 기본값 순이다.
- 소리: 음량 측정, 목표 LUFS로 게인, 4배 오버샘플 리미터, AAC 인코딩 뒤 다시 재서 맞춘다.
- 본편: 1280×720으로 줄여 CRF 인코딩. 분당 용량을 넘으면 2패스 비트레이트로 다시 한다.
- 포스터 2장: JPEG 품질을 낮춰 가며 용량 안에 넣는다.
- 썸네일: 구간을 1200×630 비율로 가운데를 잘라 무음, -g 30, 양 끝 1초에 비트를 더 준다. 용량을 넘으면 CRF를 2씩 올린다. spec 블록에 `SEAM_XF=0.3`을 주면 끝 0.3초를 시작 직전 프레임 쪽으로 섞어 이음새를 잇는다.
- 끝에 check.sh를 돌린다.
- 이미 만든 영상을 고칠 때는 덮어쓰기 전에 `intro-prev.mp4`, `intro.src-prev.html`, `thumb-prev.mp4`처럼 백업한다. 썸네일은 그 구간의 그림이나 헤드라인이 바뀌었을 때만 다시 만든다.

## 6. 검사

```bash
bash "$V/scripts/check.sh" .           # 통과/실패 출력, 실패가 있으면 exit 1
```
check.sh가 재는 것: 해상도, fps, 코덱, 분당 용량, faststart, 샘플레이트, 음량(LUFS), true peak, 2초 멈춤, 썸네일 크기·무음·용량·키프레임 간격·루프 이음새(SSIM), 썸네일 처음/끝 프레임과 마스터의 같은 시각 비교(P55, finish.sh가 `MASTER`를 넘길 때), 포스터 크기와 용량.

눈으로 볼 것(check/ 폴더)
- `tiles_NN.jpg` 전부: 잘림, 겹침, 교차 페이드 글자, 4겹 글자, 빈 화면, 흰 번쩍임, 밝기 튐, 글꼴 폴백, 남은 상태 표시.
- 빠른 이동 구간과 헤드라인·설명 구간은 원본 크기 프레임으로: `ffmpeg -ss 12.3 -i intro.mp4 -frames:v 1 work/f.png`.
- `thumb-seam.jpg`(끝 3장과 처음 3장), `thumb-safe.jpg`(가운데 880px), `thumb-400.jpg`(400px 축소본).
- 기획서 "쓰지 않을 것"을 한 줄씩 대조한다.

## 7. 평가 맡기기

평가는 반드시 만든 쪽과 다른 세션이 한다(P64). 자기 평가로 대신하지 않는다. 평가가 "통과"일 때만 사용자에게 보고한다.
- Claude: 별도 에이전트를 띄워 `video-review` 스킬로 평가를 맡긴다. 작업 폴더와 기획서 경로만 넘기고, 만든 쪽의 판단이나 결론은 넘기지 않는다.
- Codex: `codex` CLI가 있으면 새 세션을 띄운다.
  ```bash
  codex exec --ephemeral -C "<작업 폴더>" -s workspace-write --skip-git-repo-check -o "<작업 폴더>/work/review.md" '$video-review .'
  ```
  - Codex 세션 안에서 띄우면 샌드박스(네트워크 꺼짐, `~/.codex` 쓰기 제한) 때문에 실패할 수 있다. 이 명령은 샌드박스 밖 실행 승인을 요청해(escalation) 돌린다.
  - Windows에서는 `-s workspace-write` 대신 `-p video`를 쓴다. 그 샌드박스에서는 Git Bash가 돌지 않아 check.sh가 실패한다.
  - `--ephemeral`은 평가 세션 기록을 디스크에 남기지 않는다. `-s workspace-write`는 check.sh가 `check/` 이미지를 쓰기 때문이다. `'$video-review .'`는 작은따옴표로 감싸 셸이 `$`를 풀지 않게 한다.
  - 끝나면 `work/review.md` 첫 줄의 판정을 읽는다.
  - `codex`가 없거나 실행이 실패하면 멈추고, 사용자에게 새 세션에서 `$video-review <작업 폴더>`를 실행해 달라고 요청한다. 자기 평가로 대신하지 않는다.
- 기획서만 평가할 때도 같은 방법으로 부르고, 프롬프트에 `기획서 평가`를 덧붙인다.

## 8. 피드백 반영

1. 사용자 피드백과 평가 지적을 `<작업 루트>/feedback.md` "기록"에 날짜와 함께 적는다. 받은 말에 가깝게 쓰고, 무엇을 바꿨는지 함께 적는다.
2. 두 번 이상 반복해서 나온 것은 같은 파일의 "이 작업 루트의 원칙"으로 올린다(한 줄 원칙과 이유 한 줄).
3. 다른 프로젝트에도 통할 원칙이면 하네스 저장소의 `skills/video/video/references/principles.md`에 새 번호로 추가하고 이유를 붙인다. 평가 항목이면 `skills/video/video-review/references/rubric.md`에도 넣는다. 저장소에서 `./install.sh claude` 또는 `./install.sh codex`로 다시 깐다.
4. 하네스 저장소를 고칠 수 없는 환경이면 올릴 원칙 문장을 보고에 "하네스 반영 제안"으로 적는다.

## 프로세스와 파일 관리

- 렌더 프로세스를 멈출 때는 자기가 띄운 PID만 종료한다. 이름(node, chrome, ffmpeg)으로 한꺼번에 끄지 않는다. 명령줄에 자기 작업 폴더 경로가 있는지 확인한 뒤 끈다.
- 다른 작업의 폴더는 읽지도 건드리지도 않는다.
- 중간 PNG와 조각 파일은 다 쓰면 자기가 만든 파일만 지정해서 지운다.
- 여러 편을 만들 때 Claude는 가능하면 편마다 에이전트를 나눠 병렬로 돌린다. 동시에 6개 이하로 두고, 사용량 한도나 연결 문제로 멈추면 파일이 남아 있으니 그 에이전트를 이어서 시킨다. 병렬이 안 되는 환경(Codex 등)에서는 한 편씩 끝낸다.

## 보고 형식 (한국어, 짧게)

- 산출물 경로와 크기, check.sh 결과
- 기획서와 달라진 점과 이유
- 설명 표: 장면, 이름, 두 줄, 자료 근거, 고치기 전과 후
- 확인하지 못한 것, 남은 약점
- 확인용 프레임 시점 3개
