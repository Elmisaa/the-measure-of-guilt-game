#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelize import harden_alpha, remove_background


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
    ap.add_argument("--rows", type=int, default=1, help="rows (directions) stacked vertically; one gif per row")
    args = ap.parse_args()

    img = remove_background(Image.open(args.input), args.tolerance)
    band_h = img.height // args.rows
    rows: list[list[Image.Image]] = []
    for r in range(args.rows):
        band = img.crop((0, r * band_h, img.width, (r + 1) * band_h))
        crops = []
        for x0, x1 in find_frames(band, args.min_gap, 8):
            c = band.crop((x0, 0, x1, band.height))
            bb = c.getbbox()
            if bb:
                crops.append(c.crop((0, bb[1], c.width, bb[3])))
        rows.append(crops)
    allc = [c for r in rows for c in r]
    if not allc:
        print("no frames found", file=sys.stderr)
        return 1
    tallest = max(c.height for c in allc)
    k = args.height / tallest
    def shrink(c: Image.Image) -> Image.Image:
        return harden_alpha(c.convert("RGBa").resize((max(1, round(c.width * k)), max(1, round(c.height * k))), Image.BOX).convert("RGBA"))
    small_rows = [[shrink(c) for c in r] for r in rows]
    cw = max(s.width for r in small_rows for s in r) + 2
    ch = args.height
    ncol = max(len(r) for r in small_rows)
    sheet = Image.new("RGBA", (cw * ncol, ch * len(small_rows)), (0, 0, 0, 0))
    for ri, r in enumerate(small_rows):
        for i, s in enumerate(r):
            sheet.paste(s, (i * cw + (cw - s.width) // 2, ri * ch + ch - s.height), s)
    if args.scale > 1:
        sheet = sheet.resize((sheet.width * args.scale, sheet.height * args.scale), Image.NEAREST)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.out)
    print(f"ok {args.out} rows={[len(r) for r in small_rows]} cell={cw * args.scale}x{ch * args.scale}")
    if args.gif:
        cwS, chS = cw * args.scale, ch * args.scale
        for ri, r in enumerate(small_rows):
            idx = range(len(r))
            if args.frames:
                a, b = (int(v) for v in args.frames.split("-"))
                idx = range(a, min(b, len(r) - 1) + 1)
            frames = []
            for i in idx:
                f = Image.new("RGBA", (cwS + 40, chS + 20), (24, 28, 34, 255))
                f.alpha_composite(sheet.crop((i * cwS, ri * chS, (i + 1) * cwS, (ri + 1) * chS)), (20, 10))
                frames.append(f.convert("RGB").resize(((cwS + 40) * 3, (chS + 20) * 3), Image.NEAREST))
            g = args.gif if args.rows == 1 else args.gif.with_name(f"{args.gif.stem}_row{ri + 1}{args.gif.suffix}")
            g.parent.mkdir(parents=True, exist_ok=True)
            frames[0].save(g, save_all=True, append_images=frames[1:], duration=int(1000 / args.fps), loop=0)
            print(f"ok {g}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
