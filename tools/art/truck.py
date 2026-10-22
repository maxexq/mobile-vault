"""The Mobile Vault truck: grim 16-bit rust-bucket (cut-away side view, faces LEFT).

Geometry (shared with scripts/world/vehicle.gd — keep in sync), given for the 4-floor shell:
  sprite 280x300, roof slab top y=36, rooms 64x52 (three per floor) at cols x=44/118/184,
  floors (bottom=0) at y = 210 - 56*f, ladder shaft x=108..117, cab x=0..37, rear deck x=254..278 (floor y=262),
  wheels (32x32) centred at (22,284) (182,284) (222,284).
Taller chassis (5 / 6 floors) add 56px on top: truck_shell_N is 300 + 56*(N-4) tall and is placed at
y = -56*(N-4), so everything below the roof keeps its coordinates.

Exterior mods are separate overlay sprites (mod_*) positioned by Vehicle so upgrades show on the truck.
"""
import math, random
from .common import *

TW = 280
BASE_H = 300
FLOOR_H = 56
COLS = [44, 118, 184]
RW, RH = 64, 52
SHAFT = (108, 118)
BODY = (38, 254)
CHASSIS_Y = 262
WHEELS = [(22, 284), (182, 284), (222, 284)]
DECK_Y = 262
rt = random.Random(4242)

HULL = "orange"     # main body plating ramp
CAB = "red"


def row_y(fb, dy):
    return 210 - FLOOR_H * fb + dy


def bolts(img, x, y0, y1, step, col):
    for yy in range(y0, y1, step):
        px(img, x, yy, col)


