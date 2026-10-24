"""v2 layered parallax backgrounds (MV-163), first biome: industrial.

Why a second generator: the v1 layers (bg.py) are 480 px wide, so the road repeats every ~5 s, and the
buildings ignore the scale of the truck. v2 rules:

- Real scale. A dweller is 20 px = 1.75 m, so the truck plane has PPM = 11.4 px per metre. A layer that
  scrolls at `speed` (1.0 = road) is that much further away, so its things are drawn at PPM * speed: a
  3 m storey is 34 px at the truck, 9 px on the mid layer (0.25), 3 px on the far skyline (0.07).
- Depth. 9 layers from smog to road, each one hazier toward the horizon colour, with its ground line a
  little higher the further it is (perspective toward the horizon).
- Long loops. Strips are 1440-3840 px; at road speed 90 px/s every layer takes 20 s to 4.5 min to come
  round again, and props are placed by a seeded walk that never puts the same kind twice in a row.
- Richer colour. Each biome gets its own ~96 colour palette (median cut over the finished layers) instead
  of the shared 16-bit master palette; still hard-edged pixels, no alpha blending, no filtering.
- PixelLab kit. Hand-picked buildings drawn by PixelLab (tools/art/pixellab/kit/*.png, tools/pixellab.py
  kit) are mixed with procedural ones, tinted and hazed like everything else in their layer.

Writes assets/bg/v2/<biome>_<layer>.png + <biome>.json (layout read by scripts/world/background.gd)
and <biome>_thumb.png (map panel).  Run through tools/generate_pixel_art.py or alone:
    python3 -m tools.art.bg2   (from the repo root)
Only Pillow is needed.
"""
import json, math, os, random
from PIL import Image, ImageDraw, ImageChops

from .common import ROOT, OUT_BG

OUT = os.path.join(OUT_BG, "v2")
KIT_DIR = os.path.join(ROOT, "tools", "art", "pixellab", "kit")
PPM = 20 / 1.75              # px per metre on the truck plane
ROAD_Y = 290                 # top of the road strip, same as Background.ROAD_Y
HORIZON = ROAD_Y - 40        # where infinitely far ground would sit
SKY_H = 900

BAYER8 = [
    [0, 32, 8, 40, 2, 34, 10, 42], [48, 16, 56, 24, 50, 18, 58, 26], [12, 44, 4, 36, 14, 46, 6, 38],
    [60, 28, 52, 20, 62, 30, 54, 22], [3, 35, 11, 43, 1, 33, 9, 41], [51, 19, 59, 27, 49, 17, 57, 25],
    [15, 47, 7, 39, 13, 45, 5, 37], [63, 31, 55, 23, 61, 29, 53, 21],
]


def bayer(x, y):
    return (BAYER8[y & 7][x & 7] + 0.5) / 64.0


def rgb(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def shade(col, k):
    """k < 0 darker, k > 0 lighter, with a slight hue shift (shadows cool, lights warm)"""
    if k < 0:
        return mix(col, (12, 10, 26), -k)
    return mix(col, (255, 214, 160), k)


# ------------------------------------------------------------------ biome config
BIOMES = {
    "industrial": dict(
        seed=7101,
        sky=[(0.0, "0b0912"), (0.30, "17111f"), (0.52, "2a1830"), (0.68, "4a2232"), (0.80, "7a3330"),
             (0.90, "b0532e"), (0.96, "d8803e"), (1.0, "eaa45a")],
        sun=("ffd890", "f0a050", 56), sun_pos=(150, 40),
        haze="9a4c3a", fog="6e3834", smog=("5a2c34", "8a4438", "c0643a"),
        concrete=["6e6a66", "8a847a", "5c5a5a", "7a6e62"], brick=["7a3a2c", "8e4a34", "6a3428", "9a5a40"],
        metal=["4a4e56", "5c6066", "3a3e46"], rust=["8a4a26", "a0582a", "6e3a20"],
        ground="3a2c2a", rubble=["4a3a34", "5e4a40", "2e2424"],
        window="16141c", lit=["ffb04a", "ffd27a", "e8803a"], light="ffc060",
        asphalt="2c2a2e", line="b89a4a",
    ),
}

# name, speed (= scale vs the truck plane), strip width, height above its ground line, haze amount
LAYERS = [
    ("clouds_hi", 0.02, 1920, 0, 0.0),
    ("clouds_lo", 0.045, 1440, 0, 0.0),
    ("far", 0.07, 1440, 250, 0.62),
    ("far2", 0.13, 1920, 190, 0.46),
    ("mid", 0.25, 2880, 130, 0.30),
    ("mid2", 0.40, 2880, 70, 0.18),
    ("near", 0.60, 3840, 90, 0.08),
    ("road", 1.0, 1920, 0, 0.0),
]
ROAD_H = 64


def ground_y(speed):
    return HORIZON + (ROAD_Y - HORIZON) * speed


# ------------------------------------------------------------------ canvas with wrap-around
class Strip:
    """an RGBA canvas W wide plus a margin; fold() wraps the margin back onto x=0 so the strip tiles"""
    MARGIN = 480

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w + self.MARGIN, h), (0, 0, 0, 0))
        self.glow = Image.new("RGBA", (w + self.MARGIN, h), (0, 0, 0, 0))   # emissive, drawn after haze
        self.d = ImageDraw.Draw(self.img)
        self.grade = None
        self.lamps = []
        self.g = ImageDraw.Draw(self.glow)

    def fold(self, img):
        out = img.crop((0, 0, self.w, self.h))
        tail = img.crop((self.w, 0, self.w + self.MARGIN, self.h))
        out.alpha_composite(tail, (0, 0))
        return out


def rect(d, x, y, w, h, col):
    if w > 0 and h > 0:
        d.rectangle([int(x), int(y), int(x + w - 1), int(y + h - 1)], fill=col + (255,) if len(col) == 3 else col)


