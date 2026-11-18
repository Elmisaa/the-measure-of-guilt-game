#!/usr/bin/env python3
"""Draft sound effects for the phone call scene (placeholders until real recordings).

  python3 tools/make_sfx.py --out-dir assets/audio/sfx

pickup.wav     — handset lifted off the cradle: plastic click + cradle spring + rustle
knock.wav      — heavy muffled knock on a door, heard through a phone line
hangup.wav     — receiver dropped / line cut: clatter + click
dialtone.wav   — one cycle of a long monotonous tone + pause (loop it)
blip_phone.wav — voice blip "through the phone": band-limited, buzzy
paper_rustle.wav — soft rustle of a sheet (hover)
page_flip.wav  — page turning: whoosh + soft snap (open a document)
"""
from __future__ import annotations

import argparse
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050


def write(path: Path, s: list[float]) -> None:
    peak = max(1e-6, max(abs(v) for v in s))
    if peak > 1.0:
        s = [v / peak for v in s]
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(v * 32767)) for v in s))
    print(f"ok {path} {len(s) / RATE:.2f}s")


def silence(ms: float) -> list[float]:
    return [0.0] * int(RATE * ms / 1000)


def tone(freq: float, ms: float, vol: float, decay: float = 0.0, attack_ms: float = 2.0, glide: float = 0.0) -> list[float]:
    n = int(RATE * ms / 1000)
    a = max(1, int(RATE * attack_ms / 1000))
    out = []
    ph = 0.0
    for i in range(n):
        f = freq * (1.0 + glide * i / n)
        ph += 2 * math.pi * f / RATE
        env = min(1.0, i / a) * (math.exp(-decay * i / n) if decay else 1.0)
        out.append(math.sin(ph) * env * vol)
    return out


def noise(ms: float, vol: float, decay: float, smooth: float, seed: int) -> list[float]:
    rnd = random.Random(seed)
    n = int(RATE * ms / 1000)
    out, p = [], 0.0
    for i in range(n):
        p = p * smooth + rnd.uniform(-1, 1) * (1 - smooth)
        out.append(p * vol * math.exp(-decay * i / n))
    return out


def mix(*parts: tuple[int, list[float]]) -> list[float]:
    n = max(off + len(p) for off, p in parts)
    out = [0.0] * n
    for off, p in parts:
        for i, v in enumerate(p):
            out[off + i] += v
    return out


def ms(x: float) -> int:
    return int(RATE * x / 1000)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", type=Path, required=True)
    o = ap.parse_args().out_dir
    o.mkdir(parents=True, exist_ok=True)

    click = lambda seed: mix((0, noise(12, 0.9, 8, 0.2, seed)), (0, tone(2200, 15, 0.3, 9)))
    write(o / "pickup.wav", mix((0, click(1)), (ms(40), tone(140, 120, 0.35, 6)), (ms(60), noise(350, 0.18, 3, 0.85, 2)), (ms(420), click(3))))

    def thud(seed: int) -> list[float]:
        return mix((0, tone(70, 260, 0.9, 7, 1, -0.3)), (0, noise(120, 0.6, 9, 0.93, seed)), (0, tone(160, 80, 0.3, 10)))
    write(o / "knock.wav", mix((0, thud(4)), (ms(230), thud(5)), (ms(470), thud(6))))

    write(o / "hangup.wav", mix((0, noise(40, 0.9, 6, 0.3, 7)), (0, tone(900, 60, 0.3, 8)), (ms(70), noise(220, 0.5, 5, 0.6, 8)), (ms(320), click(9)), (ms(330), tone(120, 120, 0.4, 7))))

    beep = [v * (0.6 + 0.4 * math.sin(2 * math.pi * 3 * i / RATE)) for i, v in enumerate(mix((0, tone(425, 1200, 0.35)), (0, tone(850, 1200, 0.06))))]
    write(o / "dialtone.wav", beep + silence(1000))

    n = ms(55)
    buzz = []
    for i in range(n):
        t = i / RATE
        env = min(1.0, i / ms(4)) * math.exp(-4.5 * i / n)
        sq = 1.0 if math.sin(2 * math.pi * 300 * (1 - 0.08 * i / n) * t) > 0 else -1.0
        buzz.append((0.35 * sq + 0.5 * math.sin(2 * math.pi * 900 * t)) * env * 0.45)
    write(o / "blip_phone.wav", mix((0, buzz), (0, noise(55, 0.08, 3, 0.1, 10))))

    # paper: bright crackly noise (low smoothing) shaped into a few short grains
    def grain(ms_len: float, vol: float, seed: int) -> list[float]:
        g = noise(ms_len, vol, 0.0, 0.25, seed)
        n = len(g)
        return [v * math.sin(math.pi * i / n) for i, v in enumerate(g)]
    rnd = random.Random(11)
    parts = [(ms(rnd.uniform(0, 160)), grain(rnd.uniform(25, 70), rnd.uniform(0.15, 0.35), 20 + k)) for k in range(7)]
    write(o / "paper_rustle.wav", mix(*parts))
    whoosh = noise(260, 0.5, 0.0, 0.55, 30)
    whoosh = [v * math.sin(math.pi * i / len(whoosh)) ** 2 for i, v in enumerate(whoosh)]
    snap = mix((0, noise(30, 0.7, 6, 0.2, 31)), (0, tone(180, 60, 0.25, 8)))
    # CRT power-on: thump + degauss hum + high whine settling
    whine = tone(15000 / 2.0, 900, 0.05, 2)  # aliased to an audible high tone at 22 kHz
    write(o / "crt_on.wav", mix((0, tone(55, 300, 0.7, 5, 1)), (0, noise(80, 0.5, 8, 0.4, 40)), (ms(40), tone(60, 700, 0.25, 3, 30, 0.1)), (ms(60), whine)))
    write(o / "key_tick.wav", mix((0, noise(14, 0.6, 9, 0.15, 41)), (0, tone(1800, 12, 0.15, 9))))
    write(o / "page_flip.wav", mix((0, grain(60, 0.3, 32)), (ms(30), whoosh), (ms(250), snap), (ms(270), grain(50, 0.2, 33))))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
