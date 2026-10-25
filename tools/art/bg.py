"""Grim 16-bit parallax backgrounds per biome: smog sky strip, a pale sun behind the haze, drifting smoke banks,
far skyline / hills, mid ruins, near props, road. Each layer is 480 px wide and wraps horizontally; bottoms line up
on the road so the Background node can stack them from the road up. Atmospheric perspective: the further the
layer, the more it melts into the horizon haze (dithered)."""
import math, os, random
from .common import *

BW = 480
SKY_H = 900

BIOMES = {
    "industrial": dict(sky=["night1", "purple1", "purple2", "dusk1", "dusk2", "dusk3"], sun="lamp1", cloud="gray2", cshade="night1",
                       far=("purple1", "night2"), mid=("gray2", "wood1", "orange0"), near="gray1", road="gray2", ground="wood0",
                       dash="yellow1", lit="lamp1", haze="dusk1"),
    "desert": dict(sky=["night1", "dusk0", "dusk1", "dusk2", "sand2", "sand3"], sun="lamp2", cloud="sand1", cshade="dusk0",
                   far=("dusk1", "sand1"), mid=("sand1", "sand2", "orange0"), near="wood1", road="sand1", ground="sand1",
                   dash="cream1", lit="lamp1", haze="sand2"),
    "forest": dict(sky=["night1", "night2", "teal0", "green1", "green2", "green3"], sun="cream3", cloud="green1", cshade="night1",
                   far=("green1", "teal0"), mid=("green1", "green2", "wood1"), near="green0", road="wood1", ground="green0",
                   dash="wood2", lit="toxic3", haze="green2"),
    "swamp": dict(sky=["night1", "purple1", "teal0", "toxic0", "toxic1", "toxic2"], sun="toxic3", cloud="teal0", cshade="night0",
                  far=("purple0", "teal0"), mid=("gray1", "teal0", "gray2"), near="night1", road="wood0", ground="toxic0",
                  dash="toxic2", lit="toxic3", haze="toxic1"),
    "tundra": dict(sky=["night1", "blue1", "blue2", "blue3", "snow1", "snow2"], sun="snow3", cloud="snow0", cshade="blue1",
                   far=("blue2", "snow0"), mid=("blue1", "snow1", "blue0"), near="blue1", road="gray3", ground="snow2",
                   dash="snow3", lit="lamp1", haze="snow1"),
    "metro": dict(sky=["night0", "night1", "purple1", "purple2", "red1", "dusk1"], sun="red3", cloud="purple1", cshade="night0",
                  far=("night2", "purple1"), mid=("night1", "gray1", "night2"), near="night0", road="gray1", ground="night1",
                  dash="yellow1", lit="lamp1", haze="red1"),
}


def wrap(fn):
    for off in (-BW, 0, BW):
        fn(off)


def haze(img, col, top_t=0.2, bot_t=0.75):
    """atmospheric perspective: dithered blend towards the horizon haze, stronger near the bottom"""
    H = img.height
    for y in range(H):
        t = top_t + (bot_t - top_t) * (y / max(1, H - 1))
        for x in range(img.width):
            p = get(img, x, y)
            if p[3]:
                k = t if bayer(x, y) < 0.5 else t * 0.8
                px(img, x, y, blend(p, col, k))
    return img


def soft_outline(img, col):
    """1px outline around opaque shapes (only where the outside is transparent)"""
    return outline_alpha(img, col)


# ------------------------------------------------------------------ sky / sun / clouds
def sky_strip(name, cfg):
    img = new(64, SKY_H)
    cols = [c(k) for k in cfg["sky"]]
    stops = [(0.0, cols[0]), (0.4, cols[1]), (0.62, cols[2]), (0.78, cols[3]), (0.9, cols[4]), (1.0, cols[5])]
    gradient_v(img, 0, 0, 64, SKY_H, stops, dither=True)
    save(img, os.path.join(OUT_BG, f"{name}_sky.png"))


