// ─────────────────────────────────────────────────────────────
// Everything you'd want to edit lives here.
// Times are in seconds. Captions: mark the highlighted (yellow) word with *asterisks*.
// ─────────────────────────────────────────────────────────────

export const FPS = 30;
export const DURATION_S = 30;
export const BPM = 120; // 1 beat = 0.5 s, so every beat boundary in the brief lands on a beat

export const TITLE_WORD = "MOTION"; // glitch title on the CRT (0–3 s)
export const PROMPT_TEXT = "make my desk feel like golden hour";
export const PHONE_SENDER = "Client";
export const PHONE_TEXT = "hmm... it looks kinda flat?";
export const CTA_WORD = "FOLLOW"; // 3D italic word on the glossy pill (27–30 s)
export const CTA_SUB = "for more 3D drops";

export const CHAT_BUBBLES = [
  "make it cinematic",
  "add golden light ☀",
  "more camera moves!",
  "lo-fi beat pls",
  "can it pop?",
];

export const SKILLS = ["CAMERA", "LIGHT", "MOTION", "SOUND"];

// Captions: words appear one by one between `start` and `end` of the reveal window,
// then the line holds until `hold`.
export const CAPTIONS: { text: string; start: number; end: number; hold: number }[] = [
  { text: "One prompt. One *REEL.*", start: 0.4, end: 1.8, hold: 2.9 },
  { text: "Ideas pop out of the *SCREEN*", start: 3.2, end: 4.8, hold: 6.9 },
  { text: "Type it. Hit *GENERATE.*", start: 7.3, end: 9.6, hold: 10.9 },
  { text: "...and it looks this *FLAT?*", start: 11.2, end: 12.4, hold: 13.9 },
  { text: "Bring back the *GOLDEN* hour", start: 14.3, end: 15.8, hold: 17.9 },
  { text: "Camera. Light. Motion. Sound. *LEVEL UP*", start: 18.3, end: 21.4, hold: 26.6 },
];
