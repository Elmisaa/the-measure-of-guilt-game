#!/usr/bin/env python3
"""Build a natural side-view walk cycle from separate body parts (cutout rig), rendered
offline at high resolution and then downscaled to the game's pixel grid — so the
result is clean pixel art (no in-engine rotation jaggies).

Parts sheet: one row on #FF00FF, in order: head, torso, upper arm, forearm+hand,
thigh, shin, foot. Limbs hang straight down with the joint at the top centre.

  python3 tools/rig_walk.py art/drafts/alexei_parts/parts_v1_a.png --height 50 --pixel 4 \
      --scales 1.0,0.93,0.86 --out assets/characters/alexei/walk_rig.png --gif art/previews/alexei_rig.gif

Output: one sheet per scale stacked vertically; each row = 2 idle + 8 walk frames.
"""
from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

from PIL import Image, ImageEnhance

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelize import harden_alpha, remove_background  # noqa: E402
from slice_sheet import find_frames  # noqa: E402

NAMES = ["head", "torso", "uarm", "farm", "thigh", "shin", "foot"]


def load_parts(path: Path) -> dict[str, Image.Image]:
    img = remove_background(Image.open(path), 90)
    parts = {}
    for name, (x0, x1) in zip(NAMES, find_frames(img, 4, 6)):
        c = img.crop((x0, 0, x1, img.height))
        parts[name] = c.crop(c.getbbox())
    return parts


def paste_rot(canvas: Image.Image, part: Image.Image, pivot_in_part: tuple[float, float], at: tuple[float, float], deg: float) -> None:
    """Rotate `part` by deg (positive = its bottom swings forward/right) around its pivot and
    place that pivot at `at` on the canvas."""
    w, h = part.size
    pad = int(math.hypot(w, h)) + 4
    big = Image.new("RGBA", (pad * 2, pad * 2), (0, 0, 0, 0))
    px, py = pivot_in_part
    big.paste(part, (int(pad - px), int(pad - py)), part)
    rot = big.rotate(deg, resample=Image.BICUBIC, center=(pad, pad))
    canvas.alpha_composite(rot, (int(at[0] - pad), int(at[1] - pad)))


def end_point(at: tuple[float, float], length: float, deg: float) -> tuple[float, float]:
    a = math.radians(deg)
    return (at[0] - math.sin(a) * length * -1.0 * -1.0 + 0 if False else at[0] + math.sin(a) * length, at[1] + math.cos(a) * length)


def shade(img: Image.Image, k: float) -> Image.Image:
    rgb = ImageEnhance.Brightness(img.convert("RGB")).enhance(k).convert("RGBA")
    rgb.putalpha(img.getchannel("A"))
    return rgb


