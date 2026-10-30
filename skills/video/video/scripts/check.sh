#!/usr/bin/env bash
# check.sh: 산출물 사양을 검사하고 눈으로 볼 이미지를 만든다. 항목마다 통과/실패, 실패가 하나라도 있으면 exit 1.
#   bash check.sh <폴더>                  폴더의 intro.mp4, thumb.mp4, intro-poster.jpg, thumb-poster.jpg
#   bash check.sh intro.mp4 [thumb.mp4]
# 이미지: VS_CHECK_DIR(기본 <폴더>/check)
#   tiles_NN.jpg      본편 0.25초 간격 타일(한 장 8x6 = 12초)
#   thumb-seam.jpg    위 줄 = 썸네일 끝 3프레임, 아래 줄 = 처음 3프레임(위 줄 오른쪽 끝 -> 아래 줄 왼쪽 끝이 이음새)
#   thumb-safe.jpg    썸네일 네 시점(처음, 1/4, 1/2, 3/4) + 가운데 SAFE_W 폭 표시,  thumb-400.jpg  400px 폭 축소본
# 사양: VS_SPEC=기획서.md 또는 VS_ 접두사 환경 변수(scripts/spec.sh). VS_POSTERS=0 이면 포스터 검사를 건너뛴다.
# VS_MASTER=work/master.mp4 와 썸네일 구간(spec 또는 VS_THUMB_START, VS_THUMB_END)이 있으면
# 썸네일 처음/끝 프레임을 마스터와 비교한다(finish.sh가 넘긴다).
set -uo pipefail
S="$(cd "$(dirname "$0")" && pwd)"
. "$S/spec.sh"

if [ $# -lt 1 ]; then sed -n '2,11p' "$0"; exit 2; fi
if [ -d "$1" ]; then d="$1"; intro="$d/intro.mp4"; thumb="$d/thumb.mp4"
else intro="$1"; d="$(dirname "$1")"; thumb="${2:-$d/thumb.mp4}"; fi
CD="${VS_CHECK_DIR:-$d/check}"
mkdir -p "$CD"

fails=0; n=0
res() {  # $1 1/0, $2 항목, $3 측정값, $4 기준
  n=$((n + 1))
  if [ "$1" = 1 ]; then printf '통과  %s: %s\n' "$2" "$3"
  else printf '실패  %s: %s  (기준 %s)\n' "$2" "$3" "$4"; fails=$((fails + 1)); fi
}
ok() { awk "BEGIN{print (($1) ? 1 : 0)}"; }
probe() { ffprobe -v error -select_streams "$2" -show_entries "$3" -of default=nw=1:nk=1 "$1" 2>/dev/null | head -1 | tr -d '\r'; }
faststart() { ffprobe -v trace -i "$1" 2>&1 | grep -oE "type:'(moov|mdat)'" | head -1 | grep -q moov && echo 1 || echo 0; }
loud() { ffmpeg -hide_banner -nostats -i "$1" -vn -af ebur128=peak=true -f null - 2>&1 | tr -d '\r' | awk '/^ *I:/{i=$2} /^ *Peak:/{p=$2} END{print i, p}'; }
kb() { awk "BEGIN{printf \"%.0f\", $(wc -c < "$1") / 1000}"; }

echo "== 본편 $intro"
if [ ! -f "$intro" ]; then res 0 "intro.mp4" "없음" "파일 있음"; else
  w=$(probe "$intro" v:0 stream=width); h=$(probe "$intro" v:0 stream=height)
  res "$( [ "$w" = "$VS_W" ] && [ "$h" = "$VS_H" ] && echo 1 || echo 0)" "해상도" "${w}x${h}" "${VS_W}x${VS_H}"
  fr=$(probe "$intro" v:0 stream=r_frame_rate); fv=$(awk -F/ '{printf "%.3f", ($2 ? $1 / $2 : $1)}' <<<"$fr")
  res "$(ok "$fv - $VS_FPS < 0.01 && $VS_FPS - $fv < 0.01")" "fps" "$fv" "$VS_FPS"
  codec=$(probe "$intro" v:0 stream=codec_name); pf=$(probe "$intro" v:0 stream=pix_fmt)
  res "$( [ "$codec" = h264 ] && { [ "$pf" = yuv420p ] || [ "$pf" = yuvj420p ]; } && echo 1 || echo 0)" "코덱" "$codec $pf" "h264 yuv420p"
  dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$intro" | tr -d '\r')
  bytes=$(wc -c < "$intro")
  mbpm=$(awk "BEGIN{printf \"%.2f\", $bytes / 1e6 / ($dur / 60)}")
  res "$(ok "$mbpm <= $VS_MB_PER_MIN")" "용량" "${mbpm}MB/분 (총 $(awk "BEGIN{printf \"%.1f\", $bytes / 1e6}")MB, ${dur}초)" "분당 ${VS_MB_PER_MIN}MB 이하"
  res "$(faststart "$intro")" "faststart" "moov $( [ "$(faststart "$intro")" = 1 ] && echo 앞 || echo 뒤)" "moov가 mdat 앞"
  sr=$(probe "$intro" a:0 stream=sample_rate)
  if [ -z "$sr" ]; then res 0 "소리" "음성 트랙 없음" "AAC ${VS_SR}Hz"; else
    res "$( [ "$sr" = "$VS_SR" ] && echo 1 || echo 0)" "샘플레이트" "$sr" "$VS_SR"
    read -r li tp <<<"$(loud "$intro")"
    res "$(ok "$li - ($VS_LUFS) <= $VS_LUFS_TOL && ($VS_LUFS) - $li <= $VS_LUFS_TOL")" "음량" "${li} LUFS" "${VS_LUFS}±${VS_LUFS_TOL}"
    res "$(ok "$tp <= $VS_TP_MAX")" "true peak" "${tp} dBTP" "${VS_TP_MAX} 이하"
  fi
  fz=$(ffmpeg -hide_banner -nostats -i "$intro" -an -vf "freezedetect=n=-60dB:d=${VS_FREEZE_S}" -f null - 2>&1 | tr -d '\r' | grep -oE 'freeze_start: [0-9.]+' | awk '{printf "%s ", $2}')
  res "$( [ -z "$fz" ] && echo 1 || echo 0)" "멈춤(${VS_FREEZE_S}초)" "$( [ -z "$fz" ] && echo 0건 || echo "시작 ${fz}")" "0건"
  rm -f "$CD"/tiles_*.jpg
  ffmpeg -v error -y -i "$intro" -vf "fps=4,scale=320:-1,tile=8x6:padding=2:color=gray" "$CD/tiles_%02d.jpg"
  echo "      타일 $(ls "$CD"/tiles_*.jpg 2>/dev/null | wc -l | tr -d ' ')장 -> $CD/tiles_NN.jpg (한 장 12초, NN번은 12x(NN-1)초부터)"
