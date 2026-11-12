#!/usr/bin/env python3
"""MV-773: bake the simple 64 px item frame (option B, picked by Parames) into assets/gear64/frames_simple.png.

A calm alternative to the MV-767 Vault hatch: a flat worn-steel plate (1 px bevel, 4 small rivets) round a dark
recessed well, and the rarity shown only as four L brackets in the rarity colour pulled 35 % toward the steel so it
never shouts. No ring, no lamps, no glow, no motion. Palette = the steel already in assets/gear64/frames.png plus the
Loot.RARITY colours.
Writes one 96 px cell per row (64 px plate + 16 px transparent pad, same cell as frames.png so GearFrame64 draws both
the same way): rows 0-5 = rarity 0-5, row 6 = the empty slot (no brackets).
The icon, +N, lock and set emblem are drawn by the game.
Usage: python tools/art/gear_frame_simple.py
"""
import os
from PIL import Image, ImageDraw

CELL, PAD, PLATE = 96, 16, 64
RAR = ["b8bec9", "6be27d", "6fc3ff", "c77dff", "ffb347", "ff5c7a"]    # Loot.RARITY[i].col
K0 = (4, 4, 2)          # outline
K1 = (20, 18, 22)       # rivet shadow
S0 = (28, 27, 21)       # shade
S2 = (47, 46, 40)       # plate
S3 = (63, 59, 48)       # left light
S4 = (78, 72, 60)       # top light / rivet
WELL = (12, 10, 10)
BRACKET = 9             # arm length
MUTE = 0.35             # pull toward the plate colour


def hx(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(round(a[i] * (1 - t) + b[i] * t) for i in range(3))


def box(d, x0, y0, x1, y1, c):
    d.rectangle([x0, y0, x1, y1], fill=c + (255,))


def plate(rank: int) -> Image.Image:
    im = Image.new("RGBA", (PLATE, PLATE), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    box(d, 0, 0, 63, 63, K0)
    box(d, 1, 1, 62, 62, S2)
    box(d, 1, 1, 62, 1, S4)
    box(d, 1, 1, 1, 62, S3)
    box(d, 1, 62, 62, 62, S0)
    box(d, 62, 1, 62, 62, S0)
    for x, y in ((4, 4), (58, 4), (4, 58), (58, 58)):
        box(d, x, y, x + 1, y + 1, S4)
        d.point((x + 1, y + 1), K1 + (255,))
    # the recessed well the icon sits in
    box(d, 7, 7, 56, 56, K0)
    box(d, 8, 8, 55, 55, WELL)
    box(d, 8, 55, 55, 55, S0)
    box(d, 55, 8, 55, 55, S0)
    if rank >= 0:
        c = mix(hx(RAR[rank]), S2, MUTE) + (255,)
        for x, y, sx, sy in ((7, 7, 1, 1), (56, 7, -1, 1), (7, 56, 1, -1), (56, 56, -1, -1)):
            for k in range(BRACKET):
                for w in range(2):
                    d.point((x + sx * k, y + sy * w), c)
                    d.point((x + sx * w, y + sy * k), c)
    return im


def main() -> None:
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "gear64", "frames_simple.png")
    sheet = Image.new("RGBA", (CELL, CELL * 7), (0, 0, 0, 0))
    for row, rank in enumerate([0, 1, 2, 3, 4, 5, -1]):
        sheet.alpha_composite(plate(rank), (PAD, row * CELL + PAD))
    sheet.save(out)
    print("ok", os.path.normpath(out), sheet.size)


if __name__ == "__main__":
    main()
