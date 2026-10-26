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
    """MV-391: 20x20 rail wheel, 4 phases: steel flange, four spokes over dark recessed gaps (a quarter turn
    over the loop), oily rust hub, one short fixed highlight on the upper flange."""
    out = []
    for f in range(4):
        w = new(20, 20)
        ellipse(w, 0, 0, 20, 20, OL)
        ellipse(w, 1, 1, 18, 18, c("gray3"))          # flange
        ellipse(w, 3, 3, 14, 14, OL)
        ellipse(w, 4, 4, 12, 12, c("gray1"))          # recessed gaps
        for k in range(4):
            a = k / 4 * math.tau + f * math.tau / 16
            ex, ey = round(9.5 + 6 * math.cos(a)), round(9.5 + 6 * math.sin(a))
            line(w, 10, 10, ex, ey, c("gray3"))
            line(w, 9, 9, round(9.5 + 5 * math.cos(a)) - 1, round(9.5 + 5 * math.sin(a)) - 1, c("gray4"))
        ellipse(w, 7, 7, 6, 6, OL)
        ellipse(w, 8, 8, 4, 4, c("orange1"))
        px(w, 10, 10, c("gray1"))                     # oil on the hub
        hline(w, 5, 2, 3, c("gray5"))                 # fixed upper highlight
        out.append(w)
    return out


# ------------------------------------------------------------------ MV-388 shell details (rig-detail-idle-concept-v1)
# Each one is also its own atlas sprite (micro-asset spec id). The static ones are baked into the shells once,
# after weathering and before the exterior copy, so the cut-away and closed views both carry them.
def decal_car_pillar_wear():
    """6x52: chip clusters, one short rust run, two rivet accents on a body pillar (columns 1-4 are paint)"""
    img = new(6, 52)
    for (x, y) in ((2, 7), (3, 7), (2, 8)):                 # chip cluster 1 (bare metal under paint)
        px(img, x, y, c("gray3"))
    px(img, 3, 8, c("ol1"))
    for (x, y) in ((3, 19), (4, 19), (3, 20)):              # chip cluster 2
        px(img, x, y, c("gray4"))
    px(img, 4, 20, c("ol1"))
    for (x, y) in ((1, 33), (2, 33), (2, 34)):              # chip cluster 3
        px(img, x, y, c("gray3"))
    px(img, 1, 34, c("ol1"))
    for (x, y) in ((3, 45), (4, 45)):                       # chip cluster 4
        px(img, x, y, c("gray4"))
    for yy in range(35, 41):                                # rust run below cluster 3
        px(img, 2, yy, c("orange2") if yy < 37 else c("orange1"))
    px(img, 3, 36, c("orange1"))
    for y in (13, 27):                                      # rivet accents
        px(img, 2, y, c("gray4"))
        px(img, 3, y + 1, OL)
    return img


def decal_car_weld_patch():
    """12x8 bolted repair plate on the chassis band with a short weld bead on its right edge"""
    img = new(12, 8)
    rect(img, 0, 0, 11, 8, OL)
    rect(img, 1, 1, 9, 6, c("gray3"))
    hline(img, 1, 1, 9, c("gray4"))
    vline(img, 1, 1, 6, c("gray4"))
    px(img, 1, 1, c("gray5"))
    hline(img, 2, 6, 8, c("gray2"))
    px(img, 6, 4, c("orange1"))                             # rust under the plate
    px(img, 7, 5, c("orange2"))
    for bx in (3, 8):                                       # bolts
        px(img, bx, 3, c("gray5"))
        px(img, bx + 1, 4, c("gray1"))
    for y in range(1, 7):                                   # weld bead
        px(img, 11, y, c("gray4") if y % 2 else c("orange1"))
    return img


