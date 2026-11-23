#!/usr/bin/env python3
import sys; sys.path.insert(0, 'tools')
from PIL import Image
import numpy as np
from pixelize import remove_background, harden_alpha
from slice_sheet import find_frames
from harmonize_walk_lib import to_lab, from_lab

SRC = sys.argv[1] if len(sys.argv) > 2 else 'art/drafts/run/run_v1_a.png'
OUT = sys.argv[2] if len(sys.argv) > 2 else 'assets/characters/alexei/run_side_depth.png'
F = 4; H = 50; SCALES = (1.0, 0.97, 0.94)

bg = Image.open('art/drafts/walk_final/pano_v1.png').convert('RGB')
zone = to_lab(np.asarray(bg.crop((0, 150, bg.width, 360)), dtype=np.float64)).reshape(-1, 3)
zm = zone.mean(0)
img = remove_background(Image.open(SRC).convert('RGB'), 110)
crops = []
for x0, x1 in find_frames(img, 6, 8):
    c = img.crop((x0, 0, x1, img.height)); crops.append(c)
top = min(c.getbbox()[1] for c in crops); bot = max(c.getbbox()[3] for c in crops)
crops = [c.crop((0, top, c.width, bot)) for c in crops]
tall = bot - top


def grade(fr: Image.Image) -> Image.Image:
    arr = np.asarray(fr, dtype=np.float64); rgb = arr[..., :3]; al = arr[..., 3] > 0
    L = to_lab(rgb); sl = L[al]; m = sl.mean(0); adj = sl.copy()
    adj[:, 0] = (sl[:, 0] - m[0]) * 0.85 + m[0] * 0.8
    adj[:, 1:] = sl[:, 1:] * 0.7 + zm[1:] * 0.3
    out = rgb.copy(); out[al] = from_lab(adj)
    mag = (rgb[..., 0] - rgb[..., 1] > 40) & (rgb[..., 2] - rgb[..., 1] > 30)
    a = np.where(mag, 0, arr[..., 3])
    return Image.fromarray(np.dstack([out, a]).astype(np.uint8))


rows = []
for s in SCALES:
    hh = round(H * s); k = hh / tall
    rows.append([grade(harden_alpha(c.convert('RGBa').resize((max(1, round(c.width * k)), hh), Image.BOX).convert('RGBA'))) for c in crops])
cw = max(fr.width for fr in rows[0]) + 2
sheet = Image.new('RGBA', (cw * len(crops), H * len(SCALES)), (0, 0, 0, 0))
for r, frs in enumerate(rows):
    for i, fr in enumerate(frs):
        sheet.paste(fr, (i * cw + (cw - fr.width) // 2, (r + 1) * H - fr.height), fr)
sheet = sheet.resize((sheet.width * F, sheet.height * F), Image.NEAREST)
sheet.save(OUT)
print(OUT, sheet.size, 'frames', len(crops), 'cell', cw * F)
