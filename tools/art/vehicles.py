"""Vehicle tiers for the prestige ladder + towed trailers (grim 16-bit, cut-away side view, faces LEFT).

Shared geometry (scripts/world/vehicle.gd + scripts/autoload/data.gd VEHICLES — keep in sync):
  every main shell is 280x300; rooms are 64x52, three per floor, at cols x=44/118/184;
  floor f (bottom = 0) sits at y = 210 - 56*f; roof slab top = 210 - 56*(floors-1) - 6;
  ladder shaft x=108..117; front (cab / nose) x=0..37; rear deck x=254..278 (floor y=262).
  The cab's bottom floor is cut open for the engine room (engine_bay.CAB, drawn as cab_<tier>_<state>).

  van   2 floors  pale-blue camper van, sliding door, roof rack          wheels (26,284) (214,284)
  bus   3 floors  rusted yellow double/triple-decker, destination sign   wheels (34,284) (214,284)
  rig   4 floors  the rust-orange cab-over 18-wheeler                     wheels (22,284) (182,284) (222,284)
  train 4 floors  armoured locomotive (riveted steel, cowcatcher, stack)  bogie wheels on rails

  trailer / wagon: 248x300, 2 floors, rooms at local cols x=22/88/154, hitch x=0..15, rear deck x=224..247.

  ext_<id>: the same shell with every room hole plated over (closed "exterior" view for the X-ray toggle).
"""
import math, random
from .common import *
from . import truck as T
from . import engine_bay as EB

FLOOR_H = 56
RW, RH = 64, 52
COLS = [44, 118, 184]
SHAFT = (108, 118)
BODY = (38, 254)
CHASSIS_Y = 262
TW = 280
TRAILER_W = 248
TRAILER_COLS = [22, 88, 154]

TIERS = {
    "van":   {"floors": 2, "paint": "blue",   "wheels": [(26, 284), (214, 284)]},
    "bus":   {"floors": 3, "paint": "yellow", "wheels": [(34, 284), (214, 284)]},
    "rig":   {"floors": 4, "paint": "orange", "wheels": [(22, 284), (182, 284), (222, 284)]},
    "train": {"floors": 4, "paint": "gray",   "wheels": []},
}
TRAIN_WHEELS = [(16, 290), (36, 290), (150, 290), (170, 290), (214, 290), (234, 290)]
rv = random.Random(909)


def row_y(fb):
    return 210 - FLOOR_H * fb


def roof_y(floors):
    return row_y(floors - 1) - 6


SHIFT = {"gray": 2}


def pc(paint, i):
    n = len(RAMPS[paint]) - 1
    i += SHIFT.get(paint, 0)
    return c(f"{paint}{max(0, min(n, i))}")


