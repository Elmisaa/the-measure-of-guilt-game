#!/usr/bin/env python3
import wave
from pathlib import Path

import numpy as np
from scipy.signal import butter, lfilter

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "assets/audio/sfx"
rng = np.random.default_rng(42)


def t_(d):
    return np.arange(int(d * SR)) / SR


def lp(x, f, o=2):
    b, a = butter(o, f / (SR / 2))
    return lfilter(b, a, x)


def hp(x, f, o=2):
    b, a = butter(o, f / (SR / 2), btype="high")
    return lfilter(b, a, x)


def bp(x, lo, hi, o=2):
    b, a = butter(o, [lo / (SR / 2), hi / (SR / 2)], btype="band")
    return lfilter(b, a, x)


def save(name, x, peak=0.8):
    x = x / (np.abs(x).max() + 1e-9) * peak
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print(name, f"{len(x) / SR:.2f}s")


def click(d, f, decay):
    t = t_(d)
    return (np.sin(2 * np.pi * f * t) + 0.5 * bp(rng.standard_normal(len(t)), f, f * 3)) * np.exp(-t * decay)


def clock_tick():
    out = np.zeros(int(2.0 * SR))
    for k, f in ((0, 2400), (1, 2000)):
        c = click(0.05, f, 160) * 0.8 + lp(click(0.05, 600, 90), 900) * 0.4
        i = int(k * SR)
        out[i:i + len(c)] += c
    return lp(out, 6000)


def gunshot():
    t = t_(1.4)
    n = rng.standard_normal(len(t))
    crack = hp(n, 1500) * np.exp(-t * 60)
    boom = lp(n, 300, 4) * np.exp(-t * 7) * 3.0
    room = lp(n, 1200) * np.exp(-t * 3.5) * 0.35
    return np.tanh((crack + boom + room) * 2.5)


def bullet_clink():
    out = np.zeros(int(1.2 * SR))
    for at, amp in ((0.0, 1.0), (0.16, 0.5), (0.27, 0.3), (0.34, 0.15)):
        t = t_(0.5)
        r = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * d) for f, d in ((3100, 14), (5230, 20), (7420, 28)))
        i = int(at * SR)
        out[i:i + len(r)] += r * amp
    return out


def glass_shatter():
    t = t_(2.2)
    n = rng.standard_normal(len(t))
    hit = hp(n, 2500) * np.exp(-t * 18) * 1.5
    out = hit + lp(n, 400) * np.exp(-t * 20) * 1.2
    for _ in range(140):
        at = rng.uniform(0.02, 1.6) ** 1.6
        f = rng.uniform(2500, 9000)
        tt = t_(0.08)
        s = np.sin(2 * np.pi * f * tt) * np.exp(-tt * rng.uniform(40, 90)) * rng.uniform(0.1, 0.6) * np.exp(-at * 1.5)
        i = int(at * SR)
        out[i:i + len(s)] += s
    return out


def body_thud():
    t = t_(1.2)
    n = rng.standard_normal(len(t))
    return lp(n, 160, 4) * np.exp(-t * 9) * 3 + np.sin(2 * np.pi * 48 * t) * np.exp(-t * 7) + lp(n, 900) * np.exp(-t * 30) * 0.3


def metal_clang():
    t = t_(2.0)
    r = sum(np.sin(2 * np.pi * f * t + p) * np.exp(-t * d) for f, d, p in ((220, 1.6, 0), (417, 2.2, 1), (733, 3.0, 2), (1130, 4.0, 3), (1987, 6.0, 4)))
    return r + hp(rng.standard_normal(len(t)), 2000) * np.exp(-t * 50)


def bars_clang():
    out = np.zeros(int(2.4 * SR))
    for at in (0.0, 0.11, 0.19):
        m = metal_clang()[: int(1.8 * SR)] * (1.0 if at == 0 else 0.5)
        i = int(at * SR)
        out[i:i + len(m)] += m
    return lp(out, 5000)


