"""Grim 16-bit survivors (14x20 frames, 9-frame sheets), 20x20 portraits, mutated enemies and bosses.
Soot-black outlines, top-left key light (the room's bulb), 2-3 shade steps, grime and wear."""
import math, random
from .common import *

rc = random.Random(99)
FW, FH = 14, 20


def auto_shade(img, hi=0.25, lo=0.35, hi_col=None, lo_col=None, lx=-1, ly=-1):
    """rim light on edges facing the key light (top-left), shadow on the opposite edges"""
    hi_col = hi_col or c("gray6")
    lo_col = lo_col or c("ol0")
    src = img.copy()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            p = src.getpixel((x, y))
            if p[3] == 0 or p[:3] == OL[:3]:
                continue
            a = get(src, x + lx, y + ly)[3] == 0 or get(src, x + lx, y + ly)[:3] == OL[:3]
            b = get(src, x - lx, y - ly)[3] == 0 or get(src, x - lx, y - ly)[:3] == OL[:3]
            if a and not b:
                px(img, x, y, blend(p, hi_col, hi))
            elif b and not a:
                px(img, x, y, blend(p, lo_col, lo))
    return img


# ================================================================== SURVIVORS (face RIGHT)
OUTFITS = {
    #            coat      coat-dark  pants     pants-dark  boots     hat
    "army":     ("green3", "green2", "green2", "green1", "wood1", "helmet"),
    "scav":     ("orange2", "orange1", "wood2", "wood1", "wood0", "goggles"),
    "lab":      ("cream3", "cream2", "blue2", "blue1", "gray1", "none"),
    "chef":     ("cream3", "cream2", "gray2", "gray1", "gray1", "rag"),
    "jumpsuit": ("blue3", "blue2", "blue3", "blue2", "gray1", "cap"),
    "medic":    ("cream3", "cream2", "teal2", "teal1", "gray1", "nurse"),
    "raider":   ("gray3", "gray2", "red1", "red0", "gray0", "mohawk"),
}
HAIRS = {"brown": ("wood2", "wood1"), "black": ("gray1", "gray0"), "blonde": ("yellow2", "yellow1"),
         "red": ("orange2", "orange1"), "gray": ("gray4", "gray3")}
SKINS = ["skin2", "skin1", "skin2", "skin3"]
FRAMES = [
    ("idle", 0, "stand", 0), ("idle", 1, "stand", 1),
    ("walk", 0, "walkA", 0), ("walk", 1, "walkB", 1), ("walk", 2, "walkC", 0), ("walk", 3, "walkB", 1),
    ("sit", 0, "sit", 0),
    ("work", 0, "work1", 0), ("work", 1, "work2", 1),
    # micro-animations while off duty (frames 9..14)
    ("guitar", 0, "guitar1", 0), ("guitar", 1, "guitar2", 0),
    ("coffee", 0, "coffee1", 0), ("coffee", 1, "coffee2", 1),
    ("clean", 0, "clean1", 0), ("clean", 1, "clean2", 0),
]


