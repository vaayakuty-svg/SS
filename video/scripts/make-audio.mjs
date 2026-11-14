// Synthesises the whole soundtrack: a 120 BPM half-time lo-fi beat (felt at 60) plus every SFX,
// written to public/audio.wav. No samples, no network. Timings mirror src/ (camera.ts, screen.ts,
// config.ts) — if you move a beat there, move it here too.
import { writeFileSync, mkdirSync } from "node:fs";

const SR = 44100;
const DUR = 30;
const N = SR * DUR;
const L = new Float32Array(N);
const R = new Float32Array(N);

// deterministic noise
let seed = 1234567;
const rnd = () => ((seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296) * 2 - 1;

const add = (t0, fn, len, gain = 1, pan = 0) => {
  const s0 = Math.floor(t0 * SR);
  const n = Math.floor(len * SR);
  const gl = gain * Math.min(1, 1 - pan), gr = gain * Math.min(1, 1 + pan);
  for (let i = 0; i < n; i++) {
    const idx = s0 + i;
    if (idx < 0 || idx >= N) continue;
    const v = fn(i / SR, i);
    L[idx] += v * gl;
    R[idx] += v * gr;
  }
};
const env = (t, a, d) => (t < a ? t / a : Math.exp(-(t - a) / d));
const mtof = (m) => 440 * Math.pow(2, (m - 69) / 12);

// ── music bus (rendered separately so we can muffle / crush it) ─────────
const ML = new Float32Array(N);
const MR = new Float32Array(N);
const madd = (t0, fn, len, gain = 1, pan = 0) => {
  const s0 = Math.floor(t0 * SR);
  const n = Math.floor(len * SR);
  for (let i = 0; i < n; i++) {
    const idx = s0 + i;
    if (idx < 0 || idx >= N) continue;
    const v = fn(i / SR, i) * gain;
    ML[idx] += v * (1 - Math.max(0, pan));
    MR[idx] += v * (1 + Math.min(0, pan));
  }
};

const BEAT = 0.5; // 120 BPM
const BAR = BEAT * 4; // 2 s
// Fmaj9 – Em7 – Dm9 – Cmaj7(add9), one chord per bar
const CHORDS = [
  [53, 57, 60, 64, 67],
  [52, 55, 59, 62, 66],
  [50, 53, 57, 60, 64],
  [48, 52, 55, 59, 62],
];
const ROOTS = [41, 40, 38, 36];

// Rhodes-ish electric piano: FM bell + tremolo
const keysVoice = (f) => (t) => {
  const mod = Math.sin(2 * Math.PI * f * 2 * t) * 1.2 * Math.exp(-t * 3);
  const v = Math.sin(2 * Math.PI * f * t + mod) * env(t, 0.01, 1.4);
  return v * (0.85 + 0.15 * Math.sin(2 * Math.PI * 4.5 * t));
};
for (let bar = 0; bar < DUR / BAR; bar++) {
  const t0 = bar * BAR;
  const ch = CHORDS[bar % 4];
  ch.forEach((m, i) => madd(t0 + i * 0.018, keysVoice(mtof(m)), 2.2, 0.075, (i - 2) * 0.15));
  // little off-beat stab on the "and" of 3
  ch.slice(2).forEach((m, i) => madd(t0 + BEAT * 2.5, keysVoice(mtof(m + 12)), 0.8, 0.03, 0.3));
  // bass
  const rf = mtof(ROOTS[bar % 4]);
  madd(t0, (t) => Math.sin(2 * Math.PI * rf * t) * env(t, 0.02, 0.9) + 0.3 * Math.sin(4 * Math.PI * rf * t) * env(t, 0.01, 0.3), 1.6, 0.22);
  madd(t0 + BEAT * 3, (t) => Math.sin(2 * Math.PI * rf * t) * env(t, 0.02, 0.3), 0.6, 0.15);
}

// drums (half time: kick 1, snare 3)
const kick = (t) => Math.sin(2 * Math.PI * (45 + 90 * Math.exp(-t * 30)) * t) * env(t, 0.002, 0.18);
const snare = (t) => (rnd() * 0.7 * env(t, 0.001, 0.09) + Math.sin(2 * Math.PI * 190 * t) * 0.4 * env(t, 0.001, 0.05));
const hat = (t) => rnd() * env(t, 0.001, 0.025);
const drumsOn = (t) => !(t >= 11.0 && t < 14.0);
for (let b = 0; b < DUR / BEAT; b++) {
  const t0 = b * BEAT;
  if (!drumsOn(t0)) continue;
  const inBar = b % 4;
  if (inBar === 0) madd(t0, kick, 0.5, 0.55);
  if (inBar === 1 && b % 8 === 5) madd(t0 + 0.25, kick, 0.5, 0.35);
  if (inBar === 2) madd(t0, snare, 0.3, 0.32);
  madd(t0, hat, 0.08, 0.06, 0.25);
  madd(t0 + 0.25 + 0.04, hat, 0.08, 0.035, -0.25); // swung 8th
}

// tape stop into the grey section, riser back out
const tapeStop = (t0, len) => {
  const s0 = Math.floor(t0 * SR), n = Math.floor(len * SR);
  const srcL = ML.slice(s0, s0 + n), srcR = MR.slice(s0, s0 + n);
  let pos = 0;
  for (let i = 0; i < n; i++) {
    const rate = 1 - i / n;
    pos += rate;
    const j = Math.min(n - 1, Math.floor(pos));
    ML[s0 + i] = srcL[j] * rate;
    MR[s0 + i] = srcR[j] * rate;
  }
};
tapeStop(10.75, 0.25);

// music bus processing: lo-fi lowpass, muffle in grey section, bitcrush in wireframe section
let lpL = 0, lpR = 0;
for (let i = 0; i < N; i++) {
  const t = i / SR;
  let cutoff = 5200;
  let g = 1;
  if (t >= 11.0 && t < 14.0) { cutoff = 450; g = 0.55; }
  if (t >= 14.0 && t < 15.0) { cutoff = 450 + (5200 - 450) * ((t - 14) / 1.0); }
  const a = 1 - Math.exp((-2 * Math.PI * cutoff) / SR);
  let l = ML[i], r = MR[i];
  if (t >= 24.0 && t < 27.0) {
    const q = 1 / 12;
    const hold = 6;
    const k = i - (i % hold);
    l = Math.round(ML[k] / q) * q;
    r = Math.round(MR[k] / q) * q;
  }
  lpL += a * (l - lpL);
  lpR += a * (r - lpR);
  L[i] += lpL * g;
  R[i] += lpR * g;
}

// vinyl crackle + hiss under everything
for (let i = 0; i < N; i++) {
  const n = rnd() * 0.004;
  const pop = (rnd() + 1) / 2 < 0.00012 ? rnd() * 0.08 : 0;
  L[i] += n + pop;
  R[i] += n + pop;
}

// ── SFX ────────────────────────────────────────────────────────────────
const whoosh = (t0, len = 0.6, gain = 0.22, pan = 0) => {
  let lp = 0;
  add(t0, (t) => {
    const x = t / len;
    const cutoff = 300 + 3500 * Math.sin(Math.PI * x);
    const a = 1 - Math.exp((-2 * Math.PI * cutoff) / SR);
    lp += a * (rnd() - lp);
    return lp * Math.sin(Math.PI * x) ** 2 * 2.2;
  }, len, gain, pan);
};
const pop = (t0, f = 600, gain = 0.3) =>
  add(t0, (t) => Math.sin(2 * Math.PI * (f + 900 * Math.exp(-t * 40)) * t) * env(t, 0.002, 0.06), 0.25, gain);
const click = (t0, gain = 0.25) => add(t0, (t) => (rnd() * 0.6 + Math.sin(2 * Math.PI * 2400 * t) * 0.4) * env(t, 0.0005, 0.012), 0.05, gain, (rnd() * 0.3));
const blip = (t0, f, gain = 0.18) => add(t0, (t) => Math.sign(Math.sin(2 * Math.PI * f * t)) * 0.5 * env(t, 0.002, 0.08), 0.2, gain);
const bell = (t0, f, gain = 0.2, pan = 0) =>
  add(t0, (t) => (Math.sin(2 * Math.PI * f * t + Math.sin(2 * Math.PI * f * 3.5 * t) * 1.5 * Math.exp(-t * 4)) * env(t, 0.003, 0.8)), 1.8, gain, pan);
const thud = (t0, gain = 0.6) => add(t0, (t) => (Math.sin(2 * Math.PI * (40 + 60 * Math.exp(-t * 20)) * t) + rnd() * 0.3 * Math.exp(-t * 30)) * env(t, 0.002, 0.25), 0.8, gain);
const glitch = (t0, len, gain = 0.12) => add(t0, (t, i) => (Math.floor(i / 40) % 3 === 0 ? rnd() : Math.sign(Math.sin(2 * Math.PI * 180 * t))) * 0.5, len, gain);

// camera moves (mirrors WHOOSH_TIMES in src/camera.ts)
[0.05, 1.5, 3.05, 5.45, 6.0, 7.2, 14.1, 16.7, 17.3, 21.5, 27.05].forEach((t, i) => whoosh(t, 0.55, 0.2, i % 2 ? 0.35 : -0.35));

// 0–3 s title glitch bursts, then settle blip
[0.55, 0.9, 1.3, 1.65, 2.05].forEach((t, i) => glitch(t, 0.06 + (i % 2) * 0.05, 0.1));
blip(2.5, 880, 0.12);

// 3–7 s chat bubbles pop out, then get sucked back in
[0, 1, 2, 3, 4].forEach((i) => pop(3.1 + i * 0.25, 500 + i * 90, 0.32));
whoosh(6.2, 0.75, 0.3);
pop(6.85, 300, 0.25);

// 7–11 s dive, typing, click, render
whoosh(7.45, 0.45, 0.35);
const PROMPT = "make my desk feel like golden hour";
const typeStart = 7.95, typeEnd = 9.55;
for (let c = 0; c < PROMPT.length; c++) {
  const t = typeStart + (c / PROMPT.length) * (typeEnd - typeStart);
  click(t, PROMPT[c] === " " ? 0.32 : 0.22);
}
click(10.15, 0.5);
add(10.15, (t) => Math.sin(2 * Math.PI * 1200 * t) * env(t, 0.001, 0.03), 0.1, 0.2);
for (let k = 0; k < 8; k++) blip(10.25 + k * 0.08, 400 + k * 60, 0.05);

// 11–14 s grey: thud as the computer tips over, CRT power-off, old phone buzz
add(11.0, (t) => rnd() * env(t, 0.001, 0.05), 0.2, 0.2);
thud(12.0, 0.7);
add(12.0, (t) => Math.sin(2 * Math.PI * (9000 * Math.exp(-t * 8)) * t) * env(t, 0.001, 0.2), 0.4, 0.06);
for (let k = 0; k < 2; k++) add(12.55 + k * 0.35, (t) => Math.sign(Math.sin(2 * Math.PI * 170 * t)) * Math.sin(2 * Math.PI * 30 * t) * env(t, 0.01, 0.2), 0.28, 0.12);
blip(12.8, 1320, 0.1);

// 13–14 s riser into the warm return
add(13.0, (t) => {
  const f = 200 + 1600 * (t / 1.0) ** 2;
  return (Math.sin(2 * Math.PI * f * t) * 0.3 + rnd() * 0.4) * (t / 1.0) ** 2;
}, 1.0, 0.18);
bell(14.0, mtof(77), 0.12, -0.3);
bell(14.02, mtof(84), 0.08, 0.3);

// 18–24 s XP: checks + LEVEL UP chime + labels
[18.9, 19.4, 19.9, 20.4].forEach((t, i) => { blip(t, 660 + i * 110, 0.14); click(t, 0.15); });
// chime: major arpeggio
[72, 76, 79, 84, 88].forEach((m, i) => bell(21.0 + i * 0.07, mtof(m), 0.16, (i - 2) * 0.2));
[0, 1, 2, 3].forEach((i) => pop(21.4 + i * 0.25, 700 + i * 120, 0.22));

// 24–27 s wireframe: digital zaps
glitch(24.0, 0.2, 0.18);
glitch(25.5, 0.08, 0.08);
glitch(26.6, 0.35, 0.12);
glitch(27.0, 0.1, 0.15);

// 27.5 s CTA slam: reverse swell into a boom
add(27.0, (t) => rnd() * (t / 0.5) ** 3 * 0.6, 0.5, 0.25);
thud(27.5, 0.85);
add(27.5, (t) => rnd() * env(t, 0.001, 0.35) * 0.5, 1.0, 0.25);
bell(27.5, mtof(72), 0.1);
bell(27.52, mtof(79), 0.08);

// ── master: fade, soft clip, write ─────────────────────────────────────
for (let i = 0; i < N; i++) {
  const t = i / SR;
  const fade = Math.min(1, t / 0.3) * Math.min(1, (DUR - t) / 1.2);
  L[i] = Math.tanh(L[i] * 1.1 * fade) * 0.9;
  R[i] = Math.tanh(R[i] * 1.1 * fade) * 0.9;
}
const buf = Buffer.alloc(44 + N * 4);
buf.write("RIFF", 0); buf.writeUInt32LE(36 + N * 4, 4); buf.write("WAVE", 8);
buf.write("fmt ", 12); buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20); buf.writeUInt16LE(2, 22);
buf.writeUInt32LE(SR, 24); buf.writeUInt32LE(SR * 4, 28); buf.writeUInt16LE(4, 32); buf.writeUInt16LE(16, 34);
buf.write("data", 36); buf.writeUInt32LE(N * 4, 40);
for (let i = 0; i < N; i++) {
  buf.writeInt16LE(Math.round(Math.max(-1, Math.min(1, L[i])) * 32767), 44 + i * 4);
  buf.writeInt16LE(Math.round(Math.max(-1, Math.min(1, R[i])) * 32767), 46 + i * 4);
}
mkdirSync("public", { recursive: true });
writeFileSync("public/audio.wav", buf);
console.log("wrote public/audio.wav");
