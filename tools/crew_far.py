#!/usr/bin/env python3
"""MV-734: crisp 2/3-size crew sheets for the world view.

In the world (world v2: room art at half scale, world_2x render) one v3 room pixel is one rendered pixel, so the
ref v3 crew at 2/3 would get 0.67 of a pixel each and nearest sampling drops every third row and column (cut
faces, broken outlines: "the crew look blurry"). This writes assets/v3/crew/<id>_far.png next to each sheet:
the same clips, every frame shrunk to 2/3 ahead of time (64 -> 43 px, feet still on the bottom row) by
majority colour: each new pixel covers 1.5 x 1.5 old pixels (3 x 3 samples on a 2x grid) and takes the colour
that covers most of it (ties -> the darker one, so outlines survive); it stays empty when 6 or more of the 9
samples are empty. Only colours from the sprite itself are used (no blending, no new colours). crew.json gets
"far": "<id>_far.png" per character and "far_frame": [43, 43].

    python3 tools/crew_far.py            # all characters in assets/v3/crew.json
Run again after tools/v3_import.py (it calls this at the end), then `godot --import`.
"""
import json, os, sys
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "v3")
SRC = 64          # source frame
FAR = 43          # ceil(64 * 2 / 3): row 42 covers source row 63 (the feet)
EMPTY_MIN = 6     # transparent when at least this many of the 9 samples are empty


def shrink_frame(a):
    """a: (64, 64, 4) uint8 -> (43, 43, 4) uint8, majority colour per 1.5 px block"""
    up = np.zeros((FAR * 3, FAR * 3, 4), np.uint8)          # 129 x 129: 2x grid + 1 empty row / column
    up[:SRC * 2, :SRC * 2] = a.repeat(2, 0).repeat(2, 1)
    b = up.reshape(FAR, 3, FAR, 3, 4).transpose(0, 2, 1, 3, 4).reshape(FAR, FAR, 9, 4)
    opaque = b[..., 3] > 127
    key = (b[..., 0].astype(np.int64) << 16) | (b[..., 1].astype(np.int64) << 8) | b[..., 2].astype(np.int64)
    key = np.where(opaque, key, -1)
    # votes[i] = how many of the 9 samples share sample i's colour (empty samples never win)
    votes = (key[..., :, None] == key[..., None, :]).sum(-1)
    votes = np.where(opaque, votes, 0)
    lum = b[..., 0].astype(np.int64) * 299 + b[..., 1].astype(np.int64) * 587 + b[..., 2].astype(np.int64) * 114
    score = votes * 1_000_000_000 - lum                    # most votes, then the darkest
    pick = score.argmax(-1)
    out = np.take_along_axis(b, pick[..., None, None], 2)[:, :, 0, :].copy()
    out[..., 3] = 255
    out[(~opaque).sum(-1) >= EMPTY_MIN] = 0
    return out


def shrink_sheet(path_in, path_out):
    a = np.array(Image.open(path_in).convert("RGBA"))
    rows, cols = a.shape[0] // SRC, a.shape[1] // SRC
    o = np.zeros((rows * FAR, cols * FAR, 4), np.uint8)
    for r in range(rows):
        for c in range(cols):
            f = a[r * SRC:(r + 1) * SRC, c * SRC:(c + 1) * SRC]
            if f[..., 3].any():
                o[r * FAR:(r + 1) * FAR, c * FAR:(c + 1) * FAR] = shrink_frame(f)
    Image.fromarray(o).save(path_out, optimize=True)


def main():
    cj = os.path.join(OUT, "crew.json")
    data = json.load(open(cj))
    for cid, e in data["crew"].items():
        src = os.path.join(OUT, "crew", e["file"])
        name = cid + "_far.png"
        shrink_sheet(src, os.path.join(OUT, "crew", name))
        e["far"] = name
    data["far_frame"] = [FAR, FAR]
    json.dump(data, open(cj, "w"), indent=1)
    print("far crew sheets:", ", ".join(data["crew"]))


if __name__ == "__main__":
    sys.exit(main())
