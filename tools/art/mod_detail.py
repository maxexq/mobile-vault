"""MV-566: finer exterior mod sprites (rivets, welds, chipped paint, rust drips, linked track shoes).

Each sprite keeps the size and anchor of its truck.py / extra.py original and is added as `<name>_fine`;
Vehicle picks it while the switch `mod_detail_fine` is on. Master palette only, binary alpha, top-left light.
"""
import math
import random
from .common import *

G = lambda i: c(f"gray{i}")


def rivet(im, x, y, head="gray6", shade=OL):
    """1px domed rivet: lit head + soot shadow down-right."""
    px(im, x, y, c(head))
    px(im, x + 1, y + 1, shade)


def bolt2(im, x, y):
    """2x2 hex bolt head."""
    px(im, x, y, G(6)); px(im, x + 1, y, G(4))
    px(im, x, y + 1, G(4)); px(im, x + 1, y + 1, G(2))


def streak(im, x, y, n, cols=("orange2", "orange1", "orange1", "orange0"), only=None):
    """rust drip running down from (x, y); only paints on opaque pixels (optionally of given colours)."""
    for k in range(n):
        p = get(im, x, y + k)
        if p[3] == 0 or (only and p not in only):
            break
        px(im, x, y + k, c(cols[min(k, len(cols) - 1)]))


