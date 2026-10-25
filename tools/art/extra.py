"""v4 content: mutated zombies, roaming mutant bosses, gore / brass particles, head-torch light cones,
off-road wheels + suspension mods, flak turret, supermarket landmark, pet events, rebirth story art.
All grim 16-bit, soot outlines, top-left key light. Enemies face LEFT (they chase the vehicle)."""
import math, random
from .common import *
from . import chars as C
from . import events as E
from . import landmarks as L

rx = random.Random(4040)


def _fin(img, hi=0.2, lo=0.35):
    return outline_alpha(C.auto_shade(img, hi, lo))


def _zombie_head(i, x, y, skin="green3", eye="red3"):
    ellipse(i, x, y, 7, 7, c(skin))
    px(i, x + 1, y + 3, c(eye))
    px(i, x + 3, y + 3, c(eye))
    hline(i, x + 1, y + 5, 3, c("ol1"))


# ================================================================== mutated zombies (2 frames each)
def en_walker(f):
    """plain road zombie the vehicle ploughs through (faces RIGHT, towards the oncoming cab)"""
    i = new(12, 20)
    _zombie_head(i, 3, 0, "green3", "yellow2")
    rect(i, 3, 7, 6, 7, c("blue2"))
    px(i, 5, 9, c("red1"))
    rect(i, 8, 8 + f, 4, 2, c("green3"))          # arms reaching forward
    rect(i, 3, 14, 2, 5 + f, c("gray2"))
    rect(i, 6, 14, 2, 6 - f, c("gray2"))
    return flip(_fin(i))


def en_runner(f):
    i = new(16, 18)
    _zombie_head(i, 1, 1 + f, "green2", "red3")
    poly(i, [(3, 7), (11, 6), (12, 12), (4, 12)], c("gray3"))
    line(i, 3, 8, 0, 12 - f * 2, c("green2"), 2)
    line(i, 10, 8, 14, 5 + f * 3, c("green2"), 2)
    line(i, 5, 12, 2 + f * 4, 17, c("gray1"), 2)
    line(i, 10, 12, 14 - f * 4, 17, c("gray1"), 2)
    px(i, 7, 9, c("red2"))
    return _fin(i)


# MV-183 (MV-178 creature redesign): Acid Spitter: lopsided head, throat sac (toxic only on its highlight and a 1 px droplet), hunched in ragged clothes.
# Drawn as text rows at native size, one character per pixel (".", empty); rows_sprite() adds the ol0 outline.
_EN_SPITTER_KEY = {'k': 'green0', 'g': 'green1', 'G': 'green2', 'h': 'green3', 'A': 'gray1', 'c': 'gray3', 'w': 'cream1', 't': 'toxic1', 'T': 'toxic3', 'y': 'yellow2'}
_EN_SPITTER = (
    (
        "................",
        "....kggk........",
        "...gGGGGg.......",
        "..gGyGGGhg..wwc.",
        ".gGGGGGGgcccwcc.",
        ".kGGkkGgcAccccc.",
        "T.ttTtkgccAcccc.",
        "..tttk.GcccAccA.",
        "...kk.G.ccAcccc.",
        "......G.cAcccAG.",
        ".....gG.cAcAccG.",
        ".....g..AcA.A.G.",
        ".....k.gG..gG.g.",
        ".......gG..gG...",
        ".......Gg..Gg...",
        ".......Gg..Gg...",
        ".......gk..gk...",
        ".......gk..gk...",
        "......kgk.kgk...",
        "......kk..kk....",
    ),
    (
        "................",
        "....kggk........",
        "...gGGGGg.......",
        "..gGyGGGhg..wwc.",
        ".gGGGGGGgcccwcc.",
        "..GGkkGgcAccccc.",
        ".kkttTkgccAcccc.",
        "T.ttk..GcccAccA.",
        "..ttk.G.ccAcccc.",
        "...k..G.cAcccAG.",
        ".....gG.cAcAccG.",
        ".....g..AcA.A.G.",
        ".....k..gG.gG.g.",
        "........gG.gG...",
        "........Gg.Gg...",
        ".......Gg..Gg...",
        ".......gk...gk..",
        ".......gk...gk..",
        "......kgk..kgk..",
        "......kk...kk...",
    ),
)


def en_spitter(f):
    return rows_sprite(_EN_SPITTER[f], _EN_SPITTER_KEY)


