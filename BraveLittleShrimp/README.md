# 🦐 The Brave Little Shrimp

A 30-second, 9:16 vertical motion-graphics short built from the "Premium Motion Graphics Animation Script".

**Final video:** [`out/brave_little_shrimp.mp4`](out/brave_little_shrimp.mp4): 1080×1920, 60 fps, H.264 with AAC stereo audio. No voiceover.

| Time | Scene | Typography |
|---|---|---|
| 0–5s | Intro: three blue circles expand, Shrimpy jumps in, spins 360°, shapes bounce around him | MEET → SHRIMPY! 🦐 |
| 5–10s | Big Dreams: the circle becomes the ocean, with parallax corals, bubbles, and Shrimpy looking up | SMALL SIZE → (letters scatter) → BIG DREAMS! |
| 10–15s | Oh No!: a fish is trapped by seaweed between rocks, warning rings pulse, the camera zooms fast to Shrimpy's face | OH NO! → HELP! (shake) |
| 15–22s | The Rescue: a speed-ramped dash with speed lines, the seaweed stretches and snaps, particles explode, the fish escapes | BE BRAVE! → (impact) → YOU DID IT! |
| 22–27s | Happy Ending: the background washes to white, the fish orbits Shrimpy, and a beating heart, hearts and circles float around them | LITTLE HERO → BIG HEART ❤️ |
| 27–30s | Final Message: a big blue ring draws in, Shrimpy waves, a cinematic zoom-out and fade to white | SMALL / BUT / MIGHTY! 🦐 |

Transitions follow the script: circle fill, bubble zoom, whip-pan, particle burst into colourful circles, and a white flash with a soft zoom. The palette is exactly `#FFFFFF`, `#007BFF`, `#00DFFF`, `#FF7043` and `#102A43`. The typeface is Montserrat Black.

## How it's made

- `animation.js`: the whole film is drawn on a canvas. Each frame is a pure function of time, so there is no flicker or randomness between renders. Characters are drawn in code with soft 3D-style shading, and one `drawShrimp()` keeps Shrimpy's design identical in every scene.
- `audio/make_soundtrack.py`: synthesizes an original 120 BPM score and every SFX cue from the script (pops, whooshes, bubble pops, cartoon alert, seaweed stretch, snap, magical chimes, final hit). It is royalty-free and synced to the animation timings.
- `render.js`: renders frames with headless Chromium using 4 parallel workers, then encodes and muxes the audio with ffmpeg.

## Usage

```bash
# Preview in a browser (click to play/pause, drag to scrub)
open index.html

# Rebuild the soundtrack (needs numpy)
python3 audio/make_soundtrack.py

# Render the video (needs node + playwright + ffmpeg); about 4–5 min on 4 cores
node render.js                     # 60 fps
node render.js --fps 30            # lighter 30 fps version
node render.js --stills 3.6,19.3   # PNG stills to out/stills/
```

Font: Montserrat (SIL Open Font License), bundled in `fonts/`.
