# Retro Desktop — 30 s 3D motion video (Remotion + React Three Fiber)

1080×1920, 30 fps, 30 s, MP4 with sound. Everything (scene, camera, screens, music, SFX) is generated from code.

## Edit
- `src/config.ts` — title word, prompt text, phone text, CTA word, chat bubbles, caption lines and timings
  (wrap the yellow key word in `*asterisks*`).
- `src/camera.ts` — camera keyframes (one continuous camera; `cut: true` starts a new shot).
- `src/Scene.tsx` — the low-poly room, lighting (golden-hour sun through blinds), bubbles, labels, CTA pill, post FX (bloom, DOF).
- `src/screen.ts` — everything drawn on the CRT / phone / full-screen OS.
- `scripts/make-audio.mjs` — synthesised lo-fi beat + SFX (keep timings in sync with the files above).

## Run
```bash
npm install
npm run studio     # preview
npm run render     # → out/retro-desktop.mp4  (60 fps pass blended to 30 fps for motion blur)
```
On a machine with a GPU, swap `--gl=swangle` for `--gl=angle` in `scripts/render.sh` for a much faster render.
