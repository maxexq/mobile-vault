"""Event illustrations 160x80 (shown at 2x in the event popup) — bright Kairosoft-like vignettes."""
import math, os, random
from .common import *
from . import chars

EW, EH = 160, 80
re_ = random.Random(2024)

DAY = ("sky1", "sky2", "sky3")
DUSK = ("purple2", "pink2", "dusk3")
NIGHT = ("night1", "night2", "purple1")


def scene(sky, ground, horizon=56, skyline=None, sun=None, clouds=2):
    img = new(EW, EH)
    stops = [(0.0, c(sky[0])), (0.6, c(sky[1])), (1.0, c(sky[2]))]
    gradient_v(img, 0, 0, EW, horizon, stops)
    if sun:
        ellipse(img, sun[0] - 11, sun[1] - 11, 22, 22, c(sun[2])[:3] + (110,))
        ellipse(img, sun[0] - 8, sun[1] - 8, 16, 16, c(sun[2]))
        ellipse(img, sun[0] - 5, sun[1] - 6, 5, 4, c("gray6"))
    for k in range(clouds):
        cx = re_.randint(10, EW - 30)
        cy = re_.randint(6, max(8, horizon - 30))
        for j in range(3):
            ellipse(img, cx + j * 7, cy - (j % 2) * 3, 12, 9, c("gray6"))
        hline(img, cx + 2, cy + 8, 22, c("sky3"))
    if skyline:
        rng = random.Random(len(skyline))
        x = 0
        while x < EW:
            w = rng.randint(8, 18)
            h = rng.randint(8, 26)
            rect(img, x, horizon - h, w, h, c(skyline))
            vline(img, x, horizon - h, h, blend(c(skyline), c("gray6"), 0.25))
            for wy in range(horizon - h + 3, horizon - 2, 5):
                for wx in range(x + 2, x + w - 2, 4):
                    px(img, wx, wy, blend(c(skyline), c("night1"), 0.4))
            x += w + rng.randint(1, 6)
    rect(img, 0, horizon, EW, EH - horizon, c(ground))
    hline(img, 0, horizon, EW, OL)
    hline(img, 0, horizon + 1, EW, blend(c(ground), c("gray6"), 0.3))
    for _ in range(60):
        px(img, re_.randint(0, EW - 1), re_.randint(horizon + 3, EH - 1), blend(c(ground), OL, 0.15))
    return img


def dweller(outfit, hair, pose="stand", flipx=False):
    f = chars.dweller_frame(outfit, hair, pose, 0)
    return flip(f) if flipx else f


def mini_truck(img, x, y):
    """~32x30 tiny truck"""
    rect(img, x + 7, y, 25, 24, OL)
    rect(img, x + 8, y + 1, 23, 22, c("orange2"))
    for r in range(3):
        for k in range(2):
            rect(img, x + 9 + k * 11, y + 2 + r * 7, 10, 6, OL)
            rect(img, x + 10 + k * 11, y + 3 + r * 7, 8, 4, c("yellow3") if (r + k) % 2 else c("sky2"))
    rect(img, x, y + 12, 9, 13, OL)
    rect(img, x + 1, y + 13, 7, 11, c("red2"))
    rect(img, x + 1, y + 14, 4, 4, c("sky2"))
    rect(img, x, y + 24, 33, 3, OL)
    for wx in (x + 5, x + 20, x + 27):
        ellipse(img, wx - 4, y + 23, 8, 8, OL)
        px(img, wx, y + 27, c("yellow2"))
    for k in range(4):
        px(img, x + 12 + k * 4, y - 1 - (k % 2), c("green3"))


def save_ev(img, name):
    save(img, os.path.join(OUT_EV, name + ".png"))


def crate(img, x, y, w, h, col="wood"):
    rect(img, x, y, w, h, OL)
    rect(img, x + 1, y + 1, w - 2, h - 2, c(col + "2"))
    hline(img, x + 1, y + 1, w - 2, c(col + "3"))
    line(img, x + 1, y + 1, x + w - 2, y + h - 2, c(col + "1"))


