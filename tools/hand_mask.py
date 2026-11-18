#!/usr/bin/env python3
"""Build an alpha mask of a warm-coloured object (hand + pencil) inside a box of a frame.

Pixels whose red clearly exceeds blue and that are not too dark count as the object;
an optional exclude box (e.g. the mug) is left out. The mask follows the frame's pixel grid.

  python3 tools/hand_mask.py assets/backgrounds/s00/cut_coffee.png --box 280,140,346,206 \
      --exclude 320,200,400,290 --out assets/fx/s00/hand_mask.png
"""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("frame", type=Path)
    ap.add_argument("--box", required=True, help="x0,y0,x1,y1")
    ap.add_argument("--exclude", default="", help="x0,y0,x1,y1 to leave out")
    ap.add_argument("--min-warm", type=int, default=18, help="r - b threshold")
    ap.add_argument("--min-luma", type=int, default=40)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    img = Image.open(args.frame).convert("RGB")
    x0, y0, x1, y1 = (int(v) for v in args.box.split(","))
    ex = tuple(int(v) for v in args.exclude.split(",")) if args.exclude else None
    mask = Image.new("RGBA", img.size, (0, 0, 0, 0))
    px, mp = img.load(), mask.load()
    n = 0
    for y in range(y0, y1):
        for x in range(x0, x1):
            if ex and ex[0] <= x < ex[2] and ex[1] <= y < ex[3]:
                continue
            r, g, b = px[x, y]
            if r - b >= args.min_warm and (r * 299 + g * 587 + b * 114) // 1000 >= args.min_luma:
                mp[x, y] = (255, 255, 255, 255)
                n += 1
    args.out.parent.mkdir(parents=True, exist_ok=True)
    mask.save(args.out)
    print(f"ok {args.out} pixels={n}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
