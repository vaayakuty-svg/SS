"""Synthesize the 30 s soundtrack (music + SFX) for The Brave Little Shrimp.

Everything is generated from scratch, so the audio is royalty-free and the
cues line up exactly with the animation timeline in animation.js.

    python3 audio/make_soundtrack.py   ->  audio/soundtrack.wav (48 kHz stereo)
"""
import os
import wave

import numpy as np

SR = 48000
DUR = 30.0
N = int(SR * DUR)
BEAT = 0.5  # 120 BPM
rng = np.random.default_rng(7)

music = np.zeros((N, 2))
sfx = np.zeros((N, 2))


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def tt(dur):
    return np.arange(int(dur * SR)) / SR


def add(bus, t0, sig, gain=1.0, pan=0.0):
    """Mix a mono or stereo signal into a bus at time t0 (seconds)."""
    if sig.ndim == 1:
        l, r = np.sqrt(0.5 * (1 - pan)), np.sqrt(0.5 * (1 + pan))
        sig = np.stack([sig * l, sig * r], axis=1) * np.sqrt(2)
    i0 = int(t0 * SR)
    if i0 >= N:
        return
    n = min(len(sig), N - i0)
    bus[i0:i0 + n] += sig[:n] * gain


def onepole_lp(x, cutoff):
    """One-pole low-pass with a per-sample (array) or fixed cutoff in Hz."""
    cutoff = np.broadcast_to(cutoff, x.shape)
    a = 1 - np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def env_ad(n_t, attack, decay):
    return np.minimum(1, n_t / max(attack, 1e-4)) * np.exp(-n_t * decay)


# ------------------------------------------------------------ instruments --
def pluck(f, dur=0.45, bright=1.0):
    t = tt(dur)
    s = np.zeros_like(t)
    for k, a in [(1, 1), (2, 0.5 * bright), (3, 0.25 * bright), (4, 0.12 * bright)]:
        s += a * np.sin(2 * np.pi * f * k * t) * np.exp(-t * (5 + 3 * k))
    return s * env_ad(t, 0.003, 4)


def bell(f, dur=1.6):
    t = tt(dur)
    s = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 4) \
        + 0.18 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * 7)
    return s * env_ad(t, 0.002, 2.6)


def bass(f, dur):
    t = tt(dur)
    s = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * 2 * f * t) + 0.1 * np.sin(2 * np.pi * 3 * f * t)
    rel = np.clip((dur - t) / 0.05, 0, 1)
    return s * np.minimum(1, t / 0.008) * rel * np.exp(-t * 1.5)


def pad(freqs, dur, attack=0.35):
    t = tt(dur)
    s = np.zeros_like(t)
    for f in freqs:
        for det in (-0.12, 0.12):
            ff = f * 2 ** (det / 12)
            for k in range(1, 7):
                s += np.sin(2 * np.pi * ff * k * t + k) / k
    s /= len(freqs) * 6
    rel = np.clip((dur - t) / 0.4, 0, 1)
    return s * np.minimum(1, t / attack) * rel


def kick(dur=0.35):
    t = tt(dur)
    f = 48 + 110 * np.exp(-t * 32)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 9) + 0.3 * np.sin(ph) * np.exp(-t * 60)


def clap(dur=0.25):
    t = tt(dur)
    n = rng.standard_normal(len(t))
    n = np.diff(n, prepend=0)
    return n * np.exp(-t * 22) * 0.45 + np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30) * 0.4


def hat(dur=0.06, open_=False):
    t = tt(0.25 if open_ else dur)
    n = np.diff(np.diff(rng.standard_normal(len(t)), prepend=0), prepend=0)
    return n * np.exp(-t * (14 if open_ else 70)) * 0.18


# ------------------------------------------------------------------ SFX --
def pop(f=520):
    t = tt(0.12)
    ph = 2 * np.pi * np.cumsum(f * (1 + 1.8 * np.exp(-t * 45))) / SR
    return np.sin(ph) * np.exp(-t * 32)


def bubble_pop(f=380):
    t = tt(0.09)
    ph = 2 * np.pi * np.cumsum(f * (1 + 3 * t / 0.09)) / SR
    return np.sin(ph) * np.sin(np.pi * t / 0.09) ** 0.5 * np.exp(-t * 12)


