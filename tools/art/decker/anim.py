#!/usr/bin/env python3
"""MV-739 Decker micro animations: anchor points + wheel spin strip for the Decker bus on the road (world v2).

Same format as tools/ambulance_anim.py (read by AmbulanceMotion with dir decker_v3), written next to the shells:
  anim.json       per deck count: wheel centres, headlight lens, rear amber indicator, red tail lamps, the
                  "9 DEPOT" destination sign (rect + one rect per glyph), exhaust tip; all in shell px
  wheel_spin.png  24-frame strip (47x47 each) of one tyre rolling west (the bus faces west)
Run after tools/art/decker/shell.py + cleanup.py; the autotest checks anim.json against the shell sizes.
Code only, no PixelLab.
"""
import importlib.util, json, os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
DIR = os.path.join(ROOT, "assets", "vehicles", "decker_v3")
spec = importlib.util.spec_from_file_location("amb", os.path.join(ROOT, "tools", "ambulance_anim.py"))
amb = importlib.util.module_from_spec(spec); spec.loader.exec_module(amb)

WHEEL_X = (62.5, 452.5, 504.5)   # tyre centres (2-deck shell px); centre row = height - 34
WHEEL_DY = 34
AMBER = lambda p: p[0] > 150 and p[1] > 90 and p[2] < 90
REDL = lambda p: p[0] > 110 and p[1] < 80 and p[2] < 60
HEAD = lambda p: sum(p[:3]) > 500


def one(n):
    im = Image.open(os.path.join(DIR, f"shell_f{n}.png")).convert("RGBA"); W, H = im.size; D = H - 344
    big = lambda bs: max(bs, key=lambda b: b["n"])
    head = big(amb.blobs(im, HEAD, (13, 256 + D, 21, 272 + D)))     # the PixelLab lamp (front/, round 3)
    marker = big(amb.blobs(im, AMBER, (588, 244 + D, 596, 256 + D)))
    tails = [b for b in amb.blobs(im, REDL, (588, 257 + D, 596, 272 + D)) if b["n"] >= 4]
    # destination sign: the amber glyphs (sign never moves: it sits above the top deck)
    sx0, sy0, sx1, sy1 = 28, 24, 72, 36
    px = im.load()
    cols = [x for x in range(sx0, sx1) if any(AMBER(px[x, y]) for y in range(sy0, sy1))]
    glyphs = []
    for x in cols:
        if glyphs and x == glyphs[-1][1]:
            glyphs[-1][1] = x + 1
        else:
            glyphs.append([x, x + 1])
    return {"size": [W, H], "wheels": [[x, H - WHEEL_DY + 0.0] for x in WHEEL_X], "wheel_r": amb.WHEEL_R,
            "head": head["c"], "marker": marker["c"], "tails": [t["c"] for t in tails],
            "sign": [cols[0], sy0, cols[-1] + 1 - cols[0], sy1 - sy0], "glyphs": [[a, b - a] for a, b in glyphs],
            "exhaust": [589.0, 303.0 + D],
            # loose cables hanging under the floor: rows below the attach row swing (AmbulanceMotion "swing")
            "swing": [[100, 300 + D, 166, 14]]}


def spin_strip():
    im = Image.open(os.path.join(DIR, "shell_f2.png")).convert("RGBA")
    S = amb.SIZE; c = S / 2
    cx, cy = 504.5, 344 - WHEEL_DY          # the last rear tyre: nothing in front of it but the mudflap
    src = im.crop((int(cx - c), int(cy - c), int(cx - c) + S, int(cy - c) + S))
    sp = src.load()
    disc = Image.new("RGBA", (S, S)); dp = disc.load()
    for y in range(S):
        for x in range(S):
            if (x + 0.5 - c) ** 2 + (y + 0.5 - c) ** 2 <= amb.WHEEL_R ** 2:
                dp[x, y] = (sp[x, S - 1 - y] if y < c - 13 else sp[x, y])[:3] + (255,)
    disc.save(os.path.join(DIR, "_disc.png"))
    amb.DIR, old = DIR, amb.DIR
    # reuse the ambulance's crisp 8x-vote rotation on this disc
    orig = Image.open
    Image.open = lambda p, *a, **k: (_Fake(disc) if p.endswith("shell_f1.png") else orig(p, *a, **k))
    try:
        amb.spin_strip()
    finally:
        Image.open = orig; amb.DIR = old
    os.remove(os.path.join(DIR, "_disc.png"))


class _Fake:
    """stands in for the ambulance shell: crop() at its tyre box returns this disc"""
    def __init__(self, disc): self.disc = disc
    def convert(self, *_): return self
    def crop(self, _box): return self.disc


if __name__ == "__main__":
    meta = {"wheel_size": amb.SIZE, "spin_frames": amb.SPIN_N, "floors": {}}
    for n in (2, 3):
        meta["floors"][str(n)] = f = one(n)
        print(n, f["size"], "head", f["head"], "marker", f["marker"], len(f["tails"]), "tails, sign", f["sign"], len(f["glyphs"]), "glyphs")
    json.dump(meta, open(os.path.join(DIR, "anim.json"), "w"), indent=1)
    spin_strip()
    print("wrote anim.json + wheel_spin.png")