def gen_events():
    wolf = flip(chars.en_wolf(0))
    # wolves
    img = scene(DUSK, "wood1", skyline="purple1", sun=(120, 36, "dusk3"))
    mini_truck(img, 16, 30)
    for (x, y) in ((70, 52), (96, 58), (124, 50)):
        paste(img, wolf, x, y)
    save_ev(img, "wolves")
    # raiders
    img = scene(DUSK, "sand1", skyline="purple1")
    for x in range(50, 130, 14):
        crate(img, x, 60, 12, 8)
    for x in (66, 96, 120):
        paste(img, dweller("raider", "black", "work1", flipx=True), x, 42)
    rect(img, 110, 54, 8, 4, c("yellow2"))
    for k in range(10):
        ellipse(img, 112 + (k % 3), 50 - k * 3, 3, 3, c("gray5"))
    save_ev(img, "raiders")
    # cache
    img = scene(DAY, "sand2", skyline="cream1", sun=(130, 18, "yellow3"))
    for i, (x, y) in enumerate(((60, 56), (78, 58), (68, 46))):
        crate(img, x, y, 18, 12, "green" if i % 2 else "wood")
    paste(img, dweller("army", "brown"), 104, 42)
    save_ev(img, "cache")
    # survivor
    img = scene(DUSK, "green2", skyline="teal1")
    paste(img, dweller("scav", "blonde", "sit"), 76, 46)
    for k, col in enumerate(("red2", "orange2", "yellow3")):
        poly(img, [(64 + k, 64), (68, 56 + k * 2), (72 - k, 64)], c(col))
    rect(img, 62, 64, 12, 2, c("wood1"))
    save_ev(img, "survivor")
    # rad storm
    img = scene(("teal1", "toxic2", "toxic3"), "green1", clouds=0)
    for k in range(18):
        ellipse(img, re_.randint(-10, EW), re_.randint(0, 36), re_.randint(20, 40), re_.randint(8, 14), c(re_.choice(["toxic1", "toxic2", "teal1"])))
    line(img, 100, 0, 92, 24, c("yellow3"), 2)
    line(img, 92, 24, 104, 40, c("yellow3"), 2)
    mini_truck(img, 30, 30)
    save_ev(img, "radstorm")
    # broken bridge
    img = scene(DAY, "blue2", horizon=52)
    for x in range(0, EW, 6):
        hline(img, x, 66 + (x % 3), 3, c("blue3"))
    for (x0, w) in ((0, 64), (100, 60)):
        rect(img, x0, 49, w, 6, OL)
        rect(img, x0, 50, w, 4, c("gray4"))
    line(img, 64, 52, 76, 66, OL, 3)
    line(img, 100, 52, 90, 68, OL, 3)
    for x in range(4, 64, 10):
        rect(img, x, 55, 3, 25, c("gray3"))
    mini_truck(img, 18, 22)
    save_ev(img, "bridge")
    # trader
    img = scene(DAY, "sand2", sun=(40, 30, "yellow3"))
    rect(img, 66, 40, 40, 22, OL)
    rect(img, 67, 41, 38, 20, c("wood2"))
    poly(img, [(62, 41), (86, 26), (110, 41)], c("red2"), OL)
    for k in range(5):
        poly(img, [(66 + k * 9, 41), (70 + k * 9, 46), (74 + k * 9, 41)], c("gray6"))
    for wx in (70, 94):
        ellipse(img, wx, 58, 10, 10, OL)
        ellipse(img, wx + 3, 61, 4, 4, c("yellow2"))
    for k in range(4):
        rect(img, 70 + k * 8, 49, 6, 6, OL)
        rect(img, 71 + k * 8, 50, 4, 4, c(["red2", "yellow2", "blue3", "green3"][k]))
    paste(img, dweller("jumpsuit", "gray"), 112, 42)
    save_ev(img, "trader")
    # sandstorm
    img = scene(("sand2", "sand3", "cream3"), "sand2", clouds=0)
    for k in range(40):
        y = re_.randint(0, EH)
        x = re_.randint(-20, EW)
        hline(img, x, y, re_.randint(8, 24), c(re_.choice(["sand3", "cream3", "orange3"])))
    mini_truck(img, 60, 30)
    save_ev(img, "sandstorm")
    # frozen
    img = scene(("blue3", "sky2", "snow3"), "snow3")
    mini_truck(img, 60, 30)
    for x in range(50, 112, 6):
        ellipse(img, x, 55, 9, 5, c("gray6"))
    for k in range(80):
        px(img, re_.randint(0, EW), re_.randint(0, EH), c("gray6"))
    save_ev(img, "frozen")
    # bugs
    img = scene(DAY, "green2", skyline="green3")
    bug = flip(chars.en_bug(0))
    for (x, y) in ((50, 60), (80, 64), (110, 58), (96, 50)):
        paste(img, bug, x, y)
    save_ev(img, "bugs")
    # bunker
    img = scene(DAY, "green2")
    poly(img, [(40, 57), (56, 30), (104, 30), (120, 57)], c("gray4"), OL)
    rect(img, 70, 38, 20, 19, OL)
    ellipse(img, 72, 40, 16, 14, c("gray3"))
    ellipse(img, 76, 44, 8, 6, c("yellow2"))
    for x in range(42, 120, 6):
        px(img, x, 54, c("yellow2"))
    save_ev(img, "bunker")
    # signal tower
    img = scene(NIGHT, "gray2", clouds=0)
    for k in range(0, 50):
        w = max(1, (50 - k) // 6)
        hline(img, 80 - w, 56 - k, w * 2 + 1, c("gray4") if k % 4 else c("red2"))
    ellipse(img, 77, 2, 7, 7, c("red3"))
    for r in (10, 18, 26):
        for a in range(200, 340, 8):
            x = 80 + r * math.cos(math.radians(a))
            y = 6 + r * 0.7 * math.sin(math.radians(a))
            px(img, x, y, c("teal3"))
    for _ in range(25):
        px(img, re_.randint(0, EW), re_.randint(0, 40), c("gray6"))
    mini_truck(img, 16, 30)
    save_ev(img, "signal")
    # stray dog
    img = scene(DUSK, "sand2", sun=(126, 36, "dusk3"))
    dog = new(14, 10)
    rect(dog, 3, 4, 9, 4, c("wood3"))
    ellipse(dog, 0, 1, 6, 6, c("wood3"))
    px(dog, 1, 0, c("wood1"))
    px(dog, 4, 0, c("wood1"))
    px(dog, 2, 3, OL)
    for x in (4, 10):
        vline(dog, x, 8, 2, c("wood2"))
    line(dog, 12, 4, 13, 1, c("wood3"))
    paste(img, outline_alpha(dog), 74, 54)
    paste(img, dweller("chef", "gray", "work1", flipx=True), 98, 44)
    ellipse(img, 90, 52, 4, 4, c("pink2"))
    save_ev(img, "dog")
    # cultists with mirrors
    img = scene(NIGHT, "gray2", clouds=0)
    for x in (40, 70, 100, 124):
        paste(img, dweller("raider", "red", "work2"), x, 42)
        px(img, x + 13, 46, c("gray6"))
    ellipse(img, 76, 50, 16, 8, c("yellow2"))
    ellipse(img, 79, 52, 10, 5, c("gray6"))
    for k in range(18):
        px(img, 84, 48 - k * 2, c("yellow3") if k < 8 else c("gray6"))
    save_ev(img, "cult")
    # gas station
    img = scene(DUSK, "sand1", skyline="purple1")
    rect(img, 30, 20, 100, 7, OL)
    rect(img, 31, 21, 98, 5, c("red2"))
    hline(img, 31, 23, 98, c("gray6"))
    for x in (36, 120):
        rect(img, x, 27, 4, 29, c("gray4"))
    for x in (60, 86):
        rect(img, x, 40, 10, 16, OL)
        rect(img, x + 1, 41, 8, 15, c("yellow2"))
        rect(img, x + 2, 42, 6, 4, c("night1"))
    for k in range(10):
        vline(img, 30 + k * 10, 27, re_.randint(2, 10), c("green2"))
    save_ev(img, "gas")
    # gambler
    img = scene(NIGHT, "wood1", clouds=0)
    rect(img, 60, 50, 40, 6, OL)
    rect(img, 61, 51, 38, 4, c("green2"))
    vline(img, 64, 56, 10, OL)
    vline(img, 95, 56, 10, OL)
    for (x, y) in ((72, 45), (80, 44)):
        rect(img, x, y, 6, 6, OL)
        rect(img, x + 1, y + 1, 4, 4, c("gray6"))
        px(img, x + 2, y + 2, c("red2"))
    paste(img, dweller("scav", "gray", "work1", flipx=True), 104, 40)
    save_ev(img, "gambler")
    # plane wreck
    img = scene(DAY, "sand2", sun=(28, 18, "yellow3"))
    poly(img, [(20, 58), (110, 40), (140, 44), (60, 62)], c("gray5"), OL)
    poly(img, [(70, 46), (96, 24), (104, 26), (86, 48)], c("gray4"), OL)
    for x in range(40, 120, 8):
        rect(img, x, 48 - (x - 40) // 5, 3, 2, c("sky1"))
    ellipse(img, 112, 38, 12, 12, None, c("yellow2"))
    for k in range(8):
        ellipse(img, 30 + re_.randint(0, 8), 48 - k * 5, 6, 5, c("gray4"))
    save_ev(img, "plane")
    # acid flood
    img = scene(("teal1", "teal2", "toxic3"), "toxic1", horizon=50, clouds=0)
    for x in range(0, EW, 3):
        px(img, x, 52 + (x // 3) % 3, c("toxic3"))
        if x % 9 == 0:
            ellipse(img, x, 60 + (x % 7), 4, 3, c("toxic3"))
    mini_truck(img, 64, 22)
    for k in range(50):
        x = re_.randint(0, EW)
        y = re_.randint(0, 46)
        line(img, x, y, x - 1, y + 3, c("toxic3"))
    save_ev(img, "acid")
    # rogue robot
    img = scene(DUSK, "gray3", skyline="purple1")
    paste(img, chars.en_sentry(0), 92, 42)
    line(img, 92, 46, 60, 50, c("pink2"))
    mini_truck(img, 20, 30)
    save_ev(img, "robot")
