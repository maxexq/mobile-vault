"""MV-741 (Parames 20:22 "driver + micro anims"): the approved driver A2 (MV-656, Dr. Ren in the field coat) in the cab.

Source: /mnt/project-files/designs/dr-ren-ambulance/drive/driver/approved/ (pick_A2 + A2_drive/chill/idle/still, 64x64
crops of the old body at (64,48), animate-with-text-v3 takes; last frame = first, dropped). The cab glass there is the
30x26 box at crop (23,21), the same size as the flat-front shell's glass at shell (87, h-139). driver_rim.py (MV-656
rim.py) draws the steering wheel over every frame. Writes:
  assets/vehicles/ambulance_v3/driver.png   rows = drive, chill, idle, still; columns = frames; 30x26 each, only the
                                            shell's glass pixels (the window frame stays the shell's)
  assets/vehicles/ambulance_v3/driver.json  {"size": [30, 26], "states": {"drive": n, ...}, "fps": 8}
Run before tools/art/ambulance/cleanup.py (it bakes the still frame into every shell) and tools/ambulance_anim.py.
"""
import json, os, sys
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from driver_rim import apply as rim
ROOT = os.path.abspath(os.path.join(HERE, "../../.."))
OUT = os.path.join(ROOT, "assets/vehicles/ambulance_v3")
SRC = sys.argv[1] if len(sys.argv) > 1 else "/mnt/project-files/designs/dr-ren-ambulance/drive/driver/approved"
GX, GY, W, H = 23, 21, 30, 26          # glass box in the 64x64 crop
GLASS = (60, 70, 78)
STATES = ["drive", "chill", "idle", "still"]


def glass_mask():
    sh = Image.open(os.path.join(OUT, "shell_f1.png")).convert("RGBA"); px = sh.load(); y0 = sh.height - 139
    return [[px[87 + x, y0 + y][3] > 0 and sum(abs(a - b) for a, b in zip(px[87 + x, y0 + y][:3], GLASS)) <= 12
             for x in range(W)] for y in range(H)]


if __name__ == "__main__":
    m = glass_mask()
    frames = {}
    for s in STATES:
        d = os.path.join(SRC, "A2_" + s)
        fs = sorted(f for f in os.listdir(d) if f.endswith(".png") and "_2x" not in f)[:-1]
        frames[s] = [rim(Image.open(os.path.join(d, f)).convert("RGBA")).crop((GX, GY, GX + W, GY + H)) for f in fs]
    cols = max(len(v) for v in frames.values())
    strip = Image.new("RGBA", (W * cols, H * len(STATES)))
    for r, s in enumerate(STATES):
        for c, fr in enumerate(frames[s]):
            fp = fr.load(); cell = Image.new("RGBA", (W, H)); cp = cell.load()
            for y in range(H):
                for x in range(W):
                    if m[y][x]: cp[x, y] = fp[x, y][:3] + (255,)
            strip.paste(cell, (c * W, r * H))
    strip.save(os.path.join(OUT, "driver.png"))
    json.dump({"size": [W, H], "states": {s: len(frames[s]) for s in STATES}, "fps": 8},
              open(os.path.join(OUT, "driver.json"), "w"), indent=1)
    print("driver.png", strip.size, {s: len(frames[s]) for s in STATES})
