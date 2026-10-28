// Render the animation to video (or stills) with headless Chromium + ffmpeg.
//   node render.js                 -> out/brave_little_shrimp.mp4 (1080x1920, 60 fps, with audio)
//   node render.js --fps 30        -> lower frame rate
//   node render.js --stills 0.5,3,8 -> PNG stills in out/stills/
const { chromium } = require('playwright');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const opt = (name, def) => { const i = args.indexOf(`--${name}`); return i >= 0 ? args[i + 1] : def; };
const FPS = Number(opt('fps', 60));
const WORKERS = Number(opt('workers', 4));
const DUR = 30;
const ROOT = __dirname;
const OUT = path.join(ROOT, 'out');
fs.mkdirSync(OUT, { recursive: true });
const pageUrl = 'file://' + path.join(ROOT, 'index.html') + '?render=1';

async function openPage(browser) {
  const page = await browser.newPage({ viewport: { width: 1080, height: 1920 } });
  await page.goto(pageUrl);
  await page.evaluate(() => window.whenReady());
  return page;
}
const grab = (page, t, type, q) => page.evaluate(([t, type, q]) => {
  window.renderFrame(t);
  return document.getElementById('stage').toDataURL(type, q).split(',')[1];
}, [t, type, q]);

function run(cmd, argv, stdinStream) {
  return new Promise((resolve, reject) => {
    const p = spawn(cmd, argv, { stdio: [stdinStream ? 'pipe' : 'ignore', 'ignore', 'inherit'] });
    p.on('error', reject);
    p.on('close', code => (code === 0 ? resolve() : reject(new Error(`${cmd} exited ${code}`))));
    if (stdinStream) stdinStream(p.stdin);
  });
}

async function stills(browser, times) {
  const dir = path.join(OUT, 'stills');
  fs.mkdirSync(dir, { recursive: true });
  const page = await openPage(browser);
  for (const t of times) {
    const b64 = await grab(page, t, 'image/png');
    const f = path.join(dir, `t${t.toFixed(2).padStart(5, '0')}.png`);
    fs.writeFileSync(f, Buffer.from(b64, 'base64'));
    console.log(f);
  }
}

async function segment(browser, idx, f0, f1) {
  const page = await openPage(browser);
  const file = path.join(OUT, `seg${idx}.mp4`);
  await run('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'mjpeg', '-i', '-',
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '16', '-pix_fmt', 'yuv420p', '-r', String(FPS), file], async stdin => {
    for (let f = f0; f < f1; f++) {
      const buf = Buffer.from(await grab(page, f / FPS, 'image/jpeg', 0.95), 'base64');
      if (!stdin.write(buf)) await new Promise(r => stdin.once('drain', r));
      if ((f - f0) % 120 === 0) console.log(`worker ${idx}: frame ${f}/${f1}`);
    }
    stdin.end();
  });
  await page.close();
  return file;
}

(async () => {
  const browser = await chromium.launch();
  try {
    const st = opt('stills');
    if (st) { await stills(browser, st.split(',').map(Number)); return; }
    const total = DUR * FPS, per = Math.ceil(total / WORKERS);
    const t0 = Date.now();
    const files = await Promise.all(Array.from({ length: WORKERS }, (_, i) => segment(browser, i, i * per, Math.min(total, (i + 1) * per))));
    const list = path.join(OUT, 'segments.txt');
    fs.writeFileSync(list, files.map(f => `file '${f}'`).join('\n'));
    const audio = path.join(ROOT, 'audio', 'soundtrack.wav');
    const final = path.join(OUT, 'brave_little_shrimp.mp4');
    const av = fs.existsSync(audio) ? ['-i', audio, '-c:a', 'aac', '-b:a', '256k', '-shortest'] : [];
    await run('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', list, ...av, '-c:v', 'copy', '-movflags', '+faststart', final]);
    files.forEach(f => fs.unlinkSync(f)); fs.unlinkSync(list);
    console.log(`done: ${final} in ${((Date.now() - t0) / 1000).toFixed(0)}s`);
  } finally {
    await browser.close();
  }
})().catch(e => { console.error(e); process.exit(1); });
