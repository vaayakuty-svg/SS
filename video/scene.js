// GoldScalperATR — cinematic teaser. Everything is a pure function of time t (seconds),
// so any frame can be rendered independently: window.renderAt(t).
import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { ShaderPass } from 'three/addons/postprocessing/ShaderPass.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';

const W = 1920, H = 1080;
const TL = await (await fetch('./timeline.json')).json();
const HITS = TL.hits;

// ---------- fonts
for (const w of [600, 700]) {
  const f = new FontFace('Cinzel', `url(./node_modules/@fontsource/cinzel/files/cinzel-latin-${w}-normal.woff2)`, { weight: String(w) });
  document.fonts.add(await f.load());
}
await Promise.all(['300', '600', '900'].map(w => document.fonts.load(`${w} 100px "Inter Display"`)));
await document.fonts.load('500 100px "JetBrains Mono"');

// ---------- utils
const rngF = seed => () => { seed |= 0; seed = seed + 0x6D2B79F5 | 0; let t = Math.imul(seed ^ seed >>> 15, 1 | seed); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; };
const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
const lerp = (a, b, k) => a + (b - a) * k;
const ramp = (t, a, b) => clamp((t - a) / (b - a));
const E = {
  out3: x => 1 - Math.pow(1 - clamp(x), 3),
  inOut3: x => { x = clamp(x); return x < .5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2; },
  outExpo: x => { x = clamp(x); return x === 1 ? 1 : 1 - Math.pow(2, -10 * x); },
  in2: x => clamp(x) ** 2,
  outBack: x => { x = clamp(x); const c1 = 1.4, c3 = c1 + 1; return 1 + c3 * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2); },
};
const V3 = (x, y, z) => new THREE.Vector3(x, y, z);
const GOLD = new THREE.Color(1.0, 0.72, 0.32);
const gold = k => GOLD.clone().multiplyScalar(k);
const hitEnv = (t, rate) => HITS.reduce((s, h) => s + (t >= h.t ? h.size * Math.exp(-(t - h.t) * rate) : 0), 0);

// ---------- renderer + post
const renderer = new THREE.WebGLRenderer({ antialias: false, preserveDrawingBuffer: true, powerPreference: 'high-performance' });
renderer.setPixelRatio(1); renderer.setSize(W, H);
renderer.toneMapping = THREE.NoToneMapping;
document.body.appendChild(renderer.domElement);
const pmrem = new THREE.PMREMGenerator(renderer);
const ENV = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;

const rt = new THREE.WebGLRenderTarget(W, H, { type: THREE.HalfFloatType, samples: 4 });
const composer = new EffectComposer(renderer, rt);
const mainPass = new RenderPass(new THREE.Scene(), new THREE.PerspectiveCamera());
composer.addPass(mainPass);
const hudScene = new THREE.Scene();
const hudCam = new THREE.OrthographicCamera(-W / 2, W / 2, H / 2, -H / 2, -100, 100);
const hudPass = new RenderPass(hudScene, hudCam); hudPass.clear = false; hudPass.clearDepth = true;
composer.addPass(hudPass);
const bloom = new UnrealBloomPass(new THREE.Vector2(W, H), 0.6, 0.5, 0.9);
composer.addPass(bloom);
const finalPass = new ShaderPass({
  uniforms: { tDiffuse: { value: null }, uTime: { value: 0 }, uFlash: { value: 0 }, uFade: { value: 1 }, uCA: { value: 0 }, uRes: { value: new THREE.Vector2(W, H) } },
  vertexShader: `varying vec2 vUv; void main(){ vUv=uv; gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.); }`,
  fragmentShader: `
    uniform sampler2D tDiffuse; uniform float uTime,uFlash,uFade,uCA; uniform vec2 uRes; varying vec2 vUv;
    vec3 aces(vec3 x){ const float a=2.51,b=.03,c=2.43,d=.59,e=.14; return clamp((x*(a*x+b))/(x*(c*x+d)+e),0.,1.); }
    float hash(vec2 p){ p=fract(p*vec2(123.34,456.21)); p+=dot(p,p+45.32); return fract(p.x*p.y); }
    void main(){
      vec2 d=vUv-.5; float r=length(d);
      vec2 off=d*(0.0025+uCA)*(0.4+r*1.6);
      vec3 col=vec3(texture2D(tDiffuse,vUv+off).r, texture2D(tDiffuse,vUv).g, texture2D(tDiffuse,vUv-off).b);
      col += uFlash*vec3(1.0,0.85,0.6);
      col = aces(col*1.15);
      float l=dot(col,vec3(.299,.587,.114));
      col += vec3(-0.004,0.002,0.006)*(1.-smoothstep(0.,.35,l)); col = max(col-0.012,0.)*1.012;            // teal shadows
      col *= mix(vec3(1.),vec3(1.05,0.99,0.9),smoothstep(.3,1.,l));        // warm highlights
      col *= smoothstep(1.05,0.25,length(d*vec2(1.0,0.85)))*0.85+0.15;    // vignette
      col = pow(max(col,0.),vec3(1./2.2));
      float g=hash(vUv*uRes+fract(uTime*7.13)*517.)-.5;
      col += g*0.075*(1.-l*0.6);                                            // film grain
      float lb=0.0556; if(vUv.y<lb||vUv.y>1.-lb) col=vec3(0.);              // 2:1 letterbox
      gl_FragColor=vec4(col*uFade,1.);
    }`,
});
composer.addPass(finalPass);

