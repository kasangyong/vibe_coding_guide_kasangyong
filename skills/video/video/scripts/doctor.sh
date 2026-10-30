#!/usr/bin/env bash
# doctor.sh: 영상 스킬에 필요한 도구가 있는지 보고, 빠진 것과 설치 방법을 출력한다. 빠진 필수 항목이 있으면 exit 1.
#   bash doctor.sh
set -uo pipefail
S="$(cd "$(dirname "$0")" && pwd)"
V="$(cd "$S/.." && pwd)"
. "$S/spec.sh"
miss=0
have() { printf '있음  %s\n' "$1"; }
lack() { printf '없음  %s\n      -> %s\n' "$1" "$2"; miss=$((miss + 1)); }
opt() { printf '선택  %s\n      -> %s\n' "$1" "$2"; }
case "$(uname -s 2>/dev/null)" in
  Linux*) os=linux ;; Darwin*) os=mac ;; *) os=win ;;
esac
py=$(pick_python) || py=""
pyc=${py:-python3}
pipcmd="$pyc -m pip install"
[ "$os" = win ] || pipcmd="$pyc -m pip install (가상환경 권장: $pyc -m venv ~/.venvs/video && . ~/.venvs/video/bin/activate)"

# node, npm (playwright 1.64는 node 20 이상)
if command -v node >/dev/null 2>&1; then
  nv=$(node -v | tr -d 'v\r'); major=${nv%%.*}
  if [ "$major" -ge 20 ]; then have "node $nv"; else lack "node $nv (20 이상 필요)" "https://nodejs.org 에서 LTS 설치"; fi
else lack "node" "https://nodejs.org 에서 LTS(20 이상) 설치"; fi
command -v npm >/dev/null 2>&1 && have "npm $(npm -v 2>/dev/null | tr -d '\r')" || lack "npm" "node 와 함께 설치된다"

# playwright 패키지와 크로미움(실제로 띄워 본다)
pwinst="npx playwright install chromium"
[ "$os" = linux ] && pwinst="npx playwright install --with-deps chromium"
if (cd "$V" && node --input-type=module -e "await import('playwright')" >/dev/null 2>&1); then
  have "playwright $(cd "$V" && node -p "require('playwright/package.json').version" 2>/dev/null | tr -d '\r')"
  if (cd "$V" && node --input-type=module -e "const {chromium}=await import('playwright'); const b=await chromium.launch(); await b.close();" >/dev/null 2>&1); then
    have "chromium (playwright)"
  else lack "chromium (playwright)" "cd \"$V\" && $pwinst"; fi
else
  lack "playwright (npm 패키지)" "cd \"$V\" && npm ci && $pwinst"
fi

# ffmpeg, ffprobe, 필요한 인코더와 필터
case "$os" in
  win) ffhint="winget install Gyan.FFmpeg" ;; mac) ffhint="brew install ffmpeg" ;; *) ffhint="sudo apt install ffmpeg (또는 배포판 패키지)" ;;
esac
if command -v ffmpeg >/dev/null 2>&1 && command -v ffprobe >/dev/null 2>&1; then
  have "$(ffmpeg -hide_banner -version | head -1 | cut -d' ' -f1-3)"
  enc=$(ffmpeg -hide_banner -encoders 2>/dev/null); flt=$(ffmpeg -hide_banner -filters 2>/dev/null)
  for e in libx264 aac; do grep -q " $e " <<<"$enc" || lack "ffmpeg 인코더 $e" "libx264 가 들어간 빌드로 설치: $ffhint"; done
  bad=""
  for f in tmix ebur128 alimiter freezedetect ssim tile blend drawbox aresample; do grep -q " $f " <<<"$flt" || bad="$bad $f"; done
  [ -z "$bad" ] && have "ffmpeg 필터 (tmix ebur128 alimiter freezedetect ssim tile blend drawbox)" || lack "ffmpeg 필터:$bad" "full 빌드로 다시 설치: $ffhint"
else
  lack "ffmpeg / ffprobe" "$ffhint"
fi

# python, fontTools, brotli
if [ -n "$py" ]; then
  have "python $("$py" -c 'import sys; print(sys.version.split()[0])' | tr -d '\r') ($py)"
  "$py" -c 'import fontTools' >/dev/null 2>&1 && have "fontTools" || lack "fontTools (글꼴 서브셋)" "$pipcmd fonttools brotli"
  "$py" -c 'import brotli' >/dev/null 2>&1 && have "brotli (woff2)" || lack "brotli (woff2 저장)" "$pipcmd brotli"
  "$py" -c 'import cv2, numpy' >/dev/null 2>&1 && have "opencv, numpy (motion.py)" || opt "opencv, numpy (motion.py, 이동량으로 블러 구간 고르기)" "$pipcmd opencv-python-headless numpy"
else
  case "$os" in
    win) lack "python" "https://www.python.org 에서 설치(스토어 스텁이 아닌 실제 설치본)" ;;
    mac) lack "python3" "brew install python" ;;
    *) lack "python3" "sudo apt install python3 python3-venv python3-pip" ;;
  esac
fi

# 글꼴
fd=$("$pyc" -c "import os; print(os.environ.get('VIDEO_FONTS') or os.path.join(os.path.expanduser('~'), '.cache', 'video-skill', 'fonts'))" 2>/dev/null | tr -d '\r')
if [ -n "$fd" ] && ls "$fd" 2>/dev/null | grep -qiE '\.(ttf|otf|woff2?)$'; then
  have "글꼴 $(ls "$fd" | grep -ciE '\.(ttf|otf|woff2?)$')개 ($fd)"
  for k in Pretendard-900 Pretendard-600; do
    ls "$fd" | grep -q "^$k\." || lack "글꼴 $k (기준 예제)" "$pyc \"$S/fonts.py\" get Pretendard 900 600"
  done
else
  lack "글꼴 (폴더 ${fd:-?} 비어 있음)" "$pyc \"$S/fonts.py\" get Pretendard 900 600   그 밖의 글꼴은 references/styles.md 글꼴 표"
fi

# 디스크
df -h . 2>/dev/null | awk 'NR == 2 {print "정보  디스크 여유 " $4 " (현재 폴더 기준). 1분 영상 렌더에 수 GB를 잡는다"}'

echo
if [ "$miss" = 0 ]; then echo "준비 완료"; else echo "빠진 것 ${miss}개. 위 -> 줄대로 설치한 뒤 다시 실행"; fi
[ "$miss" = 0 ]
