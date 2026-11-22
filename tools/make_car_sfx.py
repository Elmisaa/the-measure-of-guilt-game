#!/usr/bin/env python3
"""Car sounds for the s02 drive cutscene (synthesized drafts).

  car_door.wav      heavy sedan door shut (thud + latch click + body rattle)
  engine_start.wav  starter cranks ~0.9 s, catches, revs once, settles to idle
  engine_idle.wav   ~4 s seamless idle loop (V8 burble, low)
  engine_off.wav    key off: idle winds down, a tick of cooling metal
  wipers.wav        one wiper sweep (rubber squeak + motor whirr)

python3 tools/make_car_sfx.py  ->  assets/audio/sfx/
"""
import wave
from pathlib import Path

import numpy as np
from scipy.signal import butter, lfilter

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "assets/audio/sfx"
rng = np.random.default_rng(98)


def lp(x, f, order=2):
    b, a = butter(order, f / (SR / 2))
    return lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = butter(order, [lo / (SR / 2), hi / (SR / 2)], btype="band")
    return lfilter(b, a, x)


def t_(dur):
    return np.arange(int(dur * SR)) / SR


def env(n, a, r):
    e = np.ones(n)
    ka, kr = int(a * SR), int(r * SR)
    if ka:
        e[:ka] = np.linspace(0, 1, ka)
    if kr:
        e[-kr:] *= np.linspace(1, 0, kr)
    return e


def engine(f_rpm, dur, rough=0.35):
    """V8-ish burble: firing pulses at rpm/60*4 Hz, uneven, through a low body resonance."""
    t = t_(dur)
    f = np.interp(t, np.linspace(0, dur, len(f_rpm)), f_rpm) / 60 * 4
    ph = np.cumsum(f / SR)
    pulse = np.maximum(0, np.sin(2 * np.pi * ph)) ** 6
    pulse *= 1 + rough * np.sin(2 * np.pi * ph / 4 + 1.3)  # uneven cylinders
    x = pulse + 0.15 * rng.standard_normal(len(t)) * pulse
    x = lp(x, 420) + 0.25 * bp(x, 600, 1600)
    return x


def save(name, x, peak=0.8):
    x = x / (np.abs(x).max() + 1e-9) * peak
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print(name, f"{len(x) / SR:.2f}s")


def car_door():
    n = int(0.9 * SR)
    t = t_(0.9)
    thud = lp(rng.standard_normal(n), 180, 4) * np.exp(-t * 18) * 3
    body = np.sin(2 * np.pi * 72 * t) * np.exp(-t * 14)
    click = np.zeros(n)
    k = int(0.012 * SR)
    click[k:k + 300] = bp(rng.standard_normal(300), 2500, 6000) * np.exp(-np.arange(300) / 60)
    rattle = bp(rng.standard_normal(n), 900, 3000) * np.exp(-t * 30) * 0.25
    return thud + body + click * 0.6 + rattle


def engine_start():
    crank_d = 0.95
    t = t_(crank_d)
    crank_f = 9 + 2 * np.sin(2 * np.pi * 1.3 * t)  # starter: ~9-11 compressions/s
    ph = np.cumsum(crank_f / SR)
    crank = (np.maximum(0, np.sin(2 * np.pi * ph)) ** 3)
    whine = np.sin(2 * np.pi * np.cumsum((380 + 40 * np.sin(2 * np.pi * 9 * t)) / SR)) * 0.12
    crank = lp(crank + 0.2 * rng.standard_normal(len(t)) * crank, 900) + whine
    rpm = [300, 1900, 2200, 1400, 850, 750, 720, 720]
    run = engine(rpm, 2.6)
    run *= env(len(run), 0.02, 0.5)
    return np.concatenate([crank * 0.7, run])


def engine_idle():
    dur = 4.0
    x = engine([720] * 8, dur + 0.5, rough=0.3)[int(0.25 * SR):int(0.25 * SR) + int(dur * SR)]
    k = int(0.15 * SR)  # crossfade the ends for a seamless loop
    x[:k] = x[:k] * np.linspace(0, 1, k) + x[-k:] * np.linspace(1, 0, k)
    return x[:-k]


def engine_off():
    run = engine([720, 650, 420, 200, 60], 1.3, rough=0.6) * env(int(1.3 * SR), 0.0, 0.6)
    tail = np.zeros(int(1.2 * SR))
    for at in (0.35, 0.9):
        k = int(at * SR)
        tail[k:k + 400] += bp(rng.standard_normal(400), 3000, 7000) * np.exp(-np.arange(400) / 50) * 0.15
    return np.concatenate([run, tail])


def wipers():
    d = 0.9
    t = t_(d)
    motor = bp(rng.standard_normal(len(t)), 120, 400) * 0.3 + 0.2 * np.sin(2 * np.pi * 110 * t)
    sweep = np.sin(np.pi * t / d)
    squeak = np.sin(2 * np.pi * np.cumsum((900 + 500 * sweep) / SR)) * (sweep ** 4) * 0.12
    rub = bp(rng.standard_normal(len(t)), 1500, 4000) * sweep * 0.15
    return (motor + squeak + rub) * env(len(t), 0.05, 0.15)


def main():
    save("car_door.wav", car_door())
    save("engine_start.wav", engine_start(), 0.75)
    save("engine_idle.wav", engine_idle(), 0.6)
    save("engine_off.wav", engine_off(), 0.7)
    save("wipers.wav", wipers(), 0.5)


if __name__ == "__main__":
    main()
