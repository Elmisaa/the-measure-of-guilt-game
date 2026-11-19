#!/usr/bin/env python3
"""Alexei's thinking sounds ("хм") — synthesized, 5 clearly different takes.

A low male voice hum: glottal pulses (jitter/shimmer) through nasal-murmur resonances, plus a breathy
"х" in front where it fits. Takes differ in contour, length and breath:
  hmm_1  "хм."      short, falling — dry remark
  hmm_2  "хм?"      rising — surprised / doubtful
  hmm_3  "мм-хм"    two humps — agreeing with himself
  hmm_4  "хммм..."  long, slow fall with a wobble — thinking it over
  hmm_5  "хм"       mostly breath through the nose — tired

python3 tools/make_hmm.py  ->  assets/audio/sfx/hmm_1..5.wav
"""
import wave
from pathlib import Path

import numpy as np
from scipy.signal import butter, lfilter, iirpeak, iirnotch

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "assets/audio/sfx"
rng = np.random.default_rng(1998)


def glottal(f0: np.ndarray) -> np.ndarray:
    """Pulse train following the f0 contour (Rosenberg-like pulses), with jitter and shimmer."""
    jitter = 1.0 + 0.012 * lfilter([1.0], [1.0, -0.995], rng.standard_normal(len(f0))) / 10.0
    phase = np.cumsum(f0 * jitter / SR) % 1.0
    open_q = 0.6
    p = np.where(phase < open_q, 0.5 - 0.5 * np.cos(np.pi * phase / open_q), np.cos(np.pi * (phase - open_q) / (2 * (1 - open_q))))
    p = np.clip(p, 0, None)
    src = np.diff(p, prepend=0.0)  # flow derivative: the buzz
    shimmer = 1.0 + 0.06 * lfilter([1.0], [1.0, -0.99], rng.standard_normal(len(f0))) / 8.0
    return src * shimmer


def resonate(x: np.ndarray, freqs: list, qs: list, gains: list) -> np.ndarray:
    out = np.zeros_like(x)
    for f, q, g in zip(freqs, qs, gains):
        b, a = iirpeak(f, q, SR)
        out += g * lfilter(b, a, x)
    return out


def hum(dur: float, f0_from: float, f0_to: float, mouth: float = 0.0, wobble: float = 0.0, breath: float = 0.08) -> np.ndarray:
    n = int(dur * SR)
    t = np.linspace(0, 1, n)
    f0 = f0_from + (f0_to - f0_from) * (t ** 1.3)
    if wobble:
        f0 *= 1.0 + wobble * np.sin(2 * np.pi * 4.5 * t * dur)
    src = glottal(f0)
    src += breath * rng.standard_normal(n) * 0.02
    # nasal murmur: strong low resonance, weak highs, a dip ~ 900 Hz (closed mouth)
    v = resonate(src, [260, 1050 + 500 * mouth, 2250], [3.0, 5.0, 6.0], [1.0, 0.18 + 0.3 * mouth, 0.10])
    b, a = iirnotch(900, 2.5, SR)
    v = lfilter(b, a, v)
    env = np.minimum(1.0, t * dur / 0.035) * np.minimum(1.0, (1 - t) * dur / 0.09)
    env *= 1.0 - 0.35 * t
    return v * env


def h_breath(dur: float, level: float = 0.5) -> np.ndarray:
    """The 'х': a soft velar/glottal fricative."""
    n = int(dur * SR)
    t = np.linspace(0, 1, n)
    b, a = butter(2, [700 / (SR / 2), 3200 / (SR / 2)], btype="band")
    x = lfilter(b, a, rng.standard_normal(n))
    env = np.sin(np.pi * t) ** 0.8
    return level * x * env * 0.15


def silence(dur: float) -> np.ndarray:
    return np.zeros(int(dur * SR))


def join(*parts: np.ndarray, overlap: float = 0.02) -> np.ndarray:
    out = parts[0]
    ov = int(overlap * SR)
    for p in parts[1:]:
        if len(out) > ov and len(p) > ov:
            mix = out[-ov:] + p[:ov]
            out = np.concatenate([out[:-ov], mix, p[ov:]])
        else:
            out = np.concatenate([out, p])
    return out


def room(x: np.ndarray) -> np.ndarray:
    """A touch of small-room reflection so it sits in the hall, then a gentle low-pass."""
    y = x.copy()
    for d, g in [(0.019, 0.22), (0.031, 0.14), (0.047, 0.08)]:
        k = int(d * SR)
        y[k:] += g * x[:-k]
    b, a = butter(2, 3800 / (SR / 2))
    return lfilter(b, a, y)


def save(name: str, x: np.ndarray, peak: float = 0.7) -> None:
    x = room(np.concatenate([silence(0.02), x, silence(0.12)]))
    x = x / (np.abs(x).max() + 1e-9) * peak
    data = (x * 32767).astype(np.int16)
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(name, f"{len(x) / SR:.2f}s")


def main() -> None:
    save("hmm_1.wav", join(h_breath(0.07, 0.6), hum(0.30, 128, 92)))
    save("hmm_2.wav", join(h_breath(0.06, 0.5), hum(0.42, 98, 146, mouth=0.15)))
    save("hmm_3.wav", join(hum(0.17, 112, 104), silence(0.07), h_breath(0.05, 0.4), hum(0.26, 124, 94), overlap=0.01), peak=0.65)
    save("hmm_4.wav", join(h_breath(0.09, 0.55), hum(0.85, 112, 86, wobble=0.025, breath=0.12)), peak=0.62)
    save("hmm_5.wav", join(h_breath(0.12, 0.9), hum(0.22, 104, 90, breath=0.5)), peak=0.5)


if __name__ == "__main__":
    main()
