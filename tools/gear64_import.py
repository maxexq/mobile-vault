#!/usr/bin/env python3
"""MV-767: bake the approved 64 px Vault hatch item frame (F5, MV-689) and the 20 gear set icons into assets/gear64.

Source: the claude.ai project folder designs/gear-sets (not in git):
  frame64/build64.py   F5 frame + tier ladder (gauge lamps, ring lights, locking dogs, bolt caps, glass light,
                       trim + embers, Mythic cracks/arcs), 16 frames at 8 fps, 80x80 cell = 64 frame + 16 px pad
  raw/<piece>_32/      PixelLab 32 px icons; take A of build.PICKS is used for every piece
Writes:
  assets/gear64/frames.png   rows 0-5 = rarity 0-5 idle (16 frames x 80 px), row 6 frame 0 = empty slot (lamps off)
  assets/gear64/icons.png    20 icons x 32 px in one row, order in gear64.json
  assets/gear64/gear64.json  {"cell": 80, "pad": 16, "frames": 16, "fps": 8, "icons": [piece ids]}
The icon and the +N badge are not baked: the game draws them (GearFrame64), so one strip serves every item.
Usage: python3 tools/gear64_import.py <path to designs/gear-sets>
(build64.py reads the Silkscreen font from /home/user/maxexq/mobile-vault/assets/fonts; symlink the repo there.)
"""
import json, os, sys
from PIL import Image


def main(src: str) -> None:
    sys.path.insert(0, os.path.join(src, "frame64"))
    sys.path.insert(0, src)
    import build64 as b
    from build import PICKS
    b.BG = (0, 0, 0, 0)          # transparent around the plate: the panel behind shows through
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "gear64")
    os.makedirs(out, exist_ok=True)
    C, N = b.C, b.N
    sheet = Image.new("RGBA", (C * N, C * 7), (0, 0, 0, 0))
    dummy = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    for r in range(6):
        for ph in range(N):
            sheet.alpha_composite(b.draw_cell(r, ph, dummy, show_icon=False), (ph * C, r * C))
    sheet.alpha_composite(b.draw_cell(0, 0, dummy, on=False, show_icon=False), (0, 6 * C))
    sheet.save(os.path.join(out, "frames.png"))
    ids = list(PICKS)
    icons = Image.new("RGBA", (32 * len(ids), 32), (0, 0, 0, 0))
    for i, p in enumerate(ids):
        seed, takes = PICKS[p]
        im = Image.open(os.path.join(src, "raw", f"{p}_32", f"{seed}_{takes[0]:02d}.png")).convert("RGBA")
        im.putalpha(im.getchannel("A").point(lambda v: 255 if v >= 128 else 0))
        icons.alpha_composite(im, (32 * i, 0))
    icons.save(os.path.join(out, "icons.png"))
    json.dump({"cell": C, "pad": b.PAD, "frames": N, "fps": b.FPS, "icons": ids}, open(os.path.join(out, "gear64.json"), "w"), indent=1)
    print("ok", sheet.size, icons.size, len(ids))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/mnt/project-files/designs/gear-sets")