def draw_head(img, ox, oy, outfit, hair, skin, blink=False):
    """8x8 head (3/4 side view, faces right) at (ox, oy)"""
    o = OUTFITS[outfit]
    hc, hd = HAIRS[hair]
    sk = c(skin)
    skd = blend(sk, c("ol0"), 0.3)
    rect(img, ox + 1, oy, 6, 8, sk)
    rect(img, ox, oy + 1, 8, 6, sk)
    vline(img, ox, oy + 2, 4, skd)                     # back of the head in shadow
    hline(img, ox + 2, oy + 7, 5, skd)                 # jaw shadow
    px(img, ox + 7, oy + 4, sk)                        # nose
    px(img, ox + 8, oy + 4, sk)
    # hair / hats
    hat = o[5]
    if hat in ("none", "goggles", "nurse", "mohawk", "cap", "rag"):
        rect(img, ox, oy, 7, 2, c(hc))
        rect(img, ox, oy + 2, 3, 3, c(hc))
        px(img, ox + 1, oy, c(hd))
        px(img, ox, oy + 4, c(hd))
    if hat == "helmet":
        rect(img, ox - 1, oy - 1, 10, 4, c(o[1]))
        hline(img, ox, oy - 1, 7, c(o[0]))
        hline(img, ox - 1, oy + 3, 10, c("gray1"))
        px(img, ox + 2, oy, c("green4"))
    elif hat == "rag":
        rect(img, ox - 1, oy - 1, 9, 3, c("cream2"))
        px(img, ox - 2, oy + 2, c("cream1"))
        px(img, ox - 2, oy + 3, c("cream1"))
    elif hat == "cap":
        rect(img, ox, oy - 1, 8, 3, c("red2"))
        hline(img, ox + 6, oy + 1, 4, c("red1"))
    elif hat == "goggles":
        hline(img, ox, oy + 2, 8, c("gray1"))
        rect(img, ox + 5, oy + 1, 3, 2, c("teal3"))
        px(img, ox + 6, oy + 1, c("gray6"))
    elif hat == "nurse":
        rect(img, ox + 1, oy - 2, 5, 2, c("cream3"))
        px(img, ox + 3, oy - 2, c("red3"))
    elif hat == "mohawk":
        for k in range(4):
            vline(img, ox + 1 + k * 2, oy - 2 - (k % 2), 3, c("red3"))
    # face: one dark eye, brow, mouth line; grime on the cheek
    if blink:
        hline(img, ox + 5, oy + 4, 2, c("ol1"))
    else:
        px(img, ox + 6, oy + 3, c("ol0"))
        px(img, ox + 6, oy + 4, c("ol0"))
        hline(img, ox + 5, oy + 2, 3, blend(c(hd), sk, 0.3) if hat != "goggles" else c("gray1"))
    px(img, ox + 6, oy + 6, skd)
    px(img, ox + 3, oy + 5, blend(sk, c("wood0"), 0.35))


def draw_body(img, ox, oy, outfit, skin, pose):
    """torso + arms + legs; oy = top of torso (6 tall), legs 4, boots 1"""
    o = OUTFITS[outfit]
    sh, shd, pa, pad, boot = c(o[0]), c(o[1]), c(o[2]), c(o[3]), c(o[4])
    sk = c(skin)
    # back arm (in shadow)
    ba = 1 if pose == "walkA" else (-1 if pose == "walkC" else 0)
    rect(img, ox + 3 - ba, oy + 1, 2, 4, shd)
    px(img, ox + 3 - ba, oy + 5, blend(sk, c("ol0"), 0.3))
    # torso
    rect(img, ox + 4, oy, 6, 6, sh)
    vline(img, ox + 9, oy + 1, 5, shd)
    hline(img, ox + 4, oy + 5, 6, c("wood0"))           # belt
    px(img, ox + 7, oy + 5, c("yellow1"))
    if outfit == "medic":
        rect(img, ox + 6, oy + 1, 1, 3, c("red3"))
        rect(img, ox + 5, oy + 2, 3, 1, c("red3"))
    elif outfit == "lab":
        vline(img, ox + 7, oy, 5, c("cream1"))
        px(img, ox + 8, oy + 1, c("teal2"))
    elif outfit == "chef":
        rect(img, ox + 5, oy + 1, 4, 4, c("cream2"))
        px(img, ox + 6, oy + 3, c("red1"))
    elif outfit == "scav":
        line(img, ox + 4, oy, ox + 9, oy + 4, c("wood1"))
        px(img, ox + 5, oy + 3, c("gray3"))
    elif outfit == "army":
        px(img, ox + 5, oy + 1, c("green4"))
        px(img, ox + 8, oy + 2, c("green1"))
    elif outfit == "jumpsuit":
        vline(img, ox + 7, oy, 5, c("yellow2"))
    elif outfit == "raider":
        for k in range(3):
            px(img, ox + 5 + k * 2, oy + 1, c("gray5"))
    # front arm
    if pose in ("work1", "work2"):
        ay = oy + (1 if pose == "work1" else 2)
        rect(img, ox + 9, ay, 3, 2, sh)
        px(img, ox + 12, ay, sk)
        px(img, ox + 12, ay + 1, sk)
    else:
        fa = 1 if pose == "walkC" else (-1 if pose == "walkA" else 0)
        rect(img, ox + 8 + max(fa, 0), oy + 1, 2, 4, sh)
        px(img, ox + 8 + max(fa, 0), oy + 5, sk)
    # legs
    ly = oy + 6
    if pose == "sit":
        rect(img, ox + 5, ly, 6, 2, pa)
        rect(img, ox + 9, ly + 2, 2, 2, pad)
        hline(img, ox + 9, ly + 4, 3, boot)
        return
    if pose == "walkA":
        legs = [(4, pad, 0), (8, pa, 0)]
    elif pose == "walkC":
        legs = [(5, pad, 0), (7, pa, 0)]
    else:
        legs = [(5, pad, 0), (7, pa, 0)]
    for lx, col, _ in legs:
        rect(img, ox + lx, ly, 2, 3, col)
        rect(img, ox + lx, ly + 3, 3 if lx > 5 else 2, 1, boot)
        if lx <= 5:
            px(img, ox + lx - 1, ly + 3, boot)