# ------------------------------------------------------------------ the multi-floor body (common to all tiers)
def body(img, floors, paint, x0=BODY[0], x1=BODY[1], cols=COLS, shaft=True):
    roof = roof_y(floors)
    cy = CHASSIS_Y
    rect(img, x0, roof, x1 - x0, cy - roof, pc(paint, 1))
    for wx in (x0, x1 - 6):
        rect(img, wx, roof, 6, cy - roof, pc(paint, 2))
        vline(img, wx, roof, cy - roof, OL)
        vline(img, wx + 1, roof, cy - roof, pc(paint, 3))
        vline(img, wx + 4, roof, cy - roof, pc(paint, 1))
        vline(img, wx + 5, roof, cy - roof, OL)
        T.bolts(img, wx + 2, roof + 9, cy, 8, pc(paint, 0))
    rect(img, x0 - 3, roof, x1 - x0 + 6, 7, OL)
    rect(img, x0 - 2, roof + 1, x1 - x0 + 4, 5, pc(paint, 2))
    hline(img, x0 - 2, roof + 1, x1 - x0 + 4, pc(paint, 3))
    hline(img, x0 - 2, roof + 4, x1 - x0 + 4, pc(paint, 0))
    for fb in range(floors - 1):
        y = row_y(fb) - 4
        rect(img, x0 + 6, y, x1 - x0 - 12, 4, c("gray4"))
        hline(img, x0 + 6, y, x1 - x0 - 12, c("gray5"))
        hline(img, x0 + 6, y + 3, x1 - x0 - 12, OL)
        for xx in range(x0 + 10, x1 - 6, 12):
            px(img, xx, y + 1, c("gray3"))
    rect(img, x0, cy, x1 - x0, 8, c("gray2"))
    hline(img, x0, cy, x1 - x0, c("gray4"))
    hline(img, x0, cy + 1, x1 - x0, c("gray3"))
    hline(img, x0, cy + 7, x1 - x0, OL)
    if shaft:
        sx0, sx1 = SHAFT
        sh = cy - roof - 6
        rect(img, sx0, roof + 6, sx1 - sx0, sh, c("night2"))
        vline(img, sx0, roof + 6, sh, OL)
        vline(img, sx1 - 1, roof + 6, sh, OL)
        vline(img, sx0 + 2, roof + 6, sh, c("yellow1"))
        vline(img, sx1 - 3, roof + 6, sh, c("yellow1"))
        for yy in range(roof + 9, cy, 4):
            hline(img, sx0 + 2, yy, sx1 - sx0 - 4, c("yellow2"))
        for fb in range(floors):
            y = row_y(fb) - 4 if fb < floors - 1 else roof + 6
            for xx in range(sx0 + 1, sx1 - 1):
                px(img, xx, y + 1, c("yellow2") if (xx // 2) % 2 else OL)
            bx = (sx0 + sx1) // 2
            px(img, bx, y + 5, c("lamp2"))
            for k in range(-3, 4):
                tint_px(img, bx + k, y + 6, c("lamp1"), 0.35)
    for cx in cols:
        for fb in range(floors):
            ry = row_y(fb)
            rect(img, cx - 1, ry - 1, RW + 2, RH + 2, OL)
            rect(img, cx, ry, RW, RH, CLEAR)


def underbody(img, wheels, x0=2, x1=274, wells=True, tanks=True):
    by = CHASSIS_Y + 8
    rect(img, x0, by, x1 - x0, 6, OL)
    rect(img, x0 + 1, by + 1, x1 - x0 - 2, 4, c("gray2"))
    hline(img, x0 + 1, by + 1, x1 - x0 - 2, c("gray3"))
    if tanks:
        rect(img, 58, by + 2, 54, 12, OL)
        rect(img, 59, by + 3, 52, 10, c("gray4"))
        hline(img, 59, by + 3, 52, c("gray5"))
        for xx in (70, 86, 100):
            vline(img, xx, by + 3, 10, c("gray3"))
        rect(img, 114, by + 2, 20, 10, OL)
        rect(img, 115, by + 3, 18, 8, c("blue2"))
        hline(img, 115, by + 3, 18, c("blue3"))
    if wells:
        for (wx, wy) in wheels:
            ellipse(img, wx - 19, wy - 19, 39, 39, OL)
            ellipse(img, wx - 17, wy - 17, 35, 35, CLEAR)
            rect(img, wx - 19, wy, 39, 20, CLEAR)
        for (wx, wy) in wheels:
            for a in range(196, 345, 2):
                ang = math.radians(a)
                for r, col in ((20, OL), (19, c("gray3")), (18, c("gray4"))):
                    px(img, round(wx + r * math.cos(ang)), round(wy + r * math.sin(ang)), col)


def rear_deck(img, x1, floors, ladder=True):
    dk = CHASSIS_Y
    roof = roof_y(floors)
    rect(img, x1, dk - 2, 24, 5, OL)
    rect(img, x1, dk - 1, 23, 3, c("gray4"))
    hline(img, x1, dk - 1, 23, c("gray5"))
    line(img, x1 + 2, dk + 3, x1 + 8, dk + 10, OL, 2)
    line(img, x1 + 22, dk + 3, x1 + 16, dk + 10, OL, 2)
    for xx in (x1 + 8, x1 + 22):
        vline(img, xx, dk - 16, 14, c("yellow2"))
        vline(img, xx + 1, dk - 16, 14, OL)
    hline(img, x1 + 8, dk - 17, 16, OL)
    hline(img, x1 + 8, dk - 16, 15, c("yellow3"))
    hline(img, x1 + 8, dk - 9, 15, c("yellow2"))
    if ladder:
        for xx in (x1, x1 + 5):
            vline(img, xx, roof - 8, dk - roof + 6, c("gray4"))
        for yy in range(roof - 6, dk - 2, 5):
            hline(img, x1, yy, 6, c("gray5"))


def turret_mount(img, x1, floors):
    my = row_y(min(2, floors - 1)) + 26
    rect(img, x1, my, 18, 4, OL)
    hline(img, x1, my + 1, 17, c("gray5"))
    hline(img, x1, my + 2, 17, c("gray3"))
    line(img, x1, my + 12, x1 + 12, my + 4, OL)


def driver(img, x, y):
    ellipse(img, x, y, 9, 8, OL)
    ellipse(img, x + 1, y + 1, 7, 6, c("skin2"))
    rect(img, x, y, 9, 3, c("green2"))
    hline(img, x, y + 3, 9, OL)
    px(img, x + 3, y + 5, OL)
    rect(img, x, y + 8, 9, 5, c("green3"))
    frame(img, x, y + 8, 9, 5, OL)


def bumper(img, y, w=18):
    rect(img, 0, y, w, 6, OL)
    rect(img, 1, y + 1, w - 2, 4, c("gray3"))
    hline(img, 1, y + 1, w - 2, c("gray4"))
    for k in range(0, w - 2, 4):
        poly(img, [(1 + k, y + 5), (3 + k, y + 1), (5 + k, y + 1), (3 + k, y + 5)], c("yellow2"))


def headlight(img, x, y):
    rect(img, x, y, 6, 7, OL)
    rect(img, x + 1, y + 1, 4, 5, c("lamp1"))
    px(img, x + 1, y + 1, c("gray6"))


# ------------------------------------------------------------------ fronts
def front_van(img, paint):
    roof = roof_y(2)
    by = CHASSIS_Y + 8
    nose = [(38, roof), (24, roof), (6, roof + 34), (2, roof + 40), (0, by - 10), (0, by), (38, by)]
    poly(img, nose, OL)
    poly(img, [(37, roof + 1), (24, roof + 1), (7, roof + 34), (3, roof + 40), (1, by - 10), (1, by - 1), (37, by - 1)], pc(paint, 2))
    line(img, 24, roof + 1, 7, roof + 34, pc(paint, 3))
    # windshield
    poly(img, [(23, roof + 4), (34, roof + 4), (34, roof + 34), (10, roof + 34)], OL)
    poly(img, [(23, roof + 5), (33, roof + 5), (33, roof + 33), (11, roof + 33)], c("blue2"))
    line(img, 16, roof + 30, 24, roof + 8, c("blue4"))
    driver(img, 22, roof + 18)
    # two-tone stripe + rust
    rect(img, 1, roof + 52, 37, 6, c("cream2"))
    hline(img, 1, roof + 52, 37, OL)
    hline(img, 1, roof + 57, 37, OL)
    headlight(img, 0, roof + 62)
    rect(img, 0, roof + 72, 8, 12, OL)
    rect(img, 1, roof + 73, 6, 10, c("gray3"))
    for yy in range(roof + 74, roof + 83, 2):
        hline(img, 1, yy, 6, c("gray1"))
    bumper(img, by - 6, 22)
    T.bolts(img, 34, roof + 40, by - 8, 7, pc(paint, 0))


def front_bus(img, paint):
    roof = roof_y(3)
    by = CHASSIS_Y + 8
    rect(img, 0, roof, 39, by - roof, OL)
    rect(img, 1, roof + 1, 37, by - roof - 2, pc(paint, 2))
    vline(img, 1, roof + 1, by - roof - 2, pc(paint, 3))
    # destination sign (lit)
    rect(img, 3, roof + 6, 33, 10, OL)
    rect(img, 4, roof + 7, 31, 8, c("night1"))
    for k in range(5):
        rect(img, 6 + k * 6, roof + 9, 4, 4, c("lamp1") if k != 2 else c("red3"))
    # big windshield (two panes) on the top deck and the bottom deck
    # the bottom-deck pane is short: the engine room (engine_bay.CAB) sits under the driver
    for (wy, wh) in ((roof + 22, 30), (row_y(0) - 16, 20)):
        rect(img, 2, wy, 30, wh, OL)
        rect(img, 3, wy + 1, 28, wh - 2, c("blue2"))
        vline(img, 17, wy + 1, wh - 2, OL)
        line(img, 5, wy + wh - 4, 12, wy + 4, c("blue4"))
    driver(img, 20, row_y(0) - 13)
    rect(img, 1, row_y(1) + 20, 37, 5, c("ol1"))
    T.bolts(img, 35, roof + 20, by - 6, 6, pc(paint, 0))
    headlight(img, 0, by - 24)
    bumper(img, by - 6, 24)


def front_rig(img, paint):
    """the cab-over truck front (moved from truck.py)"""
    CAB = "red"
    top = 188
    by = CHASSIS_Y + 8
    poly(img, [(0, top + 8), (6, top), (37, top), (37, by), (0, by)], OL)
    poly(img, [(1, top + 8), (6, top + 1), (36, top + 1), (36, by - 1), (1, by - 1)], c(CAB + "2"))
    hline(img, 6, top + 1, 30, c(CAB + "3"))
    vline(img, 1, top + 8, by - top - 9, c(CAB + "3"))
    rect(img, 1, top + 36, 36, by - top - 37, c(CAB + "1"))
    hline(img, 1, top + 36, 36, OL)
    rect(img, 9, top - 4, 22, 4, OL)
    for i in range(4):
        rect(img, 10 + i * 5, top - 3, 4, 2, c("lamp1") if i % 2 else c("gray2"))
    poly(img, [(2, top + 9), (6, top + 3), (14, top + 3), (14, top + 26), (2, top + 26)], OL)
    poly(img, [(3, top + 9), (7, top + 4), (13, top + 4), (13, top + 25), (3, top + 25)], c("blue2"))
    line(img, 5, top + 22, 9, top + 8, c("gray6"))
    line(img, 8, top + 23, 12, top + 12, c("blue4"))
    rect(img, 16, top + 4, 19, 19, OL)
    rect(img, 17, top + 5, 17, 17, c("lamp0"))
    hline(img, 17, top + 5, 17, c("orange2"))
    driver(img, 21, top + 9)
    frame(img, 16, top + 25, 19, by - top - 27, c(CAB + "1"))
    rect(img, 30, top + 30, 4, 1, c("gray6"))
    digits = ["111.111", "1.1...1", "1.1..1.", "111..1."]
    for j, row in enumerate(digits):
        for i, ch in enumerate(row):
            if ch == "1":
                px(img, 20 + i, top + 40 + j, c("gray6"))
    headlight(img, 0, top + 34)
    rect(img, 0, top + 43, 5, 4, OL)
    rect(img, 1, top + 44, 3, 2, c("orange2"))
    rect(img, 0, top + 50, 8, 18, OL)
    rect(img, 1, top + 51, 6, 16, c("gray3"))
    for yy in range(top + 52, top + 67, 2):
        hline(img, 1, yy, 6, c("gray1"))
    bumper(img, by - 4, 18)
    rect(img, 31, 150, 6, 40, OL)
    rect(img, 32, 150, 4, 40, c("gray4"))
    vline(img, 32, 150, 40, c("gray5"))
    rect(img, 30, 146, 8, 5, OL)
    rect(img, 31, 147, 6, 3, c("gray3"))
    for i, yy in enumerate((CHASSIS_Y + 2, CHASSIS_Y + 6)):
        rect(img, 18 + i * 2, yy, 12, 3, OL)
        hline(img, 19 + i * 2, yy + 1, 10, c("gray5"))


def front_train(img, paint):
    roof = roof_y(4)
    by = CHASSIS_Y + 8
    nose = [(39, roof), (22, roof), (4, roof + 70), (1, by - 2), (39, by - 2)]
    poly(img, nose, OL)
    poly(img, [(38, roof + 1), (22, roof + 1), (5, roof + 70), (2, by - 3), (38, by - 3)], c("gray3"))
    line(img, 22, roof + 1, 5, roof + 70, c("gray4"))
    # riveted armour bands
    for y in range(roof + 12, by - 4, 14):
        for x in range(4, 38):
            if get(img, x, y)[:3] == c("gray3")[:3]:
                px(img, x, y, c("gray2"))
                if x % 4 == 0:
                    px(img, x, y - 2, c("gray5"))
    # vision slit with the driver
    rect(img, 18, roof + 30, 18, 12, OL)
    rect(img, 19, roof + 31, 16, 10, c("lamp0"))
    driver(img, 23, roof + 31)
    rect(img, 18, roof + 30, 18, 4, OL)
    # red war-stripe
    for x in range(2, 38):
        for y in range(roof + 96, roof + 102):
            if get(img, x, y)[3] and get(img, x, y)[:3] != OL[:3]:
                px(img, x, y, c("red1"))
    # big round headlamp
    ellipse(img, 4, roof + 120, 16, 16, OL)
    ellipse(img, 6, roof + 122, 12, 12, c("lamp1"))
    px(img, 9, roof + 125, c("lamp2"))
    # smokestack on top of the nose
    rect(img, 24, roof - 18, 10, 19, OL)
    rect(img, 25, roof - 18, 8, 19, c("gray2"))
    vline(img, 26, roof - 18, 19, c("gray3"))
    rect(img, 22, roof - 22, 14, 5, OL)
    rect(img, 23, roof - 21, 12, 3, c("gray3"))
    # cowcatcher
    poly(img, [(0, by + 2), (24, by + 2), (24, by + 22), (10, by + 22)], OL)
    for k in range(4):
        x = 2 + k * 5
        line(img, x + 2, by + 3, x + 9, by + 21, c("gray4"))


def train_bogies(img):
    by = CHASSIS_Y + 8
    for bx in (6, 140, 204):
        rect(img, bx, by + 6, 46 if bx != 204 else 44, 6, OL)
        rect(img, bx + 1, by + 7, 44 if bx != 204 else 42, 4, c("gray2"))
        hline(img, bx + 1, by + 7, 44 if bx != 204 else 42, c("gray3"))
    for (wx, wy) in TRAIN_WHEELS:
        ellipse(img, wx - 10, wy - 10, 21, 21, OL)
        ellipse(img, wx - 9, wy - 9, 19, 19, CLEAR)


def rail_wheel_frames():
    out = []
    for f in range(4):
        w = new(20, 20)
        ellipse(w, 0, 0, 20, 20, OL)
        ellipse(w, 1, 1, 18, 18, c("gray3"))
        ellipse(w, 3, 3, 14, 14, c("gray2"))
        for k in range(4):
            a = k / 4 * math.tau + f * math.tau / 16
            line(w, 10, 10, round(10 + 6 * math.cos(a)), round(10 + 6 * math.sin(a)), c("gray4"))
        ellipse(w, 7, 7, 6, 6, OL)
        ellipse(w, 8, 8, 4, 4, c("orange1"))
        a = f * math.tau / 4
        rect(w, round(9 + 5 * math.cos(a)), round(9 + 5 * math.sin(a)), 2, 2, c("gray5"))
        out.append(w)
    return out


# ------------------------------------------------------------------ assemble
FRONTS = {"van": front_van, "bus": front_bus, "rig": front_rig, "train": front_train}


def roof_props(img, floors, tier):
    props = T.gen_roof_props(floors)
    paste(img, props, 0, roof_y(floors) - 36)
    if tier == "van":
        # roof rack with crates/jerrycans over the front
        r = roof_y(2)
        rect(img, 40, r - 4, 40, 2, OL)
        for x in (42, 56, 70):
            vline(img, x, r - 4, 4, OL)


def gen_tier(tier):
    cfg = TIERS[tier]
    floors, paint = cfg["floors"], cfg["paint"]
    img = new(TW, 300)
    body(img, floors, paint)
    if tier == "train":
        train_bogies(img)
        underbody(img, [], wells=False, tanks=False)
        train_bogies(img)
    else:
        underbody(img, cfg["wheels"])
    rear_deck(img, BODY[1], floors)
    turret_mount(img, BODY[1], floors)
    FRONTS[tier](img, paint)
    roof_props(img, floors, tier)
    return img


def exterior(shell, floors, cols, paint, tier):
    """plate over every room hole (closed hull view for the cut-away toggle)"""
    img = shell.copy()
    rng = random.Random(len(tier) * 31)
    for fb in range(floors):
        ry = row_y(fb)
        for ci, cx in enumerate(cols):
            rect(img, cx, ry, RW, RH, pc(paint, 1))
            for xx in range(cx + 16, cx + RW, 16):
                vline(img, xx, ry, RH, pc(paint, 0))
                vline(img, xx + 1, ry, RH, pc(paint, 2))
            hline(img, cx, ry + RH // 2, RW, pc(paint, 0))
            for xx in range(cx + 3, cx + RW, 8):
                px(img, xx, ry + 2, pc(paint, 3))
                px(img, xx, ry + RH - 3, pc(paint, 3))
            # porthole windows, some lit
            for k in range(2):
                wx = cx + 12 + k * 30
                rect(img, wx, ry + 14, 10, 8, OL)
                lit = rng.random() < 0.55
                rect(img, wx + 1, ry + 15, 8, 6, c("lamp0") if lit else c("night1"))
                if lit:
                    px(img, wx + 2, ry + 16, c("lamp1"))
                rect(img, wx + 1, ry + 18, 8, 1, OL)
            if rng.random() < 0.4:
                rect(img, cx + 26, ry + 32, 12, 8, c("gray2"))
                for yy in range(ry + 33, ry + 40, 2):
                    hline(img, cx + 27, yy, 10, c("gray1"))
    if cols == COLS:
        sx0, sx1 = SHAFT
        r = roof_y(floors)
        rect(img, sx0, r + 6, sx1 - sx0, CHASSIS_Y - r - 6, pc(paint, 0))
        vline(img, sx0 + 4, r + 6, CHASSIS_Y - r - 6, pc(paint, 2))
    # livery stripe across the whole body
    x0 = cols[0] - 6
    x1 = cols[-1] + RW + 6
    yb = row_y(0) + 40
    rect(img, x0, yb, x1 - x0, 4, c("red1") if paint != "red" else c("cream2"))
    hline(img, x0, yb, x1 - x0, OL)
    hline(img, x0, yb + 3, x1 - x0, OL)
    return img


def gen_trailer(kind="trailer"):
    paint = "orange" if kind == "trailer" else "gray"
    img = new(TRAILER_W, 300)
    x0, x1 = 16, 224
    body(img, 2, paint, x0=x0, x1=x1, cols=TRAILER_COLS, shaft=False)
    # hitch / coupler
    by = CHASSIS_Y + 8
    rect(img, 0, CHASSIS_Y + 2, 18, 5, OL)
    rect(img, 1, CHASSIS_Y + 3, 16, 3, c("gray3"))
    ellipse(img, 0, CHASSIS_Y + 1, 7, 7, OL)
    if kind == "trailer":
        wheels = [(60, 284), (184, 284)]
        underbody(img, wheels, x0=14, x1=226, tanks=False)
    else:
        underbody(img, [], x0=14, x1=226, wells=False, tanks=False)
        for bx in (24, 162):
            rect(img, bx, by + 6, 46, 6, OL)
            rect(img, bx + 1, by + 7, 44, 4, c("gray2"))
        for wx in (34, 54, 172, 192):
            ellipse(img, wx - 10, 280, 21, 21, OL)
            ellipse(img, wx - 9, 281, 19, 19, CLEAR)
    rear_deck(img, x1, 2, ladder=True)
    # tarp + cargo on the trailer roof
    r = roof_y(2)
    for (bx, bw) in ((30, 30), (70, 22), (120, 36), (170, 26)):
        rect(img, bx, r - 10, bw, 10, OL)
        rect(img, bx + 1, r - 9, bw - 2, 8, c("green2") if bx % 20 else c("wood2"))
        line(img, bx + 1, r - 9, bx + bw - 2, r - 2, c("green1"))
    return img


def rails_strip():
    """480x14 seamless railway (sleepers + two rails) drawn over the road for the armoured train"""
    img = new(480, 14)
    for x in range(0, 480, 12):
        rect(img, x, 6, 8, 6, OL)
        rect(img, x + 1, 7, 6, 4, c("wood1"))
        hline(img, x + 1, 7, 6, c("wood2"))
    rect(img, 0, 2, 480, 3, OL)
    hline(img, 0, 2, 480, c("gray5"))
    hline(img, 0, 3, 480, c("gray3"))
    return img


def gen_vehicles():
    for tier, cfg in TIERS.items():
        shell = T.weather(gen_tier(tier), len(tier) * 11)
        add(f"ext_{tier}", exterior(shell, cfg["floors"], COLS, cfg["paint"], tier))
        EB.cut_cab(shell, tier)          # v4.6: the cab's bottom floor is the walk-in engine room
        add(f"veh_{tier}", shell)
    for kind in ("trailer", "wagon"):
        sh = T.weather(gen_trailer(kind), len(kind) * 5)
        add(f"veh_{kind}", sh)
        add(f"ext_{kind}", exterior(sh, 2, TRAILER_COLS, "orange" if kind == "trailer" else "gray", kind))
    for i, f in enumerate(rail_wheel_frames()):
        add(f"rwheel_{i}", f)
    save(rails_strip(), OUT_BG + "/rails.png")
