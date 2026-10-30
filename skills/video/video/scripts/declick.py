# declick.py: WebAudio 시작 시각 오차로 생기는 한 샘플짜리 튐을 찾아 이웃 평균으로 바꾼다.
#   python declick.py in.wav out.wav     고치고 남은 수를 보고
#   python declick.py in.wav             세기만
# 튐 기준: 이웃 평균과의 차이가 150 넘고, 양옆 기울기 합(|p - pp| + |nn - n|)의 8배 이상.
# 촘촘한 잡음(종이, 스냅)은 주변이 원래 그만큼 움직이므로 건너뛴다.
import sys, wave, array

w = wave.open(sys.argv[1]); prm = w.getparams(); a = array.array('h', w.readframes(w.getnframes())); w.close()
C = prm.nchannels


def scan(fix):
    hits = []
    for c in range(C):
        for i in range(2 * C + c, len(a) - 2 * C, C):
            pp, p, x, n, nn = a[i - 2 * C], a[i - C], a[i], a[i + C], a[i + 2 * C]
            e = abs(2 * x - p - n) / 2
            if e <= 150 or e < 8 * (abs(p - pp) + abs(nn - n)):
                continue
            nb = [abs(a[k] - a[k - C]) for k in range(max(C, i - 16 * C), min(len(a), i + 17 * C), C) if abs(k - i) > 2 * C]
            if nb and e < 8 * sum(nb) / len(nb):
                continue
            hits.append((c, i // C))
            if fix:
                a[i] = (p + n) // 2
    return hits


if len(sys.argv) > 2:
    h = scan(True); print('fixed', len(h), 'samples')
    o = wave.open(sys.argv[2], 'wb'); o.setparams(prm); o.writeframes(a.tobytes()); o.close()
h = scan(False)
per = [sum(1 for c, _ in h if c == k) for k in range(C)]
print('clicks left per channel', per, [round(i / prm.framerate, 3) for _, i in h[:12]])