def gen_shell(floors=4):
    dy = FLOOR_H * (floors - 4)
    TH = BASE_H + dy
    img = new(TW, TH)
    x0, x1 = BODY
    roof = 36
    cy = CHASSIS_Y + dy
    # ---------------- body block
    rect(img, x0, roof, x1 - x0, cy - roof, c(HULL + "1"))
    for wx in (x0, x1 - 6):
        rect(img, wx, roof, 6, cy - roof, c(HULL + "2"))
        vline(img, wx, roof, cy - roof, OL)
        vline(img, wx + 1, roof, cy - roof, c(HULL + "3"))
        vline(img, wx + 4, roof, cy - roof, c(HULL + "1"))
        vline(img, wx + 5, roof, cy - roof, OL)
        bolts(img, wx + 2, roof + 9, cy, 8, c(HULL + "0"))
    # ---------------- roof slab (with a cream trim band)
    rect(img, x0 - 3, roof, x1 - x0 + 6, 7, OL)
    rect(img, x0 - 2, roof + 1, x1 - x0 + 4, 5, c(HULL + "2"))
    hline(img, x0 - 2, roof + 1, x1 - x0 + 4, c(HULL + "3"))
    hline(img, x0 - 2, roof + 4, x1 - x0 + 4, c("orange0"))
    hline(img, x0 - 2, roof + 5, x1 - x0 + 4, c(HULL + "1"))
    # ---------------- floor slabs between rows + chassis slab
    for fb in range(floors - 1):
        y = row_y(fb, dy) - 4
        rect(img, x0 + 6, y, x1 - x0 - 12, 4, c("gray4"))
        hline(img, x0 + 6, y, x1 - x0 - 12, c("gray5"))
        hline(img, x0 + 6, y + 3, x1 - x0 - 12, OL)
        for xx in range(x0 + 10, x1 - 6, 12):
            px(img, xx, y + 1, c("gray3"))
    rect(img, x0, cy, x1 - x0, 8, c("gray2"))
    hline(img, x0, cy, x1 - x0, c("gray4"))
    hline(img, x0, cy + 1, x1 - x0, c("gray3"))
    for xx in range(x0 + 3, x1, 6):
        px(img, xx, cy + 4, c("gray4"))
    hline(img, x0, cy + 7, x1 - x0, OL)
    # ---------------- ladder shaft
    sx0, sx1 = SHAFT
    sh = cy - roof - 6
    rect(img, sx0, roof + 6, sx1 - sx0, sh, c("night2"))
    vline(img, sx0, roof + 6, sh, OL)
    vline(img, sx1 - 1, roof + 6, sh, OL)
    vline(img, sx0 + 2, roof + 6, sh, c("yellow1"))
    vline(img, sx1 - 3, roof + 6, sh, c("yellow1"))
    for yy in range(roof + 9, cy, 4):
        hline(img, sx0 + 2, yy, sx1 - sx0 - 4, c("yellow2"))
    # hatch stripes + little lamps at each level
    for fb in range(floors):
        y = row_y(fb, dy) - 4 if fb < floors - 1 else roof + 6
        for xx in range(sx0 + 1, sx1 - 1):
            px(img, xx, y + 1, c("yellow2") if (xx // 2) % 2 else OL)
        bx = (sx0 + sx1) // 2
        px(img, bx, y + 5, c("lamp2"))
        for k in range(-3, 4):
            tint_px(img, bx + k, y + 6, c("lamp1"), 0.35)
    # ---------------- room holes (1px dark frame)
    for cx in COLS:
        for fb in range(floors):
            ry = row_y(fb, dy)
            rect(img, cx - 1, ry - 1, RW + 2, RH + 2, OL)
            rect(img, cx, ry, RW, RH, CLEAR)
    # cute patches / stickers on the outer walls
    for (wx, wy) in ((x0 + 1, roof + 30), (x1 - 6, roof + 90)):
        rect(img, wx, wy, 5, 8, c("gray4"))
        frame(img, wx, wy, 5, 8, OL)
        px(img, wx + 1, wy + 1, c("gray6"))
        px(img, wx + 3, wy + 6, c("gray2"))

    # ---------------- cab (cab-over, faces left)
    top = 188 + dy
    by = cy + 8
    cab = [(0, top + 8), (6, top), (37, top), (37, by), (0, by)]
    poly(img, cab, OL)
    poly(img, [(1, top + 8), (6, top + 1), (36, top + 1), (36, by - 1), (1, by - 1)], c(CAB + "2"))
    hline(img, 6, top + 1, 30, c(CAB + "3"))
    vline(img, 1, top + 8, by - top - 9, c(CAB + "3"))
    rect(img, 1, top + 36, 36, by - top - 37, c(CAB + "1"))
    hline(img, 1, top + 36, 36, OL)
    hline(img, 1, top + 37, 36, c(CAB + "1"))
    # roof light bar
    rect(img, 9, top - 4, 22, 4, OL)
    for i in range(4):
        rect(img, 10 + i * 5, top - 3, 4, 2, c("lamp1") if i % 2 else c("gray2"))
    # windshield + side window (with a tiny driver)
    poly(img, [(2, top + 9), (6, top + 3), (14, top + 3), (14, top + 26), (2, top + 26)], OL)
    poly(img, [(3, top + 9), (7, top + 4), (13, top + 4), (13, top + 25), (3, top + 25)], c("blue2"))
    line(img, 5, top + 22, 9, top + 8, c("gray6"))
    line(img, 8, top + 23, 12, top + 12, c("blue4"))
    rect(img, 16, top + 4, 19, 19, OL)
    rect(img, 17, top + 5, 17, 17, c("lamp0"))
    hline(img, 17, top + 5, 17, c("orange2"))
    ellipse(img, 21, top + 9, 9, 8, OL)
    ellipse(img, 22, top + 10, 7, 6, c("skin2"))
    rect(img, 21, top + 9, 9, 3, c("green2"))
    hline(img, 21, top + 12, 9, OL)
    px(img, 24, top + 14, OL)
    
    rect(img, 21, top + 17, 9, 5, c("green3"))
    frame(img, 21, top + 17, 9, 5, OL)
    # door + number plate + star sticker
    frame(img, 16, top + 25, 19, by - top - 27, c(CAB + "1"))
    rect(img, 30, top + 30, 4, 1, c("gray6"))
    digits = ["111.111", "1.1...1", "1.1..1.", "111..1."]   # "07"
    for j, row in enumerate(digits):
        for i, ch in enumerate(row):
            if ch == "1":
                px(img, 20 + i, top + 40 + j, c("gray6"))
    # headlight, grille, bumper
    rect(img, 0, top + 34, 6, 7, OL)
    rect(img, 1, top + 35, 4, 5, c("lamp1"))
    px(img, 1, top + 35, c("gray6"))
    rect(img, 0, top + 43, 5, 4, OL)
    rect(img, 1, top + 44, 3, 2, c("orange2"))
    rect(img, 0, top + 50, 8, 18, OL)
    rect(img, 1, top + 51, 6, 16, c("gray3"))
    for yy in range(top + 52, top + 67, 2):
        hline(img, 1, yy, 6, c("gray1"))
    rect(img, 0, by - 4, 18, 6, OL)
    rect(img, 1, by - 3, 16, 4, c("gray3"))
    hline(img, 1, by - 3, 16, c("gray4"))
    for k in range(0, 16, 4):
        poly(img, [(1 + k, by + 1), (3 + k, by - 3), (5 + k, by - 3), (3 + k, by + 1)], c("yellow2"))
    # exhaust stack behind the cab
    rect(img, 31, 150 + dy, 6, 40, OL)
    rect(img, 32, 150 + dy, 4, 40, c("gray4"))
    vline(img, 32, 150 + dy, 40, c("gray5"))
    rect(img, 30, 146 + dy, 8, 5, OL)
    rect(img, 31, 147 + dy, 6, 3, c("gray3"))
    for yy in range(158 + dy, 188 + dy, 8):
        hline(img, 32, yy, 4, c("gray2"))
    # steps
    for i, yy in enumerate((cy + 2, cy + 6)):
        rect(img, 18 + i * 2, yy, 12, 3, OL)
        hline(img, 19 + i * 2, yy + 1, 10, c("gray5"))

    # ---------------- chassis frame / under-body
    rect(img, 2, by, 272, 6, OL)
    rect(img, 3, by + 1, 270, 4, c("gray2"))
    hline(img, 3, by + 1, 270, c("gray3"))
    # fuel tank + tool box
    rect(img, 58, by + 2, 54, 12, OL)
    rect(img, 59, by + 3, 52, 10, c("gray4"))
    hline(img, 59, by + 3, 52, c("gray5"))
    for xx in (70, 86, 100):
        vline(img, xx, by + 3, 10, c("gray3"))
    rect(img, 114, by + 2, 20, 10, OL)
    rect(img, 115, by + 3, 18, 8, c("blue2"))
    hline(img, 115, by + 3, 18, c("blue3"))
    rect(img, 122, by + 5, 4, 2, c("gray6"))
    # wheel wells (transparent so the wheels show underneath) + fenders
    for (wx, wy0) in WHEELS:
        wy = wy0 + dy
        ellipse(img, wx - 19, wy - 19, 39, 39, OL)
        ellipse(img, wx - 17, wy - 17, 35, 35, CLEAR)
        rect(img, wx - 19, wy, 39, 20, CLEAR)
    for (wx, wy0) in WHEELS:
        wy = wy0 + dy
        for a in range(196, 345, 2):
            ang = math.radians(a)
            for r, col in ((20, OL), (19, c("gray3")), (18, c("gray4"))):
                px(img, round(wx + r * math.cos(ang)), round(wy + r * math.sin(ang)), col)
    rect(img, 242, by + 6, 4, 12, OL)
    rect(img, 243, by + 7, 2, 10, c("gray1"))
    # ---------------- rear deck + railing + ladder + side turret mount
    dk = DECK_Y + dy
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
    for xx in (x1, x1 + 5):
        vline(img, xx, roof - 8, dk - roof + 6, c("gray4"))
    for yy in range(roof - 6, dk - 2, 5):
        hline(img, x1, yy, 6, c("gray5"))
    my = row_y(2, dy) + 26
    rect(img, x1, my, 18, 4, OL)
    hline(img, x1, my + 1, 17, c("gray5"))
    hline(img, x1, my + 2, 17, c("gray3"))
    line(img, x1, my + 12, x1 + 12, my + 4, OL)
    # a few vines/flowers for charm
    for x in (x0 + 2, x0 + 4):
        for k in range(rt.randint(6, 16)):
            px(img, x + (k // 3) % 2, roof + 7 + k, c("green2") if k % 3 else c("green3"))
    
    return img


def weather(img, seed=7):
    """rust blooms, grime streaks under every bolt line, soot toward the chassis"""
    rng = random.Random(seed)
    w, h = img.size
    src = img.copy()
    for _ in range(int(w * h / 260)):
        x, y = rng.randint(0, w - 1), rng.randint(0, h - 1)
        p = src.getpixel((x, y))
        if p[3] == 0 or p[:3] == OL[:3]:
            continue
        r = rng.randint(1, 3)
        for yy in range(y - r, y + r + 1):
            for xx in range(x - r, x + r + 1):
                q = get(img, xx, yy)
                if q[3] and q[:3] != OL[:3] and math.hypot(xx - x, yy - y) <= r and rng.random() < 0.7:
                    px(img, xx, yy, blend(q, c(rng.choice(["orange1", "orange2", "wood1"])), 0.55))
    for _ in range(int(w / 3)):
        x, y = rng.randint(0, w - 1), rng.randint(0, h - 1)
        for k in range(rng.randint(4, 18)):
            q = get(img, x, y + k)
            if q[3] and q[:3] != OL[:3]:
                px(img, x, y + k, blend(q, c("ol0"), 0.32 - k * 0.015))
    for y in range(h):
        t = max(0.0, (y - h * 0.55) / (h * 0.45))
        for x in range(w):
            q = get(img, x, y)
            if q[3] and t > 0 and bayer(x, y) < t * 0.8:
                px(img, x, y, blend(q, c("ol0"), 0.18))
    return img


def gen_roof_props(floors=4):
    """everything that stands on the roof (drawn into the shell's top 36px)"""
    img = new(TW, 38)
    by = 36
    # planter boxes with veggies
    for bx in (40, 54):
        rect(img, bx, by - 6, 13, 6, OL)
        rect(img, bx + 1, by - 5, 11, 4, c("wood2"))
        hline(img, bx + 1, by - 5, 11, c("wood3"))
        for k in range(0, 11, 3):
            h = 4 + (k * 7) % 5
            vline(img, bx + 2 + k, by - 6 - h, h, c("green1"))
            ellipse(img, bx + k, by - 8 - h, 5, 4, OL)
            ellipse(img, bx + 1 + k, by - 7 - h, 3, 2, c("green3"))
            if k % 2 == 0:
                px(img, bx + 2 + k, by - 5 - h // 2, c("red2"))
    # sunflower
    vline(img, 51, by - 22, 16, c("green2"))
    ellipse(img, 47, by - 27, 9, 9, OL)
    ellipse(img, 48, by - 26, 7, 7, c("yellow1"))
    ellipse(img, 50, by - 24, 3, 3, c("wood1"))
    # solar mounts
    for mx in (78, 104):
        rect(img, mx, by - 10, 3, 10, OL)
        vline(img, mx + 1, by - 10, 10, c("gray4"))
        rect(img, mx - 3, by - 2, 9, 2, OL)
    # shaft hatch + antenna mast with a tattered flag
    rect(img, 104, by - 4, 18, 4, OL)
    rect(img, 105, by - 3, 16, 3, c("gray4"))
    rect(img, 109, by - 6, 8, 2, c("gray3"))
    vline(img, 113, 2, by - 8, OL)
    vline(img, 114, 2, by - 8, c("gray4"))
    poly(img, [(115, 4), (126, 5), (122, 7), (125, 9), (115, 10)], c("red1"), OL)
    # water tank on legs + satellite dish on top
    tx, ty, tw, th = 150, by - 20, 32, 14
    for lx in (tx + 3, tx + tw - 5):
        rect(img, lx, ty + th, 3, by - ty - th, OL)
    rect(img, tx, ty, tw, th, OL)
    rect(img, tx + 1, ty + 1, tw - 2, th - 2, c("teal1"))
    rect(img, tx + 1, ty + 1, tw - 2, 3, c("teal2"))
    for bx in (tx + 8, tx + 16, tx + 24):
        vline(img, bx, ty + 1, th - 2, c("blue2"))
    for k in range(3):
        rect(img, tx + 10 + k * 5, ty + 6, 3, 4, c("cream1"))
    ellipse(img, 158, ty - 12, 12, 12, OL)
    ellipse(img, 159, ty - 11, 10, 10, c("gray5"))
    ellipse(img, 161, ty - 9, 6, 6, c("gray4"))
    line(img, 164, ty - 6, 170, ty - 10, OL)
    px(img, 170, ty - 10, c("red2"))
    vline(img, 164, ty - 2, 3, OL)
    # sandbag nest for the roof gunner
    for (sx, sy) in ((228, by - 6), (237, by - 6), (246, by - 6), (232, by - 10), (241, by - 10)):
        ellipse(img, sx, sy, 10, 6, OL)
        ellipse(img, sx + 1, sy + 1, 8, 4, c("sand2"))
        hline(img, sx + 2, sy + 1, 5, c("sand3"))
    # railings + clothes line
    for xx in (38, 255):
        vline(img, xx, by - 11, 11, OL)
    hline(img, 38, by - 11, 6, OL)
    hline(img, 249, by - 11, 7, OL)
    for x in range(130, 150):
        px(img, x, 22 + (x - 130) // 5, c("gray3"))
    rect(img, 132, 23, 3, 4, c("cream1"))
    vline(img, 129, 18, by - 18, OL)
    rect(img, 137, 24, 3, 5, c("blue3"))
    return img


def solar_frames():
    """5 tilt frames of the solar panel"""
    W, H = 24, 8
    face = new(W, H)
    rect(face, 0, 0, W, H, OL)
    for x in range(1, W - 1):
        for y in range(1, H - 1):
            px(face, x, y, c("blue2") if (x // 4 + y // 3) % 2 else c("blue3"))
    for x in range(4, W - 1, 4):
        vline(face, x, 1, H - 2, c("sky3"))
    hline(face, 1, 3, W - 2, c("sky3"))
    hline(face, 2, 1, 6, c("gray6"))
    out = []
    for ang in (-24, -12, 0, 12, 24):
        a = math.radians(ang)
        S = 30
        img = new(S, 20)
        cx, cy = S / 2, 12
        for y in range(20):
            for x in range(S):
                dx_, dy_ = x + 0.5 - cx, y + 0.5 - cy
                u = dx_ * math.cos(-a) - dy_ * math.sin(-a) + W / 2
                v = dx_ * math.sin(-a) + dy_ * math.cos(-a) + H / 2
                if 0 <= u < W and 0 <= v < H:
                    p = face.getpixel((int(u), int(v)))
                    if p[3]:
                        px(img, x, y, p)
        rect(img, int(cx) - 1, int(cy) + 2, 3, 3, OL)
        out.append(img)
    return out


def wheel_frames():
    out = []
    for f in range(4):
        w = new(32, 32)
        ellipse(w, 0, 0, 32, 32, OL)
        ellipse(w, 1, 1, 30, 30, c("gray1"))
        for k in range(12):
            a = (k / 12) * math.tau + f * math.tau / 48
            for rad in (13.5, 14.5):
                px(w, round(15.5 + rad * math.cos(a)), round(15.5 + rad * math.sin(a)), c("gray0"))
        ellipse(w, 7, 7, 18, 18, OL)
        ellipse(w, 8, 8, 16, 16, c("gray5"))
        ellipse(w, 9, 9, 13, 13, c("gray4"))
        for k in range(5):
            a = k / 5 * math.tau + f * (math.tau / 5) / 4
            px(w, round(15.5 + 5 * math.cos(a)), round(15.5 + 5 * math.sin(a)), c("gray2"))
        ellipse(w, 12, 12, 8, 8, OL)
        ellipse(w, 13, 13, 6, 6, c("orange1"))
        px(w, 14, 14, c("orange3"))
        for k in range(7):
            a = -math.pi * 0.85 + k * 0.1
            px(w, round(15.5 + 13 * math.cos(a)), round(15.5 + 13 * math.sin(a)), c("gray3"))
        out.append(w)
    return out


def turret_sprites():
    """side turrets 18x14 facing RIGHT (enemies chase from behind)"""
    for name, body, barrel in (("mg", "green", "gray1"), ("harpoon", "orange", "gray5"), ("tesla", "blue", "teal2")):
        t = new(18, 14)
        rect(t, 3, 9, 10, 5, OL)
        rect(t, 4, 10, 8, 3, c("gray3"))
        rect(t, 2, 3, 10, 7, OL)
        rect(t, 3, 4, 8, 5, c(body + "2"))
        hline(t, 3, 4, 8, c(body + "3"))
        px(t, 5, 6, OL)
        px(t, 8, 6, OL)
        if name == "mg":
            rect(t, 11, 5, 7, 3, OL)
            hline(t, 12, 6, 5, c("gray3"))
            rect(t, 4, 0, 5, 3, OL)
            hline(t, 5, 1, 3, c("yellow2"))
        elif name == "harpoon":
            rect(t, 11, 6, 5, 1, OL)
            poly(t, [(15, 4), (17, 6), (15, 8)], c("gray5"), OL)
            line(t, 2, 2, 8, 2, OL)
        else:
            vline(t, 12, 1, 7, OL)
            ellipse(t, 10, 0, 5, 5, OL)
            ellipse(t, 11, 1, 3, 3, c("teal3"))
            px(t, 16, 4, c("teal3"))
        add(f"turret_{name}", t)


# ================================================================== exterior mod overlays
def mod_spike_ram():
    """front plough on the cab bumper, 3 levels (28x34, anchor top-left at (-20, 242))"""
    for lv in (1, 2, 3):
        img = new(28, 34)
        poly(img, [(27, 2), (27, 33), (8, 33), (4, 26), (12, 10), (18, 2)], OL)
        poly(img, [(26, 3), (26, 32), (9, 32), (5, 26), (13, 11), (19, 3)], c("gray4"))
        line(img, 13, 12, 19, 4, c("gray6"))
        line(img, 6, 26, 12, 13, c("gray5"))
        for k in range(4):
            y = 31 - k * 7
            poly(img, [(10 + k * 2, y), (15 + k * 2, y), (12 + k * 2, y - 4)], c("yellow2"))
        n = lv + 2
        for k in range(n):
            y = 6 + k * (24 // n)
            x = 17 - (y - 4) // 3 if y < 12 else 6 + max(0, 26 - y) // 3
            ln = 5 + lv * 2
            poly(img, [(x, y), (max(0, x - ln), y + 2), (x, y + 5)], c("gray6"), OL)
        if lv >= 2:
            for (bx, by) in ((22, 8), (22, 26)):
                px(img, bx, by, OL)
        if lv == 3:
            rect(img, 19, 14, 6, 6, OL)
            rect(img, 20, 15, 4, 4, c("red2"))
        add(f"mod_spike_ram_{lv}", img)


def mod_roof_turret():
    """roof auto-turret 22x18 (anchor: (174, roof-18)), barrel faces RIGHT (enemies chase from behind)"""
    for lv in (1, 2, 3):
        img = new(24, 18)
        rect(img, 4, 13, 14, 5, OL)
        rect(img, 5, 14, 12, 3, c("gray3"))
        ellipse(img, 3, 4, 14, 11, OL)
        ellipse(img, 4, 5, 12, 9, c(["green", "blue", "purple"][lv - 1] + "2"))
        hline(img, 6, 6, 8, c(["green", "blue", "purple"][lv - 1] + "3"))
        rect(img, 8, 8, 4, 2, c("teal3"))
        frame(img, 7, 7, 6, 4, OL)
        for b in range(min(lv, 2)):
            y = 7 + b * 3 - (1 if lv > 1 else 0)
            rect(img, 15, y, 9, 3, OL)
            hline(img, 16, y + 1, 7, c("gray4"))
        if lv == 3:
            poly(img, [(2, 2), (8, 0), (8, 6), (2, 6)], c("gray4"), OL)
        vline(img, 6, 0, 4, OL)
        px(img, 6, 0, c("red2"))
        add(f"mod_roof_turret_{lv}", img)


def mod_fuel_tank():
    """one spare fuel drum strapped to the front wall (16x22); Vehicle stacks one per level"""
    img = new(16, 22)
    rect(img, 1, 0, 13, 22, OL)
    rect(img, 2, 1, 11, 20, c("yellow2"))
    rect(img, 3, 1, 3, 20, c("yellow3"))
    vline(img, 12, 1, 20, c("yellow1"))
    for y in (5, 15):
        hline(img, 2, y, 11, OL)
    rect(img, 5, 8, 6, 5, c("red2"))
    frame(img, 5, 8, 6, 5, OL)
    px(img, 7, 10, c("gray6"))
    rect(img, 13, 3, 3, 2, OL)
    rect(img, 13, 17, 3, 2, OL)
    rect(img, 4, -1, 4, 2, OL)
    add("mod_fuel_tank", img)


def mod_tracks():
    """snow tracks replacing the two rear wheels: 84x38, centred at (170, 284); 4 animated frames"""
    W, H = 84, 38
    for f in range(4):
        img = new(W, H)
        # belt outline (stadium)
        ellipse(img, 0, 2, 36, 36, OL)
        ellipse(img, W - 36, 2, 36, 36, OL)
        rect(img, 18, 2, W - 36, 36, OL)
        ellipse(img, 1, 3, 34, 34, c("gray1"))
        ellipse(img, W - 35, 3, 34, 34, c("gray1"))
        rect(img, 18, 3, W - 36, 34, c("gray1"))
        # treads along the top and bottom (scroll with f)
        for x in range(18 + (f * 2) % 8, W - 18, 8):
            rect(img, x, 3, 4, 3, c("gray3"))
            rect(img, x - 2, H - 4, 4, 3, c("gray3"))
        # inner frame + road wheels
        rect(img, 12, 12, W - 24, 16, OL)
        rect(img, 13, 13, W - 26, 14, c("orange2"))
        hline(img, 13, 13, W - 26, c("orange3"))
        for k, wx in enumerate((6, 26, 46, 66)):
            ellipse(img, wx, 16, 13, 13, OL)
            ellipse(img, wx + 1, 17, 11, 11, c("gray4"))
            ellipse(img, wx + 4, 20, 5, 5, c("yellow2"))
            a = f * math.tau / 16 + k
            px(img, round(wx + 6 + 3 * math.cos(a)), round(22 + 3 * math.sin(a)), OL)
        add(f"mod_tracks_{f}", img)


def mod_armor():
    """bolted armour plates: wall strip (6x56 per floor) + cab plate (24x22)"""
    seg = new(8, 56)
    for y0 in (0, 28):
        rect(seg, 0, y0, 8, 27, OL)
        rect(seg, 1, y0 + 1, 6, 25, c("gray4"))
        vline(seg, 1, y0 + 1, 25, c("gray5"))
        for yy in (y0 + 3, y0 + 23):
            px(seg, 3, yy, c("gray2"))
            px(seg, 5, yy, c("gray2"))
    add("mod_armor_wall", seg)
    cab = new(26, 22)
    poly(cab, [(0, 0), (25, 0), (25, 21), (3, 21), (0, 17)], OL)
    poly(cab, [(1, 1), (24, 1), (24, 20), (4, 20), (1, 16)], c("gray4"))
    hline(cab, 1, 1, 24, c("gray5"))
    for (x, y) in ((4, 4), (20, 4), (4, 15), (20, 16)):
        px(cab, x, y, c("gray2"))
    for k in range(4):
        hline(cab, 7, 7 + k * 3, 11, c("gray3"))
    add("mod_armor_cab", cab)


def mod_solar_cover():
    """retractable hood above each solar panel (34x9)"""
    img = new(34, 9)
    poly(img, [(0, 8), (4, 0), (30, 0), (33, 8)], OL)
    poly(img, [(2, 7), (5, 1), (29, 1), (31, 7)], c("orange2"))
    for x in range(6, 30, 4):
        vline(img, x, 2, 5, c("orange1"))
    hline(img, 5, 1, 24, c("orange3"))
    add("mod_solar_cover", img)


def mod_rad_shield():
    """lead skirt along the chassis (180x10) with radiation emblems + cab door badge"""
    img = new(208, 10)
    rect(img, 0, 0, 208, 10, OL)
    rect(img, 1, 1, 206, 8, c("gray2"))
    hline(img, 1, 1, 206, c("gray3"))
    for x in range(10, 208, 40):
        ellipse(img, x, 1, 8, 8, c("yellow2"))
        ellipse(img, x + 3, 4, 2, 2, OL)
        for a in (90, 210, 330):
            r = math.radians(a)
            px(img, round(x + 3.5 + 2.6 * math.cos(r)), round(4.5 - 2.6 * math.sin(r)), OL)
    for x in range(4, 208, 6):
        px(img, x, 7, c("gray1"))
    add("mod_rad_shield", img)


def mod_rain_catcher():
    """tarp funnel above the roof water tank (40x16)"""
    img = new(40, 16)
    vline(img, 1, 3, 13, OL)
    vline(img, 38, 3, 13, OL)
    poly(img, [(0, 2), (39, 2), (23, 13), (16, 13)], OL)
    poly(img, [(2, 3), (37, 3), (22, 12), (17, 12)], c("teal2"))
    hline(img, 2, 3, 36, c("teal3"))
    for x in range(6, 34, 6):
        line(img, x, 4, 19 + (x - 20) // 6, 11, c("teal1"))
    rect(img, 18, 13, 4, 3, OL)
    px(img, 19, 6, c("sky3"))
    px(img, 25, 7, c("sky3"))
    add("mod_rain_catcher", img)


def mod_heater():
    """chimney with a warm glow for the heater mod (12x20)"""
    img = new(12, 20)
    rect(img, 2, 4, 8, 16, OL)
    rect(img, 3, 5, 6, 15, c("red1"))
    for y in range(7, 20, 4):
        hline(img, 3, y, 6, c("red0"))
    rect(img, 0, 0, 12, 5, OL)
    rect(img, 1, 1, 10, 3, c("gray3"))
    px(img, 5, 2, c("orange3"))
    add("mod_heater", img)


def gen_mods():
    mod_spike_ram()
    mod_roof_turret()
    mod_fuel_tank()
    mod_tracks()
    mod_armor()
    mod_solar_cover()
    mod_rad_shield()
    mod_rain_catcher()
    mod_heater()


def gen_truck():
    from . import vehicles
    vehicles.gen_vehicles()
    for i, f in enumerate(solar_frames()):
        add(f"solar_{i}", f)
    for i, f in enumerate(wheel_frames()):
        add(f"wheel_{i}", f)
    turret_sprites()
    gen_mods()
    # spikes on the rear bumper (vertical rack, 10x26)
    sp = new(10, 26)
    vline(sp, 0, 0, 26, OL)
    vline(sp, 1, 0, 26, c("gray3"))
    for i in range(6):
        poly(sp, [(1, 1 + i * 4), (9, 3 + i * 4), (1, 5 + i * 4)], c("gray5"), OL)
    add("spikes", sp)
