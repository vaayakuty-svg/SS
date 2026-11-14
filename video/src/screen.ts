// 2D canvas drawing for everything that appears on the CRT, the phone LCD and the
// full-screen "inside the computer" overlay. Pure functions of time → deterministic renders.
import { PROMPT_TEXT, SKILLS, TITLE_WORD, PHONE_SENDER, PHONE_TEXT } from "./config";
import { clamp01, easeInOut, easeOut, lerp, rand, range, spring } from "./util";

export const C = {
  deepOrange: "#E8590C",
  amber: "#FFB000",
  warmRed: "#C9302C",
  brown: "#2B1A10",
  brown2: "#4A2C17",
  cream: "#FFF1D6",
  beige: "#E9DCC0",
  green: "#3DFF7A",
};

type Ctx = CanvasRenderingContext2D;

const rr = (ctx: Ctx, x: number, y: number, w: number, h: number, r: number) => {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
};

const scanlines = (ctx: Ctx, w: number, h: number, alpha = 0.18) => {
  ctx.fillStyle = `rgba(0,0,0,${alpha})`;
  const step = Math.max(2, Math.round(h / 240));
  for (let y = 0; y < h; y += step * 2) ctx.fillRect(0, y, w, step);
};

const vignette = (ctx: Ctx, w: number, h: number, a = 0.55) => {
  const g = ctx.createRadialGradient(w / 2, h / 2, Math.min(w, h) * 0.25, w / 2, h / 2, Math.max(w, h) * 0.75);
  g.addColorStop(0, "rgba(0,0,0,0)");
  g.addColorStop(1, `rgba(0,0,0,${a})`);
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, w, h);
};

const desktopBg = (ctx: Ctx, w: number, h: number) => {
  const g = ctx.createLinearGradient(0, 0, 0, h);
  g.addColorStop(0, "#5A2A12");
  g.addColorStop(1, "#B8460F");
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, w, h);
  // dither
  ctx.fillStyle = "rgba(255,200,120,0.07)";
  const s = Math.max(4, Math.round(w / 120));
  for (let y = 0; y < h; y += s * 2) for (let x = (y / s) % 2 ? s : 0; x < w; x += s * 2) ctx.fillRect(x, y, s * 0.5, s * 0.5);
};

const bevel = (ctx: Ctx, x: number, y: number, w: number, h: number, k: number, pressed = false, fill = C.beige) => {
  ctx.fillStyle = fill;
  ctx.fillRect(x, y, w, h);
  ctx.fillStyle = pressed ? "#7a6a52" : "#fffaf0";
  ctx.fillRect(x, y, w, k);
  ctx.fillRect(x, y, k, h);
  ctx.fillStyle = pressed ? "#fffaf0" : "#7a6a52";
  ctx.fillRect(x, y + h - k, w, k);
  ctx.fillRect(x + w - k, y, k, h);
};

const taskbar = (ctx: Ctx, w: number, h: number, u: number, clock = "4:57 PM") => {
  const th = 34 * u;
  bevel(ctx, 0, h - th, w, th, 2 * u);
  bevel(ctx, 4 * u, h - th + 4 * u, 90 * u, th - 8 * u, 2 * u);
  ctx.fillStyle = C.warmRed;
  ctx.fillRect(12 * u, h - th + 11 * u, 12 * u, 12 * u);
  ctx.fillStyle = "#1b1209";
  ctx.font = `${22 * u}px VT323`;
  ctx.textBaseline = "middle";
  ctx.textAlign = "left";
  ctx.fillText("START", 30 * u, h - th / 2);
  ctx.textAlign = "right";
  ctx.fillText(clock, w - 12 * u, h - th / 2);
};

const cursor = (ctx: Ctx, x: number, y: number, s: number) => {
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(s, s);
  ctx.beginPath();
  ctx.moveTo(0, 0);
  ctx.lineTo(0, 22);
  ctx.lineTo(6, 17);
  ctx.lineTo(10, 26);
  ctx.lineTo(14, 24);
  ctx.lineTo(10, 15);
  ctx.lineTo(17, 15);
  ctx.closePath();
  ctx.fillStyle = "#fff";
  ctx.fill();
  ctx.lineWidth = 1.6;
  ctx.strokeStyle = "#000";
  ctx.stroke();
  ctx.restore();
};

