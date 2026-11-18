#!/usr/bin/env python3
"""Synthesize a short soft "voice blip" for speech without voice acting.

A low sine with a touch of 2nd/3rd harmonic, fast attack and quick decay.
The game plays it with random pitch while text is typed.

  python3 tools/make_blip.py --freq 240 --ms 55 --out assets/audio/sfx/voice_blip.wav
"""
from __future__ import annotations

import argparse
import math
import struct
import wave
from pathlib import Path


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--freq", type=float, default=240.0)
    ap.add_argument("--ms", type=float, default=55.0)
    ap.add_argument("--rate", type=int, default=22050)
    ap.add_argument("--volume", type=float, default=0.5)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    n = int(args.rate * args.ms / 1000.0)
    attack = int(args.rate * 0.004)
    frames = bytearray()
    for i in range(n):
        t = i / args.rate
        env = min(1.0, i / max(1, attack)) * math.exp(-5.0 * i / n)
        f = args.freq * (1.0 - 0.08 * i / n)  # slight downward glide, like a syllable
        s = math.sin(2 * math.pi * f * t) + 0.25 * math.sin(4 * math.pi * f * t) + 0.1 * math.sin(6 * math.pi * f * t)
        frames += struct.pack("<h", int(max(-1.0, min(1.0, s / 1.35 * env * args.volume)) * 32767))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(args.out), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(args.rate)
        w.writeframes(bytes(frames))
    print(f"ok {args.out} {n} samples")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
