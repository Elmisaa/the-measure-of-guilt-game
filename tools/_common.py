from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_PALETTE = ROOT / "art" / "palette.png"
MAGENTA = (255, 0, 255)


def load_palette(path: Path | None = None) -> list[tuple[int, int, int]]:
    path = path or DEFAULT_PALETTE
    if not path.exists():
        return []
    img = Image.open(path).convert("RGBA")
    seen: dict[tuple[int, int, int], None] = {}
    for r, g, b, a in img.getdata():
        if a > 0:
            seen.setdefault((r, g, b), None)
    return list(seen)


def nearest_color(c: tuple[int, int, int], palette: list[tuple[int, int, int]]) -> tuple[int, int, int]:
    r, g, b = c
    return min(palette, key=lambda p: 2 * (p[0] - r) ** 2 + 4 * (p[1] - g) ** 2 + 3 * (p[2] - b) ** 2)


def is_background(c: tuple[int, int, int], tolerance: int) -> bool:
    r, g, b = c
    return abs(r - 255) <= tolerance and g <= tolerance and abs(b - 255) <= tolerance