// ── 0–3 s: glitching title that settles ────────────────────────────────
const GLYPHS = "#$%&@01ABX/<>?*";
export const drawTitle = (ctx: Ctx, w: number, h: number, t: number, frame: number) => {
  ctx.fillStyle = "#140a05";
  ctx.fillRect(0, 0, w, h);
  const glow = ctx.createRadialGradient(w / 2, h / 2, 10, w / 2, h / 2, w * 0.6);
  glow.addColorStop(0, "rgba(255,140,30,0.35)");
  glow.addColorStop(1, "rgba(0,0,0,0)");
  ctx.fillStyle = glow;
  ctx.fillRect(0, 0, w, h);

  const g = 1 - easeInOut(range(t, 0.5, 2.5)); // glitch amount
  const settle = t > 2.5;
  let word = "";
  for (let i = 0; i < TITLE_WORD.length; i++) {
    const r = rand(frame * 13.1 + i * 7.7);
    word += r < g * 0.75 ? GLYPHS[Math.floor(rand(frame + i * 3.3) * GLYPHS.length)] : TITLE_WORD[i];
  }
  const fs = w * 0.21;
  ctx.font = `${fs}px VT323`;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  const off = g * w * 0.025 * (0.5 + rand(frame * 3.7));
  ctx.globalCompositeOperation = "lighter";
  ctx.fillStyle = "rgba(255,40,30,0.85)";
  ctx.fillText(word, w / 2 + off, h * 0.46);
  ctx.fillStyle = "rgba(30,200,255,0.6)";
  ctx.fillText(word, w / 2 - off, h * 0.46);
  ctx.globalCompositeOperation = "source-over";
  ctx.fillStyle = settle ? C.amber : "#ffcf70";
  ctx.shadowColor = C.deepOrange;
  ctx.shadowBlur = w * 0.03;
  ctx.fillText(word, w / 2, h * 0.46);
  ctx.shadowBlur = 0;

  // slice displacement
  const slices = Math.floor(g * 9);
  for (let k = 0; k < slices; k++) {
    const sy = rand(frame * 1.7 + k * 11) * h;
    const sh = (0.02 + rand(frame + k) * 0.06) * h;
    const dx = (rand(frame * 2.3 + k) - 0.5) * w * 0.18 * g;
    ctx.drawImage(ctx.canvas, 0, sy, w, sh, dx, sy, w, sh);
  }
  ctx.font = `${w * 0.05}px VT323`;
  ctx.fillStyle = C.cream;
  ctx.globalAlpha = settle ? 1 : 0.3;
  const blink = Math.floor(t * 3) % 2 === 0 ? "_" : " ";
  ctx.fillText(`> READY${blink}`, w / 2, h * 0.7);
  ctx.globalAlpha = 1;
  scanlines(ctx, w, h);
  vignette(ctx, w, h);
};

// ── 3–7 s: inbox of ideas ──────────────────────────────────────────────
export const drawInbox = (ctx: Ctx, w: number, h: number, t: number) => {
  desktopBg(ctx, w, h);
  const u = w / 640;
  const wx = 70 * u, wy = 60 * u, ww = 500 * u, wh = 330 * u;
  bevel(ctx, wx, wy, ww, wh, 3 * u);
  const tg = ctx.createLinearGradient(wx, 0, wx + ww, 0);
  tg.addColorStop(0, C.brown2);
  tg.addColorStop(1, C.deepOrange);
  ctx.fillStyle = tg;
  ctx.fillRect(wx + 4 * u, wy + 4 * u, ww - 8 * u, 28 * u);
  ctx.fillStyle = C.cream;
  ctx.font = `${24 * u}px VT323`;
  ctx.textAlign = "left";
  ctx.textBaseline = "middle";
  ctx.fillText("IDEAS.CHAT", wx + 12 * u, wy + 18 * u);
  ctx.fillStyle = "#1b1209";
  ctx.font = `${30 * u}px VT323`;
  const n = Math.min(5, Math.floor(range(t, 3.0, 4.6) * 5.99));
  ctx.fillText(`${n} new ideas incoming`, wx + 24 * u, wy + 80 * u);
  for (let i = 0; i < 3; i++) {
    const a = 0.35 + 0.65 * (Math.sin(t * 9 - i * 1.1) * 0.5 + 0.5);
    ctx.fillStyle = `rgba(232,89,12,${a})`;
    ctx.beginPath();
    ctx.arc(wx + 60 * u + i * 40 * u, wy + 180 * u, 12 * u, 0, Math.PI * 2);
    ctx.fill();
  }
  taskbar(ctx, w, h, u);
  scanlines(ctx, w, h, 0.12);
  vignette(ctx, w, h, 0.5);
};

