#!/usr/bin/env python3
import argparse
import os

import soundfile as sf

ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("out")
ap.add_argument("--quality", type=float, default=0.75)
a = ap.parse_args()
info = sf.info(a.src)
with sf.SoundFile(a.out, "w", samplerate=info.samplerate, channels=info.channels, format="OGG",
                  subtype="VORBIS", compression_level=1.0 - a.quality) as f:
    for block in sf.blocks(a.src, blocksize=info.samplerate, dtype="float32"):
        f.write(block)
print(f"ok {a.out} {os.path.getsize(a.out) / 1e6:.1f} MB")