def decal_car_tank_detail():
    """54x12 overlay on the fuel tank box (58..111, 272..283): straps at local x=12/28/42, a seam, low soot"""
    img = new(54, 12)
    for x in (12, 28, 42):
        px(img, x, 1, c("gray5"))
        vline(img, x, 2, 9, c("gray2"))
        vline(img, x + 1, 1, 10, OL)
        px(img, x - 1, 6, c("gray3"))                       # strap buckle
    hline(img, 18, 5, 6, c("gray2"))                        # weld seam
    px(img, 20, 5, c("gray4"))
    for (x, y, k) in ((3, 9, "gray1"), (4, 10, "gray1"), (5, 10, "gray2"), (22, 10, "gray1"), (23, 9, "gray2"),
                      (34, 10, "gray1"), (35, 10, "gray1"), (47, 9, "gray2"), (48, 10, "gray1")):
        px(img, x, y, c(k))                                 # soot clusters
    px(img, 13, 8, c("orange1"))                            # rust where the straps bite
    px(img, 29, 9, c("orange2"))
    px(img, 43, 8, c("orange1"))
    return img


def prop_car_leaf_spring():
    """32x10 stock leaf spring: three stepped leaves, shackle brackets at both ends, central axle clamp"""
    img = new(32, 10)
    for (x, y, w) in ((2, 3, 28), (5, 5, 22), (9, 7, 14)):
        rect(img, x, y, w, 2, OL)
        hline(img, x + 1, y, w - 2, c("gray4") if y == 3 else c("gray3"))
    px(img, 3, 3, c("gray5"))
    for bx in (0, 29):                                      # shackle brackets bolted to the chassis
        rect(img, bx, 0, 3, 5, OL)
        vline(img, bx + 1, 0, 4, c("gray2"))
        px(img, bx + 1, 3, c("orange1"))
    rect(img, 14, 2, 4, 8, OL)                              # axle clamp + U-bolt
    vline(img, 15, 3, 6, c("gray4"))
    vline(img, 16, 3, 6, c("gray2"))
    px(img, 15, 3, c("gray5"))
    px(img, 16, 8, c("orange2"))
    return img


def decal_car_lamp_cage():
    """2x6 protective strip over the left columns of the nose lamp: four corner fasteners, open middle"""
    img = new(2, 6)
    for (x, y) in ((0, 0), (1, 0), (0, 5), (1, 5)):
        px(img, x, y, OL)
    px(img, 0, 1, c("gray4"))
    px(img, 0, 4, c("gray2"))
    px(img, 1, 1, c("orange1"))
    return img


def decal_train_bogie_detail():
    """44x6 overlay inside a 46px train bogie beam: two spring recesses, four bolts, a rust seam"""
    img = new(44, 6)
    for x in (10, 30):                                      # spring recesses
        rect(img, x, 1, 4, 4, OL)
        hline(img, x + 1, 2, 2, c("gray1"))
        hline(img, x + 1, 4, 2, c("gray2"))
    for x in (3, 6, 37, 40):                                # bolt groups
        px(img, x, 1, c("gray5"))
        px(img, x, 2, c("gray1"))
    hline(img, 17, 4, 9, c("orange1"))                      # rust seam
    px(img, 20, 4, c("orange2"))
    px(img, 24, 3, c("gray4"))
    return img


PILLAR_WEAR = decal_car_pillar_wear()
WELD_PATCH = decal_car_weld_patch()
TANK_DETAIL = decal_car_tank_detail()
LAMP_CAGE = decal_car_lamp_cage()
BOGIE_DETAIL = decal_train_bogie_detail()
# where the cage sits on the nose lamp: (cut-away after cut_cab, closed shell); the train is excluded
LAMP_CAGE_AT = {"van": ((0, 210), (0, 210)), "bus": ((0, 222), (0, 224)), "rig": ((0, 228), (0, 230))}


def prop_car_chain_idle():
    """MV-399: 4 frames 6x14 at 2 fps: a safety chain hanging from the rear deck; the top two pixels are fixed,
    links alternate dark / lit, only the lower tip moves (1 px)"""
    tips = [0, 1, 0, -1]
    out = []
    for f, dx in enumerate(tips):
        img = new(6, 14)
        px(img, 2, 0, OL)                                   # shackle (fixed)
        px(img, 2, 1, c("gray4"))
        for y in range(2, 13):
            x = 2 + (dx if y >= 9 else 0)
            px(img, x, y, c("gray2") if y % 2 else c("gray4"))
            if y % 2 == 0:
                px(img, x + 1, y, OL)
        px(img, 2 + dx, 13, c("orange1"))                   # rusty hook
        out.append(img)
    return out


