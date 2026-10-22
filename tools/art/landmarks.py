"""Expedition landmarks (lm_*): grim ruined buildings parked beside the road while a team scavenges.
Every sprite is 100 wide, bottom row = road contact, and its door is centred at x=DOOR_X (walkers enter there)."""
import math, random
from .common import *
from .truck import weather

LW = 100
DOOR_X = 30
rl = random.Random(555)


def bldg(img, x, y, w, h, ramp, i=2):
    rect(img, x, y, w, h, OL)
    rect(img, x + 1, y + 1, w - 2, h - 2, c(f"{ramp}{i}"))
    vline(img, x + 1, y + 1, h - 2, c(f"{ramp}{min(i + 1, len(RAMPS[ramp]) - 1)}"))
    vline(img, x + w - 2, y + 1, h - 2, c(f"{ramp}{max(i - 1, 0)}"))


def roof_edge(img, x, y, w, ramp="gray", i=3):
    rect(img, x - 2, y, w + 4, 4, OL)
    rect(img, x - 1, y + 1, w + 2, 2, c(f"{ramp}{i}"))
    hline(img, x - 1, y + 1, w + 2, c(f"{ramp}{min(i + 1, len(RAMPS[ramp]) - 1)}"))


def windows(img, x, y, cols, rows, dx=12, dy=12, w=8, h=8, lit=0.25, broken=0.25):
    for r in range(rows):
        for k in range(cols):
            wx, wy = x + k * dx, y + r * dy
            rect(img, wx, wy, w, h, OL)
            roll = rl.random()
            if roll < broken:
                rect(img, wx + 1, wy + 1, w - 2, h - 2, c("night1"))
                line(img, wx + 1, wy + 1, wx + w - 3, wy + h // 2, c("sky2"))
            elif roll < broken + lit:
                rect(img, wx + 1, wy + 1, w - 2, h - 2, c("yellow3"))
            else:
                rect(img, wx + 1, wy + 1, w - 2, h - 2, c("sky2"))
                px(img, wx + 1, wy + 1, c("gray6"))
            hline(img, wx, wy + h, w, c("gray5"))


def door(img, bottom, w=12, h=16, col="wood"):
    x = DOOR_X - w // 2
    y = bottom - h
    rect(img, x, y, w, h, OL)
    rect(img, x + 1, y + 1, w - 2, h - 1, c("night1"))
    rect(img, x + 1, y + 1, (w - 2) // 2, h - 1, c(col + "1"))   # one wing hanging open
    px(img, x + (w - 2) // 2 - 1, y + h // 2, c("yellow2"))
    rect(img, x - 2, bottom - 1, w + 4, 1, OL)


def sign(img, x, y, w, h, bg, txt_col, glyphs=4):
    rect(img, x, y, w, h, OL)
    rect(img, x + 1, y + 1, w - 2, h - 2, c(bg))
    for k in range(glyphs):
        gx = x + 3 + k * ((w - 6) // glyphs)
        rect(img, gx, y + 2, max(2, (w - 6) // glyphs - 2), h - 4, c(txt_col))


def vines(img, x, y, n, length=14):
    for k in range(n):
        xx = x + k * 3
        ln = rl.randint(length // 2, length)
        for j in range(ln):
            px(img, xx + (j // 4) % 2, y + j, c("green2" if j % 3 else "green3"))


def rubble(img, bottom, x0=0, x1=LW):
    for _ in range(9):
        x = rl.randint(x0, x1 - 8)
        w = rl.randint(4, 9)
        h = rl.randint(2, 4)
        ellipse(img, x, bottom - h, w, h + 1, OL)
        ellipse(img, x + 1, bottom - h + 1, w - 2, h - 1, c(rl.choice(["gray4", "gray3", "sand2"])))


def crack(img, x, y, n):
    for k in range(n):
        px(img, x + (k % 3) - 1, y + k, OL)


def _fin(img):
    return img


# ------------------------------------------------------------------ sites
def lm_hospital():
    img = new(LW, 110)
    B = 109
    bldg(img, 8, 30, 84, B - 30, "cream", 2)
    roof_edge(img, 8, 28, 84, "gray", 4)
    windows(img, 16, 40, 6, 3, 12, 14)
    rect(img, 46, 8, 22, 22, OL)
    rect(img, 47, 9, 20, 20, c("gray6"))
    rect(img, 54, 11, 6, 16, c("red2"))
    rect(img, 49, 16, 16, 6, c("red2"))
    vline(img, 57, 30, 0, OL)
    sign(img, 52, B - 26, 36, 8, "sky2", "blue2", 5)
    door(img, B, 14, 18)
    rect(img, 18, B - 22, 24, 3, c("red2"))
    crack(img, 70, 40, 12)
    crack(img, 20, 70, 9)
    vines(img, 84, 32, 3, 30)
    rubble(img, B + 1, 60, 100)
    return img


def lm_depot():
    img = new(LW, 90)
    B = 89
    # quonset hangar
    ellipse(img, 4, 24, 92, 120, OL)
    ellipse(img, 5, 25, 90, 118, c("green2"))
    for x in range(10, 92, 8):
        for y in range(26, B):
            if get(img, x, y)[:3] == c("green2")[:3]:
                px(img, x, y, c("green1"))
    rect(img, 0, B + 1, LW, 40, CLEAR)
    ellipse(img, 20, 30, 20, 8, c("green3"))
    # big door + small door
    rect(img, 46, 52, 40, B - 52, OL)
    rect(img, 47, 53, 38, B - 53, c("gray3"))
    for y in range(55, B, 4):
        hline(img, 47, y, 38, c("gray2"))
    door(img, B, 12, 16, "gray")
    # star + crates + sandbags
    poly(img, [(66, 34), (68, 40), (74, 40), (69, 44), (71, 50), (66, 46), (61, 50), (63, 44), (58, 40), (64, 40)], c("yellow2"), OL)
    for (x, y) in ((4, B - 10), (14, B - 10), (8, B - 18)):
        rect(img, x, y, 10, 10, OL)
        rect(img, x + 1, y + 1, 8, 8, c("wood2"))
        line(img, x + 1, y + 1, x + 8, y + 8, c("wood1"))
    for (sx, sy) in ((86, B - 6), (92, B - 6), (89, B - 11)):
        ellipse(img, sx, sy, 8, 6, OL)
        ellipse(img, sx + 1, sy + 1, 6, 4, c("sand2"))
    return img


def lm_gas():
    img = new(LW, 90)
    B = 89
    # canopy on posts
    rect(img, 4, 18, 92, 10, OL)
    rect(img, 5, 19, 90, 8, c("red2"))
    hline(img, 5, 19, 90, c("red3"))
    hline(img, 5, 24, 90, c("gray6"))
    for x in (12, 84):
        rect(img, x, 28, 5, B - 28, OL)
        rect(img, x + 1, 28, 3, B - 28, c("gray5"))
    # shop
    bldg(img, 18, 46, 30, B - 46, "sand", 2)
    windows(img, 38, 52, 1, 1, 0, 0, 8, 10, lit=0.0, broken=1.0)
    door(img, B, 10, 16, "red")
    # pumps
    for x in (58, 72):
        rect(img, x, B - 22, 10, 22, OL)
        rect(img, x + 1, B - 21, 8, 21, c("yellow2"))
        rect(img, x + 2, B - 19, 6, 5, c("night1"))
        px(img, x + 3, B - 17, c("orange3"))
        line(img, x + 9, B - 12, x + 12, B - 4, OL)
    # sign pole + sand drifts
    vline(img, 92, 4, 14, OL)
    ellipse(img, 84, 0, 16, 10, OL)
    ellipse(img, 85, 1, 14, 8, c("yellow2"))
    rect(img, 89, 3, 6, 3, c("red2"))
    for x in range(0, LW, 20):
        ellipse(img, x, B - 4, 26, 8, c("sand2"))
    rect(img, 0, B + 1, LW, 4, CLEAR)
    return img


def lm_dish():
    img = new(LW, 120)
    B = 119
    # lattice tower
    for k in range(0, 60, 6):
        y = B - k
        w = 30 - k // 3
        line(img, 50 - w // 2, y, 50 + w // 2, y - 6, c("gray4"))
        line(img, 50 + w // 2, y, 50 - w // 2, y - 6, c("gray4"))
    line(img, 35, B, 44, B - 60, OL, 2)
    line(img, 65, B, 56, B - 60, OL, 2)
    # dish
    ellipse(img, 18, 14, 64, 50, OL)
    ellipse(img, 20, 16, 60, 46, c("gray6"))
    ellipse(img, 26, 22, 48, 34, c("gray5"))
    for a in range(0, 360, 45):
        r = math.radians(a)
        line(img, 50, 39, 50 + 24 * math.cos(r), 39 + 17 * math.sin(r), c("gray4"))
    line(img, 50, 39, 68, 12, OL, 2)
    ellipse(img, 65, 8, 7, 7, c("red2"), OL)
    # control hut
    bldg(img, 6, B - 24, 28, 24, "teal", 2)
    roof_edge(img, 6, B - 26, 28, "gray", 4)
    door(img, B, 10, 15, "gray")
    rect(img, 76, B - 20, 18, 20, OL)
    rect(img, 77, B - 19, 16, 19, c("gray3"))
    for y in range(B - 17, B, 3):
        hline(img, 78, y, 14, c("teal3") if (y // 3) % 2 else c("gray2"))
    return img


def lm_tower():
    img = new(LW, 120)
    B = 119
    # stilts
    for x in (34, 66):
        line(img, x, B, x + (8 if x < 50 else -8), 40, OL, 3)
        line(img, x, B, x + (8 if x < 50 else -8), 40, c("wood1"))
    for y in range(52, B, 16):
        line(img, 38, y, 62, y + 12, c("wood1"))
        line(img, 62, y, 38, y + 12, c("wood1"))
    # cabin
    bldg(img, 32, 18, 36, 24, "wood", 2)
    windows(img, 36, 23, 3, 1, 10, 0, 8, 8, lit=0.4, broken=0.2)
    poly(img, [(28, 18), (50, 4), (72, 18)], c("red2"), OL)
    hline(img, 30, 42, 40, OL)
    # stairs to the door at ground
    for k in range(8):
        rect(img, 18 + k * 2, B - 4 - k * 9, 8, 2, c("wood2"))
    bldg(img, 16, B - 20, 28, 20, "wood", 1)
    door(img, B, 10, 15, "wood")
    # trees
    for (x, h) in ((80, 40), (90, 30), (2, 34)):
        rect(img, x + 4, B - 10, 3, 10, c("wood0"))
        poly(img, [(x, B - 8), (x + 5, B - h), (x + 11, B - 8)], c("green2"), OL)
    vines(img, 64, 20, 2, 20)
    return img


def lm_lab():
    img = new(LW, 100)
    B = 99
    # dome
    ellipse(img, 48, 8, 40, 36, OL)
    ellipse(img, 49, 9, 38, 34, c("teal2"))
    ellipse(img, 54, 13, 12, 10, c("teal3"))
    for x in range(56, 84, 8):
        line(img, x, 10, x - 2, 33, c("teal1"))
    bldg(img, 6, 34, 88, B - 34, "gray", 5)
    roof_edge(img, 6, 32, 88, "purple", 2)
    windows(img, 44, 44, 4, 2, 12, 14, 8, 8, lit=0.3, broken=0.3)
    sign(img, 8, 40, 30, 8, "purple2", "gray6", 4)
    door(img, B, 14, 18, "gray")
    # toxic puddle + hazard
    ellipse(img, 50, B - 3, 30, 5, c("toxic2"))
    poly(img, [(80, 70), (86, 60), (92, 70)], c("yellow2"), OL)
    vines(img, 8, 36, 4, 26)
    return img


def lm_chem():
    img = new(LW, 110)
    B = 109
    # tanks + stack
    for (x, w, h) in ((54, 22, 50), (76, 20, 40)):
        rect(img, x, B - h, w, h, OL)
        rect(img, x + 1, B - h + 1, w - 2, h - 1, c("gray4"))
        vline(img, x + 2, B - h + 1, h - 1, c("gray5"))
        ellipse(img, x, B - h - 4, w, 8, OL)
        ellipse(img, x + 1, B - h - 3, w - 2, 6, c("gray5"))
        rect(img, x + 4, B - h + 12, w - 8, 6, c("toxic2"))
        frame(img, x + 4, B - h + 12, w - 8, 6, OL)
    rect(img, 40, 6, 8, B - 6, OL)
    rect(img, 41, 6, 6, B - 6, c("red2"))
    for y in range(10, B, 12):
        hline(img, 41, y, 6, c("gray6"))
    bldg(img, 6, B - 40, 40, 40, "sand", 1)
    roof_edge(img, 6, B - 42, 40, "gray", 3)
    windows(img, 30, B - 34, 1, 2, 0, 12, 8, 7, lit=0.0, broken=0.6)
    door(img, B, 12, 16, "gray")
    # glowing barrels
    for x in (60, 72):
        rect(img, x, B - 12, 9, 12, OL)
        rect(img, x + 1, B - 11, 7, 11, c("toxic1"))
        hline(img, x + 1, B - 8, 7, OL)
        px(img, x + 4, B - 5, c("toxic3"))
    ellipse(img, 52, B - 3, 40, 5, c("toxic2"))
    return img


def lm_stilt():
    img = new(LW, 100)
    B = 99
    # water line
    rect(img, 0, B - 10, LW, 10, c("teal1"))
    hline(img, 0, B - 10, LW, c("teal3"))
    for x in range(4, LW, 12):
        hline(img, x, B - 6, 5, c("teal2"))
    # stilts + two huts + walkway
    for x in (10, 30, 52, 70, 90):
        rect(img, x, B - 40, 3, 40, OL)
        vline(img, x + 1, B - 40, 40, c("wood1"))
    rect(img, 4, B - 42, 92, 4, OL)
    hline(img, 5, B - 41, 90, c("wood3"))
    bldg(img, 6, B - 72, 34, 30, "wood", 2)
    poly(img, [(2, B - 72), (23, B - 88), (44, B - 72)], c("green2"), OL)
    bldg(img, 54, B - 66, 40, 24, "wood", 3)
    poly(img, [(50, B - 66), (74, B - 82), (98, B - 66)], c("orange2"), OL)
    windows(img, 62, B - 60, 2, 1, 14, 0, 8, 8, lit=0.5, broken=0.0)
    rect(img, 18, B - 64, 10, 12, c("night1"))
    frame(img, 18, B - 64, 10, 12, OL)
    # ramp down to the road + the walkers' door at ground (a shed)
    line(img, 30, B - 40, 44, B, OL, 2)
    bldg(img, 20, B - 22, 20, 22, "wood", 1)
    door(img, B, 10, 14, "wood")
    vines(img, 6, B - 72, 3, 16)
    return img


def lm_polar():
    img = new(LW, 90)
    B = 89
    # modular station on skids
    rect(img, 4, B - 6, 92, 6, OL)
    rect(img, 5, B - 5, 90, 4, c("gray3"))
    bldg(img, 8, B - 40, 50, 34, "red", 2)
    bldg(img, 58, B - 30, 34, 24, "orange", 2)
    for (x, y, w) in ((8, B - 42, 50), (58, B - 32, 34)):
        rect(img, x - 1, y - 2, w + 2, 4, c("snow3"))
        for k in range(0, w, 6):
            ellipse(img, x + k, y - 3, 6, 4, c("snow3"))
    windows(img, 38, B - 34, 1, 1, 0, 0, 12, 8, lit=0.6, broken=0.0)
    windows(img, 64, B - 24, 2, 1, 12, 0, 8, 6, lit=0.5, broken=0.0)
    door(img, B - 6, 12, 18, "gray")
    # mast + dome
    vline(img, 80, 20, B - 50, OL)
    ellipse(img, 72, 10, 16, 14, c("gray6"), OL)
    poly(img, [(80, 20), (90, 24), (80, 28)], c("blue3"), OL)
    for x in range(0, LW, 16):
        ellipse(img, x, B - 3, 22, 6, c("snow3"))
    rect(img, 0, B + 1, LW, 4, CLEAR)
    return img


def lm_mine():
    img = new(LW, 100)
    B = 99
    # rocky hill with tunnel mouth
    poly(img, [(0, B), (10, 40), (34, 20), (60, 30), (84, 14), (100, 36), (100, B)], OL)
    poly(img, [(1, B), (11, 41), (34, 22), (60, 32), (84, 16), (99, 37), (99, B)], c("gray3"))
    for (x, y) in ((40, 40), (70, 30), (20, 60), (80, 60)):
        ellipse(img, x, y, 10, 6, c("gray4"))
    for (x, y, w) in ((30, 20, 10), (78, 14, 12)):
        ellipse(img, x, y, w, 6, c("snow3"))
    # timber frame
    rect(img, 16, B - 34, 30, 34, OL)
    rect(img, 18, B - 32, 26, 32, c("night1"))
    rect(img, 14, B - 36, 34, 5, c("wood2"))
    frame(img, 14, B - 36, 34, 5, OL)
    for x in (16, 42):
        rect(img, x, B - 32, 4, 32, c("wood1"))
        frame(img, x, B - 32, 4, 32, OL)
    # tracks + cart
    hline(img, 20, B - 1, 80, OL)
    rect(img, 56, B - 12, 18, 9, OL)
    rect(img, 57, B - 11, 16, 6, c("orange1"))
    for (x, y) in ((58, B - 13), (63, B - 14), (68, B - 13)):
        ellipse(img, x, y, 5, 4, c("blue3"))
    for x in (58, 68):
        ellipse(img, x, B - 4, 4, 4, OL)
    px(img, DOOR_X, B - 20, c("yellow3"))
    return img


def lm_mall():
    img = new(LW, 100)
    B = 99
    bldg(img, 2, 26, 96, B - 26, "pink", 2)
    roof_edge(img, 2, 24, 96, "gray", 4)
    sign(img, 22, 12, 56, 12, "yellow2", "red2", 4)
    vline(img, 30, 24, 0, OL)
    windows(img, 8, 32, 7, 1, 13, 0, 10, 10, lit=0.2, broken=0.4)
    # glass entrance
    rect(img, 18, B - 30, 70, 30, OL)
    for k in range(5):
        rect(img, 19 + k * 14, B - 29, 13, 29, c("sky2") if k else c("night1"))
        line(img, 21 + k * 14, B - 26, 28 + k * 14, B - 18, c("gray6"))
    door(img, B, 14, 20, "gray")
    # trolley + vines
    rect(img, 80, B - 10, 12, 6, OL)
    rect(img, 81, B - 9, 10, 4, c("gray5"))
    for x in (82, 90):
        px(img, x, B - 2, OL)
    vines(img, 60, 28, 6, 30)
    return img


def lm_spire():
    img = new(LW, 140)
    B = 139
    # HELIOS megatower (the final site)
    poly(img, [(30, B), (40, 20), (60, 20), (70, B)], OL)
    poly(img, [(31, B), (41, 21), (59, 21), (69, B)], c("blue2"))
    for y in range(26, B, 8):
        w = 18 + (y - 20) // 6
        hline(img, 50 - w // 2, y, w, c("sky2"))
        for x in range(50 - w // 2 + 2, 50 + w // 2 - 2, 6):
            px(img, x, y + 3, c("yellow3") if rl.random() < 0.3 else c("night2"))
    vline(img, 50, 0, 20, OL)
    ellipse(img, 44, 4, 12, 12, c("yellow2"), OL)
    ellipse(img, 47, 7, 6, 6, c("gray6"))
    # podium + door
    bldg(img, 4, B - 26, 92, 26, "gray", 4)
    roof_edge(img, 4, B - 28, 92, "blue", 3)
    sign(img, 52, B - 22, 36, 8, "night1", "yellow2", 6)
    door(img, B, 14, 18, "gray")
    crack(img, 44, 60, 14)
    vines(img, 32, 40, 3, 40)
    return img


LANDMARKS = {"lm_hospital": lm_hospital, "lm_depot": lm_depot, "lm_gas": lm_gas, "lm_dish": lm_dish,
             "lm_tower": lm_tower, "lm_lab": lm_lab, "lm_chem": lm_chem, "lm_stilt": lm_stilt,
             "lm_polar": lm_polar, "lm_mine": lm_mine, "lm_mall": lm_mall, "lm_spire": lm_spire}


def gen_landmarks():
    for k, fn in LANDMARKS.items():
        img = weather(fn(), len(k) * 7)
        add(k, img)
