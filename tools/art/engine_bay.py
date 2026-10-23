"""Engine bay (v4.6): the walk-in engine room inside every cab + the engine type icons for the engine menu.

The room sits in the cab's bottom floor, under the driver (never in the body's room grid). Each vehicle's
cab gets its own size so it fits that front (keep CAB in sync with Data.VEHICLES[tier].cab):
  van   31x58 at (2,204)  under the cream stripe, small inline-4
  bus   32x46 at (2,216)  under the shortened bottom-deck windshield, inline-6
  rig   33x41 at (2,222)  under the cab-over driver, turbo diesel with its snail
  train 35x66 at (3,196)  tall locomotive bay with a catwalk, diesel-electric genset

cab_<tier>_<state> (state: idle / run / hot / broken) is the interior drawn BEHIND the shell; vehicles.py cuts
the hole and draws the trim (cut_cab). Crew are DwellerActors on top (floor = h - 6).
eng_<type> (56x40) are the engine pictures for the menu.
"""
import random
from .common import *

CAB = {
    "van":   {"rect": (2, 204, 31, 58), "trim": "blue",   "engine": "i4"},
    "bus":   {"rect": (2, 216, 32, 46), "trim": "yellow", "engine": "i6"},
    "rig":   {"rect": (2, 222, 33, 41), "trim": "red",    "engine": "turbo"},
    "train": {"rect": (3, 196, 35, 66), "trim": "gray",   "engine": "genset"},
}
STATES = ("idle", "run", "hot", "broken")


