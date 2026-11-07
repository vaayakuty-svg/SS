# GoldScalperATR — cinematic teaser (rendered in code)

A 26-second, 1920×1080 / 30 fps teaser for `Experts/GoldScalperATR.mq5`, generated entirely from code:
three.js scenes with HDR bloom, a custom film pass (grain, vignette, chromatic aberration, grade, 2:1 letterbox),
spark particles, kinetic type, a synthesised score and a local neural-TTS voice-over.

Output: `GoldScalperATR_teaser.mp4`

## Scenes (`timeline.json` holds every shared beat)
| Time | Scene | VO |
|---|---|---|
| 0–4.8 s | Glowing price line drawing through the dark, sparks off the tip, rolling clock | "Gold never sleeps." |
| 4.8–9.45 s | 3D candlesticks, 15-bar high, a fake-out, then the real breakout | "Every minute, it breaks out. Or fakes you out." |
| 9.45–15.2 s | Kinetic type: TREND / BREAKOUT / VOLATILITY converge into one point | "Trend. Breakout. Volatility. Three filters. One decision." |
| 15.2–20.6 s | Rotating gold bar, orbit rings, "1%" | "Risk is set before the trade. One percent. Every time." |
| 20.6–26 s | Title reveal, shockwave, disclaimer | "Gold Scalper, ATR. Every rule, in the source." |

## Rebuild
```bash
cd video
npm install                       # three, @fontsource/cinzel (Playwright + Chromium must be available)
python3 audio/music.py            # -> audio/music.wav (score, locked to timeline.json hits)
python3 audio/mix.py              # -> audio/mix.wav  (VO processing, placement, ducking, -14 LUFS)
node render.js stills 2.6 8.8     # quick preview frames -> out/still_<t>.png
node render.js video 4            # -> out/silent.mp4 (4 parallel headless workers)
ffmpeg -i out/silent.mp4 -i audio/mix.wav -c:v copy -c:a aac -b:a 256k -shortest GoldScalperATR_teaser.mp4
```
VO lines in `audio/vo/` were made with Piper TTS (`en_US-ryan-high`), e.g.
`echo "Gold never sleeps." | python3 -m piper -m en_US-ryan-high.onnx --length-scale 1.18 -f raw_1.wav`.
