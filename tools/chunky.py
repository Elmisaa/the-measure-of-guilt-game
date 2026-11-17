#!/usr/bin/env python3
"""Make pixels N times bigger without changing colours: box-downscale by N, then
nearest-upscale by N. Alpha is premultiplied while averaging and hardened after.

  python3 tools/chunky.py in.png --factor 2 --out out.png
  python3 tools/chunky.py in.png --factor 2 --native-out small.png   # also save the 1/N image
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelize import harden_alpha  # noqa: E402


def chunky(img: Image.Image, f: int) -> Image.Image:
    img = img.convert("RGBA")
    w, h = max(1, round(img.width / f)), max(1, round(img.height / f))
    small = img.convert("RGBa").resize((w, h), Image.BOX).convert("RGBA")
    small = harden_alpha(small)
    return small.resize((w * f, h * f), Image.NEAREST)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("input", type=Path)
    ap.add_argument("--factor", type=int, default=2)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    out = chunky(Image.open(args.input), args.factor)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    out.save(args.out)
    print(f"ok {args.out} {out.width}x{out.height}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
