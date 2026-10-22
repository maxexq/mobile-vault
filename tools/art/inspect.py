"""Stranger inspection close-ups (v4.4): a flashlit portrait at the door, layered at runtime
(backdrop + face/skin + hair + eyes), plus 96x48 magnified details for each body check.

  assets/inspect/door.png               64x80 rainy doorway backdrop with the torch beam
  assets/inspect/face_<skin>.png        64x80 head + shoulders (3 skin tones)
  assets/inspect/hair_<n>.png           64x80 hair / hood overlays
  assets/inspect/eyes_<kind>.png        64x80 eye overlay: normal | red | glassy
  assets/inspect/d_<check>_<sign>.png   96x48 magnified detail shown after a check

Run alone:  python3 -c "import sys; sys.path.insert(0,'tools'); from art import inspect; inspect.gen_inspect()"
"""
import os, random
from .common import *

OUT_IN = os.path.join(ROOT, "assets", "inspect")
PW, PH = 64, 80
DW, DH = 96, 48
SKINS = {"a": "skin", "b": "wood", "c": "pink"}   # pale-ish / dark / ruddy — all grimy
ri = random.Random(4417)


def _save(img, name):
    os.makedirs(OUT_IN, exist_ok=True)
    save(img, os.path.join(OUT_IN, name + ".png"))


def _sk(skin, i):
    ramp = SKINS[skin]
    n = len(RAMPS[ramp])
    return c("%s%d" % (ramp, max(0, min(n - 1, i))))


# ------------------------------------------------------------------ portrait layers
def door():
    img = new(PW, PH, c("night0"))
    # door frame: rusted steel jambs, the night outside, rain
    gradient_v(img, 8, 0, 48, PH, [(0.0, c("night1")), (1.0, c("night2"))])
    for x in (0, 56):
        rect(img, x, 0, 8, PH, c("gray1"))
        vline(img, x + (7 if x == 0 else 0), 0, PH, OL)
        for y in range(4, PH, 13):
            px(img, x + 3, y, c("gray3"))
            px(img, x + 4, y + 1, c("orange1"))
    rect(img, 0, 0, PW, 5, c("gray1"))
    hline(img, 0, 5, PW, OL)
    for _ in range(70):
        x = ri.randint(9, 54)
        y = ri.randint(6, PH - 4)
        vline(img, x, y, ri.randint(2, 4), c("blue2"))
    # torch beam from the bottom-left (our side of the door)
    light_cone(img, 30, 4, 16, 60, PH - 4, c("lamp1"), strength=0.22, steps=3)
    speckle(img, 0, 0, PW, PH, [c("gray0"), c("orange0")], density=0.04, rng=ri)
    return img


def face(skin):
    img = new(PW, PH)
    # shoulders: ragged coat with a scarf
    poly(img, [(4, PH), (10, 60), (22, 54), (42, 54), (54, 60), (60, PH)], c("gray2"), OL)
    poly(img, [(18, 58), (26, 54), (38, 54), (46, 58), (40, 64), (24, 64)], c("red1"), OL)
    for x in range(12, 54, 5):
        px(img, x, 66 + (x % 3), c("gray1"))
    rect(img, 27, 46, 10, 10, _sk(skin, 1))           # neck
    vline(img, 27, 46, 9, OL)
    vline(img, 36, 46, 9, OL)
    # head
    ellipse(img, 16, 10, 32, 40, _sk(skin, 2), OL)
    ellipse(img, 13, 26, 5, 9, _sk(skin, 1), OL)      # ears
    ellipse(img, 46, 26, 5, 9, _sk(skin, 1), OL)
    ellipse(img, 20, 14, 18, 22, _sk(skin, 3))        # lit cheek / forehead
    shade_rect(img, 38, 14, 10, 34, c("ol0"), 0.35)   # far side in shadow
    # brows, nose, closed mouth, grime
    hline(img, 22, 24, 7, _sk(skin, 0))
    hline(img, 35, 24, 7, _sk(skin, 0))
    vline(img, 32, 28, 7, _sk(skin, 1))
    px(img, 31, 35, _sk(skin, 0))
    px(img, 33, 35, _sk(skin, 0))
    hline(img, 28, 40, 9, _sk(skin, 0))
    px(img, 27, 39, _sk(skin, 1))
    hline(img, 29, 41, 7, _sk(skin, 1))
    for _ in range(45):
        x = ri.randint(19, 45)
        y = ri.randint(30, 47)
        if get(img, x, y)[3] > 0:
            px(img, x, y, blend(get(img, x, y), c("ol0"), 0.35))  # stubble / soot
    line(img, 40, 16, 43, 21, _sk(skin, 0))           # old scar
    light_radial(img, 22, 22, 22, c("lamp1"), strength=0.25, steps=3)
    return img


