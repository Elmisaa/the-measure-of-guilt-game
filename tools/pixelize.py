#!/usr/bin/env python3
"""Turn an AI-generated "pixel-art-looking" image into a real grid-aligned sprite.

Steps: remove #FF00FF background -> split into frames -> crop each frame to its
content -> downscale (nearest) to fit --size -> place into a cell (bottom-center)
-> snap colors to art/palette.png -> assemble a one-row sprite sheet.

Examples:
  python3 tools/pixelize.py art/drafts/hero_idle/v1_b.png --size 32x32 --frames 4 \
      --out assets/characters/hero/hero_idle.png
  python3 tools/pixelize.py art/drafts/bg_forest/v1_a.png --size 320x180 --fit stretch \
      --keep-bg --out assets/backgrounds/forest.png
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import is_background, load_palette, nearest_color  # noqa: E402


def remove_background(img: Image.Image, tolerance: int) -> Image.Image:
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0 or is_background((r, g, b), tolerance):
                px[x, y] = (0, 0, 0, 0)
    return img


def harden_alpha(img: Image.Image, threshold: int = 128) -> Image.Image:
    """Pixel art has no semi-transparency: alpha becomes 0 or 255."""
    r, g, b, a = img.split()
    a = a.point(lambda v: 255 if v >= threshold else 0)
    return Image.merge("RGBA", (r, g, b, a))


def fit_into_cell(frame: Image.Image, cw: int, ch: int, fit: str, resample: str = "nearest") -> Image.Image:
    if fit == "stretch":
        return frame.resize((cw, ch), Image.BOX if resample == "box" else Image.NEAREST)
    bbox = frame.getbbox()
    if bbox is None:
        return Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    content = frame.crop(bbox)
    scale = min(cw / content.width, ch / content.height)
    nw, nh = max(1, round(content.width * scale)), max(1, round(content.height * scale))
    content = content.resize((nw, nh), Image.NEAREST)
    cell = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    cell.paste(content, ((cw - nw) // 2, ch - nh), content)  # bottom-center: feet on the ground
    return cell


def quantize(img: Image.Image, palette: list[tuple[int, int, int]]) -> Image.Image:
    if not palette:
        return img
    cache: dict[tuple[int, int, int], tuple[int, int, int]] = {}
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            key = (r, g, b)
            if key not in cache:
                cache[key] = nearest_color(key, palette)
            px[x, y] = (*cache[key], 255)
    return img


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("input", type=Path)
    ap.add_argument("--size", required=True, help="cell size WxH, e.g. 32x32")
    ap.add_argument("--frames", type=int, default=1, help="frames in a single row of the input")
    ap.add_argument("--fit", choices=["contain", "stretch"], default="contain",
                    help="contain: crop to content and keep aspect; stretch: center-crop to --size aspect, then resize (backgrounds)")
    ap.add_argument("--resample", choices=["nearest", "box"], default="nearest",
                    help="downscale filter for stretch: box averages colors (smoother for painted backgrounds)")
    ap.add_argument("--tolerance", type=int, default=60, help="magenta background tolerance")
    ap.add_argument("--keep-bg", action="store_true", help="do not remove background (opaque backgrounds)")
    ap.add_argument("--palette", type=Path, default=None, help="palette PNG (default art/palette.png)")
    ap.add_argument("--no-palette", action="store_true")
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    cw, ch = (int(v) for v in args.size.lower().split("x"))
    src = Image.open(args.input).convert("RGBA")
    if args.fit == "stretch" and args.frames == 1:
        # Center-crop to the target aspect first, so backgrounds are not distorted.
        target = cw / ch
        if src.width / src.height > target:
            nw = round(src.height * target)
            src = src.crop(((src.width - nw) // 2, 0, (src.width + nw) // 2, src.height))
        else:
            nh = round(src.width / target)
            src = src.crop((0, (src.height - nh) // 2, src.width, (src.height + nh) // 2))
    if not args.keep_bg:
        src = remove_background(src, args.tolerance)

    fw = src.width // args.frames
    frames = [src.crop((i * fw, 0, (i + 1) * fw, src.height)) for i in range(args.frames)]
    cells = [harden_alpha(fit_into_cell(f, cw, ch, args.fit, args.resample)) for f in frames]

    sheet = Image.new("RGBA", (cw * len(cells), ch), (0, 0, 0, 0))
    for i, cell in enumerate(cells):
        sheet.paste(cell, (i * cw, 0))

    palette = [] if args.no_palette else load_palette(args.palette)
    if not palette and not args.no_palette:
        print("warning: palette not found, colors not snapped", file=sys.stderr)
    sheet = quantize(sheet, palette)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.out)
    print(f"ok {args.out} {sheet.width}x{sheet.height} frames={len(cells)} cell={cw}x{ch}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
