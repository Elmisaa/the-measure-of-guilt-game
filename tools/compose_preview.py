#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageFilter


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("bg", type=Path)
    ap.add_argument("sprites", nargs="+", help="path@x,y")
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--scale", type=int, default=3)
    ap.add_argument("--shadow", action="store_true")
    args = ap.parse_args()

    canvas = Image.open(args.bg).convert("RGBA")
    for spec in args.sprites:
        path, pos = spec.rsplit("@", 1)
        x, y = (int(v) for v in pos.split(","))
        spr = Image.open(path).convert("RGBA")
        if args.shadow:
            alpha = spr.getchannel("A").filter(ImageFilter.GaussianBlur(2))
            sh = Image.new("RGBA", spr.size, (0, 0, 0, 0))
            sh.putalpha(alpha.point(lambda v: v * 110 // 255))
            canvas.alpha_composite(sh, (x + 3, y + 4))
        canvas.alpha_composite(spr, (x, y))
    out = canvas.resize((canvas.width * args.scale, canvas.height * args.scale), Image.NEAREST)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    out.save(args.out)
    print(f"ok {args.out} {out.width}x{out.height}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
