// audio.mjs: 페이지의 window.buildAudio(ctx)를 OfflineAudioContext에서 돌려 48 kHz 16비트 스테레오 WAV로 저장한다.
//   node audio.mjs page.html out.wav
// buildAudio는 받은 ctx(길이 = VIDEO.duration)에 음악과 효과음을 예약한다. 시각은 영상 시간(초)이다.
import { chromium } from 'playwright';
import { writeFileSync } from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const [html, out] = process.argv.slice(2);
if (!html || !out) { console.log('usage: node audio.mjs page.html out.wav'); process.exit(1); }
const b = await chromium.launch({ args: ['--allow-file-access-from-files'] });
const page = await b.newPage();
await page.goto(pathToFileURL(path.resolve(html)).href + '?render' + (process.env.VS_QS || ''), { timeout: 180000 });
await page.waitForFunction(() => window.VIDEO, null, { timeout: 60000 });
if (!await page.evaluate(() => typeof window.buildAudio === 'function')) {
  console.error('window.buildAudio(ctx) 가 없다. 소리를 페이지에서 합성해야 한다(references/production.md 소리 절).');
  await b.close(); process.exit(2);
}
const b64 = await page.evaluate(async () => {
  const sr = 48000, dur = window.VIDEO.duration, ctx = new OfflineAudioContext(2, Math.ceil(sr * dur), sr);
  await window.buildAudio(ctx);
  const buf = await ctx.startRendering(), L = buf.getChannelData(0), R = buf.getChannelData(buf.numberOfChannels > 1 ? 1 : 0);
  let peak = 0; for (let i = 0; i < L.length; i++) peak = Math.max(peak, Math.abs(L[i]), Math.abs(R[i]));
  const i16 = new Int16Array(L.length * 2);
  for (let i = 0; i < L.length; i++) { i16[2 * i] = Math.max(-1, Math.min(1, L[i])) * 32767; i16[2 * i + 1] = Math.max(-1, Math.min(1, R[i])) * 32767; }
  const u8 = new Uint8Array(i16.buffer); let s = '';
  for (let i = 0; i < u8.length; i += 0x8000) s += String.fromCharCode.apply(null, u8.subarray(i, i + 0x8000));
  window.__peak = peak;
  return btoa(s);
});
const peak = await page.evaluate(() => window.__peak);
const pcm = Buffer.from(b64, 'base64'), h = Buffer.alloc(44);
h.write('RIFF', 0); h.writeUInt32LE(36 + pcm.length, 4); h.write('WAVEfmt ', 8); h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(2, 22);
h.writeUInt32LE(48000, 24); h.writeUInt32LE(192000, 28); h.writeUInt16LE(4, 32); h.writeUInt16LE(16, 34); h.write('data', 36); h.writeUInt32LE(pcm.length, 40);
writeFileSync(out, Buffer.concat([h, pcm]));
await b.close();
// 1.0을 넘으면 int16에서 잘린다. 믹스 끝에 게인을 낮춰 여유를 둔다.
console.log(`audio -> ${out}  peak ${peak.toFixed(3)}${peak > 1 ? '  (1.0 초과: 잘림. 마스터 게인을 낮출 것)' : ''}`);
