#!/usr/bin/env python3
"""MV-733: copy the approved realistic-size pets (MV-601: 3 dogs, 3 cats, 3 chickens) into the game (assets/v3/pets/).

    python3 tools/pets_v3_import.py [--src /mnt/project-files/designs/pets-preview/approved-realistic]

Source: <pet>/still.png + <pet>/walk/0..7.png, 64x64 canvas, feet on row 53, facing east, drawn at v2/v3 room pixel
scale (the pets stand 14-20 room px tall next to the ~40 px crew). Each pet becomes one sheet of 32x24 frames cut
from the canvas at (16, 30): frame 0 = still, 1..8 = walk loop. Feet = bottom row of the frame, centre x 16.
Writes assets/v3/pets.json. Re-run after any art change, then `godot --import` so the .import files exist.
"""
import argparse, json, os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "v3", "pets")
SRC = "/mnt/project-files/designs/pets-preview/approved-realistic"
CUT = (16, 30, 48, 54)                     # x0, y0, x1, y1 on the 64x64 canvas (feet row 53 -> last frame row)
FW, FH = CUT[2] - CUT[0], CUT[3] - CUT[1]
# game pet kind -> the breeds that can play it (first = the default / named story pet)
KINDS = {"dog": ["dog_mutt", "dog_shepherd", "dog_terrier"], "cat": ["cat_ginger", "cat_tabby", "cat_black"],
         "hen": ["hen_brown", "hen_white", "rooster"]}
SPEED = {"dog": 14.0, "cat": 11.0, "hen": 6.0}   # room px / s (crew 16)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=SRC)
    a = ap.parse_args()
    man = json.load(open(os.path.join(a.src, "manifest.json")))
    os.makedirs(OUT, exist_ok=True)
    pets = {}
    for kind, breeds in KINDS.items():
        for b in breeds:
            m = man["pets"][b]
            n = int(m["walk"]["frames"])
            frames = [os.path.join(a.src, b, m["still"])] + [os.path.join(a.src, b, "walk", "%d.png" % i) for i in range(n)]
            sheet = Image.new("RGBA", (FW * len(frames), FH), (0, 0, 0, 0))
            for i, f in enumerate(frames):
                im = Image.open(f).convert("RGBA")
                assert im.size == (64, 64), f
                bb = im.getbbox()
                assert bb and bb[0] >= CUT[0] and bb[1] >= CUT[1] and bb[2] <= CUT[2] and bb[3] <= CUT[3], (f, bb)
                sheet.paste(im.crop(CUT), (i * FW, 0))
            sheet.save(os.path.join(OUT, b + ".png"))
            w, h = m["size_px"]
            pets[b] = {"kind": kind, "file": b + ".png", "walk": {"n": n, "fps": int(m["walk"]["fps"])},
                       "size": [w, h], "speed": SPEED[kind]}
            print(b, len(frames), "frames")
    out = {"note": "MV-733 / MV-601 approved realistic pets. Frame %dx%d, feet at (%d, %d) = bottom centre, facing east; "
                   "frame 0 still, 1..n walk. Made by tools/pets_v3_import.py" % (FW, FH, FW // 2, FH),
           "frame": [FW, FH], "kinds": KINDS, "pets": pets}
    with open(os.path.join(ROOT, "assets", "v3", "pets.json"), "w") as f:
        json.dump(out, f, indent=1)
        f.write("\n")


if __name__ == "__main__":
    main()