fi

echo "== 썸네일 $thumb"
if [ ! -f "$thumb" ]; then res 0 "thumb.mp4" "없음" "파일 있음"; else
  w=$(probe "$thumb" v:0 stream=width); h=$(probe "$thumb" v:0 stream=height)
  res "$( [ "$w" = "$VS_TW" ] && [ "$h" = "$VS_TH" ] && echo 1 || echo 0)" "해상도" "${w}x${h}" "${VS_TW}x${VS_TH}"
  na=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$thumb" | wc -l | tr -d ' ')
  res "$( [ "$na" = 0 ] && echo 1 || echo 0)" "무음" "음성 트랙 ${na}개" "0개"
  res "$(ok "$(kb "$thumb") <= $VS_THUMB_KB")" "용량" "$(kb "$thumb")KB" "${VS_THUMB_KB}KB 이하"
  res "$(faststart "$thumb")" "faststart" "moov $( [ "$(faststart "$thumb")" = 1 ] && echo 앞 || echo 뒤)" "moov가 mdat 앞"
  gap=$(ffprobe -v error -select_streams v:0 -show_entries packet=flags -of csv=p=0 "$thumb" | tr -d '\r' |
    awk '{ if (index($0, "K")) { if (NR > 1 && NR - last > g) g = NR - last; last = NR } } END { if (NR - last + 1 > g) g = NR - last + 1; print g + 0 }')
  res "$(ok "$gap <= $VS_THUMB_G")" "키프레임 간격" "최대 ${gap}프레임" "${VS_THUMB_G} 이하(-g ${VS_THUMB_G})"
  nf=$(ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of default=nw=1:nk=1 "$thumb" | tr -d '\r')
  ffmpeg -v error -y -i "$thumb" -frames:v 1 "$CD/_first.png"
  ffmpeg -v error -y -i "$thumb" -vf "select=eq(n\,$((nf - 1)))" -fps_mode passthrough -frames:v 1 "$CD/_last.png"
  seam=$(ffmpeg -hide_banner -i "$CD/_last.png" -i "$CD/_first.png" -lavfi ssim -f null - 2>&1 | tr -d '\r' | grep -oE 'All:[0-9.]+' | tail -1 | cut -d: -f2)
  # 이음새 SSIM 을 썸네일 안의 이웃 프레임 SSIM 분포(하위 10%)와 비교한다
  p10=$(ffmpeg -v error -i "$thumb" -i "$thumb" -filter_complex "[0:v]trim=start_frame=1,setpts=PTS-STARTPTS[a];[1:v]setpts=PTS-STARTPTS[b];[a][b]ssim=shortest=1:stats_file=-" -f null - 2>/dev/null |
    tr -d '\r' | grep -oE 'All:[0-9.]+' | cut -d: -f2 | sort -n | awk '{v[NR] = $1} END {i = int(NR * 0.1); if (i < 1) i = 1; print v[i]}')
  if [ -z "$seam" ] || [ -z "$p10" ]; then res 0 "루프 이음새" "SSIM을 재지 못함(이음새 ${seam:-없음}, 이웃 ${p10:-없음})" "측정 가능"
  else res "$(ok "$seam >= 0.97 || $seam >= $p10 - 0.03")" "루프 이음새" "SSIM ${seam} (이웃 프레임 하위 10% ${p10})" "0.97 이상 또는 이웃 프레임 수준"; fi
  # P55: 썸네일 처음/끝 프레임을 마스터의 같은 시각(같은 자르기)과 비교한다. finish.sh가 MASTER를 넘긴다.
  if [ -n "${VS_MASTER:-}" ] && [ -n "${VS_THUMB_START:-}" ] && [ -n "${VS_THUMB_END:-}" ]; then
    te=$(awk "BEGIN{print $VS_THUMB_END - 1 / $VS_FPS}")
    awk "BEGIN{exit !($VS_SEAM_XF > 0)}" && te=$(awk "BEGIN{print $VS_THUMB_START - 1 / $VS_FPS}")   # 섞은 끝은 시작 직전 프레임과 같아야 한다
    for pair in "처음 $VS_THUMB_START _first" "끝 $te _last"; do
      set -- $pair
      ffmpeg -v error -y -ss "$2" -i "$VS_MASTER" -frames:v 1 -vf "$VS_THUMB_CROP" "$CD/_m.png"
      s=$(ffmpeg -hide_banner -i "$CD/$3.png" -i "$CD/_m.png" -lavfi ssim -f null - 2>&1 | tr -d '\r' | grep -oE 'All:[0-9.]+' | tail -1 | cut -d: -f2)
      res "$(ok "${s:-0} >= 0.95")" "썸네일 $1 프레임 = 마스터" "SSIM ${s:-측정 실패} (마스터 ${2}초)" "0.95 이상"
    done
    rm -f "$CD/_m.png"
  fi
  ffmpeg -v error -y -i "$thumb" -filter_complex "[0:v]split[x][y];[x]select='gte(n\,$((nf - 3)))',scale=400:-1,tile=3x1:padding=4:color=gray[t];[y]select='lt(n\,3)',scale=400:-1,tile=3x1:padding=4:color=gray[b];[t][b]vstack" -frames:v 1 "$CD/thumb-seam.jpg"
  mid=$(awk "BEGIN{print $(ffprobe -v error -show_entries format=duration -of csv=p=0 "$thumb" | tr -d '\r') / 2}")
  # 루프 안 네 시점(처음, 1/4, 1/2, 3/4)에 가운데 SAFE_W 폭을 표시해 2x2로 모은다. 카메라가 움직여도 놓치지 않게.
  q4=$(( nf / 4 ))
  ffmpeg -v error -y -i "$thumb" -vf "select='eq(n\,0)+eq(n\,${q4})+eq(n\,$((q4 * 2)))+eq(n\,$((q4 * 3)))',drawbox=x=(iw-${VS_SAFE_W})/2:y=0:w=${VS_SAFE_W}:h=ih:color=red@0.9:t=4,scale=600:-1,tile=2x2:padding=4:color=gray" -fps_mode passthrough -frames:v 1 "$CD/thumb-safe.jpg"
  ffmpeg -v error -y -ss "$mid" -i "$thumb" -frames:v 1 -vf "scale=400:-1:flags=lanczos" "$CD/thumb-400.jpg"
  rm -f "$CD/_first.png" "$CD/_last.png"
  echo "      이음새/안전 영역 이미지 -> $CD/thumb-seam.jpg, thumb-safe.jpg, thumb-400.jpg"