// ── 7–11 s: retro OS prompt window (used on the CRT and full-screen) ───
export const OS_TIMES = { typeStart: 7.95, typeEnd: 9.55, moveStart: 9.65, click: 10.15, renderEnd: 10.9 };

export const typedCount = (t: number) =>
  Math.floor(clamp01((t - OS_TIMES.typeStart) / (OS_TIMES.typeEnd - OS_TIMES.typeStart)) * PROMPT_TEXT.length);

export const drawOS = (ctx: Ctx, w: number, h: number, t: number) => {
  desktopBg(ctx, w, h);
  const portrait = h > w;
  const u = portrait ? w / 540 : w / 640;
  // icons
  const icons = ["MY_DESK", "REELS", "SFX.WAV"];
  icons.forEach((name, i) => {
    const ix = 18 * u, iy = (portrait ? 140 : 18) * u + i * 70 * u;
    ctx.fillStyle = i === 1 ? C.amber : C.beige;
    ctx.fillRect(ix + 10 * u, iy, 34 * u, 28 * u);
    ctx.fillStyle = C.cream;
    ctx.font = `${16 * u}px VT323`;
    ctx.textAlign = "center";
    ctx.textBaseline = "top";
    ctx.fillText(name, ix + 27 * u, iy + 32 * u);
  });

  const ww = (portrait ? 500 : 520) * u;
  const wh = (portrait ? 430 : 360) * u;
  const wx = (w - ww) / 2 + (portrait ? 0 : 30 * u);
  const wy = portrait ? h * 0.36 : (h - wh) / 2 - 14 * u;
  // shadow
  ctx.fillStyle = "rgba(0,0,0,0.35)";
  ctx.fillRect(wx + 8 * u, wy + 8 * u, ww, wh);
  bevel(ctx, wx, wy, ww, wh, 3 * u);
  const tg = ctx.createLinearGradient(wx, 0, wx + ww, 0);
  tg.addColorStop(0, C.brown2);
  tg.addColorStop(1, C.deepOrange);
  ctx.fillStyle = tg;
  ctx.fillRect(wx + 4 * u, wy + 4 * u, ww - 8 * u, 30 * u);
  ctx.fillStyle = C.cream;
  ctx.font = `${26 * u}px VT323`;
  ctx.textAlign = "left";
  ctx.textBaseline = "middle";
  ctx.fillText("PROMPT.EXE", wx + 12 * u, wy + 19 * u);
  ["_", "□", "x"].forEach((s, i) => {
    const bx = wx + ww - (3 - i) * 26 * u - 6 * u;
    bevel(ctx, bx, wy + 8 * u, 22 * u, 22 * u, 2 * u);
    ctx.fillStyle = "#1b1209";
    ctx.textAlign = "center";
    ctx.font = `${20 * u}px VT323`;
    ctx.fillText(s, bx + 11 * u, wy + 18 * u);
  });

  ctx.textAlign = "left";
  ctx.fillStyle = "#1b1209";
  ctx.font = `${26 * u}px VT323`;
  ctx.fillText("Describe your scene:", wx + 24 * u, wy + 64 * u);

  // text field
  const fx = wx + 24 * u, fy = wy + 84 * u, fw = ww - 48 * u, fh = 150 * u;
  bevel(ctx, fx, fy, fw, fh, 3 * u, true, "#fffdf6");
  const n = typedCount(t);
  const txt = PROMPT_TEXT.slice(0, n);
  ctx.font = `${34 * u}px VT323`;
  ctx.fillStyle = "#24160c";
  ctx.textBaseline = "top";
  // wrap
  const words = txt.split(" ");
  const lines: string[] = [];
  let cur = "";
  for (const wd of words) {
    const test = cur ? cur + " " + wd : wd;
    if (ctx.measureText(test).width > fw - 30 * u && cur) {
      lines.push(cur);
      cur = wd;
    } else cur = test;
  }
  lines.push(cur);
  lines.forEach((l, i) => ctx.fillText(l, fx + 14 * u, fy + 14 * u + i * 36 * u));
  const last = lines[lines.length - 1];
  if (Math.floor(t * 4) % 2 === 0 || (t > OS_TIMES.typeStart && t < OS_TIMES.typeEnd)) {
    ctx.fillStyle = C.deepOrange;
    ctx.fillRect(fx + 16 * u + ctx.measureText(last).width, fy + 16 * u + (lines.length - 1) * 36 * u, 12 * u, 28 * u);
  }

  // Generate button
  const bw = 200 * u, bh = 52 * u;
  const bx = wx + ww - bw - 24 * u, by = fy + fh + 26 * u;
  const pressed = t >= OS_TIMES.click && t < OS_TIMES.click + 0.15;
  const hot = t >= OS_TIMES.click;
  bevel(ctx, bx, by, bw, bh, 3 * u, pressed, hot ? C.amber : "#F08A3C");
  ctx.fillStyle = "#1b1209";
  ctx.font = `${32 * u}px VT323`;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText("GENERATE ▶", bx + bw / 2 + (pressed ? 2 * u : 0), by + bh / 2 + (pressed ? 2 * u : 0));

  // progress after click
  const py = by + bh + 22 * u;
  if (t > OS_TIMES.click) {
    const p = easeInOut(range(t, OS_TIMES.click + 0.1, OS_TIMES.renderEnd));
    bevel(ctx, fx, py, fw, 30 * u, 2 * u, true, "#fffdf6");
    const segs = Math.floor(p * 24);
    ctx.fillStyle = C.deepOrange;
    for (let i = 0; i < segs; i++) ctx.fillRect(fx + 6 * u + i * ((fw - 12 * u) / 24), py + 6 * u, (fw - 12 * u) / 24 - 3 * u, 18 * u);
    ctx.fillStyle = "#1b1209";
    ctx.textAlign = "left";
    ctx.font = `${22 * u}px VT323`;
    ctx.fillText(p < 1 ? `Rendering... ${Math.round(p * 100)}%` : "Done.", fx, py + 50 * u);
  } else {
    ctx.fillStyle = "#6b5a44";
    ctx.textAlign = "left";
    ctx.font = `${22 * u}px VT323`;
    ctx.fillText(`${n}/${PROMPT_TEXT.length} chars`, fx, by + bh / 2);
  }

  taskbar(ctx, w, h, u);

  // mouse cursor: rests near the field, glides to the button, clicks
  const m = easeInOut(range(t, OS_TIMES.moveStart, OS_TIMES.click - 0.05));
  const cx = lerp(wx + ww * 0.35, bx + bw * 0.55, m);
  const cy = lerp(fy + fh + 90 * u, by + bh * 0.55, m);
  const press = t >= OS_TIMES.click && t < OS_TIMES.click + 0.15 ? 0.88 : 1;
  cursor(ctx, cx, cy, 1.6 * u * press);
  if (t >= OS_TIMES.click && t < OS_TIMES.click + 0.35) {
    const k = range(t, OS_TIMES.click, OS_TIMES.click + 0.35);
    ctx.strokeStyle = `rgba(255,241,214,${1 - k})`;
    ctx.lineWidth = 4 * u;
    ctx.beginPath();
    ctx.arc(cx, cy, (10 + 50 * k) * u, 0, Math.PI * 2);
    ctx.stroke();
  }
  scanlines(ctx, w, h, portrait ? 0.08 : 0.12);
  vignette(ctx, w, h, 0.45);
};