def hair(n):
    img = new(PW, PH)
    if n == 0:   # short spiky
        poly(img, [(15, 24), (17, 12), (22, 6), (30, 4), (40, 6), (47, 13), (49, 24), (44, 15), (36, 12), (26, 13), (19, 17)],
             c("wood1"), OL)
        for x in range(20, 46, 4):
            line(img, x, 7, x + 1, 11, c("wood2"))
    elif n == 1:  # long, tied back, strands over the face
        poly(img, [(14, 34), (15, 14), (24, 6), (40, 6), (49, 14), (50, 34), (46, 20), (32, 13), (19, 20)], c("gray1"), OL)
        line(img, 20, 18, 18, 36, c("gray2"))
        line(img, 44, 18, 47, 38, c("gray2"))
        rect(img, 47, 30, 6, 16, c("gray1"))
        frame(img, 47, 30, 6, 16, OL)
    elif n == 2:  # rag hood
        poly(img, [(10, 56), (11, 22), (18, 8), (32, 3), (46, 8), (53, 22), (54, 56), (48, 50), (47, 24), (40, 14), (24, 14), (17, 24), (16, 50)],
             c("green1"), OL)
        line(img, 18, 12, 14, 40, c("green2"))
        for _ in range(30):
            x, y = ri.randint(11, 53), ri.randint(4, 54)
            if get(img, x, y)[3] > 0:
                px(img, x, y, c("green0"))
    else:         # shaved, tight goggles strap
        hline(img, 16, 19, 32, c("gray1"))
        hline(img, 16, 20, 32, OL)
        rect(img, 41, 15, 8, 7, c("gray2"))
        frame(img, 41, 15, 8, 7, OL)
        px(img, 44, 17, c("teal3"))
        for _ in range(20):
            x, y = ri.randint(20, 44), ri.randint(11, 18)
            px(img, x, y, c("gray1"))
    return img


def eyes(kind):
    img = new(PW, PH)
    for ex in (23, 36):
        sclera = c("cream3")
        iris = c("wood2")
        if kind == "red":
            sclera = c("red4")
        if kind == "glassy":
            sclera = c("cream2")
            iris = c("gray5")
        rect(img, ex, 27, 6, 3, sclera)
        frame(img, ex - 1, 26, 8, 5, OL)
        rect(img, ex + 2, 27, 2, 3, iris)
        px(img, ex + 2, 28, OL if kind != "glassy" else c("lamp2"))   # glassy eyes throw the torch back
        if kind == "red":
            px(img, ex, 28, c("red2"))
            px(img, ex + 5, 27, c("red2"))
            hline(img, ex - 1, 31, 8, c("purple2"))                  # dark bags
    return img


# ------------------------------------------------------------------ magnified details (96x48)
def _lens():
    img = new(DW, DH, c("night0"))
    gradient_v(img, 0, 0, DW, DH, [(0.0, c("gray1")), (1.0, c("night1"))])
    return img


