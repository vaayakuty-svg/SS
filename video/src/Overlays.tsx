import React, { useLayoutEffect, useRef } from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig } from "remotion";
import { CAPTIONS, CTA_SUB } from "./config";
import { CODE_LINES, drawOS } from "./screen";
import { warmthAt, wireAt } from "./Scene";
import { clamp01, easeInOut, easeOut, lerp, rand, range, spring } from "./util";

const useT = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return { t: frame / fps, frame };
};

// CSS grade applied to the 3D layer: snaps to flat grey at 11 s, returns at 14 s.
export const gradeFilter = (t: number) => {
  const w = warmthAt(t);
  return `saturate(${lerp(0.08, 1.12, w)}) contrast(${lerp(0.82, 1.06, w)}) brightness(${lerp(0.9, 1.0, w)})`;
};

// ── "inside the computer": full-frame retro OS (7.6–11 s) ─────────────
export const OSOverlay = () => {
  const { t } = useT();
  const ref = useRef<HTMLCanvasElement>(null);
  const visible = t >= 7.55 && t < 11.0;
  useLayoutEffect(() => {
    if (!visible || !ref.current) return;
    drawOS(ref.current.getContext("2d")!, 1080, 1920, t);
  });
  if (!visible) return null;
  const k = easeOut(range(t, 7.55, 7.9));
  return (
    <AbsoluteFill style={{ opacity: clamp01(k * 1.4), transform: `scale(${lerp(0.42, 1, k)})`, borderRadius: lerp(60, 0, k), overflow: "hidden" }}>
      <canvas ref={ref} width={1080} height={1920} style={{ width: "100%", height: "100%" }} />
      {/* CRT curvature hint */}
      <AbsoluteFill style={{ boxShadow: "inset 0 0 220px rgba(0,0,0,0.65)", borderRadius: 40 }} />
    </AbsoluteFill>
  );
};

// ── flashes on cuts ───────────────────────────────────────────────────
const FLASHES: { t: number; d: number; c: string; a: number }[] = [
  { t: 7.72, d: 0.3, c: "255,214,150", a: 0.85 },
  { t: 11.0, d: 0.22, c: "235,235,235", a: 0.6 },
  { t: 12.5, d: 0.18, c: "255,255,255", a: 0.35 },
  { t: 24.0, d: 0.25, c: "190,255,210", a: 0.9 },
  { t: 27.0, d: 0.25, c: "255,230,190", a: 0.8 },
  { t: 27.5, d: 0.3, c: "255,200,120", a: 0.5 },
];
export const Flashes = () => {
  const { t } = useT();
  let a = 0, c = "255,255,255";
  for (const f of FLASHES) {
    if (t >= f.t && t < f.t + f.d) {
      const v = f.a * (1 - easeOut(range(t, f.t, f.t + f.d)));
      if (v > a) { a = v; c = f.c; }
    }
  }
  if (a <= 0) return null;
  return <AbsoluteFill style={{ background: `rgba(${c},${a})`, mixBlendMode: "screen" }} />;
};

// ── golden warmth + sweep ─────────────────────────────────────────────
export const Warmth = () => {
  const { t } = useT();
  const w = warmthAt(t);
  const sweep = t >= 14.0 && t < 15.6 ? easeInOut(range(t, 14.0, 15.6)) : -1;
  return (
    <>
      <AbsoluteFill
        style={{
          background: "radial-gradient(120% 70% at 0% 25%, rgba(255,150,40,0.55), rgba(255,120,30,0) 60%)",
          mixBlendMode: "soft-light",
          opacity: w,
        }}
      />
      {sweep >= 0 && (
        <AbsoluteFill
          style={{
            background: `linear-gradient(105deg, rgba(255,170,60,0) ${sweep * 160 - 60}%, rgba(255,190,90,0.55) ${sweep * 160 - 30}%, rgba(255,170,60,0) ${sweep * 160}%)`,
            mixBlendMode: "screen",
          }}
        />
      )}
    </>
  );
};