def en_bloater(f):
    i = new(20, 20)
    ellipse(i, 1, 4, 18, 14 + f, c("pink2"))
    ellipse(i, 4, 7, 10, 7, c("pink3"))
    for (x, y) in ((6, 9), (12, 13), (9, 15), (14, 8)):
        ellipse(i, x, y, 3, 3, c("toxic2"))
    _zombie_head(i, 6, 0, "pink1", "yellow2")
    rect(i, 5, 17, 3, 3, c("gray1"))
    rect(i, 12, 17, 3, 3, c("gray1"))
    return _fin(i, 0.15, 0.3)


def en_screecher(f):
    i = new(22, 14)
    if f:
        poly(i, [(5, 6), (10, 0), (13, 5)], c("purple1"))
        poly(i, [(10, 6), (19, 0), (21, 6)], c("purple2"))
    else:
        poly(i, [(5, 6), (10, 13), (13, 7)], c("purple1"))
        poly(i, [(10, 6), (19, 13), (21, 6)], c("purple2"))
    ellipse(i, 6, 4, 9, 6, c("gray3"))
    _zombie_head(i, 1, 3, "gray4", "red3")
    hline(i, 0, 7, 2, c("pink3"))
    return _fin(i)


# MV-184 (MV-178 creature redesign): Bone Brute: small sunken head, uneven bone-plated shoulders, one huge hanging fist, short legs.
# Drawn as text rows at native size, one character per pixel (".", empty); rows_sprite() adds the ol0 outline.
_EN_BRUTE_KEY = {'k': 'green0', 'g': 'green1', 'G': 'green2', 'h': 'green3', 'b': 'cream0', 'B': 'cream1', 'p': 'cream2', 'P': 'cream3', 'A': 'gray1', 'a': 'gray3', 'e': 'red2'}
_EN_BRUTE = (
    (
        "....................",
        "...PPPp.............",
        "..PPPPppb...........",
        "..PPpppBbkkk.pPPp...",
        ".hPpBBbbkhhGkPPpPpb.",
        ".hGpBbGGkehGkpPpBpG.",
        ".hGGbgGGkkGkGpBpBGG.",
        "hGGGgkGPPpPpGPpGGGg.",
        "hGGg.kGPpBbPPpBGkGg.",
        "hGGg.kGpPBpPpBbG.Gg.",
        "GGGg.kGGPpbBpPGg.Gg.",
        "hGGg.kGGGbPpBGGg.gG.",
        "GGGg..kGGGBpGGg..gG.",
        "GGGg..kAaaaaaaA..gg.",
        "hGGgg.AaaAaaAaaA....",
        "GGGGg..AaA..AaA.....",
        "hGGGg..GGg..GGg.....",
        "PPGGGg.GGg..GGg.....",
        "PpPGGg.GGg..GGg.....",
        "pPpGGg.GgG..GgG.....",
        "hGGGGg.Ggg..Ggg.....",
        "gGGGg..GGg..GGg.....",
        ".ggg..kGGg.kGGg.....",
        "......kkkk.kkkk.....",
    ),
    (
        "....................",
        "...............pPP..",
        "...PPPp......pPPpPp.",
        "..PPPPppbkkk.PPpBpb.",
        "..PPpppBbhhGkpPpBpG.",
        ".hPpBBbbkehGkGpBpGG.",
        ".hGpBbGGkkGkGPpGGGg.",
        ".hGGbgGPPpPpGPpGGGg.",
        "hGGGgkGPpBbPPpBGkGg.",
        "hGGg.kGpPBpPpBbG.Gg.",
        "hGGg.kGGPpbBpPGg.Gg.",
        "GGGg.kGGGbPpBGGg.gG.",
        "hGGg..kGGGBpGGg..gG.",
        "GGGg..kAaaaaaaA..gg.",
        "GGGgg.AaaAaaAaaA....",
        "hGGGg..AaA..AaA.....",
        "GGGGg..GGg..GGg.....",
        "hGGGg..GGg..GGg.....",
        "PPGGGg.GGg..GGg.....",
        "PpPGGg.GgG..GgG.....",
        "pPpGGg.Ggg..Ggg.....",
        "hGGGg..GGg..GGg.....",
        ".gggg.kGGg.kGGg.....",
        "......kkkk.kkkk.....",
    ),
)


def en_brute(f):
    return rows_sprite(_EN_BRUTE[f], _EN_BRUTE_KEY)


ENEMIES = {"walker": en_walker, "runner": en_runner, "spitter": en_spitter, "bloater": en_bloater,
           "screecher": en_screecher, "brute": en_brute}