// ---------- text (per-letter planes in HUD space, pixels, origin at centre)
const FONTS = {
  cinzel: { family: 'Cinzel', weight: 700 }, cinzel6: { family: 'Cinzel', weight: 600 },
  black: { family: 'Inter Display', weight: 900 }, semi: { family: 'Inter Display', weight: 600 }, light: { family: 'Inter Display', weight: 300 },
  mono: { family: 'JetBrains Mono', weight: 500 },
};
const texCache = new Map();
const mctx = document.createElement('canvas').getContext('2d');
function glyph(ch, font, px, fill) {
  const key = ch + font.family + font.weight + px + fill;
  if (texCache.has(key)) return texCache.get(key);
  const f = `${font.weight} ${px}px "${font.family}"`; mctx.font = f;
  const adv = mctx.measureText(ch).width, pad = Math.ceil(px * 0.25);
  const c = document.createElement('canvas'); c.width = Math.ceil(adv + pad * 2); c.height = Math.ceil(px * 1.3 + pad * 2);
  const x = c.getContext('2d'); x.font = f; x.textBaseline = 'alphabetic';
  if (fill === 'gold') { const g = x.createLinearGradient(0, pad, 0, pad + px); g.addColorStop(0, '#fff2c8'); g.addColorStop(0.45, '#f4c55a'); g.addColorStop(1, '#a8701f'); x.fillStyle = g; }
  else x.fillStyle = fill;
  x.fillText(ch, pad, pad + px * 0.95);
  const tex = new THREE.CanvasTexture(c); tex.colorSpace = THREE.SRGBColorSpace; tex.minFilter = THREE.LinearFilter;
  const g = { tex, w: c.width, h: c.height, adv, pad, px }; texCache.set(key, g); return g;
}
const PLANE = new THREE.PlaneGeometry(1, 1);
class Text {
  constructor(parent, str, { font = FONTS.semi, px = 60, tracking = 0, fill = 'gold', x = 0, y = 0, align = 'center', intensity = 1 } = {}) {
    Object.assign(this, { font, px, tracking, fill, intensity });
    this.group = new THREE.Group(); this.group.position.set(x, y, 0); parent.add(this.group);
    this.letters = []; this.setString(str, align);
  }
  setString(str, align = this.align) {
    this.align = align;
    if (this.str && this.str.length === str.length) {   // fixed-length update (clocks)
      [...str].forEach((ch, i) => { const L = this.letters[i]; if (L && ch !== ' ') { const g = glyph(ch, this.font, this.px, this.fill); L.mesh.material.map = g.tex; } });
      this.str = str; return;
    }
    this.str = str; let cur = 0;
    for (const ch of str) {
      const g = glyph(ch === ' ' ? ' ' : ch, this.font, this.px, this.fill);
      const m = new THREE.Mesh(PLANE, new THREE.MeshBasicMaterial({ map: g.tex, transparent: true, depthTest: false, depthWrite: false, color: new THREE.Color(1, 1, 1).multiplyScalar(this.intensity) }));
      m.scale.set(g.w, g.h, 1); this.group.add(m);
      this.letters.push({ mesh: m, bx: cur + g.w / 2 - g.pad, by: -(g.h / 2 - g.pad - this.px * 0.95) - this.px * 0.35, w: g.w, h: g.h });
      cur += g.adv + this.tracking * this.px;
    }
    this.width = cur - this.tracking * this.px;
    const off = align === 'center' ? -this.width / 2 : align === 'right' ? -this.width : 0;
    for (const L of this.letters) L.bx += off;
    this.set(() => ({ o: 1 }));
  }
  set(fn) {
    const n = this.letters.length;
    this.letters.forEach((L, i) => {
      const r = fn(i, n); const o = r.o ?? 1, s = r.s ?? 1, k = r.k ?? this.intensity;
      L.mesh.visible = o > 0.003; L.mesh.material.opacity = clamp(o);
      L.mesh.material.color.setScalar(k);
      L.mesh.position.set(L.bx * (r.sx ?? 1) + (r.dx ?? 0), L.by + (r.dy ?? 0), 0);
      L.mesh.scale.set(L.w * s, L.h * s, 1);
    });
    return this;
  }
}
// thin HUD line and soft glow sprites
const lineGeo = new THREE.PlaneGeometry(1, 1).translate(0.5, 0, 0);
class HLine {
  constructor(parent, k = 3, thick = 2) { this.m = new THREE.Mesh(lineGeo, new THREE.MeshBasicMaterial({ color: gold(k), transparent: true, depthTest: false, blending: THREE.AdditiveBlending })); this.thick = thick; parent.add(this.m); }
  set(x1, y1, x2, y2, p = 1, o = 1) { const dx = x2 - x1, dy = y2 - y1, len = Math.hypot(dx, dy) * p; this.m.position.set(x1, y1, 0); this.m.rotation.z = Math.atan2(dy, dx); this.m.scale.set(Math.max(len, 0.001), this.thick, 1); this.m.material.opacity = o; this.m.visible = o > 0 && p > 0; }
}
const glowTex = (() => { const c = document.createElement('canvas'); c.width = c.height = 128; const x = c.getContext('2d'); const g = x.createRadialGradient(64, 64, 0, 64, 64, 64); g.addColorStop(0, 'rgba(255,255,255,1)'); g.addColorStop(0.25, 'rgba(255,255,255,.35)'); g.addColorStop(1, 'rgba(255,255,255,0)'); x.fillStyle = g; x.fillRect(0, 0, 128, 128); return new THREE.CanvasTexture(c); })();
function glow(parent, color, additive = true) { const m = new THREE.Mesh(PLANE, new THREE.MeshBasicMaterial({ map: glowTex, color, transparent: true, depthTest: false, depthWrite: false, blending: additive ? THREE.AdditiveBlending : THREE.NormalBlending })); parent.add(m); return m; }

