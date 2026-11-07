// Usage:
//   node render.js stills 0.5 2 6.3 ...      -> out/still_<t>.png (quick look)
//   node render.js video [workers]           -> out/silent.mp4
const http = require('http'), fs = require('fs'), path = require('path'), { spawn } = require('child_process');
const { chromium } = require('playwright');
const ROOT = __dirname, OUT = path.join(ROOT, 'out');
fs.mkdirSync(OUT, { recursive: true });
const TL = JSON.parse(fs.readFileSync(path.join(ROOT, 'timeline.json')));
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.woff2': 'font/woff2' };

function serve() {
  return new Promise(res => {
    const srv = http.createServer((req, rsp) => {
      const p = path.join(ROOT, decodeURIComponent(req.url.split('?')[0]));
      if (!p.startsWith(ROOT) || !fs.existsSync(p) || fs.statSync(p).isDirectory()) { rsp.writeHead(404); return rsp.end(); }
      rsp.writeHead(200, { 'Content-Type': MIME[path.extname(p)] || 'application/octet-stream' }); fs.createReadStream(p).pipe(rsp);
    }).listen(0, () => res(srv));
  });
}
async function openPage(port) {
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
  page.on('console', m => { if (m.type() === 'error') console.error('[page]', m.text()); });
  page.on('pageerror', e => console.error('[pageerror]', e.message));
  await page.goto(`http://localhost:${port}/scene.html`);
  await page.waitForFunction('window.ready === true', null, { timeout: 120000 });
  return { browser, page };
}
async function frame(page, t, type = 'jpeg') {
  await page.evaluate(t => { window.renderAt(t); return new Promise(r => requestAnimationFrame(() => r())); }, t);
  return page.screenshot(type === 'png' ? { type: 'png', timeout: 120000 } : { type: 'jpeg', quality: 96, timeout: 120000 });
}

(async () => {
  const srv = await serve(), port = srv.address().port;
  const [mode, ...rest] = process.argv.slice(2);
  if (mode === 'stills') {
    const { browser, page } = await openPage(port);
    for (const s of rest) { const t0 = Date.now(); fs.writeFileSync(path.join(OUT, `still_${s}.png`), await frame(page, parseFloat(s), 'png')); console.log('still', s, Date.now() - t0, 'ms'); }
    await browser.close();
  } else {
    const workers = parseInt(rest[0] || '4'), fps = TL.fps, total = Math.round(TL.duration * fps);
    const per = Math.ceil(total / workers); let done = 0; const t0 = Date.now();
    await Promise.all([...Array(workers)].map(async (_, w) => {
      const a = w * per, b = Math.min(total, a + per);
      const { browser, page } = await openPage(port);
      const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(fps), '-c:v', 'mjpeg', '-i', '-', '-c:v', 'libx264', '-preset', 'slow', '-crf', '15', '-pix_fmt', 'yuv420p', path.join(OUT, `part_${w}.mp4`)], { stdio: ['pipe', 'inherit', 'inherit'] });
      for (let f = a; f < b; f++) {
        const buf = await frame(page, f / fps);
        if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
        if (++done % 30 === 0) console.log(`${done}/${total} frames  ${((Date.now() - t0) / done).toFixed(0)} ms/frame avg`);
      }
      ff.stdin.end(); await new Promise(r => ff.on('close', r)); await browser.close();
    }));
    fs.writeFileSync(path.join(OUT, 'parts.txt'), [...Array(workers)].map((_, w) => `file 'part_${w}.mp4'`).join('\n'));
    await new Promise(r => spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', path.join(OUT, 'parts.txt'), '-c', 'copy', path.join(OUT, 'silent.mp4')], { stdio: 'inherit' }).on('close', r));
    console.log('done in', ((Date.now() - t0) / 1000).toFixed(0), 's');
  }
  srv.close();
})();