# ------------------------------------------------------------------ procedural props (sizes in metres)
def building(S, x, gy, s, B, rng, storeys, width_m, mat, roof_clutter=True, damage=0.5):
    """concrete / brick block: 3 m storeys, material texture, framed windows, a shop floor up close,
    missing chunks with rebar, rooftop junk and the odd lit window"""
    m = s * PPM
    w = max(6, int(width_m * m))
    sh = max(2, int(round(3.0 * m)))
    h = sh * storeys + max(1, int(m * 0.6))
    top = gy - h
    base = mix(rgb(rng.choice(B[mat])), (58, 40, 42), rng.uniform(0.1, 0.3))
    d, g = S.d, S.g
    rect(d, x, top, w, h, base)
    # material: brick courses / concrete panel joints, dithered so they read as texture, not stripes
    joint = shade(base, -0.16)
    if m >= 3:
        if mat == "brick":
            for y in range(top + 1, gy, 2):
                for xx in range(x, x + w):
                    if bayer(xx, y) < 0.45:
                        d.point([(xx, y)], fill=joint + (255,))
        else:
            pw = max(4, int(3.0 * m))
            for xx in range(x + pw, x + w, pw):
                d.line([xx, top, xx, gy], fill=joint + (255,))
    # grime streaks running down from the roof
    for _ in range(max(1, w // 10)):
        sx = x + rng.randint(0, w - 1)
        L = rng.randint(h // 4, h)
        for y in range(top, top + L):
            if bayer(sx, y) < 0.6 * (1 - (y - top) / L):
                d.point([(sx, y)], fill=shade(base, -0.28) + (255,))
    # light: lit left edge, shaded right side (low sun on the left)
    side = max(1, w // 6)
    rect(d, x + w - side, top, side, h, shade(base, -0.35))
    rect(d, x, top, max(1, w // 16), h, shade(base, 0.14))
    for k in range(1, storeys):
        y = gy - k * sh
        d.line([x, y, x + w - 1, y], fill=shade(base, -0.22) + (255,))
    # windows
    win = rgb(B["window"])
    ww = max(1, int(round(1.2 * m)))
    wh = max(1, int(round(1.5 * m)))
    step = max(ww + 1, int(round(3.0 * m)))
    shop = s >= 0.4 and storeys <= 3
    for k in range(storeys):
        y = gy - (k + 1) * sh + max(1, (sh - wh) // 2)
        if shop and k == 0:
            # ground-floor shop: dark opening, half-pulled rusty shutter, door
            oy, oh = gy - sh + max(1, int(0.6 * m)), sh - max(1, int(0.6 * m))
            ow = int(w * 0.6)
            rect(d, x + 2, oy, ow, oh, win)
            sht = rgb(rng.choice(B["rust"]))
            for yy in range(oy, oy + int(oh * rng.uniform(0.3, 0.8)), 2):
                d.line([x + 2, yy, x + 1 + ow, yy], fill=sht + (255,))
            rect(d, x + ow + 4, oy + 1, max(2, int(1.0 * m)), oh - 1, shade(base, -0.45))
            continue
        for wx in range(x + max(1, step // 2), x + w - ww - 1, step):
            r = rng.random()
            if r < 0.035:
                rect(g, wx, y, ww, wh, rgb(rng.choice(B["lit"])) + (255,))
            elif r < 0.12:
                rect(d, wx, y, ww, wh, shade(base, 0.22))            # boarded up
            elif r < 0.96:
                rect(d, wx, y, ww, wh, win)
                if ww >= 2 and wh >= 3:
                    d.point([(wx, y)], fill=shade(win, 0.3) + (255,))   # glint
                    d.line([wx, y + wh, wx + ww - 1, y + wh], fill=shade(base, 0.25) + (255,))  # sill
    # damage: a bite out of a top corner, with rebar sticking out
    if rng.random() < damage and w > 8:
        bw = int(w * rng.uniform(0.25, 0.6))
        bh = int(sh * rng.uniform(1, max(1.2, storeys * 0.45)))
        left = rng.random() < 0.5
        bx = x if left else x + w - bw
        pts = [(bx, top - 1), (bx + bw, top - 1)]
        pts += [(bx + bw, top + bh), (bx, top + bh // 3)] if left else [(bx + bw, top + bh // 3), (bx, top + bh)]
        d.polygon(pts, fill=(0, 0, 0, 0))
        reb = rgb(rng.choice(B["rust"]))
        for _ in range(max(1, bw // 4)):
            rx = bx + rng.randint(0, max(0, bw - 1))
            d.line([rx, top + bh // 2, rx + rng.randint(-1, 1), top + bh // 2 - max(2, int(m * 1.5))], fill=reb + (255,))
    elif roof_clutter:
        if rng.random() < 0.6 and w > 6:
            tw = max(2, int(2.5 * m))
            rect(d, x + w // 4, top - int(2.5 * m), tw, int(2.5 * m), shade(base, -0.25))
        if rng.random() < 0.5:
            ax = x + int(w * rng.uniform(0.5, 0.9))
            d.line([ax, top, ax, top - int(rng.uniform(4, 9) * m)], fill=rgb(B["metal"][0]) + (255,))
    d.line([x, top, x + w - 1, top], fill=shade(base, 0.2) + (255,))          # parapet catches the light
    return w


def chimney(S, x, gy, s, B, rng, h_m, smoke=True):
    m = s * PPM
    h = int(h_m * m)
    wb = max(2, int(h_m * 0.07 * m))
    wt = max(1, int(wb * 0.7))
    d = S.d
    base = rgb(rng.choice(B["brick"] + B["concrete"]))
    d.polygon([(x, gy), (x + wb, gy), (x + wb - (wb - wt) // 2, gy - h), (x + (wb - wt) // 2, gy - h)], fill=base + (255,))
    d.line([x + wb - 1, gy, x + wb - 1 - (wb - wt) // 2, gy - h], fill=shade(base, -0.4) + (255,))
    # faded warning bands near the top
    for k in (0.06, 0.14):
        y = gy - h + int(h * k)
        d.line([x + (wb - wt) // 2, y, x + wb - (wb - wt) // 2, y], fill=mix(base, (190, 180, 170), 0.5) + (255,))
    S.g.point([(x + wb // 2, gy - h - 1)], fill=(230, 60, 40, 255))   # aviation light
    if smoke:
        plume(S, x + wb // 2, gy - h, s, B, rng)
    return wb


def plume(S, x, y, s, B, rng):
    """leaning smoke column: dithered dots that widen and thin out downwind (to the right)"""
    cols = [rgb(c) for c in B["smog"]]
    length = int(rng.uniform(60, 120) * max(0.35, s * 4))
    for i in range(length):
        t = i / length
        cx = x + i * 0.9
        cy = y - i * 0.35 - math.sin(i * 0.12) * 2
        r = 1 + t * length * 0.12
        dens = 0.75 * (1 - t) ** 1.3
        for yy in range(int(cy - r), int(cy + r) + 1):
            for xx in range(int(cx - r * 0.6), int(cx + r * 0.6) + 1):
                if math.hypot((xx - cx) / 0.6, yy - cy) <= r and bayer(xx, yy) < dens:
                    S.d.point([(xx, yy)], fill=cols[0 if yy > cy else 1] + (255,))


def cooling_tower(S, x, gy, s, B, rng):
    m = s * PPM
    h = int(rng.uniform(110, 150) * m)
    wb = int(h * 0.8)
    pts_l, pts_r = [], []
    for k in range(h + 1):
        t = k / h
        half = wb / 2 * (0.55 + 0.45 * ((0.72 - t) / 0.72) ** 1.6 if t < 0.72 else 0.55 + 0.6 * ((t - 0.72) / 0.28) ** 2 * 0.2)
        y = gy - k
        pts_l.append((x + wb / 2 - half, y))
        pts_r.append((x + wb / 2 + half, y))
    base = rgb(B["concrete"][2])
    S.d.polygon(pts_l + pts_r[::-1], fill=base + (255,))
    for (lx, y), (rx, _) in zip(pts_l, pts_r):            # shaded right third
        S.d.line([lx + (rx - lx) * 0.68, y, rx, y], fill=shade(base, -0.3) + (255,))
    if rng.random() < 0.7:
        plume(S, x + wb // 2, gy - h, s, B, rng)
    return wb


def lattice(S, x, gy, s, B, rng, h_m, w_m, top_w_m=None, col=None):
    """steel lattice: pylon / crane mast / water tower legs"""
    m = s * PPM
    h, wb = int(h_m * m), max(2, int(w_m * m))
    wt = max(1, int((top_w_m if top_w_m is not None else w_m * 0.35) * m))
    c = (col or rgb(rng.choice(B["metal"]))) + (255,)
    lx0, rx0, lx1, rx1 = x, x + wb, x + (wb - wt) / 2, x + (wb + wt) / 2
    S.d.line([lx0, gy, lx1, gy - h], fill=c)
    S.d.line([rx0, gy, rx1, gy - h], fill=c)
    n = max(2, int(h / max(3, 3 * m)))
    for k in range(n):
        t0, t1 = k / n, (k + 1) / n
        a = (lx0 + (lx1 - lx0) * t0, gy - h * t0)
        b = (rx0 + (rx1 - rx0) * t1, gy - h * t1)
        S.d.line([a, b], fill=c)
        S.d.line([(rx0 + (rx1 - rx0) * t0, gy - h * t0), (lx0 + (lx1 - lx0) * t1, gy - h * t1)], fill=c)
    return wb, h


def pylon(S, x, gy, s, B, rng):
    m = s * PPM
    wb, h = lattice(S, x, gy, s, B, rng, rng.uniform(32, 42), 7, 1.5)
    arm = int(7 * m)
    c = rgb(B["metal"][0]) + (255,)
    for k in (0.72, 0.86):
        y = gy - int(h * k)
        S.d.line([x + wb / 2 - arm, y, x + wb / 2 + arm, y], fill=c)
    return wb, [(x + wb / 2 - arm, gy - int(h * 0.72)), (x + wb / 2 + arm, gy - int(h * 0.72)), (x + wb / 2, gy - int(h * 0.86))]


def crane(S, x, gy, s, B, rng):
    m = s * PPM
    col = rgb(rng.choice(B["rust"]))
    wb, h = lattice(S, x, gy, s, B, rng, rng.uniform(40, 60), 3, 3, col)
    jib = int(rng.uniform(30, 45) * m)
    y = gy - h
    S.d.line([x - jib * 0.3, y, x + jib, y], fill=col + (255,))
    S.d.line([x - jib * 0.3, y + 1, x + jib, y + 1], fill=shade(col, -0.3) + (255,))
    S.d.line([x + wb / 2, y - int(5 * m), x + jib, y], fill=col + (255,))
    hook = x + int(jib * rng.uniform(0.4, 0.9))
    S.d.line([hook, y, hook, y + int(rng.uniform(8, 20) * m)], fill=(30, 28, 34, 255))
    return wb


def tank(S, x, gy, s, B, rng, sphere=False):
    m = s * PPM
    base = rgb(rng.choice(B["concrete"] + B["metal"]))
    if sphere:
        r = int(rng.uniform(7, 10) * m)
        lx, h = lattice(S, x, gy, s, B, rng, 6, 2 * r / m, 2 * r / m)
        S.d.ellipse([x, gy - 6 * m - 2 * r, x + 2 * r, gy - 6 * m], fill=base + (255,))
        S.d.chord([x, gy - 6 * m - 2 * r, x + 2 * r, gy - 6 * m], 300, 120, fill=shade(base, -0.3) + (255,))
        return 2 * r
    w, h = int(rng.uniform(10, 18) * m), int(rng.uniform(8, 14) * m)
    rect(S.d, x, gy - h, w, h, base)
    rect(S.d, x + w * 2 // 3, gy - h, w - w * 2 // 3, h, shade(base, -0.3))
    S.d.ellipse([x, gy - h - max(1, int(m)), x + w, gy - h + max(1, int(m))], fill=shade(base, 0.15) + (255,))
    for k in range(1, 3):
        S.d.line([x, gy - h * k // 3, x + w - 1, gy - h * k // 3], fill=shade(base, -0.12) + (255,))
    return w


def dead_tree(S, x, gy, s, B, rng):
    m = s * PPM
    h = rng.uniform(5, 11) * m
    col = (34, 26, 28, 255)

    def branch(x0, y0, ang, ln, depth):
        x1, y1 = x0 + math.cos(ang) * ln, y0 - math.sin(ang) * ln
        S.d.line([x0, y0, x1, y1], fill=col, width=max(1, int(depth * 0.6)) if depth > 2 else 1)
        if depth > 0 and ln > 1.5:
            for da in (rng.uniform(0.25, 0.6), -rng.uniform(0.25, 0.6)):
                branch(x1, y1, ang + da, ln * rng.uniform(0.55, 0.75), depth - 1)
    branch(x, gy, math.pi / 2 + rng.uniform(-0.15, 0.15), h * 0.5, 4)
    return int(h * 0.6)


def car(S, x, gy, s, B, rng, bus=False):
    m = s * PPM
    L = int((rng.uniform(10, 12) if bus else rng.uniform(4.2, 4.8)) * m)
    H = int((2.9 if bus else 1.45) * m)
    body = rgb(rng.choice(B["rust"] + B["metal"] + ["7a6a5a", "5a4c48"]))
    wh = max(1, int(0.35 * m))
    d = S.d
    if bus:
        rect(d, x, gy - H - wh, L, H, body)
        for wx in range(x + 2, x + L - 3, max(3, int(1.6 * m))):
            rect(d, wx, gy - H - wh + max(1, int(0.5 * m)), max(1, int(1.1 * m)), max(1, int(0.8 * m)), rgb(B["window"]))
    else:
        cab = int(H * 0.45)
        rect(d, x, gy - H + cab - wh, L, H - cab, body)
        d.polygon([(x + L * 0.22, gy - H + cab - wh), (x + L * 0.32, gy - H - wh), (x + L * 0.7, gy - H - wh),
                   (x + L * 0.8, gy - H + cab - wh)], fill=shade(body, -0.15) + (255,))
        d.polygon([(x + L * 0.27, gy - H + cab - wh), (x + L * 0.34, gy - H + 1 - wh), (x + L * 0.68, gy - H + 1 - wh),
                   (x + L * 0.75, gy - H + cab - wh)], fill=rgb(B["window"]) + (255,))
    d.line([x, gy - wh - 1, x + L - 1, gy - wh - 1], fill=shade(body, -0.4) + (255,))
    for wx in ((x + L * 0.18, x + L * 0.78) if not bus else (x + L * 0.12, x + L * 0.85)):
        r = max(1, int(0.38 * m))
        d.ellipse([wx - r, gy - 2 * r, wx + r, gy], fill=(20, 18, 22, 255))
    return L


def utility_pole(S, x, gy, s, B, rng, lamp=False):
    m = s * PPM
    h = int(rng.uniform(8.5, 10) * m)
    wood = rgb("3a2a22")
    rect(S.d, x, gy - h, max(1, int(0.3 * m)), h, wood)
    arm = int(1.6 * m)
    y = gy - h + max(2, int(0.6 * m))
    S.d.line([x - arm, y, x + arm, y], fill=wood + (255,))
    if lamp:
        # sodium street lamp hanging off the pole, warm pool of light on the ground
        S.d.line([x, y + 3, x + int(2 * m), y + 1], fill=rgb(B["metal"][0]) + (255,))
        lx = x + int(2 * m)
        S.g.rectangle([lx - 1, y + 1, lx + 1, y + 2], fill=rgb(B["light"]) + (255,))
        S.lamps.append((lx, y + 2, gy))
    if rng.random() < 0.35:
        rect(S.d, x + 1, y + 2, max(2, int(0.9 * m)), max(2, int(1.2 * m)), rgb(B["metal"][1]))   # transformer
    return [(x - arm, y), (x + arm, y)]


def fence(S, x, gy, s, B, rng, length_m):
    m = s * PPM
    L, h = int(length_m * m), max(3, int(2.2 * m))
    post = rgb(B["metal"][0]) + (255,)
    mesh = rgb(B["metal"][1])
    for xx in range(x, x + L):
        for yy in range(gy - h, gy):
            if (xx + yy) % 3 == 0 or (xx - yy) % 3 == 0:
                if bayer(xx, yy) < 0.55:
                    S.d.point([(xx, yy)], fill=mesh + (255,))
    for px_ in range(x, x + L, max(4, int(3 * m))):
        S.d.line([px_, gy, px_, gy - h - 1], fill=post)
    S.d.line([x, gy - h, x + L, gy - h], fill=post)
    if rng.random() < 0.5:   # a sagging, torn section
        cx = x + rng.randint(0, max(1, L - 8))
        S.d.polygon([(cx, gy - h), (cx + 8, gy - h), (cx + 4, gy - h // 2)], fill=(0, 0, 0, 0))
    return L


def billboard(S, x, gy, s, B, rng):
    m = s * PPM
    w, h = int(rng.uniform(8, 12) * m), int(rng.uniform(3.5, 4.5) * m)
    leg = int(rng.uniform(4, 6) * m)
    metal = rgb(B["metal"][0]) + (255,)
    for lx in (x + w // 4, x + 3 * w // 4):
        S.d.line([lx, gy, lx, gy - leg], fill=metal)
    panel = rgb(rng.choice(["8a7a5e", "6e5a4a", "7a4a3a", "4e5a5a"]))
    rect(S.d, x, gy - leg - h, w, h, panel)
    # peeling poster: faded stripes and a torn corner
    for k in range(3):
        y = gy - leg - h + 2 + k * max(2, h // 4)
        S.d.line([x + 2, y, x + w - 3 - rng.randint(0, w // 3), y], fill=shade(panel, rng.choice([-0.3, 0.25])) + (255,))
    S.d.polygon([(x + w - 1, gy - leg - h), (x + w - 1, gy - leg - h // 2), (x + w - w // 4, gy - leg - h)], fill=(0, 0, 0, 0))
    S.d.rectangle([x, gy - leg - h, x + w - 1, gy - leg - 1], outline=shade(panel, -0.45) + (255,))
    return w


def barrel_fire(S, x, gy, s, B, rng):
    m = s * PPM
    w, h = max(2, int(0.6 * m)), max(3, int(0.9 * m))
    rect(S.d, x, gy - h, w, h, rgb(rng.choice(B["rust"])))
    S.g.point([(x + w // 2, gy - h - 1), (x + w // 2 - 1, gy - h - 1), (x + w // 2, gy - h - 2)], fill=rgb(B["lit"][2]) + (255,))
    S.g.point([(x + w // 2, gy - h - 3)], fill=rgb(B["lit"][1]) + (255,))
    S.lamps.append((x + w // 2, gy - h - 2, gy))
    return w


def rubble(S, gy, s, B, rng, w):
    """uneven ground line: rubble heaps, kerb stones, weeds along the whole strip"""
    m = s * PPM
    cols = [rgb(c) for c in B["rubble"]]
    x = 0
    while x < w + Strip.MARGIN:
        hw = int(rng.uniform(4, 14) * m) + 2
        hh = max(1, int(rng.uniform(0.3, 1.6) * m))
        col = rng.choice(cols)
        S.d.polygon([(x, gy), (x + hw * 0.35, gy - hh), (x + hw * 0.6, gy - hh + 1), (x + hw, gy)], fill=col + (255,))
        x += hw + rng.randint(0, int(6 * m) + 2)


def ground_texture(S, gy, s, B, rng, w):
    """dirt between this layer's ground line and the road: dithered tones, cracks, weed tufts"""
    base = rgb(B["ground"])
    W = w + Strip.MARGIN
    for y in range(gy, S.h):
        for x in range(W):
            n = math.sin(x * 0.045 + y * 0.7) + math.sin(x * 0.011 + 1.7) * 1.3
            if bayer(x, y) < abs(n) * 0.18:
                S.d.point([(x, y)], fill=shade(base, 0.12 if n > 0 else -0.22) + (255,))
    weed = (52, 46, 34, 255)
    for _ in range(W // 18):
        x, y = rng.randint(0, W - 1), rng.randint(gy, S.h - 1)
        for k in range(rng.randint(1, 3)):
            S.d.line([x + k, y, x + k + rng.choice((-1, 0, 1)), y - rng.randint(1, max(2, int(0.6 * s * PPM)))], fill=weed)


def wire(S, a, b, sag, col):
    """catenary-ish power line between two points"""
    (x0, y0), (x1, y1) = a, b
    n = max(2, int(abs(x1 - x0)))
    pts = [(x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n + sag * 4 * (i / n) * (1 - i / n)) for i in range(n + 1)]
    S.d.line(pts, fill=col + (255,))


# ------------------------------------------------------------------ PixelLab kit
_kit_cache = {}
try:
    with open(os.path.join(ROOT, "tools", "art", "pixellab", "kit.json"), encoding="utf-8") as _f:
        KIT_SPEC = json.load(_f)["items"]
except OSError:
    KIT_SPEC = {}


def kit(name):
    if name not in _kit_cache:
        p = os.path.join(KIT_DIR, name + ".png")
        if not os.path.exists(p):
            _kit_cache[name] = None
        else:
            im = Image.open(p).convert("RGBA")
            a = im.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
            im.putalpha(a)
            im = im.crop(a.getbbox())
            trim = KIT_SPEC.get(name, {}).get("trim_bottom", 0)      # PixelLab sometimes adds a pavement slab
            if trim:
                im = im.crop((0, 0, im.width, im.height - trim))
                im = im.crop(im.getchannel("A").getbbox())
            _kit_cache[name] = im
    return _kit_cache[name]


def place_kit(S, name, x, gy, scale=1.0, flip=False, sink=1):
    im = kit(name)
    if im is None:
        return 0
    if scale != 1.0:
        w, h = max(1, int(im.width * scale)), max(1, int(im.height * scale))
        im = im.resize((w, h), Image.BOX)
        im.putalpha(im.getchannel("A").point(lambda v: 255 if v >= 128 else 0))
    if flip:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    if S.grade:
        # pull PixelLab's own palette toward the biome light so kit pieces sit with the procedural ones
        a = im.getchannel("A")
        im = Image.blend(im.convert("RGB"), Image.new("RGB", im.size, S.grade), 0.18).convert("RGBA")
        im.putalpha(a)
    S.img.alpha_composite(im, (int(x), int(gy - im.height + sink)))
    return im.width


# ------------------------------------------------------------------ layer recipes
def scatter(S, w, rng, recipe, gap):
    """seeded walk along the strip: never the same kind twice in a row"""
    x, last = rng.randint(0, 20), None
    while x < w:
        kinds = [k for k in recipe if k[0] != last]
        tot = sum(k[1] for k in kinds)
        r, acc = rng.random() * tot, 0
        for k in kinds:
            acc += k[1]
            if r <= acc:
                break
        used = k[2](x) or 0
        last = k[0]
        x += max(4, used) + rng.randint(*gap)


def layer_far(S, B, rng, w, gy, s):
    # two depths inside the layer: a paler back row first, then the skyline
    for row, (ss, fade) in enumerate(((s * 0.7, 0.35), (s, 0.0))):
        S2 = S
        scatter(S2, w, rng, [
            ("tower", 4, lambda x: building(S2, x, gy - row * 2, ss, B, rng, rng.randint(18, 60), rng.uniform(18, 40), "concrete", damage=0.6)),
            ("highrise", 2, lambda x: building(S2, x, gy - row * 2, ss, B, rng, rng.randint(60, 95), rng.uniform(26, 45), "concrete", damage=0.8)),
            ("block", 3, lambda x: building(S2, x, gy - row * 2, ss, B, rng, rng.randint(5, 12), rng.uniform(30, 60), "concrete")),
            ("chimney", 2, lambda x: chimney(S2, x, gy, ss, B, rng, rng.uniform(90, 150))),
            ("cooling", 1, lambda x: cooling_tower(S2, x, gy, ss, B, rng)),
        ], (0, 30) if row else (10, 60))


def layer_far2(S, B, rng, w, gy, s):
    lines = []
    def pyl(x):
        wb, arms = pylon(S, x, gy, s, B, rng)
        lines.append(arms)
        return wb
    scatter(S, w, rng, [
        ("highrise", 1, lambda x: building(S, x, gy, s, B, rng, rng.randint(20, 40), rng.uniform(20, 32), "concrete", damage=0.7)),
        ("hall", 4, lambda x: building(S, x, gy, s, B, rng, rng.randint(2, 4), rng.uniform(40, 90), rng.choice(["brick", "concrete"]), damage=0.3)),
        ("chimney", 2, lambda x: chimney(S, x, gy, s, B, rng, rng.uniform(55, 85))),
        ("crane", 1, lambda x: crane(S, x, gy, s, B, rng)),
        ("tank", 2, lambda x: tank(S, x, gy, s, B, rng, sphere=rng.random() < 0.4)),
        ("refinery", 2, lambda x: place_kit(S, "ind_refinery", x, gy, scale=s / 0.13 * rng.uniform(0.9, 1.1), flip=rng.random() < 0.5)),
        ("pylon", 1, pyl),
    ], (6, 40))
    _string_wires(S, lines, rgb("2a2230"), 6)


def layer_mid(S, B, rng, w, gy, s):
    lines = []
    def pyl(x):
        wb, arms = pylon(S, x, gy, s, B, rng)
        lines.append(arms)
        return wb
    flip = lambda: rng.random() < 0.5
    scatter(S, w, rng, [
        ("apt_a", 2, lambda x: place_kit(S, "ind_apartment_a", x, gy, flip=flip())),
        ("apt_b", 2, lambda x: place_kit(S, "ind_apartment_b", x, gy, flip=flip())),
        ("warehouse", 2, lambda x: place_kit(S, "ind_warehouse", x, gy, flip=flip())),
        ("boiler", 1, lambda x: place_kit(S, "ind_factory", x, gy, flip=flip())),
        ("water", 1, lambda x: place_kit(S, "ind_water_tower", x, gy)),
        ("block", 4, lambda x: building(S, x, gy, s, B, rng, rng.randint(3, 9), rng.uniform(14, 30), rng.choice(["brick", "concrete"]))),
        ("tree", 2, lambda x: dead_tree(S, x, gy, s, B, rng)),
        ("pylon", 1, pyl),
    ], (2, 26))
    _string_wires(S, lines, rgb("221c26"), 10)


def layer_mid2(S, B, rng, w, gy, s):
    scatter(S, w, rng, [
        ("containers", 2, lambda x: place_kit(S, "ind_containers", x, gy, flip=rng.random() < 0.5)),
        ("bus", 1, lambda x: place_kit(S, "ind_bus_wreck", x, gy, flip=rng.random() < 0.5)),
        ("car", 3, lambda x: car(S, x, gy, s, B, rng)),
        ("fence", 4, lambda x: fence(S, x, gy, s, B, rng, rng.uniform(8, 25))),
        ("billboard", 2, lambda x: billboard(S, x, gy, s, B, rng)),
        ("tree", 2, lambda x: dead_tree(S, x, gy, s, B, rng)),
        ("hut", 2, lambda x: building(S, x, gy, s, B, rng, 1, rng.uniform(6, 10), "brick", roof_clutter=False, damage=0.7)),
    ], (6, 50))


def layer_near(S, B, rng, w, gy, s):
    poles = []
    def pole(x):
        poles.append(utility_pole(S, x, gy, s, B, rng, lamp=rng.random() < 0.55))
        return 3
    flip = lambda: rng.random() < 0.5
    scatter(S, w, rng, [
        ("shop", 3, lambda x: place_kit(S, "ind_shop", x, gy, flip=flip())),
        ("gas", 1, lambda x: place_kit(S, "ind_gas_station", x, gy, flip=flip())),
        ("store", 3, lambda x: building(S, x, gy, s, B, rng, rng.randint(1, 3), rng.uniform(8, 14), rng.choice(["brick", "concrete"]), damage=0.6)),
        ("car", 3, lambda x: car(S, x, gy, s, B, rng)),
        ("pole", 5, pole),
        ("fence", 2, lambda x: fence(S, x, gy, s, B, rng, rng.uniform(6, 16))),
        ("fire", 1, lambda x: barrel_fire(S, x, gy, s, B, rng)),
        ("tree", 1, lambda x: dead_tree(S, x, gy, s, B, rng)),
    ], (4, 40))
    _string_wires(S, poles, rgb("1c1820"), 7)


def _string_wires(S, anchors, col, sag):
    anchors = sorted(anchors, key=lambda a: a[0][0])
    for a, b in zip(anchors, anchors[1:]):
        if b[0][0] - a[-1][0] > 260:
            continue
        for p, q in zip(a, b):
            wire(S, p, q, sag, col)


RECIPES = {"far": layer_far, "far2": layer_far2, "mid": layer_mid, "mid2": layer_mid2, "near": layer_near}


# ------------------------------------------------------------------ post: haze, fog, emissive light
def haze_layer(img, haze, k, fog, fog_k, h_fog):
    """blend toward the horizon colour by k, plus extra ground fog over the bottom h_fog px"""
    if k <= 0 and fog_k <= 0:
        return img
    rgb_im = img.convert("RGB")
    hazed = Image.blend(rgb_im, Image.new("RGB", img.size, haze), k) if k > 0 else rgb_im
    if fog_k > 0:
        mask = Image.new("L", img.size, 0)
        md = ImageDraw.Draw(mask)
        for y in range(img.height - h_fog, img.height):
            t = (y - (img.height - h_fog)) / max(1, h_fog)
            md.line([0, y, img.width, y], fill=int(255 * fog_k * t))
        hazed = Image.composite(Image.new("RGB", img.size, fog), hazed, mask)
    out = hazed.convert("RGBA")
    out.putalpha(img.getchannel("A"))
    return out


def apply_lamps(img, lamps, col, s):
    """warm light pools: dithered bands that tint opaque pixels around each lamp/fire"""
    r = max(6, int(7 * s * PPM))
    px = img.load()
    for lx, ly, gy in lamps:
        for y in range(int(ly - r * 0.4), min(img.height, int(gy + 2))):
            for x in range(int(lx - r), int(lx + r) + 1):
                xx = x % img.width
                p = px[xx, y]
                if p[3] == 0:
                    continue
                d = math.hypot((x - lx) / r, (y - gy) / (r * 0.9) if y > ly else (y - ly) / (r * 0.4))
                if d >= 1:
                    continue
                band = (1 - d) * 3
                b = int(band) + (1 if band - int(band) > bayer(x, y) else 0)
                if b:
                    px[xx, y] = mix(p[:3], col, 0.16 * b) + (255,)


# ------------------------------------------------------------------ sky, sun, clouds, road
def sky(B):
    img = Image.new("RGB", (64, SKY_H))
    stops = [(t, rgb(c)) for t, c in B["sky"]]
    px = img.load()
    for y in range(SKY_H):
        t = y / (SKY_H - 1)
        for i in range(len(stops) - 1):
            if stops[i][0] <= t <= stops[i + 1][0]:
                a, b = stops[i], stops[i + 1]
                f = (t - a[0]) / max(1e-6, b[0] - a[0])
                break
        for x in range(64):
            # ordered dither between the two stops in 4 sub-steps: smooth but crisp
            q = min(4, int(f * 4 + bayer(x, y)))
            px[x, y] = mix(a[1], b[1], q / 4)
    return img


def sun(B):
    core, glow, r = rgb(B["sun"][0]), rgb(B["sun"][1]), B["sun"][2]
    S = r * 3
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    px = img.load()
    c = S / 2
    for y in range(S):
        for x in range(S):
            d = math.hypot(x - c + 0.5, y - c + 0.5)
            if d <= r * 0.42:
                px[x, y] = core + (255,)
            elif d <= r * 1.45:
                t = (d - r * 0.42) / (r * 1.03)
                if bayer(x, y) < (1 - t) ** 1.6 * 0.9:
                    px[x, y] = mix(core, glow, min(1, t * 1.6)) + (255,)
    for k, y in enumerate((c + 3, c + 7, c + 12)):   # smog bands across the disc
        for x in range(S):
            if px[x, int(y)][3] and (x + k) % 2 == 0:
                px[x, int(y)] = (0, 0, 0, 0)
    return img


def clouds(B, w, h, rng, lit):
    S = Strip(w, h)
    cols = [rgb(c) for c in B["smog"]]
    for _ in range(int(w / 70)):
        cx, cy = rng.randint(0, w), rng.randint(16, h - 16)
        L, th = rng.randint(90, 260), rng.randint(3, 9)
        for y in range(cy - th, cy + th + 1):
            t = abs(y - cy) / th
            half = int(L / 2 * (1 - t * t)) + rng.randint(-4, 4)
            for x in range(cx - half, cx + half):
                edge = min(x - (cx - half), cx + half - x) / max(1, half)
                if bayer(x, y) < min(1.0, edge * 3) * (1 - t * 0.5):
                    # underside catches the sunset (lit), top is in shadow
                    col = cols[2] if (lit and y > cy + th * 0.4) else cols[1] if y > cy else cols[0]
                    S.d.point([(x + S.MARGIN // 2, y)], fill=col + (255,))
    # the strip was drawn shifted by MARGIN/2 so clouds straddling x=0 wrap too
    img = S.img
    left = img.crop((0, 0, S.MARGIN // 2, h))
    body = img.crop((S.MARGIN // 2, 0, S.MARGIN // 2 + w + S.MARGIN // 2, h))
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.alpha_composite(body.crop((0, 0, w, h)))
    out.alpha_composite(body.crop((w, 0, w + S.MARGIN // 2, h)), (0, 0))
    out.alpha_composite(left, (w - S.MARGIN // 2, 0))
    return out


def road(B, w, rng):
    h = ROAD_H
    asphalt = rgb(B["asphalt"])
    img = Image.new("RGBA", (w, h), asphalt + (255,))
    px = img.load()
    # tone noise: worn and patched asphalt in 3 shades, ordered so it stays pixel-crisp
    for y in range(h):
        for x in range(w):
            n = (math.sin(x * 0.051 + y * 0.9) * 0.6 + math.sin(x * 0.0093 - y * 0.05) * 1.1) * 0.16
            if bayer(x, y) < abs(n):
                px[x, y] = shade(asphalt, 0.18 if n > 0 else -0.25) + (255,)
    d = ImageDraw.Draw(img)
    # kerb + cracked pavement on top
    kerb = rgb(B["concrete"][2])
    rect(d, 0, 0, w, 4, shade(kerb, -0.2))
    rect(d, 0, 4, w, 2, kerb)
    for x in range(0, w, 13):
        d.line([x, 0, x, 3], fill=shade(kerb, -0.45) + (255,))
    # faded dashed centre line, some dashes missing
    ly = 34
    for x in range(0, w, 40):
        if rng.random() < 0.8:
            for k in range(22):
                if rng.random() < 0.85:
                    d.point([(x + k, ly), (x + k, ly + 1)], fill=mix(rgb(B["line"]), asphalt, rng.uniform(0.1, 0.5)) + (255,))
    # cracks (random walks), potholes, patches, oil stains
    for _ in range(w // 60):
        x, y = rng.randint(0, w), rng.randint(8, h - 4)
        for _ in range(rng.randint(8, 30)):
            d.point([(x % w, y)], fill=shade(asphalt, -0.6) + (255,))
            x += 1
            y = max(7, min(h - 2, y + rng.choice((-1, 0, 0, 1))))
    for _ in range(w // 160):
        x, y = rng.randint(0, w - 20), rng.randint(14, h - 10)
        pw, ph = rng.randint(6, 14), rng.randint(2, 4)
        d.ellipse([x, y, x + pw, y + ph], fill=shade(asphalt, -0.55) + (255,))
        d.line([x + 1, y, x + pw - 1, y], fill=shade(asphalt, 0.2) + (255,))
    for _ in range(w // 220):
        x, y = rng.randint(0, w - 40), rng.randint(10, h - 18)
        pw, ph = rng.randint(14, 40), rng.randint(6, 12)
        d.polygon([(x, y + 1), (x + 3, y), (x + pw, y + 1), (x + pw - 2, y + ph), (x + 2, y + ph - 1)], fill=shade(asphalt, -0.12) + (255,))
    for _ in range(w // 90):     # debris: bits of glass, brick, metal
        x, y = rng.randint(0, w - 1), rng.randint(8, h - 2)
        d.point([(x, y)], fill=rgb(rng.choice(B["rubble"] + B["rust"])) + (255,))
    # dark shoulder at the bottom
    rect(d, 0, h - 5, w, 5, shade(asphalt, -0.4))
    return img


# ------------------------------------------------------------------ palette
def biome_palette(images, n=96):
    """median-cut palette over every opaque pixel of the biome, so all layers share the same colours"""
    samples = []
    for im in images:
        rgba = im.convert("RGBA")
        small = rgba if rgba.width * rgba.height < 400_000 else rgba.resize((rgba.width // 2, rgba.height // 2), Image.NEAREST)
        a = small.getchannel("A")
        bg = Image.new("RGB", small.size, (0, 0, 0))
        bg.paste(small.convert("RGB"), mask=a)
        # sample opaque only: push transparent pixels to a colour we strip later
        samples.append((bg, a))
    W = max(s[0].width for s in samples)
    H = sum(s[0].height for s in samples)
    sheet = Image.new("RGB", (W, H), samples[0][0].getpixel((0, 0)))
    y = 0
    for bg, a in samples:
        fill = Image.new("RGB", bg.size, bg.getpixel((bg.width // 2, bg.height - 1)))
        fill.paste(bg, mask=a)
        sheet.paste(fill, (0, y))
        y += bg.height
    return sheet.quantize(colors=n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)


def snap(img, pal):
    a = img.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    q = img.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGBA")
    q.putalpha(a)
    return q


# ------------------------------------------------------------------ build one biome
def build(name):
    B = BIOMES[name]
    rng = random.Random(B["seed"])
    os.makedirs(OUT, exist_ok=True)
    out, layout = {}, []
    out["sky"] = sky(B)
    out["sun"] = sun(B)
    for lname, s, w, hmax, hz in LAYERS:
        lrng = random.Random(rng.randint(0, 1 << 30))
        if lname.startswith("clouds"):
            h = 220 if lname == "clouds_hi" else 160
            img = clouds(B, w, h, lrng, lit=lname == "clouds_lo")
            y = ROAD_Y - (640 if lname == "clouds_hi" else 420)
        elif lname == "road":
            img, y = road(B, w, lrng), ROAD_Y
        else:
            gy_world = ground_y(s)
            top = int(gy_world - hmax - 40)          # headroom for chimneys / plumes
            h = ROAD_Y + 2 - top
            S = Strip(w, h)
            S.grade = rgb(B["haze"])
            gy = int(gy_world - top)
            # ground band from this layer's ground line down to the road (hidden by nearer layers mostly)
            rect(S.d, 0, gy, w + S.MARGIN, h - gy, rgb(B["ground"]))
            ground_texture(S, gy, s, B, lrng, w)
            rubble(S, gy, s, B, lrng, w)
            RECIPES[lname](S, B, lrng, w, gy, s)
            body = haze_layer(S.img, rgb(B["haze"]), hz, rgb(B["fog"]), min(0.55, hz + 0.25), max(6, int(18 * s * 2)))
            glow = S.glow
            body.alpha_composite(glow)
            img = S.fold(body)
            lamps = [((lx % w), ly, g) for lx, ly, g in S.lamps]
            apply_lamps(img, lamps, rgb(B["light"]), s)
            y = top
        out[lname] = img
        layout.append({"name": lname, "speed": s, "scroll": s, "y": y, "w": w, "h": img.height})
    pal = biome_palette([out[k] for k in out if k != "sky"] + [out["sky"].convert("RGBA")], 96)
    for k, im in out.items():
        im = snap(im.convert("RGBA"), pal) if k != "sky" else im.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB")
        out[k] = im
        im.save(os.path.join(OUT, f"{name}_{k}.png"), optimize=True)
    thumb = preview(name, out, layout, 168, 168, x0=40, cam_y=ROAD_Y + 18 - 168).resize((56, 56), Image.BOX)
    thumb.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB").save(os.path.join(OUT, f"{name}_thumb.png"))
    meta = {"version": 2, "road_y": ROAD_Y, "sky_h": SKY_H, "sun": list(B["sun_pos"]), "layers": layout,
            "ground": "#%02x%02x%02x" % rgb(B["ground"])}
    with open(os.path.join(OUT, f"{name}.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=1)
    return out, layout


def preview(name, out, layout, W, H, x0=0, cam_y=None):
    """what the camera sees: road near the bottom, every layer offset like the game would at scroll x0"""
    cam_y = ROAD_Y + 70 - H if cam_y is None else cam_y
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    skyim = out["sky"].convert("RGBA")
    sy = ROAD_Y + 4 - SKY_H - cam_y
    for x in range(0, W, 64):
        img.paste(skyim, (x, sy), skyim)
    sx, syy = BIOMES[name]["sun_pos"]
    img.paste(out["sun"], (int(sx - x0 * 0.02), int(ROAD_Y - 250 + syy - cam_y)), out["sun"])
    for L in layout:
        im = out[L["name"]].convert("RGBA")
        off = int(x0 * L["speed"]) % L["w"]
        for k in (0, 1):
            img.paste(im, (k * L["w"] - off, int(L["y"] - cam_y)), im)
    return img


def gen_backgrounds_v2():
    for name in BIOMES:
        build(name)


if __name__ == "__main__":
    gen_backgrounds_v2()
