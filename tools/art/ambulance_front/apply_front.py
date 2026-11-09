"""MV-731: put the approved flat 2D front (no hood nub, steel bumper + tow hook) on every ambulance shell.

Source: /mnt/project-files/designs/vehicle-upgrades/ext/approved/front_stock.png (canvas 224x144 = shell x0-176,
y(h-144)-h with a 48 px pad on the left, opaque BG (38,36,42)). Pixels at shell x >= 0 replace the shell's front;
the part in front of x 0 (bumper tip + tow hook, 12 px) becomes assets/vehicles/ambulance_v3/nose.png, drawn at
(-12, h-144) by Vehicle and InteriorV3Panel. Run from the repo root on the ORIGINAL shells (git checkout them first),
then python3 tools/ambulance_anim.py.
"""
import sys
from PIL import Image
SRC = sys.argv[1] if len(sys.argv) > 1 else "/mnt/project-files/designs/vehicle-upgrades/ext/approved/front_stock.png"
DIR = "assets/vehicles/ambulance_v3/"; BG = (38, 36, 42); PAD = 48; NOSE = 12
def near_bg(p): return sum(abs(p[i] - BG[i]) for i in range(3)) <= 24
front = Image.open(SRC).convert("RGBA"); fp = front.load()
for n in range(1, 6):
    sh = Image.open(f"{DIR}shell_f{n}.png").convert("RGBA"); sp = sh.load(); top = sh.height - front.height
    for y in range(front.height):
        for x in range(PAD, front.width):
            sx, sy = x - PAD, top + y; p = fp[x, y]
            if near_bg(p) and sp[sx, sy][3] == 0: continue          # empty stays empty
            if near_bg(p): sp[sx, sy] = (0, 0, 0, 0); continue        # the nub and old edge pixels that were removed
            sp[sx, sy] = p
    sh.save(f"{DIR}shell_f{n}.png")
nose = Image.new("RGBA", (NOSE, front.height), (0, 0, 0, 0)); np_ = nose.load()
for y in range(front.height):
    for x in range(NOSE):
        p = fp[PAD - NOSE + x, y]
        if not near_bg(p): np_[x, y] = p
nose.save(f"{DIR}nose.png"); print("shells + nose.png written", nose.getbbox())