def _vignette(img):
    light_radial(img, DW // 2, DH // 2, 52, c("lamp1"), strength=0.2, steps=3)
    for y in range(DH):
        for x in range(DW):
            dx, dy = (x - DW / 2) / (DW / 2), (y - DH / 2) / (DH / 2)
            if dx * dx + dy * dy > 1.05:
                px(img, x, y, c("night0"))
    frame(img, 0, 0, DW, DH, c("gray3"))
    return img


def d_eyes(kind):
    img = _lens()
    rect(img, 0, 0, DW, DH, c("skin2"))
    hline(img, 20, 10, 56, c("skin0"))                 # brow
    ellipse(img, 22, 14, 52, 22, OL)
    sclera = {"normal": "cream3", "red": "red4", "glassy": "cream2"}[kind]
    ellipse(img, 23, 15, 50, 20, c(sclera))
    iris = {"normal": "wood3", "red": "wood2", "glassy": "gray5"}[kind]
    ellipse(img, 39, 15, 18, 20, c(iris), OL)
    ellipse(img, 44, 20, 8, 10, OL)
    if kind == "glassy":
        ellipse(img, 44, 20, 8, 10, c("gray6"))
        rect(img, 46, 22, 4, 5, c("lamp2"))            # flat, mirror-like pupil
        frame(img, 44, 20, 8, 10, c("gray4"))
    else:
        px(img, 46, 21, c("cream3"))                   # normal wet highlight
    if kind == "red":
        for (x0, y0, x1, y1) in ((24, 24, 34, 22), (26, 28, 36, 26), (60, 20, 70, 23), (58, 28, 70, 27), (30, 18, 37, 21)):
            line(img, x0, y0, x1, y1, c("red2"))
        hline(img, 24, 37, 48, c("purple2"))
    hline(img, 22, 14, 52, OL)
    return _vignette(img)


def d_teeth(kind):
    img = _lens()
    rect(img, 0, 0, DW, DH, c("skin2"))
    ellipse(img, 12, 8, 72, 32, c("red1"), OL)        # open mouth
    ellipse(img, 16, 26, 64, 12, c("red0"))           # throat shadow
    if kind == "perfect":
        for i in range(14):                            # too many, too even, too white
            rect(img, 18 + i * 4, 12, 3, 9, c("lamp2"))
            rect(img, 18 + i * 4, 27, 3, 7, c("lamp2"))
            vline(img, 21 + i * 4, 12, 9, c("gray6"))
        hline(img, 18, 11, 56, c("pink3"))
    else:
        rot = kind == "rot"
        for i in range(9):
            if rot and i in (2, 6):
                continue
            h = 8 - (i % 3)
            col = c("cream2") if i % 2 else c("cream1")
            if rot:
                col = c("wood1") if i % 3 else c("ol1")
            rect(img, 18 + i * 6, 12, 5, h, col)
            frame(img, 18 + i * 6, 12, 5, h, OL)
            if not rot and i % 4 == 0:
                px(img, 20 + i * 6, 12 + h - 2, c("sand1"))   # ordinary stains
        for i in range(8):
            if rot and i in (1, 4, 5):
                continue
            rect(img, 21 + i * 6, 28, 5, 6, c("cream1") if not rot else c("wood0"))
            frame(img, 21 + i * 6, 28, 5, 6, OL)
        if rot:
            hline(img, 16, 11, 64, c("purple2"))       # swollen black gums
            hline(img, 16, 35, 64, c("purple2"))
            for x in range(20, 70, 9):
                vline(img, x, 36, 3, c("toxic1"))      # drool with a sick tint
    return _vignette(img)


def d_hands(kind):
    img = _lens()
    rect(img, 0, 0, DW, DH, c("wood1"))
    skin = "skin"
    poly(img, [(6, 48), (14, 26), (36, 18), (70, 16), (90, 20), (90, 34), (60, 40), (30, 48)], c(skin + "2"), OL)
    for i, y in enumerate((17, 23, 29, 35)):           # fingers to the right
        rect(img, 70, y, 22, 5, c(skin + "2"))
        frame(img, 70, y, 22, 5, OL)
        nail = c("cream1") if kind == "spotless" else c("cream0")
        rect(img, 87, y + 1, 4, 3, nail)
        if kind != "spotless":
            hline(img, 87, y + 3, 4, c("ol1"))          # dirt under the nails
    if kind != "spotless":
        for _ in range(60):
            x, y = ri.randint(14, 86), ri.randint(18, 46)
            if get(img, x, y)[:3] == c(skin + "2")[:3]:
                px(img, x, y, c(skin + "1"))           # grime + calluses
        line(img, 30, 30, 44, 26, c(skin + "0"))       # healed cut
    else:
        light_radial(img, 50, 28, 30, c("cream3"), strength=0.25, steps=2)   # unnaturally smooth
    if kind == "veins":
        for (x0, y0, x1, y1) in ((10, 46, 30, 32), (30, 32, 44, 30), (18, 46, 36, 38), (36, 38, 56, 34), (24, 48, 40, 44), (44, 30, 62, 24)):
            line(img, x0, y0, x1, y1, c("toxic0"))
            line(img, x0, y0 - 1, x1, y1 - 1, c("purple1"))
    if kind == "tattoo":
        ellipse(img, 40, 24, 14, 14, OL)               # gang skull with the red cross
        ellipse(img, 41, 25, 12, 10, c("cream1"))
        px(img, 44, 29, OL)
        px(img, 49, 29, OL)
        line(img, 38, 22, 56, 40, c("red3"), 2)
        line(img, 56, 22, 38, 40, c("red3"), 2)
    return _vignette(img)


def d_neck(kind):
    img = _lens()
    rect(img, 0, 0, DW, DH, c("gray1"))
    rect(img, 0, 12, DW, 24, c("skin2"))               # rolled-up forearm
    hline(img, 0, 12, DW, OL)
    hline(img, 0, 35, DW, OL)
    shade_rect(img, 0, 28, DW, 7, c("ol0"), 0.3)
    rect(img, 0, 8, 14, 32, c("green1"))                # rolled sleeve
    frame(img, 0, 8, 14, 32, OL)
    line(img, 30, 20, 40, 18, c("skin1"))              # everybody has scratches out here
    line(img, 66, 26, 74, 27, c("skin1"))
    if kind == "bite":
        rect(img, 42, 13, 26, 22, c("cream1"))         # dirty bandage
        for x in range(42, 68, 4):
            vline(img, x, 13, 22, c("cream0"))
        ellipse(img, 48, 18, 14, 12, c("red1"))         # seeping through
        ellipse(img, 51, 20, 8, 7, c("purple1"))
        for (x, y) in ((50, 19), (54, 18), (57, 22), (49, 27), (55, 28)):
            px(img, x, y, OL)                          # tooth marks
        line(img, 68, 22, 82, 18, c("toxic0"))         # infection creeping out
        line(img, 68, 27, 84, 30, c("toxic0"))
    if kind == "brand":
        for (x0, y0, x1, y1) in ((46, 16, 58, 32), (58, 16, 46, 32), (44, 24, 60, 24)):
            line(img, x0, y0, x1, y1, c("red2"), 2)    # burnt raider brand
        ellipse(img, 42, 14, 20, 20, None, c("pink2"))
    return _vignette(img)


def d_bag(kind):
    img = _lens()
    rect(img, 0, 0, DW, DH, c("gray0"))
    poly(img, [(8, 46), (14, 8), (82, 8), (88, 46)], c("green1"), OL)   # open backpack
    rect(img, 16, 12, 64, 30, c("night1"))
    frame(img, 16, 12, 64, 30, c("green0"))
    # ordinary survivor stuff
    rect(img, 20, 24, 10, 14, c("gray4")); frame(img, 20, 24, 10, 14, OL); hline(img, 20, 29, 10, c("red2"))   # can
    rect(img, 34, 18, 7, 20, c("teal2")); frame(img, 34, 18, 7, 20, OL); rect(img, 35, 16, 5, 3, c("gray3"))  # bottle
    poly(img, [(44, 38), (50, 26), (60, 30), (56, 40)], c("cream1"), OL)    # rag
    if kind == "picks":
        for i in range(4):
            line(img, 62 + i * 3, 16, 64 + i * 3, 36, c("gray5"))          # lockpicks
            px(img, 64 + i * 3, 37, c("yellow2"))
        for i in range(3):                                                 # someone else's IDs and watches
            rect(img, 46 + i * 5, 14 + i * 3, 9, 6, c("cream2")); frame(img, 46 + i * 5, 14 + i * 3, 9, 6, OL)
            px(img, 48 + i * 5, 16 + i * 3, c("skin1"))
        ellipse(img, 22, 14, 8, 8, c("yellow3"), OL)
        ellipse(img, 70, 34, 7, 7, c("yellow2"), OL)
    if kind == "radio":
        rect(img, 62, 14, 12, 24, c("gray2")); frame(img, 62, 14, 12, 24, OL)
        vline(img, 66, 6, 8, c("gray3"))
        px(img, 70, 17, c("red4"))                     # live, blinking
        for y in range(22, 34, 3):
            hline(img, 64, y, 8, c("gray1"))
        rect(img, 46, 14, 14, 10, c("cream1")); frame(img, 46, 14, 14, 10, OL)   # map ...
        line(img, 48, 16, 56, 22, c("red3"))
        line(img, 56, 16, 48, 22, c("red3"))           # ... with our route marked
        rect(img, 76, 18, 3, 16, c("red2")); px(img, 77, 17, c("yellow3"))       # flare
    return _vignette(img)


def d_temp():
    img = _lens()
    rect(img, 18, 20, 60, 8, c("cream2"))
    frame(img, 17, 19, 62, 10, OL)
    ellipse(img, 10, 16, 14, 16, c("red3"), OL)
    for x in range(26, 76, 5):
        vline(img, x, 20, 3, c("gray2"))
    rect(img, 22, 23, 40, 2, c("red3"))
    return _vignette(img)


def d_refused():
    img = _lens()
    rect(img, 0, 0, DW, DH, c("gray0"))
    poly(img, [(14, 46), (20, 8), (76, 8), (82, 46)], c("green1"), OL)   # closed bag, a hand pulls it back
    rect(img, 22, 20, 52, 4, c("gray3"))
    poly(img, [(54, 26), (70, 20), (92, 24), (92, 36), (66, 36)], c("skin2"), OL)
    return _vignette(img)


def gen_inspect():
    _save(door(), "door")
    for s in SKINS:
        _save(face(s), "face_" + s)
    for n in range(4):
        _save(hair(n), "hair_%d" % n)
    for k in ("normal", "red", "glassy"):
        _save(eyes(k), "eyes_" + k)
        _save(d_eyes(k), "d_eyes_" + k)
    for k in ("normal", "rot", "perfect"):
        _save(d_teeth(k), "d_teeth_" + k)
    for k in ("normal", "veins", "spotless", "tattoo"):
        _save(d_hands(k), "d_hands_" + k)
    for k in ("normal", "bite", "brand"):
        _save(d_neck(k), "d_neck_" + k)
    for k in ("normal", "picks", "radio"):
        _save(d_bag(k), "d_bag_" + k)
    _save(d_temp(), "d_temp")
    _save(d_refused(), "d_refused")
    print("inspect art", len(os.listdir(OUT_IN)))