def _props(img, pose, skin):
    sk = c(skin)
    if pose.startswith("guitar"):
        # acoustic guitar across the lap, strumming hand moves
        ellipse(img, 5, 13, 6, 5, c("wood2"))
        px(img, 7, 15, c("ol0"))
        line(img, 10, 14, 13, 11, c("wood1"))
        px(img, 13, 10, c("wood3"))
        hy = 13 if pose == "guitar1" else 15
        px(img, 6, hy, sk)
        px(img, 12, 12, sk)
    elif pose.startswith("coffee"):
        my = 9 if pose == "coffee1" else 10
        rect(img, 10, my, 3, 3, c("cream2"))
        px(img, 13, my + 1, c("cream1"))
        px(img, 10, my - 1, sk)
        if pose == "coffee1":
            px(img, 11, my - 2, c("gray5"))
            px(img, 12, my - 4, c("gray4"))
    elif pose.startswith("clean"):
        # rifle on the knees, rag moving along the barrel
        hline(img, 2, 15, 12, c("gray2"))
        rect(img, 2, 15, 3, 2, c("wood1"))
        px(img, 13, 15, c("gray4"))
        rx = 7 if pose == "clean1" else 10
        rect(img, rx, 14, 2, 2, c("cream2"))
        px(img, rx, 13, sk)


def dweller_frame(outfit, hair, pose, bob, skin="skin2", blink=False):
    img = new(FW, FH)
    b = 1 if bob else 0
    if pose[:-1] in ("guitar", "clean"):
        draw_body(img, 0, 11, outfit, skin, "sit")
        draw_head(img, 3, 3, outfit, hair, skin, blink)
        _props(img, pose, skin)
        img = auto_shade(img, 0.18, 0.3)
        return outline_alpha(img)
    if pose[:-1] == "coffee":
        draw_body(img, 0, 9, outfit, skin, "stand")
        draw_head(img, 3, 1 + b, outfit, hair, skin, blink)
        _props(img, pose, skin)
        img = auto_shade(img, 0.18, 0.3)
        return outline_alpha(img)
    if pose == "sit":
        draw_body(img, 0, 11, outfit, skin, pose)
        draw_head(img, 3, 3, outfit, hair, skin, blink)
    else:
        draw_body(img, 0, 9, outfit, skin, pose)
        draw_head(img, 3, 1 + b, outfit, hair, skin, blink)
    img = auto_shade(img, 0.18, 0.3)
    return outline_alpha(img)


def portrait(outfit, hair, skin):
    """20x20 bust: 3/4 head + shoulders, lit from the top-left"""
    o = OUTFITS[outfit]
    img = new(20, 20)
    hc, hd = HAIRS[hair]
    sk = c(skin)
    skd = blend(sk, c("ol0"), 0.32)
    # shoulders / collar
    rect(img, 2, 15, 16, 5, c(o[0]))
    rect(img, 12, 15, 6, 5, c(o[1]))
    hline(img, 2, 15, 16, blend(c(o[0]), c("gray6"), 0.2))
    if outfit == "medic":
        rect(img, 5, 16, 3, 1, c("red3"))
        rect(img, 6, 15, 1, 3, c("red3"))
    if outfit == "scav":
        line(img, 3, 15, 10, 19, c("wood1"))
    rect(img, 8, 13, 4, 3, skd)
    # head 11x12
    rect(img, 5, 2, 10, 12, sk)
    rect(img, 4, 3, 12, 10, sk)
    vline(img, 4, 5, 6, skd)
    vline(img, 5, 6, 6, skd)
    hline(img, 7, 13, 7, skd)
    rect(img, 15, 7, 2, 2, sk)          # nose
    px(img, 16, 9, skd)
    hat = o[5]
    if hat in ("none", "goggles", "nurse", "mohawk", "cap", "rag"):
        rect(img, 4, 1, 10, 3, c(hc))
        rect(img, 4, 4, 4, 5, c(hc))
        hline(img, 5, 1, 6, blend(c(hc), c("gray6"), 0.25))
        px(img, 4, 8, c(hd))
    if hat == "helmet":
        rect(img, 3, 0, 14, 5, c(o[1]))
        hline(img, 4, 0, 11, c(o[0]))
        hline(img, 3, 5, 14, c("gray1"))
    elif hat == "rag":
        rect(img, 3, 0, 13, 4, c("cream2"))
        rect(img, 2, 4, 2, 4, c("cream1"))
    elif hat == "cap":
        rect(img, 4, 0, 11, 3, c("red2"))
        hline(img, 13, 3, 5, c("red1"))
    elif hat == "goggles":
        hline(img, 4, 5, 12, c("gray1"))
        rect(img, 11, 4, 4, 3, c("teal3"))
        px(img, 12, 4, c("gray6"))
    elif hat == "nurse":
        rect(img, 6, 0, 7, 2, c("cream3"))
        px(img, 9, 0, c("red3"))
    elif hat == "mohawk":
        for k in range(5):
            vline(img, 5 + k * 2, 0, 3, c("red3"))
    # face
    if hat != "goggles":
        hline(img, 10, 5, 4, c(hd))
        rect(img, 12, 6, 2, 2, c("ol0"))
        px(img, 12, 6, c("gray6"))
    hline(img, 12, 11, 3, skd)
    for (x, y) in ((8, 9), (14, 4)):
        px(img, x, y, blend(sk, c("wood0"), 0.4))
    img = auto_shade(img, 0.2, 0.25)
    return outline_alpha(img)


