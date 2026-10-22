"""Expedition live-feed backdrops: 256x100 seamless (tile horizontally) interiors the scavenging squad walks
through while the panel shows them working. One per kind of site; the feed scrolls deeper as the team explores.
Feet line is y=86. Grim 16-bit palette, baked low light with a few dying lamps."""
import math, os, random
from .common import *

W, H = 256, 100
FL = 86            # feet line (floor top)
OUT_EXP = os.path.join(ROOT, "assets", "exp")
os.makedirs(OUT_EXP, exist_ok=True)


# ------------------------------------------------------------------ kit
def blk(img, x, y, w, h, ramp, i=2):
    f = c(f"{ramp}{i}")
    hi = c(f"{ramp}{min(i + 1, len(RAMPS[ramp]) - 1)}")
    lo = c(f"{ramp}{max(i - 1, 0)}")
    rect(img, x, y, w, h, OL)
    rect(img, x + 1, y + 1, w - 2, h - 2, f)
    hline(img, x + 1, y + 1, w - 2, hi)
    vline(img, x + w - 2, y + 2, h - 3, lo)
    hline(img, x + 2, y + h - 2, w - 3, lo)


def shadow(img, x, w, y=FL):
    for xx in range(x, x + w):
        tint_px(img, xx % W, y, c("ol0"), 0.45)
        tint_px(img, xx % W, y + 1, c("ol0"), 0.25)


