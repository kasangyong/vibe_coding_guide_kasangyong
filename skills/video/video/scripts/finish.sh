#!/usr/bin/env bash
# finish.sh: 무음 마스터 + 페이지 소리 -> 산출물 4개, 끝에 check.sh.
#   bash finish.sh master.mp4 intro.html [outdir=.]
# 산출물: intro.mp4(본편, 소리), intro-poster.jpg, thumb.mp4(무음 루프), thumb-poster.jpg. 중간 파일은 outdir/work/.
# 사양: VS_SPEC=기획서.md 로 기획서의 ```spec 블록을 읽는다. 환경 변수는 VS_ 접두사로 준다(scripts/spec.sh).
# 이 스크립트만 쓰는 값(spec 블록에서는 접두사 없이):
#   THUMB_START, THUMB_END   썸네일 루프 구간(영상 초). 필수. 페이지 값은 render.mjs --info 로 본다.
#   POSTER_T                 본편 포스터 시각(기본: 길이의 40%)
#   THUMB_POSTER_T           썸네일 포스터 시각(기본: 썸네일 구간 가운데)
#   SEAM_XF                  썸네일 마지막 몇 초를 시작 직전 프레임 쪽으로 섞어 이음새를 잇는다(기본 0 = 끔)
# 환경 변수만:
#   VS_LIMIT                 리미터 시작값(선형, 기본 0.85). true peak가 넘치면 자동으로 낮춘다.
#   VS_NO_AUDIO=1            소리 없이 만든다(확인용. check.sh 소리 항목은 실패한다)
# 소리: audio.mjs -> declick.py -> 목표 LUFS로 게인 -> 4배 오버샘플 리미터 -> AAC. AAC 인코딩 뒤 수치를 다시 재서 맞춘다.
# 본편: 분당 용량을 넘으면 2패스 비트레이트로 다시 인코딩한다.
set -euo pipefail
S="$(cd "$(dirname "$0")" && pwd)"
. "$S/spec.sh"

master="${1:-}"; page="${2:-}"; out="${3:-.}"
if [ -z "$master" ] || [ -z "$page" ]; then sed -n '2,15p' "$0"; exit 2; fi
[ -f "$master" ] || { echo "마스터 파일이 없다: $master" >&2; exit 1; }
[ -f "$page" ] || { echo "페이지 파일이 없다: $page" >&2; exit 1; }
: "${VS_THUMB_START:?썸네일 시작 초: 기획서 spec 블록의 THUMB_START 또는 VS_THUMB_START 로 정할 것}"
: "${VS_THUMB_END:?썸네일 끝 초: THUMB_END 또는 VS_THUMB_END 로 정할 것}"
wk="$out/work"; mkdir -p "$wk"
calc() { awk "BEGIN{print $*}"; }
is() { [ "$(awk "BEGIN{print (($*) ? 1 : 0)}")" = 1 ]; }
size() { wc -c < "$1" | tr -d ' '; }
loud() { ffmpeg -hide_banner -nostats -i "$1" -vn -af ebur128=peak=true -f null - 2>&1 | tr -d '\r' | awk '/^ *I:/{i=$2} /^ *Peak:/{p=$2} END{print i, p}'; }
dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$master" | tr -d '\r')
: "${VS_POSTER_T:=$(calc "$dur * 0.4")}"
: "${VS_THUMB_POSTER_T:=$(calc "($VS_THUMB_START + $VS_THUMB_END) / 2")}"

# 시각 검사: 모두 영상 길이 안이어야 한다
is "$VS_THUMB_START >= 0 && $VS_THUMB_START < $VS_THUMB_END && $VS_THUMB_END <= $dur + 0.001" ||
  { echo "썸네일 구간 오류: THUMB_START=$VS_THUMB_START THUMB_END=$VS_THUMB_END, 마스터 길이 ${dur}초. 0 <= 시작 < 끝 <= 길이 여야 한다" >&2; exit 1; }