// ---------- particles
const ptsMat = () => new THREE.ShaderMaterial({
  uniforms: { uScale: { value: 10 } }, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
  vertexShader: `attribute float aSize; attribute vec4 aColor; varying vec4 vC; uniform float uScale;
    void main(){ vec4 mv=modelViewMatrix*vec4(position,1.); gl_Position=projectionMatrix*mv; gl_PointSize=max(aSize*uScale/-mv.z,0.); vC=aColor; }`,
  fragmentShader: `varying vec4 vC; void main(){ float d=length(gl_PointCoord-.5)*2.; float a=smoothstep(1.,0.,d); a*=a; gl_FragColor=vec4(vC.rgb, vC.a*a); }`,
});
class Points {
  constructor(scene, n) {
    this.n = n; this.geo = new THREE.BufferGeometry();
    this.pos = new Float32Array(n * 3); this.col = new Float32Array(n * 4); this.size = new Float32Array(n);
    this.geo.setAttribute('position', new THREE.BufferAttribute(this.pos, 3));
    this.geo.setAttribute('aColor', new THREE.BufferAttribute(this.col, 4));
    this.geo.setAttribute('aSize', new THREE.BufferAttribute(this.size, 1));
    this.obj = new THREE.Points(this.geo, ptsMat()); this.obj.frustumCulled = false; scene.add(this.obj);
  }
  put(i, x, y, z, r, g, b, a, s) { const p = this.pos, c = this.col; p[i * 3] = x; p[i * 3 + 1] = y; p[i * 3 + 2] = z; c[i * 4] = r; c[i * 4 + 1] = g; c[i * 4 + 2] = b; c[i * 4 + 3] = a; this.size[i] = s; }
  flush() { for (const k of ['position', 'aColor', 'aSize']) this.geo.attributes[k].needsUpdate = true; }
}
// ballistic sparks with drag + gravity, drawn with 3 trailing samples for a streak
class Sparks extends Points {
  constructor(scene, max, { gravity = 7, drag = 1.6 } = {}) { super(scene, max * 3); this.list = []; this.G = gravity; this.D = drag; }
  emit(birth, p, v, life, size) { this.list.push({ birth, p, v, life, size }); }
  burst(rnd, t, p, n, { speed = [2, 8], up = 0.0, life = [0.5, 1.4], size = [5, 12], spreadZ = 1 } = {}) {
    for (let i = 0; i < n; i++) {
      const th = rnd() * Math.PI * 2, ph = Math.acos(2 * rnd() - 1), sp = lerp(speed[0], speed[1], rnd() ** 0.7);
      const v = V3(Math.sin(ph) * Math.cos(th), Math.cos(ph) + up, Math.sin(ph) * Math.sin(th) * spreadZ).normalize().multiplyScalar(sp);
      this.emit(t + rnd() * 0.04, p.clone(), v, lerp(life[0], life[1], rnd()), lerp(size[0], size[1], rnd()));
    }
  }
  at(s, age) {
    const k = this.D, f = (1 - Math.exp(-k * age)) / k;
    return [s.p.x + s.v.x * f, s.p.y + s.v.y * f - 0.5 * this.G * age * age, s.p.z + s.v.z * f];
  }
  update(t) {
    let i = 0;
    for (const s of this.list) {
      const age = t - s.birth;
      if (age < 0 || age > s.life) { for (let j = 0; j < 3; j++) this.size[i++] = 0; continue; }
      const h = 1 - age / s.life;
      for (let j = 0; j < 3; j++) {
        const a2 = Math.max(age - j * 0.014, 0), [x, y, z] = this.at(s, a2);
        const r = 1.0, g = lerp(0.35, 0.85, h), b = lerp(0.08, 0.6, h ** 3), k = 2.5 + 7 * h ** 2;
        this.put(i++, x, y, z, r * k, g * k, b * k, h ** 1.3 * (1 - j * 0.3), s.size * (1 - j * 0.25) * (0.5 + 0.5 * h));
      }
    }
    this.flush();
  }
}
class Dust extends Points {
  constructor(scene, n, box, seed = 3, k = 0.5) {
    super(scene, n); const r = rngF(seed); this.d = [];
    for (let i = 0; i < n; i++) this.d.push({ x: lerp(box[0], box[1], r()), y: lerp(box[2], box[3], r()), z: lerp(box[4], box[5], r()), ph: r() * 6.28, sp: 0.1 + r() * 0.3, s: 2 + r() ** 3 * 18, a: 0.15 + r() * 0.6 });
    this.k = k;
  }
  update(t) {
    this.d.forEach((d, i) => { const k = this.k * (0.6 + 0.4 * Math.sin(t * 1.3 + d.ph)); this.put(i, d.x + Math.sin(t * d.sp + d.ph) * 0.4, d.y + t * d.sp * 0.25, d.z + Math.cos(t * d.sp * 0.7 + d.ph) * 0.3, 1.0 * k, 0.68 * k, 0.35 * k, d.a, d.s); });
    this.flush();
  }
}

// ---------- shared helpers
function shake(cam, t, amp = 0.09) {
  const a = hitEnv(t, 7) * amp;
  cam.position.x += Math.sin(t * 71.3) * a; cam.position.y += Math.sin(t * 57.1 + 1.3) * a; cam.rotation.z += Math.sin(t * 43.7) * a * 0.12;
}
const toHud = (v, cam) => { const p = v.clone().project(cam); return [p.x * W / 2, p.y * H / 2]; };
function hudLabelTL(group) { // persistent "XAU/USD · M1" tag
  const tag = new Text(group, 'XAU/USD  ·  M1', { font: FONTS.mono, px: 22, tracking: 0.12, fill: '#e9c27a', x: -880, y: 405, align: 'left', intensity: 0.9 });
  const dot = glow(group, new THREE.Color(1, 0.55, 0.2).multiplyScalar(3)); dot.position.set(-900, 405, 0); dot.scale.set(22, 22, 1);
  return t => { dot.material.opacity = 0.4 + 0.6 * (Math.sin(t * 6) > 0 ? 1 : 0.2); };
}

const segments = [];
function segment(start, end, fadeIn, fadeOut, build) {
  const scene = new THREE.Scene(); scene.background = new THREE.Color(0x030201);
  const camera = new THREE.PerspectiveCamera(36, W / H, 0.1, 400);
  const hud = new THREE.Group(); hudScene.add(hud);
  const s = { start, end, fadeIn, fadeOut, scene, camera, hud };
  s.update = build(s); segments.push(s);
}

// ===================================================== S1 — the price line never sleeps
segment(0, 4.8, 0.7, 0.12, ({ scene, camera, hud }) => {
  scene.fog = new THREE.FogExp2(0x030201, 0.03);
  const r = rngF(11), pts = []; let y = 0;
  for (let i = 0; i <= 220; i++) { const x = -33 + i * 0.3; y += (r() - 0.46) * 0.6; y *= 0.97; pts.push(V3(x, y + x * 0.09, 0)); }
  const curve = new THREE.CatmullRomCurve3(pts);
  const SEG = 1800, RAD = 6;
  const core = new THREE.Mesh(new THREE.TubeGeometry(curve, SEG, 0.035, RAD), new THREE.MeshBasicMaterial({ color: gold(5) }));
  const halo = new THREE.Mesh(new THREE.TubeGeometry(curve, SEG, 0.16, RAD), new THREE.MeshBasicMaterial({ color: gold(0.7), transparent: true, opacity: 0.14, blending: THREE.AdditiveBlending, depthWrite: false }));
  scene.add(core, halo);
  // ghost "previous days" lines behind
  for (let k = 1; k <= 3; k++) {
    const gp = pts.map((p, i) => V3(p.x, p.y + Math.sin(i * 0.11 + k * 2) * 1.5 - k * 1.2, -k * 3.5));
    const m = new THREE.Mesh(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(gp), 600, 0.02, 4), new THREE.MeshBasicMaterial({ color: gold(0.9 / k), transparent: true, opacity: 0.5, blending: THREE.AdditiveBlending, depthWrite: false }));
    scene.add(m);
  }
  const grid = new THREE.GridHelper(200, 100, 0x6b4a1c, 0x3a2a12); grid.position.y = -6; grid.material.transparent = true; grid.material.opacity = 0.35; scene.add(grid);
  const back = new THREE.GridHelper(200, 100, 0x3a2a12, 0x2a1d0c); back.rotation.x = Math.PI / 2; back.position.z = -30; back.material.transparent = true; back.material.opacity = 0.2; scene.add(back);
  const prog = t => lerp(0.2, 0.72, E.inOut3(ramp(t, -0.4, 5.2)));
  const tipPts = new Points(scene, 2);
  const sparks = new Sparks(scene, 1400, { gravity: 5 }); const sr = rngF(5);
  for (let s = 0.15; s < 4.9; s += 1 / 120) {
    const p = curve.getPointAt(prog(s));
    sparks.emit(s, p, V3(-1 - sr() * 3.5, sr() * 3 - 0.6, (sr() - 0.5) * 3), 0.4 + sr() * 0.9, 4 + sr() * 9);
  }
  sparks.burst(sr, 1.2, curve.getPointAt(prog(1.2)), 260, { speed: [2, 10], up: 0.3 });
  const dust = new Dust(scene, 500, [-40, 40, -6, 8, -25, 6], 4, 0.6);
  // HUD
  const title = new Text(hud, 'GOLD NEVER SLEEPS', { font: FONTS.cinzel6, px: 104, tracking: 0.2, y: -300, intensity: 1.25 });
  const clock = new Text(hud, '23:59:51', { font: FONTS.mono, px: 26, tracking: 0.1, fill: '#e9c27a', x: 880, y: 405, align: 'right', intensity: 0.9 });
  const tag = hudLabelTL(hud);
  return t => {
    const p = prog(t), tip = curve.getPointAt(p);
    core.geometry.setDrawRange(0, Math.floor(p * SEG) * RAD * 6);
    halo.geometry.setDrawRange(0, Math.floor(p * SEG) * RAD * 6);
    tipPts.put(0, tip.x, tip.y, tip.z, 6, 4.6, 3, 1, 70 + 12 * Math.sin(t * 20)); tipPts.put(1, tip.x, tip.y, tip.z, 1.2, 0.7, 0.3, 0.5, 130); tipPts.flush();
    sparks.update(t); dust.update(t);
    const intro = E.out3(ramp(t, 0, 3));
    camera.position.set(tip.x - 4.2 + 1.2 * Math.sin(t * 0.4), tip.y + lerp(3.5, 1.1, intro), lerp(13, 8.2, intro));
    camera.lookAt(tip.x + 2.4, tip.y * 0.92 + 0.3, 0); shake(camera, t, 0.05);
    title.set((i, n) => { const a = E.out3(ramp(t, 0.9 + i * 0.05, 1.7 + i * 0.05)); const o = a * (1 - ramp(t, 4.3, 4.75)); return { o, dy: (1 - a) * -26, s: 1 + 0.35 * (1 - a), sx: 1 + 0.05 * ramp(t, 0.9, 4.8), k: 1.25 + 2.5 * (1 - a) }; });
    const sec = Math.floor(51 + t * 3); const tt = sec < 60 ? `23:59:${String(sec).padStart(2, '0')}` : `00:00:${String(sec - 60).padStart(2, '0')}`;
    clock.setString(tt); clock.set(() => ({ o: ramp(t, 0.4, 1.0) })); tag(t);
  };
});