# ------------------------------------------------------------------ spiked ram
def spike_ram(lv):
    rng = random.Random(100 + lv)
    im = new(28, 34)
    poly(im, [(27, 2), (27, 33), (8, 33), (4, 26), (12, 10), (18, 2)], OL)
    poly(im, [(26, 3), (26, 32), (9, 32), (5, 26), (13, 11), (19, 3)], G(4))
    # cold right-hand flange in shadow, dithered into the face
    for y in range(3, 33):
        for x in range(19, 27):
            if get(im, x, y) == G(4) and (x >= 23 or (x >= 21 and bayer(x, y) > 0.5)):
                px(im, x, y, G(3))
    vline(im, 26, 3, 30, G(2))
    # lit bevel along the cutting edge (top-left light)
    line(im, 13, 11, 19, 3, G(6)); line(im, 14, 11, 19, 4, G(5))
    line(im, 6, 26, 13, 12, G(6)); line(im, 7, 26, 13, 13, G(5))
    line(im, 6, 27, 9, 31, G(3))
    hline(im, 19, 3, 7, G(5))
    # welded plate seams: dark groove, bead dots, lit lip below
    for sy in (12, 23):
        for x in range(5, 26):
            if get(im, x, sy)[3] and get(im, x, sy) != OL and get(im, x - 1, sy) != (0, 0, 0, 0):
                px(im, x, sy, G(2) if x % 2 else G(1))
                if get(im, x, sy + 1)[3] and get(im, x, sy + 1) != OL:
                    px(im, x, sy + 1, G(5) if x < 21 else G(4))
    # worn hazard stripes on the lower blade, chipped to bare steel and rust
    for y in range(14, 32):
        for x in range(8, 21):
            p = get(im, x, y)
            if p not in (G(4), G(3)) or y in (23, 24):
                continue
            if ((x + y) // 3) % 2 == 0:
                col = c("yellow2") if x < 15 else c("yellow1")
                if ((x + y) % 3 == 0) and y < 23:
                    col = c("yellow3")
            else:
                col = c("ol1")
            r = rng.random()
            if r < 0.10:
                col = G(4)
            elif r < 0.15:
                col = c("orange1")
            px(im, x, y, col)
    # rivet column on the flange with rust weeping from each head
    for y in range(5, 31, 5):
        rivet(im, 23, y, "gray5", G(1))
        streak(im, 23, y + 2, 2 + (y % 3), only=(G(3), G(4)))
    # dents: lit rim over a dark pit
    for (x, y) in ((17, 7), (19, 18), (21, 28)):
        px(im, x, y, G(2)); px(im, x - 1, y - 1, G(6))
    # spikes: lit top flank, dark belly, welded root, dried blood on the tips
    n = lv + 2
    for k in range(n):
        y = 6 + k * (24 // n)
        x = 17 - (y - 4) // 3 if y < 12 else 6 + max(0, 26 - y) // 3
        ln = 5 + lv * 2
        poly(im, [(x, y), (max(0, x - ln), y + 2), (x, y + 5)], G(4), OL)
        tip = max(0, x - ln)
        line(im, x - 1, y + 1, tip + 1, y + 2, G(6))
        line(im, x - 1, y + 4, tip + 2, y + 3, G(2))
        for t in range(2):
            if get(im, tip + 1 + t, y + 2) != OL:
                px(im, tip + 1 + t, y + 2, c("red1") if t == 0 else c("red0"))
        for yy in range(y + 1, y + 5):
            px(im, x, yy, G(5) if yy % 2 else G(2))
    if lv >= 2:
        for (bx, by) in ((21, 7), (21, 25)):
            rect(im, bx - 1, by - 1, 4, 4, OL)
            bolt2(im, bx, by)
            streak(im, bx, by + 3, 3, only=(G(3), G(4), c("yellow1"), c("yellow2"), c("ol1")))
    if lv == 3:
        # caged warning lamp
        rect(im, 19, 14, 6, 6, OL)
        rect(im, 20, 15, 4, 4, c("red2"))
        px(im, 20, 15, c("red4")); px(im, 21, 15, c("red3")); px(im, 20, 16, c("red3"))
        hline(im, 20, 18, 4, c("red1")); px(im, 23, 17, c("red1"))
        vline(im, 22, 15, 4, G(3))
        px(im, 22, 15, G(5))
    return im


# ------------------------------------------------------------------ roof turret
def roof_turret(lv):
    hue = ["green", "blue", "purple"][lv - 1]
    H = lambda i: c(f"{hue}{i}")
    im = new(24, 18)
    # base ring mount
    rect(im, 4, 13, 14, 5, OL)
    rect(im, 5, 14, 12, 3, G(3))
    hline(im, 5, 14, 12, G(5))
    hline(im, 5, 16, 12, G(2))
    for x in (6, 10, 14):
        rivet(im, x, 15, "gray6", G(1))
    px(im, 16, 15, c("orange1")); px(im, 16, 16, c("orange0"))
    # dome: 3-step ramp, rim light top-left, panel line, soot on the belly
    ellipse(im, 3, 4, 14, 11, OL)
    ellipse(im, 4, 5, 12, 9, H(2))
    for y in range(5, 14):
        for x in range(4, 16):
            if get(im, x, y) == H(2):
                d = (x - 9.5) + (y - 9) * 1.2
                if d > 4:
                    px(im, x, y, H(1))
                elif d > 2.5 and bayer(x, y) > 0.5:
                    px(im, x, y, H(1))
                elif d < -4.5:
                    px(im, x, y, H(3))
    hline(im, 6, 5, 7, H(3)); px(im, 5, 6, H(3))
    hline(im, 6, 12, 8, H(0))
    px(im, 7, 12, G(1)); px(im, 12, 12, G(1))
    vline(im, 13, 6, 6, H(1)); px(im, 14, 7, H(3))
    # sensor visor with lit lens and glint
    frame(im, 7, 7, 6, 4, OL)
    rect(im, 8, 8, 4, 2, c("teal1"))
    px(im, 8, 8, c("teal3")); px(im, 9, 8, c("teal2")); px(im, 11, 9, c("teal0"))
    # barrels: lit top, dark belly, cooling holes, muzzle brake, soot at the mouth
    for b in range(min(lv, 2)):
        y = 7 + b * 3 - (1 if lv > 1 else 0)
        rect(im, 15, y, 9, 3, OL)
        hline(im, 16, y + 1, 7, G(4))
        for x in (17, 19):
            px(im, x, y + 1, G(2))
        px(im, 16, y + 1, G(6)); px(im, 18, y + 1, G(5))
        px(im, 21, y + 1, G(5)); px(im, 22, y + 1, G(1))
    # cable from the mount into the dome
    px(im, 4, 12, G(1)); px(im, 3, 13, OL)
    if lv == 3:
        # bolted gun shield, scratched
        poly(im, [(2, 2), (8, 0), (8, 6), (2, 6)], G(4), OL)
        line(im, 3, 2, 7, 1, G(6))
        px(im, 3, 4, G(6)); px(im, 4, 5, OL)
        px(im, 6, 3, G(2)); px(im, 5, 4, G(5))
        px(im, 7, 4, c("orange1"))
    vline(im, 6, 0, 4, OL)
    px(im, 6, 0, c("red3"))
    if lv < 3:
        px(im, 6, 1, c("red1"))
    return im


# ------------------------------------------------------------------ fuel drum
def fuel_tank():
    rng = random.Random(7)
    im = new(16, 22)
    rect(im, 1, 0, 13, 22, OL)
    # cylinder ramp: rim light, lit band, body, core shadow, reflected edge
    cols = {2: "yellow2", 3: "yellow3", 4: "yellow3", 5: "yellow2", 6: "yellow2", 7: "yellow2",
            8: "yellow2", 9: "yellow1", 10: "yellow1", 11: "yellow0", 12: "yellow1"}
    for x, n in cols.items():
        vline(im, x, 1, 20, c(n))
    for y in range(1, 21):
        if bayer(8, y) > 0.5:
            px(im, 8, y, c("yellow1"))
    # rolling hoops: lit lip, groove, shadow
    for y in (5, 15):
        hline(im, 2, y - 1, 11, c("yellow3")); px(im, 11, y - 1, c("yellow1")); px(im, 12, y - 1, c("yellow1"))
        hline(im, 2, y, 11, OL)
        hline(im, 2, y + 1, 11, c("yellow1")); px(im, 11, y + 1, c("yellow0")); px(im, 12, y + 1, c("yellow0"))
    # top chime + bung cap
    hline(im, 2, 1, 11, c("yellow1"))
    rect(im, 4, -1, 4, 2, OL)
    px(im, 5, 0, G(5)); px(im, 6, 0, G(3))
    # hazard label: flame pictogram on red, peeling corner
    rect(im, 5, 8, 6, 5, c("red2"))
    frame(im, 5, 8, 6, 5, OL)
    px(im, 7, 9, c("lamp0")); px(im, 7, 10, c("yellow3")); px(im, 8, 10, c("lamp0"))
    px(im, 6, 11, c("yellow3")); px(im, 7, 11, c("orange3")); px(im, 8, 11, c("yellow3"))
    px(im, 9, 9, c("red3")); px(im, 10, 12, c("cream1"))
    # dents, chips and rust weeping from the hoops
    px(im, 4, 18, c("yellow0")); px(im, 3, 17, c("yellow3"))
    for (x, y) in ((10, 3), (3, 12), (11, 18), (6, 19)):
        px(im, x, y, c("orange1"))
    for (x, y, n) in ((9, 6, 3), (4, 16, 3), (12, 6, 2), (7, 16, 4)):
        streak(im, x, y + 1, n, cols=("orange1", "orange1", "orange0"))
    for y in range(17, 21):
        for x in range(2, 13):
            if rng.random() < 0.18:
                px(im, x, y, c("sand1") if rng.random() < 0.5 else c("yellow0"))
    # spilled fuel stain down from the cap
    px(im, 7, 2, c("yellow0")); px(im, 7, 3, c("yellow1"))
    # ratchet straps to the wall bracket
    for sy in (3, 17):
        rect(im, 13, sy, 3, 2, OL)
        px(im, 14, sy, G(4)); px(im, 15, sy, G(2))
        px(im, 13, sy + 1, c("green1"))
    px(im, 14, 17, G(6))
    return im


# ------------------------------------------------------------------ snow tracks
def tracks(f):
    W, H = 84, 38
    im = new(W, H)
    ellipse(im, 0, 2, 36, 36, OL)
    ellipse(im, W - 36, 2, 36, 36, OL)
    rect(im, 18, 2, W - 36, 36, OL)
    ellipse(im, 1, 3, 34, 34, G(1))
    ellipse(im, W - 35, 3, 34, 34, G(1))
    rect(im, 18, 3, W - 36, 34, G(1))
    # inner belt face (darker, in shadow) with guide horns
    ellipse(im, 6, 8, 24, 24, G(0)); ellipse(im, W - 30, 8, 24, 24, G(0)); rect(im, 18, 8, W - 36, 24, G(0))
    # linked shoes: every belt pixel gets its link phase; dark groove between plates, lit upper run
    per = 2 * (W - 36) + math.pi * 16.5
    n = 28
    for y in range(H):
        for x in range(W):
            if get(im, x, y) != G(1):
                continue
            if 18 <= x <= W - 18:
                s = x - 18 if y < 20 else (W - 36) + math.pi * 16.5 + (W - 18 - x)
            elif x > W - 18:
                s = (W - 36) + 16.5 * (math.atan2(y - 20, x - (W - 18)) + math.pi / 2)
            else:
                a2 = math.atan2(y - 20, x - 18) % math.tau
                s = 2 * (W - 36) + math.pi * 16.5 + 16.5 * (a2 - math.pi / 2)
            ph = (s / per * n - f / 4) % 1
            if ph < 0.25:
                px(im, x, y, G(0))
            elif y < 20:
                px(im, x, y, G(4) if (ph < 0.5 and y < 12) else G(3))
            else:
                px(im, x, y, G(2))
    # packed snow and grit caught in the lower run
    for x in range(20, W - 20, 7):
        xx = x + (f * 2) % 7
        if xx < W - 20:
            px(im, xx, 35, c("snow2")); px(im, xx + 1, 35, c("snow1"))
    # bogie frame: rust ramp, rivets, weld bead, mud splash
    rect(im, 12, 12, W - 24, 16, OL)
    rect(im, 13, 13, W - 26, 14, c("orange2"))
    hline(im, 13, 13, W - 26, c("orange3"))
    hline(im, 13, 14, W - 26, c("orange2"))
    rect(im, 13, 22, W - 26, 5, c("orange1"))
    for x in range(13, W - 13):
        if bayer(x, 21) > 0.5:
            px(im, x, 21, c("orange1"))
    hline(im, 13, 26, W - 26, c("orange0"))
    for x in range(16, W - 14, 6):
        rivet(im, x, 15, "orange3", c("orange0"))
    for x in range(14, W - 14, 9):
        streak(im, x + 2, 17, 4, cols=("orange1", "orange1", "orange0"))
    for x in range(14, W - 13, 3):
        px(im, x, 25, c("sand1") if x % 2 else c("sand0"))
    px(im, 30, 24, c("snow2")); px(im, 55, 24, c("snow2")); px(im, 56, 25, c("snow1"))
    # road wheels: rim light top-left, shadow bottom-right, rotating lug bolts
    for k, wx in enumerate((6, 26, 46, 66)):
        ellipse(im, wx, 16, 13, 13, OL)
        ellipse(im, wx + 1, 17, 11, 11, G(4))
        for y in range(17, 28):
            for x in range(wx + 1, wx + 12):
                if get(im, x, y) == G(4):
                    d = (x - wx - 6) + (y - 22)
                    if d >= 5:
                        px(im, x, y, G(2))
                    elif d >= 3:
                        px(im, x, y, G(3))
                    elif d <= -6:
                        px(im, x, y, G(5))
        px(im, wx + 3, 18, G(6)); px(im, wx + 2, 19, G(6))
        ellipse(im, wx + 3, 19, 7, 7, OL)
        ellipse(im, wx + 4, 20, 5, 5, c("yellow2"))
        px(im, wx + 5, 20, c("yellow3")); px(im, wx + 4, 21, c("yellow3"))
        px(im, wx + 7, 23, c("yellow1")); px(im, wx + 8, 22, c("yellow1"))
        px(im, wx + 6, 22, OL)
        for j in range(3):
            a = f * math.tau / 12 + k + j * math.tau / 3
            px(im, round(wx + 6 + 4 * math.cos(a)), round(22 + 4 * math.sin(a)), G(1))
    return im


# ------------------------------------------------------------------ armour pillar
def armor_wall():
    im = new(8, 56)
    for i, y0 in enumerate((0, 28)):
        rect(im, 0, y0, 8, 27, OL)
        rect(im, 1, y0 + 1, 6, 25, G(4))
        vline(im, 1, y0 + 1, 25, G(5)); px(im, 1, y0 + 1, G(6)); hline(im, 1, y0 + 1, 5, G(5))
        vline(im, 6, y0 + 2, 24, G(3))
        hline(im, 2, y0 + 25, 5, G(3))
        for yy in (y0 + 3, y0 + 23):
            rivet(im, 2, yy, "gray6", G(2))
            rivet(im, 4, yy, "gray6", G(2))
        # cross weld seam
        for x in range(1, 7):
            px(im, x, y0 + 13, G(2) if x % 2 else G(3))
            px(im, x, y0 + 14, G(5) if x < 6 else G(4))
        # scratches, a bullet dent, rust weeping from the lower rivets
        line(im, 2, y0 + 7 + i * 3, 4, y0 + 9 + i * 3, G(5))
        px(im, 4, y0 + 18 - i * 2, G(1)); px(im, 3, y0 + 17 - i * 2, G(6)); px(im, 5, y0 + 19 - i * 2, G(3))
        streak(im, 3, y0 + 5, 3, cols=("orange1", "orange0"))
        for x in (2, 5):
            px(im, x, y0 + 25, c("orange1"))
        px(im, 5, y0 + 24, c("orange0"))
    return im


# ------------------------------------------------------------------ solar hood
def solar_cover():
    im = new(34, 9)
    poly(im, [(0, 8), (4, 0), (30, 0), (33, 8)], OL)
    poly(im, [(2, 7), (5, 1), (29, 1), (31, 7)], c("orange2"))
    # corrugation: each rib lit on the left, shaded on the right
    for x in range(5, 30):
        k = (x - 5) % 4
        col = ["orange3", "orange2", "orange1", "orange2"][k]
        for y in range(2, 8):
            if get(im, x, y) == c("orange2"):
                px(im, x, y, c(col))
    hline(im, 5, 1, 24, c("orange3"))
    hline(im, 3, 7, 28, c("orange0"))
    for x in range(4, 31):
        if get(im, x, 6)[3] and get(im, x, 6) != OL and bayer(x, 6) > 0.5:
            px(im, x, 6, c("orange1"))
    # holes eaten through, soot and drips
    px(im, 12, 4, OL); px(im, 13, 5, c("orange0"))
    px(im, 23, 3, OL)
    px(im, 18, 2, c("sand2")); px(im, 8, 3, c("sand2"))
    # hinge brackets and rivet row on the lip
    for x in (4, 28):
        rect(im, x, 4, 2, 3, G(2)); px(im, x, 4, G(5)); px(im, x + 1, 6, OL)
    for x in range(8, 28, 5):
        rivet(im, x, 1, "gray5", c("orange0"))
    return im


# ------------------------------------------------------------------ lead skirt
def rad_shield():
    rng = random.Random(3)
    im = new(208, 10)
    rect(im, 0, 0, 208, 10, OL)
    rect(im, 1, 1, 206, 8, G(2))
    hline(im, 1, 1, 206, G(4))
    hline(im, 1, 2, 206, G(3))
    hline(im, 1, 8, 206, G(1))
    # grime rising from the road
    for x in range(1, 207):
        if bayer(x, 7) > 0.4:
            px(im, x, 7, G(1))
        if rng.random() < 0.12:
            px(im, x, 8, c("sand0") if rng.random() < 0.6 else c("sand1"))
    # panel seams with lit lip, rivets top and bottom
    for x in range(26, 207, 26):
        vline(im, x, 1, 8, OL); vline(im, x + 1, 2, 6, G(4))
    for x in range(4, 207, 13):
        rivet(im, x, 2, "gray5", G(1))
        if rng.random() < 0.5:
            streak(im, x, 4, 2, cols=("orange1", "orange0"), only=(G(2), G(1)))
    # weathered trefoil placards
    for x in range(10, 208, 40):
        ellipse(im, x, 1, 8, 8, c("yellow2"))
        px(im, x + 2, 2, c("yellow3")); px(im, x + 1, 3, c("yellow3"))
        px(im, x + 6, 7, c("yellow1")); px(im, x + 7, 5, c("yellow1"))
        ellipse(im, x + 3, 4, 2, 2, OL)
        for a in (90, 210, 330):
            r = math.radians(a)
            px(im, round(x + 3.5 + 2.6 * math.cos(r)), round(4.5 - 2.6 * math.sin(r)), OL)
        if (x // 40) % 2:
            px(im, x + 7, 2, G(3)); px(im, x + 6, 1, G(3))
        else:
            px(im, x + 1, 7, c("orange1"))
    return im


# ------------------------------------------------------------------ rain funnel
def rain_catcher():
    im = new(40, 16)
    vline(im, 1, 3, 13, OL); vline(im, 38, 3, 13, OL)
    poly(im, [(0, 2), (39, 2), (23, 13), (16, 13)], OL)
    poly(im, [(2, 3), (37, 3), (22, 12), (17, 12)], c("teal2"))
    # sagging tarp: lit near the rim, darker into the throat
    for y in range(3, 13):
        for x in range(2, 38):
            if get(im, x, y) == c("teal2"):
                if y >= 9 or (y >= 8 and bayer(x, y) > 0.5):
                    px(im, x, y, c("teal1"))
    hline(im, 2, 3, 36, c("teal3"))
    for x in range(3, 37):
        if bayer(x, 4) > 0.6:
            px(im, x, 4, c("teal3"))
    # fold creases: dark valley with a lit ridge beside it
    for x in range(6, 34, 6):
        ex = 19 + (x - 20) // 6
        line(im, x, 4, ex, 11, c("teal0"))
        line(im, x - 1, 4, ex - 1, 10, c("teal3") if x < 20 else c("teal2"))
    # rope rim with knots at the posts
    for x in range(2, 38):
        px(im, x, 2, c("cream1") if x % 4 else c("cream0"))
    for x in (1, 38):
        px(im, x, 2, c("cream3")); px(im, x, 3, c("cream1"))
    # posts: lit edge
    px(im, 1, 4, G(4)); px(im, 38, 4, G(3))
    px(im, 1, 15, G(2)); px(im, 38, 15, G(2))
    # stitched canvas patch, pooled water, outlet collar
    rect(im, 8, 5, 4, 3, c("cream1")); px(im, 8, 5, c("cream2"))
    px(im, 12, 6, c("cream0")); px(im, 9, 7, c("cream0")); px(im, 11, 5, c("cream0"))
    px(im, 20, 11, c("sky3")); px(im, 19, 11, c("sky2")); px(im, 21, 10, c("sky2"))
    px(im, 25, 7, c("sky3")); px(im, 14, 6, c("sky2"))
    rect(im, 18, 13, 4, 3, OL)
    px(im, 19, 13, G(4)); px(im, 20, 13, G(3))
    px(im, 19, 14, G(2))
    return im


# ------------------------------------------------------------------ heavy shock
def shock(lv):
    coil = ["yellow", "red", "blue"][lv - 1]
    hi = {"yellow": 3, "red": 3, "blue": 4}[coil]
    im = new(8 + (lv - 1) * 2, 20)
    w = im.width
    m = w // 2
    # piston: chromed rod in a dark body
    rect(im, m - 1, 0, 3, 20, OL)
    vline(im, m, 0, 20, G(4))
    for y in range(2, 10):
        px(im, m, y, G(6) if y % 3 else G(5))
    for y in range(10, 18):
        px(im, m, y, G(3))
    # coil turns: helix strand stepping down left to right, lit on the left, cast shadow on the rod
    for y in range(3, 17, 3):
        for x in range(w):
            yy = y + (1 if x > m else 0)
            if x in (0, w - 1):
                px(im, x, yy, OL)
            else:
                k = hi if x <= 2 else (hi - 1 if x < w - 3 else hi - 2)
                px(im, x, yy, c(f"{coil}{k}"))
        px(im, m, y + 2, c(f"{coil}0"))
    # mounts: bolt eye with lit rim, grime on the lower cap
    for yy in (0, 18):
        rect(im, 0, yy, w, 2, G(3))
        hline(im, 0, yy, w, G(5))
        px(im, m, yy, OL); px(im, m - 1, yy, G(6)); px(im, w - 1, yy + 1, G(1))
    px(im, 1, 19, c("sand1")); px(im, w - 3, 19, c("sand0"))
    # dust boot ribs and an oily weep
    px(im, m, 17, G(1))
    px(im, m + 1, 11, c("ol1")); px(im, m + 1, 12, c("ol1"))
    return im


# ------------------------------------------------------------------ heater cowl
def heater():
    im = new(12, 20)
    rect(im, 2, 4, 8, 16, OL)
    rect(im, 3, 5, 6, 15, c("red1"))
    # running-bond bricks: lit top-left edges, mortar, a few scorched bricks
    for y in range(5, 20):
        row = (y - 5) // 3
        for x in range(3, 9):
            if (y - 5) % 3 == 2:
                px(im, x, y, c("red0"))
            elif (x + (2 if row % 2 else 0)) % 4 == 3:
                px(im, x, y, c("red0"))
            elif (y - 5) % 3 == 0:
                px(im, x, y, c("red2"))
    vline(im, 3, 5, 15, c("red2"))
    vline(im, 8, 5, 15, c("red0"))
    for (x, y) in ((4, 9), (6, 15)):
        px(im, x, y, c("red3"))
    for (x, y) in ((5, 12), (7, 6)):
        px(im, x, y, c("orange1"))
    # soot climbing the top bricks
    for y in range(5, 8):
        for x in range(3, 9):
            if bayer(x, y) > 0.55 + (y - 5) * 0.15:
                px(im, x, y, G(1))
    # steel band with bolt
    hline(im, 3, 13, 6, G(3)); px(im, 3, 13, G(5)); px(im, 7, 13, G(6)); px(im, 8, 13, G(2))
    # rain hat: lit lip, rivets, ember glow in the throat
    rect(im, 0, 0, 12, 5, OL)
    rect(im, 1, 1, 10, 3, G(3))
    hline(im, 1, 1, 10, G(5)); px(im, 1, 1, G(6))
    hline(im, 1, 3, 10, G(2))
    rivet(im, 2, 2, "gray5", G(1)); rivet(im, 9, 2, "gray5", G(1))
    px(im, 4, 2, c("orange3")); px(im, 5, 2, c("lamp0")); px(im, 6, 2, c("orange3")); px(im, 7, 2, c("orange2"))
    px(im, 5, 3, c("orange1"))
    px(im, 10, 2, c("orange1"))
    return im


def gen_mod_detail():
    out = {}
    for lv in (1, 2, 3):
        out[f"mod_spike_ram_{lv}"] = spike_ram(lv)
        out[f"mod_roof_turret_{lv}"] = roof_turret(lv)
        out[f"mod_shock_{lv}"] = shock(lv)
    out["mod_fuel_tank"] = fuel_tank()
    for f in range(4):
        out[f"mod_tracks_{f}"] = tracks(f)
    out["mod_armor_wall"] = armor_wall()
    out["mod_solar_cover"] = solar_cover()
    out["mod_rad_shield"] = rad_shield()
    out["mod_rain_catcher"] = rain_catcher()
    out["mod_heater"] = heater()
    for n, im in out.items():
        assert im.size == atlas_items[n].size, (n, im.size, atlas_items[n].size)
        add(n + "_fine", im, q=False)
    # MV-565 motion strips that replace a mod's whole texture, cut from the fine art with the same frame logic
    for lv in (1, 2, 3):
        base = out[f"mod_roof_turret_{lv}"]
        for f in range(4):
            im = base.copy()
            if f in (1, 2):
                for y in ([7] if lv == 1 else [6, 9]):
                    barrel = base.crop((15, y, 24, y + 3))
                    rect(im, 15, y, 9, 3, CLEAR)
                    rect(im, 15, y, 2, 3, c(["green2", "blue2", "purple2"][lv - 1]))
                    im.alpha_composite(barrel, (14, y))
            add(f"anim_ext_turret_lv{lv}_recoil_fine_{f}", im, q=False)
        base = out[f"mod_shock_{lv}"]
        for f in range(4):
            im = base.copy()
            if f in (1, 2):
                for y in (6, 9, 12):
                    strip = base.crop((0, y, base.width, y + 2))
                    rect(im, 0, y, base.width, 2, CLEAR)
                    vline(im, base.width // 2, y, 2, G(5))
                    im.alpha_composite(strip, (0, y + 1))
            add(f"anim_ext_shock_lv{lv}_fine_{f}", im, q=False)
    base = out["mod_rain_catcher"]
    for f in range(4):
        im = base.copy()
        if f == 1:
            for x, y in ((14, 8), (27, 7)):
                px(im, x, y, c("teal2")); px(im, x, y + 1, c("teal1"))
        add(f"anim_ext_catcher_hem_fine_{f}", im, q=False)
    base = out["mod_heater"]
    clean = base.copy()
    rect(clean, 0, 0, 12, 5, CLEAR)
    add("ext_base_mod_heater_fine", clean, q=False)
    for f in range(4):
        im = base.crop((0, 0, 12, 5))
        if f == 1:
            px(im, 10, 2, G(1)); px(im, 10, 3, G(3))
        add(f"anim_ext_heater_cap_fine_{f}", im, q=False)