# ================================================================== roaming mutant bosses (native size)
def boss_acid(f):
    img = new(40, 44)
    s = f
    ellipse(img, 4, 14, 32, 26, c("toxic1"))
    for (x, y, r) in ((8, 18, 8), (22, 22, 9), (14, 30, 7)):
        ellipse(img, x, y, r, r, c("toxic2"))
        px(img, x + r // 2, y + 1, c("toxic3"))
    ellipse(img, 2, 2 + s, 16, 15, c("green2"))
    ellipse(img, 0, 8 + s, 9, 8, c("toxic2"))            # swollen acid jaw
    px(img, 1, 10 + s, c("toxic3"))
    rect(img, 6, 6 + s, 2, 2, c("red3"))
    rect(img, 11, 6 + s, 2, 2, c("red3"))
    for k in range(4):
        vline(img, 8 + k * 7, 38, 6, c("green1"))
    return _fin(img)


def boss_bloat(f):
    img = new(44, 44)
    s = f
    ellipse(img, 2, 6 - s, 40, 34 + s, c("pink2"))
    ellipse(img, 8, 12, 24, 16, c("pink3"))
    for (x, y) in ((10, 16), (26, 22), (16, 30), (32, 12), (6, 26)):
        ellipse(img, x, y, 5, 5, c("toxic2"))
        px(img, x + 2, y + 2, c("toxic3"))
    _zombie_head(img, 16, 0, "pink1", "yellow2")
    rect(img, 9, 38, 6, 6, c("gray1"))
    rect(img, 28, 38, 6, 6, c("gray1"))
    rect(img, 0, 18 + s, 5, 12, c("pink1"))
    return _fin(img, 0.15, 0.3)


def boss_harpy(f):
    img = new(48, 30)
    s = f
    if s:
        poly(img, [(14, 12), (24, 0), (30, 11)], c("purple1"))
        poly(img, [(22, 12), (40, 0), (47, 12)], c("purple2"))
    else:
        poly(img, [(14, 12), (24, 28), (30, 13)], c("purple1"))
        poly(img, [(22, 12), (40, 28), (47, 12)], c("purple2"))
    ellipse(img, 12, 8, 20, 12, c("gray3"))
    ellipse(img, 2, 6, 13, 12, c("gray4"))
    poly(img, [(0, 12), (4, 10), (4, 14)], c("yellow2"))
    px(img, 6, 9, c("red3"))
    px(img, 9, 9, c("red3"))
    for k in range(3):
        line(img, 16 + k * 4, 19, 14 + k * 4, 25, c("gray2"))
    return _fin(img)


def boss_hulk(f):
    img = new(44, 48)
    s = f
    C._legs(img, [12, 26], 34, 14, c("green1"), s)
    ellipse(img, 4, 8, 36, 30, c("green2"))
    for (x, y, w) in ((6, 10, 14), (22, 9, 14), (10, 22, 22), (8, 30, 12)):
        rect(img, x, y, w, 4, c("cream3"))
        hline(img, x, y + 3, w, c("cream1"))
        px(img, x + 2, y + 1, c("cream2"))
    ellipse(img, 14, 0 + s, 14, 12, c("green2"))
    rect(img, 16, 2 + s, 10, 3, c("cream3"))            # bone mask
    px(img, 18, 3 + s, c("red3"))
    px(img, 23, 3 + s, c("red3"))
    ellipse(img, 0, 14 + s, 10, 22, c("green2"))
    ellipse(img, 34, 14 - s, 10, 20, c("green2"))
    return _fin(img)


def boss_worm(f):
    img = new(48, 40)
    s = f
    for k in range(5):
        ellipse(img, 8 + k * 7, 14 + abs(2 - k) * 3 - s, 14, 14, c("pink1") if k % 2 else c("pink2"))
    ellipse(img, 0, 6 + s, 18, 18, c("pink2"))
    ellipse(img, 2, 10 + s, 10, 10, c("night0"))          # drilling maw
    for a in range(0, 360, 45):
        r = math.radians(a)
        px(img, round(7 + 5 * math.cos(r)), round(15 + s + 5 * math.sin(r)), c("cream3"))
    rect(img, 4, 34, 40, 6, c("wood1"))                    # torn-up asphalt
    for x in range(4, 44, 6):
        rect(img, x, 32 - (x % 3), 4, 3, c("gray3"))
    return _fin(img)


def boss_screamer(f):
    img = new(30, 46)
    s = f
    rect(img, 8, 14, 14, 20, c("gray3"))
    for k in range(4):
        vline(img, 9 + k * 4, 16, 16, c("gray2"))
    ellipse(img, 6, 0, 18, 18, c("cream2"))
    ellipse(img, 10, 8 - s, 10, 9 + s * 2, c("night0"))     # screaming mouth
    px(img, 10, 4, c("red3"))
    px(img, 18, 4, c("red3"))
    if s:
        for r in (4, 7):
            for a in range(150, 210, 10):
                rr = math.radians(a)
                px(img, round(15 + (12 + r) * math.cos(rr)), round(12 + (12 + r) * math.sin(rr)), c("purple3"))
    rect(img, 2, 16 - s, 6, 14, c("gray2"))
    rect(img, 22, 16 + s, 6, 14, c("gray2"))
    rect(img, 9, 34, 4, 12, c("gray1"))
    rect(img, 17, 34, 4, 12, c("gray1"))
    return _fin(img)


def boss_priest(f):
    img = new(32, 46)
    s = f
    poly(img, [(6, 14), (26, 14), (31, 46), (1, 46)], c("red0"))
    for k in range(4):
        vline(img, 6 + k * 6, 18, 26, c("red1"))
    ellipse(img, 9, 2, 14, 14, c("cream2"))                # skull face under the hood
    poly(img, [(6, 10), (16, -1), (26, 10), (24, 16), (8, 16)], c("red1"))
    ellipse(img, 11, 6, 10, 10, c("cream2"))
    rect(img, 13, 9, 2, 2, c("toxic3"))
    rect(img, 17, 9, 2, 2, c("toxic3"))
    vline(img, 2, 6 - s, 38, c("wood1"))                    # bone staff
    ellipse(img, 0, 2 - s, 6, 6, c("cream3"))
    px(img, 2, 4 - s, c("toxic3"))
    return _fin(img)


def boss_spider(f):
    img = new(48, 34)
    s = f
    for k in range(4):
        x = 8 + k * 10
        dx = s if k % 2 else -s
        line(img, x + 4, 14, x - 4 + dx, 30, c("gray2"), 2)
        line(img, x + 4, 14, x + 10 - dx, 32, c("gray2"), 2)
    ellipse(img, 10, 4, 30, 18, c("gray4"))
    rect(img, 14, 10, 22, 4, c("yellow1"))
    for x in range(15, 36, 4):
        px(img, x, 11, OL)
    ellipse(img, 2, 6, 12, 10, c("gray3"))
    for (x, y) in ((4, 8), (8, 8), (6, 11)):
        px(img, x, y, c("red3"))
    rect(img, 38, 2, 6, 4, c("gray2"))                      # missile pod
    return _fin(img)


BOSSES = {"acid": boss_acid, "bloat": boss_bloat, "harpy": boss_harpy, "hulk": boss_hulk,
          "worm": boss_worm, "screamer": boss_screamer, "priest": boss_priest, "spider": boss_spider}


# ================================================================== FX
def gen_fx():
    # head-torch light cones (additive), 44x24, origin at the left-middle; 0 level, 1 up, 2 down
    for k, tilt in enumerate((0.0, -0.22, 0.25)):
        img = new(44, 24)
        for x in range(44):
            for y in range(24):
                dy = (y - 12) - tilt * x
                half = 2 + x * 0.32
                if abs(dy) <= half:
                    t = x / 44.0
                    edge = abs(dy) / half
                    v = (1.0 - t) * (1.0 - edge * 0.6)
                    if bayer(x, y) < v * 1.25:
                        px(img, x, y, c("lamp1") if v > 0.55 else c("lamp0") if v > 0.3 else c("dusk2"))
        add(f"fx_flashlight_{k}", img, q=False)
    # gore + brass
    p = new(2, 2); rect(p, 0, 0, 2, 2, c("red2")); px(p, 1, 1, c("red1")); add("pt_blood", p)
    p = new(3, 2); rect(p, 0, 0, 3, 2, c("red1")); px(p, 0, 0, c("pink2")); add("pt_gib", p)
    p = new(3, 1); rect(p, 0, 0, 3, 1, c("yellow2")); px(p, 2, 0, c("yellow3")); add("pt_casing", p)
    p = new(2, 1); rect(p, 0, 0, 2, 1, c("gray5")); add("pt_shard", p)
    p = new(3, 3); ellipse(p, 0, 0, 3, 3, c("toxic3")); px(p, 1, 1, c("toxic2")); add("pt_acid_glob", p)
    for k in range(3):
        img = new(12, 4)
        for _ in range(9 + k * 3):
            x, y = rx.randint(0, 11), rx.randint(1, 3)
            px(img, x, y, c(rx.choice(["red0", "red1", "red1", "red2"])))
        rect(img, 3, 2, 6, 2, c("red1"))
        add(f"fx_splat_{k}", img)
    # explosion puff frames
    for k in range(3):
        img = new(24, 24)
        r = 5 + k * 4
        ellipse(img, 12 - r, 12 - r, r * 2, r * 2, c("orange2") if k < 2 else c("gray3"))
        ellipse(img, 12 - r // 2, 12 - r // 2, r, r, c("lamp1") if k == 0 else c("orange3"))
        for _ in range(10):
            a = rx.random() * math.tau
            px(img, round(12 + (r + 1) * math.cos(a)), round(12 + (r + 1) * math.sin(a)), c("gray4"))
        add(f"fx_boom_{k}", img)


def gen_drivetrain():
    # off-road knobby wheels (same 32x32 footprint so they fit the wheel wells). MV-390: bigger 2px knob groups,
    # recessed six-lug yellow rim, rust hub; knobs advance tau/64 per frame (16 knobs = one period in 4 frames)
    def at(r, a, c0=15.5):
        return round(c0 + r * math.cos(a)), round(c0 + r * math.sin(a))

    for f in range(4):
        w = new(32, 32)
        ellipse(w, 0, 0, 32, 32, OL)
        ellipse(w, 1, 1, 30, 30, c("gray1"))
        for k in range(16):
            a = (k / 16) * math.tau + f * math.tau / 64
            # a knob: 2x2 block on the edge + a second row inside, lit edge on the inner side
            x, y = at(13.6, a, 15.0)
            rect(w, x, y, 2, 2, c("gray0"))
            x, y = at(11.6, a + 0.04, 15.0)
            rect(w, x, y, 2, 1, c("gray0"))
            px(w, *at(10.4, a + 0.2), c("gray2"))
        # fixed top-left highlight on the tyre shoulder
        for k in range(5):
            px(w, *at(13.0, -math.pi * 0.82 + k * 0.12), c("gray3"))
        ellipse(w, 8, 8, 16, 16, OL)
        ellipse(w, 9, 9, 14, 14, c("yellow1"))
        # recess: dark ring inside the paint, lower-right side deeper
        ellipse(w, 11, 11, 10, 10, c("gray0"))
        ellipse(w, 11, 11, 9, 9, c("gray3"))
        for k in range(6):
            a = k / 6 * math.tau + f * (math.tau / 6) / 4
            x, y = at(4.0, a)
            px(w, x, y, c("gray4"))
            if get(w, x + 1, y + 1)[:3] == c("gray3")[:3]:    # shadow only on the rim face, never on the paint
                px(w, x + 1, y + 1, OL)
        ellipse(w, 13, 13, 6, 6, OL)
        ellipse(w, 14, 14, 4, 4, c("orange1"))
        px(w, 16, 16, c("gray0"))
        add(f"bwheel_{f}", w)
    # heavy suspension: coil-over shock absorbers above each wheel, 3 levels (8x20)
    for lv in (1, 2, 3):
        img = new(8 + (lv - 1) * 2, 20)
        w = img.width
        rect(img, w // 2 - 1, 0, 3, 20, OL)
        vline(img, w // 2, 0, 20, c("gray4"))
        for y in range(3, 17, 3):
            hline(img, 0, y, w, OL)
            hline(img, 1, y, w - 2, c(["yellow2", "red2", "blue3"][lv - 1]))
        rect(img, 0, 0, w, 2, c("gray3"))
        rect(img, 0, 18, w, 2, c("gray3"))
        add(f"mod_shock_{lv}", img)
    # flak turret (18x14, faces RIGHT like the others)
    t = new(18, 14)
    rect(t, 3, 9, 10, 5, OL)
    rect(t, 4, 10, 8, 3, c("gray3"))
    rect(t, 2, 4, 10, 6, OL)
    rect(t, 3, 5, 8, 4, c("gray4"))
    for k in range(2):
        line(t, 10, 6 - k * 3, 17, 1 - k * 2 + 2, OL, 2)
        px(t, 16, 2 - k, c("gray5"))
    rect(t, 4, 6, 3, 2, c("red2"))
    add("turret_flak", t)


def lm_market():
    img = new(100, 100)
    B = 99
    L.bldg(img, 2, 34, 96, B - 34, "sand", 2)
    L.roof_edge(img, 2, 32, 96, "gray", 4)
    # big broken sign
    rect(img, 12, 14, 62, 16, OL)
    rect(img, 13, 15, 60, 14, c("red1"))
    for k, ch in enumerate((1, 1, 0, 1, 1, 1, 0, 1)):
        if ch:
            rect(img, 16 + k * 7, 18, 5, 8, c("cream3"))
    vline(img, 30, 30, 4, OL)
    vline(img, 60, 30, 4, OL)
    poly(img, [(74, 14), (86, 22), (74, 30)], c("red0"), OL)
    # shop front: shattered glass, shopping trolleys, stacked cans
    rect(img, 14, B - 34, 76, 34, OL)
    for k in range(5):
        rect(img, 15 + k * 15, B - 33, 14, 33, c("night1") if k % 2 else c("teal1"))
        line(img, 17 + k * 15, B - 30, 26 + k * 15, B - 18, c("teal2"))
    L.door(img, B, 14, 20, "gray")
    for x in (52, 66):
        rect(img, x, B - 9, 10, 5, OL)
        rect(img, x + 1, B - 8, 8, 3, c("gray4"))
        px(img, x + 1, B - 2, OL)
        px(img, x + 8, B - 2, OL)
    for (x, y) in ((80, B - 6), (84, B - 6), (82, B - 10)):
        rect(img, x, y, 4, 5, c("red2"))
        hline(img, x, y + 1, 4, c("cream3"))
    L.vines(img, 4, 36, 4, 24)
    L.rubble(img, B + 1, 70, 100)
    return img


def gen_events_extra():
    # cat in a wrecked car
    img = E.scene(E.DUSK, "gray2", skyline="purple1")
    rect(img, 50, 50, 50, 14, c("blue1"))
    rect(img, 60, 42, 30, 10, c("blue1"))
    rect(img, 64, 44, 10, 7, c("night1"))
    for x in (54, 88):
        ellipse(img, x, 60, 10, 10, c("gray1"))
    cat = C._pet_cat(2)
    paste(img, cat, 76, 54)
    E.save_ev(img, "cat")
    # two-headed hen
    img = E.scene(E.DAY, "sand1")
    paste(img, C._pet_hen(0), 76, 54)
    for k in range(3):
        ellipse(img, 92 + k * 5, 62, 4, 5, c("cream3"))
    E.save_ev(img, "hen")
    # rebirth stories
    img = E.scene(E.NIGHT, "gray1", clouds=0)
    E.mini_truck(img, 52, 36)
    for k in range(6):
        px(img, 80 + rx.randint(-6, 6), 30 - k * 3, c("gray4"))
    vline(img, 72, 12, 24, c("gray3"))
    for r in (6, 11, 16):
        for a in range(200, 340, 12):
            rr = math.radians(a)
            px(img, round(72 + r * math.cos(rr)), round(12 + r * math.sin(rr)), c("lamp1"))
    rect(img, 110, 14, 24, 6, c("gray3"))
    hline(img, 104, 13, 36, c("gray4"))
    px(img, 122, 22, c("red3"))
    for k in range(30):
        px(img, rx.randint(0, 159), rx.randint(0, 40), c("gray6"))
    E.save_ev(img, "story_sos")
    img = E.scene(E.DUSK, "gray2", skyline="gray3")
    rect(img, 90, 20, 60, 36, c("gray3"))
    rect(img, 96, 26, 48, 8, c("lamp0"))
    for x in range(98, 144, 8):
        rect(img, x, 40, 5, 6, c("night1"))
    vline(img, 120, 6, 14, c("gray4"))
    px(img, 120, 5, c("red3"))
    E.mini_truck(img, 30, 30)
    for k in range(4):
        paste(img, C.dweller_frame(["army", "medic", "scav", "lab"][k], "brown", "stand", 0), 66 + k * 6, 40)
    E.save_ev(img, "story_command")


def gen_extra():
    for name, fn in ENEMIES.items():
        add(f"en_{name}_0", fn(0))
        add(f"en_{name}_1", fn(1))
    for k, fn in BOSSES.items():
        for f in (0, 1):
            add(f"boss_{k}_{f}", fn(f))
    gen_fx()
    gen_drivetrain()
    add("lm_market", L.weather(lm_market(), 77) if hasattr(L, "weather") else lm_market())
    gen_events_extra()
