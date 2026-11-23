#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import is_background, load_palette, nearest_color


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
    content = content.resize((nw, nh), Image.BOX if resample == "box" else Image.NEAREST)
    cell = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    cell.paste(content, ((cw - nw) // 2, ch - nh), content)
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


BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def grade(img: Image.Image, saturation: float, colors: int, dither: float) -> Image.Image:
    from PIL import ImageEnhance

    alpha = img.getchannel("A")
    rgb = img.convert("RGB")
    if saturation != 1.0:
        rgb = ImageEnhance.Color(rgb).enhance(saturation)
    if colors:
        pal_img = rgb.quantize(colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        if dither > 0:
            import numpy as np

            a = np.asarray(rgb, dtype=np.float32)
            h, w = a.shape[:2]
            m = (np.array(BAYER4, dtype=np.float32) + 0.5) / 16.0 - 0.5
            a += np.tile(m, (h // 4 + 1, w // 4 + 1))[:h, :w, None] * dither
            rgb = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
        rgb = rgb.quantize(palette=pal_img, dither=Image.Dither.NONE).convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


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
    ap.add_argument("--saturation", type=float, default=1.0, help="1.0 = as is, 0.8 = 20%% less saturated")
    ap.add_argument("--colors", type=int, default=0, help="reduce to N adaptive colors (used with --no-palette)")
    ap.add_argument("--dither", type=float, default=0.0, help="ordered Bayer dither strength, e.g. 24")
    ap.add_argument("--trim", action="store_true", help="single object: crop transparent margins")
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    cw, ch = (int(v) for v in args.size.lower().split("x"))
    src = Image.open(args.input).convert("RGBA")
    if args.fit == "stretch" and args.frames == 1:
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

    if args.saturation != 1.0 or args.colors or args.dither:
        sheet = grade(sheet, args.saturation, args.colors, args.dither)

    palette = [] if args.no_palette else load_palette(args.palette)
    if not palette and not args.no_palette:
        print("warning: palette not found, colors not snapped", file=sys.stderr)
    sheet = quantize(sheet, palette)

    if args.trim and args.frames == 1:
        bbox = sheet.getbbox()
        if bbox:
            sheet = sheet.crop(bbox)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.out)
    print(f"ok {args.out} {sheet.width}x{sheet.height} frames={len(cells)} cell={cw}x{ch}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