def wind():
    d = 8.0
    t = t_(d)
    n = rng.standard_normal(len(t))
    gust = 0.55 + 0.45 * np.sin(2 * np.pi * t / d * 3 + 0.5) * np.sin(2 * np.pi * t / d)
    howl = bp(n, 350, 900) * gust + bp(n, 900, 2200) * gust ** 2 * 0.5
    k = int(0.4 * SR)
    howl[:k] = howl[:k] * np.linspace(0, 1, k) + howl[-k:] * np.linspace(1, 0, k)
    return howl[:-k]


def whisper():
    d = 2.6
    t = t_(d)
    out = np.zeros(len(t))
    for v in range(3):
        n = rng.standard_normal(len(t))
        syl = (np.sin(2 * np.pi * (2.2 + v * 0.7) * t + v) > 0.2).astype(float)
        syl = lp(syl, 12)
        voiced = bp(n, 500 + v * 300, 2600 + v * 400) * syl
        voiced += bp(n, 4000, 7000) * syl * 0.4
        out += np.roll(voiced, int(v * 0.07 * SR)) * (1.0 - v * 0.2)
    env = np.minimum(1, t / 0.2) * np.minimum(1, (d - t) / 0.5)
    return out * env


def mobile_ring():
    notes = [1318, 1568, 1760, 1568, 1318, 0, 1318, 1568, 2093, 1760]
    out = []
    for f in notes:
        t = t_(0.12)
        if f == 0:
            out.append(np.zeros(len(t)))
            continue
        sq = np.sign(np.sin(2 * np.pi * f * t)) * 0.5 + np.sin(2 * np.pi * f * 2 * t) * 0.2
        out.append(sq * np.minimum(1, t / 0.005) * np.minimum(1, (0.12 - t) / 0.01))
    ring = np.concatenate(out)
    return np.concatenate([ring, np.zeros(int(0.9 * SR))])


def voice_blip(f0, name, rough):
    t = t_(0.06)
    ph = 2 * np.pi * f0 * t
    x = np.sign(np.sin(ph)) * 0.4 + np.sin(ph * 2) * 0.3
    x += rough * rng.standard_normal(len(t)) * 0.3
    x = bp(x, 200, 2400)
    save(name, x * np.minimum(1, t / 0.004) * np.minimum(1, (0.06 - t) / 0.02), 0.5)


def murmur(f0, formants, dur, breath):
    t = t_(dur)
    f = f0 * (1.0 + 0.06 * np.sin(2 * np.pi * rng.uniform(2, 4) * t) - 0.08 * t / dur)
    ph = np.cumsum(f / SR)
    src = np.maximum(0, np.sin(2 * np.pi * ph)) ** 3
    src = np.diff(src, prepend=0.0) + breath * rng.standard_normal(len(t)) * 0.05
    out = np.zeros(len(t))
    for fc, bw, g in formants:
        out += bp(src, max(60, fc - bw), fc + bw) * g
    env = np.sin(np.pi * np.minimum(1, t / dur)) ** 1.5
    return lp(out * env, 2600)


def entity_drone():
    d = 9.0
    t = t_(d)
    sub = np.sin(2 * np.pi * 41 * t) * 0.6 + np.sin(2 * np.pi * 41.7 * t) * 0.5
    n = rng.standard_normal(len(t))
    grind = bp(n, 90, 260) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.23 * t)) * 0.8
    metal = sum(np.sin(2 * np.pi * f * t + p) for f, p in ((587, 0), (593.5, 1), (881, 2))) * 0.04 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.11 * t))
    x = sub + grind + metal
    k = int(0.5 * SR)
    x[:k] = x[:k] * np.linspace(0, 1, k) + x[-k:] * np.linspace(1, 0, k)
    return x[:-k]


def entity_voice():
    d = 2.8
    t = t_(d)
    out = np.zeros(len(t))
    for v, f0 in enumerate((55, 58.3, 82.4)):
        ph = np.cumsum((f0 * (1 + 0.02 * np.sin(2 * np.pi * 0.7 * t + v))) / SR)
        saw = 2 * (ph % 1.0) - 1
        voice = bp(saw, 200 + v * 150, 900 + v * 300) + bp(rng.standard_normal(len(t)), 300 + v * 200, 1400) * 0.25
        out += voice * (1 - v * 0.2)
    swell = (t / d) ** 2.2
    out = out * swell
    out = out[::-1] * 0.5 + out
    out += np.sin(2 * np.pi * 36 * t) * swell * 0.6
    tail = np.exp(-np.maximum(0, t - d * 0.85) * 12)
    return lp(out * tail, 3000)