// ===================================================== S2 — candles, fake-out, breakout
segment(4.8, 9.45, 0, 0.25, ({ scene, camera, hud }) => {
  scene.fog = new THREE.FogExp2(0x030201, 0.045);
  scene.environment = ENV; scene.environmentIntensity = 0.35;
  scene.add(new THREE.AmbientLight(0x332211, 0.6));
  const key = new THREE.PointLight(0xffb060, 80, 0, 2); key.position.set(1, 6, 6); scene.add(key);
  const rim = new THREE.DirectionalLight(0x5fb8ff, 0.3); rim.position.set(-5, 3, -6); scene.add(rim);
  const floor = new THREE.Mesh(new THREE.PlaneGeometry(200, 200), new THREE.MeshStandardMaterial({ color: 0x050303, metalness: 0.6, roughness: 0.5, envMapIntensity: 0.1 }));
  floor.rotation.x = -Math.PI / 2; floor.position.y = -2.4; scene.add(floor);
  const r = rngF(21), N = 22, LVL = 1.0, cs = [];
  let o = -0.3;
  for (let i = 0; i < N - 2; i++) {
    let c = clamp(o + (r() - 0.5) * 0.9, -1.4, 0.75); let h = Math.max(o, c) + r() * 0.25, l = Math.min(o, c) - r() * 0.3;
    if (i === 12) { h = LVL - 0.02; }
    h = Math.min(h, LVL - 0.04 + (i === 12 ? 0.02 : 0));
    cs.push({ o, c, h, l }); o = c;
  }
  cs.push({ o: 0.3, c: 0.3, h: 0.3, l: 0.1, fake: true });
  cs.push({ o: 0.2, c: 0.2, h: 0.2, l: 0.05, brk: true });
  const X = i => (i - (N - 1)) * 0.85;
  const bodyGeo = new THREE.BoxGeometry(0.52, 1, 0.52), wickGeo = new THREE.BoxGeometry(0.05, 1, 0.05);
  const BULL = new THREE.Color(0xd9a441), BEAR = new THREE.Color(0x2a1d15), BULLE = new THREE.Color(0xffa030), BEARE = new THREE.Color(0x8a2a10);
  const cm = cs.map((d, i) => {
    const mat = new THREE.MeshStandardMaterial({ color: BULL.clone(), metalness: 0.9, roughness: 0.28, emissive: BULLE.clone(), emissiveIntensity: 0.3 });
    const body = new THREE.Mesh(bodyGeo, mat), wick = new THREE.Mesh(wickGeo, new THREE.MeshBasicMaterial({ color: gold(1.6) }));
    body.position.x = wick.position.x = X(i); scene.add(body, wick); return { d, body, wick, mat };
  });
  const iLvl0 = N - 2 - 15;
  const lvl = new THREE.Mesh(new THREE.BoxGeometry(1, 0.025, 0.025), new THREE.MeshBasicMaterial({ color: new THREE.Color(1, 0.9, 0.7) }));
  scene.add(lvl);
  const shock = new THREE.Mesh(new THREE.TorusGeometry(1, 0.02, 8, 96), new THREE.MeshBasicMaterial({ color: gold(5), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false })); scene.add(shock);
  const sparks = new Sparks(scene, 1600, { gravity: 6 }); const sr = rngF(9);
  sparks.burst(sr, 6.12, V3(X(N - 2), LVL, 0), 120, { speed: [1.5, 6], up: 0.6, life: [0.4, 1.0] });
  sparks.burst(sr, 8.6, V3(X(N - 1), LVL, 0), 380, { speed: [3, 13], up: 0.5, life: [0.5, 1.5], size: [3, 9] });
  for (let s = 8.6; s < 9.4; s += 1 / 90) sparks.emit(s, V3(X(N - 1), 3.3, 0), V3((sr() - .5) * 3, 2 + sr() * 3, (sr() - .5) * 3), 0.5 + sr() * 0.6, 4 + sr() * 6);
  const dust = new Dust(scene, 400, [-25, 10, -2, 7, -14, 5], 8, 0.5);
  // HUD
  const lblLvl = new Text(hud, '15-BAR HIGH', { font: FONTS.mono, px: 28, tracking: 0.15, fill: '#f6deb0', align: 'left', intensity: 1.1 });
  const lblFake = new Text(hud, 'FAKE-OUT', { font: FONTS.mono, px: 34, tracking: 0.2, fill: '#ff7a5a', intensity: 1.4 });
  const fakeStrike = new HLine(hud, 2, 2); fakeStrike.m.material.color.set(new THREE.Color(1, 0.35, 0.25).multiplyScalar(2));
  const lblBrk = new Text(hud, 'CLOSE  >  15-BAR HIGH', { font: FONTS.mono, px: 30, tracking: 0.15, fill: '#ffe7b0', intensity: 1.5 });
  const big = new Text(hud, 'BREAKOUT', { font: FONTS.black, px: 210, tracking: 0.06, y: -250, intensity: 1.1 });
  const tag = hudLabelTL(hud);
  return t => {
    cm.forEach(({ d, body, wick, mat }, i) => {
      let { o, c, h, l } = d, g = E.outBack(ramp(t, 4.85 + i * 0.045, 5.2 + i * 0.045));
      if (d.fake) { g = ramp(t, 5.75, 5.9); const up = E.out3(ramp(t, 5.85, 6.15)), dn = E.inOut3(ramp(t, 6.75, 7.3)); c = lerp(lerp(0.3, 1.45, up), -0.05, dn); h = Math.max(0.35, lerp(0.3, 1.5, up)); l = 0.0; }
      if (d.brk) { g = ramp(t, 7.85, 8.0); const a = E.inOut3(ramp(t, 7.9, 8.4)), b = E.outExpo(ramp(t, 8.45, 8.75)); c = lerp(lerp(0.2, 0.92, a), 3.3, b); h = Math.max(c + 0.25 * b, 0.25); l = 0.05; }
      const cc = lerp(o, c, g), top = Math.max(o, cc), bot = Math.min(o, cc);
      body.scale.y = Math.max(top - bot, 0.03) * (g > 0 ? 1 : 0.0001); body.position.y = (top + bot) / 2;
      const hh = lerp(top, h, g), ll = lerp(bot, l, g); wick.scale.y = Math.max(hh - ll, 0.001) * (g > 0 ? 1 : 0.0001); wick.position.y = (hh + ll) / 2;
      const bull = clamp((cc - o) / 0.15 + 0.5);
      mat.color.copy(BEAR).lerp(BULL, bull); mat.emissive.copy(BEARE).lerp(BULLE, bull);
      mat.emissiveIntensity = 0.25 + (d.brk ? 0.9 * ramp(t, 8.45, 8.7) * (1 - 0.6 * ramp(t, 8.8, 9.4)) : 0) + (d.fake ? 1.2 * Math.max(0, cc - LVL) : 0);
    });
    const x0 = X(iLvl0) - 0.4, x1 = X(N - 1) + 1.4, lp = E.out3(ramp(t, 5.2, 5.8));
    lvl.scale.x = (x1 - x0) * lp + 0.001; lvl.position.set(x0 + (x1 - x0) * lp / 2, LVL, 0);
    const flick = (t > 6.05 && t < 6.6 ? 0.5 + 0.5 * Math.sin(t * 90) : 0) + 4 * Math.exp(-Math.max(t - 8.6, 0) * 4) * (t > 8.6 ? 1 : 0);
    lvl.material.color.setRGB(1, 0.85, 0.6).multiplyScalar(1.1 + flick * 1.5);
    const sk = ramp(t, 8.6, 9.4); shock.position.set(X(N - 1), LVL, 0); shock.scale.setScalar(0.2 + E.out3(sk) * 9); shock.material.opacity = t > 8.6 ? (1 - sk) ** 2 : 0;
    sparks.update(t); dust.update(t);
    const k = E.inOut3(ramp(t, 4.8, 8.5)), push = E.out3(ramp(t, 8.6, 9.45));
    camera.position.set(lerp(-10, 2.2, k) - push * 0.4, lerp(0.6, 1.4, k) + push * 0.7, lerp(6.8, 5.4, k) - push * 1.0);
    camera.lookAt(lerp(-7, 0.2, k), lerp(0.3, 1.0, k) + push * 0.9, 0); shake(camera, t, 0.12);
    // labels
    const [lx, ly] = toHud(V3(x1 + 0.1, LVL, 0), camera); lblLvl.group.position.set(lx + 12, ly + 14, 0); lblLvl.set(() => ({ o: ramp(t, 5.6, 5.9) * (1 - ramp(t, 8.55, 8.7)) }));
    const [fx, fy] = toHud(V3(X(N - 2), 1.85, 0), camera); lblFake.group.position.set(fx, fy + 10, 0);
    const fo = ramp(t, 6.95, 7.1) * (1 - ramp(t, 7.9, 8.1)); lblFake.set((i) => ({ o: fo * ramp(t, 6.95 + i * 0.02, 7.0 + i * 0.02) }));
    fakeStrike.set(fx - lblFake.width / 2 - 8, fy + 10 + 2, fx + lblFake.width / 2 + 8, fy + 12, E.out3(ramp(t, 7.25, 7.5)), fo);
    const [bx, by] = toHud(V3(X(N - 1), 3.9, 0), camera); lblBrk.group.position.set(bx, by + 20, 0);
    lblBrk.set(i => ({ o: ramp(t, 8.75 + i * 0.015, 8.8 + i * 0.015) * (1 - ramp(t, 9.2, 9.4)) }));
    big.set((i, n) => { const a = E.outExpo(ramp(t, 8.6 + Math.abs(i - (n - 1) / 2) * 0.02, 8.95)); return { o: a * (1 - ramp(t, 9.2, 9.42)), s: 1 + 0.5 * (1 - a), k: 1.1 + 4 * (1 - a), sx: 1 + 0.08 * ramp(t, 8.6, 9.45) }; });
    tag(t);
  };
});