def prop_car_mudflap_idle():
    """MV-400: 4 frames 10x14 at 3 fps, played once per wind gust: rubber flap on two fixed mounting pixels,
    the ragged lower edge moves at most 1 px; caked dust near the bottom"""
    sway = [0, 1, 1, 0]
    out = []
    for f, dx in enumerate(sway):
        img = new(10, 14)
        px(img, 2, 0, OL)                                   # mounting bolts (fixed)
        px(img, 7, 0, OL)
        rect(img, 1, 1, 8, 9, OL)
        rect(img, 2, 1, 6, 8, c("gray1"))
        vline(img, 2, 1, 8, c("gray2"))
        for y in range(10, 13):                             # lower part sways
            hline(img, 1 + dx, y, 8, OL)
            hline(img, 2 + dx, y, 6, c("gray1") if y < 12 else c("sand1"))
        for x in (2, 5, 7):                                 # ragged edge
            px(img, x + dx, 13, OL)
        px(img, 4 + dx, 11, c("sand1"))
        out.append(img)
    return out


# ------------------------------------------------------------------ MV-519 driving cabs (Viktor, approved rig v3)
# Each cab is a micro-asset decal baked into veh_<tier> / ext_<tier> at its anchor (frame 0). The driver is the
# actual dw_crew_viktor sit frame (chars.crew_frame) mirrored to face left; only the arm is redrawn to reach the
# wheel. decal_<tier>_driver_cockpit_idle_0..3 = the same decal with one tiny change each, played over the
# window by Vehicle (switch driver_cab): 0 = the baked look, 1 = Viktor blinks, 2 = the indicator goes dark,
# 3 = his hand nudges the wheel.
DRIVER_CAB = {
    # anchor (shell px), size, Viktor's top-left, wheel rim x, dash top y (None = no dash), seat x,
    # overhead lamp (x, y) / None, ceiling rail y / None, dial, indicator
    "van":   {"at": (11, 153), "size": (23, 29), "vk": (10, 11), "wheel": 9, "dash": 25, "seat": 21,
              "lamp": (16, 6), "ceil": 6, "dial": (12, 26), "ind": (14, 26)},
    "bus":   {"at": (18, 195), "size": (13, 18), "vk": (0, 2), "wheel": 0, "dash": 16, "seat": 12,
              "lamp": (2, 0), "ceil": 0, "dial": (1, 17), "ind": (3, 17)},
    "rig":   {"at": (17, 193), "size": (17, 17), "vk": (3, 2), "wheel": 1, "dash": 15, "seat": 15,
              "lamp": (2, 0), "ceil": 0, "dial": (1, 16), "ind": (3, 16)},
    "train": {"at": (18, 66), "size": (18, 14), "vk": (5, 0), "wheel": 3, "dash": None, "seat": 15,
              "lamp": None, "ceil": None, "dial": (2, 4), "ind": (2, 6)},
}
VAN_GLASS = [(12, 0), (22, 0), (22, 28), (0, 28)]      # the van's original inner windshield, decal-local
VAN_GLINT = (5, 25, 13, 3)                              # and its reflection


def _viktor(blink):
    """dw_crew_viktor sit (strip cell 6), mirrored left, exactly as the crew strip draws it"""
    from . import chars
    return flip(chars.crew_frame("viktor", "sit", 0, blink=blink))


