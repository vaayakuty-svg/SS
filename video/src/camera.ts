// One continuous virtual camera. Keys are grouped into shots; within a shot the path is a
// Catmull-Rom spline through the keys, and each segment has its own easing so the camera is
// always drifting. `cut: true` starts a new shot (only used where the brief asks for a cut
// or where a full-frame flash hides it).
import { Vector3 } from "three";
import { easeIn, easeInOut, easeOut, lerp } from "./util";

type V = [number, number, number];
type Ease = "io" | "in" | "out" | "lin";
type Key = { t: number; p: V; l: V; fov?: number; ease?: Ease; cut?: boolean };

// CRT screen centre in world space.
export const SCREEN: V = [-0.15, 1.13, 0.135];
export const PHONE: V = [0.78, 0.79, 0.3];
const PHONE_SCREEN: V = [0.774, 0.79, 0.265];

const KEYS: Key[] = [
  // 0–3 s: wide golden reveal, push in to the CRT
  { t: 0.0, p: [2.5, 2.05, 3.5], l: [-0.1, 1.0, -0.25], fov: 42 },
  { t: 1.5, p: [1.0, 1.42, 1.85], l: [-0.15, 1.08, 0.0], ease: "lin" },
  { t: 2.8, p: [-0.08, 1.15, 1.02], l: SCREEN, ease: "out", fov: 40 },
  // 3–7 s: pull back + slow orbit with the chat bubbles, quick whip to the plant
  { t: 3.6, p: [0.45, 1.32, 1.85], l: [-0.15, 1.18, 0.05], ease: "io" },
  { t: 5.2, p: [-0.75, 1.42, 1.7], l: [-0.15, 1.18, 0.05], ease: "lin" },
  { t: 5.75, p: [-0.7, 1.36, 1.5], l: [-0.95, 1.0, -0.3], ease: "io" },
  { t: 6.3, p: [-0.35, 1.25, 1.3], l: SCREEN, ease: "io" },
  // 7–8 s: dive into the screen
  { t: 7.1, p: [-0.15, 1.14, 0.78], l: SCREEN, ease: "lin" },
  { t: 7.85, p: [-0.15, 1.13, 0.3], l: SCREEN, ease: "in", fov: 38 },
  // 11 s: grey room (cut on the beat)
  { t: 11.0, p: [1.55, 1.55, 2.15], l: [-0.1, 1.0, 0.0], fov: 40, cut: true },
  { t: 12.5, p: [1.2, 1.42, 1.75], l: [-0.1, 1.0, 0.0], ease: "lin" },
  // 12.5 s: cut to the phone, then warm light returns and we orbit the desk
  { t: 12.5, p: [0.775, 1.02, 0.36], l: PHONE_SCREEN, fov: 40, cut: true },
  { t: 13.7, p: [0.775, 0.99, 0.34], l: PHONE_SCREEN, ease: "lin" },
  { t: 14.0, p: [0.776, 0.98, 0.335], l: PHONE_SCREEN, ease: "lin" },
  { t: 15.3, p: [1.25, 1.35, 1.25], l: [0.2, 0.95, -0.1], ease: "io" },
  { t: 16.5, p: [2.05, 1.6, 1.25], l: [-0.1, 1.0, -0.3], ease: "lin" },
  // whip-pan to the lamp and mug
  { t: 17.0, p: [1.95, 1.5, 1.1], l: [0.75, 1.1, -0.2], ease: "io" },
  { t: 17.6, p: [0.9, 1.3, 1.3], l: SCREEN, ease: "io" },
  // 18–21 s: on the CRT for the XP bar
  { t: 18.4, p: [0.02, 1.16, 1.0], l: SCREEN, ease: "out" },
  { t: 21.2, p: [-0.1, 1.15, 0.9], l: SCREEN, ease: "lin" },
  // pull back, labels float around the room
  { t: 22.6, p: [0.7, 1.55, 2.4], l: [-0.1, 1.25, -0.3], ease: "io" },
  { t: 24.0, p: [-0.4, 1.85, 3.25], l: [0.0, 1.3, -0.5], ease: "lin", fov: 44 },
  // 24 s: wireframe flash hides a cut to a low-angle macro over the keyboard
  { t: 24.0, p: [-0.62, 0.87, 0.66], l: [0.05, 0.82, 0.25], fov: 46, cut: true },
  { t: 25.6, p: [-0.15, 0.86, 0.62], l: [0.25, 0.83, 0.2], ease: "lin" },
  { t: 27.0, p: [0.3, 0.95, 0.75], l: [-0.05, 0.92, 0.0], ease: "lin" },
  // 27–30 s: rise and land on the desk for the CTA
  { t: 28.3, p: [0.12, 1.22, 1.38], l: [0.0, 1.06, 0.0], ease: "out", fov: 42 },
  { t: 30.0, p: [0.08, 1.2, 1.3], l: [0.0, 1.06, 0.0], ease: "lin" },
];