def sun(name, cfg):
    S = 72
    img = new(S, S)
    col = c(cfg["sun"])
    for r, a in ((34, 40), (27, 80), (21, 130)):
        for y in range(S):
            for x in range(S):
                if math.hypot(x - S / 2 + 0.5, y - S / 2 + 0.5) <= r and bayer(x, y) < a / 255:
                    px(img, x, y, col[:3] + (255,))
    ellipse(img, S // 2 - 14, S // 2 - 14, 28, 28, col)
    for y in (S // 2 + 3, S // 2 + 7, S // 2 + 10):       # smog bands crossing the disc
        hline(img, 0, y, S, CLEAR)
    img.save(os.path.join(OUT_BG, f"{name}_sun.png"))


def smog_bank(img, cx, cy, w, h, fill, shade, rng, off):
    """long ragged smoke streak with a dithered fringe (no outline)"""
    for y in range(cy - h, cy + h + 1):
        t = abs(y - cy) / max(1, h)
        half = int(w / 2 * (1 - t * t)) + rng.randint(-3, 3)
        for x in range(cx - half, cx + half):
            edge = min(x - (cx - half), cx + half - x) / max(1, half)
            if bayer(x, y) < min(1.0, edge * 3.0) * (1 - t * 0.6):
                px(img, (x + off) % BW, y, shade if y > cy else fill)


def clouds(name, cfg):
    H = 220
    img = new(BW, H)
    rng = random.Random(len(name) * 31)
    fill = c(cfg["cloud"])
    shade = c(cfg["cshade"])
    for _ in range(10):
        cx = rng.randint(0, BW)
        cy = rng.randint(14, H - 14)
        w = rng.randint(80, 200)
        h = rng.randint(3, 8)
        smog_bank(img, cx, cy, w, h, fill, shade, random.Random(rng.randint(0, 9999)), 0)
    save(img, os.path.join(OUT_BG, f"{name}_clouds.png"))


# ------------------------------------------------------------------ helpers for buildings
def ruin(img, x, w, h, H, col, win_col, rng, broken=True, lit=None, roof=None):
    top = H - h
    rect(img, x, top, w, h, col)
    vline(img, x, top, h, blend(col, c("gray6"), 0.25))
    hl = blend(col, c("gray6"), 0.3)
    hline(img, x, top, w, hl)
    if roof:
        rect(img, x - 1, top - 2, w + 2, 3, c(roof))
    for wy in range(top + 5, H - 4, 8):
        for wx in range(x + 3, x + w - 4, 6):
            r = rng.random()
            if r < 0.08 and lit:
                rect(img, wx, wy, 3, 4, lit)
            elif r < 0.85:
                rect(img, wx, wy, 3, 4, win_col)
    if broken and rng.random() < 0.6:
        cut = rng.randint(6, max(8, h // 3))
        poly(img, [(x + w // 3, top - 1), (x + w + 1, top - 1), (x + w + 1, top + cut)], CLEAR)


def pine(img, x, base, h, col, dk, snow=None):
    rect(img, x - 1, base - 4, 3, 4, c("wood1"))
    for k in range(3):
        y0 = base - 4 - k * (h // 4)
        w = (h // 2) - k * (h // 8)
        poly(img, [(x - w // 2, y0), (x, y0 - h // 2), (x + w // 2, y0)], col)
        line(img, x, y0 - h // 2, x + w // 2, y0, dk)
        if snow:
            poly(img, [(x - 3, y0 - h // 2 + 5), (x, y0 - h // 2), (x + 3, y0 - h // 2 + 5)], c(snow))


def round_tree(img, x, base, h, col, lite, trunk="wood1"):
    rect(img, x - 2, base - h // 2, 4, h // 2, c(trunk))
    r = h // 2
    ellipse(img, x - r, base - h - r // 3, r * 2, r + r // 2, col)
    ellipse(img, x - r + 3, base - h - r // 3 + 2, r, r // 2, lite)


# ------------------------------------------------------------------ far layer
def far(name, cfg):
    H = 300
    img = new(BW, H)
    rng = random.Random(len(name) * 77)
    col = blend(c(cfg["far"][0]), c(cfg["far"][1]), 0.45)
    dk = blend(col, c("ol0"), 0.12)
    if name in ("industrial", "metro"):
        x = 0
        while x < BW:
            w = rng.randint(16, 34)
            h = rng.randint(50, 190 if name == "metro" else 130)
            seed = rng.randint(0, 9999)

            def d(off, x=x, w=w, h=h, seed=seed):
                ruin(img, x + off, w, h, H, col, dk, random.Random(seed), broken=name != "metro",
                     lit=c(cfg["lit"]) if name == "metro" else None)
            wrap(d)
            x += w + rng.randint(-2, 8)
        if name == "metro":
            def d(off):
                rect(img, 230 + off, 30, 16, H - 30, blend(col, c("ol0"), 0.1))
                poly(img, [(226 + off, 50), (238 + off, 4), (250 + off, 50)], blend(col, c("ol0"), 0.1))
                ellipse(img, 233 + off, 0, 10, 10, c("yellow3"))
                for y in range(40, H, 10):
                    hline(img, 232 + off, y, 12, c("pink2"))
            wrap(d)
    elif name == "desert":
        pts = [(0, H)]
        for x in range(0, BW + 1, 6):
            pts.append((x, int(H - 60 - 20 * math.sin(x / BW * math.tau * 2 + 1))))
        pts.append((BW, H))
        poly(img, pts, blend(col, c("sand3"), 0.4))
        for mx, mw, mh in ((40, 100, 130), (300, 120, 110)):
            def d(off, mx=mx, mw=mw, mh=mh):
                poly(img, [(mx + off, H), (mx + off + 10, H - mh), (mx + off + mw - 10, H - mh - 4), (mx + off + mw, H)], col)
                hline(img, mx + off + 10, H - mh - 1, mw - 20, blend(col, c("gray6"), 0.3))
                for k in range(3):
                    hline(img, mx + off + 6, H - mh + 30 + k * 26, mw - 12, dk)
            wrap(d)
    elif name == "tundra":
        pts = [(0, H)]
        for x in range(0, BW + 1, 6):
            pts.append((x, int(H - 140 - 70 * abs(math.sin(x / BW * math.pi * 3)) - rng.randint(0, 4))))
        pts.append((BW, H))
        mcol = c("blue3")
        poly(img, pts, mcol)
        for x in range(BW):
            line_y = H - 172 + int(8 * math.sin(x * 0.17)) + int(4 * math.sin(x * 0.05))
            for y in range(0, line_y):
                if get(img, x, y)[:3] == mcol[:3]:
                    px(img, x, y, c("snow3"))
    else:   # forest / swamp: rolling hills of round tree tops
        for row, (cc, base) in enumerate(((col, H - 60), (blend(col, c("ol0"), 0.1), H - 20))):
            pts = [(0, H)]
            for x in range(0, BW + 1, 4):
                pts.append((x, int(base - 40 - 24 * math.sin(x / BW * math.tau * (2 + row) + row))))
            pts.append((BW, H))
            poly(img, pts, cc)
            for x in range(0, BW, 14):
                def d(off, x=x, row=row, base=base, cc=cc):
                    y = int(base - 40 - 24 * math.sin(x / BW * math.tau * (2 + row) + row))
                    ellipse(img, x + off - 8, y - 6, 18, 14, cc)
                    ellipse(img, x + off - 4, y - 4, 7, 4, blend(cc, c("gray6"), 0.2))
                wrap(d)
        if name == "swamp":
            def d(off):
                for tx in (80, 300):
                    rect(img, tx + off, H - 200, 12, 200, c("gray3"))
                    for y in range(H - 190, H, 16):
                        hline(img, tx + off - 2, y, 16, c("gray2"))
                    ellipse(img, tx + off + 1, H - 214, 10, 14, c("toxic3"))
                    ellipse(img, tx + off + 3, H - 210, 6, 8, c("yellow3"))
            wrap(d)
    img = haze(img, c(cfg["haze"]), 0.25, 0.6)
    save(img, os.path.join(OUT_BG, f"{name}_far.png"))


# ------------------------------------------------------------------ mid layer
def mid(name, cfg):
    H = 230
    img = new(BW, H)
    rng = random.Random(len(name) * 131)
    col = c(cfg["mid"][0])
    lt = c(cfg["mid"][1])
    acc = c(cfg["mid"][2])
    win = blend(col, c("night1"), 0.55)
    if name in ("industrial", "metro"):
        x = 0
        while x < BW:
            w = rng.randint(30, 54)
            h = rng.randint(60, 170)
            seed = rng.randint(0, 9999)
            pick = rng.choice([col, lt, acc]) if name == "industrial" else rng.choice([col, lt])

            def d(off, x=x, w=w, h=h, seed=seed, pick=pick):
                r2 = random.Random(seed)
                ruin(img, x + off, w, h, H, pick, blend(pick, c("night1"), 0.5), r2, broken=True,
                     lit=c(cfg["lit"]), roof="gray3" if name == "industrial" else None)
                if name == "metro" and r2.random() < 0.6:
                    bx, by = x + off + 4, H - h + r2.randint(8, 30)
                    bw = min(w - 8, 24)
                    rect(img, bx, by, bw, 10, c("night1"))
                    frame(img, bx, by, bw, 10, c(r2.choice(["pink2", "teal2", "yellow2"])))
                    for k in range(2):
                        hline(img, bx + 3, by + 3 + k * 3, r2.randint(6, bw - 5), c(r2.choice(["pink3", "teal3"])))
                if name == "industrial" and r2.random() < 0.5:
                    for k in range(r2.randint(2, 6)):
                        vline(img, x + off + r2.randint(1, w - 2), H - h + 1, r2.randint(4, 16), c("green2"))
            wrap(d)
            x += w + rng.randint(8, 30)
        if name == "industrial":
            def d(off):     # water tower + crane
                for lx in (378, 402):
                    vline(img, lx + off, H - 90, 90, c("gray3"))
                ellipse(img, 370 + off, H - 120, 42, 36, c("red2"))
                rect(img, 370 + off, H - 104, 42, 12, c("red2"))
                hline(img, 372 + off, H - 106, 38, c("red3"))
                vline(img, 120 + off, H - 200, 200, c("yellow1"))
                hline(img, 90 + off, H - 196, 90, c("yellow1"))
                line(img, 120 + off, H - 210, 176 + off, H - 196, c("yellow1"))
                vline(img, 170 + off, H - 196, 40, c("gray2"))
                rect(img, 166 + off, H - 156, 9, 6, c("orange2"))
            wrap(d)
    elif name == "desert":
        pts = [(0, H)]
        for x in range(0, BW + 1, 4):
            pts.append((x, int(H - 40 - 16 * math.sin(x / BW * math.tau * 3 + 0.5))))
        pts.append((BW, H))
        for x in (40, 200, 340):
            def d(off, x=x):
                poly(img, [(x + off, H - 30), (x + off + 6, H - 140), (x + off + 36, H - 150), (x + off + 44, H - 30)], acc)
                for wy in range(H - 136, H - 40, 8):
                    for wx in range(x + off + 9, x + off + 36, 6):
                        rect(img, wx, wy, 3, 4, blend(acc, c("night1"), 0.5))
            wrap(d)
        poly(img, pts, col)
        for x in range(0, BW, 4):
            y = int(H - 40 - 16 * math.sin(x / BW * math.tau * 3 + 0.5))
            hline(img, x, y, 4, lt)
    elif name == "tundra":
        x = 0
        while x < BW:
            w = rng.randint(30, 50)
            h = rng.randint(50, 120)
            seed = rng.randint(0, 9999)

            def d(off, x=x, w=w, h=h, seed=seed):
                r2 = random.Random(seed)
                ruin(img, x + off, w, h, H, col, c("blue1"), r2, broken=True, lit=c(cfg["lit"]))
                rect(img, x + off - 1, H - h - 2, w + 2, 4, c("snow3"))
                for k in range(0, w, 7):
                    ellipse(img, x + off + k - 1, H - h - 4, 8, 5, c("snow3"))
            wrap(d)
            x += w + rng.randint(30, 60)
        for x in range(10, BW, 26):
            def d(off, x=x):
                pine(img, x + off, H, 50 + (x * 7) % 30, c("teal1"), c("teal0"), snow="snow3")
            wrap(d)
    else:   # forest / swamp
        trees = 6 if name == "forest" else 8
        for k in range(trees):
            x = k * (BW // trees) + rng.randint(0, 20)
            h = rng.randint(70, 130)

            def d(off, x=x, h=h):
                if name == "forest":
                    round_tree(img, x + off, H, h, col, lt)
                else:
                    line(img, x + off, H, x + off - 2, H - h, c("gray2"), 4)
                    for j in range(4):
                        line(img, x + off - 2, H - h + j * 12, x + off - 14 + j * 8, H - h - 10 + j * 10, c("gray2"), 2)
                    for j in range(3):
                        vline(img, x + off - 6 + j * 5, H - h + 4 + j * 6, 10 + j * 3, c("green2"))
            wrap(d)
        if name == "forest":
            def d(off):     # overgrown ruined house
                rect(img, 220 + off, H - 70, 60, 70, c("cream1"))
                poly(img, [(214 + off, H - 70), (250 + off, H - 100), (286 + off, H - 70)], c("red1"))
                poly(img, [(250 + off, H - 100), (286 + off, H - 70), (270 + off, H - 70)], CLEAR)
                for wx in (230, 256):
                    rect(img, wx + off, H - 56, 12, 12, c("night1"))
                for k in range(0, 60, 3):
                    vline(img, 220 + off + k, H - 70, (k * 13) % 30, c("green2"))
            wrap(d)
        else:
            def d(off):     # leaking chemical silos (radiation zone)
                for tx in (150, 380):
                    rect(img, tx + off, H - 110, 34, 110, c("gray4"))
                    ellipse(img, tx + off, H - 118, 34, 14, c("gray5"))
                    rect(img, tx + off + 8, H - 80, 18, 16, c("yellow2"))
                    ellipse(img, tx + off + 12, H - 77, 10, 10, c("ol0"))
                    ellipse(img, tx + off + 15, H - 74, 4, 4, c("yellow2"))
                    for k in range(5):
                        vline(img, tx + off + 4 + k * 6, H - 60, 10 + (k * 7) % 30, c("toxic3"))
            wrap(d)
    img = haze(img, c(cfg["haze"]), 0.05, 0.35)
    img = soft_outline(img, c("ol0"))
    save(img, os.path.join(OUT_BG, f"{name}_mid.png"))


# ------------------------------------------------------------------ near layer
def bush(img, x, base, w, col):
    lite = blend(col, c("gray6"), 0.3)
    for k in range(max(2, w // 10)):
        ellipse(img, x + k * 8, base - 12 - (k % 2) * 3, 14, 14, col)
    ellipse(img, x + 3, base - 12, 6, 4, lite)


def rad_barrel(img, x, base):
    rect(img, x, base - 14, 11, 14, c("ol0"))
    rect(img, x + 1, base - 13, 9, 13, c("yellow2"))
    rect(img, x + 2, base - 13, 2, 13, c("yellow3"))
    hline(img, x + 1, base - 10, 9, c("ol0"))
    hline(img, x + 1, base - 4, 9, c("ol0"))
    ellipse(img, x + 3, base - 9, 5, 5, c("ol0"))
    px(img, x + 5, base - 7, c("yellow2"))
    ellipse(img, x - 2, base - 17, 6, 4, c("toxic3"))


def near(name, cfg):
    H = 130
    img = new(BW, H)
    rng = random.Random(len(name) * 991)
    col = c(cfg["near"])
    g = c(cfg["ground"])
    rect(img, 0, H - 14, BW, 14, g)
    hline(img, 0, H - 14, BW, blend(g, c("gray6"), 0.3))
    for x in range(0, BW, 3):
        if rng.random() < 0.4:
            vline(img, x, H - 16, 2, blend(g, c("ol0"), 0.15))
    if name in ("industrial", "metro"):
        for x in (30, 250):
            def d(off, x=x):
                rect(img, x + off, 8, 4, H - 22, c("gray4") if name == "metro" else c("wood1"))
                rect(img, x + off - 10, 8, 22, 3, c("gray3"))
                ellipse(img, x + off - 12, 10, 6, 5, c(cfg["lit"]))
            wrap(d)
        for xa, xb in ((34, 254), (254, 514)):
            for t in range(0, 101):
                xx = xa + (xb - xa) * t / 100
                yy = 12 + 14 * math.sin(math.pi * t / 100)
                px(img, int(xx) % BW, int(yy), c("ol1"))

        def d(off):    # cute wrecked car, cones, fence
            rect(img, 120 + off, H - 32, 52, 16, c("sky1") if name == "industrial" else c("pink2"))
            rect(img, 130 + off, H - 44, 32, 13, c("sky1") if name == "industrial" else c("pink2"))
            rect(img, 134 + off, H - 41, 10, 8, c("sky3"))
            rect(img, 148 + off, H - 41, 10, 8, c("night1"))
            for wx in (126, 156):
                ellipse(img, wx + off, H - 22, 12, 12, c("gray1"))
                ellipse(img, wx + off + 3, H - 19, 6, 6, c("gray4"))
            for k in range(3):
                poly(img, [(330 + off + k * 12, H - 14), (334 + off + k * 12, H - 28), (338 + off + k * 12, H - 14)], c("orange2"))
                hline(img, 332 + off + k * 12, H - 20, 5, c("gray6"))
            for fx in range(380, 470, 8):
                vline(img, fx + off, H - 40, 26, c("cream2"))
                poly(img, [(fx + off - 1, H - 40), (fx + off + 2, H - 44), (fx + off + 4, H - 40)], c("cream2"))
            hline(img, 378 + off, H - 34, 94, c("cream1"))
            hline(img, 378 + off, H - 22, 94, c("cream1"))
            bush(img, 200 + off, H - 14, 40, c("green2"))
            bush(img, 40 + off, H - 14, 30, c("green3"))
        wrap(d)
    elif name == "desert":
        for x in (80, 330):
            def d(off, x=x):
                cc = c("green2")
                rect(img, x + off, H - 62, 9, 48, cc)
                vline(img, x + off + 2, H - 60, 44, c("green3"))
                rect(img, x + off - 8, H - 46, 8, 6, cc)
                rect(img, x + off - 8, H - 58, 6, 14, cc)
                rect(img, x + off + 9, H - 40, 8, 6, cc)
                rect(img, x + off + 12, H - 52, 6, 14, cc)
                px(img, x + off + 4, H - 64, c("pink2"))
            wrap(d)

        def d(off):
            ellipse(img, 190 + off, H - 26, 18, 14, c("gray6"))
            rect(img, 194 + off, H - 21, 3, 3, c("ol0"))
            rect(img, 201 + off, H - 21, 3, 3, c("ol0"))
            line(img, 420 + off, H - 14, 436 + off, 10, c("wood1"), 3)
            rect(img, 420 + off, 12, 30, 12, c("red2"))
            hline(img, 424 + off, 17, 22, c("gray6"))
            for k in range(4):
                ellipse(img, 260 + off + k * 30, H - 18, 26, 8, c("sand3"))
        wrap(d)
    elif name == "forest":
        for x in range(0, BW, 26):
            def d(off, x=x):
                h = 14 + (x * 7) % 18
                bush(img, x + off, H - 14, 26, col if x % 52 else blend(col, c("teal1"), 0.3))
                if x % 78 == 0:
                    for k in range(3):
                        px(img, x + off + 6 + k * 6, H - 22 - h // 3, c(["pink2", "yellow3", "gray6"][k]))
            wrap(d)

        def d(off):
            rect(img, 40 + off, H - 34, 40, 20, c("orange1"))
            rect(img, 46 + off, H - 44, 26, 12, c("orange1"))
            for k in range(0, 40, 3):
                vline(img, 40 + off + k, H - 34, (k * 7) % 14, c("green3"))
            line(img, 300 + off, H - 14, 316 + off, 4, c("wood1"), 3)
            rect(img, 302 + off, 6, 28, 12, c("green1"))
            hline(img, 306 + off, 11, 20, c("gray6"))
        wrap(d)
    elif name == "swamp":
        rect(img, 0, H - 14, BW, 14, c("toxic1"))
        for x in range(0, BW, 6):
            if rng.random() < 0.45:
                hline(img, x, H - 10 + rng.randint(0, 6), rng.randint(2, 6), c("toxic3"))
        for x in range(0, BW, 34):
            def d(off, x=x):
                for k in range(4):
                    vline(img, x + off + 20 + k * 2, H - 26 - k * 3, 12 + k * 3, c("green2"))
                    px(img, x + off + 20 + k * 2, H - 27 - k * 3, c("wood1"))
            wrap(d)
        for x in (60, 200, 410):
            def d(off, x=x):
                rad_barrel(img, x + off, H - 12)
                rad_barrel(img, x + off + 13, H - 10)
            wrap(d)

        def d(off):
            vline(img, 300 + off, H - 60, 46, c("wood1"))
            poly(img, [(288 + off, H - 60), (300 + off, H - 80), (312 + off, H - 60)], c("yellow2"))
            ellipse(img, 296 + off, H - 70, 8, 7, c("ol0"))
            px(img, 300 + off, H - 67, c("yellow2"))
        wrap(d)
    else:   # tundra
        for x in range(0, BW, 64):
            def d(off, x=x):
                pine(img, x + off + 20, H - 12, 60, c("teal1"), c("teal0"), snow="snow3")
            wrap(d)
        for x in range(0, BW, 40):
            def d(off, x=x):
                ellipse(img, x + off, H - 22, 30, 14, c("snow3"))
                hline(img, x + off + 6, H - 20, 14, c("gray6"))
            wrap(d)

        def d(off):
            rect(img, 200 + off, H - 32, 50, 18, c("red1"))
            rect(img, 210 + off, H - 42, 26, 12, c("red1"))
            rect(img, 198 + off, H - 34, 54, 4, c("snow3"))
            rect(img, 208 + off, H - 44, 30, 3, c("snow3"))
        wrap(d)
    img = soft_outline(img, c("ol0"))
    save(img, os.path.join(OUT_BG, f"{name}_near.png"))


# ------------------------------------------------------------------ road
def road(name, cfg):
    H = 64
    img = new(BW, H)
    g = c(cfg["ground"])
    r_ = c(cfg["road"])
    rng = random.Random(9)
    rect(img, 0, 0, BW, 5, g)
    for x in range(0, BW, 4):
        px(img, x + rng.randint(0, 3), rng.randint(0, 3), blend(g, c("ol0"), 0.15))
    rect(img, 0, 5, BW, H - 5, r_)
    hline(img, 0, 5, BW, c("ol0"))
    hline(img, 0, 6, BW, blend(r_, c("gray6"), 0.3))
    hline(img, 0, 7, BW, blend(r_, c("gray6"), 0.15))
    for _ in range(140):
        px(img, rng.randint(0, BW - 1), rng.randint(9, H - 2), blend(r_, c("ol0"), 0.15))
    for x in range(0, BW, 48):
        rect(img, x + 6, 30, 24, 3, c(cfg["dash"]))
        hline(img, x + 6, 33, 24, blend(r_, c("ol0"), 0.2))
    for _ in range(10):
        x = rng.randint(0, BW - 1)
        y = rng.randint(12, H - 6)
        for k in range(rng.randint(5, 12)):
            px(img, (x + k) % BW, y, blend(r_, c("ol0"), 0.35))
            y += rng.choice([-1, 0, 1])
            y = max(10, min(H - 2, y))
    for x in (70, 230, 400):
        ellipse(img, x, 42, 18, 6, blend(r_, c("ol0"), 0.35))
        hline(img, x + 4, 46, 10, blend(r_, c("gray6"), 0.2))
    if name == "tundra":
        for x in range(0, BW, 50):
            ellipse(img, x, 48, 30, 8, c("snow3"))
            ellipse(img, x + 20, 14, 20, 5, c("snow3"))
    if name == "swamp":
        for x in range(0, BW, 90):
            ellipse(img, x + 20, 44, 30, 6, c("toxic2"))
            hline(img, x + 26, 44, 16, c("toxic3"))
    if name == "desert":
        for x in range(0, BW, 70):
            ellipse(img, x, 3, 40, 10, c("sand3"))
    save(img, os.path.join(OUT_BG, f"{name}_road.png"))


def gen_backgrounds():
    for name, cfg in BIOMES.items():
        sky_strip(name, cfg)
        sun(name, cfg)
        clouds(name, cfg)
        far(name, cfg)
        mid(name, cfg)
        near(name, cfg)
        road(name, cfg)
    from .industrial_bg import generate
    generate()
