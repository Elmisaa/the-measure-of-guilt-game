#!/usr/bin/env python3
"""Slice a generated sprite row (on #FF00FF) into frames, pixelize and assemble.

Frames are found by gaps of empty columns, so uneven spacing from the generator
is fine. All frames get one common scale (so the character keeps its height),
are bottom-aligned in equal cells and box-downscaled; optional integer upscale.

  python3 tools/slice_sheet.py art/drafts/walk_probe/alexei_v1_a.png --height 40 --scale 2 \
      --out assets/characters/alexei/walk.png --gif art/previews/alexei_walk.gif --fps 10
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelize import harden_alpha, remove_background  # noqa: E402


def find_frames(img: Image.Image, min_gap: int, min_w: int) -> list[tuple[int, int]]:
    a = img.getchannel("A")
    w, h = img.size
    cols = [any(a.getpixel((x, y)) for y in range(0, h, 2)) for x in range(w)]
    spans, start, gap = [], None, 0
    for x, on in enumerate(cols + [False] * (min_gap + 1)):
        if on:
            if start is None:
                start = x
            gap = 0
        elif start is not None:
            gap += 1
            if gap > min_gap:
                end = x - gap + 1
                if end - start >= min_w:
                    spans.append((start, end))
                start, gap = None, 0
    return spans


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("input", type=Path)
    ap.add_argument("--height", type=int, required=True, help="character height in art pixels")
    ap.add_argument("--scale", type=int, default=2)
    ap.add_argument("--tolerance", type=int, default=70)
    ap.add_argument("--min-gap", type=int, default=6)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--gif", type=Path)
    ap.add_argument("--fps", type=int, default=10)
    ap.add_argument("--frames", default="", help="subset for the gif, e.g. 2-9")
    args = ap.parse_args()

    img = remove_background(Image.open(args.input), args.tolerance)
    spans = find_frames(img, args.min_gap, 8)
    crops = []
    for x0, x1 in spans:
        c = img.crop((x0, 0, x1, img.height))
        bb = c.getbbox()
        if bb:
            crops.append(c.crop((0, bb[1], c.width, bb[3])))
    if not crops:
        print("no frames found", file=sys.stderr)
        return 1
    tallest = max(c.height for c in crops)
    k = args.height / tallest
    small = [harden_alpha(c.convert("RGBa").resize((max(1, round(c.width * k)), max(1, round(c.height * k))), Image.BOX).convert("RGBA")) for c in crops]
    cw = max(s.width for s in small) + 2
    ch = args.height
    sheet = Image.new("RGBA", (cw * len(small), ch), (0, 0, 0, 0))
    for i, s in enumerate(small):
        sheet.paste(s, (i * cw + (cw - s.width) // 2, ch - s.height), s)
    if args.scale > 1:
        sheet = sheet.resize((sheet.width * args.scale, sheet.height * args.scale), Image.NEAREST)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.out)
    print(f"ok {args.out} frames={len(small)} cell={cw * args.scale}x{ch * args.scale} heights={[c.height for c in crops]}")
    if args.gif:
        cwS, chS = cw * args.scale, ch * args.scale
        idx = range(len(small))
        if args.frames:
            a, b = (int(v) for v in args.frames.split("-"))
            idx = range(a, b + 1)
        frames = []
        for i in idx:
            f = Image.new("RGBA", (cwS + 40, chS + 20), (24, 28, 34, 255))
            cell = sheet.crop((i * cwS, 0, (i + 1) * cwS, chS))
            f.alpha_composite(cell, (20, 10))
            frames.append(f.convert("RGB").resize(((cwS + 40) * 3, (chS + 20) * 3), Image.NEAREST))
        args.gif.parent.mkdir(parents=True, exist_ok=True)
        frames[0].save(args.gif, save_all=True, append_images=frames[1:], duration=int(1000 / args.fps), loop=0)
        print(f"ok {args.gif}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