def _engine(r, kind, w, h, state):
    floor = h - 6
    bx, bw, bh = {"i4": (9, 14, 13), "i6": (9, 17, 14), "turbo": (8, 16, 13), "genset": (7, 22, 20)}[kind]
    stand = 4
    by = floor - stand - bh
    rect(r, bx - 1, floor - stand, bw + 2, stand, OL)
    rect(r, bx, floor - stand + 1, bw, stand - 2, c("yellow1"))
    for i in range(0, bw, 4):
        rect(r, bx + i, floor - stand + 1, 2, stand - 2, c("ol1"))
    genset = kind == "genset"
    orect(r, bx, by, bw, bh, c("yellow1" if genset else "gray3"), OL)
    hline(r, bx + 1, by + 1, bw - 2, c("yellow2" if genset else "gray5"))
    for i in range(bw // 5):
        vline(r, bx + 3 + i * 5, by + 4, bh - 7, c("ol1" if genset else "gray2"))
    cover = {"i4": ("red2", "red3"), "i6": ("teal2", "teal3"), "turbo": ("red2", "red3"), "genset": ("gray3", "gray4")}[kind]
    orect(r, bx - 1, by - 4, bw + 2, 5, c(cover[0]), OL)
    hline(r, bx, by - 3, bw, c(cover[1]))
    if kind == "turbo":
        ellipse(r, bx + bw - 3, by + 2, 8, 8, OL)
        ellipse(r, bx + bw - 2, by + 3, 6, 6, c("gray4"))
        px(r, bx + bw + 1, by + 6, c("orange2"))
    if genset:
        orect(r, bx + bw - 1, by + 4, 6, bh - 4, c("teal1"), OL)
        vline(r, bx + bw + 1, by + 6, bh - 8, c("teal3"))
        line(r, bx + bw + 5, by + 6, w - 3, by - 2, c("orange2"))
    if state in ("run", "hot"):
        k = "orange2" if state == "run" else "red3"
        for i in range(bw // 6 + 1):
            px(r, bx + 3 + i * 5, by + bh - 3, c(k))
        light_radial(r, bx + bw // 2, by + bh - 2, 10, c("orange3"), 0.25 if state == "run" else 0.55)
    if state == "broken":
        line(r, bx + 3, by + 2, bx + 9, by + bh - 3, OL)
        rect(r, bx + 1, floor - 1, 12, 1, c("gray0"))
    return bx, by, bw, bh


def cab_room(tier, state):
    cfg = CAB[tier]
    _, _, w, h = cfg["rect"]
    rng = random.Random(len(tier) * 7 + STATES.index(state))
    r = new(w, h)
    gradient_v(r, 0, 0, w, h, [(0.0, c("gray1")), (0.7, c("gray2")), (1.0, c("gray1"))])
    rect(r, 0, 0, w, 2, OL)
    hline(r, 0, 1, w, c("gray4"))
    gh = h - 16
    rect(r, 0, 6, 5, gh, OL)
    for yy in range(7, 6 + gh - 1, 2):
        hline(r, 1, yy, 3, c("gray4"))
    bx, by, bw, bh = _engine(r, cfg["engine"], w, h, state)
    fy = by + bh // 2 - 5
    ellipse(r, 5, fy, 5, 10, OL)
    vline(r, 7, fy + 1, 8, c("gray4"))
    ex = min(bx + bw - 3, w - 10)
    rect(r, ex, 0, 3, max(2, by - 4), OL)
    vline(r, ex + 1, 0, max(2, by - 4), c("gray4"))
    hk = bx + bw // 2 - 2
    vline(r, hk, 2, max(3, by - 12), c("gray5"))
    px(r, hk - 1, by - 9, c("gray5"))
    px(r, hk + 1, by - 9, c("gray5"))
    # gauges (top right), lamp (top left)
    orect(r, w - 8, 5, 7, 11, c("gray1"), OL)
    ellipse(r, w - 7, 6, 5, 5, c("cream3"))
    hot = state == "hot"
    line(r, w - 5, 8, w - 3 if hot else w - 6, 7, OL)
    px(r, w - 6, 13, c("toxic3") if state != "idle" else c("gray3"))
    px(r, w - 4, 13, c("red3" if hot or state == "broken" else "gray3"))
    if hot:
        light_radial(r, w - 4, 13, 5, c("red3"), 0.5)
    rect(r, 7, 2, 4, 2, c("lamp1"))
    light_cone(r, 5, 4, 4, 16, min(30, h - 10), c("lamp1"), 0.15)
    if h >= 44:
        hline(r, w - 8, 19, 7, c("wood2"))
        for i in range(3):
            vline(r, w - 7 + i * 2, 20, 5, c("gray5"))
    orect(r, w - 7, h - 15, 5, 9, c("red1"), OL)
    if cfg["engine"] == "genset":
        hline(r, 0, 26, w, c("gray4"))
        for xx in range(2, w, 6):
            vline(r, xx, 26, 5, c("gray3"))
    rect(r, 0, h - 6, w, 6, c("gray2"))
    for xx in range(0, w, 3):
        vline(r, xx, h - 5, 4, c("gray1"))
    for xx in range(0, w, 6):
        rect(r, xx, h - 2, 3, 2, c("yellow2"))
    puffs = {"hot": "cream3", "broken": "gray3"}.get(state)
    if puffs:
        for i in range(6):
            rr = rng.randint(2, 3)
            ellipse(r, bx + rng.randint(-2, bw - 2), max(3, by - 14) + rng.randint(0, 10), rr * 2, rr * 2, c(puffs, 200))
    frame(r, 0, 0, w, h, OL)
    return r


def cut_cab(img, tier):
    """open the cab's bottom floor: paint trim around the hole and clear it (the cab_* interior shows through)"""
    cfg = CAB[tier]
    x, y, w, h = cfg["rect"]
    t = cfg["trim"]
    hi = {"blue": "blue4", "yellow": "yellow3", "red": "red4", "gray": "gray5"}[t]
    lo = {"blue": "blue1", "yellow": "yellow1", "red": "red1", "gray": "gray2"}[t]
    rect(img, x - 1, y - 2, w + 2, 2, c(hi))
    hline(img, x - 1, y - 2, w + 2, OL)
    if t == "yellow":                   # bus: hazard band over the opening
        for xx in range(x, x + w, 4):
            rect(img, xx, y - 2, 2, 2, OL)
    vline(img, x + w, y, h, c(lo))
    if t == "gray":                     # riveted locomotive frame
        for yy in range(y, y + h, 4):
            px(img, x + w, yy, c("gray5"))
    rect(img, x, y, w, h, CLEAR)
    if tier != "train":                 # the headlight stays on the nose
        rect(img, 0, y + 6, 2, 6, c("lamp1"))
        px(img, 0, y + 6, c("lamp2"))


# ------------------------------------------------------------------ engine type pictures (56x40)
def _eng_diesel4():
    im = new(56, 40)
    orect(im, 8, 14, 40, 20, c("blue2"), OL)
    hline(im, 9, 15, 38, c("blue4"))
    for i in range(4):
        orect(im, 11 + i * 9, 8, 7, 7, c("gray4"), OL)
        hline(im, 12 + i * 9, 9, 5, c("gray6"))
    orect(im, 4, 18, 5, 10, c("gray3"), OL)
    rect(im, 14, 34, 28, 3, c("gray1"))
    for i in range(4):
        px(im, 13 + i * 9, 30, c("orange1"))
    ellipse(im, 44, 2, 6, 5, c("gray2"))
    ellipse(im, 47, 0, 5, 4, c("gray1"))
    return im


def _eng_v8():
    im = new(56, 40)
    poly(im, [(6, 16), (16, 8), (28, 18), (40, 8), (50, 16), (50, 34), (6, 34)], OL)
    poly(im, [(7, 17), (16, 9), (28, 19), (40, 9), (49, 17), (49, 33), (7, 33)], c("red2"))
    line(im, 8, 17, 16, 10, c("red4"))
    line(im, 30, 18, 40, 10, c("red4"))
    ellipse(im, 17, 1, 22, 9, OL)
    ellipse(im, 18, 2, 20, 7, c("gray5"))
    hline(im, 20, 4, 16, c("gray6"))
    for i in range(4):
        px(im, 10 + i * 3, 26, c("gray5"))
        px(im, 36 + i * 3, 26, c("gray5"))
    rect(im, 12, 34, 32, 3, c("gray1"))
    for i in range(4):
        orect(im, 8 + i * 11, 36, 4, 3, c("orange2"), OL)
    return im


def _eng_turbo6():
    im = new(56, 40)
    orect(im, 4, 14, 38, 20, c("gray3"), OL)
    hline(im, 5, 15, 36, c("gray5"))
    orect(im, 4, 9, 38, 6, c("teal2"), OL)
    for i in range(6):
        px(im, 7 + i * 6, 11, c("teal3"))
    ellipse(im, 40, 14, 14, 14, OL)
    ellipse(im, 41, 15, 12, 12, c("gray4"))
    ellipse(im, 44, 18, 6, 6, c("orange2"))
    px(im, 46, 20, c("lamp1"))
    rect(im, 44, 8, 3, 7, c("gray4"))
    rect(im, 8, 34, 30, 3, c("gray1"))
    return im


def _eng_woodgas():
    im = new(56, 40)
    orect(im, 6, 2, 16, 34, c("gray2"), OL)
    for yy in (8, 18, 28):
        hline(im, 7, yy, 14, c("gray4"))
    orect(im, 10, 22, 8, 8, c("dusk1"), OL)
    rect(im, 11, 23, 6, 6, c("dusk3"))
    px(im, 13, 25, c("lamp2"))
    light_radial(im, 14, 26, 9, c("orange3"), 0.35)
    rect(im, 21, 6, 12, 3, c("orange1"))
    vline(im, 32, 6, 14, c("orange1"))
    orect(im, 26, 18, 26, 16, c("green2"), OL)
    hline(im, 27, 19, 24, c("green4"))
    orect(im, 28, 13, 10, 6, c("gray3"), OL)
    ellipse(im, 2, 0, 7, 6, c("gray1"))
    ellipse(im, 0, 4, 6, 5, c("gray2"))
    return im


def _eng_electric():
    im = new(56, 40)
    for i in range(3):
        orect(im, 4 + i * 11, 20, 10, 15, c("gray2"), OL)
        hline(im, 5 + i * 11, 21, 8, c("gray4"))
        px(im, 8 + i * 11, 25, c("toxic3" if i < 2 else "red3"))
    orect(im, 38, 12, 14, 20, c("blue3"), OL)
    for yy in range(14, 30, 3):
        hline(im, 39, yy, 12, c("blue1"))
    rect(im, 52, 20, 3, 4, c("gray5"))
    line(im, 10, 19, 38, 14, c("orange2"))
    line(im, 30, 19, 38, 17, c("orange2"))
    light_radial(im, 12, 25, 7, c("toxic3"), 0.2)
    return im


def _eng_hybrid():
    im = new(56, 40)
    orect(im, 3, 12, 28, 22, c("yellow1"), OL)
    hline(im, 4, 13, 26, c("yellow2"))
    for i in range(3):
        rect(im, 6 + i * 8, 17, 5, 2, c("ol1"))
    orect(im, 31, 14, 10, 18, c("teal1"), OL)
    vline(im, 33, 16, 14, c("teal3"))
    orect(im, 42, 20, 11, 14, c("gray2"), OL)
    px(im, 47, 24, c("toxic3"))
    line(im, 36, 13, 47, 19, c("orange2"))
    orect(im, 8, 4, 4, 9, c("gray3"), OL)
    return im


def _eng_turbine():
    im = new(56, 40)
    poly(im, [(4, 10), (40, 13), (52, 16), (52, 28), (40, 31), (4, 34)], OL)
    poly(im, [(5, 11), (40, 14), (51, 17), (51, 27), (40, 30), (5, 33)], c("gray4"))
    hline(im, 6, 13, 34, c("gray6"))
    ellipse(im, 1, 11, 10, 22, OL)
    ellipse(im, 2, 12, 8, 20, c("gray2"))
    for yy in range(14, 31, 3):
        hline(im, 3, yy, 6, c("gray5"))
    for xx in (16, 24, 32):
        vline(im, xx, 13, 19, c("gray3"))
    light_radial(im, 52, 22, 10, c("orange3"), 0.5)
    rect(im, 51, 19, 3, 6, c("lamp2"))
    return im


def _eng_fusion():
    im = new(56, 40)
    orect(im, 10, 6, 36, 30, c("gray2"), OL)
    for xx in (10, 45):
        vline(im, xx, 6, 30, c("gray4"))
    ellipse(im, 18, 11, 20, 20, OL)
    ellipse(im, 19, 12, 18, 18, c("toxic1"))
    ellipse(im, 23, 16, 10, 10, c("toxic3"))
    px(im, 27, 19, c("lamp2"))
    light_radial(im, 28, 21, 18, c("toxic3"), 0.4)
    rect(im, 4, 18, 6, 5, c("yellow3"))
    for i in range(3):
        px(im, 5 + i * 2, 20, OL)
    return im


ENGINES = {"diesel4": _eng_diesel4, "v8": _eng_v8, "turbo6": _eng_turbo6, "woodgas": _eng_woodgas,
           "electric": _eng_electric, "hybrid": _eng_hybrid, "turbine": _eng_turbine, "fusion": _eng_fusion}


def gen_engine_bay():
    for tier in CAB:
        for st in STATES:
            add(f"cab_{tier}_{st}", cab_room(tier, st))
    for k, fn in ENGINES.items():
        add(f"eng_{k}", fn())