// ===================================================== S3 — three filters, one decision
segment(9.45, 15.2, 0.15, 0.22, ({ scene, camera, hud }) => {
  scene.fog = new THREE.FogExp2(0x030201, 0.03);
  const rings = []; const ringGeo = new THREE.TorusGeometry(6, 0.018, 6, 160);
  for (let i = 0; i < 34; i++) { const m = new THREE.Mesh(ringGeo, new THREE.MeshBasicMaterial({ color: gold(0.8), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false })); scene.add(m); rings.push(m); }
  const WN = 900, wave = new Points(scene, WN);
  const dust = new Dust(scene, 500, [-14, 14, -8, 8, -40, 4], 12, 0.55);
  const sparks = new Sparks(scene, 900, { gravity: 2, drag: 2.2 }); const sr = rngF(31);
  for (const h of [9.6, 10.35, 11.36]) sparks.burst(sr, h, V3(0, 0, -2), 160, { speed: [3, 9], life: [0.4, 1.0], size: [4, 9] });
  sparks.burst(sr, 13.92, V3(0, -0.4, 1), 380, { speed: [3, 12], life: [0.5, 1.4], size: [5, 12] });
  // HUD words
  const words = ['TREND', 'BREAKOUT', 'VOLATILITY'], times = [9.6, 10.35, 11.36], rowY = [215, 10, -195];
  const caps = ['M15  ·  50 EMA  ·  M1 21 EMA', 'CLOSE BEYOND THE 15-BAR RANGE', 'ATR(14)  ≥  1.1 × ITS AVERAGE'];
  const wT = words.map((w, i) => new Text(hud, w, { font: FONTS.black, px: 150, tracking: 0.05, y: rowY[i], intensity: 1.15 }));
  const cT = caps.map((c, i) => new Text(hud, c, { font: FONTS.mono, px: 24, tracking: 0.18, fill: '#e9c27a', y: rowY[i] - 92, intensity: 0.9 }));
  const lines = [0, 1, 2].map(() => new HLine(hud, 4, 3));
  const flare = glow(hud, gold(4)), flareH = glow(hud, gold(2.5));
  const one = new Text(hud, 'ONE DECISION.', { font: FONTS.cinzel, px: 120, tracking: 0.12, y: -230, intensity: 1.3 });
  const three = new Text(hud, 'THREE FILTERS', { font: FONTS.mono, px: 24, tracking: 0.5, fill: '#e9c27a', y: 440, intensity: 0.9 });
  const tag = hudLabelTL(hud);
  const COLX = [-560, 0, 560], PT = [0, -60];
  return t => {
    const speed = 6 + 10 * hitEnv(t, 2.5);
    const travel = (t - 9.45) * 7 + [9.6, 10.35, 11.36, 13.92].reduce((s, h) => s + (t > h ? E.out3((t - h) / 0.6) * 5 : 0), 0);
    rings.forEach((m, i) => { const z = ((i * 2.4 + travel) % 82) - 76; m.position.z = z; m.rotation.z = i * 0.3 + t * 0.1; m.scale.setScalar(1 + 0.03 * Math.sin(i)); m.material.opacity = clamp((z + 76) / 20) * clamp((6 - z) / 8) * 0.4; });
    // morphing signal: rising trend -> step breakout -> volatile oscillation
    const wB = E.inOut3(ramp(t, 10.35, 10.8)), wV = E.inOut3(ramp(t, 11.36, 11.9)), conv = E.inOut3(ramp(t, 12.6, 13.6));
    for (let i = 0; i < WN; i++) {
      const u = i / (WN - 1), x = lerp(-16, 16, u);
      const yT = x * 0.12 + Math.sin(x * 1.3 + t * 2) * 0.12;
      const yB = (x < 4 ? Math.sin(x * 2.2 + t) * 0.35 : 0.35 + (x - 4) * 0.45);
      const amp = 0.4 + 1.6 * ramp(t, 11.36, 12.2);
      const yV = Math.sin(x * 2.4 + t * 5) * amp * (0.6 + 0.4 * Math.sin(x * 0.7 - t * 2)) ;
      let y = lerp(lerp(yT, yB, wB), yV, wV) * (1 - conv) - 3.6 * (1 - conv) - 0.4 * conv;
      const k = 2.2 + 2 * hitEnv(t, 4);
      wave.put(i, x * (1 - conv * 0.98), y, -4, 1 * k, 0.7 * k, 0.32 * k, 0.9 * ramp(t, 9.5, 9.9), 7);
    }
    wave.flush(); dust.update(t); sparks.update(t);
    camera.position.set(Math.sin(t * 0.3) * 0.4, Math.cos(t * 0.25) * 0.3, 8); camera.lookAt(0, 0, -10); shake(camera, t, 0.08);
    const m = E.inOut3(ramp(t, 12.6, 13.15));
    wT.forEach((w, wi) => {
      const T = times[wi];
      w.group.position.set(lerp(0, COLX[wi], m), lerp(rowY[wi], 330, m), 0); w.group.scale.setScalar(lerp(1, 0.36, m));
      w.set((i, n) => { const a = E.outExpo(ramp(t, T + i * 0.012, T + 0.3 + i * 0.012)); return { o: ramp(t, T + i * 0.012, T + 0.06 + i * 0.012) * (1 - ramp(t, 14.9, 15.2)), s: 1 + 0.9 * (1 - a), k: lerp(1.0, 1.5, m) + 3 * Math.exp(-Math.max(t - T, 0) * 5) * (t > T ? 1 : 0) }; });
      cT[wi].set(i => ({ o: ramp(t, T + 0.25 + i * 0.012, T + 0.3 + i * 0.012) * (1 - ramp(t, 12.6, 12.85)) }));
      lines[wi].set(COLX[wi], 290, PT[0], PT[1], E.inOut3(ramp(t, 12.85 + wi * 0.08, 13.75)), 1 - ramp(t, 14.9, 15.2));
    });
    const f = ramp(t, 13.5, 13.92) ** 2 + 4 * Math.exp(-Math.max(t - 13.92, 0) * 3) * (t > 13.92 ? 1 : 0);
    flare.position.set(PT[0], PT[1], 0); flare.scale.setScalar(30 + 110 * Math.min(f, 2)); flare.material.opacity = clamp(f) * (1 - ramp(t, 14.9, 15.2));
    flareH.position.set(PT[0], PT[1], 0); flareH.scale.set(80 + 1100 * Math.min(f, 2), 8 + 12 * f, 1); flareH.material.opacity = 0.6 * clamp(f) * (1 - ramp(t, 14.9, 15.2));
    one.set((i, n) => { const a = E.outExpo(ramp(t, 13.92 + Math.abs(i - n / 2) * 0.02, 14.3)); return { o: a * (1 - ramp(t, 14.95, 15.2)), s: 1 + 0.4 * (1 - a), k: 1.3 + 4 * (1 - a), sx: 1 + 0.05 * ramp(t, 13.92, 15.2) }; });
    three.set(i => ({ o: ramp(t, 12.6 + i * 0.02, 12.7 + i * 0.02) * (1 - ramp(t, 14.9, 15.2)) * 0.9 }));
    tag(t);
  };
});

