#!/usr/bin/env python3
"""Cutscene frame -> game frame: scale to cover WxH (box filter), centre-crop, then chunky pixels (factor N).

  python3 tools/frame_px.py in.png --size 680x290 --factor 4 --out out.png [--sat 0.6] [--cool 0.15]
--sat: saturation multiplier (1 = as generated); --cool: blend toward the game's cold night blue (keeps brightness).
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageEnhance

sys.path.insert(0, str(Path(__file__).resolve().parent))
from chunky import chunky  # noqa: E402


def cover(img: Image.Image, w: int, h: int) -> Image.Image:
    r = max(w / img.width, h / img.height)
    img = img.resize((max(w, round(img.width * r)), max(h, round(img.height * r))), Image.BOX)
    x, y = (img.width - w) // 2, (img.height - h) // 2
    return img.crop((x, y, x + w, y + h))


NIGHT = (70, 88, 120)


def grade(img: Image.Image, sat: float, cool: float) -> Image.Image:
    if sat != 1.0:
        img = ImageEnhance.Color(img).enhance(sat)
    if cool > 0:
        lum = img.convert("L")
        tint = Image.merge("RGB", [lum.point(lambda v, c=c: min(255, v * c / 100)) for c in NIGHT])
        img = Image.blend(img, tint, cool)
    return img


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("input", type=Path)
    ap.add_argument("--size", required=True, help="WxH after pixelization")
    ap.add_argument("--factor", type=int, default=4)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--sat", type=float, default=1.0)
    ap.add_argument("--cool", type=float, default=0.0)
    a = ap.parse_args()
    w, h = (int(v) for v in a.size.lower().split("x"))
    img = grade(cover(Image.open(a.input).convert("RGB"), w, h), a.sat, a.cool)
    out = chunky(img, a.factor).convert("RGB").crop((0, 0, w, h))
    a.out.parent.mkdir(parents=True, exist_ok=True)
    out.save(a.out)
    print(a.out, out.size)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
