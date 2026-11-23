#!/usr/bin/env python3
from __future__ import annotations

import argparse
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050


def write(path: Path, samples: list[float]) -> None:
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples))
    print(f"ok {path} {len(samples)} samples")


def tone(freq: float, ms: float, decay: float, vol: float, glide: float = 0.0) -> list[float]:
    n = int(RATE * ms / 1000)
    out = []
    for i in range(n):
        f = freq * (1.0 + glide * i / n)
        env = min(1.0, i / (RATE * 0.002)) * math.exp(-decay * i / n)
        out.append(math.sin(2 * math.pi * f * i / RATE) * env * vol)
    return out


def noise(ms: float, decay: float, vol: float, seed: int) -> list[float]:
    rnd = random.Random(seed)
    n = int(RATE * ms / 1000)
    out, prev = [], 0.0
    for i in range(n):
        prev = prev * 0.6 + rnd.uniform(-1, 1) * 0.4
        out.append(prev * math.exp(-decay * i / n) * vol)
    return out


def mix(*parts: list[float]) -> list[float]:
    n = max(len(p) for p in parts)
    return [sum(p[i] for p in parts if i < len(p)) for i in range(n)]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", type=Path, required=True)
    args = ap.parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)
    write(args.out_dir / "ui_hover.wav", mix(tone(1400, 35, 7, 0.18), noise(12, 6, 0.08, 1)))
    write(args.out_dir / "ui_click.wav", mix(tone(220, 90, 6, 0.45, -0.25), tone(880, 30, 8, 0.12), noise(25, 7, 0.25, 2)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