// ===================================================== S4 — the gold bar: risk first
segment(15.2, 20.6, 0.25, 0, ({ scene, camera, hud }) => {
  scene.environment = ENV; scene.environmentIntensity = 0.6;
  scene.add(new THREE.AmbientLight(0x221608, 0.4));
  const key = new THREE.PointLight(0xffc27a, 50, 0, 2); key.position.set(4, 5, 5); scene.add(key);
  const rim = new THREE.PointLight(0x6fbaff, 22, 0, 2); rim.position.set(-5, 4.5, -6); scene.add(rim);
  const top = new THREE.PointLight(0xffe0b0, 14, 0, 2); top.position.set(0, 6, 0); scene.add(top);
  const sh = new THREE.Shape(); sh.moveTo(-2, -0.62); sh.lineTo(2, -0.62); sh.lineTo(1.55, 0.62); sh.lineTo(-1.55, 0.62); sh.closePath();
  const geo = new THREE.ExtrudeGeometry(sh, { depth: 1.8, bevelEnabled: true, bevelThickness: 0.12, bevelSize: 0.1, bevelSegments: 5, curveSegments: 4 }); geo.center();
  const goldMat = new THREE.MeshPhysicalMaterial({ color: 0xffc35c, metalness: 1, roughness: 0.2, clearcoat: 0.5, clearcoatRoughness: 0.15, emissive: 0xff9a20, emissiveIntensity: 0.02 });
  const ingot = new THREE.Group(); const bar = new THREE.Mesh(geo, goldMat); ingot.add(bar); scene.add(ingot);
  // engraving on the top face
  const ec = document.createElement('canvas'); ec.width = 1024; ec.height = 640; const ex = ec.getContext('2d');
  ex.strokeStyle = 'rgba(70,40,5,0.85)'; ex.lineWidth = 8; ex.strokeRect(40, 40, 944, 560);
  ex.fillStyle = 'rgba(70,40,5,0.9)'; ex.textAlign = 'center';
  ex.font = '700 88px Cinzel'; ex.fillText('FINE GOLD', 512, 200);
  ex.font = '700 190px Cinzel'; ex.fillText('1%', 512, 420);
  ex.font = '500 52px "JetBrains Mono"'; ex.fillText('RISK  ·  999.9', 512, 530);
  const etex = new THREE.CanvasTexture(ec); etex.colorSpace = THREE.SRGBColorSpace;
  const eng = new THREE.Mesh(new THREE.PlaneGeometry(2.7, 1.62), new THREE.MeshStandardMaterial({ map: etex, transparent: true, metalness: 0.6, roughness: 0.5, depthWrite: false }));
  eng.rotation.x = -Math.PI / 2; eng.position.y = 0.745; ingot.add(eng);
  const floor = new THREE.Mesh(new THREE.PlaneGeometry(80, 80), new THREE.MeshStandardMaterial({ color: 0x050302, metalness: 0.7, roughness: 0.3, envMapIntensity: 0.08 }));
  floor.rotation.x = -Math.PI / 2; floor.position.y = -0.85; // floor omitted: ingot floats in black
  const ringA = new THREE.Mesh(new THREE.TorusGeometry(3.3, 0.012, 6, 220), new THREE.MeshBasicMaterial({ color: gold(4) }));
  const ringB = new THREE.Mesh(new THREE.TorusGeometry(3.9, 0.008, 6, 220), new THREE.MeshBasicMaterial({ color: gold(2.5) }));
  scene.add(ringA, ringB);
  const OR = 380, orb = new Points(scene, OR); const orr = rngF(41); const od = [...Array(OR)].map(() => ({ a: orr() * 6.28, r: 3.2 + orr() * 1.0, y: (orr() - 0.5) * 0.25, s: 0.3 + orr() * 0.8, z: 2 + orr() * 8 }));
  const sparks = new Sparks(scene, 900, { gravity: 5 }); const sr = rngF(43);
  sparks.burst(sr, 17.5, V3(0, 0.8, 0), 420, { speed: [2, 9], up: 0.8, life: [0.5, 1.5] });
  const dust = new Dust(scene, 350, [-10, 10, -1, 6, -12, 6], 44, 0.45);
  // HUD — left column
  const X = -470;
  const l1 = new Text(hud, 'RISK IS SET', { font: FONTS.semi, px: 54, tracking: 0.3, x: X, y: 230, intensity: 1.0 });
  const l2 = new Text(hud, 'BEFORE THE TRADE', { font: FONTS.semi, px: 54, tracking: 0.3, x: X, y: 160, intensity: 1.0 });
  const pct = new Text(hud, '1%', { font: FONTS.cinzel, px: 300, tracking: 0.02, x: X, y: -60, intensity: 1.35 });
  const l3 = new Text(hud, 'EVERY TIME.', { font: FONTS.semi, px: 54, tracking: 0.3, x: X, y: -235, intensity: 1.0 });
  const l4 = new Text(hud, 'LOT SIZE = 1% OF BALANCE AT THE STOP', { font: FONTS.mono, px: 20, tracking: 0.12, fill: '#e9c27a', x: X, y: -305, intensity: 0.85 });
  const div = new HLine(hud, 2.5, 2);
  const white = glow(hud, new THREE.Color(1, 0.9, 0.7).multiplyScalar(3));
  const tag = hudLabelTL(hud);
  camera.fov = 32; camera.updateProjectionMatrix();
  return t => {
    const lt = t - 15.2, pre = E.in2(ramp(t, 19.5, 20.6));
    ingot.rotation.y = -0.5 + lt * 0.32 + pre * 3.5; ingot.rotation.x = 0.06 * Math.sin(lt * 0.8);
    ingot.position.y = 0.05 * Math.sin(lt * 1.3);
    const pulse = t > 17.5 ? Math.exp(-(t - 17.5) * 4) : 0;
    ingot.scale.setScalar(1 + 0.06 * pulse);
    goldMat.emissiveIntensity = 0.02 + 0.12 * pulse + 0.5 * pre; scene.environmentIntensity = 0.6 + 0.5 * pulse;
    ringA.rotation.set(1.2 + 0.1 * Math.sin(lt), lt * 0.6, 0.3); ringB.rotation.set(1.35, -lt * 0.4, -0.25);
    const rs = lerp(1, 0.25, pre); ringA.scale.setScalar(rs); ringB.scale.setScalar(rs * 1.05);
    od.forEach((d, i) => { const a = d.a + lt * d.s * (1 + 6 * pre); const r = d.r * rs; const k = 2 + 2 * pulse; orb.put(i, Math.cos(a) * r, d.y + Math.sin(a * 3) * 0.08, Math.sin(a) * r, k, 0.7 * k, 0.3 * k, 0.8, d.z); });
    orb.flush(); sparks.update(t); dust.update(t);
    const ang = 0.55 - lt * 0.09, rad = lerp(12, 10, E.inOut3(ramp(t, 15.2, 20.0))) - pre * 1.6;
    camera.position.set(Math.sin(ang) * rad, lerp(2.6, 1.7, ramp(t, 15.2, 20.6)), Math.cos(ang) * rad);
    camera.lookAt(0, -0.25, 0); camera.setViewOffset(W, H, -340, 0, W, H); shake(camera, t, 0.06);
    const fadeOut = 1 - ramp(t, 19.6, 20.1);
    const rise = (T) => (i) => { const a = E.out3(ramp(t, T + i * 0.025, T + 0.45 + i * 0.025)); return { o: a * fadeOut, dy: (1 - a) * -18 }; };
    l1.set(rise(15.4)); l2.set(rise(16.34)); l3.set(rise(18.6)); l4.set(i => ({ o: ramp(t, 18.9 + i * 0.01, 19.0 + i * 0.01) * fadeOut }));
    pct.set((i) => { const a = E.outExpo(ramp(t, 17.5 + i * 0.04, 17.85 + i * 0.04)); return { o: a * fadeOut, s: 1 + 0.6 * (1 - a), k: 1.35 + 5 * (1 - a) }; });
    div.set(X - 230, 100, X + 230, 100, E.out3(ramp(t, 16.6, 17.2)), fadeOut * 0.7);
    white.position.set(0, 0, 0); white.scale.set(W * 2.5, H * 2.5, 1); white.material.opacity = pre ** 2.5 * 0.9;
    tag(t);
  };
});

