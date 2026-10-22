"""Expedition special-encounter illustrations 160x80 (shown at 2x in the encounter popup).
Dark interiors lit by the squad's flashlight / emissive accents only. Feet line y=66."""
import os, random
from .common import *
from . import chars

EW, EH = 160, 80
FL = 66
OUT_EV = os.path.join(ROOT, "assets", "events")


def room(wall_a="gray2", wall_b="gray1", floor="gray1", style="concrete", seed=1):
    rr = random.Random(seed)
    img = new(EW, EH)
    rect(img, 0, 0, EW, FL, c(wall_a))
    cb = c(wall_b)
    if style == "concrete":
        for y in range(0, FL, 14):
            hline(img, 0, y, EW, cb)
        for x in range(0, EW, 48):
            vline(img, x, 0, FL, cb)
    elif style == "tile":
        for y in range(0, FL, 8):
            hline(img, 0, y, EW, cb)
            for x in range((y // 8) % 2 * 4, EW, 8):
                vline(img, x, y, 8, cb)
    elif style == "brick":
        for y in range(0, FL, 5):
            hline(img, 0, y, EW, cb)
            for x in range((y // 5) % 2 * 6, EW, 12):
                vline(img, x, y, 5, cb)
    # rust streaks + cracks
    for _ in range(10):
        x = rr.randint(1, EW - 2)
        for k in range(rr.randint(4, 14)):
            tint_px(img, x, k, c("orange1"), 0.5 - k * 0.03)
    for _ in range(3):
        x, y = rr.randint(4, EW - 6), rr.randint(4, 30)
        for k in range(rr.randint(8, 16)):
            px(img, x, y, OL)
            x = max(1, min(EW - 2, x + rr.choice((-1, 0, 1))))
            y += 1
    rect(img, 0, FL, EW, EH - FL, c(floor))
    hline(img, 0, FL, EW, c("gray3"))
    hline(img, 0, FL + 1, EW, OL)
    for _ in range(90):
        px(img, rr.randint(0, EW - 1), rr.randint(FL + 2, EH - 1), c(rr.choice(("gray0", "gray2", "wood1"))))
    for _ in range(18):        # rubble along the wall foot
        x = rr.randint(1, EW - 6)
        w = rr.randint(2, 5)
        y = FL - rr.randint(0, 2)
        rect(img, x, y, w, FL + 1 - y, c("gray%d" % rr.randint(1, 4)))
        px(img, x, y, OL)
    return img


def darken(img, t=0.38):
    for y in range(EH):
        for x in range(EW):
            p = get(img, x, y)
            if p[3]:
                px(img, x, y, blend(p, c("night0"), t if bayer(x, y) < 0.5 else t - 0.06))


def beam(img, x, y, w_end, length, col="lamp1", strength=0.3):
    """flashlight beam pointing right from (x, y)"""
    for dx in range(length):
        half = 1 + (w_end * dx) // (2 * length)
        s = strength * (1.0 - dx / (length * 1.25))
        for dy in range(-half, half + 1):
            yy = y + dy
            if 0 <= yy < EH and 0 <= x + dx < EW and bayer(x + dx, yy) < 0.85:
                tint_px(img, x + dx, yy, c(col), s)


def glow(img, cx, cy, r, col, strength=0.45):
    light_radial(img, cx, cy, r, c(col), strength=strength, x0=0, y0=0, x1=EW, y1=EH)


def guy(outfit, hair, pose="stand", flipx=False):
    f = chars.dweller_frame(outfit, hair, pose, 0)
    return flip(f) if flipx else f


def torch_holder(img, x):
    """our scavenger at the left edge with a lit flashlight"""
    paste(img, guy("scav", "brown", "work1"), x, FL - 22)
    rect(img, x + 15, FL - 12, 3, 2, OL)
    px(img, x + 17, FL - 12, c("lamp2"))


def crate(img, x, y, w, h, ramp="wood"):
    rect(img, x, y, w, h, OL)
    rect(img, x + 1, y + 1, w - 2, h - 2, c(ramp + "2"))
    hline(img, x + 1, y + 1, w - 2, c(ramp + "3"))
    line(img, x + 1, y + 1, x + w - 2, y + h - 2, c(ramp + "1"))


def red_cross(img, x, y):
    rect(img, x, y + 2, 7, 3, c("red3"))
    rect(img, x + 2, y, 3, 7, c("red3"))


def save_ev(img, name):
    save(img, os.path.join(OUT_EV, name + ".png"))


def enc_survivor():
    img = room("gray2", "gray1", seed=11)
    # overturned table, a frightened face peeking over it
    paste(img, guy("jumpsuit", "red", "sit", flipx=True), 104, FL - 24)
    rect(img, 92, FL - 9, 40, 9, OL)
    rect(img, 93, FL - 8, 38, 7, c("wood2"))
    hline(img, 93, FL - 8, 38, c("wood3"))
    for x in (96, 126):
        rect(img, x, FL - 19, 2, 10, c("wood1"))
    darken(img)
    torch_holder(img, 14)
    beam(img, 32, FL - 12, 26, 96)
    save_ev(img, "enc_survivor")


def enc_wounded():
    img = room("red1", "red0", style="brick", seed=12)
    # stranger slumped against the wall, blood pool, dropped pack
    paste(img, guy("raider", "gray", "sit", flipx=True), 98, FL - 20)
    ellipse(img, 90, FL + 1, 26, 5, c("red1"))
    ellipse(img, 96, FL + 2, 14, 3, c("red2"))
    crate(img, 124, FL - 9, 12, 9, "green")
    rect(img, 70, FL - 2, 6, 2, c("gray4"))          # spent shells
    px(img, 80, FL - 1, c("yellow2"))
    darken(img, 0.42)
    torch_holder(img, 14)
    beam(img, 32, FL - 10, 22, 90)
    save_ev(img, "enc_wounded")


def enc_cry():
    img = room("gray1", "gray0", style="tile", seed=13)
    # long corridor, door ajar with red emergency light, "HELP" smeared on the wall
    rect(img, 98, 18, 26, FL - 18, OL)
    rect(img, 99, 19, 24, FL - 19, c("red1"))
    rect(img, 112, 19, 11, FL - 19, c("gray2"))         # half-open door leaf
    vline(img, 112, 19, FL - 19, OL)
    glow(img, 106, 40, 30, "red3", 0.5)
    # silhouette waving in the doorway
    sil = guy("scav", "black", "work2")
    for y in range(sil.height):
        for x in range(sil.width):
            if get(sil, x, y)[3]:
                px(img, 100 + x, FL - 22 + y, OL)
    # HELP
    for i, ch in enumerate(("H", "E", "L", "P")):
        x0 = 30 + i * 9
        col = c("red2")
        if ch == "H":
            vline(img, x0, 14, 8, col); vline(img, x0 + 4, 14, 8, col); hline(img, x0, 18, 5, col)
        elif ch == "E":
            vline(img, x0, 14, 8, col); hline(img, x0, 14, 5, col); hline(img, x0, 18, 4, col); hline(img, x0, 21, 5, col)
        elif ch == "L":
            vline(img, x0, 14, 8, col); hline(img, x0, 21, 5, col)
        else:
            vline(img, x0, 14, 8, col); hline(img, x0, 14, 4, col); hline(img, x0, 18, 4, col); vline(img, x0 + 4, 14, 5, col)
        for d in range(1, 4):
            tint_px(img, x0 + 1, 22 + d, c("red1"), 0.6)
    darken(img, 0.3)
    torch_holder(img, 8)
    beam(img, 26, FL - 12, 18, 70, strength=0.22)
    save_ev(img, "enc_cry")


def enc_vault():
    img = room("gray2", "gray1", seed=14)
    # collapsed slabs over a half-buried steel safe, rebar sticking out
    poly(img, [(40, FL), (70, 30), (96, 34), (88, FL)], c("gray3"), OL)
    poly(img, [(100, FL), (112, 22), (150, 28), (158, FL)], c("gray3"), OL)
    for (x0, y0, x1, y1) in ((72, 32, 64, 18), (110, 26, 118, 12), (130, 27, 140, 14)):
        line(img, x0, y0, x1, y1, c("orange1"))
    rect(img, 82, FL - 22, 26, 22, OL)
    rect(img, 83, FL - 21, 24, 20, c("blue2"))
    hline(img, 83, FL - 21, 24, c("blue4"))
    ellipse(img, 89, FL - 16, 9, 9, c("blue3"), OL)
    px(img, 93, FL - 12, c("lamp2"))
    rect(img, 100, FL - 14, 2, 6, c("gray5"))
    for _ in range(40):        # dust in the air
        rr = random.Random(_)
        px(img, rr.randint(30, 150), rr.randint(4, FL - 4), c("cream1"))
    darken(img, 0.34)
    torch_holder(img, 10)
    beam(img, 28, FL - 12, 24, 80)
    save_ev(img, "enc_vault")


def enc_floor():
    img = room("wood1", "wood0", style="concrete", seed=15)
    # sagging upper floor with supply crates teetering above a hole
    poly(img, [(56, 20), (150, 14), (150, 22), (60, 30)], c("gray3"), OL)
    for x in range(64, 148, 10):
        line(img, x, 26 - (x - 60) // 12, x + 3, 32 - (x - 60) // 12, OL)
    crate(img, 92, 2, 14, 13)
    crate(img, 108, 0, 16, 14, "green")
    crate(img, 128, 3, 12, 10)
    for k in range(6):          # falling dust
        px(img, 70 + k * 9, 34 + (k * 7) % 20, c("cream2"))
    ellipse(img, 80, FL - 1, 48, 6, c("night0"))      # hole in the floor
    paste(img, guy("army", "blonde", "stand"), 34, FL - 22)
    darken(img, 0.36)
    glow(img, 112, 10, 18, "lamp0", 0.3)
    save_ev(img, "enc_floor")


def enc_toxic():
    img = room("teal1", "teal0", style="tile", seed=16)
    # contaminated pharmacy: leaking barrels, green glow, med crate behind it
    for x in (40, 54):
        rect(img, x, FL - 18, 12, 18, OL)
        rect(img, x + 1, FL - 17, 10, 16, c("yellow1"))
        hline(img, x + 1, FL - 12, 10, OL)
        poly(img, [(x + 3, FL - 9), (x + 6, FL - 4), (x + 9, FL - 9)], c("ol0"))
    ellipse(img, 36, FL - 2, 40, 6, c("toxic2"))
    crate(img, 104, FL - 16, 22, 16, "cream")
    red_cross(img, 112, FL - 12)
    crate(img, 128, FL - 10, 14, 10, "cream")
    darken(img, 0.36)
    glow(img, 56, FL - 2, 34, "toxic2", 0.45)
    paste(img, guy("medic", "black", "stand"), 80, FL - 22)
    save_ev(img, "enc_toxic")


def gen_encounters():
    for fn in (enc_survivor, enc_wounded, enc_cry, enc_vault, enc_floor, enc_toxic):
        fn()
    print("encounter art 6")


if __name__ == "__main__":
    gen_encounters()