is "$VS_POSTER_T >= 0 && $VS_POSTER_T < $dur" || { echo "POSTER_T=$VS_POSTER_T 가 마스터 길이 ${dur}초 밖이다" >&2; exit 1; }
is "$VS_THUMB_POSTER_T >= 0 && $VS_THUMB_POSTER_T < $dur" || { echo "THUMB_POSTER_T=$VS_THUMB_POSTER_T 가 마스터 길이 ${dur}초 밖이다" >&2; exit 1; }
VF="scale=${VS_W}:${VS_H}:flags=lanczos:out_range=tv,fps=${VS_FPS},format=yuv420p"

echo "== 본편 영상 (${dur}초)"
ffmpeg -v error -y -i "$master" -an -vf "$VF" -c:v libx264 -preset slow -crf "$VS_CRF" -color_range tv -pix_fmt yuv420p "$wk/v.mp4"
abr_k=${VS_ABR%k}
limit=$(calc "int($VS_MB_PER_MIN * 1e6 * $dur / 60)")
need=$(calc "$(size "$wk/v.mp4") + $abr_k * 1000 / 8 * $dur")
if is "$need > $limit"; then
  kbps=$(calc "int($limit * 0.95 * 8 / $dur / 1000 - $abr_k)")
  echo "  CRF ${VS_CRF}가 분당 ${VS_MB_PER_MIN}MB를 넘는다 -> 2패스 ${kbps}k"
  ffmpeg -v error -y -i "$master" -an -vf "$VF" -c:v libx264 -preset slow -b:v "${kbps}k" -pass 1 -passlogfile "$wk/x264" -color_range tv -pix_fmt yuv420p -f null -
  ffmpeg -v error -y -i "$master" -an -vf "$VF" -c:v libx264 -preset slow -b:v "${kbps}k" -pass 2 -passlogfile "$wk/x264" -color_range tv -pix_fmt yuv420p "$wk/v.mp4"
  rm -f "$wk"/x264*
fi

if [ "${VS_NO_AUDIO:-0}" = 1 ]; then
  ffmpeg -v error -y -i "$wk/v.mp4" -c copy -movflags +faststart "$out/intro.mp4"
else
  echo "== 소리"
  py=$(pick_python) || { echo "python 이 없다" >&2; exit 1; }
  node "$S/audio.mjs" "$page" "$wk/mix.wav"
  "$py" "$S/declick.py" "$wk/mix.wav" "$wk/mix-dc.wav"
  read -r i0 _ <<<"$(loud "$wk/mix-dc.wav")"
  g=$(calc "$VS_LUFS - ($i0)"); lim=${VS_LIMIT:-0.85}
  for pass in 1 2 3 4 5 6; do
    ffmpeg -v error -y -i "$wk/mix-dc.wav" -af "volume=${g}dB,aresample=192000,alimiter=limit=${lim}:attack=2:release=60:level=false,aresample=${VS_SR}" \
      -c:a aac -b:a "$VS_ABR" -ar "$VS_SR" "$wk/a.m4a"
    read -r li tp <<<"$(loud "$wk/a.m4a")"
    echo "  $pass: gain ${g}dB limit ${lim} -> ${li} LUFS, ${tp} dBTP"
    okl=$(calc "(($li) - ($VS_LUFS) <= 0.4 && ($VS_LUFS) - ($li) <= 0.4) ? 1 : 0")
    okp=$(calc "(($tp) <= ($VS_TP_MAX) - 0.1) ? 1 : 0")
    [ "$okl$okp" = 11 ] && break
    g=$(calc "$g + ($VS_LUFS) - ($li)")
    [ "$okp" = 1 ] || lim=$(awk "BEGIN{l = $lim * 10 ^ ((($VS_TP_MAX) - 0.3 - ($tp)) / 20); if (l < 0.0625) l = 0.0625; printf \"%.4f\", l}")
  done
  ffmpeg -v error -y -i "$wk/v.mp4" -i "$wk/a.m4a" -map 0:v -map 1:a -c copy -shortest -movflags +faststart "$out/intro.mp4"