// ── 11–14 s: the flat result ───────────────────────────────────────────
export const drawFlat = (ctx: Ctx, w: number, h: number) => {
  ctx.fillStyle = "#6f6f6f";
  ctx.fillRect(0, 0, w, h);
  const u = w / 640;
  bevel(ctx, 90 * u, 70 * u, 460 * u, 320 * u, 3 * u, false, "#bdbdbd");
  ctx.fillStyle = "#8a8a8a";
  ctx.fillRect(110 * u, 110 * u, 420 * u, 230 * u);
  ctx.fillStyle = "#9c9c9c";
  ctx.fillRect(200 * u, 190 * u, 140 * u, 100 * u);
  ctx.fillStyle = "#333";
  ctx.font = `${24 * u}px VT323`;
  ctx.textAlign = "left";
  ctx.textBaseline = "middle";
  ctx.fillText("render_final.mp4  — meh.", 110 * u, 92 * u);
  scanlines(ctx, w, h, 0.1);
};

// ── idle desktop (14–18 s, 27–30 s) ───────────────────────────────────
export const drawIdle = (ctx: Ctx, w: number, h: number, t: number) => {
  ctx.fillStyle = "#140a05";
  ctx.fillRect(0, 0, w, h);
  const glow = ctx.createRadialGradient(w / 2, h / 2, 10, w / 2, h / 2, w * 0.6);
  glow.addColorStop(0, "rgba(255,140,30,0.4)");
  glow.addColorStop(1, "rgba(0,0,0,0)");
  ctx.fillStyle = glow;
  ctx.fillRect(0, 0, w, h);
  ctx.font = `${w * 0.19}px VT323`;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillStyle = C.amber;
  ctx.shadowColor = C.deepOrange;
  ctx.shadowBlur = w * 0.03;
  ctx.fillText(TITLE_WORD, w / 2, h * 0.45);
  ctx.shadowBlur = 0;
  ctx.font = `${w * 0.05}px VT323`;
  ctx.fillStyle = C.cream;
  ctx.fillText(Math.floor(t * 3) % 2 ? "> _" : ">  ", w / 2, h * 0.7);
  scanlines(ctx, w, h);
  vignette(ctx, w, h);
};

