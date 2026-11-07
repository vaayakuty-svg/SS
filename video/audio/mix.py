"""Process + place voice-over lines from timeline.json, duck the score under them, write audio/mix.wav."""
import json, os, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
TL = json.load(open(os.path.join(HERE, "..", "timeline.json")))
VO = os.path.join(HERE, "vo")

# voice chain: -2 semitones (formant-ish deepening), warmth, presence, compression, small room
PITCH = 0.89
chain = (f"aresample=48000,asetrate={48000*PITCH:.0f},aresample=48000,atempo={1/PITCH:.4f},"
         "highpass=f=70,equalizer=f=140:t=q:w=1:g=4,equalizer=f=3200:t=q:w=1.2:g=2.5,equalizer=f=7500:t=q:w=1:g=-2,"
         "acompressor=threshold=-20dB:ratio=3.5:attack=5:release=120:makeup=4,"
         "aecho=0.8:0.5:45|90:0.18|0.10")
inputs, filters, labels = [], [], []
for i, line in enumerate(TL["vo"]):
    inputs += ["-i", os.path.join(VO, line["file"])]
    d = int(line["t"] * 1000)
    filters.append(f"[{i}:a]{chain},adelay={d}|{d},apad[v{i}]")
    labels.append(f"[v{i}]")
n = len(TL["vo"])
inputs += ["-i", os.path.join(HERE, "music.wav")]
filters.append(f"{''.join(labels)}amix=inputs={n}:normalize=0,pan=stereo|c0=c0|c1=c0,atrim=0:{TL['duration']},volume=1.6,asplit=2[vo][vosc]")
filters.append(f"[{n}:a]volume=0.85,apad[mus]")
filters.append("[mus][vosc]sidechaincompress=threshold=0.04:ratio=5:attack=20:release=350:makeup=1[duck]")
filters.append("[duck][vo]amix=inputs=2:normalize=0,alimiter=limit=0.89,loudnorm=I=-14:TP=-1.0:LRA=11,apad[out]")
out = os.path.join(HERE, "mix.wav")
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *inputs, "-filter_complex", ";".join(filters), "-map", "[out]", "-ar", "48000", "-t", str(TL["duration"]), out], check=True)
print("wrote", out)