def gen_dwellers():
    variants = []
    for oi, outfit in enumerate(OUTFITS):
        for hi_, hair in enumerate(HAIRS):
            name = f"dw_{outfit}_{hair}"
            skin = SKINS[(oi * 3 + hi_) % len(SKINS)]
            sheet = new(FW * len(FRAMES), FH)
            for i, (anim, idx, pose, bob) in enumerate(FRAMES):
                fr = dweller_frame(outfit, hair, pose, bob, skin, blink=(anim == "idle" and idx == 1 and (oi + hi_) % 2 == 0))
                sheet.paste(fr, (i * FW, 0), fr)
            add(name, sheet)
            add("pt_" + name, portrait(outfit, hair, skin))
            variants.append(name)
    return variants


# ================================================================== PETS (walk0, walk1, sit, sleep)
def _pet_dog(f):
    i = new(16, 11)
    body_y = 4 if f != 3 else 6
    if f == 3:   # curled up asleep
        ellipse(i, 3, 5, 11, 6, c("wood3"))
        ellipse(i, 2, 5, 5, 5, c("wood3"))
        px(i, 3, 7, OL)
        line(i, 12, 9, 14, 8, c("wood2"))
        return outline_alpha(auto_shade(i, 0.15, 0.3))
    rect(i, 4, body_y, 9, 4, c("wood3"))
    ellipse(i, 10, body_y - 3, 6, 6, c("wood3"))       # head (faces right)
    px(i, 11, body_y - 4, c("wood1"))
    px(i, 14, body_y - 4, c("wood1"))
    px(i, 13, body_y - 1, OL)
    px(i, 15, body_y, OL)
    px(i, 14, body_y + 1, c("red3"))
    line(i, 4, body_y, 1, body_y - 3 + (f % 2), c("wood2"))
    if f == 2:
        rect(i, 4, body_y + 3, 3, 3, c("wood2"))
        rect(i, 10, body_y + 4, 2, 3, c("wood2"))
    else:
        for k, x in enumerate((5, 7, 10, 12)):
            vline(i, x + ((f + k) % 2), body_y + 4, 3, c("wood2"))
    return outline_alpha(auto_shade(i, 0.15, 0.3))


def _pet_cat(f):
    i = new(14, 11)
    if f == 3:
        ellipse(i, 2, 5, 10, 6, c("orange2"))
        ellipse(i, 8, 4, 5, 5, c("orange2"))
        line(i, 2, 9, 6, 10, c("orange1"))
        return outline_alpha(auto_shade(i, 0.15, 0.3))
    y = 5 if f != 2 else 6
    rect(i, 3, y, 7, 3, c("orange2"))
    for x in (4, 7):
        px(i, x, y + 1, c("orange1"))
    ellipse(i, 8, y - 4, 5, 5, c("orange2"))
    px(i, 8, y - 5, c("orange2"))
    px(i, 12, y - 5, c("orange2"))
    px(i, 11, y - 2, c("toxic3"))
    line(i, 3, y, 1, y - 4 + (f % 2), c("orange2"))
    if f == 2:
        rect(i, 3, y + 2, 3, 2, c("orange1"))
    else:
        for k, x in enumerate((4, 6, 8, 9)):
            vline(i, x, y + 3, 2 + ((f + k) % 2), c("orange1"))
    return outline_alpha(auto_shade(i, 0.15, 0.3))