def _driver_cab(tier, frame=0):
    d = DRIVER_CAB[tier]
    w, h = d["size"]
    img = new(w, h)
    rect(img, 0, 0, w, h, c("gray1"))                       # dark cabin
    ox, oy = d["vk"]
    sx = d["seat"]
    vline(img, sx, oy + 9, h - oy - 9, OL)                  # worn seat back behind his right
    if sx + 1 < w:
        vline(img, sx + 1, oy + 10, h - oy - 10, c("wood1"))
        px(img, sx + 1, oy + 10, c("gray3"))
    if d["ceil"] is not None:                               # ceiling rail
        hline(img, 0, d["ceil"], w, c("wood1"))
    if d["dash"] is not None:                               # dash under the windscreen: one dial, one indicator
        dy = d["dash"]
        rect(img, 0, dy, w, h - dy, c("gray3"))
        hline(img, 0, dy, w, OL)
    paste(img, _viktor(frame == 1).crop((0, 0, 14, 16)), ox, oy)   # head, collar, jacket; the sill hides the rest
    if d["dash"] is not None:
        hline(img, 0, d["dash"], ox + 3, OL)
        rect(img, 0, d["dash"] + 1, ox + 3, h - d["dash"] - 1, c("gray3"))
    # driving arm: from his shoulder forward (left) to the wheel, sleeve snow2 over snow0, soot above
    wx = d["wheel"]
    nudge = 1 if frame == 3 else 0
    ay = oy + 12
    for x in range(wx + 1, ox + 6):
        px(img, x, ay - 1, OL)
        px(img, x, ay, c("snow2"))
        px(img, x, ay + 1, c("snow0"))
    # steering wheel seen edge-on: a tilted rim, soot-lined, hand gripping its lower side
    for k in range(4):
        x = wx + (1 if k < 2 else 0)
        px(img, x, ay - 3 + k, c("gray5"))
        px(img, x - 1, ay - 3 + k, OL)
    px(img, wx + 1, ay - nudge, c("skin3"))                 # hand on the rim
    px(img, wx + 2, ay - nudge, c("skin1"))
    if nudge:
        px(img, wx + 1, ay, c("snow2"))
        px(img, wx + 2, ay, c("snow2"))
    px(img, *d["dial"], c("cream2"))
    px(img, *d["ind"], c("lamp1") if frame != 2 else c("gray3"))
    if d["lamp"] is not None:                               # overhead practical lamp in a soot housing
        lx, ly = d["lamp"]
        hline(img, lx, ly, 3, OL)
        px(img, lx + 1, ly + 1, c("lamp1"))
        px(img, lx, ly + 1, OL)
        px(img, lx + 2, ly + 1, OL)
    return img


def _cab_frame(tier, img):
    """vehicle-specific framing of a cab decal (what the shell's window shape asks for)"""
    w, h = img.size
    if tier == "van":
        mask = new(w, h)
        poly(mask, VAN_GLASS, OL)
        glass = new(w, h)
        rect(glass, 0, 0, w, h, c("blue2"))
        line(glass, *VAN_GLINT, c("blue4"))
        gx0, gy0, gx1, gy1 = VAN_GLINT
        out = new(w, h)
        for y in range(h):
            # cold glass and its glint on the upper/left slope, the cabin behind it lower/right
            edge = gx0 + (gy0 - min(y, gy0)) * (gx1 - gx0) // (gy0 - gy1) + 2
            for x in range(w):
                if mask.getpixel((x, y))[3]:
                    inside = y >= 6 and x >= edge
                    out.putpixel((x, y), img.getpixel((x, y)) if inside else glass.getpixel((x, y)))
        return out
    if tier == "train":
        hline(img, 0, 0, w, OL)                             # armoured visor over the slit
        hline(img, 0, 1, w, c("gray4"))
        px(img, 0, 1, OL)
        px(img, w - 1, 1, OL)
        vline(img, 0, 2, h - 2, OL)
        vline(img, w - 1, 2, h - 2, OL)
        hline(img, 0, h - 1, w, OL)                         # sill hides the lower body
    return img


def driver_cab_frames(tier):
    return [_cab_frame(tier, _driver_cab(tier, f)) for f in range(4)]


def shell_details(img, floors, trailer, tier=""):
    """bake the static MV-388 details once into a weathered shell (before exterior() copies it)"""
    xs = (16, 218) if trailer else (38, 248)
    for fb in range(floors):
        for x in xs:
            paste(img, PILLAR_WEAR, x, 210 - 56 * fb)
    paste(img, WELD_PATCH, 136 if trailer else 138, 262)
    if tier in ("van", "bus", "rig"):
        paste(img, TANK_DETAIL, 58, 272)
    if tier == "train":
        for bx in (7, 141):
            paste(img, BOGIE_DETAIL, bx, 276)


# ------------------------------------------------------------------ assemble
FRONTS = {"van": front_van, "bus": front_bus, "rig": front_rig, "train": front_train}