def whoosh(dur=0.5, lo=300, hi=4500, peak=0.55):
    t = tt(dur)
    p = t / dur
    cut = np.where(p < peak, lo + (hi - lo) * (p / peak) ** 2, hi - (hi - lo) * ((p - peak) / (1 - peak)))
    n = onepole_lp(rng.standard_normal(len(t)), cut)
    n = onepole_lp(n, cut)
    e = np.where(p < peak, (p / peak) ** 2, ((1 - p) / (1 - peak)) ** 1.5)
    return n * e * 2.2


def alert():
    out = np.zeros(int(0.5 * SR))
    for i, f in enumerate([880, 660, 880]):
        t = tt(0.11)
        s = np.sign(np.sin(2 * np.pi * f * t)) * 0.35 + np.sin(2 * np.pi * f * t) * 0.5
        s = onepole_lp(s, 3500) * env_ad(t, 0.004, 10)
        i0 = int(i * 0.14 * SR)
        out[i0:i0 + len(s)] += s
    return out


def stretch(dur=2.2):
    t = tt(dur)
    f = 110 * 2 ** (1.9 * (t / dur) ** 1.3) * (1 + 0.02 * np.sin(2 * np.pi * 9 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = sum(np.sin(k * ph) / k for k in range(1, 6))
    s = onepole_lp(s, 1600)
    trem = 0.75 + 0.25 * np.sin(2 * np.pi * (6 + 10 * t / dur) * t)
    return s * trem * np.minimum(1, t / 0.15) * np.clip((dur - t) / 0.02, 0, 1) * 0.6


def snap():
    t = tt(0.4)
    n = rng.standard_normal(len(t)) * np.exp(-t * 40)
    thump = np.sin(2 * np.pi * np.cumsum(60 + 120 * np.exp(-t * 25)) / SR) * np.exp(-t * 10)
    return n * 0.7 + thump


def riser(dur):
    t = tt(dur)
    p = t / dur
    n = onepole_lp(rng.standard_normal(len(t)), 300 + 7000 * p ** 2)
    tone = np.sin(2 * np.pi * np.cumsum(200 * 2 ** (3 * p)) / SR) * 0.15
    return (n * 1.2 + tone) * p ** 2


def crash(dur=2.5):
    t = tt(dur)
    n = np.diff(rng.standard_normal(len(t)), prepend=0)
    return n * np.exp(-t * 2.2) * 0.35


# ---------------------------------------------------------------- music --
C, G, Am, F, Dm, E_ = [60, 64, 67], [55, 59, 62], [57, 60, 64], [53, 57, 60], [50, 53, 57], [52, 56, 59]
def chord_at(t):
    if t < 10: return [C, G, Am, F, C][int(t // 2)]
    if t < 18: return [Am, F, Dm, E_][int((t - 10) // 2)]
    if t < 19: return G
    if t < 22: return G if t >= 21 else C
    if t < 27: return [F, C, Am, G, F][min(4, int((t - 22) // 1))]
    return C

# drums
for b in range(60):
    t0 = b * BEAT
    if t0 < 0.5 or 26.9 < t0 < 28.3 or t0 >= 29.0:
        continue
    tense = 10 <= t0 < 15
    if tense:
        if b % 2 == 0: add(music, t0, kick(), 0.55)
        add(music, t0 + 0.25, hat(), 0.5, 0.3)
        continue
    if 15 <= t0 < 18.9:
        add(music, t0, kick(), 0.8)
        if t0 >= 17: add(music, t0 + 0.25, kick(), 0.55)
        add(music, t0 + 0.25, hat(), 0.7, 0.3)
        if b % 2 == 1: add(music, t0, clap(), 0.5, -0.1)
        continue
    if 22 <= t0 < 27:  # soft section
        if b % 2 == 0: add(music, t0, kick(), 0.45)
        add(music, t0 + 0.25, hat(), 0.4, 0.3)
        continue
    add(music, t0, kick(), 0.85)
    if b % 2 == 1: add(music, t0, clap(), 0.55, -0.1)
    add(music, t0 + 0.25, hat(), 0.65, 0.3)
    add(music, t0, hat(), 0.35, -0.3)

# snare roll into the snap
for i in range(16):
    tr = 17.9 + i * (1.0 / 16)
    add(music, tr, clap(0.12), 0.18 + 0.4 * i / 16, 0.1)

# bass: eighth notes following the chord roots
for i in range(int(DUR / 0.25)):
    t0 = i * 0.25
    if t0 < 0.5 or 26.9 < t0 < 28.3 or t0 >= 29.0 or 18.9 <= t0 < 19.0:
        continue
    ch = chord_at(t0)
    root = hz(min(ch) - 24 if min(ch) - 24 >= 26 else min(ch) - 12)
    if 10 <= t0 < 15 and i % 2: continue
    if 22 <= t0 < 27 and i % 4: continue
    oct_ = 2 if (i % 4 == 3 and not (10 <= t0 < 15)) else 1
    add(music, t0, bass(root * oct_, 0.24 if not (22 <= t0 < 27) else 0.95), 0.32)

# arpeggiated plucks
for i in range(int(DUR / 0.25)):
    t0 = i * 0.25
    if t0 < 1.0 or 26.9 < t0 < 28.3 or t0 >= 29.0 or 18.9 <= t0 < 19.0:
        continue
    ch = chord_at(t0)
    pattern = [0, 1, 2, 1, 0, 2, 1, 2]
    note = ch[pattern[i % 8]] + (12 if not (10 <= t0 < 15) else 0)
    if 10 <= t0 < 15 and i % 2: continue
    pan = 0.35 if i % 2 else -0.35
    add(music, t0, pluck(hz(note), 0.4, 0.7 if 10 <= t0 < 15 else 1.0), 0.16 if 22 <= t0 < 27 else 0.2, pan)

# pads, chord by chord
for t0, t1, ch in [(0, 2, C), (2, 4, G), (4, 6, Am), (6, 8, F), (8, 10, C), (10, 12, Am), (12, 14, F),
                   (14, 16, Dm), (16, 18, E_), (18, 18.9, G), (19.0, 20, C), (20, 21, C), (21, 22, G),
                   (22, 23, F), (23, 24, C), (24, 25, Am), (25, 26, G), (26, 27, F), (28.3, 30, C)]:
    add(music, t0, pad([hz(n) for n in ch] + [hz(ch[0] - 12)], t1 - t0 + 0.4), 0.22)

# magical bells in the happy ending
for i, n in enumerate([84, 79, 76, 72, 77, 81, 84, 88, 86, 84]):
    add(music, 22.0 + i * 0.5, bell(hz(n), 1.4), 0.12, 0.4 if i % 2 else -0.4)

# --------------------------------------------------------------- SFX cue --
cues = [
    (0.05, pop(220), 0.5, 0), (0.05, kick(), 0.7, 0),                    # musical beat on the circles
    (0.15, pop(700), 0.25, -0.3), (0.31, pop(820), 0.25, 0.3),
    (0.42, whoosh(0.7, 300, 5000, 0.6), 0.5, 0),                        # shrimp jumps in
    (1.25, pop(480), 0.7, 0),                                            # lands
    (1.75, whoosh(0.75, 400, 6000, 0.5), 0.45, 0.2),                     # 360 spin
    *[(t0, pop(900 + 120 * k), 0.18, (-1) ** k * 0.5) for k, t0 in enumerate([0.95, 1.12, 1.28, 1.42, 1.55, 1.66])],
    (2.45, whoosh(0.45, 600, 7000, 0.4), 0.35, 0),                       # MEET -> SHRIMPY morph
    (2.65, pop(640), 0.45, 0),
    (4.3, whoosh(0.75, 200, 3500, 0.7), 0.55, 0),                        # circle fills screen
    *[(5.2 + k * 0.37, bubble_pop(300 + 60 * (k % 5)), 0.22, ((k * 37) % 10 - 5) / 6) for k in range(12)],
    (7.2, whoosh(0.5, 800, 8000, 0.3), 0.4, 0),                          # letters scatter
    (8.2, bell(hz(91), 1.2), 0.12, 0.3), (8.35, bell(hz(96), 1.2), 0.1, -0.3),
    (9.35, bubble_pop(260), 0.6, 0), (9.4, whoosh(0.6, 200, 2500, 0.8), 0.5, 0),  # bubble zoom
    (10.55, alert(), 0.35, 0),                                           # cartoon alert
    *[(10.8 + k * 0.45, bubble_pop(500 + 90 * (k % 3)), 0.18, 0.3) for k in range(7)],
    (12.0, pop(300), 0.6, -0.2), (12.02, bubble_pop(700), 0.5, -0.2),    # shrimp notices
    (12.7, alert(), 0.3, 0),
    (14.58, whoosh(0.45, 600, 9000, 0.5), 0.7, 0),                       # whip-pan
    (15.3, whoosh(1.0, 300, 7000, 0.7), 0.65, -0.3),                     # rush
    (16.3, pop(560), 0.55, 0),                                           # grab
    (16.6, stretch(2.3), 0.45, 0),                                       # seaweed stretches
    (17.4, riser(1.5), 0.35, 0),
    (18.9, snap(), 0.8, 0), (18.9, kick(), 1.0, 0), (18.92, crash(), 0.7, 0),  # SNAP + impact
    *[(18.95 + k * 0.07, pop(700 + 140 * k), 0.3, (-1) ** k * 0.4) for k in range(5)],  # happy pops
    (21.1, whoosh(0.7, 400, 6000, 0.4), 0.5, 0),                         # particle burst
    *[(21.25 + k * 0.06, pop(500 + 70 * k), 0.15, ((k * 3) % 7 - 3) / 4) for k in range(9)],
    *[(22.15 + k * 0.09, bell(hz(n), 1.5), 0.16, (-1) ** k * 0.3) for k, n in enumerate([84, 88, 91, 96])],  # chime
    *[(24.85 + k * 0.09, bell(hz(n), 1.5), 0.16, (-1) ** k * 0.3) for k, n in enumerate([88, 91, 96, 100])],
    (26.5, whoosh(0.5, 800, 9000, 0.85), 0.45, 0),                       # white flash
    (27.0, pop(420), 0.5, 0),
    (27.45, pop(620), 0.45, -0.2), (27.85, pop(760), 0.45, 0.2),
    (28.3, kick(), 1.0, 0), (28.3, crash(1.7), 0.6, 0), (28.3, pop(520), 0.5, 0),  # final musical hit
    *[(28.3, bell(hz(n), 1.7), 0.14, p) for n, p in [(72, -0.3), (76, 0.3), (79, 0), (84, 0)]],
]
for t0, sig, g, pan in cues:
    add(sfx, t0, sig, g, pan)

# ---------------------------------------------------------------- mixing --
def reverb(x, secs=1.4, wet=0.2):
    n = int(secs * SR)
    t = np.arange(n) / SR
    out = x.copy()
    for ch in range(2):
        ir = rng.standard_normal(n) * np.exp(-t * 4.5)
        ir = onepole_lp(ir, 5000)
        ir /= np.sqrt(np.sum(ir ** 2))
        L = len(x) + n
        nfft = 1 << (L - 1).bit_length()
        y = np.fft.irfft(np.fft.rfft(x[:, ch], nfft) * np.fft.rfft(ir, nfft), nfft)[:len(x)]
        out[:, ch] += wet * y
    return out

# duck the music a touch under the big SFX moments
duck = np.ones(N)
for t0, depth, length in [(18.9, 0.5, 0.6), (28.3, 0.3, 0.5), (12.0, 0.3, 0.4)]:
    i0 = int(t0 * SR); n = int(length * SR)
    duck[i0:i0 + n] *= 1 - depth * np.exp(-np.arange(n) / (0.25 * SR))[: N - i0]
music = reverb(music, 1.6, 0.22) * duck[:, None]
sfx = reverb(sfx, 0.9, 0.12)

mix = music * 0.9 + sfx
t = np.arange(N) / SR
mix *= np.clip(t / 0.03, 0, 1)[:, None]
mix *= np.clip((DUR - t) / 1.2, 0, 1)[:, None] ** 1.5    # smooth ending
mix /= np.max(np.abs(mix)) + 1e-9
mix = np.tanh(mix * 1.6) / np.tanh(1.6) * 0.89          # gentle soft-clip master

path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'soundtrack.wav')
with wave.open(path, 'wb') as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((mix * 32767).astype('<i2').tobytes())
print('wrote', path)
