#!/usr/bin/env python3
"""MV-726 vehicle micro animations: anchor points + wheel spin strip for Dr. Ren's ambulance (world v2).

Reads assets/vehicles/ambulance_v3/shell_f<n>.png (MV-715) and writes, next to them:
  anim.json       per floor count: wheel centres, lamp spots (headlight, amber marker, roof light bar halves,
                  roof lantern, rear tail lights, mast tip) and the roof flag's cloth rect; all in shell px
  wheel_spin.png  24-frame strip (47x47 each) of one tyre rolling forward (counter-clockwise: the cab faces west)
Run it again whenever the shells are rebuilt (designs/dr-ren-ambulance/mf/shell.py); the autotest checks that
anim.json still matches the shell sizes. Code only, no PixelLab.
"""
import json, math, os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR = os.path.join(ROOT, "assets", "vehicles", "ambulance_v3")
WHEEL_R = 22.5          # tyre radius (shell px); contact run is 17 px wide, centre 23 px above the bottom row
WHEEL_DY = 23           # wheel centre row = shell height - WHEEL_DY
SPIN_N = 24
SIZE = 47               # wheel sprite, centre (23.5, 23.5)


def blobs(im, pred, box):
    px = im.load(); seen = set(); out = []
    x0, y0, x1, y1 = box
    for y in range(max(0, y0), min(im.height, y1)):
        for x in range(max(0, x0), min(im.width, x1)):
            if (x, y) in seen or not (px[x, y][3] and pred(px[x, y])):
                continue
            st = [(x, y)]; pts = []
            while st:
                a, b = st.pop()
                if (a, b) in seen or not (x0 <= a < x1 and y0 <= b < y1) or not (0 <= a < im.width and 0 <= b < im.height):
                    continue
                q = px[a, b]
                if not (q[3] and pred(q)):
                    continue
                seen.add((a, b)); pts.append((a, b)); st += [(a + 1, b), (a - 1, b), (a, b + 1), (a, b - 1)]
            xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
            out.append({"n": len(pts), "rect": [min(xs), min(ys), max(xs) + 1 - min(xs), max(ys) + 1 - min(ys)],
                        "c": [(min(xs) + max(xs) + 1) / 2, (min(ys) + max(ys) + 1) / 2]})
    return out


RED = lambda p: p[0] > 170 and p[1] < 80 and p[2] < 80                       # tail lamps
BAR = lambda p: p[0] > 135 and p[1] < 60 and p[2] < 55                        # roof light bar lens
YEL = lambda p: p[0] > 200 and p[1] > 160 and p[2] < 170 and p[0] - p[2] > 50  # headlight, lantern flame
CLOTH = lambda p: True


def wheels(im):
    px = im.load(); W, H = im.size; out = []; x = 0
    low = [any(px[x, y][3] for y in (H - 1, H - 2)) for x in range(W)]
    while x < W:
        if low[x]:
            s = x
            while x < W and low[x]:
                x += 1
            if x - s >= 12:
                out.append([(s + x) / 2, H - WHEEL_DY + 0.5])
        x += 1
    return out


def one(n):
    im = Image.open(os.path.join(DIR, f"shell_f{n}.png")).convert("RGBA"); W, H = im.size; D = H - 240
    big = lambda bs: max(bs, key=lambda b: b["n"])
    head = big(blobs(im, YEL, (0, 160 + D, 30, 190 + D)))
    marker = big(blobs(im, YEL, (60, 150 + D, 80, 170 + D)))
    bar = big(blobs(im, BAR, (85, 80 + D, 120, 95 + D)))
    lantern = big(blobs(im, YEL, (100, 60, 125, 100)))
    tails = [b for b in blobs(im, RED, (600, 0, W, H)) if b["n"] >= 4]
    # mast tip: topmost opaque pixel over the rear roof
    px = im.load(); tip = None
    for y in range(H):
        xs = [x for x in range(575, 605) if px[x, y][3]]
        if xs:
            tip = [sum(xs) / len(xs) + 0.5, y + 0.5]; break
    # flag cloth: the red cross, grown over every opaque pixel right of the pole
    cross = big(blobs(im, BAR, (133, 0, 160, 60)))
    cx, cy = int(cross["c"][0]), int(cross["c"][1])
    cloth = [b for b in blobs(im, CLOTH, (133, cy - 14, 165, cy + 14)) if b["rect"][0] <= cx < b["rect"][0] + b["rect"][2]]
    bx, by, bw, bh = bar["rect"]
    return {"size": [W, H], "wheels": wheels(im), "wheel_r": WHEEL_R,
            "head": head["c"], "marker": marker["c"], "bar_l": [bx + bw / 4, by + bh / 2], "bar_r": [bx + bw * 3 / 4, by + bh / 2],
            "bar": bar["rect"], "lantern": lantern["c"], "tails": [t["c"] for t in tails], "mast": tip,
            "flag": big(cloth)["rect"], **lantern_flicker(im, lantern["c"])}


