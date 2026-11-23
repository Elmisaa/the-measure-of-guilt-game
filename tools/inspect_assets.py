#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import ROOT, is_background, load_palette


def inspect(path: Path, palette: set[tuple[int, int, int]], cell: tuple[int, int] | None) -> str:
    img = Image.open(path)
    mode = img.mode
    rgba = img.convert("RGBA")
    colors = rgba.getcolors(maxcolors=1 << 20) or []
    opaque = {(r, g, b) for _, (r, g, b, a) in colors if a > 0}
    alphas = {a for _, (_, _, _, a) in colors}
    has_alpha = any(a < 255 for a in alphas)
    semi = any(0 < a < 255 for a in alphas)
    magenta = sum(n for n, (r, g, b, a) in colors if a > 0 and is_background((r, g, b), 60))
    parts = [f"{rgba.width}x{rgba.height}", mode, f"alpha={'yes' if has_alpha else 'no'}",
             f"colors={len(opaque)}"]
    if semi:
        parts.append("SEMI-TRANSPARENT")
    if magenta:
        parts.append(f"MAGENTA_PX={magenta}")
    if palette:
        off = len(opaque - palette)
        parts.append(f"off_palette={off}")
    if cell:
        cw, ch = cell
        if rgba.width % cw or rgba.height % ch:
            parts.append(f"NOT_MULTIPLE_OF_{cw}x{ch}")
        else:
            parts.append(f"frames={rgba.width // cw}x{rgba.height // ch}")
    try:
        rel = path.resolve().relative_to(ROOT)
    except ValueError:
        rel = path
    return f"{rel}: " + " ".join(parts)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="*", type=Path, default=[ROOT / "assets"])
    ap.add_argument("--cell", help="expected frame size WxH")
    args = ap.parse_args()
    cell = tuple(int(v) for v in args.cell.lower().split("x")) if args.cell else None
    palette = set(load_palette())

    files: list[Path] = []
    for p in args.paths:
        files += sorted(p.rglob("*.png")) if p.is_dir() else [p]
    if not files:
        print("no png files found")
        return 1
    for f in files:
        try:
            print(inspect(f, palette, cell))
        except Exception as e:
            print(f"{f}: ERROR {e}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
