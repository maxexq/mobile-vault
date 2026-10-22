"""Room interiors (64x52, three per floor), grim 16-bit style: stained walls, rust drips, cracked plaster, soot,
a single caged bulb throwing a warm pool of light into a dark room. Dwellers stand on y=46."""
import math, random
from .common import *

RW, RH = 64, 52
FLOOR = 46          # feet line / top of floor
rr = random.Random(77)


# ------------------------------------------------------------------ shell pieces
def wallpaper(img, style, a, b, y0=4, y1=FLOOR):
    h = y1 - y0
    ca, cb = c(a), c(b)
    rect(img, 0, y0, RW, h, ca)
    if style == "stripe":
        for x in range(0, RW, 8):
            rect(img, x, y0, 4, h, cb)
    elif style == "dots":
        for y in range(y0 + 2, y1, 6):
            for x in range((y // 6) % 2 * 3 + 1, RW, 6):
                px(img, x, y, cb)
                px(img, x + 1, y, cb)
    elif style == "tile":
        for y in range(y0, y1, 6):
            hline(img, 0, y, RW, cb)
        for y in range(y0, y1, 6):
            for x in range(((y - y0) // 6) % 2 * 3, RW, 6):
                vline(img, x, y, 6, cb)
    elif style == "plank":
        for y in range(y0 + 4, y1, 5):
            hline(img, 0, y, RW, cb)
        for y in range(y0, y1, 5):
            for x in range(rr.randint(0, 12), RW, rr.randint(16, 26)):
                vline(img, x, y, 5, cb)
    elif style == "panel":
        for x in range(0, RW, 20):
            vline(img, x, y0, h, cb)
        for x in range(3, RW, 20):
            for y in (y0 + 2, y1 - 3):
                px(img, x, y, cb)
                px(img, x + 13, y, cb)
    elif style == "brick":
        for y in range(y0, y1, 4):
            hline(img, 0, y, RW, cb)
            for x in range((y // 4) % 2 * 5, RW, 10):
                vline(img, x, y, 4, cb)
    elif style == "check":
        for y in range(y0, y1, 4):
            for x in range(((y - y0) // 4) % 2 * 4, RW, 8):
                rect(img, x, y, 4, 4, cb)


def wainscot(img, col, trim, y=36):
    rect(img, 0, y, RW, FLOOR - y, c(col))
    hline(img, 0, y, RW, c(trim))
    hline(img, 0, y + 1, RW, blend(c(trim), c("gray6"), 0.4))
    for x in range(4, RW, 10):
        vline(img, x, y + 3, FLOOR - y - 4, blend(c(col), c("ol0"), 0.15))


def ceiling(img, col="wood1"):
    rect(img, 0, 0, RW, 4, c(col))
    hline(img, 0, 0, RW, blend(c(col), c("gray6"), 0.35))
    hline(img, 0, 3, RW, OL)
    for x in range(6, RW, 18):
        px(img, x, 1, c("ol1"))


def floor(img, kind="wood"):
    y = FLOOR
    if kind == "wood":
        rect(img, 0, y, RW, RH - y, c("wood2"))
        hline(img, 0, y, RW, c("wood3"))
        hline(img, 0, y + 3, RW, c("wood1"))
        for x in range(rr.randint(0, 9), RW, 14):
            vline(img, x, y + 1, 2, c("wood1"))
            vline(img, (x + 7) % RW, y + 4, 2, c("wood1"))
    elif kind == "metal":
        rect(img, 0, y, RW, RH - y, c("gray3"))
        hline(img, 0, y, RW, c("gray5"))
        for x in range(0, RW, 4):
            px(img, x, y + 2, c("gray2"))
            px(img, x + 2, y + 4, c("gray2"))
    elif kind == "tile":
        rect(img, 0, y, RW, RH - y, c("gray5"))
        hline(img, 0, y, RW, c("gray6"))
        for x in range(0, RW, 6):
            vline(img, x, y + 1, RH - y, c("gray4"))
        hline(img, 0, y + 3, RW, c("gray4"))
    elif kind == "hazard":
        rect(img, 0, y, RW, RH - y, c("gray3"))
        hline(img, 0, y, RW, c("gray4"))
        for x in range(-6, RW, 8):
            poly(img, [(x, RH - 1), (x + 4, y + 1), (x + 8, y + 1), (x + 4, RH - 1)], c("yellow2"))
    rect(img, 0, RH - 1, RW, 1, OL)


def ceiling_lamp(img, x, col="lamp1"):
    vline(img, x, 4, 3, OL)
    rect(img, x - 2, 7, 5, 3, OL)
    rect(img, x - 1, 7, 3, 2, c(col))
    px(img, x, 7, c("lamp2"))
    hline(img, x - 2, 10, 5, c("gray2"))


def base(style, a, b, floor_kind="wood", wains=None, ceil="wood1"):
    img = new(RW, RH)
    wallpaper(img, style, a, b)
    if wains:
        wainscot(img, *wains)
    ceiling(img, ceil)
    floor(img, floor_kind)
    # soft shadow under the ceiling + corner dim, Kairosoft rooms are bright so keep it light
    for x in range(RW):
        tint_px(img, x, 4, c("ol0"), 0.22)
        tint_px(img, x, FLOOR - 1, c("ol0"), 0.12)
    for y in range(4, FLOOR):
        tint_px(img, 0, y, c("ol0"), 0.25)
        tint_px(img, RW - 1, y, c("ol0"), 0.25)
    return img


# ------------------------------------------------------------------ furniture kit
def box(img, x, y, w, h, ramp, i=2, top=True):
    """outlined block with highlight top/left and shade right/bottom"""
    f = c(f"{ramp}{i}")
    hi = c(f"{ramp}{min(i + 1, len(RAMPS[ramp]) - 1)}")
    lo = c(f"{ramp}{max(i - 1, 0)}")
    rect(img, x, y, w, h, OL)
    rect(img, x + 1, y + 1, w - 2, h - 2, f)
    if top:
        hline(img, x + 1, y + 1, w - 2, hi)
    vline(img, x + 1, y + 2, h - 4, blend(f, hi, 0.5))
    vline(img, x + w - 2, y + 2, h - 3, lo)
    hline(img, x + 2, y + h - 2, w - 3, lo)


def floor_shadow(img, x, w):
    for xx in range(x + 1, x + w - 1):
        tint_px(img, xx, FLOOR, c("ol0"), 0.35)
        tint_px(img, xx, FLOOR + 1, c("ol0"), 0.18)


def legs(img, x, y, w, h=3):
    vline(img, x + 1, y, h, OL)
    vline(img, x + w - 2, y, h, OL)


def poster(img, x, y, w, h, bg, fg):
    rect(img, x, y, w, h, OL)
    rect(img, x + 1, y + 1, w - 2, h - 2, c(bg))
    px(img, x + w // 2, y - 1, c("red2"))
    return fg


def window(img, x, y, w, h, sky="sky2"):
    rect(img, x, y, w, h, OL)
    rect(img, x + 1, y + 1, w - 2, h - 2, c(sky))
    hline(img, x + 1, y + 1 + (h - 2) * 2 // 3, w - 2, c("sky3"))
    vline(img, x + w // 2, y + 1, h - 2, c("wood2"))
    hline(img, x + 1, y + h // 2, w - 2, c("wood2"))
    hline(img, x - 1, y + h, w + 2, c("wood2"))
    hline(img, x - 1, y + h + 1, w + 2, OL)


def shelf(img, x, y, w, items=None):
    hline(img, x, y, w, c("wood3"))
    hline(img, x, y + 1, w, c("wood1"))
    hline(img, x, y + 2, w, OL)
    px(img, x + 1, y + 3, OL)
    px(img, x + w - 2, y + 3, OL)
    xx = x + 1
    for it in items or []:
        col, iw, ih = it
        rect(img, xx, y - ih, iw, ih, OL)
        rect(img, xx + 1, y - ih + 1, iw - 2, ih - 1, c(col))
        px(img, xx + 1, y - ih + 1, blend(c(col), c("gray6"), 0.5))
        xx += iw + 1
        if xx > x + w - 3:
            break


def jar_items(n, cols):
    return [(cols[k % len(cols)], 3 + (k % 2), 4 + (k % 3)) for k in range(n)]


def plant_pot(img, x, y, leaf="green", pot="orange", h=8, flower=None):
    rect(img, x, y - 4, 7, 5, OL)
    rect(img, x + 1, y - 4, 5, 4, c(pot + "1"))
    hline(img, x + 1, y - 4, 5, c(pot + "2"))
    for k, (dx, dy) in enumerate(((1, -h), (3, -h - 2), (5, -h + 1), (2, -h + 3), (4, -h + 2))):
        ellipse(img, x + dx - 1, y - 4 + dy, 4, 4, OL)
    for k, (dx, dy) in enumerate(((1, -h), (3, -h - 2), (5, -h + 1), (2, -h + 3), (4, -h + 2))):
        ellipse(img, x + dx, y - 3 + dy, 2, 2, c(leaf + ("3" if k % 2 else "2")))
    for k in range(h - 4):
        px(img, x + 3, y - 5 - k, c(leaf + "1"))
    if flower:
        px(img, x + 3, y - 3 - h - 2, c(flower))


def screen(img, x, y, w, h, glow="teal", graph=False):
    rect(img, x, y, w, h, OL)
    rect(img, x + 1, y + 1, w - 2, h - 2, c("night1"))
    rect(img, x + 2, y + 2, w - 4, h - 4, c(glow + "1"))
    if graph:
        pts = [(x + 2 + i, y + h // 2 + (0 if i % 6 else -(h // 3)) + (1 if i % 6 == 1 else 0)) for i in range(w - 4)]
        for p in pts:
            px(img, p[0], p[1], c(glow + "3"))
    else:
        for yy in range(y + 3, y + h - 2, 2):
            hline(img, x + 3, yy, rr.randint(2, w - 6), c(glow + "3"))
    px(img, x + 2, y + 2, c("gray6"))


def rug(img, x, w, col):
    rect(img, x, FLOOR + 1, w, 2, c(col + "2"))
    hline(img, x, FLOOR + 1, w, c(col + "3"))
    for xx in range(x, x + w, 2):
        px(img, xx, FLOOR + 3, c(col + "1"))


def pipe_h(img, x, y, w, ramp="gray", i=4):
    rect(img, x, y, w, 4, OL)
    rect(img, x, y + 1, w, 2, c(f"{ramp}{i}"))
    hline(img, x, y + 1, w, c(f"{ramp}{min(i + 1, len(RAMPS[ramp]) - 1)}"))
    for xx in range(x + 8, x + w, 16):
        rect(img, xx, y, 2, 4, c(f"{ramp}{i - 1}"))


def pipe_v(img, x, y, h, ramp="gray", i=4):
    rect(img, x, y, 4, h, OL)
    rect(img, x + 1, y, 2, h, c(f"{ramp}{i}"))
    vline(img, x + 1, y, h, c(f"{ramp}{min(i + 1, len(RAMPS[ramp]) - 1)}"))


def gauge(img, x, y, needle="red2"):
    ellipse(img, x, y, 7, 7, OL)
    ellipse(img, x + 1, y + 1, 5, 5, c("gray6"))
    line(img, x + 3, y + 3, x + 5, y + 2, c(needle))


def barrel(img, x, y, ramp="yellow", w=10, h=13, symbol=None):
    rect(img, x, y, w, h, OL)
    rect(img, x + 1, y + 1, w - 2, h - 2, c(ramp + "1"))
    rect(img, x + 2, y + 1, 3, h - 2, c(ramp + "2"))
    hline(img, x + 1, y + 3, w - 2, OL)
    hline(img, x + 1, y + h - 4, w - 2, OL)
    if symbol == "fuel":
        rect(img, x + 3, y + 5, 4, 3, c("red2"))
    elif symbol == "rad":
        ellipse(img, x + 3, y + 5, 4, 3, c("ol0"))
        px(img, x + 4, y + 6, c(ramp + "2"))


# ------------------------------------------------------------------ rooms
def room_quarters():
    img = base("stripe", "pink3", "cream2", wains=("wood2", "wood3"))
    window(img, 28, 10, 12, 10)
    poster(img, 44, 9, 8, 11, "sky2", None)
    ellipse(img, 46, 11, 4, 4, c("yellow2"))
    rect(img, 45, 16, 6, 3, c("green2"))
    # bunk bed
    for yy, blank in ((14, "blue"), (30, "red")):
        rect(img, 2, yy, 22, 7, OL)
        rect(img, 3, yy + 1, 20, 3, c(blank + "2"))
        hline(img, 3, yy + 1, 20, c(blank + "3"))
        rect(img, 3, yy + 4, 20, 2, c("wood2"))
        rect(img, 3, yy - 2, 6, 3, OL)
        rect(img, 4, yy - 1, 4, 2, c("cream3"))
    vline(img, 1, 10, FLOOR - 10, OL)
    vline(img, 2, 10, FLOOR - 10, c("wood2"))
    vline(img, 24, 10, FLOOR - 10, OL)
    vline(img, 23, 10, FLOOR - 10, c("wood2"))
    for yy in range(18, 30, 3):
        hline(img, 20, yy, 3, c("wood1"))
    floor_shadow(img, 1, 24)
    box(img, 52, 36, 10, 10, "wood", 2)
    hline(img, 54, 40, 6, OL)
    rect(img, 55, 30, 4, 6, OL)
    rect(img, 54, 28, 6, 3, c("yellow3"))
    frame(img, 54, 28, 6, 3, OL)
    floor_shadow(img, 52, 10)
    rug(img, 28, 20, "purple")
    return img


def room_kitchen():
    img = base("check", "gray6", "sky3", floor_kind="tile", wains=None)
    for x in (2, 16):
        box(img, x, 7, 13, 10, "teal", 2)
        px(img, x + 6, 13, OL)
    box(img, 1, 32, 38, 14, "cream", 2)
    rect(img, 1, 31, 38, 2, OL)
    hline(img, 2, 32, 36, c("wood3"))
    for x in (4, 14, 25):
        rect(img, x, 37, 8, 7, OL)
        rect(img, x + 1, 38, 6, 5, c("cream1"))
        px(img, x + 4, 40, OL)
    rect(img, 4, 30, 11, 1, c("gray1"))
    rect(img, 5, 23, 9, 7, OL)
    rect(img, 6, 24, 7, 5, c("red2"))
    hline(img, 6, 24, 7, c("red3"))
    rect(img, 3, 24, 2, 2, OL)
    rect(img, 14, 24, 2, 2, OL)
    for (sx, sy) in ((8, 20), (10, 17), (8, 14)):
        ellipse(img, sx, sy, 3, 3, c("gray5"))
    rect(img, 25, 30, 10, 2, c("gray4"))
    vline(img, 30, 25, 5, c("gray3"))
    hline(img, 30, 25, 3, c("gray3"))
    shelf(img, 30, 14, 14, jar_items(4, ["orange2", "yellow2", "red2", "green3"]))
    box(img, 46, 12, 16, 34, "sky", 2)
    hline(img, 47, 26, 14, OL)
    vline(img, 48, 16, 7, c("gray4"))
    vline(img, 48, 29, 9, c("gray4"))
    rect(img, 53, 16, 4, 4, c("yellow2"))
    frame(img, 53, 16, 4, 4, OL)
    floor_shadow(img, 1, 38)
    floor_shadow(img, 46, 16)
    vline(img, 42, 4, 4, OL)
    ellipse(img, 40, 8, 5, 5, OL)
    ellipse(img, 41, 9, 3, 3, c("gray3"))
    return img


def room_hydro():
    img = base("tile", "green4", "green3", floor_kind="wood", wains=None)
    for x in (4, 24, 44):
        rect(img, x, 5, 16, 3, OL)
        rect(img, x + 1, 6, 14, 1, c("purple3"))
        for dx in range(0, 16, 2):
            for dy in range(8, 12):
                if (dx + dy) % 4 == 0:
                    tint_px(img, x + dx, dy, c("purple3"), 0.3)
    for x in (2, 22, 42):
        for yy in (24, 40):
            box(img, x, yy, 19, 6, "wood", 2)
            rect(img, x + 2, yy + 1, 15, 2, c("wood0"))
            for k in range(3):
                px_ = x + 3 + k * 5
                h = 5 + (k * 7 + yy) % 4
                vline(img, px_ + 1, yy - h + 2, h - 1, c("green1"))
                ellipse(img, px_ - 1, yy - h, 5, 4, OL)
                ellipse(img, px_, yy - h + 1, 3, 2, c("green3" if k % 2 else "green4"))
                if (k + yy) % 3 == 0:
                    px(img, px_ + 1, yy - h - 1, c("red3"))
        vline(img, x + 1, 30, 10, OL)
        vline(img, x + 17, 30, 10, OL)
        floor_shadow(img, x, 19)
    pipe_h(img, 0, 14, RW, "blue", 3)
    for x in (12, 32, 52):
        rect(img, x, 18, 1, 2, c("blue4"))
    return img


def room_water():
    img = base("panel", "sky3", "sky2", floor_kind="metal", wains=("blue3", "blue4", 38))
    rect(img, 3, 8, 24, 38, OL)
    rect(img, 4, 9, 22, 36, c("blue2"))
    rect(img, 5, 9, 4, 36, c("blue3"))
    hline(img, 4, 14, 22, OL)
    hline(img, 4, 40, 22, OL)
    rect(img, 11, 17, 10, 20, OL)
    rect(img, 12, 18, 8, 18, c("sky1"))
    rect(img, 12, 24, 8, 12, c("blue3"))
    hline(img, 12, 24, 8, c("blue4"))
    floor_shadow(img, 3, 24)
    for x in (36, 49):
        rect(img, x, 22, 12, 24, OL)
        rect(img, x + 1, 23, 10, 22, c("gray5"))
        rect(img, x + 2, 23, 3, 22, c("gray6"))
        hline(img, x + 1, 30, 10, OL)
        hline(img, x + 1, 38, 10, OL)
        rect(img, x + 3, 32, 5, 4, c("teal2"))
        frame(img, x + 3, 32, 5, 4, OL)
        floor_shadow(img, x, 12)
    pipe_h(img, 26, 12, 38, "gray", 4)
    pipe_v(img, 40, 12, 10)
    pipe_v(img, 53, 12, 10)
    gauge(img, 29, 18)
    px(img, 61, 30, c("blue4"))
    px(img, 61, 33, c("blue4"))
    return img


def room_medical():
    img = base("stripe", "gray6", "sky3", floor_kind="tile", wains=("teal2", "teal3", 38))
    rect(img, 28, 7, 11, 11, OL)
    rect(img, 29, 8, 9, 9, c("gray6"))
    rect(img, 32, 9, 3, 7, c("red3"))
    rect(img, 30, 11, 7, 3, c("red3"))
    rect(img, 3, 32, 24, 6, OL)
    rect(img, 4, 33, 22, 2, c("cream3"))
    rect(img, 4, 35, 22, 2, c("sky2"))
    rect(img, 4, 30, 7, 3, OL)
    rect(img, 5, 30, 5, 2, c("cream3"))
    vline(img, 2, 26, 20, OL)
    vline(img, 3, 26, 20, c("gray4"))
    legs(img, 3, 38, 24, 8)
    floor_shadow(img, 3, 24)
    vline(img, 31, 20, 26, c("gray3"))
    rect(img, 28, 20, 7, 1, c("gray3"))
    rect(img, 29, 22, 4, 6, OL)
    rect(img, 30, 23, 2, 4, c("red2"))
    hline(img, 28, 45, 7, OL)
    screen(img, 37, 22, 12, 10, "green", graph=True)
    rect(img, 39, 32, 8, 2, OL)
    rect(img, 37, 34, 12, 12, OL)
    rect(img, 38, 35, 10, 10, c("cream2"))
    floor_shadow(img, 37, 12)
    box(img, 51, 20, 12, 26, "gray", 5)
    hline(img, 52, 33, 10, OL)
    rect(img, 55, 24, 4, 4, c("red3"))
    px(img, 53, 29, OL)
    px(img, 53, 37, OL)
    floor_shadow(img, 51, 12)
    return img


def room_armory():
    img = base("brick", "orange3", "orange2", floor_kind="metal", wains=("gray3", "gray4", 38), ceil="gray2")
    box(img, 3, 8, 30, 22, "wood", 1)
    for k in range(3):
        x = 8 + k * 9
        vline(img, x, 10, 18, OL)
        vline(img, x + 1, 10, 18, c("gray2"))
        rect(img, x - 1, 22, 4, 5, c("wood2"))
        frame(img, x - 1, 22, 4, 5, OL)
        px(img, x, 9, c("gray4"))
    rect(img, 38, 8, 12, 14, OL)
    rect(img, 39, 9, 10, 12, c("cream3"))
    ellipse(img, 40, 10, 8, 8, c("red2"))
    ellipse(img, 42, 12, 4, 4, c("cream3"))
    px(img, 43, 13, c("red2"))
    for (x, y, w, h) in ((36, 34, 13, 12), (49, 34, 13, 12), (42, 25, 14, 9)):
        box(img, x, y, w, h, "green", 2)
        rect(img, x + w // 2 - 2, y + 3, 4, 3, c("yellow2"))
        frame(img, x + w // 2 - 2, y + 3, 4, 3, OL)
    floor_shadow(img, 36, 26)
    box(img, 3, 34, 28, 4, "wood", 2)
    legs(img, 3, 38, 28, 8)
    rect(img, 7, 30, 11, 4, OL)
    rect(img, 8, 31, 9, 2, c("gray2"))
    rect(img, 21, 31, 5, 3, c("yellow2"))
    frame(img, 21, 31, 5, 3, OL)
    floor_shadow(img, 3, 28)
    return img


def room_science():
    img = base("panel", "purple3", "purple2", floor_kind="tile", wains=None)
    rect(img, 3, 8, 26, 17, c("wood1"))
    rect(img, 4, 9, 24, 15, OL)
    rect(img, 5, 10, 22, 13, c("green1"))
    for k, ln in enumerate((12, 8, 15)):
        hline(img, 7, 12 + k * 4, ln, c("gray5"))
    ellipse(img, 20, 13, 5, 5, None, c("yellow3"))
    shelf(img, 36, 16, 26, [])
    for k, (col, w, h) in enumerate((("toxic3", 5, 7), ("pink3", 4, 5), ("sky3", 5, 8), ("yellow2", 4, 6))):
        x = 38 + k * 6
        rect(img, x + w // 2 - 1, 16 - h - 2, 2, 3, OL)
        ellipse(img, x, 16 - h, w, h, OL)
        ellipse(img, x + 1, 16 - h + 2, w - 2, h - 3, c(col))
    box(img, 3, 34, 28, 4, "gray", 4)
    legs(img, 3, 38, 28, 8)
    screen(img, 7, 22, 13, 11, "teal")
    rect(img, 12, 33, 4, 1, OL)
    rect(img, 22, 31, 7, 3, OL)
    rect(img, 23, 32, 5, 1, c("gray5"))
    floor_shadow(img, 3, 28)
    box(img, 36, 32, 26, 14, "gray", 5)
    hline(img, 37, 38, 24, OL)
    ellipse(img, 39, 24, 8, 8, OL)
    ellipse(img, 40, 26, 6, 5, c("toxic2"))
    rect(img, 42, 21, 2, 4, OL)
    for k in range(3):
        px(img, 42 + k % 2, 19 - k * 2, c("toxic3"))
    rect(img, 53, 22, 3, 10, OL)
    rect(img, 50, 22, 8, 3, OL)
    rect(img, 51, 23, 6, 1, c("purple3"))
    rect(img, 50, 30, 9, 2, OL)
    floor_shadow(img, 36, 26)
    return img


def room_radio():
    img = base("plank", "sand3", "sand2", floor_kind="wood", wains=("wood1", "wood2", 38))
    rect(img, 3, 7, 22, 16, OL)
    rect(img, 4, 8, 20, 14, c("cream3"))
    for (x, y, w, h) in ((6, 10, 7, 5), (13, 14, 9, 6), (6, 17, 5, 4)):
        ellipse(img, x, y, w, h, c("green3"))
    line(img, 8, 12, 18, 17, c("red2"))
    for (x, y) in ((8, 12), (18, 17), (13, 15)):
        px(img, x, y, c("red1"))
    box(img, 29, 10, 34, 21, "gray", 2)
    for k in range(3):
        ellipse(img, 31 + k * 7, 13, 6, 6, OL)
        ellipse(img, 32 + k * 7, 14, 4, 4, c("gray4"))
        px(img, 34 + k * 7, 15, c("red3"))
    screen(img, 52, 13, 10, 8, "orange", graph=True)
    for k in range(7):
        rect(img, 31 + k * 4, 22, 2, 2, c(["green3", "yellow2", "red3"][k % 3]))
    rect(img, 31, 26, 30, 3, c("night1"))
    for k in range(0, 30, 3):
        vline(img, 31 + k, 26, 3, c("gray1"))
    px(img, 44, 27, c("orange3"))
    box(img, 27, 32, 37, 4, "wood", 2)
    legs(img, 27, 36, 37, 10)
    vline(img, 36, 26, 6, OL)
    rect(img, 34, 23, 5, 4, OL)
    rect(img, 35, 24, 3, 2, c("gray4"))
    ellipse(img, 8, 28, 9, 8, None, OL)
    rect(img, 7, 32, 3, 4, c("red2"))
    rect(img, 14, 32, 3, 4, c("red2"))
    floor_shadow(img, 27, 37)
    line(img, 58, 4, 62, 10, OL)
    return img


def room_engine():
    img = base("panel", "gray4", "gray3", floor_kind="hazard", wains=None, ceil="gray2")
    pipe_h(img, 0, 6, RW, "orange", 1)
    pipe_v(img, 6, 6, 40, "orange", 1)
    box(img, 16, 20, 32, 26, "red", 1)
    rect(img, 18, 22, 28, 6, c("gray3"))
    frame(img, 18, 22, 28, 6, OL)
    for k in range(3):
        x = 20 + k * 9
        rect(img, x, 12, 6, 10, OL)
        rect(img, x + 1, 13, 4, 8, c("gray4"))
        hline(img, x + 1, 13, 4, c("gray5"))
        rect(img, x, 10, 6, 3, c("gray2"))
    for k in range(5):
        hline(img, 20, 31 + k * 3, 24, c("red0"))
    gauge(img, 37, 34)
    gauge(img, 27, 34, "green2")
    floor_shadow(img, 16, 32)
    rect(img, 51, 10, 6, 36, OL)
    rect(img, 52, 10, 4, 36, c("gray3"))
    vline(img, 52, 10, 36, c("gray4"))
    box(img, 57, 32, 7, 14, "red", 2)
    hline(img, 58, 37, 5, OL)
    hline(img, 58, 41, 5, OL)
    poly(img, [(10, 26), (13, 19), (16, 26)], c("yellow2"), OL)
    px(img, 13, 22, OL)
    px(img, 13, 24, OL)
    return img


def room_refinery():
    img = base("brick", "yellow3", "sand2", floor_kind="metal", wains=("gray3", "gray4", 38), ceil="gray2")
    rect(img, 6, 6, 12, 40, OL)
    rect(img, 7, 7, 10, 38, c("gray4"))
    vline(img, 8, 7, 38, c("gray5"))
    for y in (14, 24, 34):
        hline(img, 6, y, 12, OL)
        hline(img, 7, y + 1, 10, c("gray3"))
    rect(img, 9, 17, 6, 5, OL)
    rect(img, 10, 18, 4, 3, c("orange3"))
    floor_shadow(img, 6, 12)
    for k, col in enumerate(("red3", "orange3", "lamp1")):
        poly(img, [(8 + k, 46), (12, 40 + k * 2), (16 - k, 46)], c(col))
    pipe_h(img, 17, 10, 24, "gray", 4)
    pipe_v(img, 37, 10, 14)
    rect(img, 31, 24, 14, 22, OL)
    rect(img, 32, 25, 12, 20, c("teal1"))
    for y in range(27, 44, 3):
        hline(img, 33, y, 10, c("teal3"))
    floor_shadow(img, 31, 14)
    barrel(img, 46, 33, "yellow", 9, 13, "fuel")
    barrel(img, 55, 33, "red", 9, 13, "fuel")
    barrel(img, 50, 20, "yellow", 9, 13, "fuel")
    floor_shadow(img, 46, 18)
    gauge(img, 21, 18)
    gauge(img, 21, 28, "green2")
    return img


def room_workshop():
    img = base("plank", "orange3", "orange2", floor_kind="wood", wains=("wood1", "wood2", 38))
    rect(img, 3, 7, 28, 19, OL)
    rect(img, 4, 8, 26, 17, c("sand2"))
    for y in range(10, 25, 3):
        for x in range(6, 29, 3):
            px(img, x, y, c("sand0"))
    line(img, 7, 10, 10, 21, c("gray4"), 2)
    ellipse(img, 5, 8, 5, 5, None, c("gray4"))
    rect(img, 13, 10, 6, 4, c("gray3"))
    frame(img, 13, 10, 6, 4, OL)
    rect(img, 15, 14, 2, 9, c("wood2"))
    poly(img, [(21, 10), (28, 10), (28, 19), (21, 14)], c("gray5"), OL)
    box(img, 3, 32, 32, 5, "wood", 2)
    legs(img, 3, 37, 32, 9)
    hline(img, 5, 42, 28, c("wood1"))
    rect(img, 6, 27, 8, 5, OL)
    rect(img, 7, 28, 6, 3, c("blue2"))
    for k in range(2):
        ellipse(img, 19 + k * 7, 28, 5, 5, OL)
        ellipse(img, 20 + k * 7, 29, 3, 3, c("gray4"))
    floor_shadow(img, 3, 32)
    for k, col in enumerate(("red", "blue", "yellow")):
        box(img, 39 + k * 8, 38, 8, 8, col, 2)
    ellipse(img, 43, 8, 16, 16, OL)
    ellipse(img, 44, 9, 14, 14, c("gray4"))
    ellipse(img, 48, 13, 6, 6, OL)
    for (dx, dy) in ((7, -1), (7, 14), (-1, 7), (14, 7)):
        rect(img, 44 + dx - 1, 9 + dy - 1, 3, 3, c("gray4"))
    rect(img, 40, 28, 22, 10, OL)
    rect(img, 41, 29, 20, 8, c("gray3"))
    ellipse(img, 44, 30, 6, 6, c("gray2"))
    floor_shadow(img, 39, 24)
    return img


def room_empty():
    img = base("panel", "cream2", "cream1", floor_kind="wood", wains=None)
    for (x, y, w, h) in ((4, 34, 13, 12), (15, 38, 9, 8), (47, 30, 15, 16)):
        box(img, x, y, w, h, "sand", 2)
        hline(img, x + 1, y + h // 2, w - 2, c("sand0"))
        rect(img, x + w // 2 - 1, y + 1, 2, h - 2, c("sand3"))
    floor_shadow(img, 4, 20)
    floor_shadow(img, 47, 15)
    line(img, 1, 4, 8, 4, c("gray5"))
    line(img, 1, 4, 1, 10, c("gray5"))
    line(img, 1, 4, 6, 9, c("gray5"))
    return img


def room_locked():
    img = new(RW, RH, c("gray2"))
    ceiling(img, "gray1")
    rect(img, 3, 4, 58, 42, OL)
    for y in range(5, 45, 4):
        rect(img, 4, y, 56, 3, c("gray3"))
        hline(img, 4, y, 56, c("gray4"))
        hline(img, 4, y + 3, 56, c("gray1"))
    rect(img, 0, 46, RW, 6, OL)
    for x in range(-6, RW, 8):
        poly(img, [(x, 51), (x + 4, 47), (x + 8, 47), (x + 4, 51)], c("yellow2"))
    ellipse(img, 27, 16, 10, 10, None, OL)
    ellipse(img, 28, 17, 8, 8, None, c("gray4"))
    orect(img, 25, 21, 14, 11, c("yellow2"))
    hline(img, 26, 22, 12, c("yellow3"))
    rect(img, 31, 24, 2, 4, OL)
    # rust + grime on the shutter
    for k in range(40):
        x, y = rr.randint(4, 59), rr.randint(5, 44)
        tint_px(img, x, y, c("orange1"), 0.5)
    return img


# ------------------------------------------------------------------ grim post-process (applied to every room)
LAMPS = {"engine": 24, "locked": None, "empty": 32, "refinery": 28}


def grime(img, rng):
    # soot along the ceiling, damp stains, rust drips from the slab above, cracks in the plaster
    for x in range(RW):
        for k, t in ((5, 0.35), (6, 0.22), (7, 0.12)):
            tint_px(img, x, k, c("ol0"), t)
    for _ in range(rng.randint(2, 4)):
        sx, sy = rng.randint(2, RW - 14), rng.randint(6, 30)
        w, h = rng.randint(6, 14), rng.randint(4, 9)
        for yy in range(sy, sy + h):
            for xx in range(sx, sx + w):
                d = ((xx - sx - w / 2) / (w / 2)) ** 2 + ((yy - sy - h / 2) / (h / 2)) ** 2
                if d < 1 and bayer(xx, yy) < 0.6 * (1 - d) + 0.15:
                    tint_px(img, xx, yy, c("wood0"), 0.28)
    for _ in range(rng.randint(3, 6)):
        x = rng.randint(1, RW - 2)
        for k in range(rng.randint(3, 12)):
            tint_px(img, x, 4 + k, c("orange1"), 0.55 - k * 0.04)
    for _ in range(rng.randint(1, 2)):
        x, y = rng.randint(4, RW - 6), rng.randint(8, 24)
        for k in range(rng.randint(5, 10)):
            px(img, x, y, blend(get(img, x, y), c("ol0"), 0.6))
            x += rng.choice((-1, 0, 1))
            y += 1
    # dirt on the floor
    for x in range(RW):
        if rng.random() < 0.25:
            tint_px(img, x, FLOOR + rng.randint(0, 4), c("ol0"), 0.3)


def light(img, lamp_x, rng):
    """dark room + warm pool of light under the bulb (dithered falloff, true pixel)"""
    for y in range(4, RH):
        for x in range(RW):
            if lamp_x is None:
                d = 1.0
            else:
                dx = (x - lamp_x) / 36.0
                dy = (y - 8) / 60.0
                d = min(1.0, math.hypot(dx * 1.1, dy))
            dark = 0.12 + 0.5 * d
            edge = min(x, RW - 1 - x)
            if edge < 4:
                dark += (4 - edge) * 0.05
            p = get(img, x, y)
            if p[3] == 0:
                continue
            q = blend(p, c("night0"), dark if bayer(x, y) < 0.5 else dark - 0.06)
            if lamp_x is not None and d < 0.45:
                warm = (0.45 - d) * (0.5 if bayer(x + 1, y) < 0.5 else 0.42)
                q = blend(q, c("lamp1"), warm)
            px(img, x, y, q)


ROOMS = {
    "quarters": room_quarters, "kitchen": room_kitchen, "hydroponics": room_hydro, "water": room_water,
    "medical": room_medical, "armory": room_armory, "science": room_science, "radio": room_radio,
    "engine": room_engine, "refinery": room_refinery, "workshop": room_workshop,
    "empty": room_empty, "locked": room_locked,
}


def gen_rooms():
    for k, fn in ROOMS.items():
        img = fn()
        rng = random.Random(len(k) * 13)
        if k != "locked":
            grime(img, rng)
        lx = LAMPS.get(k, 32)
        light(img, lx, rng)
        if lx is not None:
            ceiling_lamp(img, lx)
        add("room_" + k, img)
    gen_construction()


# ------------------------------------------------------------------ v4.3 construction site
def room_construct():
    """bare steel frame of a room that is still being put up: raw rusty panels, I-beams, cross bracing,
    a tarp over the gap in the hull, sandbags, a toolbox and loose planks. Lit by a caged work lamp."""
    img = base("panel", "gray3", "gray2", floor_kind="metal", wains=None, ceil="gray1")
    # missing wall panels: dark gaps showing the hull ribs behind
    for (x, w) in ((22, 12), (44, 9)):
        rect(img, x, 8, w, 22, c("gray1"))
        for y in range(10, 30, 5):
            hline(img, x, y, w, c("gray0"))
    # vertical I-beams
    for x in (2, 31, 58):
        rect(img, x, 4, 4, 42, OL)
        rect(img, x + 1, 4, 2, 42, c("orange1"))
        vline(img, x + 1, 4, 42, c("orange2"))
        for y in range(8, 44, 7):
            px(img, x + 2, y, c("gray5"))                  # rivets
    # cross bracing
    line(img, 6, 8, 30, 30, c("orange1"))
    line(img, 6, 30, 30, 8, c("orange0"))
    # horizontal girder
    rect(img, 0, 30, RW, 3, OL)
    hline(img, 0, 31, RW, c("orange2"))
    # torn tarp hanging on the right
    poly(img, [(36, 6), (56, 6), (55, 22), (49, 26), (44, 21), (37, 24)], c("teal1"), OL)
    for x in range(39, 55, 4):
        vline(img, x, 7, 14, c("teal2"))
    # hazard tape
    for x in range(0, RW, 6):
        rect(img, x, 36, 3, 2, c("yellow2"))
        rect(img, x + 3, 36, 3, 2, OL)
    # sandbags + toolbox + loose planks on the floor
    for k, (x, y) in enumerate(((5, 41), (11, 41), (8, 37))):
        ellipse(img, x, y, 8, 5, c("sand2"), OL)
        hline(img, x + 2, y + 1, 4, c("sand3"))
    box(img, 46, 39, 12, 7, "red", 2)
    hline(img, 49, 38, 6, OL)
    line(img, 20, 45, 42, 41, c("wood3"))
    line(img, 20, 46, 42, 42, c("wood1"))
    line(img, 24, 45, 40, 45, c("wood2"))
    floor_shadow(img, 5, 16)
    floor_shadow(img, 46, 12)
    return img


def scaffold_front():
    """transparent scaffolding drawn over the room while it is worked on (crew stay visible between poles)"""
    img = new(RW, RH)
    for x in (4, 59):
        rect(img, x - 1, 4, 3, 42, OL)
        vline(img, x, 4, 42, c("gray4"))
        for y in range(6, 46, 8):
            hline(img, x - 1, y, 3, c("gray5"))            # clamps
    for y in (18, 33):
        rect(img, 2, y, 60, 3, OL)
        hline(img, 3, y + 1, 58, c("wood3"))
        for x in range(10, 60, 12):
            px(img, x, y + 1, c("wood1"))
    line(img, 5, 21, 58, 33, c("gray3"))
    # warning sign hanging from the top plank
    orect(img, 27, 21, 10, 9, c("yellow2"))
    poly(img, [(32, 22), (35, 28), (29, 28)], OL)
    px(img, 32, 25, c("yellow2"))
    return img


def fx_weld(f):
    """welding sparks, 4 frames"""
    img = new(9, 9)
    r = random.Random(500 + f)
    px(img, 4, 4, c("lamp2"))
    for k in range(5 + f * 2):
        a = r.uniform(0, math.tau)
        d = r.uniform(1, 2 + f)
        col = c("lamp2") if d < 2 else (c("lamp1") if d < 3.5 else c("yellow2"))
        px(img, 4 + round(math.cos(a) * d), 4 + round(math.sin(a) * d), col)
    return img


def fx_dust(f):
    """dust puff kicked up by a hammer blow, 3 frames"""
    img = new(10, 6)
    r = 2 + f
    ellipse(img, 5 - r, 5 - r // 2 - 1, r * 2, r + 1, c("sand2"))
    if f > 0:
        for x in range(10):
            for y in range(6):
                if get(img, x, y)[3] and bayer(x, y) < 0.25 * f:
                    px(img, x, y, CLEAR)
    return img


def gen_construction():
    img = room_construct()
    rng = random.Random(4243)
    grime(img, rng)
    light(img, 32, rng)
    ceiling_lamp(img, 32, "lamp0")
    add("room_construct", img)
    add("scaffold_front", scaffold_front())
    for f in range(4):
        add(f"fx_weld_{f}", fx_weld(f))
    for f in range(3):
        add(f"fx_dust_{f}", fx_dust(f))