fi

# JPEG 품질을 낮춰 가며 용량 상한 안에 넣는다
jpg() {  # $1 시각, $2 필터, $3 파일, $4 KB
  for q in 2 3 4 5 6 7 8 10 12 15 20; do
    ffmpeg -v error -y -ss "$1" -i "$master" -frames:v 1 -vf "$2" -q:v "$q" "$3"
    [ "$(size "$3")" -le $(($4 * 1000)) ] && return 0
  done
  echo "  경고: $3 가 ${4}KB를 넘는다" >&2
}
echo "== 포스터"
jpg "$VS_POSTER_T" "scale=${VS_W}:${VS_H}:flags=lanczos" "$out/intro-poster.jpg" "$VS_POSTER_KB"
jpg "$VS_THUMB_POSTER_T" "$VS_THUMB_CROP" "$out/thumb-poster.jpg" "$VS_TPOSTER_KB"

echo "== 썸네일 (${VS_THUMB_START}~${VS_THUMB_END}초, ${VS_FPS}fps)"
td=$(calc "$VS_THUMB_END - $VS_THUMB_START")
nf=$(calc "int($td * $VS_FPS + 0.5)")
# 루프 양 끝 1초에 비트를 더 줘 이음새가 흐려지지 않게 한다
zones="zones=0,$((VS_FPS - 1)),b=1.6/$((nf - VS_FPS)),$((nf - 1)),b=1.6"
[ "$nf" -ge $((VS_FPS * 3)) ] || zones="zones=0,0,b=1"
if is "$VS_SEAM_XF > 0"; then
  tb=$(calc "$VS_THUMB_START - $td")
  is "$tb >= 0" || { echo "SEAM_XF는 THUMB_START가 구간 길이 이상일 때만 쓴다" >&2; exit 1; }
  tx=$(calc "$td - $VS_SEAM_XF")
  # 마지막 프레임(T = td - 1/FPS)에서 섞는 비율이 정확히 1이 되게 한 프레임 당긴다
  mixe="clip((T-${tx}+1/${VS_FPS})/${VS_SEAM_XF},0,1)"
  FG="[0:v]trim=start=${VS_THUMB_START}:end=${VS_THUMB_END},setpts=PTS-STARTPTS,fps=${VS_FPS}[m];[0:v]trim=start=${tb}:end=${VS_THUMB_START},setpts=PTS-STARTPTS,fps=${VS_FPS}[b];[m][b]blend=all_expr='A*(1-${mixe})+B*${mixe}',${VS_THUMB_CROP}[v]"
else
  FG="[0:v]trim=start=${VS_THUMB_START}:end=${VS_THUMB_END},setpts=PTS-STARTPTS,fps=${VS_FPS},${VS_THUMB_CROP}[v]"
fi
crf=$VS_TCRF
while :; do
  ffmpeg -v error -y -i "$master" -filter_complex "$FG" -map "[v]" -an -c:v libx264 -preset slower -crf "$crf" -g "$VS_THUMB_G" \
    -x264-params "$zones" -color_range tv -pix_fmt yuv420p -movflags +faststart "$out/thumb.mp4"
  kbs=$(( $(size "$out/thumb.mp4") / 1000 ))
  echo "  CRF $crf -> ${kbs}KB"
  [ "$kbs" -le "$VS_THUMB_KB" ] && break
  [ "$crf" -ge 40 ] && { echo "  경고: CRF 40에서도 ${VS_THUMB_KB}KB를 넘는다. 구간을 줄이거나 움직임을 줄일 것" >&2; break; }
  crf=$((crf + 2))
done

echo
# check.sh가 썸네일 처음/끝 프레임을 마스터의 같은 시각과 비교하도록 넘긴다(P55)
VS_MASTER="$master" VS_THUMB_START="$VS_THUMB_START" VS_THUMB_END="$VS_THUMB_END" bash "$S/check.sh" "$out"
