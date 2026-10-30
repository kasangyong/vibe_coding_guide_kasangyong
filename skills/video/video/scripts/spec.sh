# spec.sh: 산출물 사양. finish.sh, check.sh, doctor.sh 가 source 한다.
# 모든 값은 VS_ 접두사 변수로 쓴다(셸에 원래 있던 W, H, CRF 같은 변수와 섞이지 않게).
# 우선순위: 환경 변수 VS_<키> > 기획서 ```spec 블록의 <키>(VS_SPEC=기획서.md 로 지정) > 아래 기본값.
# spec 블록 한 줄은 KEY=VALUE(접두사 없이) 이고 # 뒤는 주석이다. 값에는 영문, 숫자, . _ + - 만 쓴다.

VS_KEYS="W H FPS MB_PER_MIN SR ABR LUFS LUFS_TOL TP_MAX CRF FREEZE_S POSTER_KB TW TH THUMB_KB THUMB_G TCRF SAFE_W TPOSTER_KB SEAM_XF THUMB_START THUMB_END POSTER_T THUMB_POSTER_T"

if [ -n "${VS_SPEC:-}" ]; then
  if [ ! -f "$VS_SPEC" ]; then echo "VS_SPEC 파일이 없다: $VS_SPEC" >&2; exit 1; fi
  while IFS= read -r line; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    case "$line" in
      *=*) k="${line%%=*}"; v="${line#*=}" ;;
      *) continue ;;
    esac
    case " $VS_KEYS " in *" $k "*) ;; *) echo "spec 키 무시(알 수 없는 키): $line" >&2; continue ;; esac
    case "$v" in ''|*[!A-Za-z0-9_.+-]*) echo "spec 값 무시: $line" >&2; continue ;; esac
    eval "cur=\${VS_$k+set}"
    [ -z "$cur" ] && export "VS_$k=$v"
  done <<EOF
$(sed -n '/^```spec/,/^```/p' "$VS_SPEC" | sed '1d;$d')
EOF
fi

# 본편 intro.mp4
: "${VS_W:=1280}" "${VS_H:=720}" "${VS_FPS:=30}"
: "${VS_MB_PER_MIN:=8}"          # 분당 용량 상한(MB = 10^6 바이트)
: "${VS_SR:=48000}" "${VS_ABR:=128k}"
: "${VS_LUFS:=-16}" "${VS_LUFS_TOL:=1}" "${VS_TP_MAX:=-1}"
: "${VS_CRF:=24}"
: "${VS_FREEZE_S:=2}"            # 이 초 이상 멈춘 구간이 있으면 실패
: "${VS_POSTER_KB:=150}"
# 썸네일 thumb.mp4 (무음 루프, 본편과 같은 FPS)
: "${VS_TW:=1200}" "${VS_TH:=630}" "${VS_THUMB_KB:=400}" "${VS_THUMB_G:=30}" "${VS_TCRF:=28}"
: "${VS_SAFE_W:=880}"            # 카드형 목록에서 가운데만 보일 때의 폭
: "${VS_TPOSTER_KB:=100}"
: "${VS_SEAM_XF:=0}"
for k in $VS_KEYS; do export "VS_$k"; done 2>/dev/null

# 값 검사
for k in W H FPS SR POSTER_KB TW TH THUMB_KB THUMB_G SAFE_W TPOSTER_KB; do      # 1 이상의 정수
  eval "v=\$VS_$k"
  case "$v" in ''|*[!0-9]*) echo "사양 오류: $k=$v 는 1 이상의 정수여야 한다" >&2; exit 1 ;; esac
  [ "$v" -ge 1 ] || { echo "사양 오류: $k=$v 는 1 이상이어야 한다" >&2; exit 1; }
done
for k in CRF TCRF; do                                                         # 0~51 정수
  eval "v=\$VS_$k"
  case "$v" in ''|*[!0-9]*) echo "사양 오류: $k=$v 는 0~51 정수여야 한다" >&2; exit 1 ;; esac
  [ "$v" -le 51 ] || { echo "사양 오류: $k=$v 는 51 이하여야 한다" >&2; exit 1; }
done
for k in MB_PER_MIN LUFS LUFS_TOL TP_MAX FREEZE_S SEAM_XF THUMB_START THUMB_END POSTER_T THUMB_POSTER_T; do   # 숫자
  eval "v=\${VS_$k:-}"
  [ -z "$v" ] && continue
  printf '%s' "$v" | grep -qE '^-?[0-9]+(\.[0-9]+)?$' || { echo "사양 오류: $k=$v 는 숫자여야 한다" >&2; exit 1; }
done
for k in MB_PER_MIN FREEZE_S; do                                              # 0보다 큰 수
  eval "v=\$VS_$k"
  awk "BEGIN{exit !($v > 0)}" || { echo "사양 오류: $k=$v 는 0보다 커야 한다" >&2; exit 1; }
done
case "$VS_ABR" in [1-9]*[0-9]k|[1-9]k) ;; *) echo "사양 오류: ABR=$VS_ABR 는 128k 처럼 써야 한다" >&2; exit 1 ;; esac

# 썸네일 자르기: 가운데를 TW:TH 비율로 잘라 TW x TH 로 줄인다(finish.sh, check.sh 공용)
VS_THUMB_CROP="crop='min(iw,ih*${VS_TW}/${VS_TH})':'min(ih,iw*${VS_TH}/${VS_TW})',scale=${VS_TW}:${VS_TH}:flags=lanczos:out_range=tv"

# 실제로 실행되는 python 을 고른다(Windows 스토어 스텁, python3 부재 대응).
pick_python() {
  for c in python3 python py; do
    if "$c" -c 'import sys' >/dev/null 2>&1; then echo "$c"; return 0; fi
  done
  return 1
}