// ── 18–24 s: XP bar, checkmarks, LEVEL UP ──────────────────────────────
export const XP_TIMES = { barStart: 18.3, barEnd: 20.6, checks: [18.9, 19.4, 19.9, 20.4], badge: 21.0 };

export const drawXP = (ctx: Ctx, w: number, h: number, t: number) => {
  ctx.fillStyle = "#1a0e07";
  ctx.fillRect(0, 0, w, h);
  const u = w / 640;
  ctx.textAlign = "left";
  ctx.textBaseline = "middle";
  ctx.fillStyle = C.amber;
  ctx.font = `${40 * u}px VT323`;
  ctx.fillText("SKILL TREE  //  LVL 1", 40 * u, 46 * u);
  // XP bar
  const p = easeInOut(range(t, XP_TIMES.barStart, XP_TIMES.barEnd));
  const bx = 40 * u, by = 78 * u, bw = 560 * u, bh = 34 * u;
  ctx.strokeStyle = C.cream;
  ctx.lineWidth = 3 * u;
  ctx.strokeRect(bx, by, bw, bh);
  const gr = ctx.createLinearGradient(bx, 0, bx + bw, 0);
  gr.addColorStop(0, C.warmRed);
  gr.addColorStop(0.6, C.deepOrange);
  gr.addColorStop(1, C.amber);
  ctx.fillStyle = gr;
  ctx.fillRect(bx + 5 * u, by + 5 * u, (bw - 10 * u) * p, bh - 10 * u);
  ctx.fillStyle = C.cream;
  ctx.font = `${26 * u}px VT323`;
  ctx.textAlign = "right";
  ctx.fillText(`XP ${Math.round(p * 1000)}/1000`, bx + bw, by + bh + 22 * u);
  // checklist
  ctx.textAlign = "left";
  SKILLS.forEach((s, i) => {
    const y = 175 * u + i * 52 * u;
    const ct = XP_TIMES.checks[i];
    const on = t >= ct;
    ctx.strokeStyle = on ? C.amber : "#6b5a44";
    ctx.lineWidth = 3 * u;
    ctx.strokeRect(50 * u, y - 16 * u, 32 * u, 32 * u);
    if (on) {
      const k = spring(t - ct, 22, 0.35);
      ctx.save();
      ctx.translate(66 * u, y);
      ctx.scale(k, k);
      ctx.strokeStyle = C.green;
      ctx.lineWidth = 6 * u;
      ctx.beginPath();
      ctx.moveTo(-10 * u, 0);
      ctx.lineTo(-2 * u, 9 * u);
      ctx.lineTo(13 * u, -11 * u);
      ctx.stroke();
      ctx.restore();
    }
    ctx.fillStyle = on ? C.cream : "#8a7660";
    ctx.font = `${36 * u}px VT323`;
    ctx.fillText(s, 100 * u, y + 2 * u);
    if (on) {
      ctx.fillStyle = C.amber;
      ctx.font = `${24 * u}px VT323`;
      ctx.fillText("+250 XP", 250 * u, y + 2 * u);
    }
  });
  // badge
  if (t >= XP_TIMES.badge) {
    const k = spring(t - XP_TIMES.badge, 16, 0.3);
    const cx = 480 * u, cy = 290 * u;
    ctx.save();
    ctx.translate(cx, cy);
    ctx.rotate(-0.12);
    ctx.scale(k, k);
    // burst
    ctx.fillStyle = "rgba(255,176,0,0.35)";
    for (let i = 0; i < 12; i++) {
      ctx.rotate(Math.PI / 6);
      ctx.fillRect(0, -6 * u, 150 * u, 12 * u);
    }
    rr(ctx, -120 * u, -52 * u, 240 * u, 104 * u, 22 * u);
    const bg = ctx.createLinearGradient(0, -52 * u, 0, 52 * u);
    bg.addColorStop(0, C.amber);
    bg.addColorStop(1, C.deepOrange);
    ctx.fillStyle = bg;
    ctx.fill();
    ctx.lineWidth = 5 * u;
    ctx.strokeStyle = C.cream;
    ctx.stroke();
    ctx.fillStyle = "#1b1209";
    ctx.textAlign = "center";
    ctx.font = `${58 * u}px VT323`;
    ctx.fillText("LEVEL UP!", 0, 4 * u);
    ctx.restore();
  }
  scanlines(ctx, w, h);
  vignette(ctx, w, h, 0.5);
};

