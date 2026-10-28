// THE BRAVE LITTLE SHRIMP — 30s 9:16 motion graphics.
// Every frame is a pure function of time t (seconds), so the renderer can
// export any frame deterministically: window.renderFrame(t).
(() => {
'use strict';

const W = 1080, H = 1920, DUR = 30, TAU = Math.PI * 2;
const C = {
  white: '#FFFFFF', blue: '#007BFF', cyan: '#00DFFF', orange: '#FF7043', navy: '#102A43',
  pink: '#FF8FB1', yellow: '#FFD54F', teal: '#1DE9B6',
};

const canvas = document.getElementById('stage');
const ctx = canvas.getContext('2d');
const mkBuf = () => { const b = document.createElement('canvas'); b.width = W; b.height = H; return b; };
const bufA = mkBuf(), bufB = mkBuf();
const ca = bufA.getContext('2d'), cb = bufB.getContext('2d');

// ---------------------------------------------------------------- math ----
const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
const lerp = (a, b, t) => a + (b - a) * t;
const prog = (t, a, b) => clamp((t - a) / (b - a));
const E = {
  in: x => x * x * x,
  out: x => 1 - Math.pow(1 - x, 3),
  inOut: x => (x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2),
  inOut5: x => (x < 0.5 ? 16 * Math.pow(x, 5) : 1 - Math.pow(-2 * x + 2, 5) / 2),
  outBack: x => { const c1 = 1.70158, c3 = c1 + 1; return 1 + c3 * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2); },
  inBack: x => { const c1 = 1.70158, c3 = c1 + 1; return c3 * x * x * x - c1 * x * x; },
  outElastic: x => (x <= 0 ? 0 : x >= 1 ? 1 : Math.pow(2, -10 * x) * Math.sin((x * 10 - 0.75) * (TAU / 3)) + 1),
  outBounce: x => {
    const n1 = 7.5625, d1 = 2.75;
    if (x < 1 / d1) return n1 * x * x;
    if (x < 2 / d1) return n1 * (x -= 1.5 / d1) * x + 0.75;
    if (x < 2.5 / d1) return n1 * (x -= 2.25 / d1) * x + 0.9375;
    return n1 * (x -= 2.625 / d1) * x + 0.984375;
  },
};
function rng(seed) {
  let s = (seed * 2654435761) >>> 0 || 1;
  return () => { s ^= s << 13; s >>>= 0; s ^= s >>> 17; s ^= s << 5; s >>>= 0; return s / 4294967296; };
}
const pick = (r, arr) => arr[Math.floor(r() * arr.length) % arr.length];

// Camera: world point (cx, cy) lands at screen center (plus shake offset).
function cam(c, cx, cy, z, dx = 0, dy = 0, rot = 0) {
  c.translate(W / 2 + dx, H / 2 + dy);
  if (rot) c.rotate(rot);
  c.scale(z, z);
  c.translate(-cx, -cy);
}
function shake(t, t0, amp, decay = 6, freq = 47) {
  if (t < t0) return [0, 0];
  const a = amp * Math.exp(-(t - t0) * decay);
  return [Math.sin((t - t0) * freq) * a, Math.cos((t - t0) * freq * 1.31) * a * 0.8];
}

// --------------------------------------------------------------- shapes ---
function heartPath(c, s) {
  c.beginPath();
  c.moveTo(0, s * 0.85);
  c.bezierCurveTo(-s * 1.35, s * 0.05, -s * 0.95, -s * 1.0, 0, -s * 0.42);
  c.bezierCurveTo(s * 0.95, -s * 1.0, s * 1.35, s * 0.05, 0, s * 0.85);
  c.closePath();
}
function drawShape(c, type, x, y, size, col, rot = 0, alpha = 1) {
  if (alpha <= 0 || size <= 0) return;
  c.save();
  c.translate(x, y); c.rotate(rot); c.globalAlpha *= alpha;
  c.fillStyle = col; c.strokeStyle = col; c.lineJoin = 'round'; c.lineCap = 'round';
  switch (type) {
    case 'tri':
      c.beginPath();
      for (let i = 0; i < 3; i++) { const a = -Math.PI / 2 + i * TAU / 3; c.lineTo(Math.cos(a) * size, Math.sin(a) * size); }
      c.closePath(); c.lineWidth = size * 0.3; c.stroke(); c.fill(); break;
    case 'ring':
      c.lineWidth = size * 0.3; c.beginPath(); c.arc(0, 0, size * 0.8, 0, TAU); c.stroke(); break;
    case 'square':
      c.lineWidth = size * 0.28; c.beginPath(); c.roundRect(-size * 0.7, -size * 0.7, size * 1.4, size * 1.4, size * 0.25); c.stroke(); break;
    case 'dot':
      c.beginPath(); c.arc(0, 0, size, 0, TAU); c.fill(); break;
    case 'plus':
      c.lineWidth = size * 0.34; c.beginPath();
      c.moveTo(-size * 0.8, 0); c.lineTo(size * 0.8, 0); c.moveTo(0, -size * 0.8); c.lineTo(0, size * 0.8); c.stroke(); break;
    case 'heart':
      heartPath(c, size); c.fill(); break;
    case 'star': // 4-point sparkle
      c.beginPath();
      for (let i = 0; i < 8; i++) { const a = i * TAU / 8, r = i % 2 ? size * 0.28 : size; c.lineTo(Math.cos(a) * r, Math.sin(a) * r); }
      c.closePath(); c.fill(); break;
  }
  c.restore();
}
function drawBubble(c, x, y, r, a = 1) {
  if (a <= 0 || r <= 0) return;
  c.save(); c.globalAlpha *= a;
  const g = c.createRadialGradient(x - r * 0.3, y - r * 0.3, r * 0.1, x, y, r);
  g.addColorStop(0, 'rgba(255,255,255,0.05)'); g.addColorStop(0.8, 'rgba(255,255,255,0.12)'); g.addColorStop(1, 'rgba(255,255,255,0.45)');
  c.fillStyle = g; c.beginPath(); c.arc(x, y, r, 0, TAU); c.fill();
  c.strokeStyle = 'rgba(255,255,255,0.75)'; c.lineWidth = Math.max(1.5, r * 0.09);
  c.beginPath(); c.arc(x, y, r, 0, TAU); c.stroke();
  c.fillStyle = 'rgba(255,255,255,0.9)';
  c.beginPath(); c.ellipse(x - r * 0.38, y - r * 0.38, r * 0.22, r * 0.13, -0.8, 0, TAU); c.fill();
  c.restore();
}

// --------------------------------------------------------------- shrimp ---
// Local space: facing right, roughly 300 x 220 units at s = 1.
function rotPt(px, py, ox, oy, a) {
  const cs = Math.cos(a), sn = Math.sin(a), dx = px - ox, dy = py - oy;
  return [ox + dx * cs - dy * sn, oy + dx * sn + dy * cs];
}
function shellGrad(c, x, y, r) {
  const g = c.createRadialGradient(x - r * 0.35, y - r * 0.5, r * 0.08, x, y, r * 1.08);
  g.addColorStop(0, '#FFC2AE'); g.addColorStop(0.42, '#FF7043'); g.addColorStop(1, '#D4441D');
  return g;
}
function clawPose(o) {
  const reach = o.reach || 0, wave = o.wave || 0, t = o.time || 0;
  let ang = lerp(0.85 + Math.sin(t * 3) * 0.08, 0.05, reach);
  let len = lerp(44, 75, reach);
  if (wave > 0) { ang = lerp(ang, -1.95 + Math.sin(t * 13) * 0.42, wave); len = lerp(len, 58, wave); }
  return { bx: 30, by: 10, ang, len };
}
function shrimpClawTip(o) {
  const p = clawPose(o), s = o.s || 1;
  const lx = p.bx + Math.cos(p.ang) * (p.len + 20), ly = p.by + Math.sin(p.ang) * (p.len + 20);
  const sx = lx * s * (o.sx || 1) * (o.flip ? -1 : 1), sy = ly * s * (o.sy || 1);
  const r = o.rot || 0;
  return [o.x + sx * Math.cos(r) - sy * Math.sin(r), o.y + sx * Math.sin(r) + sy * Math.cos(r)];
}
function drawClaw(c, bx, by, ang, len, open, dark) {
  const col = dark ? '#E0552B' : '#FF7A4F';
  c.save(); c.translate(bx, by); c.rotate(ang);
  c.lineCap = 'round'; c.strokeStyle = dark ? '#C9461F' : '#F25B2D'; c.lineWidth = 12;
  c.beginPath(); c.moveTo(0, 0); c.lineTo(len, 0); c.stroke();
  c.translate(len, 0);
  c.fillStyle = dark ? '#D04A20' : shellGrad(c, 4, -2, 18);
  c.beginPath(); c.ellipse(4, 0, 17, 13, 0, 0, TAU); c.fill();
  c.save(); c.rotate(-open); c.fillStyle = col;
  c.beginPath(); c.ellipse(20, -5, 17, 7.5, 0.1, 0, TAU); c.fill(); c.restore();
  c.save(); c.rotate(open * 0.7); c.fillStyle = dark ? '#C9461F' : '#F2643A';
  c.beginPath(); c.ellipse(17, 6, 13, 6, -0.1, 0, TAU); c.fill(); c.restore();
  if (!dark) { c.fillStyle = 'rgba(255,255,255,0.45)'; c.beginPath(); c.ellipse(0, -5, 6, 3, -0.4, 0, TAU); c.fill(); }
  c.restore();
}
function drawShrimp(c, t, o) {
  const s = o.s || 1, expr = o.expr || 'happy', swim = o.swim ?? 0.4;
  if ((o.alpha ?? 1) <= 0 || s <= 0) return;
  c.save();
  c.globalAlpha *= (o.alpha ?? 1);
  c.translate(o.x, o.y); c.rotate(o.rot || 0);
  c.scale((o.flip ? -1 : 1) * s * (o.sx || 1), s * (o.sy || 1));
  c.lineCap = 'round'; c.lineJoin = 'round';

  const wag = Math.sin(t * (3.5 + swim * 11)) * (0.06 + swim * 0.16);
  const base = [[-98, 52, 19], [-88, 22, 25], [-68, -3, 30], [-40, -19, 34], [-6, -24, 38]];
  const pts = base.map((p, i) => {
    const k = (4 - i) / 4;
    const [x, y] = rotPt(p[0], p[1], 0, -20, wag * k * 1.4);
    return [x, y, p[2]];
  });

  // swimmerets (legs)
  c.strokeStyle = '#E8582A'; c.lineWidth = 6;
  for (let i = 1; i <= 4; i++) {
    const [x, y, r] = pts[i];
    const ph = Math.sin(t * (6 + swim * 16) + i * 1.1) * (5 + swim * 9);
    c.beginPath(); c.moveTo(x + 2, y + r * 0.72); c.lineTo(x - 4 + ph, y + r * 0.72 + 22); c.stroke();
  }
  // far claw
  const cp = clawPose({ ...o, time: t });
  drawClaw(c, 18, 6, (o.reach ? cp.ang + 0.15 : 1.15 + Math.sin(t * 3 + 1) * 0.08), o.reach ? cp.len - 6 : 40, o.open ?? 0.3, true);

  // tail fan
  {
    const [tx, ty] = pts[0], [qx, qy] = pts[1];
    const dir = Math.atan2(ty - qy, tx - qx);
    c.save(); c.translate(tx, ty); c.rotate(dir + wag * 0.8);
    for (const a of [-0.55, 0.55, 0]) {
      c.save(); c.rotate(a);
      c.fillStyle = shellGrad(c, 18, -4, 26);
      c.beginPath(); c.ellipse(24, 0, 28, 12, 0, 0, TAU); c.fill();
      c.restore();
    }
    c.restore();
  }
  // body segments, tail -> head
  for (let i = 0; i < pts.length; i++) {
    const [x, y, r] = pts[i];
    c.fillStyle = shellGrad(c, x, y, r);
    c.beginPath(); c.arc(x, y, r, 0, TAU); c.fill();
    c.strokeStyle = 'rgba(255,255,255,0.38)'; c.lineWidth = 4;
    c.beginPath(); c.arc(x, y, r * 0.72, -2.5, -1.25); c.stroke();
    c.strokeStyle = 'rgba(160,45,10,0.18)'; c.lineWidth = 3;
    c.beginPath(); c.arc(x, y, r * 0.98, 0.2, 1.6); c.stroke();
  }
  // antennae
  const sw = Math.sin(t * 2.6) * 10, sw2 = Math.sin(t * 2.1 + 1) * 12;
  c.strokeStyle = '#FF8A65'; c.lineWidth = 5;
  c.beginPath(); c.moveTo(76, -56); c.quadraticCurveTo(112 + sw, -140, 196 + sw * 2, -150 + sw); c.stroke();
  c.beginPath(); c.moveTo(66, -62); c.quadraticCurveTo(78 + sw2, -150, 132 + sw2 * 1.4, -196); c.stroke();
  c.fillStyle = '#FF8A65';
  c.beginPath(); c.arc(196 + sw * 2, -150 + sw, 6, 0, TAU); c.fill();
  c.beginPath(); c.arc(132 + sw2 * 1.4, -196, 6, 0, TAU); c.fill();
  // rostrum
  c.fillStyle = '#F25B2D';
  c.beginPath(); c.moveTo(66, -60); c.quadraticCurveTo(104, -72, 118, -64); c.quadraticCurveTo(98, -56, 84, -44); c.closePath(); c.fill();
  // head
  c.fillStyle = shellGrad(c, 42, -22, 56);
  c.beginPath(); c.ellipse(42, -22, 58, 47, -0.12, 0, TAU); c.fill();
  c.strokeStyle = 'rgba(255,255,255,0.4)'; c.lineWidth = 5;
  c.beginPath(); c.ellipse(42, -22, 44, 34, -0.12, -2.7, -1.6); c.stroke();
  // cheek
  c.fillStyle = 'rgba(255,72,96,0.32)';
  c.beginPath(); c.ellipse(74, -8, 12, 7, 0, 0, TAU); c.fill();

  // eye
  const blinkPh = (t + (o.blinkOffset || 0)) % 3.3;
  const blink = blinkPh < 0.14 ? 1 - Math.sin(blinkPh / 0.14 * Math.PI) * 0.9 : 1;
  const er = expr === 'surprised' ? 26 : 22;
  const look = o.look || [0.35, 0];
  c.save(); c.translate(58, -36); c.scale(1, blink);
  const eg = c.createRadialGradient(-6, -8, 2, 0, 0, er);
  eg.addColorStop(0, '#FFFFFF'); eg.addColorStop(1, '#DCE6F0');
  c.fillStyle = eg; c.beginPath(); c.arc(0, 0, er, 0, TAU); c.fill();
  const pr = expr === 'surprised' ? 9 : 13;
  const px = look[0] * er * 0.38, py = look[1] * er * 0.38;
  c.fillStyle = C.navy; c.beginPath(); c.arc(px, py, pr, 0, TAU); c.fill();
  c.fillStyle = '#fff';
  c.beginPath(); c.arc(px - pr * 0.35, py - pr * 0.4, pr * 0.38, 0, TAU); c.fill();
  c.beginPath(); c.arc(px + pr * 0.35, py + pr * 0.35, pr * 0.16, 0, TAU); c.fill();
  c.restore();
  // brows
  c.strokeStyle = C.navy; c.lineWidth = 5;
  if (expr === 'determined') { c.beginPath(); c.moveTo(38, -66); c.lineTo(78, -56); c.stroke(); }
  if (expr === 'surprised') { c.beginPath(); c.arc(58, -40, 38, -2.15, -1.2); c.stroke(); }
  // mouth
  c.fillStyle = C.navy; c.strokeStyle = C.navy; c.lineWidth = 4.5;
  if (expr === 'surprised') {
    c.beginPath(); c.ellipse(90, -2, 7, 10, 0, 0, TAU); c.fill();
  } else if (expr === 'proud') {
    c.beginPath(); c.moveTo(74, -11); c.quadraticCurveTo(88, 12, 101, -9); c.closePath(); c.fill();
    c.fillStyle = '#FF6F8B'; c.beginPath(); c.ellipse(88, -1, 6, 3.5, 0, 0, TAU); c.fill();
  } else if (expr === 'determined') {
    c.beginPath(); c.moveTo(76, -4); c.quadraticCurveTo(88, 0, 99, -10); c.stroke();
  } else {
    c.beginPath(); c.arc(87, -14, 11, 0.25 * Math.PI, 0.85 * Math.PI); c.stroke();
  }
  // near claw
  drawClaw(c, cp.bx, cp.by, cp.ang, cp.len, o.open ?? (0.3 + Math.sin(t * 4) * 0.08), false);
  c.restore();
}
function groundShadow(c, x, y, w, a) {
  if (a <= 0) return;
  c.save();
  const g = c.createRadialGradient(x, y, 0, x, y, w);
  g.addColorStop(0, `rgba(16,42,67,${0.22 * a})`); g.addColorStop(1, 'rgba(16,42,67,0)');
  c.fillStyle = g; c.translate(x, y); c.scale(1, 0.18); c.translate(-x, -y);
  c.beginPath(); c.arc(x, y, w, 0, TAU); c.fill();
  c.restore();
}

// ----------------------------------------------------------------- fish ---
function drawFish(c, t, o) {
  const s = o.s || 1, expr = o.expr || 'happy';
  c.save();
  c.translate(o.x, o.y); c.rotate(o.rot || 0); c.scale((o.flip ? -1 : 1) * s, s);
  const wag = Math.sin(t * (o.wagSpeed || 8)) * 0.35;
  // tail
  c.save(); c.translate(-60, 0); c.rotate(wag);
  const tg = c.createLinearGradient(-55, 0, 0, 0); tg.addColorStop(0, C.cyan); tg.addColorStop(1, C.blue);
  c.fillStyle = tg;
  c.beginPath(); c.moveTo(4, 0); c.quadraticCurveTo(-26, -12, -56, -44); c.quadraticCurveTo(-40, 0, -56, 44); c.quadraticCurveTo(-26, 12, 4, 0); c.fill();
  c.restore();
  // dorsal fin
  c.fillStyle = '#0066E0';
  c.beginPath(); c.moveTo(-34, -38); c.quadraticCurveTo(-6, -92 + wag * 10, 32, -42); c.closePath(); c.fill();
  // body
  const bg = c.createRadialGradient(-12, -24, 6, 0, 0, 82);
  bg.addColorStop(0, '#8DF3FF'); bg.addColorStop(0.35, '#22C3FF'); bg.addColorStop(0.75, C.blue); bg.addColorStop(1, '#0052BD');
  c.fillStyle = bg; c.beginPath(); c.ellipse(0, 0, 72, 52, 0, 0, TAU); c.fill();
  c.fillStyle = 'rgba(255,255,255,0.28)'; c.beginPath(); c.ellipse(6, 24, 48, 20, 0, 0, TAU); c.fill();
  c.strokeStyle = 'rgba(255,255,255,0.35)'; c.lineWidth = 6; c.lineCap = 'round';
  c.beginPath(); c.arc(-46, 0, 34, -0.9, 0.9); c.stroke();
  c.beginPath(); c.arc(-26, 0, 38, -0.85, 0.85); c.stroke();
  // pectoral fin
  c.save(); c.translate(-4, 16); c.rotate(0.6 + wag * 0.8);
  c.fillStyle = '#0064DA'; c.beginPath(); c.ellipse(-8, 0, 22, 10, 0, 0, TAU); c.fill(); c.restore();
  // eye
  c.fillStyle = '#fff'; c.beginPath(); c.arc(34, -12, 17, 0, TAU); c.fill();
  const lk = o.look || [0.3, 0];
  c.fillStyle = C.navy; c.beginPath(); c.arc(36 + lk[0] * 5, -12 + lk[1] * 5, 10, 0, TAU); c.fill();
  c.fillStyle = '#fff'; c.beginPath(); c.arc(33 + lk[0] * 5, -16 + lk[1] * 5, 3.8, 0, TAU); c.fill();
  // brow / mouth / cheek
  c.strokeStyle = C.navy; c.lineWidth = 4; c.lineCap = 'round';
  if (expr === 'worried') {
    c.beginPath(); c.moveTo(20, -38); c.quadraticCurveTo(34, -44, 48, -34); c.stroke();
    c.fillStyle = C.navy; c.beginPath(); c.ellipse(60, 14, 6, 8, 0, 0, TAU); c.fill();
  } else {
    c.beginPath(); c.arc(54, 6, 10, 0.2 * Math.PI, 0.8 * Math.PI); c.stroke();
  }
  c.fillStyle = 'rgba(255,111,139,0.45)'; c.beginPath(); c.ellipse(46, 8, 8, 5, 0, 0, TAU); c.fill();
  c.restore();
}

// ----------------------------------------------------------------- text ---
const SEG = new Intl.Segmenter('en', { granularity: 'grapheme' });
const fontStr = size => `900 ${size}px Montserrat, "Noto Color Emoji", sans-serif`;
const layoutCache = new Map();
function layout(str, size, tracking = 0, maxW = W - 150) {
  const key = `${str}|${size}|${tracking}|${maxW}`;
  if (layoutCache.has(key)) return layoutCache.get(key);
  const g = [...SEG.segment(str)].map(s => s.segment);
  let sz = size, res;
  for (let k = 0; k < 30; k++) {
    ctx.font = fontStr(sz);
    const ws = g.map(ch => ctx.measureText(ch).width);
    const tr = tracking * sz / size;
    const total = ws.reduce((a, b) => a + b, 0) + tr * (g.length - 1);
    if (total <= maxW || k === 29) {
      let x = -total / 2;
      res = { size: sz, total, items: g.map((ch, i) => { const it = { ch, x: x + ws[i] / 2, w: ws[i], space: ch === ' ' }; x += ws[i] + tr; return it; }) };
      break;
    }
    sz *= 0.95;
  }
  layoutCache.set(key, res);
  return res;
}
// fn(i, n, item) -> {dx, dy, s, sx, sy, rot, a, blur, fill, xs}
function drawText(c, L, x, y, style, fn) {
  c.save();
  c.font = fontStr(L.size); c.textAlign = 'center'; c.textBaseline = 'alphabetic';
  const n = L.items.length, base = L.size * 0.36;
  L.items.forEach((it, i) => {
    if (it.space) return;
    const f = fn ? fn(i, n, it) : {};
    const a = f.a ?? 1, sc = f.s ?? 1;
    if (a <= 0.003 || Math.abs(sc) < 0.003) return;
    c.save();
    c.translate(x + it.x * (f.xs ?? 1) + (f.dx || 0), y + (f.dy || 0));
    if (f.rot) c.rotate(f.rot);
    c.scale(sc * (f.sx || 1), sc * (f.sy || 1));
    c.globalAlpha *= clamp(a);
    if ((f.blur || 0) > 0.4) c.filter = `blur(${f.blur.toFixed(1)}px)`;
    if (style.shadow) {
      c.shadowColor = style.shadow; c.shadowBlur = style.shadowBlur ?? 26;
      c.shadowOffsetY = style.shadowY ?? 10;
    }
    c.fillStyle = f.fill || style.fill;
    c.fillText(it.ch, 0, base);
    c.restore();
  });
  c.restore();
}
// Elastic per-letter entrance.
const popIn = (t, t0, stagger = 0.05, dur = 0.75, rise = 70) => i => {
  const p = prog(t, t0 + i * stagger, t0 + i * stagger + dur);
  return { s: E.outElastic(p), a: clamp(p * 5), dy: (1 - E.out(p)) * rise };
};

// ------------------------------------------------------ shared ocean env ---
function oceanBg(c, mood, t) {
  const g = c.createLinearGradient(0, 0, 0, H);
  if (mood === 'deep') {
    g.addColorStop(0, '#0A78EC'); g.addColorStop(0.5, '#0A4CA8'); g.addColorStop(1, '#0B2552');
  } else {
    g.addColorStop(0, '#13CFFF'); g.addColorStop(0.45, C.blue); g.addColorStop(1, '#0A3C8C');
  }
  c.fillStyle = g; c.fillRect(0, 0, W, H);
  // light rays
  c.save(); c.globalCompositeOperation = 'lighter';
  for (let k = 0; k < 5; k++) {
    const x0 = 80 + k * 230 + Math.sin(t * 0.5 + k * 1.7) * 50;
    const rg = c.createLinearGradient(0, 0, 0, 1500);
    const a = (mood === 'deep' ? 0.05 : 0.085) * (0.7 + 0.3 * Math.sin(t * 0.8 + k));
    rg.addColorStop(0, `rgba(255,255,255,${a})`); rg.addColorStop(1, 'rgba(255,255,255,0)');
    c.fillStyle = rg;
    c.beginPath(); c.moveTo(x0, -10); c.lineTo(x0 + 90, -10); c.lineTo(x0 + 330, 1500); c.lineTo(x0 + 70, 1500); c.closePath(); c.fill();
  }
  c.restore();
}
function vignette(c, a = 0.35) {
  const g = c.createRadialGradient(W / 2, H / 2, H * 0.3, W / 2, H / 2, H * 0.75);
  g.addColorStop(0, 'rgba(6,20,45,0)'); g.addColorStop(1, `rgba(6,20,45,${a})`);
  c.fillStyle = g; c.fillRect(0, 0, W, H);
}
function drawSeaweed(c, x, baseY, h, t, col, w, ph, sway = 1) {
  const N = 14;
  c.save(); c.lineCap = 'round'; c.strokeStyle = col;
  let px = x, py = baseY;
  for (let i = 1; i <= N; i++) {
    const k = i / N;
    const nx = x + Math.sin(t * 1.5 + ph + i * 0.45) * k * 34 * sway;
    const ny = baseY - h * k;
    c.lineWidth = w * (1 - k * 0.65);
    c.beginPath(); c.moveTo(px, py); c.lineTo(nx, ny); c.stroke();
    if (i % 3 === 0) {
      c.fillStyle = col;
      c.save(); c.translate(nx, ny); c.rotate((i % 2 ? 0.9 : -0.9) + Math.sin(t * 2 + i) * 0.2);
      c.beginPath(); c.ellipse(w * 0.9, 0, w * 1.1, w * 0.45, 0, 0, TAU); c.fill(); c.restore();
    }
    px = nx; py = ny;
  }
  c.restore();
}
function rockPts(seed, n = 12) {
  const r = rng(seed); const pts = [];
  for (let i = 0; i < n; i++) pts.push(0.86 + r() * 0.22);
  return pts;
}
function drawRock(c, R) {
  const n = R.pts.length, P = [];
  for (let i = 0; i < n; i++) {
    const a = i / n * TAU;
    P.push([R.x + Math.cos(a) * R.rx * R.pts[i], R.y + Math.sin(a) * R.ry * R.pts[i]]);
  }
  const g = c.createLinearGradient(0, R.y - R.ry, 0, R.y + R.ry * 0.6);
  g.addColorStop(0, '#3D6390'); g.addColorStop(1, '#122E4F');
  c.fillStyle = g;
  c.beginPath();
  for (let i = 0; i <= n; i++) {
    const p0 = P[i % n], p1 = P[(i + 1) % n];
    const mx = (p0[0] + p1[0]) / 2, my = (p0[1] + p1[1]) / 2;
    if (i === 0) c.moveTo(mx, my); else c.quadraticCurveTo(p0[0], p0[1], mx, my);
  }
  c.closePath(); c.fill();
  c.save(); c.clip();
  c.fillStyle = 'rgba(255,255,255,0.10)';
  c.beginPath(); c.ellipse(R.x - R.rx * 0.25, R.y - R.ry * 0.7, R.rx * 0.55, R.ry * 0.25, -0.2, 0, TAU); c.fill();
  c.fillStyle = 'rgba(8,24,48,0.35)';
  for (const [dx, dy, rr] of [[0.3, -0.2, 0.12], [-0.4, 0.1, 0.09], [0.1, 0.3, 0.1]]) {
    c.beginPath(); c.arc(R.x + dx * R.rx, R.y + dy * R.ry, rr * R.rx, 0, TAU); c.fill();
  }
  c.restore();
}
const ROCK_L = { x: 500, y: 1460, rx: 200, ry: 175, pts: rockPts(3) };
const ROCK_R = { x: 885, y: 1430, rx: 230, ry: 215, pts: rockPts(11) };
const FISH_TRAP = { x: 705, y: 1262 };
const ANCHOR = { x: 838, y: 1262 };
const P_REST = { x: 572, y: 1232 };
const DECOR_WEED = [
  [300, 1640, 380, '#12A889', 26, 0], [395, 1640, 300, '#17C29C', 22, 1.2], [1000, 1640, 420, '#12A889', 28, 2.1],
  [1060, 1640, 300, '#1DE9B6', 20, 0.4], [180, 1640, 260, '#0E8F75', 22, 2.8], [620, 1640, 230, '#17C29C', 18, 1.7],
];
function deepFloor(c) {
  const g = c.createLinearGradient(0, 1560, 0, H);
  g.addColorStop(0, '#0D3D7A'); g.addColorStop(1, '#081E40');
  c.fillStyle = g;
  c.beginPath(); c.moveTo(0, 1600);
  for (let x = 0; x <= W; x += 40) c.lineTo(x, 1600 + Math.sin(x * 0.012) * 16);
  c.lineTo(W, H); c.lineTo(0, H); c.closePath(); c.fill();
}
function deepBack(c, t) {
  for (const [x, y, h, col, w, ph] of DECOR_WEED) drawSeaweed(c, x, y, h, t, col, w, ph);
}
function deepRocks(c) { drawRock(c, ROCK_L); drawRock(c, ROCK_R); }
function deepFront(c, t) {
  drawSeaweed(c, 40, 1960, 620, t, '#0B7A63', 40, 0.9, 0.7);
  drawSeaweed(c, 1060, 1980, 520, t, '#0B7A63', 36, 2.2, 0.7);
}
const BUB = (() => {
  const r = rng(21), list = [];
  for (let i = 0; i < 46; i++) list.push({ x: r() * W, y0: r() * H, v: 70 + r() * 170, r: 5 + r() * 20, ph: r() * TAU });
  return list;
})();
function risingBubbles(c, t, t0, alpha = 1, count = 46, xoff = 0) {
  for (let i = 0; i < count; i++) {
    const b = BUB[i];
    const y = ((b.y0 - (t - t0) * b.v) % (H + 100) + H + 100) % (H + 100) - 50;
    const x = ((b.x + Math.sin(t * 1.6 + b.ph) * 18 - xoff) % W + W) % W;
    drawBubble(c, x, y, b.r, alpha * 0.85);
  }
}
// The seaweed strand trapping the fish. Returns its polyline.
function strandPath(t, P, slack) {
  const A = ANCHOR, pts = [];
  const mx = (A.x + P.x) / 2, my = (A.y + P.y) / 2;
  const cx = lerp(mx, 712, slack), cy = lerp(my, 1150, slack);
  for (let i = 0; i <= 28; i++) {
    const u = i / 28, v = 1 - u;
    pts.push([v * v * A.x + 2 * v * u * cx + u * u * P.x, v * v * A.y + 2 * v * u * cy + u * u * P.y]);
  }
  return pts;
}
function strokeStrand(c, pts, thick, t, wobble = 0) {
  const P = pts.map(([x, y], i) => [x, y + Math.sin(t * 40 + i * 0.9) * wobble * Math.sin(i / (pts.length - 1) * Math.PI)]);
  c.save(); c.lineCap = 'round'; c.lineJoin = 'round';
  const path = () => { c.beginPath(); P.forEach(([x, y], i) => (i ? c.lineTo(x, y) : c.moveTo(x, y))); };
  c.strokeStyle = '#0B7F63'; c.lineWidth = thick + 7; path(); c.stroke();
  c.strokeStyle = '#25DDAA'; c.lineWidth = thick; path(); c.stroke();
  c.strokeStyle = 'rgba(255,255,255,0.35)'; c.lineWidth = Math.max(2, thick * 0.22);
  c.beginPath(); P.forEach(([x, y], i) => (i ? c.lineTo(x, y - thick * 0.22) : c.moveTo(x, y - thick * 0.22))); c.stroke();
  c.fillStyle = '#1BC596';
  for (let i = 3; i < P.length - 2; i += 5) {
    const [x, y] = P[i], [x2, y2] = P[i + 1];
    const a = Math.atan2(y2 - y, x2 - x) + (i % 2 ? 0.9 : -0.9);
    c.save(); c.translate(x, y); c.rotate(a);
    c.beginPath(); c.ellipse(thick * 0.9, 0, thick * 1.1, thick * 0.42, 0, 0, TAU); c.fill(); c.restore();
  }
  c.restore();
}

// ---------------------------------------------------- SCENE 1 — INTRO -----
const S1_SHAPES = [
  ['tri', 205, 760, 58, C.cyan, 0.95], ['ring', 880, 720, 52, C.blue, 1.05], ['square', 165, 1380, 52, C.orange, 1.12],
  ['dot', 905, 1400, 30, C.navy, 1.2], ['plus', 830, 1590, 44, C.cyan, 1.28], ['dot', 285, 1600, 20, C.blue, 1.34],
  ['tri', 940, 1060, 38, C.orange, 1.42], ['ring', 125, 1050, 32, C.cyan, 1.48], ['dot', 420, 690, 15, C.orange, 1.55],
  ['square', 700, 650, 26, C.blue, 1.6], ['plus', 300, 1220, 22, C.navy, 1.66], ['dot', 760, 1230, 12, C.cyan, 1.7],
];
function s1Shrimp(t) {
  const o = { x: 540, y: 1080, s: 1.32, rot: 0, expr: 'happy', swim: 0.3, look: [0.35, 0], sx: 1, sy: 1 };
  const pj = prog(t, 0.45, 1.25);
  if (t < 1.25) {
    o.y = lerp(2300, 1080, E.out(pj)) - Math.sin(pj * Math.PI) * 280;
    o.rot = lerp(-0.7, 0, E.out(pj)); o.swim = 1;
  }
  const q = prog(t, 1.25, 1.85);
  if (q > 0 && q < 1) { const sq = Math.sin(q * Math.PI * 3) * (1 - q) * 0.22; o.sy = 1 - sq; o.sx = 1 + sq * 0.8; }
  const sp = prog(t, 1.75, 2.5);
  if (sp > 0) { o.rot += TAU * E.inOut(sp); o.y -= Math.sin(sp * Math.PI) * 120; }
  if (t > 2.5) o.y += Math.sin((t - 2.5) * 3) * 8;
  o.look = t > 2.6 ? [0.15, 0.25] : o.look;
  o.wave = t > 3.0 ? E.inOut(prog(t, 3.0, 3.3)) * (1 - E.inOut(prog(t, 4.0, 4.3))) : 0;
  return o;
}
function scene1(c, t) {
  c.fillStyle = C.white; c.fillRect(0, 0, W, H);
  const bg = c.createRadialGradient(540, 1060, 200, 540, 1060, 1200);
  bg.addColorStop(0, '#FFFFFF'); bg.addColorStop(1, '#EAF3FC');
  c.fillStyle = bg; c.fillRect(0, 0, W, H);
  c.save();
  cam(c, 540, 1000, lerp(1.0, 1.07, E.inOut(prog(t, 0.3, 4.6))));
  const cx = 540, cy = 1080;
  // three expanding circles
  const R = [450, 330, 225];
  for (let i = 0; i < 3; i++) {
    const r = R[i] * E.outElastic(prog(t, 0.05 + i * 0.16, 1.15 + i * 0.16));
    if (r <= 0) continue;
    if (i === 0) {
      c.fillStyle = 'rgba(0,123,255,0.07)'; c.beginPath(); c.arc(cx, cy, r, 0, TAU); c.fill();
      c.strokeStyle = 'rgba(0,123,255,0.22)'; c.lineWidth = 3; c.stroke();
    } else if (i === 1) {
      c.save(); c.strokeStyle = C.cyan; c.lineWidth = 10; c.setLineDash([26, 22]);
      c.lineDashOffset = -t * 60; c.lineCap = 'round';
      c.beginPath(); c.arc(cx, cy, r, 0, TAU); c.stroke(); c.restore();
    } else {
      c.save(); c.shadowColor = 'rgba(0,90,200,0.35)'; c.shadowBlur = 50; c.shadowOffsetY = 24;
      const g = c.createLinearGradient(cx - r, cy - r, cx + r, cy + r);
      g.addColorStop(0, C.cyan); g.addColorStop(1, C.blue);
      c.fillStyle = g; c.beginPath(); c.arc(cx, cy, r, 0, TAU); c.fill(); c.restore();
      c.fillStyle = 'rgba(255,255,255,0.18)'; c.beginPath(); c.ellipse(cx - r * 0.3, cy - r * 0.45, r * 0.45, r * 0.2, -0.5, 0, TAU); c.fill();
    }
  }
  // bouncing geometric shapes
  S1_SHAPES.forEach(([type, x, y, size, col, t0], i) => {
    const p = prog(t, t0, t0 + 0.9);
    const bounce = Math.abs(Math.sin((t - t0) * 2.6 + i)) * 26 * clamp(p * 3);
    drawShape(c, type, x, y - bounce, size * E.outElastic(p), col, t * 0.7 * (i % 2 ? 1 : -1) + i, 1);
  });
  // shrimp (+ motion-blur ghosts while moving fast)
  const o = s1Shrimp(t);
  if (t > 1.2) groundShadow(c, 540, 1235, 170 * (1 - Math.sin(prog(t, 1.75, 2.5) * Math.PI) * 0.35), 0.8);
  const fast = (t > 0.45 && t < 1.3) || (t > 1.75 && t < 2.5);
  if (fast) for (let k = 3; k >= 1; k--) drawShrimp(c, t - k * 0.022, { ...s1Shrimp(t - k * 0.022), alpha: 0.14 });
  drawShrimp(c, t, o);
  c.restore();

  // typography: MEET -> SHRIMPY! 🦐
  const ty = 430;
  if (t < 2.85) {
    const L = layout('MEET', 210, 18);
    const m = E.inBack(prog(t, 2.45, 2.8));
    drawText(c, L, 540, ty, { fill: C.blue, shadow: 'rgba(0,123,255,0.25)' }, (i, n, it) => {
      const f = popIn(t, 0.85, 0.07)(i);
      return { ...f, xs: 1 - m, s: f.s * (1 - m * 0.5), a: f.a * (1 - m), blur: m * 16 };
    });
  }
  if (t > 2.55) {
    const L = layout('SHRIMPY! 🦐', 150, 6);
    drawText(c, L, 540, ty, { fill: C.navy, shadow: 'rgba(16,42,67,0.22)' }, (i, n) => {
      const p = prog(t, 2.6 + i * 0.03, 3.25 + i * 0.03);
      return { xs: lerp(0, 1, E.outBack(p)), s: lerp(0.4, 1, E.outElastic(p)), a: clamp(p * 4), blur: (1 - E.out(p)) * 14 };
    });
    const u = E.out(prog(t, 3.05, 3.55));
    if (u > 0) {
      c.fillStyle = C.orange; c.beginPath(); c.roundRect(540 - 170 * u, ty + 92, 340 * u, 16, 8); c.fill();
    }
  }
}

// ------------------------------------------------ SCENE 2 — BIG DREAMS ----
const S2 = (() => {
  const r = rng(7), near = [], far = [];
  const types = ['tower', 'bubble', 'pyramid', 'fan', 'tube'];
  const cols = [C.orange, C.cyan, C.pink, C.yellow, '#FFFFFF', C.teal, C.orange];
  for (let x = -260, i = 0; x < 2600; x += 150 + r() * 160, i++) near.push({ x, type: pick(r, types), h: 170 + r() * 230, col: pick(r, cols), ph: r() * TAU, i });
  for (let x = -200, i = 0; x < 1900; x += 120 + r() * 120, i++) far.push({ x, type: pick(r, types), h: 160 + r() * 200, col: '#4FA9FF', ph: r() * TAU, i });
  return { near, far };
})();
function drawCoral(c, k, x, gy, grow, t, scale = 1) {
  if (grow <= 0) return;
  c.save(); c.translate(x, gy); c.rotate(Math.sin(t * 1.3 + k.ph) * 0.04); c.scale(scale * grow, scale * grow);
  const h = k.h, col = k.col;
  c.fillStyle = col; c.strokeStyle = col; c.lineCap = 'round';
  const shade = 'rgba(16,42,67,0.16)';
  switch (k.type) {
    case 'tower':
      for (let j = 0; j < 3; j++) {
        const hh = h * (0.55 + j * 0.2), xx = (j - 1) * 34;
        c.fillStyle = col; c.beginPath(); c.roundRect(xx - 14, -hh, 28, hh, 14); c.fill();
        c.beginPath(); c.arc(xx, -hh, 22, 0, TAU); c.fill();
        c.fillStyle = shade; c.beginPath(); c.roundRect(xx + 2, -hh, 12, hh, 6); c.fill();
      }
      break;
    case 'bubble':
      for (let j = 0; j < 6; j++) {
        const rr = 34 - j * 3.5, yy = -rr - j * 40, xx = Math.sin(j * 1.7 + k.ph) * 22;
        c.fillStyle = col; c.beginPath(); c.arc(xx, yy * h / 260, rr, 0, TAU); c.fill();
        c.fillStyle = 'rgba(255,255,255,0.3)'; c.beginPath(); c.arc(xx - rr * 0.35, yy * h / 260 - rr * 0.35, rr * 0.3, 0, TAU); c.fill();
      }
      break;
    case 'pyramid':
      for (let j = 0; j < 3; j++) {
        const w = 120 - j * 30, y0 = -j * h * 0.28;
        c.fillStyle = j % 2 ? shade : col;
        c.beginPath(); c.moveTo(-w / 2, y0); c.lineTo(0, y0 - h * 0.42); c.lineTo(w / 2, y0); c.closePath(); c.fill();
        if (j % 2) { c.fillStyle = col; c.globalAlpha *= 0.9; c.fill(); c.globalAlpha /= 0.9; }
      }
      break;
    case 'fan':
      c.lineWidth = 14; c.beginPath(); c.moveTo(0, 0); c.lineTo(0, -h * 0.35); c.stroke();
      c.beginPath(); c.arc(0, -h * 0.35, h * 0.55, Math.PI, TAU); c.closePath(); c.fill();
      c.strokeStyle = shade; c.lineWidth = 6;
      for (let j = 1; j < 6; j++) { const a = Math.PI + j * Math.PI / 6; c.beginPath(); c.moveTo(0, -h * 0.35); c.lineTo(Math.cos(a) * h * 0.5, -h * 0.35 + Math.sin(a) * h * 0.5); c.stroke(); }
      break;
    default: // tube
      for (let j = 0; j < 3; j++) {
        const hh = h * (0.5 + (j === 1 ? 0.35 : 0.1 * j)), xx = (j - 1) * 40;
        c.fillStyle = col; c.beginPath(); c.roundRect(xx - 18, -hh, 36, hh, 18); c.fill();
        c.fillStyle = shade; c.beginPath(); c.ellipse(xx, -hh + 12, 12, 6, 0, 0, TAU); c.fill();
      }
  }
  c.restore();
}
function s2Shrimp(t) {
  const o = { x: 0, y: 0, s: 1.22, rot: 0, expr: 'happy', swim: 0.75, look: [0.4, 0] };
  o.x = lerp(-420, 470, E.out(prog(t, 5.1, 6.1)));
  o.y = 1080 + Math.sin(t * 2.2) * 26;
  o.rot = Math.sin(t * 2.2 + 1) * 0.06;
  const up = E.inOut(prog(t, 7.9, 8.5));
  o.rot = lerp(o.rot, -0.32, up); o.y -= up * 40; o.look = [lerp(0.4, 0.3, up), lerp(0, -1, up)];
  o.swim = lerp(0.75, 0.25, up);
  return o;
}
function scene2(c, t) {
  t = Math.max(t, 5);
  c.fillStyle = C.blue; c.fillRect(0, 0, W, H);
  const build = E.inOut(prog(t, 5.0, 5.8));
  c.save(); c.globalAlpha = build; oceanBg(c, 'day', t); c.restore();
  const camX = Math.max(0, t - 5.3) * 230;
  // far layer (parallax 0.35)
  c.save(); c.globalAlpha = 0.45 * build;
  for (const k of S2.far) {
    const x = k.x - camX * 0.35;
    if (x < -200 || x > W + 200) continue;
    drawCoral(c, k, x, 1560, E.outBack(prog(t, 5.2 + Math.min(k.i, 10) * 0.03, 5.9 + Math.min(k.i, 10) * 0.03)), t, 0.6);
  }
  c.restore();
  // floor
  const fg = c.createLinearGradient(0, 1600, 0, H);
  fg.addColorStop(0, '#0B4FA8'); fg.addColorStop(1, '#092F6E');
  c.fillStyle = fg;
  c.beginPath(); c.moveTo(0, H);
  for (let x = 0; x <= W; x += 30) c.lineTo(x, H - 280 * build + Math.sin((x + camX) * 0.011) * 18);
  c.lineTo(W, H); c.closePath(); c.fill();
  // near corals
  for (const k of S2.near) {
    const x = k.x - camX;
    if (x < -220 || x > W + 220) continue;
    drawCoral(c, k, x, 1660 + Math.sin((k.x) * 0.011) * 14, E.outBack(prog(t, 5.3 + Math.min(k.i, 8) * 0.05, 6.0 + Math.min(k.i, 8) * 0.05)), t, 1);
  }
  // bubbles + particles
  risingBubbles(c, t, 5, build, 34, camX * 0.6);
  c.save(); c.fillStyle = 'rgba(255,255,255,0.55)';
  for (let i = 0; i < 40; i++) {
    const r = rng(100 + i); const bx = r() * W, by = r() * H;
    const x = ((bx - camX * 0.8 + Math.sin(t + i) * 12) % W + W) % W, y = ((by - t * 25) % H + H) % H;
    c.globalAlpha = build * (0.35 + 0.35 * Math.sin(t * 3 + i));
    c.beginPath(); c.arc(x, y, 2 + (i % 3), 0, TAU); c.fill();
  }
  c.restore();
  // shrimp
  const o = s2Shrimp(t);
  drawShrimp(c, t, o);
  // dream sparkles
  const sp = prog(t, 8.2, 9.5);
  if (sp > 0) {
    for (let i = 0; i < 6; i++) {
      const p = prog(t, 8.2 + i * 0.12, 8.9 + i * 0.12);
      const x = o.x + 150 + Math.cos(i * 1.3) * 150, y = o.y - 280 - i * 40 + Math.sin(t * 2 + i) * 10;
      drawShape(c, 'star', x, y, (16 + (i % 3) * 8) * E.outElastic(p) * (0.85 + 0.15 * Math.sin(t * 6 + i)), i % 2 ? C.yellow : '#fff', t * 0.8, 1);
    }
  }
  // foreground parallax bokeh
  c.save(); c.filter = 'blur(10px)';
  for (let i = 0; i < 5; i++) {
    const r = rng(300 + i);
    const x = ((r() * W * 1.6 - camX * 1.6) % (W * 1.6) + W * 1.6) % (W * 1.6) - W * 0.3;
    drawBubble(c, x, 300 + r() * 1400, 40 + r() * 40, 0.6 * build);
  }
  c.restore();
  vignette(c, 0.3);

  // typography: SMALL SIZE -> (scatter) -> BIG DREAMS!
  const ty = 420, style = { fill: '#FFFFFF', shadow: 'rgba(6,30,80,0.35)' };
  if (t < 7.9) {
    const L = layout('SMALL SIZE', 150, 6);
    drawText(c, L, 540, ty, style, (i, n) => {
      const f = popIn(t, 5.5, 0.045)(i);
      const r = rng(500 + i), p = E.in(prog(t, 7.2 + i * 0.015, 7.75 + i * 0.015));
      const ang = r() * TAU, d = 350 + r() * 450;
      return { s: f.s * (1 - p * 0.6), a: f.a * (1 - p), dy: f.dy + Math.sin(ang) * d * p, dx: Math.cos(ang) * d * p, rot: (r() - 0.5) * 3 * p, blur: p * 8 };
    });
  }
  if (t > 7.35) {
    const L = layout('BIG DREAMS!', 150, 6);
    drawText(c, L, 540, ty, { ...style, shadow: 'rgba(0,223,255,0.6)', shadowY: 0, shadowBlur: 34 }, (i, n) => {
      const r = rng(900 + i), p = E.out(prog(t, 7.4 + i * 0.035, 8.15 + i * 0.035));
      const ang = r() * TAU, d = 400 + r() * 400;
      return { dx: Math.cos(ang) * d * (1 - p), dy: Math.sin(ang) * d * (1 - p), rot: (r() - 0.5) * 3 * (1 - p), s: lerp(0.4, 1, p), a: clamp(p * 2), blur: (1 - p) * 8,
        fill: i >= 4 ? '#FFFFFF' : C.yellow };
    });
  }
}

// -------------------------------------------------- SCENE 3 — OH NO! ------
function fishTrapped(t, strength = 1) {
  return {
    x: FISH_TRAP.x + Math.sin(t * 23) * 6 * strength, y: FISH_TRAP.y + Math.sin(t * 17) * 4 * strength,
    rot: Math.sin(t * 19) * 0.12 * strength, s: 0.95, flip: true, expr: 'worried', wagSpeed: 22, look: [0.6, -0.3],
  };
}
function s3Shrimp(t) {
  const o = { x: 0, y: 1160, s: 1.0, rot: 0, expr: 'happy', swim: 0.8, look: [0.4, 0] };
  o.x = lerp(-260, 300, E.out(prog(t, 10.2, 11.5)));
  o.y += Math.sin(t * 2.4) * 14;
  o.rot = Math.sin(t * 2.4 + 1) * 0.05;
  if (t >= 12.0) {
    o.expr = 'surprised'; o.look = [1, -0.1]; o.swim = 0.2;
    const hp = prog(t, 12.0, 12.4);
    o.y -= Math.sin(hp * Math.PI) * 60;
    const sq = Math.sin(prog(t, 12.0, 12.5) * Math.PI * 2) * (1 - prog(t, 12.0, 12.5)) * 0.15;
    o.sx = 1 - sq; o.sy = 1 + sq;
  }
  return o;
}
function warningRings(c, t, x, y, t0, t1) {
  for (let k = 0; k < 8; k++) {
    const s0 = t0 + k * 0.55;
    if (s0 > t1) break;
    const p = prog(t, s0, s0 + 1.3);
    if (p <= 0 || p >= 1) continue;
    c.strokeStyle = `rgba(255,112,67,${0.75 * (1 - p)})`; c.lineWidth = 10 * (1 - p) + 2;
    c.beginPath(); c.arc(x, y, 50 + p * 260, 0, TAU); c.stroke();
  }
}
function scene3(c, t) {
  t = Math.max(t, 10);
  oceanBg(c, 'deep', t);
  // camera: quick zoom to shrimp's surprised face, then back out
  const o = s3Shrimp(t);
  const head = [o.x + 52, o.y - 30];
  const zin = E.inOut5(prog(t, 12.05, 12.4)), zout = E.inOut(prog(t, 13.6, 14.2));
  const k = zin * (1 - zout);
  const z = lerp(1.0, 2.15, k);
  const cx = lerp(540, head[0], k), cy = lerp(1000, head[1], k);
  const sh1 = shake(t, 12.0, 22, 7), sh2 = t > 12.7 && t < 14.5 ? [Math.sin(t * 61) * 5, Math.cos(t * 53) * 4] : [0, 0];
  c.save();
  cam(c, cx, cy, z, sh1[0] + sh2[0], sh1[1] + sh2[1]);
  deepFloor(c);
  deepBack(c, t);
  risingBubbles(c, t, 10, 0.6, 18);
  // fish + struggle bubbles
  const f = fishTrapped(t, 1);
  drawFish(c, t, f);
  for (let i = 0; i < 5; i++) {
    const ph = ((t * 0.9 + i * 0.2) % 1);
    drawBubble(c, f.x - 60 + Math.sin(t * 3 + i) * 10, f.y - 40 - ph * 260, 6 + i * 2, 1 - ph);
  }
  deepRocks(c);
  strokeStrand(c, strandPath(t, { x: P_REST.x + Math.sin(t * 2) * 4, y: P_REST.y }, 1), 22, t, 0);
  warningRings(c, t, FISH_TRAP.x, FISH_TRAP.y - 20, 10.6, 14.4);
  // "!" badge
  const bp = E.outElastic(prog(t, 10.7, 11.4));
  if (bp > 0) {
    const by = 1060 + Math.sin(t * 4) * 10;
    c.save(); c.translate(FISH_TRAP.x, by); c.scale(bp, bp);
    c.fillStyle = C.orange; c.beginPath(); c.arc(0, 0, 44, 0, TAU); c.fill();
    c.fillStyle = '#fff'; c.font = fontStr(64); c.textAlign = 'center'; c.textBaseline = 'middle'; c.fillText('!', 0, 4);
    c.restore();
  }
  drawShrimp(c, t, o);
  // surprise burst lines
  const sb = prog(t, 12.0, 12.45);
  if (sb > 0 && sb < 1) {
    c.save(); c.strokeStyle = `rgba(255,213,79,${1 - sb})`; c.lineWidth = 6; c.lineCap = 'round';
    for (let i = 0; i < 7; i++) {
      const a = -Math.PI * 0.95 + i * 0.3;
      const r0 = 95 + sb * 40, r1 = r0 + 40;
      c.beginPath(); c.moveTo(head[0] + Math.cos(a) * r0, head[1] + Math.sin(a) * r0);
      c.lineTo(head[0] + Math.cos(a) * r1, head[1] + Math.sin(a) * r1); c.stroke();
    }
    c.restore();
  }
  deepFront(c, t);
  c.restore();
  vignette(c, 0.4);

  // typography: OH NO! -> HELP!
  const ty = 400;
  if (t < 12.85) {
    const L = layout('OH NO!', 200, 8);
    const out = E.inBack(prog(t, 12.55, 12.85));
    drawText(c, L, 540, ty, { fill: C.orange, shadow: 'rgba(0,0,0,0.3)' }, (i) => {
      const p = prog(t, 10.5 + i * 0.06, 11.3 + i * 0.06);
      const jit = t > 12.3 ? Math.sin(t * 70 + i * 2) * 7 : 0;
      return { dy: -(1 - E.outBounce(p)) * 500, a: clamp(p * 6) * (1 - out), s: 1 - out * 0.7, dx: jit, rot: jit * 0.01 };
    });
  }
  if (t > 12.7) {
    const L = layout('HELP!', 230, 10);
    drawText(c, L, 540, ty, { fill: '#FFFFFF', shadow: 'rgba(255,82,82,0.85)', shadowY: 0, shadowBlur: 30 }, (i) => {
      const f = popIn(t, 12.72, 0.05, 0.6, 0)(i);
      const amp = 9 + 6 * Math.max(0, Math.sin(t * 6));
      return { ...f, dx: Math.sin(t * 64 + i * 1.7) * amp, dy: Math.cos(t * 57 + i * 2.3) * amp * 0.6, rot: Math.sin(t * 41 + i) * 0.07 };
    });
  }
}

// ---------------------------------------------- SCENE 4 — THE RESCUE ------
const SNAP = 18.9;
function s4Shrimp(t) {
  const o = { x: 150, y: 1190, s: 1.0, rot: 0, expr: 'determined', swim: 0.6, look: [1, 0.1], reach: 0, open: undefined, sx: 1, sy: 1 };
  if (t < 15.35) {
    const p = prog(t, 15.0, 15.35);
    o.x = lerp(150, 85, E.out(p)); o.sx = 1 - 0.14 * Math.sin(p * Math.PI); o.sy = 1 + 0.1 * Math.sin(p * Math.PI); o.swim = 0.3;
  } else if (t < 16.3) {
    const p = prog(t, 15.35, 16.3), e = E.inOut5(p);
    o.x = lerp(85, 450, e); o.y = lerp(1190, 1218, e);
    o.sx = 1 + 0.28 * Math.sin(p * Math.PI); o.sy = 1 - 0.14 * Math.sin(p * Math.PI);
    o.swim = 1; o.reach = E.out(prog(t, 15.95, 16.3)); o.open = lerp(0.3, 0.65, o.reach);
  } else if (t < 16.6) {
    const p = prog(t, 16.3, 16.6);
    o.x = 450 + Math.sin(p * Math.PI) * 8; o.y = 1218; o.reach = 1; o.open = lerp(0.65, 0.05, E.out(p));
    const sq = Math.sin(p * Math.PI) * 0.12; o.sx = 1 - sq; o.sy = 1 + sq;
  } else if (t < SNAP) {
    const p = prog(t, 16.6, SNAP), e = E.inOut(p);
    o.x = 450 - 250 * e - Math.sin(t * 30) * 5 * p; o.y = 1218 + Math.sin(t * 23) * 3 * p;
    o.rot = -0.16 * E.out(prog(t, 16.6, 17.0)) - 0.04 * Math.sin(t * 9);
    o.sx = 1 + 0.07 * Math.sin(t * 13) * p; o.sy = 1 - 0.05 * Math.sin(t * 13) * p;
    o.reach = 1; o.open = 0.05; o.swim = 1;
  } else {
    const p = prog(t, SNAP, 19.75);
    o.x = 200 - 110 * E.out(p); o.y = 1218 - Math.sin(p * Math.PI) * 60;
    o.rot = -0.16 - Math.sin(p * Math.PI) * 0.75 * (1 - p);
    o.reach = 1 - E.out(prog(t, 19.0, 19.5)); o.open = lerp(0.05, 0.35, o.reach < 1 ? 1 - o.reach : 0);
    o.expr = t < 19.45 ? 'surprised' : 'proud';
    o.swim = 0.5;
    const back = E.inOut(prog(t, 19.75, 20.7));
    o.x = lerp(o.x, 330, back); o.y = lerp(o.y, 1150, back);
    if (t > 19.75) o.y += Math.sin((t - 19.75) * 3) * 10;
    o.wave = E.inOut(prog(t, 20.3, 20.6));
    o.look = t > 19.6 ? [0.8, -0.6] : [1, 0.1];
  }
  return o;
}
function s4FishPath(t) {
  if (t < SNAP) return fishTrapped(t, t > 16.6 ? 1.3 : 1);
  const p = prog(t, SNAP, 20.2);
  if (t < 20.2) {
    const e = E.out(p), u = 1 - e;
    const P0 = [FISH_TRAP.x, FISH_TRAP.y], P1 = [760, 1000], P2 = [800, 820], P3 = [600, 860];
    const x = u * u * u * P0[0] + 3 * u * u * e * P1[0] + 3 * u * e * e * P2[0] + e * e * e * P3[0];
    const y = u * u * u * P0[1] + 3 * u * u * e * P1[1] + 3 * u * e * e * P2[1] + e * e * e * P3[1];
    return { x, y, s: 0.95, flip: e > 0.62, rot: e < 0.6 ? -0.9 * (1 - e) : 0, expr: 'happy', wagSpeed: 16 };
  }
  const a = (t - 20.2) * 3.2;
  return { x: 560 + Math.sin(a) * 70, y: 870 + Math.sin(a * 2) * 26 + Math.sin(t * 2) * 8, s: 0.95, flip: Math.cos(a) < 0 ? false : true, expr: 'happy', wagSpeed: 10, look: [-0.5, 0.4] };
}
const PARTS = (() => {
  const r = rng(77), list = [];
  const types = ['dot', 'tri', 'square', 'ring', 'plus', 'star', 'dot'];
  const cols = [C.orange, C.cyan, '#FFFFFF', C.yellow, C.pink, C.teal, C.blue];
  for (let i = 0; i < 70; i++) {
    const a = r() * TAU;
    list.push({ a, v: 500 + r() * 1300, type: pick(r, types), col: pick(r, cols), size: 9 + r() * 22, spin: (r() - 0.5) * 10, life: 0.9 + r() * 0.8 });
  }
  return list;
})();
function snapPoint() { return strandPath(SNAP, { x: 325, y: 1232 }, 0)[14]; }
function scene4(c, t) {
  t = Math.max(t, 15);
  oceanBg(c, 'deep', t);
  const o = s4Shrimp(t);
  const pull = E.inOut(prog(t, 16.6, SNAP)), rel = E.inOut(prog(t, 19.2, 20.6));
  const z = lerp(1.0, 1.14, pull) * (1 - rel) + 1.0 * rel;
  let cx = lerp(540 + (o.x - 300) * 0.15, 490, pull), cy = lerp(1000, 1090, pull);
  cx = lerp(cx, 540, rel); cy = lerp(cy, 1000, rel);
  const sh = shake(t, SNAP, 34, 5);
  const tremble = t > 16.6 && t < SNAP ? 3 * pull : 0;
  c.save();
  cam(c, cx, cy, z, sh[0] + Math.sin(t * 70) * tremble, sh[1] + Math.cos(t * 63) * tremble);
  deepFloor(c);
  deepBack(c, t);
  risingBubbles(c, t, 15, 0.6, 18);
  const f = s4FishPath(t);
  if (t < SNAP) drawFish(c, t, f);
  deepRocks(c);
  // seaweed strand: rest -> grabbed & stretched -> snapped
  const B = snapPoint();
  if (t < SNAP) {
    const grabbed = t >= 16.3;
    const tip = grabbed ? shrimpClawTip(s4Shrimp(t)) : null;
    const P = grabbed ? { x: tip[0], y: tip[1] } : { x: P_REST.x + Math.sin(t * 2) * 4, y: P_REST.y };
    const len = Math.hypot(P.x - ANCHOR.x, P.y - ANCHOR.y), rest = Math.hypot(P_REST.x - ANCHOR.x, P_REST.y - ANCHOR.y);
    const stretch = clamp(len / rest, 1, 3);
    strokeStrand(c, strandPath(t, P, clamp(1.25 - stretch * 0.6 + (grabbed ? 0 : 0.35))), 22 * clamp(Math.pow(1 / stretch, 1.1), 0.38, 1), t, grabbed ? 2 + 4 * pull : 0);
  } else {
    const p = prog(t, SNAP, SNAP + 0.9), rec = E.outElastic(p);
    const A = ANCHOR, end1 = [lerp(B[0], A[0] - 70, rec), lerp(B[1], A[1] + 110, rec) + Math.sin(t * 9) * 6];
    strokeStrand(c, [[A.x, A.y], [lerp(A.x, end1[0], 0.5), Math.min(A.y, end1[1]) - 20], end1].flatMap((q, i, arr) => i ? [q] : [q]), 15, t, 0);
    const fade = 1 - prog(t, 19.3, 19.8);
    if (fade > 0) {
      const tip = shrimpClawTip(o);
      const end2 = [lerp(B[0], tip[0] + 30, rec), lerp(B[1], tip[1] + 90, rec)];
      c.save(); c.globalAlpha = fade;
      strokeStrand(c, [[tip[0], tip[1]], [(tip[0] + end2[0]) / 2, (tip[1] + end2[1]) / 2 + 20], end2], 13, t, 0);
      c.restore();
    }
  }
  if (t >= SNAP) drawFish(c, t, f);
  // speed lines during the rush
  const rush = prog(t, 15.35, 16.3);
  if (rush > 0 && rush < 1) {
    const sp = Math.sin(rush * Math.PI);
    c.save(); c.lineCap = 'round';
    for (let i = 0; i < 12; i++) {
      const r = rng(40 + i);
      const y = o.y - 90 + r() * 180, len = 140 + r() * 260, x1 = o.x - 140 - r() * 120;
      c.strokeStyle = i % 3 ? `rgba(255,255,255,${0.55 * sp})` : `rgba(0,223,255,${0.8 * sp})`;
      c.lineWidth = 4 + r() * 6;
      c.beginPath(); c.moveTo(x1, y); c.lineTo(x1 - len * sp, y); c.stroke();
    }
    c.restore();
    for (let k = 3; k >= 1; k--) drawShrimp(c, t - k * 0.025, { ...s4Shrimp(t - k * 0.025), alpha: 0.16 * sp });
  }
  drawShrimp(c, t, o);
  // snap: flash ring + particle explosion
  const dt = t - SNAP;
  if (dt > 0) {
    const fr = prog(dt, 0, 0.45);
    if (fr < 1) {
      c.strokeStyle = `rgba(255,255,255,${1 - fr})`; c.lineWidth = 18 * (1 - fr) + 2;
      c.beginPath(); c.arc(B[0], B[1], 30 + E.out(fr) * 380, 0, TAU); c.stroke();
    }
    for (const q of PARTS) {
      if (dt > q.life) continue;
      const k = 3.2, d = q.v * (1 - Math.exp(-k * dt)) / k;
      const x = B[0] + Math.cos(q.a) * d, y = B[1] + Math.sin(q.a) * d + 160 * dt * dt;
      const a = 1 - prog(dt, q.life * 0.55, q.life);
      drawShape(c, q.type, x, y, q.size * (1 - dt / q.life * 0.4) * E.outBack(prog(dt, 0, 0.15)), q.col, q.a + dt * q.spin, a);
    }
  }
  deepFront(c, t);
  c.restore();
  vignette(c, 0.4);
  // white impact flash
  const fl = 1 - prog(t, SNAP, SNAP + 0.35);
  if (dt > 0 && fl > 0) { c.fillStyle = `rgba(255,255,255,${0.5 * fl})`; c.fillRect(0, 0, W, H); }

  // typography: BE BRAVE! -> (impact) -> YOU DID IT!
  const ty = 400;
  if (t < SNAP + 0.2) {
    const L = layout('BE BRAVE!', 175, 8);
    const out = prog(t, SNAP - 0.02, SNAP + 0.18);
    drawText(c, L, 540, ty, { fill: '#FFFFFF', shadow: 'rgba(255,112,67,0.9)', shadowY: 0, shadowBlur: 28 }, (i) => {
      const f = popIn(t, 15.25, 0.05, 0.7, 90)(i);
      const pulse = t > 16.6 ? 1 + 0.04 * Math.sin(t * 12) : 1;
      return { ...f, s: f.s * pulse * (1 + out * 0.8), a: f.a * (1 - out), blur: out * 18 };
    });
  }
  if (t > SNAP) {
    const L = layout('YOU DID IT!', 165, 6);
    const p = prog(t, SNAP + 0.02, SNAP + 0.4);
    const e = E.outBack(p);
    drawText(c, L, 540, ty, { fill: C.yellow, shadow: 'rgba(255,112,67,0.95)', shadowY: 8, shadowBlur: 10 }, (i, n) => ({
      s: lerp(2.6, 1, e) * (1 + 0.025 * Math.sin((t - SNAP) * 5 + i * 0.6)), a: clamp(p * 3), blur: (1 - p) * 10, xs: lerp(1.6, 1, e),
      dy: Math.sin((t - SNAP) * 5 + i * 0.6) * 6,
    }));
  }
}

// ------------------------------------ transition 4 -> 5: burst to circles -
const TCIRC = (() => {
  const r = rng(5), list = [];
  const cols = [C.blue, C.cyan, C.orange, C.navy, '#FFFFFF', C.yellow, C.pink, C.blue, C.cyan];
  for (let gy = -1; gy <= 8; gy++) for (let gx = -1; gx <= 5; gx++) {
    list.push({ x: gx * 270 + (gy % 2 ? 135 : 0) + (r() - 0.5) * 40, y: gy * 245 + (r() - 0.5) * 40, rmax: 235 + r() * 70, col: pick(r, cols), d: r() * 0.12, d2: r() * 0.15 });
  }
  return list;
})();
function circleTransition(c, t) {
  const B = [540, 960];
  for (const q of TCIRC) {
    const pm = E.out(prog(t, 21.15 + q.d, 21.75 + q.d));
    if (pm <= 0) continue;
    const grow = E.inOut(prog(t, 21.35 + q.d, 21.85 + q.d));
    const shrink = E.inOut(prog(t, 22.0 + q.d2, 22.6 + q.d2));
    const r = (lerp(10, q.rmax, grow)) * (1 - shrink);
    if (r <= 0.5) continue;
    c.fillStyle = q.col;
    c.beginPath(); c.arc(lerp(B[0], q.x, pm), lerp(B[1], q.y, pm), r, 0, TAU); c.fill();
  }
}

// ------------------------------------------ SCENE 5 — HAPPY ENDING -------
const ORBIT = (() => {
  const r = rng(55), list = [];
  for (let i = 0; i < 16; i++) list.push({ a: i / 16 * TAU, type: ['dot', 'heart', 'ring', 'heart'][i % 4], col: [C.blue, C.orange, C.cyan, C.pink][i % 4], size: 16 + r() * 18, by: (r() - 0.5) * 80, ph: r() * TAU });
  return list;
})();
const FLOAT = (() => {
  const r = rng(66), list = [];
  for (let i = 0; i < 22; i++) list.push({ x: r() * W, y0: r() * H, v: 40 + r() * 70, size: 14 + r() * 30, type: i % 3 ? 'dot' : 'heart', col: i % 3 ? 'rgba(0,123,255,0.18)' : 'rgba(255,112,67,0.35)', ph: r() * TAU });
  return list;
})();
function s5Fish(t) {
  const a = (t - 22) * 1.7 + 0.6;
  const depth = Math.sin(a);
  return { x: 540 + Math.cos(a) * 340, y: 1150 + Math.sin(a) * 120 - 20, s: 0.78 + 0.18 * depth, flip: depth > 0, expr: 'happy', wagSpeed: 11, depth, look: [0.2, 0] };
}
function s5Shrimp(t) {
  const hop = Math.abs(Math.sin((t - 22) * Math.PI * 1.25)) * 32;
  const o = { x: 540 + Math.sin((t - 22) * 0.9) * 18, y: 1160 - hop, s: 1.32, expr: 'proud', swim: 0.35, look: [0.2, -0.3], rot: Math.sin((t - 22) * 2.5) * 0.05 };
  o.wave = E.inOut(prog(t, 22.6, 22.9)) * (1 - E.inOut(prog(t, 24.3, 24.6))) + E.inOut(prog(t, 25.4, 25.7));
  o.wave = clamp(o.wave);
  return o;
}
function scene5(c, t) {
  t = Math.max(t, 22);
  c.fillStyle = C.blue; c.fillRect(0, 0, W, H);
  const wash = E.inOut(prog(t, 22.1, 23.0));
  const rw = lerp(0, 2300, wash);
  if (rw > 0) {
    const g = c.createRadialGradient(540, 1100, 0, 540, 1100, rw);
    g.addColorStop(0, '#FFFFFF'); g.addColorStop(0.82, '#FFFFFF'); g.addColorStop(1, 'rgba(255,255,255,0)');
    c.fillStyle = g; c.fillRect(0, 0, W, H);
  }
  const soft = c.createRadialGradient(540, 1150, 300, 540, 1150, 1300);
  soft.addColorStop(0, 'rgba(234,243,252,0)'); soft.addColorStop(1, `rgba(214,232,250,${0.8 * wash})`);
  c.fillStyle = soft; c.fillRect(0, 0, W, H);

  // floating circles & hearts
  for (const q of FLOAT) {
    const y = ((q.y0 - (t - 22) * q.v) % (H + 100) + H + 100) % (H + 100) - 50;
    drawShape(c, q.type, q.x + Math.sin(t + q.ph) * 20, y, q.size, q.col, Math.sin(t + q.ph) * 0.3, 1);
  }
  // camera orbit sway
  const orbitRot = Math.sin((t - 22) * 0.8) * 0.02;
  c.save();
  cam(c, 540 + Math.sin((t - 22) * 0.9) * 25, 1000, 1.0 + 0.03 * Math.sin((t - 22) * 0.7), 0, 0, orbitRot);
  // glow
  const pulse = 0.5 + 0.5 * Math.sin(t * 3);
  const gl = c.createRadialGradient(540, 1140, 40, 540, 1140, 460);
  gl.addColorStop(0, `rgba(0,223,255,${0.22 + 0.08 * pulse})`); gl.addColorStop(1, 'rgba(0,223,255,0)');
  c.fillStyle = gl; c.fillRect(0, 500, W, 1300);
  // big beating heart
  const hp = E.outElastic(prog(t, 24.85, 25.7));
  if (hp > 0) {
    const beat = Math.pow(Math.max(0, Math.sin(t * TAU * 1.2)), 6) * 0.06;
    c.save(); c.translate(540, 1110); c.scale(hp * (1 + beat), hp * (1 + beat));
    const hg = c.createLinearGradient(-300, -300, 300, 300);
    hg.addColorStop(0, 'rgba(255,143,177,0.45)'); hg.addColorStop(1, 'rgba(255,112,67,0.45)');
    c.fillStyle = hg; heartPath(c, 300); c.fill();
    c.restore();
  }
  // orbit ring — back half
  const orb = ORBIT.map(q => {
    const a = q.a + (t - 22) * 0.45;
    return { ...q, x: 540 + Math.cos(a) * 470, y: 1180 + Math.sin(a) * 230 + q.by + Math.sin(t * 2 + q.ph) * 10, d: Math.sin(a) };
  });
  const drawOrb = q => {
    const appear = E.outBack(prog(t, 22.3 + q.a * 0.05, 22.9 + q.a * 0.05));
    c.save(); if (q.d < 0) c.filter = `blur(${(-q.d * 4).toFixed(1)}px)`;
    drawShape(c, q.type, q.x, q.y, q.size * (0.75 + 0.35 * q.d) * appear, q.col, Math.sin(t + q.ph) * 0.3, q.d < 0 ? 0.55 : 0.9);
    c.restore();
  };
  orb.filter(q => q.d < 0).forEach(drawOrb);
  const fsh = s5Fish(t);
  groundShadow(c, 540, 1345, 190, wash);
  if (fsh.depth < 0) drawFish(c, t, fsh);
  drawShrimp(c, t, s5Shrimp(t));
  if (fsh.depth >= 0) drawFish(c, t, fsh);
  orb.filter(q => q.d >= 0).forEach(drawOrb);
  // little hearts popping from the pair
  for (let i = 0; i < 8; i++) {
    const t0 = 22.8 + i * 0.5, p = prog(t, t0, t0 + 1.6);
    if (p <= 0 || p >= 1) continue;
    const x = 540 + (i % 2 ? 1 : -1) * (60 + i * 12) + Math.sin(p * 6 + i) * 20, y = 1000 - p * 380;
    drawShape(c, 'heart', x, y, 22 * E.outBack(prog(p, 0, 0.3)), i % 3 ? C.orange : C.pink, Math.sin(p * 5) * 0.2, 1 - prog(p, 0.6, 1));
  }
  c.restore();

  // typography: LITTLE HERO -> BIG HEART ❤️
  const ty = 420;
  if (t < 25.2) {
    const L = layout('LITTLE HERO', 140, 8);
    const out = E.inOut(prog(t, 24.75, 25.15));
    const track = lerp(1.35, 1, E.out(prog(t, 22.7, 24.0)));
    drawText(c, L, 540, ty, { fill: C.navy, shadow: 'rgba(16,42,67,0.18)' }, (i) => {
      const p = prog(t, 22.75 + i * 0.05, 23.5 + i * 0.05);
      return { xs: track, a: E.out(p) * (1 - out), dy: (1 - E.out(p)) * 50 - out * 50, blur: (1 - p) * 14 + out * 16, s: 1 - out * 0.12 };
    });
  }
  if (t > 24.9) {
    const L = layout('BIG HEART ❤️', 140, 8);
    const pulse = 1 + 0.02 * Math.sin(t * 5);
    drawText(c, L, 540, ty, { fill: C.orange, shadow: 'rgba(255,112,67,0.3)' }, (i) => {
      const p = prog(t, 24.95 + i * 0.04, 25.65 + i * 0.04);
      return { a: E.out(p), dy: (1 - E.out(p)) * 60, blur: (1 - p) * 16, s: lerp(0.85, 1, E.outBack(p)) * pulse };
    });
  }
}

// ---------------------------------------- SCENE 6 — FINAL MESSAGE --------
const S6_SHAPES = [
  ['tri', 160, 900, 34, C.cyan, 27.5], ['plus', 930, 880, 30, C.orange, 27.6], ['dot', 150, 1420, 18, C.blue, 27.7],
  ['square', 940, 1450, 28, C.navy, 27.8], ['ring', 880, 1650, 24, C.cyan, 27.9], ['dot', 210, 1640, 12, C.orange, 28.0],
];
const CONF = (() => {
  const r = rng(99), list = [];
  for (let i = 0; i < 26; i++) list.push({ a: -Math.PI / 2 + (r() - 0.5) * 2.6, v: 500 + r() * 700, type: pick(r, ['dot', 'star', 'tri', 'heart']), col: pick(r, [C.orange, C.cyan, C.blue, C.yellow]), size: 9 + r() * 12, spin: (r() - 0.5) * 8 });
  return list;
})();
function scene6(c, t) {
  t = Math.max(t, 27);
  c.fillStyle = C.white; c.fillRect(0, 0, W, H);
  const bg = c.createRadialGradient(540, 1130, 200, 540, 1130, 1200);
  bg.addColorStop(0, '#FFFFFF'); bg.addColorStop(1, '#EAF3FC');
  c.fillStyle = bg; c.fillRect(0, 0, W, H);
  const z = lerp(1.1, 1.0, E.out(prog(t, 27.0, 27.7))) * lerp(1, 0.9, E.inOut(prog(t, 28.5, 29.9)));
  c.save();
  cam(c, 540, 960, z);
  const cx = 540, cy = 1130;
  // soft disc + big blue ring
  const dp = E.outBack(prog(t, 27.05, 27.7));
  c.fillStyle = 'rgba(0,123,255,0.07)'; c.beginPath(); c.arc(cx, cy, 400 * dp, 0, TAU); c.fill();
  const rp = E.inOut(prog(t, 27.1, 27.85));
  if (rp > 0) {
    const rot = (t - 27) * 0.35;
    const g = c.createLinearGradient(cx - 360, cy - 360, cx + 360, cy + 360);
    g.addColorStop(0, C.cyan); g.addColorStop(1, C.blue);
    c.save(); c.strokeStyle = g; c.lineWidth = 34; c.lineCap = 'round';
    c.shadowColor = 'rgba(0,123,255,0.3)'; c.shadowBlur = 30; c.shadowOffsetY = 12;
    c.beginPath(); c.arc(cx, cy, 340, -Math.PI / 2 + rot, -Math.PI / 2 + rot + TAU * rp * 0.999); c.stroke(); c.restore();
    c.save(); c.strokeStyle = 'rgba(0,123,255,0.35)'; c.lineWidth = 4; c.setLineDash([14, 18]); c.lineDashOffset = t * 40;
    c.beginPath(); c.arc(cx, cy, 420 * rp, 0, TAU); c.stroke(); c.restore();
    [[C.orange, 0], [C.cyan, 2.1], [C.navy, 4.2]].forEach(([col, a0]) => {
      const a = a0 - (t - 27) * 1.2;
      drawShape(c, 'dot', cx + Math.cos(a) * 420 * rp, cy + Math.sin(a) * 420 * rp, 13 * rp, col, 0, 1);
    });
  }
  S6_SHAPES.forEach(([type, x, y, size, col, t0], i) => {
    const p = prog(t, t0, t0 + 0.8);
    drawShape(c, type, x, y - Math.abs(Math.sin((t - t0) * 2.4 + i)) * 18 * p, size * E.outElastic(p), col, t * 0.6 * (i % 2 ? 1 : -1), 1);
  });
  // shrimp waving
  const sp = E.outElastic(prog(t, 27.0, 27.75));
  groundShadow(c, cx, cy + 210, 170 * sp, 0.9);
  drawShrimp(c, t, { x: cx - 10, y: cy + Math.sin(t * 3) * 10, s: 1.45 * sp, expr: 'happy', swim: 0.3, look: [0.1, 0.2],
    wave: E.inOut(prog(t, 27.55, 27.9)), rot: Math.sin(t * 2) * 0.04 });
  c.restore();

  // final typography, word by word
  c.save(); cam(c, 540, 960, lerp(1, 0.95, E.inOut(prog(t, 28.5, 29.9))));
  const words = [
    ['SMALL', 170, 270, C.navy, 27.45], ['BUT', 110, 445, C.orange, 27.85], ['MIGHTY! 🦐', 175, 625, C.blue, 28.3],
  ];
  for (const [w, size, y, col, t0] of words) {
    const L = layout(w, size, 10);
    const p = prog(t, t0, t0 + 0.75);
    if (p <= 0) continue;
    drawText(c, L, 540, y, { fill: col, shadow: 'rgba(16,42,67,0.18)' }, (i) => ({
      s: E.outElastic(p), a: clamp(p * 5), xs: lerp(1.5, 1, E.out(p)), blur: (1 - clamp(p * 2)) * 10,
    }));
  }
  // confetti hit on MIGHTY!
  const dt = t - 28.3;
  if (dt > 0) for (const q of CONF) {
    const d = q.v * (1 - Math.exp(-3 * dt)) / 3;
    drawShape(c, q.type, 540 + Math.cos(q.a) * d, 625 + Math.sin(q.a) * d + 220 * dt * dt, q.size, q.col, dt * q.spin, 1 - prog(dt, 0.8, 1.5));
  }
  c.restore();
}

// ---------------------------------------------------------- compositor ---
function directionalBlur(c, buf, x, spread) {
  const N = spread > 2 ? 8 : 1;
  for (let k = 0; k < N; k++) {
    c.globalAlpha = 1 / (k + 1);
    c.drawImage(buf, x + (N > 1 ? (k / (N - 1) - 0.5) * spread : 0), 0);
  }
  c.globalAlpha = 1;
}
function render(t) {
  const c = ctx;
  c.setTransform(1, 0, 0, 1, 0, 0); c.globalAlpha = 1; c.filter = 'none';
  c.globalCompositeOperation = 'source-over';
  if (t < 4.3) scene1(c, t);
  else if (t < 5.0) {
    // blue circle expands from the shrimp and becomes the ocean
    scene1(c, t);
    const p = E.inOut(prog(t, 4.3, 5.0)), r = lerp(0, 2300, p);
    c.save(); c.beginPath(); c.arc(540, 1080, r, 0, TAU); c.clip(); scene2(c, t); c.restore();
  } else if (t < 9.35) scene2(c, t);
  else if (t < 10.0) {
    // bubble zoom
    const p = prog(t, 9.35, 10.0), e = E.in(p);
    const o = s2Shrimp(t), bx = o.x + 30, by = o.y - 10;
    scene2(ca, t);
    c.save(); c.translate(bx, by); c.scale(1 + e * 0.6, 1 + e * 0.6); c.translate(-bx, -by); c.drawImage(bufA, 0, 0); c.restore();
    const r = lerp(170, 2400, e) * E.outBack(prog(t, 9.35, 9.6));
    c.save(); c.beginPath(); c.arc(bx, by, r, 0, TAU); c.clip(); scene3(c, 10); c.restore();
    drawBubble(c, bx, by, r, 1);
    c.strokeStyle = 'rgba(255,255,255,0.9)'; c.lineWidth = 8 + e * 20;
    c.beginPath(); c.arc(bx, by, r, 0, TAU); c.stroke();
  } else if (t < 14.6) scene3(c, t);
  else if (t < 15.0) {
    // whip-pan
    const p = prog(t, 14.6, 15.0), u = E.inOut(p), spread = Math.sin(p * Math.PI) * 220;
    scene3(ca, t); scene4(cb, 15);
    c.fillStyle = '#0A4CA8'; c.fillRect(0, 0, W, H);
    directionalBlur(c, bufA, -u * W, spread);
    directionalBlur(c, bufB, (1 - u) * W, spread);
    c.save(); c.globalAlpha = Math.sin(p * Math.PI) * 0.5; c.strokeStyle = '#fff'; c.lineCap = 'round';
    for (let i = 0; i < 16; i++) { const r = rng(600 + i); c.lineWidth = 2 + r() * 5; const y = r() * H, x = r() * W; c.beginPath(); c.moveTo(x, y); c.lineTo(x + 300 + r() * 400, y); c.stroke(); }
    c.restore();
  } else if (t < 21.98) {
    scene4(c, t);
    if (t > 21.1) circleTransition(c, t);
  } else if (t < 26.55) {
    scene5(c, t);
    if (t < 22.8) circleTransition(c, t);
  } else if (t < 27.0) {
    // white flash with soft zoom
    const p = prog(t, 26.55, 27.0);
    scene5(ca, t);
    const zz = 1 + E.in(p) * 0.18;
    c.save(); c.translate(540, 1100); c.scale(zz, zz); c.translate(-540, -1100); c.drawImage(bufA, 0, 0); c.restore();
    c.fillStyle = `rgba(255,255,255,${E.in(p)})`; c.fillRect(0, 0, W, H);
  } else {
    scene6(c, t);
    const fin = 1 - E.out(prog(t, 27.0, 27.35));
    if (fin > 0) { c.fillStyle = `rgba(255,255,255,${fin})`; c.fillRect(0, 0, W, H); }
    const fade = E.inOut(prog(t, 29.3, 30.0));
    if (fade > 0) { c.fillStyle = `rgba(255,255,255,${fade})`; c.fillRect(0, 0, W, H); }
  }
}

// ------------------------------------------------------------ runtime ---
const ready = Promise.all([
  document.fonts.load(fontStr(100), 'MEET'),
  document.fonts.load('100px "Noto Color Emoji"', '🦐❤️'),
]).then(() => { layoutCache.clear(); }).catch(() => {});
window.DURATION = DUR;
window.whenReady = () => ready;
window.renderFrame = t => { render(clamp(t, 0, DUR - 1e-6)); };

const params = new URLSearchParams(location.search);
if (params.has('render')) {
  document.body.classList.add('render');
  ready.then(() => render(Number(params.get('t') || 0)));
} else {
  const audio = document.getElementById('audio');
  const btn = document.getElementById('play'), scrub = document.getElementById('scrub'), label = document.getElementById('time');
  let playing = false, t0 = 0, offset = 0, cur = 0;
  const draw = t => { cur = t; render(t); scrub.value = t.toFixed(2); label.textContent = `${t.toFixed(2)}s`; };
  const loop = now => {
    if (!playing) return;
    let t = offset + (now - t0) / 1000;
    if (t >= DUR) { offset = 0; t0 = now; t = 0; try { audio.currentTime = 0; } catch (e) {} }
    draw(t);
    requestAnimationFrame(loop);
  };
  const toggle = () => {
    playing = !playing; btn.textContent = playing ? '❚❚ Pause' : '▶ Play';
    if (playing) {
      offset = cur >= DUR - 0.05 ? 0 : cur; t0 = performance.now();
      try { audio.currentTime = offset; audio.play().catch(() => {}); } catch (e) {}
      requestAnimationFrame(loop);
    } else audio.pause();
  };
  btn.onclick = toggle; canvas.onclick = toggle;
  scrub.oninput = () => { const t = Number(scrub.value); offset = t; t0 = performance.now(); try { audio.currentTime = t; } catch (e) {} draw(t); };
  ready.then(() => draw(0));
}
})();