fi

if [ "${VS_POSTERS:-1}" != 0 ]; then
  echo "== 포스터"
  for spec in "intro-poster.jpg $VS_W $VS_H $VS_POSTER_KB" "thumb-poster.jpg $VS_TW $VS_TH $VS_TPOSTER_KB"; do
    set -- $spec; f="$d/$1"
    if [ ! -f "$f" ]; then res 0 "$1" "없음" "파일 있음"; continue; fi
    w=$(probe "$f" v:0 stream=width); h=$(probe "$f" v:0 stream=height)
    res "$( [ "$w" = "$2" ] && [ "$h" = "$3" ] && echo 1 || echo 0)" "$1 크기" "${w}x${h}" "${2}x${3}"
    res "$(ok "$(kb "$f") <= $4")" "$1 용량" "$(kb "$f")KB" "${4}KB 이하"
  done
fi

echo
if [ "$fails" = 0 ]; then echo "결과: 통과 (${n}항목)"; else echo "결과: 실패 ${fails}건 / ${n}항목"; fi
echo "눈으로 볼 것: 타일 전체(잘림, 겹침, 4겹 글자, 빈 화면, 흰 번쩍임, 글꼴 폴백), 이음새 이미지, 가운데 ${VS_SAFE_W}px, 400px 축소본"
[ "$fails" = 0 ]
