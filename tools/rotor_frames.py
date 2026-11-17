#!/usr/bin/env python3
"""Make a spin animation sheet from a top-down rotor (fan) image on magenta.

Rotates the hi-res source, squashes it vertically for perspective, box-downscales
to the target width and hardens alpha. Rotational symmetry of N blades means one
loop only needs 360/N degrees.

  python3 tools/rotor_frames.py art/drafts/fan/rotor_v1_a.png --blades 4 --frames 8 \
      --width 64 --squash 0.28 --out assets/fx/s01/fan_spin.png
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelize import harden_alpha, remove_background  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("input", type=Path)
    ap.add_argument("--blades", type=int, required=True)
    ap.add_argument("--frames", type=int, default=8)
    ap.add_argument("--width", type=int, required=True, help="frame width in base pixels")
    ap.add_argument("--squash", type=float, default=0.3, help="vertical scale for perspective")
    ap.add_argument("--tolerance", type=int, default=60)
    ap.add_argument("--scale", type=int, default=1, help="pixel size: render at width/scale, then nearest-upscale")
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    src = remove_background(Image.open(args.input), args.tolerance)
    src = src.crop(src.getbbox())
    side = max(src.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(src, ((side - src.width) // 2, (side - src.height) // 2))
    w = args.width // args.scale
    h = max(1, round(w * args.squash))
    step = 360.0 / args.blades / args.frames
    frames = []
    for i in range(args.frames):
        rot = sq.rotate(-i * step, resample=Image.BICUBIC)
        frames.append(harden_alpha(rot.resize((w, h), Image.BOX)))
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * w, 0))
    if args.scale > 1:
        sheet = sheet.resize((sheet.width * args.scale, sheet.height * args.scale), Image.NEAREST)
        w, h = w * args.scale, h * args.scale
    args.out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.out)
    print(f"ok {args.out} {sheet.width}x{sheet.height} frames={len(frames)} cell={w}x{h}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