// ── 24–27 s: code ─────────────────────────────────────────────────────
export const CODE_LINES = [
  "<ThreeCanvas width={1080} height={1920}>",
  "  <directionalLight castShadow",
  "    color=\"#ffb35c\" intensity={4.2} />",
  "  <Blinds slats={14} />",
  "  <CRT screen={drawXP(t)} />",
  "const cam = track(frame / fps);",
  "camera.position.copy(cam.pos);",
  "bloom.intensity = lerp(0.6, 1.4, t);",
  "if (t > 21) levelUp();",
  "export const fps = 30;",
  "sfx.whoosh(at(beat(14)));",
  "dof.focus = dist(cam, target);",
];
export const drawCode = (ctx: Ctx, w: number, h: number, t: number) => {
  ctx.fillStyle = "#020b04";
  ctx.fillRect(0, 0, w, h);
  const u = w / 640;
  ctx.font = `${22 * u}px "JetBrains Mono"`;
  ctx.textAlign = "left";
  ctx.textBaseline = "top";
  const scroll = (t - 24) * 70 * u;
  for (let i = 0; i < 30; i++) {
    const y = i * 30 * u - (scroll % (30 * u));
    const line = CODE_LINES[(i + Math.floor(scroll / (30 * u))) % CODE_LINES.length];
    ctx.fillStyle = i % 5 === 0 ? "#B7FFCD" : C.green;
    ctx.fillText(line, 20 * u, y);
  }
  scanlines(ctx, w, h, 0.2);
};

