#!/usr/bin/env python3
"""Pack all reference images of a scene into ONE compact contact sheet for Claude.

  python3 tools/ref_sheet.py <scene> [--tile 360] [--cols 4]

Reads art/refs/<scene>/ (png/jpg/jpeg/webp/gif, any size), fits each image into a
--tile square (keeping aspect), captions it with a number + filename, and saves
art/refs/<scene>/_sheet.jpg. Claude opens only this sheet (one image instead of
many full-size files), and reads notes.md next to it.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import ROOT  # noqa: E402

EXTS = {".png", ".jpg", ".jpeg", ".webp", ".gif"}
CAPTION_H = 16
PAD = 6


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("scene")
    ap.add_argument("--tile", type=int, default=360)
    ap.add_argument("--cols", type=int, default=4)
    args = ap.parse_args()

    folder = ROOT / "art" / "refs" / args.scene
    files = sorted(f for f in folder.glob("*") if f.suffix.lower() in EXTS and not f.name.startswith("_"))
    if not files:
        print(f"no reference images in {folder.relative_to(ROOT)}")
        return 1

    t = args.tile
    cols = min(args.cols, len(files))
    rows = (len(files) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (t + PAD) + PAD, rows * (t + CAPTION_H + PAD) + PAD), (32, 32, 32))
    draw = ImageDraw.Draw(sheet)
    for i, f in enumerate(files):
        img = Image.open(f).convert("RGB")
        scale = min(t / img.width, t / img.height)
        # Upscaling small pixel art: keep it crisp; downscaling photos: smooth.
        method = Image.NEAREST if scale >= 1 else Image.LANCZOS
        img = img.resize((max(1, int(img.width * scale)), max(1, int(img.height * scale))), method)
        x = PAD + (i % cols) * (t + PAD)
        y = PAD + (i // cols) * (t + CAPTION_H + PAD)
        draw.text((x, y), f"{i + 1}. {f.name}"[: t // 6], fill=(230, 230, 230))
        sheet.paste(img, (x + (t - img.width) // 2, y + CAPTION_H + (t - img.height) // 2))

    out = folder / "_sheet.jpg"
    sheet.save(out, quality=85)
    print(f"ok {out.relative_to(ROOT)} {sheet.width}x{sheet.height} images={len(files)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