def _pet_hen(f):
    i = new(11, 11)
    y = 3 if f != 3 else 4
    ellipse(i, 1, y + 1, 8, 6, c("cream3"))
    ellipse(i, 6, y - 2, 4, 4, c("cream3"))
    ellipse(i, 3, y - 3, 4, 4, c("cream3"))          # second head
    px(i, 5, y - 4, c("red3"))
    px(i, 8, y - 3, c("red3"))
    px(i, 9, y - 1, c("yellow2"))
    px(i, 6, y - 2, c("yellow2"))
    px(i, 8, y - 1, OL)
    px(i, 4, y - 2, OL)
    if f == 3:
        rect(i, 2, y + 6, 6, 1, c("cream2"))
    else:
        for k, x in enumerate((3, 6)):
            vline(i, x + ((f + k) % 2 if f < 2 else 0), y + 7, 2, c("yellow1"))
    return outline_alpha(auto_shade(i, 0.15, 0.3))


def gen_pets():
    for name, fn in (("dog", _pet_dog), ("cat", _pet_cat), ("hen", _pet_hen)):
        for f in range(4):
            add(f"pet_{name}_{f}", fn(f))


# ================================================================== ENEMIES (face LEFT, towards the truck)
def _fin(img):
    return outline_alpha(auto_shade(img, 0.2, 0.35))


def en_rat(f):
    i = new(16, 10)
    ellipse(i, 3, 2, 12, 7, c("gray3"))
    ellipse(i, 0, 2, 7, 6, c("gray3"))
    px(i, 2, 4, OL)
    px(i, 0, 5, c("pink2"))
    ellipse(i, 4, 0, 4, 4, c("pink2"))
    line(i, 14, 6, 15, 3 + f, c("pink2"))
    for x in (5, 11):
        vline(i, x + (f if x == 5 else -f), 8, 2, c("gray2"))
    return _fin(i)


def en_drone(f):
    i = new(16, 11)
    hline(i, 0, 1, 6, c("gray4") if f else c("gray3"))
    hline(i, 10, 1, 6, c("gray3") if f else c("gray4"))
    vline(i, 3, 1, 3, c("gray2"))
    vline(i, 12, 1, 3, c("gray2"))
    ellipse(i, 2, 3, 12, 7, c("yellow2"))
    rect(i, 2, 6, 12, 2, c("yellow1"))
    ellipse(i, 4, 4, 4, 4, c("gray6"))
    px(i, 5, 5, c("red2"))
    vline(i, 8, 10, 1, c("red2"))
    return _fin(i)


def en_scorpion(f):
    i = new(18, 12)
    ellipse(i, 4, 5, 12, 6, c("orange2"))
    for k in range(3):
        line(i, 6 + k * 3, 10, 5 + k * 3 - f, 11, c("orange1"))
    pts = [(14, 6), (17, 3), (16, 0), (12, 0)]
    for a, b in zip(pts, pts[1:]):
        line(i, a[0], a[1], b[0], b[1], c("orange2"), 2)
    rect(i, 10, 0, 3, 2, c("red2"))
    ellipse(i, 0, 3 - f, 5, 4, c("orange3"))
    ellipse(i, 0, 7 + f, 5, 4, c("orange3"))
    px(i, 6, 6, OL)
    return _fin(i)


def en_vulture(f):
    i = new(18, 12)
    if f:
        poly(i, [(4, 5), (9, 0), (14, 5)], c("purple1"))
    else:
        poly(i, [(4, 5), (9, 10), (14, 5)], c("purple1"))
    ellipse(i, 5, 3, 9, 6, c("purple2"))
    ellipse(i, 1, 2, 5, 5, c("pink2"))
    rect(i, 0, 4, 2, 2, c("yellow2"))
    px(i, 3, 3, OL)
    return _fin(i)


