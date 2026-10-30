// render.mjs: seek(t) 페이지를 프레임 단위로 찍어 무음 mp4로 만든다. 서브프레임 모션 블러(180도 셔터) 포함.
//   node render.mjs page.html out.mp4 [fps=30] [subframes=1] [workers=2]
//   node render.mjs page.html sheet.jpg --stills 0.5,1.2,3     원본 크기 프레임 묶음(확인용)
//   node render.mjs page.html outdir --frames 0.5,1.2           원본 크기 PNG를 한 장씩
//   node render.mjs page.html --info                            길이, window.THUMB, window.POSTER 와 기획서 spec 줄을 출력
// 환경 변수
//   VS_RANGE=a,b    프레임 a..b-1만 렌더한다(부분 재렌더). 결과는 out.mp4 하나.
//   VS_FAST=f.json  서브프레임을 쓸 프레임 번호 목록(motion.py 결과). 없으면 페이지의 window.blurAt(t), 그것도 없으면 모든 프레임.
//   VS_QS=&story    페이지 주소에 덧붙일 쿼리.
//   VS_ALLOW_FALLBACK=1  글꼴이 안 불러져도 계속한다(기본은 멈춘다).
// 페이지 규약: window.VIDEO = { w, h, duration }, window.seek(t). 같은 t면 같은 그림.
import { chromium } from 'playwright';
import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync, rmSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const [html, out, a3, a4, a5] = process.argv.slice(2);
if (!html || !out) {
  console.log('usage: node render.mjs page.html out.mp4 [fps=30] [subframes=1] [workers=2]\n       node render.mjs page.html sheet.jpg --stills t1,t2,...\n       node render.mjs page.html outdir --frames t1,t2,...\n       node render.mjs page.html --info');
  process.exit(1);
}
const run = (args) => new Promise((res, rej) => {
  const p = spawn('ffmpeg', args, { stdio: 'inherit' });
  p.on('close', c => c ? rej(new Error('ffmpeg exit ' + c)) : res());
});
const url = pathToFileURL(path.resolve(html)).href + '?render' + (process.env.VS_QS || '');
const browser = await chromium.launch({ args: ['--allow-file-access-from-files'] });

async function openPage(V) {
  const page = await browser.newPage(V ? { viewport: { width: V.w, height: V.h }, deviceScaleFactor: 1 } : {});
  const errs = [];
  page.on('pageerror', e => errs.push(String(e)));
  await page.goto(url, { timeout: 180000 });
  await page.waitForFunction(() => window.VIDEO && typeof window.seek === 'function', null, { timeout: 60000 })
    .catch(() => { throw new Error('window.VIDEO / window.seek 가 없다. ' + errs.join(' | ')); });
  // t=0에 숨은 장면의 글꼴까지 전부 불러 둔다
  const bad = await page.evaluate(async () => {
    await Promise.all([...document.fonts].map(f => f.load().catch(() => {})));
    await document.fonts.ready;
    return [...document.fonts].filter(f => f.status !== 'loaded').map(f => f.family);
  });
  if (bad.length) {
    console.error('글꼴을 못 불러왔다(폴백 사용):', [...new Set(bad)].join(', '), '- fonts.py embed 로 넣었는지 확인');
    if (!process.env.VS_ALLOW_FALLBACK) process.exit(2);
  }
  if (errs.length) console.warn('페이지 오류:', errs.join(' | '));
  return page;
}
const shot = async (page, t, type = 'jpeg') => {
  for (let i = 0; ; i++) {
    try {
      await page.evaluate(t => window.seek(t), t);
      return await page.screenshot(type === 'png' ? { type: 'png', timeout: 120000 } : { type: 'jpeg', quality: 95, timeout: 120000 });
    } catch (e) { if (i >= 3) throw e; console.warn('다시 찍음', t, String(e).slice(0, 80)); }
  }
};

// 크기를 먼저 읽고, 모든 페이지를 정확히 그 크기로 연다(불러올 때 크기를 재는 페이지도 맞게).
const probe = await openPage(null);
const V = await probe.evaluate(() => window.VIDEO);
if (out === '--info') {
  const I = await probe.evaluate(() => ({ thumb: window.THUMB || null, poster: window.POSTER ?? null }));
  await browser.close();
  console.log(JSON.stringify({ w: V.w, h: V.h, duration: V.duration, thumb: I.thumb, poster: I.poster }));
  console.log('# 기획서 spec 블록에 옮길 값');
  if (I.thumb) console.log(`THUMB_START=${I.thumb[0]}\nTHUMB_END=${I.thumb[1]}`);
  else console.log('# window.THUMB 이 없다. 페이지에 썸네일 루프 구간 [시작, 끝](영상 초)을 정해 둘 것');
  if (I.poster != null) console.log(`POSTER_T=${I.poster}`);
  process.exit(0);
}
await probe.close();

