#!/usr/bin/env python3
"""MV-738 round 3: Bastion 42-B micro animations on the road (world v2), same format as tools/art/decker/anim.py.

  anim.json       per deck count: the 4 tyre centres (8x8 truck: 2 front + 2 rear axles), headlamp lens, rear amber
                  marker, red tail lamp (all drawn by cleanup.py), the solar array's cell pixels (sun glint) and the
                  loose air lines at the rear hitch (swing)
  wheel_spin.png  24-frame strip of one tyre rolling west (the truck faces west)
Run after tools/art/bastion/shell.py + cleanup.py. Code only, no PixelLab.
"""
import importlib.util, json, os, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
DIR = os.path.join(ROOT, "assets", "vehicles", "bastion_v3")
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import cleanup as cl
spec = importlib.util.spec_from_file_location("dk_anim", os.path.join(HERE, "..", "decker", "anim.py"))
dk = importlib.util.module_from_spec(spec); spec.loader.exec_module(dk)
amb = dk.amb

WHEEL_X = (60.5, 116.5, 492.5, 548.5)   # tyre centres; centre row = height - 33.5 (r 22 measured)
WHEEL_DY = 33.5


def one(n):
    im = Image.open(os.path.join(DIR, f"shell_f{n}.png")).convert("RGBA"); W, H = im.size; D = H - 344
    px = im.load()
    top = cl.Y0 + cl.FH * (n - 2)
    sx0, sy0 = cl.SOLAR["x0"], top + cl.SOLAR["top"]
    sy1 = sy0 + 2 * cl.SOLAR["pan"] + cl.SOLAR["gap"]
    cells = {c[:3] for c in cl.SOLAR_CELL}
    solar = [[x, y] for y in range(sy0, sy1) for x in range(sx0, cl.SOLAR["x1"]) if px[x, y][:3] in cells]
    return {"size": [W, H], "wheels": [[x, H - WHEEL_DY + 0.0] for x in WHEEL_X], "wheel_r": amb.WHEEL_R,
            "head": [cl.HEAD[0] + 0.5, cl.HEAD[1] + D + 0.5],
            "marker": [cl.MARK[0] + 1.0, cl.MARK[1] + D + 0.5], "tails": [[cl.TAIL[0] + 1.0, cl.TAIL[1] + D + 0.5]],
            "solar_px": solar,
            "swing": [[598, 286 + D, 26, 16]]}


def spin_strip():
    """the rear-most tyre (x 548) rotated by the ambulance's crisp 8x-vote rotation"""
    im = Image.open(os.path.join(DIR, "shell_f2.png")).convert("RGBA")
    S = amb.SIZE; c = S / 2
    cx, cy = 548.5, 344 - WHEEL_DY
    src = im.crop((int(cx - c), int(cy - c), int(cx - c) + S, int(cy - c) + S))
    sp = src.load()
    disc = Image.new("RGBA", (S, S)); dp = disc.load()
    for y in range(S):
        for x in range(S):
            if (x + 0.5 - c) ** 2 + (y + 0.5 - c) ** 2 <= amb.WHEEL_R ** 2:
                dp[x, y] = sp[x, y][:3] + (255,)
    old = amb.DIR; amb.DIR = DIR
    orig = Image.open
    Image.open = lambda p, *a, **k: (dk._Fake(disc) if str(p).endswith("shell_f1.png") else orig(p, *a, **k))
    try:
        amb.spin_strip()
    finally:
        Image.open = orig; amb.DIR = old


if __name__ == "__main__":
    meta = {"wheel_size": amb.SIZE, "spin_frames": amb.SPIN_N, "floors": {}}
    for n in (2, 3):
        meta["floors"][str(n)] = f = one(n)
        print(n, f["size"], "head", f["head"], "solar px", len(f["solar_px"]))
    json.dump(meta, open(os.path.join(DIR, "anim.json"), "w"), separators=(",", ":"))   # solar_px is long: one line
    spin_strip()
    print("wrote anim.json + wheel_spin.png")
