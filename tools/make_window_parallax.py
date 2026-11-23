#!/usr/bin/env python3
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
BG = ROOT / "assets/backgrounds/s01/walk_hall.png"
OUT = ROOT / "assets/backgrounds/s01"
WINDOWS = [(476, 604), (656, 808)]
Y0, Y1 = 96, 204
MARGIN = 48
GRID = 4


def main() -> None:
    im = np.array(Image.open(BG).convert("RGB")).astype(int)
    h, w, _ = im.shape
    lum = im.mean(2)
    mask = np.zeros((h, w), bool)
    x_lo, x_hi = WINDOWS[0][0], WINDOWS[-1][1]
    strip = im[Y0:Y1, x_lo:x_hi].copy()
    good_col = np.zeros(x_hi - x_lo, bool)
    good_row = np.ones(Y1 - Y0, bool)
    for x0, x1 in WINDOWS:
        sub = lum[Y0:Y1, x0:x1]
        frame_cols = sub.mean(0) < 57.0
        frame_rows = sub.mean(1) < 46.0
        glass = np.ones_like(sub)
        glass[:, frame_cols] = False
        glass[frame_rows, :] = False
        mask[Y0:Y1, x0:x1] = glass
        good_col[x0 - x_lo:x1 - x_lo] = ~frame_cols
        good_row &= ~frame_rows
    gap0, gap1 = WINDOWS[0][1] - x_lo, WINDOWS[1][0] - x_lo
    strip[:, gap0:gap1] = strip[:, 0:gap1 - gap0]
    good_col[gap0:gap1] = good_col[0:gap1 - gap0]
    for x in range(strip.shape[1]):
        if not good_col[x]:
            src = x - 1
            while src > 0 and not good_col[src]:
                src -= 1
            strip[:, x] = strip[:, max(src, 0)]
    for y in range(strip.shape[0]):
        if not good_row[y]:
            src = y - 1
            while src > 0 and not good_row[src]:
                src -= 1
            if src < 0 or not good_row[max(src, 0)]:
                src = y + 1
                while src < strip.shape[0] - 1 and not good_row[src]:
                    src += 1
            strip[y] = strip[src]
    left = strip[:, :MARGIN][:, ::-1]
    right = strip[:, -MARGIN:][:, ::-1]
    full = np.concatenate([left, strip, right], axis=1)
    full = full.reshape(full.shape[0] // GRID, GRID, full.shape[1] // GRID, GRID, 3)[:, 0, :, 0, :]
    full = np.repeat(np.repeat(full, GRID, 0), GRID, 1)
    Image.fromarray(full.clip(0, 255).astype("uint8")).save(OUT / "walk_windows_city.png")
    Image.fromarray((mask * 255).astype("uint8")).save(OUT / "walk_windows_mask.png")
    print("city", full.shape[1], "x", full.shape[0], "origin", (x_lo - MARGIN, Y0))


if __name__ == "__main__":
    main()
