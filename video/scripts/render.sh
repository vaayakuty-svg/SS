#!/usr/bin/env bash
# Full render: soundtrack → 60 fps silent pass → 2-frame blend down to 30 fps (180° shutter motion blur) → mux audio.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p out
node scripts/make-audio.mjs
npx remotion render RetroDesktop60 out/raw60.mp4 --gl=swangle --concurrency=4 --crf=12 --muted
ffmpeg -y -v error -i out/raw60.mp4 -i public/audio.wav \
  -filter_complex "[0:v]tmix=frames=2:weights='1 1',fps=30,format=yuv420p[v]" \
  -map "[v]" -map 1:a -c:v libx264 -preset slow -crf 17 -profile:v high -movflags +faststart \
  -c:a aac -b:a 192k -shortest out/retro-desktop.mp4
echo "done → out/retro-desktop.mp4"