def pose(parts: dict[str, Image.Image], p: float | None, breathe: float = 0.0) -> Image.Image:
    P = parts
    W, H = 2600, 3000
    cv = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    hip = (W / 2, 1300.0)
    ov = 0.10  # joint overlap fraction
    L_th = P["thigh"].height * (1 - ov)
    L_sh = P["shin"].height * (1 - ov)
    L_ua = P["uarm"].height * (1 - ov)
    if p is None:  # idle
        legs = [(2.0, 4.0, -2.0), (-2.0, 4.0, 2.0)]
        arms = [(3.0, 8.0), (-3.0, 8.0)]
        bob = breathe
    else:
        legs = []
        for q in (p, p + math.pi):
            th = 24 * math.sin(q)
            kn = 6 + 42 * max(0.0, math.cos(q)) ** 1.4
            ft = -(th - kn) * 0.55 + (12 if math.cos(q) > 0.6 else 0)
            legs.append((th, kn, ft))
        arms = [(-16 * math.sin(q), 10 + 16 * max(0.0, -math.sin(q))) for q in (p, p + math.pi)]
        bob = 0.0

    def leg(th: float, kn: float, ft: float, dark: bool) -> None:
        th_img, sh_img, ft_img = P["thigh"], P["shin"], P["foot"]
        if dark:
            th_img, sh_img, ft_img = shade(th_img, 0.62), shade(sh_img, 0.62), shade(ft_img, 0.62)
        knee = end_point(hip, L_th, th)
        ankle = end_point(knee, L_sh, th - kn)
        paste_rot(cv, sh_img, (sh_img.width / 2, sh_img.height * 0.04), knee, th - kn)
        paste_rot(cv, ft_img, (ft_img.width * 0.28, ft_img.height * 0.12), ankle, ft * 0.3)
        paste_rot(cv, th_img, (th_img.width / 2, th_img.height * 0.05), hip, th)

    def arm(sh_deg: float, el: float, dark: bool, shoulder: tuple[float, float]) -> None:
        ua, fa = P["uarm"], P["farm"]
        if dark:
            ua, fa = shade(ua, 0.62), shade(fa, 0.62)
        elbow = end_point(shoulder, L_ua, sh_deg)
        paste_rot(cv, fa, (fa.width / 2, fa.height * 0.05), elbow, sh_deg + el)
        paste_rot(cv, ua, (ua.width / 2, ua.height * 0.06), shoulder, sh_deg)

    torso = P["torso"]
    t_top = (hip[0], hip[1] + torso.height * 0.08 - torso.height + bob)
    shoulder = (hip[0] + torso.width * 0.05, t_top[1] + torso.height * 0.12)
    # far side first (darker, behind), then torso and head, then near side
    leg(*legs[1], dark=True)
    arm(*arms[1], dark=True, shoulder=shoulder)
    cv.alpha_composite(torso, (int(hip[0] - torso.width / 2), int(t_top[1])))
    head = P["head"]
    cv.alpha_composite(head, (int(hip[0] - head.width * 0.45), int(t_top[1] - head.height * 0.82)))
    leg(*legs[0], dark=False)
    arm(*arms[0], dark=False, shoulder=shoulder)
    return cv


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("parts", type=Path)
    ap.add_argument("--height", type=int, default=50, help="standing height in art pixels at scale 1")
    ap.add_argument("--pixel", type=int, default=4)
    ap.add_argument("--scales", default="1.0")
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--gif", type=Path)
    a = ap.parse_args()
    parts = load_parts(a.parts)
    hires = [pose(parts, None, 0), pose(parts, None, -6)] + [pose(parts, i * 2 * math.pi / 8) for i in range(8)]
    # common crop + ground the lowest pixel of every frame on the same line
    bbs = [f.getbbox() for f in hires]
    stand_h = bbs[0][3] - bbs[0][1]
    left = min(b[0] for b in bbs) - 10
    right = max(b[2] for b in bbs) + 10
    top = min(b[1] for b in bbs) - 10
    rows = []
    for s in [float(v) for v in a.scales.split(",")]:
        k = a.height * s / stand_h
        cw = math.ceil((right - left) * a.height / stand_h) + 2  # same cell width in every row
        ch = math.ceil(a.height * 1.08)
        row = Image.new("RGBA", (cw * len(hires), ch), (0, 0, 0, 0))
        for i, (f, b) in enumerate(zip(hires, bbs)):
            c = f.crop((left, top, right, b[3]))
            sm = harden_alpha(c.convert("RGBa").resize((max(1, round(c.width * k)), max(1, round(c.height * k))), Image.BOX).convert("RGBA"))
            row.paste(sm, (i * cw + (cw - sm.width) // 2, ch - sm.height), sm)
        rows.append(row)
    W = max(r.width for r in rows)
    sheet = Image.new("RGBA", (W, sum(r.height for r in rows)), (0, 0, 0, 0))
    y = 0
    for r in rows:
        sheet.paste(r, (0, y))
        y += r.height
    sheet = sheet.resize((sheet.width * a.pixel, sheet.height * a.pixel), Image.NEAREST)
    a.out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(a.out)
    print(f"ok {a.out} {sheet.size} rows={len(rows)} frames={len(hires)} row_heights={[r.height * a.pixel for r in rows]} cell_w={[r.width // len(hires) * a.pixel for r in rows]}")
    if a.gif:
        r0 = rows[0].resize((rows[0].width * a.pixel, rows[0].height * a.pixel), Image.NEAREST)
        cw = r0.width // len(hires)
        frames = []
        for i in range(2, 10):
            f = Image.new("RGBA", (cw + 40, r0.height + 20), (24, 28, 34, 255))
            f.alpha_composite(r0.crop((i * cw, 0, (i + 1) * cw, r0.height)), (20, 10))
            frames.append(f.convert("RGB").resize(((cw + 40) * 2, (r0.height + 20) * 2), Image.NEAREST))
        frames[0].save(a.gif, save_all=True, append_images=frames[1:], duration=110, loop=0)
        print(f"ok {a.gif}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