def en_wolf(f):
    i = new(20, 13)
    ellipse(i, 4, 3, 14, 7, c("gray3"))
    ellipse(i, 0, 1, 8, 7, c("gray3"))
    poly(i, [(2, 2), (3, -1), (5, 2)], c("gray3"))
    poly(i, [(5, 2), (6, -1), (8, 2)], c("gray2"))
    rect(i, 0, 5, 3, 2, c("gray4"))
    px(i, 3, 3, c("red2"))
    px(i, 0, 5, OL)
    poly(i, [(17, 4), (20, 1 + f), (19, 6)], c("gray3"))
    for k, x in enumerate((5, 8, 13, 16)):
        vline(i, x + (f if k % 2 else -f), 9, 3, c("gray2"))
    return _fin(i)


def en_bug(f):
    i = new(16, 9)
    ellipse(i, 3, 1, 12, 7, c("purple2"))
    ellipse(i, 0, 2, 5, 5, c("purple1"))
    px(i, 1, 3, c("toxic3"))
    hline(i, 6, 3, 6, c("purple3"))
    for k in range(3):
        line(i, 5 + k * 3, 7, 4 + k * 3 + (f if k % 2 else -f), 8, OL)
    return _fin(i)


def en_crawler(f):
    i = new(16, 14)
    ellipse(i, 2, 4, 12, 10, c("green2"))
    ellipse(i, 4, 0, 8, 7, c("green3"))
    px(i, 5, 3, c("red2"))
    px(i, 8, 3, c("red2"))
    for k in range(4):
        vline(i, 3 + k * 3, 1 + (k + f) % 2, 3, c("green4"))
    rect(i, 0, 7, 3, 2, c("green2"))
    return _fin(i)


def en_yeti(f):
    i = new(16, 20)
    ellipse(i, 2, 4, 12, 13, c("snow3"))
    ellipse(i, 3, 0, 10, 8, c("snow3"))
    ellipse(i, 4, 2, 6, 5, c("snow1"))
    px(i, 5, 4, OL)
    px(i, 8, 4, OL)
    hline(i, 5, 6, 3, c("red1"))
    rect(i, 0, 8 + f, 3, 6, c("snow2"))
    rect(i, 13, 8 - f, 3, 6, c("snow2"))
    rect(i, 4 - f, 16, 3, 4, c("snow1"))
    rect(i, 9 + f, 16, 3, 4, c("snow1"))
    return _fin(i)


def en_toad(f):
    i = new(16, 11)
    ellipse(i, 2, 2, 13, 9, c("toxic1"))
    ellipse(i, 1, 0, 5, 5, c("toxic2"))
    ellipse(i, 7, 0, 5, 5, c("toxic2"))
    px(i, 2, 1, OL)
    px(i, 8, 1, OL)
    hline(i, 2, 6, 6, c("red2"))
    for (x, y) in ((10, 4), (12, 7), (8, 8)):
        px(i, x, y, c("toxic3"))
    rect(i, 3 - f, 9, 3, 2, c("toxic1"))
    rect(i, 10 + f, 9, 3, 2, c("toxic1"))
    return _fin(i)


def en_mosquito(f):
    i = new(16, 12)
    if f:
        ellipse(i, 5, 0, 8, 4, c("sky3"))
    else:
        ellipse(i, 5, 8, 8, 4, c("sky3"))
    ellipse(i, 4, 4, 10, 5, c("gray2"))
    ellipse(i, 1, 3, 5, 5, c("gray2"))
    px(i, 2, 4, c("red3"))
    hline(i, 0, 6, 2, c("gray4"))
    return _fin(i)


def en_bogwalker(f):
    i = new(14, 20)
    ellipse(i, 2, 0, 10, 9, c("green1"))
    px(i, 4, 4, c("toxic3"))
    px(i, 8, 4, c("toxic3"))
    rect(i, 3, 8, 8, 7, c("green1"))
    rect(i, 0, 9 + f, 3, 5, c("green1"))
    rect(i, 11, 9 - f, 3, 5, c("green1"))
    rect(i, 4 - f, 15, 3, 5, c("green0"))
    rect(i, 8 + f, 15, 3, 5, c("green0"))
    for k in range(3):
        px(i, 4 + k * 3, 12 + k % 2, c("toxic2"))
    return _fin(i)


def en_sentry(f):
    i = new(18, 16)
    rect(i, 4, 1, 10, 8, c("gray4"))
    rect(i, 4, 6, 10, 3, c("gray3"))
    rect(i, 6, 3, 4, 2, c("pink2"))
    rect(i, 0, 4, 5, 2, c("gray2"))
    for k, x in enumerate((5, 12)):
        line(i, x, 9, x - 2 + (f if k else -f), 15, c("gray2"))
    vline(i, 9, 0, 2, c("red2"))
    return _fin(i)


