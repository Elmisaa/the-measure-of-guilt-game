#!/usr/bin/env python3
import math, random, struct, wave
from pathlib import Path

SR = 22050
rnd = random.Random(1998)


def write(path: str, s: list[float]) -> None:
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    peak = max(1e-6, max(abs(v) for v in s))
    g = 0.85 / peak
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v * g)) * 32767)) for v in s))


def hiss(n: int, vol: float) -> list[float]:
    out = []; lp = 0.0
    for _ in range(n):
        lp += 0.35 * (rnd.uniform(-1, 1) - lp); out.append(lp * vol)
    return out


def add(dst: list[float], src: list[float], at: int) -> None:
    for i, v in enumerate(src):
        if 0 <= at + i < len(dst):
            dst[at + i] += v


def note(freq: float, sec: float, vol: float, kind: str = "box") -> list[float]:
    n = int(sec * SR); out = []
    for i in range(n):
        t = i / SR
        env = min(1.0, t / 0.005) * math.exp(-t * (3.0 if kind == "box" else 0.0))
        if kind == "beep":
            env = min(1.0, t / 0.004, (sec - t) / 0.004)
        f = freq * (1 + 0.004 * math.sin(2 * math.pi * 5.5 * t))
        v = math.sin(2 * math.pi * f * t)
        if kind == "box":
            v += 0.35 * math.sin(2 * math.pi * f * 2.01 * t) + 0.15 * math.sin(2 * math.pi * f * 3.98 * t)
        out.append(v * env * vol)
    return out


def strange() -> list[float]:
    L = int(48 * SR)
    s = hiss(L, 0.22)
    for i in range(L):
        t = i / SR
        swell = 0.75 + 0.25 * math.sin(2 * math.pi * t / 12.0) * math.sin(2 * math.pi * t / 4.0)
        s[i] = s[i] * swell + 0.035 * math.sin(2 * math.pi * (1210 + 6 * math.sin(2 * math.pi * t / 8.0)) * t)
    for _ in range(40):
        at = rnd.randrange(L - 400)
        for j in range(rnd.randrange(60, 300)):
            s[at + j] += rnd.uniform(-0.5, 0.5) * math.exp(-j / 80)
    for i in range(int(0.3 * SR)):
        k = i / (0.3 * SR); s[i] *= k; s[-1 - i] *= k
    return s


def static_sweep() -> list[float]:
    n = int(0.7 * SR); s = hiss(n, 0.6)
    for i in range(n):
        t = i / SR
        s[i] += 0.25 * math.sin(2 * math.pi * (300 + 2400 * t) * t) * (1 - t / 0.7)
        s[i] *= min(1.0, t / 0.03, (0.7 - t) / 0.12)
    return s


def click() -> list[float]:
    n = int(0.06 * SR); return [rnd.uniform(-1, 1) * math.exp(-i / (0.004 * SR)) + 0.4 * math.sin(2 * math.pi * 1800 * i / SR) * math.exp(-i / (0.01 * SR)) for i in range(n)]


def breath() -> list[float]:
    out = []
    for k, (dur, vol) in enumerate(((0.45, 0.7), (0.6, 1.0))):
        n = int(dur * SR); lp = 0.0; bp = 0.0
        for i in range(n):
            t = i / n
            lp += 0.12 * (rnd.uniform(-1, 1) - lp); bp += 0.5 * (lp - bp)
            out.append((lp - bp * 0.6) * vol * math.sin(math.pi * t) ** 1.5)
        out += [0.0] * int(0.08 * SR)
    return out


def pour() -> list[float]:
    n = int(1.4 * SR); out = []; lp = 0.0
    for i in range(n):
        t = i / SR
        lp += (0.25 + 0.15 * math.sin(2 * math.pi * 7 * t)) * (rnd.uniform(-1, 1) - lp)
        gl = 0.3 * math.sin(2 * math.pi * (400 + 500 * t) * t) * (rnd.random() < 0.02)
        out.append((lp + gl) * min(1.0, t / 0.08, (1.4 - t) / 0.25))
    return out


def gulp() -> list[float]:
    out = []
    for f0 in (180.0, 150.0):
        n = int(0.18 * SR)
        out += [math.sin(2 * math.pi * (f0 - 300 * i / SR) * i / SR) * math.sin(math.pi * i / n) * 0.8 for i in range(n)]
        out += [0.0] * int(0.25 * SR)
    return out


def water() -> list[float]:
    n = int(2.2 * SR); out = []; lp = 0.0; hp = 0.0
    for i in range(n):
        t = i / SR
        x = rnd.uniform(-1, 1); lp += 0.5 * (x - lp); hp = lp - 0.6 * hp
        drip = 0.4 * math.sin(2 * math.pi * (900 - 2000 * (t % 0.23)) * t) * math.exp(-(t % 0.23) * 40) if t > 1.5 else 0.0
        out.append((hp * 0.7 * min(1.0, t / 0.1, max(0.0, (1.5 - t) / 0.2) + 0.0) if t < 1.5 else 0.0) + drip)
    return out


def door() -> list[float]:
    out = [rnd.uniform(-1, 1) * math.exp(-i / (0.003 * SR)) for i in range(int(0.04 * SR))]
    n = int(0.45 * SR)
    for i in range(n):
        t = i / SR
        f = 180 + 120 * math.sin(2 * math.pi * 3 * t)
        out.append(0.35 * math.sin(2 * math.pi * f * t) * (1 if rnd.random() > 0.3 else 0.4) * math.sin(math.pi * i / n))
    out += [0.8 * math.sin(2 * math.pi * 70 * i / SR) * math.exp(-i / (0.03 * SR)) + 0.2 * rnd.uniform(-1, 1) * math.exp(-i / (0.01 * SR)) for i in range(int(0.25 * SR))]
    return out


write("assets/audio/sfx/door.wav", door())
write("assets/audio/sfx/water.wav", water())
write("assets/audio/sfx/radio_click.wav", click())
write("assets/audio/sfx/breath.wav", breath())
write("assets/audio/sfx/pour.wav", pour())
write("assets/audio/sfx/gulp.wav", gulp())
write("art/sources/audio/strange_station.wav", strange())
write("art/sources/audio/tune_static.wav", static_sweep())
print("ok")