// ── wireframe beat: green code blocks (24–27 s) ───────────────────────
export const CodeBlocks = () => {
  const { t, frame } = useT();
  if (!wireAt(t) && !(t >= 24 && t < 27 && t > 26.55)) return null;
  if (t < 24 || t >= 27) return null;
  const blocks = Array.from({ length: 7 });
  const local = t - 24;
  return (
    <AbsoluteFill style={{ fontFamily: "JetBrains Mono", color: "#3DFF7A" }}>
      {blocks.map((_, i) => {
        const born = i * 0.18;
        if (local < born) return null;
        const k = spring(local - born, 16, 0.32);
        const x = 60 + rand(i * 5.1) * 520;
        const y = 380 + ((i * 197) % 1150) - (local - born) * 60;
        const lines = [0, 1, 2].map((j) => CODE_LINES[(i * 3 + j) % CODE_LINES.length]);
        const jitter = (rand(frame * 1.7 + i) - 0.5) * (t > 26.55 ? 30 : 4);
        return (
          <div key={i} style={{
            position: "absolute", left: x + jitter, top: y, transform: `scale(${k})`, transformOrigin: "left top",
            background: "rgba(2,20,8,0.72)", border: "2px solid rgba(61,255,122,0.65)", borderRadius: 14,
            padding: "14px 20px", fontSize: 26, lineHeight: 1.35, whiteSpace: "pre",
            boxShadow: "0 0 30px rgba(61,255,122,0.35)", textShadow: "0 0 10px rgba(61,255,122,0.8)",
          }}>
            {lines.join("\n")}
          </div>
        );
      })}
    </AbsoluteFill>
  );
};

// ── captions ──────────────────────────────────────────────────────────
type Word = { text: string; key: boolean };
const parse = (s: string): Word[] => {
  const out: Word[] = [];
  let inKey = false;
  for (const raw of s.split(" ")) {
    let w = raw, key = inKey;
    if (w.startsWith("*")) { key = true; inKey = true; w = w.slice(1); }
    if (w.endsWith("*")) { w = w.slice(0, -1); inKey = false; }
    out.push({ text: w, key });
  }
  return out;
};

export const Captions = () => {
  const { t } = useT();
  const line = CAPTIONS.find((c) => t >= c.start - 0.05 && t < c.hold + 0.25);
  if (!line) return null;
  const words = parse(line.text);
  const out = range(t, line.hold, line.hold + 0.25);
  return (
    <AbsoluteFill style={{ alignItems: "center", paddingTop: 250 }}>
      <div style={{
        width: 940, textAlign: "center", fontFamily: "Fredoka", fontWeight: 700, fontSize: 84,
        lineHeight: 1.08, color: "#fff", letterSpacing: 0.5, opacity: 1 - out,
        transform: `translateY(${-out * 30}px)`,
      }}>
        {words.map((w, i) => {
          const at = line.start + (i * (line.end - line.start)) / Math.max(1, words.length - 1);
          if (t < at) return <span key={i} style={{ opacity: 0 }}>{w.text} </span>;
          const k = spring(t - at, 20, 0.32);
          return (
            <span key={i} style={{
              display: "inline-block", marginRight: 22, color: w.key ? "#FFD60A" : "#fff",
              transform: `scale(${0.6 + 0.4 * k}) translateY(${(1 - k) * 18}px)`,
              textShadow: "0 6px 22px rgba(0,0,0,0.55), 0 2px 4px rgba(0,0,0,0.6)",
            }}>{w.text}</span>
          );
        })}
      </div>
    </AbsoluteFill>
  );
};

export const CtaSub = () => {
  const { t } = useT();
  if (t < 27.75) return null;
  const k = spring(t - 27.75, 14, 0.35);
  return (
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "center" }}>
      <div style={{
        marginTop: 330, fontFamily: "Fredoka", fontWeight: 600, fontSize: 52, color: "#FFF1D6",
        opacity: clamp01(k), transform: `translateY(${(1 - k) * 30}px)`,
        textShadow: "0 4px 18px rgba(0,0,0,0.6)",
      }}>{CTA_SUB}</div>
    </AbsoluteFill>
  );
};

// ── film grain + vignette ─────────────────────────────────────────────
export const Grain = () => {
  const { frame } = useT();
  return (
    <>
      <AbsoluteFill style={{ background: "radial-gradient(ellipse at center, rgba(0,0,0,0) 55%, rgba(20,6,0,0.55) 100%)" }} />
      <AbsoluteFill style={{ opacity: 0.11, mixBlendMode: "overlay" }}>
        <svg width="1080" height="1920">
          <filter id="g">
            <feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="2" seed={frame % 97} stitchTiles="stitch" />
            <feColorMatrix type="saturate" values="0" />
          </filter>
          <rect width="100%" height="100%" filter="url(#g)" />
        </svg>
      </AbsoluteFill>
    </>
  );
};