def en_ape(f):
    i = new(18, 18)
    ellipse(i, 3, 5, 13, 11, c("purple1"))
    ellipse(i, 4, 0, 9, 8, c("purple1"))
    ellipse(i, 5, 2, 6, 5, c("skin1"))
    px(i, 6, 3, OL)
    px(i, 9, 3, OL)
    rect(i, 0, 8 + f, 4, 7, c("purple1"))
    rect(i, 14, 8 - f, 4, 7, c("purple1"))
    rect(i, 5 - f, 15, 3, 3, c("purple0"))
    rect(i, 11 + f, 15, 3, 3, c("purple0"))
    return _fin(i)


ENEMIES = {"rat": en_rat, "drone": en_drone, "scorpion": en_scorpion, "vulture": en_vulture, "wolf": en_wolf,
           "bug": en_bug, "crawler": en_crawler, "yeti": en_yeti, "toad": en_toad, "mosquito": en_mosquito,
           "bogwalker": en_bogwalker, "sentry": en_sentry, "ape": en_ape}


def gen_enemies():
    for name, fn in ENEMIES.items():
        add(f"en_{name}_0", fn(0))
        add(f"en_{name}_1", fn(1))


# ================================================================== BOSSES (native size)
def _legs(img, xs, y, h, col, step):
    for i, x in enumerate(xs):
        dx = step if i % 2 == 0 else -step
        rect(img, x + dx, y, 5, h, col)
        rect(img, x + dx - 1, y + h - 2, 7, 2, OL)


def boss_golem(f):
    img = new(40, 44)
    s = f
    _legs(img, [10, 24], 32, 11, c("gray3"), s)
    ellipse(img, 4, 8, 32, 28, c("orange1"))
    rect(img, 9, 12, 8, 7, c("gray4"))
    rect(img, 22, 18, 9, 8, c("blue3"))
    rect(img, 12, 24, 7, 7, c("yellow2"))
    ellipse(img, 26, 2 - s, 12, 12, c("gray1"))
    ellipse(img, 29, 5 - s, 6, 6, c("yellow2"))
    ellipse(img, 13, 0 + s, 14, 12, c("gray4"))
    rect(img, 16, 4 + s, 3, 3, OL)
    rect(img, 22, 4 + s, 3, 3, OL)
    px(img, 17, 4 + s, c("red3"))
    px(img, 23, 4 + s, c("red3"))
    ellipse(img, 0, 14 + s, 8, 16, c("orange1"))
    ellipse(img, 0, 27 + s, 9, 8, c("gray3"))
    ellipse(img, 32, 14 - s, 8, 14, c("orange1"))
    for (x, y) in ((8, 20), (30, 12), (20, 30)):
        px(img, x, y, c("wood0"))
    return outline_alpha(auto_shade(img, 0.2, 0.35))


def boss_scorpion(f):
    img = new(48, 28)
    s = f
    for i, x in enumerate(range(10, 38, 5)):
        dx = s if i % 2 else -s
        line(img, x, 18, x - 3 + dx, 26, c("red1"), 2)
    ellipse(img, 8, 9, 32, 13, c("red2"))
    for x in range(14, 38, 6):
        vline(img, x, 11, 9, c("red1"))
    pts = [(38, 14), (44, 8), (44, 2), (38, 0), (30, 2 + s)]
    for a, b in zip(pts, pts[1:]):
        line(img, a[0], a[1], b[0], b[1], c("red2"), 3)
    poly(img, [(30, 0 + s), (25, 3 + s), (31, 6 + s)], c("yellow2"))
    ellipse(img, 0, 7 - s, 10, 7, c("red3"))
    ellipse(img, 0, 15 + s, 10, 7, c("red3"))
    rect(img, 12, 12, 3, 3, OL)
    px(img, 12, 12, c("gray6"))
    poly(img, [(18, 9), (20, 4), (22, 8), (24, 3), (26, 8), (28, 4), (30, 9)], c("yellow2"))
    return outline_alpha(auto_shade(img, 0.2, 0.35))