def roof_props(img, floors, tier):
    props = T.gen_roof_props(floors, flag=False)     # MV-388: the flag is animated by Vehicle
    paste(img, props, 0, roof_y(floors) - 36)
    if tier == "van":
        # roof rack with crates/jerrycans over the front
        r = roof_y(2)
        rect(img, 40, r - 4, 40, 2, OL)
        for x in (42, 56, 70):
            vline(img, x, r - 4, 4, OL)


ROOF_LEGACY_X, ROOF_LEGACY_W = 38, 146     # roof-local box that holds the old planters / tank / dish


def split_roof_parts(raw, shells, floors):
    """MV-462: lift the old planters, water tank and dish out of the finished (weathered) shells. A pixel goes
    when the roof props draw it only with those parts and nothing drawn later covered it (raw = the shell
    before weathering). It is replaced by what the props draw without them. Returns the lifted pixels as
    roof_legacy_<tier> (ROOF_LEGACY_W x 38, at roof-local x=ROOF_LEGACY_X), the switch-off look."""
    full = T.gen_roof_props(floors, flag=False)
    bare = T.gen_roof_props(floors, flag=False, parts=False)
    off = roof_y(floors) - 36
    legacy = new(ROOF_LEGACY_W, 38)
    for y in range(38):
        for x in range(ROOF_LEGACY_X, ROOF_LEGACY_X + ROOF_LEGACY_W):
            p = full.getpixel((x, y))
            if p == bare.getpixel((x, y)) or raw.getpixel((x, y + off)) != p:
                continue
            legacy.putpixel((x - ROOF_LEGACY_X, y), shells[0].getpixel((x, y + off)))
            for sh in shells:
                sh.putpixel((x, y + off), bare.getpixel((x, y)))
    return legacy


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
        raw = gen_tier(tier)
        shell = T.weather(raw.copy(), len(tier) * 11)
        shell_details(shell, cfg["floors"], False, tier)
        cab = driver_cab_frames(tier)
        paste(shell, cab[0], *DRIVER_CAB[tier]["at"])      # MV-519: before exterior() copies the shell
        ext = exterior(shell, cfg["floors"], COLS, cfg["paint"], tier)
        EB.cut_cab(shell, tier)          # v4.6: the cab's bottom floor is the walk-in engine room
        if tier in LAMP_CAGE_AT:
            paste(shell, LAMP_CAGE, *LAMP_CAGE_AT[tier][0])
            paste(ext, LAMP_CAGE, *LAMP_CAGE_AT[tier][1])
        add(f"roof_legacy_{tier}", split_roof_parts(raw, [shell, ext], cfg["floors"]))
        add(f"ext_{tier}", ext)
        add(f"veh_{tier}", shell)
        add(f"decal_{tier}_driver_cockpit", cab[0])
        for i in range(1, len(cab)):
            add(f"decal_{tier}_driver_cockpit_idle_{i}", cab[i])
    for kind in ("trailer", "wagon"):
        sh = T.weather(gen_trailer(kind), len(kind) * 5)
        shell_details(sh, 2, True)
        add(f"veh_{kind}", sh)
        add(f"ext_{kind}", exterior(sh, 2, TRAILER_COLS, "orange" if kind == "trailer" else "gray", kind))
    # MV-388: the details as their own sprites (micro-asset ids); the leaf spring is placed at runtime by Vehicle
    add("decal_car_pillar_wear", PILLAR_WEAR)
    add("decal_car_weld_patch", WELD_PATCH)
    add("decal_car_tank_detail", TANK_DETAIL)
    add("prop_car_leaf_spring", prop_car_leaf_spring())
    add("decal_car_lamp_cage", LAMP_CAGE)
    add("decal_train_bogie_detail", BOGIE_DETAIL)
    for i, f in enumerate(prop_car_chain_idle()):
        add(f"prop_car_chain_idle_{i}", f)
    for i, f in enumerate(prop_car_mudflap_idle()):
        add(f"prop_car_mudflap_idle_{i}", f)
    for i, f in enumerate(rail_wheel_frames()):
        add(f"rwheel_{i}", f)
    save(rails_strip(), OUT_BG + "/rails.png")