const shots: Key[][] = [];
for (const k of KEYS) {
  if (k.cut || shots.length === 0) shots.push([k]);
  else shots[shots.length - 1].push(k);
}

// Hermite spline with time-based (non-uniform Catmull-Rom) tangents: no overshoot when keys are
// unevenly spaced in time.
const herm = (p0: number, p1: number, p2: number, p3: number, t0: number, t1: number, t2: number, t3: number, u: number) => {
  const d = t2 - t1;
  const m1 = ((p2 - p0) / Math.max(1e-3, t2 - t0)) * d;
  const m2 = ((p3 - p1) / Math.max(1e-3, t3 - t1)) * d;
  const u2 = u * u, u3 = u2 * u;
  return (2 * u3 - 3 * u2 + 1) * p1 + (u3 - 2 * u2 + u) * m1 + (-2 * u3 + 3 * u2) * p2 + (u3 - u2) * m2;
};
const hV = (a: Key, b: Key, c: Key, d: Key, k: "p" | "l", u: number): V =>
  [0, 1, 2].map((j) => herm(a[k][j], b[k][j], c[k][j], d[k][j], a.t, b.t, c.t, d.t, u)) as V;

const ease = (e: Ease | undefined, x: number) =>
  e === "in" ? easeIn(x) : e === "out" ? easeOut(x) : e === "lin" ? x : easeInOut(x);

export type CamState = { pos: Vector3; look: Vector3; fov: number; shot: number };

export const cameraAt = (t: number): CamState => {
  let si = 0;
  for (let i = 0; i < shots.length; i++) if (t >= shots[i][0].t) si = i;
  const s = shots[si];
  if (s.length === 1 || t <= s[0].t) {
    const k = s[0];
    return { pos: new Vector3(...k.p), look: new Vector3(...k.l), fov: k.fov ?? 40, shot: si };
  }
  let i = 0;
  while (i < s.length - 2 && t >= s[i + 1].t) i++;
  const a = s[i], b = s[i + 1];
  const x = Math.min(1, Math.max(0, (t - a.t) / (b.t - a.t)));
  const u = ease(b.ease, x);
  const p0 = s[Math.max(0, i - 1)], p3 = s[Math.min(s.length - 1, i + 2)];
  // at the ends of a shot, mirror the time so the tangent stays finite
  const q0 = p0 === a ? { ...a, t: a.t - (b.t - a.t) } : p0;
  const q3 = p3 === b ? { ...b, t: b.t + (b.t - a.t) } : p3;
  const pos = hV(q0, a, b, q3, "p", u);
  const look = hV(q0, a, b, q3, "l", u);
  // fov carries forward from the most recent key that set it
  let fa = 40;
  for (let j = 0; j <= i; j++) if (s[j].fov) fa = s[j].fov!;
  const fb = b.fov ?? fa;
  return { pos: new Vector3(...pos), look: new Vector3(...look), fov: lerp(fa, fb, u), shot: si };
};

// Times at which the camera makes a big move → whoosh SFX (also used by the audio script).
export const WHOOSH_TIMES = [0.05, 1.5, 3.05, 5.45, 6.0, 7.2, 14.1, 16.7, 17.3, 21.5, 27.05];
