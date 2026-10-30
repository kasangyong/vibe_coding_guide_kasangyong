# motion.py: 프레임 간 이동량을 재서 서브프레임(모션 블러)을 쓸 프레임 번호를 고른다. 선택 도구(opencv-python, numpy 필요).
#   python motion.py draft.mp4 fast.json [threshold_px=8]
# draft.mp4는 서브프레임 1로 빠르게 뽑은 렌더. 이동량은 1080 높이 기준 px/프레임으로 환산한다.
# 이동량 상위 0.2% 값이 기준을 넘는 프레임과 그 앞 프레임을 고른다(셔터가 f에서 열려 f..f+1을 덮으므로).
# 결과를 render.mjs에 VS_FAST=fast.json 으로 넘긴다. 손으로 빠른 구간을 고르지 않는다.
import sys, json
import cv2
import numpy as np

src, out = sys.argv[1], sys.argv[2]
th = float(sys.argv[3]) if len(sys.argv) > 3 else 8.0
cap = cv2.VideoCapture(src)
fps = cap.get(cv2.CAP_PROP_FPS) or 30
prev, mags, k = None, [], 1.0
while True:
    ok, fr = cap.read()
    if not ok:
        break
    h, w = fr.shape[:2]
    sw = 480; sh = max(2, round(h * sw / w))
    k = 1080 / sh
    g = cv2.cvtColor(cv2.resize(fr, (sw, sh), interpolation=cv2.INTER_AREA), cv2.COLOR_BGR2GRAY)
    if prev is None:
        mags.append(0.0); prev = g; continue
    diff = cv2.absdiff(g, prev) > 6
    if diff.sum() < 4:
        mags.append(0.0); prev = g; continue
    flow = cv2.calcOpticalFlowFarneback(prev, g, None, 0.5, 4, 21, 3, 7, 1.5, 0)
    m = np.hypot(flow[..., 0], flow[..., 1])[diff] * k
    mags.append(float(np.percentile(m, 99.8)))
    prev = g
mags = np.array(mags)
fast = set()
for i, v in enumerate(mags):
    if v > th:
        fast.update([i - 1, i])
fast = sorted(x for x in fast if x >= 0)
json.dump(fast, open(out, 'w'))
print('frames', len(mags), 'fast', len(fast), 'max', round(float(mags.max()) if len(mags) else 0, 1), 'px/frame')
runs, s = [], None
for i in range(len(mags)):
    f = mags[i] > th
    if f and s is None:
        s = i
    if not f and s is not None:
        runs.append((s, i - 1)); s = None
if s is not None:
    runs.append((s, len(mags) - 1))
print('fast runs (s):', ' '.join(f'{a / fps:.2f}-{b / fps:.2f}' for a, b in runs[:100]))
