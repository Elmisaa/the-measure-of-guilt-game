#!/usr/bin/env python3
"""Build a x4 preview sheet of all assets referenced in art/briefs/<scene>.md.

  python3 tools/make_preview.py <scene> [--scale 4]

Collects every `assets/...png` path mentioned in the brief, upscales with
nearest-neighbour, lays them out in rows with captions on a checkerboard,
and saves art/previews/<scene>.png.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import ROOT  # noqa: E402

PAD = 12
CAPTION_H = 14
MAX_ROW_W = 1600


def checkerboard(w: int, h: int, size: int = 8) -> Image.Image:
    img = Image.new("RGBA", (w, h), (60, 60, 60, 255))
    d = ImageDraw.Draw(img)
    for y in range(0, h, size):
        for x in range(0, w, size):
            if (x // size + y // size) % 2:
                d.rectangle((x, y, x + size - 1, y + size - 1), fill=(80, 80, 80, 255))
    return img


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("scene")
    ap.add_argument("--scale", type=int, default=4)
    args = ap.parse_args()

    brief = ROOT / "art" / "briefs" / f"{args.scene}.md"
    if not brief.exists():
        print(f"brief not found: {brief}")
        return 1
    paths = list(dict.fromkeys(re.findall(r"assets/[\w./-]+\.png", brief.read_text(encoding="utf-8"))))
    items: list[tuple[str, Image.Image]] = []
    missing: list[str] = []
    for p in paths:
        f = ROOT / p
        if not f.exists():
            missing.append(p)
            continue
        img = Image.open(f).convert("RGBA")
        items.append((p.removeprefix("assets/"), img.resize((img.width * args.scale, img.height * args.scale), Image.NEAREST)))
    if not items:
        print("no existing assets referenced in brief; missing:", *missing, sep="\n  ")
        return 1

    # Simple row packing.
    rows: list[list[tuple[str, Image.Image]]] = [[]]
    row_w = PAD
    for name, img in items:
        w = max(img.width, len(name) * 6) + PAD
        if rows[-1] and row_w + w > MAX_ROW_W:
            rows.append([])
            row_w = PAD
        rows[-1].append((name, img))
        row_w += w
    width = max(PAD + sum(max(i.width, len(n) * 6) + PAD for n, i in r) for r in rows)
    height = PAD + sum(max(i.height for _, i in r) + CAPTION_H + PAD for r in rows)

    sheet = checkerboard(width, height)
    draw = ImageDraw.Draw(sheet)
    y = PAD
    for r in rows:
        x = PAD
        rh = max(i.height for _, i in r)
        for name, img in r:
            draw.text((x, y), name, fill=(230, 230, 230, 255))
            sheet.paste(img, (x, y + CAPTION_H), img)
            x += max(img.width, len(name) * 6) + PAD
        y += rh + CAPTION_H + PAD

    out = ROOT / "art" / "previews" / f"{args.scene}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    print(f"ok {out.relative_to(ROOT)} assets={len(items)} missing={len(missing)}")
    for m in missing:
        print(f"  missing: {m}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