def phone_ring():
    out = []
    for _ in range(2):
        t = t_(0.9)
        buzz = np.sin(2 * np.pi * 160 * t) * (np.sin(2 * np.pi * 22 * t) > 0) * 0.35
        out.append(lp(buzz + 0.15 * rng.standard_normal(len(t)) * (np.sin(2 * np.pi * 22 * t) > 0), 900))
        t2 = t_(0.08)
        out.append(np.zeros(int(0.15 * SR)))
    ring = []
    for _ in range(4):
        t = t_(0.06)
        tone = (np.sin(2 * np.pi * 1180 * t) + 0.5 * np.sin(2 * np.pi * 1180 * 2.01 * t))
        ring.append(tone * np.minimum(1, t / 0.004) * np.minimum(1, (0.06 - t) / 0.01))
        ring.append(np.zeros(int(0.04 * SR)))
    trill = np.concatenate(ring)
    seq = np.concatenate([np.concatenate(out), trill, np.zeros(int(0.25 * SR)), trill, np.zeros(int(0.6 * SR))])
    return seq


def soft_key(f, body, name):
    t = t_(0.09)
    n = rng.standard_normal(len(t))
    thock = np.sin(2 * np.pi * f * t) * np.exp(-t * 55) + 0.5 * np.sin(2 * np.pi * f * 1.5 * t) * np.exp(-t * 80)
    tick = bp(n, 1800, 4200) * np.exp(-t * 260) * 0.25
    felt = lp(n, 700) * np.exp(-t * 90) * body
    save(name, lp(thock + tick + felt, 3000), 0.45)


def punch():
    t = t_(0.5)
    n = rng.standard_normal(len(t))
    thud = lp(n, 220, 4) * np.exp(-t * 22) * 2.5 + np.sin(2 * np.pi * 70 * t) * np.exp(-t * 18)
    slap = bp(n, 900, 3500) * np.exp(-t * 90) * 0.6
    return np.tanh((thud + slap) * 1.6)


def main():
    save("clock_tick.wav", clock_tick(), 0.5)
    save("gunshot.wav", gunshot(), 0.9)
    save("bullet_clink.wav", bullet_clink(), 0.6)
    save("glass_shatter.wav", glass_shatter(), 0.85)
    save("body_thud.wav", body_thud(), 0.8)
    save("metal_clang.wav", metal_clang(), 0.7)
    save("bars_clang.wav", bars_clang(), 0.7)
    save("wind_loop.wav", wind(), 0.5)
    save("entity_whisper.wav", whisper(), 0.6)
    voice_blip(120, "blip_viktor.wav", 0.6)
    voice_blip(165, "blip_ivan.wav", 0.15)
    vowels = [((500, 120, 1.0), (1100, 200, 0.5), (2400, 300, 0.15)), ((380, 100, 1.0), (900, 180, 0.5), (2300, 300, 0.12)),
              ((600, 140, 1.0), (1000, 180, 0.4), (2500, 300, 0.1)), ((300, 90, 1.0), (2100, 250, 0.3), (2900, 300, 0.1))]
    for i, fm in enumerate(vowels, start=1):
        save(f"murmur_viktor_{i}.wav", murmur(102 + i * 3, fm, 0.13 + 0.02 * (i % 2), 1.2), 0.45)
    for i, fm in enumerate(vowels[:3], start=1):
        save(f"murmur_ivan_{i}.wav", murmur(138 + i * 4, fm, 0.11, 0.5), 0.45)
    for i, (f, b) in enumerate(((140, 0.5), (128, 0.6), (152, 0.45)), start=1):
        soft_key(f, b, f"key_viktor_{i}.wav")
    for i, (f, b) in enumerate(((205, 0.35), (190, 0.4), (220, 0.3)), start=1):
        soft_key(f, b, f"key_ivan_{i}.wav")
    save("punch.wav", punch(), 0.85)
    save("entity_drone.wav", entity_drone(), 0.6)
    save("entity_voice.wav", entity_voice(), 0.8)
    save("mobile_ring.wav", phone_ring(), 0.55)


if __name__ == "__main__":
    main()