// ===================================================== S5 — title
segment(20.6, 26.0, 0, 0.95, ({ scene, camera, hud }) => {
  scene.fog = new THREE.FogExp2(0x030201, 0.03);
  const sparks = new Sparks(scene, 2400, { gravity: 1.2, drag: 1.4 }); const sr = rngF(51);
  sparks.burst(sr, 20.6, V3(0, 0.3, 0), 600, { speed: [3, 18], up: 0, life: [0.7, 2.2], size: [3, 10], spreadZ: 0.35 });
  for (let s = 21.0; s < 26; s += 1 / 40) sparks.emit(s, V3((sr() - 0.5) * 16, -3.2, (sr() - 0.5) * 2), V3((sr() - .5) * 0.6, 1.5 + sr() * 2.5, 0), 1.5 + sr() * 1.5, 3 + sr() * 5);
  const shock = new THREE.Mesh(new THREE.TorusGeometry(1, 0.03, 8, 160), new THREE.MeshBasicMaterial({ color: gold(6), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false })); scene.add(shock);
  const HN = 900, halo = new Points(scene, HN); const hr = rngF(52); const hd = [...Array(HN)].map(() => ({ a: hr() * 6.28, r: 9 + hr() * 3 + (hr() < 0.2 ? hr() * 6 : 0), z: -8 + (hr() - 0.5) * 3, s: 3 + hr() ** 3 * 14, b: 0.3 + hr() }));
  const dust = new Dust(scene, 400, [-16, 16, -9, 9, -20, 5], 53, 0.5);
  const grid = new THREE.GridHelper(200, 120, 0x4a3315, 0x2a1d0c); grid.position.y = -4.5; grid.material.transparent = true; grid.material.opacity = 0.3; scene.add(grid);
  // HUD
  const title = new Text(hud, 'GOLDSCALPER', { font: FONTS.cinzel, px: 158, tracking: 0.1, y: 70, intensity: 1.3 });
  const under = new HLine(hud, 3.5, 2), under2 = new HLine(hud, 3.5, 2);
  const atr = new Text(hud, 'ATR', { font: FONTS.black, px: 70, tracking: 0.75, y: -78, intensity: 1.3 });
  const sub = new Text(hud, 'XAU/USD  ·  M1  ·  ATR BREAKOUT SCALPER', { font: FONTS.mono, px: 22, tracking: 0.3, fill: '#e9c27a', y: -150, intensity: 0.9 });
  const tagline = new Text(hud, 'EVERY RULE, IN THE SOURCE.', { font: FONTS.light, px: 40, tracking: 0.32, fill: '#fff1d6', y: -265, intensity: 1.05 });
  const disc = new Text(hud, 'Trading involves substantial risk. Backtest, then run it on a demo account first.', { font: FONTS.light, px: 19, tracking: 0.06, fill: '#d9c7a8', y: -428, intensity: 0.75 });
  const flareH = glow(hud, gold(3)), flareC = glow(hud, new THREE.Color(1, 0.9, 0.75).multiplyScalar(4));
  return t => {
    const lt = t - 20.6;
    sparks.update(t); dust.update(t);
    hd.forEach((d, i) => { const a = d.a + lt * 0.05; const k = d.b * (1.2 + 0.4 * Math.sin(t * 2 + i)) * E.out3(ramp(t, 20.7, 22)); halo.put(i, Math.cos(a) * d.r, Math.sin(a) * d.r * 0.55, d.z, k, 0.68 * k, 0.3 * k, 0.6, d.s); });
    halo.flush();
    const sk = ramp(t, 20.6, 22.0); shock.scale.setScalar(0.3 + E.out3(sk) * 16); shock.material.opacity = (1 - sk) ** 2;
    camera.position.set(0, 0.2, lerp(11, 9.2, E.out3(ramp(t, 20.6, 26)))); camera.lookAt(0, 0, 0); shake(camera, t, 0.1);
    title.set((i, n) => { const T = 20.6 + Math.abs(i - (n - 1) / 2) * 0.035; const a = E.outExpo(ramp(t, T, T + 0.5)); return { o: ramp(t, T, T + 0.1), s: 1 + 0.7 * (1 - a), k: 1.3 + 6 * (1 - a) + 0.15 * Math.sin(t * 2 + i * 0.6), sx: 1 + 0.035 * ramp(t, 20.6, 26) }; });
    const up = E.inOut3(ramp(t, 20.95, 21.6)), uw = 600;
    under.set(0, -18, -uw, -18, up, 0.9); under2.set(0, -18, uw, -18, up, 0.9);
    atr.set((i) => { const a = E.outExpo(ramp(t, 21.55 + i * 0.12, 21.9 + i * 0.12)); return { o: a, s: 1 + 0.8 * (1 - a), k: 1.3 + 5 * (1 - a) }; });
    sub.set(i => ({ o: ramp(t, 22.1 + i * 0.012, 22.2 + i * 0.012) * 0.95 }));
    tagline.set(i => { const a = E.out3(ramp(t, 22.87 + i * 0.03, 23.3 + i * 0.03)); return { o: a, dy: (1 - a) * -14 }; });
    disc.set(() => ({ o: ramp(t, 23.8, 24.3) * 0.85 }));
    const f = t >= 20.6 ? Math.exp(-(t - 20.6) * 2.2) : 0;
    flareH.position.set(0, 70, 0); flareH.scale.set(400 + 3000 * f + 200, 8 + 40 * f, 1); flareH.material.opacity = 0.25 + 0.75 * f;
    flareC.position.set(0, 70, 0); flareC.scale.setScalar(60 + 380 * f); flareC.material.opacity = f;
  };
});

// ---------- frame driver
window.renderAt = (t) => {
  const seg = segments.find(s => t >= s.start && t < s.end) || segments[segments.length - 1];
  for (const s of segments) s.hud.visible = s === seg;
  seg.camera.rotation.z = 0; seg.camera.clearViewOffset?.();
  seg.update(t);
  mainPass.scene = seg.scene; mainPass.camera = seg.camera;
  const fade = Math.min(seg.fadeIn ? ramp(t, seg.start, seg.start + seg.fadeIn) : 1, seg.fadeOut ? 1 - ramp(t, seg.end - seg.fadeOut, seg.end) : 1);
  finalPass.uniforms.uFade.value = E.inOut3(fade);
  finalPass.uniforms.uFlash.value = hitEnv(t, 11) * 0.22;
  finalPass.uniforms.uCA.value = hitEnv(t, 6) * 0.006;
  finalPass.uniforms.uTime.value = t;
  composer.render();
};
window.ready = true;