def wall(img, ramp_a, ramp_b, style, y0=8, y1=FL):
    rect(img, 0, y0, W, y1 - y0, c(ramp_a))
    cb = c(ramp_b)
    if style == "tile":
        for y in range(y0, y1, 8):
            hline(img, 0, y, W, cb)
            for x in range(((y - y0) // 8) % 2 * 4, W, 8):
                vline(img, x, y, 8, cb)
    elif style == "panel":
        for x in range(0, W, 32):
            vline(img, x, y0, y1 - y0, cb)
            for y in range(y0 + 3, y1, 10):
                px(img, x + 3, y, cb)
                px(img, x + 28, y, cb)
        hline(img, 0, y0 + 30, W, cb)
    elif style == "concrete":
        for y in range(y0, y1, 16):
            hline(img, 0, y, W, cb)
        for x in range(0, W, 64):
            vline(img, x, y0, y1 - y0, cb)
    elif style == "brick":
        for y in range(y0, y1, 5):
            hline(img, 0, y, W, cb)
            for x in range((y // 5) % 2 * 6, W, 12):
                vline(img, x, y, 5, cb)
    elif style == "rock":
        rr = random.Random(9)
        for _ in range(140):
            x, y = rr.randint(0, W - 1), rr.randint(y0, y1 - 4)
            w, h = rr.randint(6, 16), rr.randint(3, 7)
            for xx in range(x, x + w):
                px(img, xx % W, y, cb)
            for yy in range(y, min(y1, y + h)):
                px(img, x % W, yy, cb)


def ceiling(img, ramp="gray", i=1):
    rect(img, 0, 0, W, 8, c(f"{ramp}{i}"))
    hline(img, 0, 7, W, OL)
    for x in range(0, W, 16):
        vline(img, x, 0, 7, c(f"{ramp}{max(0, i - 1)}"))


def ground(img, ramp="gray", i=2, kind="tile"):
    rect(img, 0, FL, W, H - FL, c(f"{ramp}{i}"))
    hline(img, 0, FL, W, c(f"{ramp}{min(i + 2, len(RAMPS[ramp]) - 1)}"))
    hline(img, 0, FL + 1, W, OL)
    if kind == "tile":
        for x in range(0, W, 16):
            vline(img, x, FL + 2, H - FL - 2, c(f"{ramp}{max(0, i - 1)}"))
        hline(img, 0, FL + 8, W, c(f"{ramp}{max(0, i - 1)}"))
    elif kind == "dirt":
        rr = random.Random(4)
        for _ in range(160):
            px(img, rr.randint(0, W - 1), rr.randint(FL + 2, H - 1), c(f"{ramp}{rr.choice((max(0, i - 1), min(i + 1, 3)))}"))
    elif kind == "grate":
        for x in range(0, W, 4):
            vline(img, x, FL + 2, H - FL - 2, c(f"{ramp}{max(0, i - 1)}"))


def dead_lamp(img, x, lit=True):
    vline(img, x, 0, 10, OL)
    rect(img, x - 4, 10, 9, 3, OL)
    rect(img, x - 3, 10, 7, 2, c("lamp1") if lit else c("gray3"))
    if lit:
        light_cone(img, x - 4, 13, 9, 46, FL - 13, c("lamp1"), strength=0.22, steps=3, dither=True)


def grime(img, seed, y0=8, y1=FL):
    rr = random.Random(seed)
    for _ in range(14):
        sx, sy = rr.randint(2, W - 22), rr.randint(y0 + 2, y1 - 20)
        w, h = rr.randint(8, 20), rr.randint(5, 14)
        for yy in range(sy, sy + h):
            for xx in range(sx, sx + w):
                d = ((xx - sx - w / 2) / (w / 2)) ** 2 + ((yy - sy - h / 2) / (h / 2)) ** 2
                if d < 1 and bayer(xx, yy) < 0.6 * (1 - d) + 0.1:
                    tint_px(img, xx, yy, c("wood0"), 0.3)
    for _ in range(18):
        x = rr.randint(1, W - 2)
        for k in range(rr.randint(4, 16)):
            tint_px(img, x, y0 + k, c("orange1"), 0.5 - k * 0.03)
    for _ in range(4):
        x, y = rr.randint(4, W - 6), rr.randint(y0 + 6, y0 + 40)
        for k in range(rr.randint(6, 14)):
            px(img, x, y, blend(get(img, x, y), c("ol0"), 0.6))
            x = max(1, min(W - 2, x + rr.choice((-1, 0, 1))))
            y += 1
    for _ in range(4):        # dried blood smears low on the walls
        x, y = rr.randint(6, W - 20), rr.randint(y1 - 26, y1 - 8)
        for k in range(rr.randint(6, 14)):
            tint_px(img, x + k, y + (k // 4), c("red1"), 0.55)
            if rr.random() < 0.4:
                for d in range(rr.randint(1, 5)):
                    tint_px(img, x + k, y + (k // 4) + d, c("red1"), 0.45)


def debris(img, seed, ramp="gray"):
    rr = random.Random(seed)
    for _ in range(26):
        x = rr.randint(1, W - 6)
        w = rr.randint(2, 5)
        y = FL - rr.randint(0, 2)
        rect(img, x, y, w, FL + 1 - y, c(f"{ramp}{rr.randint(1, len(RAMPS[ramp]) - 1)}"))
        px(img, x, y, OL)


def mood(img, dark=0.32, seed=1):
    """bake low light: everything leans to night; a vignette at the top + floor edge"""
    for y in range(H):
        t = dark + (0.18 if y < 10 else 0) + max(0, (y - FL - 6)) * 0.02
        for x in range(W):
            p = get(img, x, y)
            if p[3] == 0:
                continue
            px(img, x, y, blend(p, c("night0"), t if bayer(x, y) < 0.5 else t - 0.05))


def can_row(img, x, y, w, cols, rr):
    xx = x + 1
    while xx < x + w - 4:
        col = rr.choice(cols)
        ih = rr.randint(3, 6)
        iw = rr.randint(3, 4)
        if rr.random() < 0.25:        # looted gap
            xx += iw + 2
            continue
        rect(img, xx, y - ih, iw, ih, OL)
        rect(img, xx + 1, y - ih + 1, iw - 2, ih - 1, c(col))
        px(img, xx + 1, y - ih + 1, blend(c(col), c("gray6"), 0.4))
        xx += iw + 1


def shelf_unit(img, x, w, rr, cols, h=56, ramp="gray"):
    top = FL - h
    rect(img, x, top, 2, h, OL)
    rect(img, x + w - 2, top, 2, h, OL)
    vline(img, x + 1, top, h, c(f"{ramp}4"))
    for y in range(top + 2, FL, 13):
        hline(img, x, y, w, OL)
        hline(img, x + 1, y + 1, w - 2, c(f"{ramp}4"))
        hline(img, x + 1, y + 2, w - 2, c(f"{ramp}2"))
        if y > top + 2:
            can_row(img, x + 2, y, w - 4, cols, rr)
    shadow(img, x, w)


# ------------------------------------------------------------------ scenes
def scene_store():
    img = new(W, H)
    rr = random.Random(11)
    ceiling(img, "gray", 2)
    wall(img, "cream0", "cream1", "tile")
    rect(img, 0, 8, W, 6, c("red1"))           # store-front stripe
    for x in range(4, W, 40):
        rect(img, x, 9, 22, 4, c("red2"))
    for i, x in enumerate((6, 70, 134, 198)):
        shelf_unit(img, x, 48, rr, ["red2", "yellow2", "teal2", "cream2", "green3", "orange2"])
    # broken fridge with a dying green glow
    blk(img, 56, 30, 12, 56, "blue", 2)
    rect(img, 58, 34, 8, 48, c("teal1"))
    for y in range(36, 82, 6):
        hline(img, 58, y, 8, c("teal2"))
    # shopping trolley on its side
    for k in range(10):
        px(img, 118 + k, FL - 6 + (k % 2), OL)
    for xx in range(118, 130, 2):
        vline(img, xx, FL - 10, 5, c("gray4"))
    hline(img, 118, FL - 10, 12, c("gray5"))
    ellipse(img, 119, FL - 3, 3, 3, OL)
    ellipse(img, 127, FL - 3, 3, 3, OL)
    # price signs dangling
    for x in (30, 94, 158, 222):
        vline(img, x, 0, 18, c("gray3"))
        rect(img, x - 6, 18, 13, 6, OL)
        rect(img, x - 5, 19, 11, 4, c("yellow3"))
        hline(img, x - 3, 21, 7, c("red2"))
    ground(img, "gray", 2, "tile")
    debris(img, 3, "cream")
    grime(img, 5)
    mood(img, 0.34)
    for x in (30, 158):
        dead_lamp(img, x + 32, lit=(x == 30))
    return img


def scene_hospital():
    img = new(W, H)
    rr = random.Random(12)
    ceiling(img, "gray", 3)
    wall(img, "teal1", "teal2", "tile", 8, 50)
    wall(img, "cream1", "cream0", "panel", 50, FL)
    hline(img, 0, 50, W, c("teal3"))
    for i, x in enumerate((12, 140)):
        # bed with stained sheet
        blk(img, x, FL - 14, 40, 6, "cream", 3)
        rect(img, x + 2, FL - 18, 10, 5, c("cream3"))
        frame(img, x + 2, FL - 18, 10, 5, OL)
        vline(img, x + 1, FL - 8, 8, OL)
        vline(img, x + 38, FL - 8, 8, OL)
        rect(img, x + 18, FL - 12, 8, 2, c("red1"))
        shadow(img, x, 40)
        # IV stand
        vline(img, x + 46, FL - 40, 40, c("gray4"))
        hline(img, x + 42, FL - 40, 9, c("gray4"))
        rect(img, x + 42, FL - 39, 3, 6, c("teal3"))
        hline(img, x + 43, FL, 7, OL)
    # curtain rail + torn curtain
    hline(img, 64, 14, 60, c("gray4"))
    for x in range(66, 120, 3):
        ln = 50 + rr.randint(-8, 8)
        vline(img, x, 15, ln, c("teal3" if x % 2 else "teal2"))
        px(img, x, 15 + ln, OL)
    # medicine cabinet
    blk(img, 200, 22, 30, 30, "gray", 4)
    vline(img, 215, 23, 28, OL)
    rect(img, 210, 27, 10, 10, c("cream3"))
    rect(img, 214, 28, 2, 8, c("red3"))
    rect(img, 211, 31, 8, 2, c("red3"))
    # red cross sign
    rect(img, 236, 22, 14, 14, OL)
    rect(img, 237, 23, 12, 12, c("cream3"))
    rect(img, 241, 24, 4, 10, c("red3"))
    rect(img, 238, 27, 10, 4, c("red3"))
    ground(img, "gray", 3, "tile")
    debris(img, 4, "cream")
    grime(img, 6)
    mood(img, 0.36)
    dead_lamp(img, 40)
    dead_lamp(img, 168, lit=False)
    return img


def scene_bunker():
    img = new(W, H)
    rr = random.Random(13)
    ceiling(img, "gray", 1)
    wall(img, "green1", "green0", "concrete")
    for x in range(0, W, 8):                    # hazard stripe
        rect(img, x, FL - 8, 4, 6, c("yellow2"))
        rect(img, x + 4, FL - 8, 4, 6, c("ol1"))
    # blast door
    blk(img, 104, 20, 48, 58, "gray", 3)
    vline(img, 128, 21, 56, OL)
    for y in range(26, 76, 10):
        px(img, 108, y, c("gray5"))
        px(img, 147, y, c("gray5"))
    ellipse(img, 122, 44, 12, 12, OL, None)
    ellipse(img, 123, 45, 10, 10, c("gray4"))
    # crate stacks
    for bx, h in ((8, 3), (40, 2), (176, 3), (212, 2)):
        for k in range(h):
            blk(img, bx, FL - 14 - k * 14, 28, 14, "green", 2)
            hline(img, bx + 4, FL - 8 - k * 14, 20, c("yellow2"))
        shadow(img, bx, 28)
    # gun rack
    rect(img, 74, 26, 24, 2, OL)
    for k in range(4):
        vline(img, 77 + k * 6, 28, 22, c("ol1"))
        vline(img, 78 + k * 6, 28, 22, c("gray3"))
    ground(img, "gray", 2, "grate")
    debris(img, 5, "gray")
    grime(img, 7)
    mood(img, 0.38)
    dead_lamp(img, 60)
    dead_lamp(img, 196, lit=False)
    return img


def scene_plant():
    img = new(W, H)
    rr = random.Random(14)
    ceiling(img, "gray", 2)
    wall(img, "gray2", "gray1", "panel")
    # big pipes
    for y, ramp in ((16, "orange"), (24, "gray")):
        rect(img, 0, y, W, 5, OL)
        rect(img, 0, y + 1, W, 3, c(f"{ramp}2"))
        hline(img, 0, y + 1, W, c(f"{ramp}3"))
        for x in range(10, W, 32):
            rect(img, x, y, 3, 5, c(f"{ramp}1"))
    # tanks
    for tx in (16, 160):
        rect(img, tx, 36, 36, 50, OL)
        rect(img, tx + 1, 37, 34, 49, c("gray3"))
        rect(img, tx + 3, 37, 5, 49, c("gray4"))
        for y in (44, 60, 76):
            hline(img, tx + 1, y, 34, c("gray1"))
        rect(img, tx + 10, 48, 16, 8, c("yellow2"))
        hline(img, tx + 12, 51, 12, OL)
        shadow(img, tx, 36)
    # valves & gauges
    for gx in (70, 92, 214):
        vline(img, gx + 3, 29, 26, c("gray4"))
        ellipse(img, gx, 54, 7, 7, OL)
        ellipse(img, gx + 1, 55, 5, 5, c("gray6"))
        line(img, gx + 3, 57, gx + 5, 56, c("red2"))
        rect(img, gx - 1, 66, 9, 3, c("red2"))
    # barrels + toxic puddle
    for k, bx in enumerate((112, 124, 236)):
        rect(img, bx, FL - 14, 10, 14, OL)
        rect(img, bx + 1, FL - 13, 8, 12, c("yellow1" if k != 1 else "toxic1"))
        rect(img, bx + 2, FL - 13, 3, 12, c("yellow2" if k != 1 else "toxic2"))
        hline(img, bx + 1, FL - 10, 8, OL)
        shadow(img, bx, 10)
    for x in range(100, 146):
        if bayer(x, FL + 3) < 0.7:
            px(img, x, FL + 3, c("toxic2"))
            px(img, x, FL + 4, c("toxic1"))
    ground(img, "gray", 2, "grate")
    debris(img, 6, "orange")
    grime(img, 8)
    mood(img, 0.32)
    dead_lamp(img, 120)
    return img


def scene_lab():
    img = new(W, H)
    rr = random.Random(15)
    ceiling(img, "blue", 1)
    wall(img, "blue1", "blue2", "panel")
    # specimen tubes with green glow
    for tx in (20, 44, 172):
        rect(img, tx, 24, 16, 62, OL)
        rect(img, tx + 1, 30, 14, 50, c("toxic1"))
        rect(img, tx + 3, 32, 3, 46, c("toxic2"))
        rect(img, tx, 24, 16, 6, c("gray3"))
        rect(img, tx, 80, 16, 6, c("gray3"))
        ellipse(img, tx + 5, 46, 6, 10, c("toxic0"))
        light_radial(img, tx + 8, 56, 24, c("toxic2"), strength=0.22, steps=3)
    # server racks
    for sx in (90, 112):
        blk(img, sx, 26, 20, 60, "gray", 1)
        for y in range(30, 82, 5):
            hline(img, sx + 3, y, 14, c("gray2"))
            px(img, sx + 15, y, c("toxic3") if rr.random() < 0.5 else c("red3"))
        shadow(img, sx, 20)
    # terminal desk
    blk(img, 200, 66, 46, 6, "gray", 3)
    vline(img, 202, 72, 14, OL)
    vline(img, 243, 72, 14, OL)
    rect(img, 212, 46, 22, 18, OL)
    rect(img, 213, 47, 20, 16, c("teal1"))
    for y in range(50, 62, 3):
        hline(img, 215, y, rr.randint(6, 16), c("teal3"))
    # warning stripes on the floor edge
    for x in range(0, W, 8):
        rect(img, x, FL - 3, 4, 2, c("yellow2"))
    ground(img, "gray", 3, "tile")
    debris(img, 7, "blue")
    grime(img, 9)
    mood(img, 0.36)
    dead_lamp(img, 140, lit=False)
    return img


def scene_mine():
    img = new(W, H)
    rr = random.Random(16)
    rect(img, 0, 0, W, 10, c("wood0"))
    wall(img, "gray1", "gray2", "rock", 0, FL)
    # timber supports every 64 px (seamless)
    for x in range(20, W, 64):
        rect(img, x, 8, 6, FL - 8, OL)
        rect(img, x + 1, 8, 4, FL - 8, c("wood2"))
        vline(img, x + 1, 8, FL - 8, c("wood3"))
    for x in range(0, W, 64):
        rect(img, x + 14, 6, 26, 5, OL)
    rect(img, 0, 6, W, 5, c("wood2"))
    hline(img, 0, 6, W, c("wood3"))
    hline(img, 0, 11, W, OL)
    # lanterns
    for x in (36, 164):
        vline(img, x, 11, 6, OL)
        rect(img, x - 2, 17, 5, 6, OL)
        rect(img, x - 1, 18, 3, 4, c("lamp1"))
        light_radial(img, x, 22, 34, c("lamp1"), strength=0.3, steps=3)
    # ore cart + rails
    blk(img, 96, FL - 18, 30, 14, "orange", 1)
    for k in range(6):
        px(img, 100 + k * 4, FL - 19, c("teal3"))
        px(img, 101 + k * 4, FL - 20, c("snow3"))
    ellipse(img, 99, FL - 5, 6, 6, OL)
    ellipse(img, 117, FL - 5, 6, 6, OL)
    # ice crystals / ore veins
    for _ in range(30):
        x, y = rr.randint(2, W - 3), rr.randint(14, FL - 10)
        px(img, x, y, c("snow3"))
        px(img, x + 1, y + 1, c("snow2"))
    ground(img, "sand", 1, "dirt")
    for x in range(0, W, 6):
        rect(img, x, FL + 4, 4, 2, c("wood1"))
    hline(img, 0, FL + 3, W, c("gray4"))
    hline(img, 0, FL + 7, W, c("gray4"))
    grime(img, 10, 12, FL)
    mood(img, 0.3)
    return img


def scene_ruins():
    """outdoor-ish: a collapsed street — the roof is gone, dusk sky shows through"""
    img = new(W, H)
    rr = random.Random(17)
    gradient_v(img, 0, 0, W, FL, [(0.0, c("dusk0")), (0.45, c("dusk1")), (0.8, c("dusk2")), (1.0, c("sand1"))])
    # broken walls with window holes
    for bx, bw, top in ((0, 70, 18), (86, 58, 30), (160, 96, 14)):
        rect(img, bx, top, bw, FL - top, c("gray2"))
        for y in range(top, FL, 5):
            hline(img, bx, y, bw, c("gray1"))
        for x in range(bx + 6, bx + bw - 10, 18):
            rect(img, x, top + 10, 9, 12, c("night1"))
            frame(img, x, top + 10, 9, 12, OL)
        # jagged top
        for x in range(bx, bx + bw):
            for k in range(rr.randint(0, 5)):
                px(img, x, top + k, c("dusk1"))
    # wrecked car
    blk(img, 100, FL - 14, 44, 10, "red", 1)
    blk(img, 110, FL - 22, 24, 9, "red", 1)
    rect(img, 113, FL - 20, 8, 5, c("night1"))
    ellipse(img, 104, FL - 7, 8, 8, OL)
    ellipse(img, 130, FL - 7, 8, 8, OL)
    shadow(img, 100, 44)
    # dead tree + chain fence
    vline(img, 76, 30, 56, c("wood1"))
    line(img, 76, 44, 66, 34, c("wood1"))
    line(img, 76, 40, 84, 30, c("wood1"))
    for x in range(150, 200, 3):
        for y in range(FL - 22, FL, 3):
            px(img, x + (y // 3) % 2, y, c("gray4"))
    hline(img, 150, FL - 23, 50, c("gray5"))
    ground(img, "sand", 1, "dirt")
    debris(img, 8, "gray")
    grime(img, 11, 20, FL)
    mood(img, 0.22)
    return img


SCENES = {"store": scene_store, "hospital": scene_hospital, "bunker": scene_bunker, "plant": scene_plant,
          "lab": scene_lab, "mine": scene_mine, "ruins": scene_ruins}


def crate():
    img = new(11, 9)
    blk(img, 0, 0, 11, 9, "wood", 2)
    line(img, 1, 1, 9, 7, c("wood1"))
    hline(img, 2, 4, 7, c("wood3"))
    return img


def gen_expedition():
    for k, fn in SCENES.items():
        save(fn(), os.path.join(OUT_EXP, f"exp_{k}.png"))
    add("exp_crate", crate())
    print("expedition feeds", len(SCENES))


if __name__ == "__main__":
    gen_expedition()