if (a3 === '--stills' || a3 === '--frames') {
  const page = await openPage(V);
  const times = String(a4).split(',').map(Number);
  const dir = a3 === '--frames' ? out : out + '.frames';
  mkdirSync(dir, { recursive: true });
  for (let i = 0; i < times.length; i++) {
    const name = a3 === '--frames' ? `t${times[i].toFixed(3)}.png` : `${String(i).padStart(3, '0')}.jpg`;
    writeFileSync(path.join(dir, name), await shot(page, times[i], a3 === '--frames' ? 'png' : 'jpeg'));
  }
  await browser.close();
  if (a3 === '--stills') {
    const cols = Math.min(3, times.length), rows = Math.ceil(times.length / cols);
    await run(['-v', 'error', '-y', '-framerate', '1', '-i', `${dir}/%03d.jpg`, '-vf', `scale=${Math.min(960, V.w)}:-1,tile=${cols}x${rows}:padding=6:color=gray`, '-frames:v', '1', out]);
    rmSync(dir, { recursive: true });
  }
  console.log(times.length, 'frames ->', out);
  process.exit(0);
}

mkdirSync(path.dirname(path.resolve(out)), { recursive: true });
const fps = +(a3 || 30), sub = Math.max(1, +(a4 || 1)), workers = Math.max(1, +(a5 || 2));
const N = Math.round(V.duration * fps);
const [F0, F1] = process.env.VS_RANGE ? process.env.VS_RANGE.split(',').map(Number) : [0, N];
const FAST = process.env.VS_FAST ? new Set(JSON.parse(readFileSync(process.env.VS_FAST, 'utf8'))) : null;
const base = out.replace(/\.mp4$/, '');
// 한 출력 프레임 = 서브프레임 sub장 평균. tmix 뒤 묶음의 마지막 프레임만 남긴다.
const vf = sub > 1 ? ['-vf', `tmix=frames=${sub},select='eq(mod(n\\,${sub})\\,${sub - 1})',setpts=N/(${fps}*TB)`] : [];
const t0 = Date.now(); let done = 0;
const per = Math.ceil((F1 - F0) / workers), segs = [];
console.log(`${V.w}x${V.h} ${fps}fps frames ${F0}..${F1 - 1} sub=${sub} workers=${workers}`);
await Promise.all(Array.from({ length: workers }, async (_, w) => {
  const a = F0 + w * per, b = Math.min(F1, a + per); if (a >= b) return;
  const seg = `${base}_seg${w}.mp4`; segs[w] = seg;
  const page = await openPage(V);
  const hasBlurAt = await page.evaluate(() => typeof window.blurAt === 'function');
  const ff = spawn('ffmpeg', ['-v', 'error', '-y', '-f', 'image2pipe', '-framerate', String(fps * sub), '-i', '-', ...vf,
    '-r', String(fps), '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '16', '-preset', 'medium', seg], { stdio: ['pipe', 'inherit', 'inherit'] });
  const closed = new Promise(r => ff.on('close', r));
  // ffmpeg가 먼저 죽으면 stdin 쓰기가 EPIPE를 낸다. 처리되지 않은 오류로 멈추지 않게 받고, 아래에서 종료 코드로 알린다.
  let pipeErr = null;
  ff.stdin.on('error', e => { pipeErr = e; });
  // 버퍼가 빌 때까지 기다리되, ffmpeg가 먼저 끝나도 풀린다. 쓰고 난 리스너는 떼어 쌓이지 않게 한다.
  const waitDrain = () => new Promise(r => {
    const done = () => { ff.stdin.off('drain', done); ff.off('close', done); r(); };
    ff.stdin.once('drain', done); ff.once('close', done);
  });
  for (let f = a; f < b && !pipeErr; f++) {
    let fast = sub > 1;
    if (fast && FAST) fast = FAST.has(f);
    else if (fast && hasBlurAt) fast = await page.evaluate(t => !!window.blurAt(t), f / fps);
    let one = null;
    for (let s = 0; s < sub; s++) {   // 느린 프레임은 한 장을 서브프레임 수만큼 되풀이한다
      const buf = fast || !one ? await shot(page, (f + (fast ? (s / sub) * 0.5 : 0)) / fps) : one;
      if (!fast) one = buf;
      if (pipeErr) break;
      if (!ff.stdin.write(buf)) await waitDrain();
    }
    if (++done % 60 === 0) console.log(`${done}/${F1 - F0} frames  ${((Date.now() - t0) / 1000).toFixed(0)}s`);
  }
  ff.stdin.end();
  const code = await closed; await page.close();
  if (code !== 0 || pipeErr) throw new Error(`세그먼트 ${w} (프레임 ${a}..${b - 1}) ffmpeg 종료 코드 ${code}${pipeErr ? ', ' + pipeErr.code : ''}`);
}));
await browser.close();
const list = base + '_segs.txt';
writeFileSync(list, segs.filter(Boolean).map(s => `file '${path.resolve(s).replace(/\\/g, '/')}'`).join('\n'));
await run(['-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', list, '-c', 'copy', out]);
segs.filter(Boolean).forEach(s => rmSync(s)); rmSync(list);
console.log(`video -> ${out}  (${F1 - F0} frames, ${((Date.now() - t0) / 1000).toFixed(0)}s)`);
