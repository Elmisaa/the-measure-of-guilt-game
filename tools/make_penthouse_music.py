#!/usr/bin/env python3
import wave
from pathlib import Path

import numpy as np
from scipy.signal import butter, lfilter, fftconvolve

SR = 32000
OUT = Path(__file__).resolve().parent.parent / "assets/audio/music/penthouse_theme.wav"
rng = np.random.default_rng(7)
BAR = 8.0
CHORDS = [
    (38, [50, 53, 57]),
    (34, [46, 50, 53]),
    (31, [43, 46, 50]),
    (33, [45, 49, 52]),
    (38, [50, 53, 57]),
    (36, [48, 51, 55]),
    (34, [46, 50, 53]),
    (33, [45, 49, 52, 55]),
]


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def t_(d):
    return np.arange(int(d * SR)) / SR


def lp(x, f, o=2):
    b, a = butter(o, f / (SR / 2))
    return lfilter(b, a, x)


def pad_note(m, d):
    t = t_(d)
    x = np.zeros(len(t))
    for det in (-0.12, 0.0, 0.11):
        ph = np.cumsum(np.full(len(t), hz(m + det)) / SR)
        x += 2 * (ph % 1.0) - 1
    x = lp(x, 700 + 250 * np.sin(m))
    env = np.minimum(1, t / 2.5) * np.minimum(1, (d - t) / 2.5)
    return x * env * 0.05


def piano(m, d=4.0):
    t = t_(d)
    f = hz(m)
    x = sum(np.sin(2 * np.pi * f * k * (1 + 0.0004 * k * k) * t) * np.exp(-t * (1.2 + k * 0.9)) / k for k in range(1, 7))
    x *= np.minimum(1, t / 0.006)
    return lp(x, 3500) * 0.22


def glass(m, d=6.0):
    t = t_(d)
    x = np.sin(2 * np.pi * hz(m) * t) + np.sin(2 * np.pi * hz(m + 1) * t) * 0.7
    env = np.sin(np.pi * t / d) ** 2
    return x * env * 0.018


def reverb(x, secs=3.2, wet=0.45):
    n = int(secs * SR)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / SR * 2.2)
    ir = lp(ir, 3000)
    ir /= np.abs(ir).sum() ** 0.5 * 6
    y = fftconvolve(x, ir)[: len(x)]
    return x * (1 - wet) + y * wet * 3


def main():
    total = BAR * len(CHORDS)
    n = int(total * SR)
    mix = np.zeros(n + int(6 * SR))
    for i, (root, notes) in enumerate(CHORDS):
        at = int(i * BAR * SR)
        bass = pad_note(root, BAR + 2.5) * 1.6
        mix[at:at + len(bass)] += bass
        for m in notes:
            p = pad_note(m, BAR + 2.5)
            mix[at:at + len(p)] += p
        steps = [0.0, 2.0, 3.0, 5.0, 6.5]
        for k, s in enumerate(steps):
            if rng.random() < 0.3:
                continue
            m = notes[k % len(notes)] + 12 + (12 if k == 3 else 0)
            pn = piano(m)
            j = int((i * BAR + s) * SR)
            mix[j:j + len(pn)] += pn * (0.7 + 0.3 * rng.random())
        if i in (2, 5, 7):
            g = glass(notes[-1] + 24)
            j = int((i * BAR + 1.0) * SR)
            mix[j:j + len(g)] += g
    t = t_(len(mix) / SR)
    mix += lp(rng.standard_normal(len(mix)), 200) * 0.01
    mix += np.sin(2 * np.pi * hz(26) * t) * 0.05 * (0.6 + 0.4 * np.sin(2 * np.pi * t / 16))
    mix = reverb(mix)
    tail = mix[n:]
    body = mix[:n].copy()
    k = min(len(tail), int(5 * SR))
    body[:k] += tail[:k] * np.linspace(1, 0, k)
    body /= np.abs(body).max() + 1e-9
    body *= 0.8
    with wave.open(str(OUT), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((body * 32767).astype(np.int16).tobytes())
    print(OUT.name, f"{len(body) / SR:.1f}s")


if __name__ == "__main__":
    main()