// ── phone LCD ────────────────────────────────────────────────────────
export const drawPhone = (ctx: Ctx, w: number, h: number, t: number) => {
  ctx.fillStyle = "#9fae86";
  ctx.fillRect(0, 0, w, h);
  ctx.fillStyle = "#26301c";
  const u = w / 240;
  ctx.font = `${26 * u}px VT323`;
  ctx.textAlign = "left";
  ctx.textBaseline = "top";
  ctx.fillText("▮▮▮▯", 10 * u, 6 * u);
  ctx.textAlign = "right";
  ctx.fillText("16:58", w - 10 * u, 6 * u);
  ctx.fillRect(8 * u, 36 * u, w - 16 * u, 2 * u);
  ctx.textAlign = "left";
  const show = t > 12.75;
  if (!show) {
    ctx.font = `${30 * u}px VT323`;
    ctx.fillText("1 new message", 16 * u, 110 * u);
    return;
  }
  ctx.font = `${24 * u}px VT323`;
  ctx.fillText(`From: ${PHONE_SENDER}`, 12 * u, 48 * u);
  ctx.font = `${32 * u}px VT323`;
  const n = Math.floor(range(t, 12.85, 13.5) * PHONE_TEXT.length);
  const txt = PHONE_TEXT.slice(0, n);
  const words = txt.split(" ");
  let line = "", y = 88 * u;
  for (const wd of words) {
    const test = line ? line + " " + wd : wd;
    if (ctx.measureText(test).width > w - 28 * u && line) {
      ctx.fillText(line, 12 * u, y);
      y += 34 * u;
      line = wd;
    } else line = test;
  }
  ctx.fillText(line, 12 * u, y);
  ctx.font = `${24 * u}px VT323`;
  ctx.fillText("Reply      Back", 12 * u, h - 34 * u);
};

// ── chat bubble card (static) ───────────────────────────────────────
export const drawBubble = (ctx: Ctx, w: number, h: number, text: string, i: number) => {
  ctx.clearRect(0, 0, w, h);
  const pad = 14;
  const fill = i % 2 ? C.cream : C.amber;
  ctx.shadowColor = "rgba(40,15,0,0.35)";
  ctx.shadowBlur = 12;
  ctx.shadowOffsetY = 6;
  rr(ctx, pad, pad, w - pad * 2, h - pad * 2 - 18, (h - pad * 2 - 18) / 2.4);
  ctx.fillStyle = fill;
  ctx.fill();
  // tail
  ctx.beginPath();
  const tx = i % 2 ? w * 0.25 : w * 0.75;
  ctx.moveTo(tx - 16, h - pad - 22);
  ctx.lineTo(tx + (i % 2 ? -14 : 14), h - pad);
  ctx.lineTo(tx + 16, h - pad - 22);
  ctx.fill();
  ctx.shadowBlur = 0;
  ctx.shadowOffsetY = 0;
  ctx.fillStyle = "#2B1A10";
  ctx.font = `600 ${h * 0.26}px Fredoka`;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(text, w / 2, (h - 18) / 2 + 2);
};

export const screenFor = (t: number) => {
  if (t < 3.0) return "title";
  if (t < 7.0) return "inbox";
  if (t < 11.0) return "os";
  if (t < 14.0) return "flat";
  if (t < 18.0) return "idle";
  if (t < 24.0) return "xp";
  if (t < 27.0) return "code";
  return "idle";
};

export const drawScreen = (ctx: Ctx, w: number, h: number, t: number, frame: number) => {
  switch (screenFor(t)) {
    case "title": return drawTitle(ctx, w, h, t, frame);
    case "inbox": return drawInbox(ctx, w, h, t);
    case "os": return drawOS(ctx, w, h, t);
    case "flat": return drawFlat(ctx, w, h);
    case "idle": return drawIdle(ctx, w, h, t);
    case "xp": return drawXP(ctx, w, h, t);
    case "code": return drawCode(ctx, w, h, t);
  }
};

export { easeOut };