def boss_wolf(f):
    img = new(40, 26)
    s = f
    ellipse(img, 8, 6, 28, 14, c("gray3"))
    ellipse(img, 1, 2 - s, 13, 12, c("gray3"))
    poly(img, [(3, 4 - s), (5, -1), (8, 4 - s)], c("gray2"))
    poly(img, [(8, 4 - s), (10, -1), (13, 4 - s)], c("gray2"))
    rect(img, 0, 8 - s, 4, 3, c("gray5"))
    px(img, 5, 6 - s, c("red3"))
    px(img, 6, 6 - s, c("red3"))
    for i, x in enumerate((10, 15, 26, 31)):
        dx = s if i % 2 else -s
        rect(img, x + dx, 18, 4, 7, c("gray2"))
    poly(img, [(34, 9), (40, 4 + s), (38, 12)], c("gray3"))
    for k in range(4):
        px(img, 15 + k * 5, 9 + (k % 2), c("toxic3"))
    return outline_alpha(auto_shade(img, 0.2, 0.35))


def boss_bogqueen(f):
    img = new(36, 44)
    s = f
    for i, x in enumerate((8, 14, 20, 26)):
        dx = s if i % 2 else -s
        line(img, x, 32, x - 2 + dx, 43, c("green0"), 2)
    ellipse(img, 4, 14, 28, 22, c("toxic1"))
    ellipse(img, 9, 19, 16, 11, c("toxic2"))
    ellipse(img, 8, 2 + s, 18, 15, c("green1"))
    for ex in (12, 19):
        rect(img, ex, 7 + s, 3, 3, c("toxic3"))
        px(img, ex, 7 + s, c("gray6"))
    hline(img, 13, 13 + s, 8, OL)
    for k in range(5):
        vline(img, 9 + k * 4, 0, 4 + (k % 2) * 2, c("green3"))
        px(img, 9 + k * 4, 0, c("pink2"))
    rect(img, 0, 20 - s, 6, 3, c("green1"))
    return outline_alpha(auto_shade(img, 0.2, 0.35))


def boss_titan(f):
    img = new(40, 48)
    s = f
    _legs(img, [11, 24], 34, 13, c("snow1"), s)
    ellipse(img, 4, 8, 32, 28, c("snow2"))
    for (x, y) in ((8, 9), (30, 10), (18, 5)):
        poly(img, [(x, y), (x + 2, y - 6), (x + 4, y)], c("sky3"))
    ellipse(img, 12, 0 + s, 16, 13, c("snow3"))
    rect(img, 15, 5 + s, 3, 3, c("blue3"))
    rect(img, 22, 5 + s, 3, 3, c("blue3"))
    ellipse(img, 0, 12 + s, 9, 20, c("snow2"))
    ellipse(img, 31, 12 - s, 9, 18, c("snow2"))
    ellipse(img, 14, 17, 12, 12, c("sky2"))
    ellipse(img, 17, 20, 6, 6, c("gray6"))
    return outline_alpha(auto_shade(img, 0.2, 0.35))


def boss_overseer(f):
    img = new(44, 48)
    s = f
    for i, x in enumerate((10, 26)):
        dx = s if i else -s
        line(img, x + 4, 30, x + dx, 40, c("gray3"), 3)
        line(img, x + dx, 40, x + 4 + dx, 47, c("gray3"), 3)
        rect(img, x - 2 + dx, 45, 10, 3, c("gray2"))
    ellipse(img, 4, 4, 36, 28, c("gray4"))
    rect(img, 8, 15, 28, 3, c("yellow2"))
    for x in range(8, 36, 4):
        px(img, x, 16, OL)
    ellipse(img, 15, 5, 14, 13, c("night1"))
    ellipse(img, 17, 7, 10, 9, None, c("yellow2"))
    ellipse(img, 20, 9, 4, 4, c("pink2"))
    rect(img, 0, 18 + s, 8, 6, c("gray2"))
    for k in range(3):
        hline(img, 0, 19 + s + k * 2, 3, OL)
    rect(img, 38, 6, 4, 10, c("gray3"))
    vline(img, 40, 0, 6, c("gray5"))
    px(img, 40, 0, c("red3"))
    rect(img, 12, 23, 20, 5, c("gray2"))
    for x in range(14, 30, 4):
        rect(img, x, 24, 2, 3, c("teal2"))
    return outline_alpha(auto_shade(img, 0.2, 0.35))


BOSSES = {"golem": boss_golem, "scorpion": boss_scorpion, "wolf": boss_wolf,
          "bogqueen": boss_bogqueen, "titan": boss_titan, "overseer": boss_overseer}


def gen_bosses():
    for k, fn in BOSSES.items():
        for f in (0, 1):
            add(f"boss_{k}_{f}", fn(f))


# kept for event art
WOLF_FN = en_wolf
