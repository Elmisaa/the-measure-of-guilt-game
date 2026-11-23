#!/usr/bin/env python3

def crt_off() -> None:
    import wave
    import numpy as np
    sr = 44100
    n = int(0.55 * sr)
    t = np.arange(n) / sr
    rng = np.random.default_rng(7)
    whine = np.sin(2 * np.pi * np.cumsum(15600 * np.exp(-t * 6.0) + 400) / sr) * np.exp(-t * 7.0) * 0.18
    crackle = rng.standard_normal(n) * np.exp(-t * 30.0) * 0.5
    thump = np.sin(2 * np.pi * 55 * t) * np.exp(-t * 18.0) * 0.7
    x = whine + crackle + thump
    x = x / np.abs(x).max() * 0.6
    out = __import__("pathlib").Path(__file__).resolve().parent.parent / "assets/audio/sfx/crt_off.wav"
    with wave.open(str(out), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print(out.name)


if __name__ == "__main__":
    crt_off()
