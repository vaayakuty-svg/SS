import { Easing } from "remotion";

export const clamp01 = (x: number) => Math.max(0, Math.min(1, x));
export const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
export const range = (t: number, a: number, b: number) => clamp01((t - a) / (b - a));
export const easeInOut = Easing.bezier(0.65, 0, 0.35, 1);
export const easeOut = Easing.bezier(0.16, 1, 0.3, 1);
export const easeIn = Easing.bezier(0.55, 0, 1, 0.45);

// Damped spring 0→1 with overshoot, t in seconds since start.
export const spring = (t: number, stiffness = 14, damping = 0.32) => {
  if (t <= 0) return 0;
  return 1 - Math.exp(-t * stiffness * damping) * Math.cos(t * stiffness);
};

// Deterministic hash noise.
export const rand = (n: number) => {
  const x = Math.sin(n * 127.1 + 311.7) * 43758.5453;
  return x - Math.floor(x);
};