LANTERN_PL = os.path.join(ROOT, "tools", "art", "ambulance", "lantern_pl.png")   # MV-741 PixelLab flicker, 8 x 18x22
PL_W, PL_C = 18, (8.5, 13.0)                                                         # frame width, glass centre in a frame
WARM = lambda p: p[3] and p[0] > 150 and p[0] - p[2] > 40


def lantern_flicker(im, c):
    """MV-741: the PixelLab flame frames mapped onto this shell's lantern glass (aligned on the glass centre).
    Returns {lantern_px: [[x, y]...], lantern_frames: [[hex...] per frame], lantern_glow: [0..1 per frame]}"""
    if not os.path.exists(LANTERN_PL):
        return {}
    px = im.load(); cx, cy = c
    glass = [[x, y] for y in range(int(cy) - 8, int(cy) + 8) for x in range(int(cx) - 6, int(cx) + 7)
             if WARM(px[x, y]) and (x + .5 - cx) ** 2 + (y + .5 - cy) ** 2 <= 49]
    strip = Image.open(LANTERN_PL).convert("RGBA"); sp = strip.load(); n = strip.width // PL_W
    frames, glow = [], []
    for i in range(n):
        cols, lum = [], 0.0
        for x, y in glass:
            fx = int(round(PL_C[0] + (x + .5 - cx) - .5)) + i * PL_W; fy = int(round(PL_C[1] + (y + .5 - cy) - .5))
            q = sp[fx, fy] if 0 <= fx - i * PL_W < PL_W and 0 <= fy < strip.height else (0, 0, 0, 0)
            q = q if q[3] else px[x, y]
            cols.append("%02x%02x%02x" % q[:3]); lum += 0.3 * q[0] + 0.59 * q[1] + 0.11 * q[2]
        frames.append(cols); glow.append(lum / max(1, len(glass)))
    hi, lo = max(glow), min(glow)
    glow = [round(0.55 + 0.45 * (g - lo) / (hi - lo if hi > lo else 1), 3) for g in glow]
    return {"lantern_px": glass, "lantern_frames": frames, "lantern_glow": glow}


def spin_strip():
    im = Image.open(os.path.join(DIR, "shell_f1.png")).convert("RGBA")
    src = im.crop((208, 217 - 23, 208 + SIZE, 217 - 23 + SIZE))       # the isolated first rear tyre, centre (231.5, 217.5)
    c = SIZE / 2
    sp = src.load()
    disc = Image.new("RGBA", (SIZE, SIZE)); dp = disc.load()
    for y in range(SIZE):
        for x in range(SIZE):
            if (x + 0.5 - c) ** 2 + (y + 0.5 - c) ** 2 <= WHEEL_R ** 2:
                # the top of the tyre hides in the wheel arch (chassis pixels): mirror the clean lower tread up there
                dp[x, y] = (sp[x, SIZE - 1 - y] if y < c - 13 else sp[x, y])[:3] + (255,)
    out = Image.new("RGBA", (SIZE * SPIN_N, SIZE))
    k = 8
    up = disc.resize((SIZE * k, SIZE * k), Image.NEAREST)
    for i in range(SPIN_N):
        # PIL rotates counter-clockwise for positive angles: frame i+1 = the tyre rolled further west.
        # Nearest rotate at 8x, then each 8x8 block takes its most common colour: no blended (blurry) pixels
        rot = up.rotate(360.0 * i / SPIN_N, resample=Image.NEAREST, center=(SIZE * k / 2, SIZE * k / 2)).load()
        fr = Image.new("RGBA", (SIZE, SIZE)); fp = fr.load()
        for y in range(SIZE):
            for x in range(SIZE):
                if not dp[x, y][3]:
                    continue
                if math.hypot(x + 0.5 - c, y + 0.5 - c) > WHEEL_R - 1.5:
                    fp[x, y] = dp[x, y]                                   # crisp outline ring
                    continue
                votes = {}
                for yy in range(y * k + 1, y * k + k, 2):
                    for xx in range(x * k + 1, x * k + k, 2):
                        q = rot[xx, yy]
                        if q[3]:
                            votes[q] = votes.get(q, 0) + 1
                fp[x, y] = max(votes, key=votes.get) if votes else dp[x, y]
        out.paste(fr, (SIZE * i, 0))
    out.save(os.path.join(DIR, "wheel_spin.png"))


if __name__ == "__main__":
    meta = {"wheel_size": SIZE, "spin_frames": SPIN_N, "floors": {}}
    for n in range(1, 6):
        if os.path.exists(os.path.join(DIR, f"shell_f{n}.png")):
            meta["floors"][str(n)] = one(n)
            f = meta["floors"][str(n)]
            print(n, f["size"], len(f["wheels"]), "wheels,", len(f["tails"]), "tails, flag", f["flag"], "lantern", f["lantern"])
    json.dump(meta, open(os.path.join(DIR, "anim.json"), "w"), indent=1)
    spin_strip()
    print("wrote anim.json + wheel_spin.png")
