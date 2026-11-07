"""Synthesised score for the GoldScalperATR teaser. Event times are shared with the visuals (timeline.json)."""
import json, os, numpy as np, wave

SR = 48000
HERE = os.path.dirname(os.path.abspath(__file__))
TL = json.load(open(os.path.join(HERE, "..", "timeline.json")))
DUR = TL["duration"]
N = int(SR * DUR)
t = np.arange(N) / SR
rng = np.random.default_rng(7)
L = np.zeros(N); R = np.zeros(N)


def add(sig, start, gain=1.0, pan=0.0):
    i = int(start * SR)
    if i >= N: return
    sig = sig[: N - i]
    L[i:i + len(sig)] += sig * gain * np.sqrt(0.5 * (1 - pan))
    R[i:i + len(sig)] += sig * gain * np.sqrt(0.5 * (1 + pan))


def env(n, a, d):
    e = np.ones(n); ai = max(1, int(a * SR)); e[:ai] = np.linspace(0, 1, ai)
    return e * np.exp(-np.arange(n) / SR / d)


def lowpass(x, fc):
    a = np.exp(-2 * np.pi * fc / SR); y = np.zeros_like(x); s = 0.0
    for k in range(len(x)):  # fine for short signals
        s = (1 - a) * x[k] + a * s; y[k] = s
    return y


def fft_filter(x, lo, hi):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    X[(f < lo) | (f > hi)] = 0
    return np.fft.irfft(X, len(x))


def midi(m): return 440 * 2 ** ((m - 69) / 12)

# --- sub drone (D1) with slow swell, ducks before the title impact
drone_env = np.clip(t / 3.0, 0, 1) * (1 - 0.6 * np.clip((t - 19.6) / 1.0, 0, 1) * (t < 20.6)) * np.clip((DUR - t) / 3.0, 0, 1)
drone = (np.sin(2 * np.pi * midi(26) * t) + 0.5 * np.sin(2 * np.pi * midi(38) * t + 0.3 * np.sin(2 * np.pi * 0.2 * t)))
add(drone * drone_env, 0, 0.32)

# --- detuned saw pad, chord changes per scene (Dm, Bb, Gm, A, Dm-add9)
chords = [(0, [50, 53, 57]), (4.8, [46, 50, 53]), (9.4, [43, 50, 55]), (15.2, [45, 49, 52, 57]), (20.6, [50, 57, 62, 64, 69])]
for ci, (st, notes) in enumerate(chords):
    en = chords[ci + 1][0] if ci + 1 < len(chords) else DUR
    n = int((en - st + 1.2) * SR); tt = np.arange(n) / SR
    sig = np.zeros(n)
    for m in notes:
        for det in (-0.08, 0.0, 0.07):
            f = midi(m + det)
            sig += 2 * ((tt * f + rng.random()) % 1) - 1
    sig = fft_filter(sig, 60, 900 if ci < 4 else 1800) / (len(notes) * 3)
    e = np.clip(tt / 0.8, 0, 1) * np.clip((en - st + 1.2 - tt) / 1.2, 0, 1)
    add(sig * e, st, 0.22, pan=(-0.2 if ci % 2 else 0.2))

# --- clock tick (8ths @ 120bpm) – "gold never sleeps"; dense hats later
def tick(freq=5200, d=0.018):
    n = int(0.06 * SR); nz = rng.standard_normal(n)
    return fft_filter(nz, freq, 14000) * env(n, 0.001, d)
for k in range(int(DUR / 0.25)):
    tm = k * 0.25
    if tm > DUR - 2.5 or 19.4 < tm < 20.6: continue
    g = 0.10 if k % 2 == 0 else 0.05
    if tm < 1.0: g *= tm
    add(tick(), tm, g, pan=0.35 if k % 2 else -0.35)

# --- heartbeat kick on beats from scene 2 on
def kick(f0=55, d=0.35):
    n = int(0.6 * SR); tt = np.arange(n) / SR
    ph = 2 * np.pi * np.cumsum(f0 + 90 * np.exp(-tt / 0.03)) / SR
    return np.sin(ph) * env(n, 0.002, d)
for k in range(int(DUR / 0.5)):
    tm = k * 0.5
    if 4.8 <= tm < 19.4 or 21.6 <= tm < DUR - 3:
        add(kick(), tm, 0.35 if k % 2 == 0 else 0.18)

# --- impacts: boom + noise burst + metallic ring
def impact(size=1.0):
    n = int(3.5 * SR); tt = np.arange(n) / SR
    boom = np.sin(2 * np.pi * np.cumsum(38 + 120 * np.exp(-tt / 0.06)) / SR) * env(n, 0.001, 0.9 * size)
    nz = fft_filter(rng.standard_normal(n), 200, 9000) * env(n, 0.001, 0.12 * size)
    ring = sum(np.sin(2 * np.pi * f * tt) for f in (midi(74), midi(81) * 1.003, midi(86) * 0.997)) * env(n, 0.002, 1.2 * size) / 3
    return boom * 0.9 + nz * 0.5 + ring * 0.12
def riser(dur):
    n = int(dur * SR); tt = np.arange(n) / SR
    nz = rng.standard_normal(n); out = np.zeros(n)
    seg = 2048
    for s in range(0, n, seg):  # sweeping band-pass
        p = s / n; lo = 300 + 5000 * p ** 2
        out[s:s + seg] = fft_filter(nz[s:s + seg], lo, lo * 2.2)
    tone = np.sin(2 * np.pi * np.cumsum(200 + 800 * (tt / dur) ** 2) / SR) * 0.15
    return (out + tone) * (tt / dur) ** 2.5
def whoosh(d=0.6):
    n = int(d * SR); tt = np.arange(n) / SR
    return fft_filter(rng.standard_normal(n), 400, 3000) * np.sin(np.pi * tt / d) ** 2

for e in TL["hits"]:
    add(impact(e["size"]), e["t"], 0.55 * e["size"])
for e in TL["risers"]:
    add(riser(e["dur"]), e["t"] - e["dur"], 0.35)
for e in TL["whooshes"]:
    add(whoosh(), e - 0.35, 0.25, pan=float(rng.uniform(-0.5, 0.5)))
# spark crackles
for e in TL["sparks"]:
    for _ in range(40):
        add(tick(3000, 0.004), e + rng.exponential(0.25), float(rng.uniform(0.02, 0.09)), pan=float(rng.uniform(-0.8, 0.8)))

# --- simple stereo reverb (multi-tap feedback)
def reverb(x, taps=((0.031, .5), (0.047, .45), (0.071, .4), (0.113, .35), (0.167, .3), (0.241, .25))):
    y = x.copy()
    for d, g in taps:
        k = int(d * SR); y[k:] += x[:-k] * g
    return y
L2 = reverb(L); R2 = reverb(R)
mix = np.stack([L * 0.7 + L2 * 0.3, R * 0.7 + R2 * 0.3], 1)
mix = np.tanh(mix * 1.4) / np.tanh(1.4)
mix /= np.max(np.abs(mix)) / 0.89
fade = np.clip((DUR - t) / 1.5, 0, 1)[:, None]
mix *= fade
with wave.open(os.path.join(HERE, "music.wav"), "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((mix * 32767).astype(np.int16).tobytes())
print("music.wav", DUR, "s")
