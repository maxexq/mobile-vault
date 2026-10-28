"""Shared helpers for the Mobile Vault pixel-art generator.

Everything is drawn with plain PIL primitives, then snapped to ONE master palette
(`quantize`) so every sprite, background and UI piece shares the same 16-bit-era colour set.
Light / shadow are painted with `light_radial`, `shade_rect` etc. (free blending) and the
quantize step turns those blends into clean colour ramps (optionally ordered-dithered).
"""
import math, os, random
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_ATLAS = os.path.join(ROOT, "assets", "atlas")
OUT_BG = os.path.join(ROOT, "assets", "bg")
OUT_EV = os.path.join(ROOT, "assets", "events")
OUT_UI = os.path.join(ROOT, "assets", "ui")
for _p in (OUT_ATLAS, OUT_BG, OUT_EV, OUT_UI):
    os.makedirs(_p, exist_ok=True)

R = random.Random(1337)


def hx(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


# ------------------------------------------------------------------ master palette (ramps dark -> light)
RAMPS = {
    # Grim 16-bit apocalypse palette: soot-black outlines, rust, grime, bone, smog; the only saturated
    # colours are emissive accents (lamp amber, radioactive green, warning red) so light reads in the dark.
    "ol":     ["0c0a0a", "1e1816"],
    "skin":   ["4e3226", "7a503a", "a07052", "c09474"],
    "wood":   ["21160f", "3a2818", "563c24", "745434", "927048"],
    "cream":  ["4e463a", "6e6450", "908670", "b2a88a"],          # bone / paper / canvas
    "red":    ["2e0e0c", "521612", "7c2218", "a8372a", "c86450"],
    "orange": ["3e1c10", "622c14", "8a4220", "ae6430"],          # rust
    "yellow": ["443210", "6e5216", "a07c24", "d8ae44"],          # hazard paint / lamp amber
    "green":  ["161c10", "242e16", "36421e", "4e5a2c", "6a7442"],  # army olive / moss
    "teal":   ["10201e", "1a3430", "2a4c46", "466c60"],          # oxidised copper
    "blue":   ["10141e", "1a2232", "28344a", "3c4c62", "5a6c80"],  # cold steel
    "sky":    ["24282c", "363c40", "4c5254", "666a68"],          # smog
    "purple": ["18101c", "281a2e", "3c2a40", "584458"],          # bruise
    "pink":   ["3a1c24", "5a2e36", "7c4a4c", "9c6c66"],
    "gray":   ["0a0a0c", "18181c", "26262a", "3a3a3e", "54544e", "727064", "9a9684"],
    "sand":   ["32281c", "4e3e2a", "6e5a3e", "8e7a58"],          # dust
    "snow":   ["2e3840", "4a5862", "6e7c82", "98a2a0"],          # dirty snow / ice
    "toxic":  ["1e2e0a", "3c5e10", "6c9a18", "a8d838"],          # radioactive glow
    "dusk":   ["2e1414", "5a2418", "8a3c1c", "c06428"],          # ember haze
    "night":  ["060608", "0e0e16", "181826"],
    "lamp":   ["c88a2c", "f0c060", "fff0b0"],                    # warm light sources only
}
PAL = {}
for _k, _v in RAMPS.items():
    for _i, _c in enumerate(_v):
        PAL[f"{_k}{_i}"] = hx(_c)
PALETTE = sorted({v[:3] for v in PAL.values()})


def c(name, a=255):
    """palette colour by ramp+index e.g. c('rust3')"""
    v = PAL[name]
    return (v[0], v[1], v[2], a)


CLEAR = (0, 0, 0, 0)
OL = c("ol0")      # outline (soot black)
OL2 = c("ol1")


def new(w, h, col=CLEAR):
    return Image.new("RGBA", (w, h), col)


def rect(img, x, y, w, h, col):
    if w <= 0 or h <= 0:
        return
    ImageDraw.Draw(img).rectangle([x, y, x + w - 1, y + h - 1], fill=col)


def orect(img, x, y, w, h, fill, line=None):
    rect(img, x, y, w, h, line or OL)
    rect(img, x + 1, y + 1, w - 2, h - 2, fill)


def frame(img, x, y, w, h, col):
    ImageDraw.Draw(img).rectangle([x, y, x + w - 1, y + h - 1], outline=col)


def px(img, x, y, col):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((int(x), int(y)), col)


def hline(img, x, y, w, col):
    rect(img, x, y, w, 1, col)


def vline(img, x, y, h, col):
    rect(img, x, y, 1, h, col)


def line(img, x0, y0, x1, y1, col, w=1):
    ImageDraw.Draw(img).line([x0, y0, x1, y1], fill=col, width=w)


def ellipse(img, x, y, w, h, col, outline=None):
    ImageDraw.Draw(img).ellipse([x, y, x + w - 1, y + h - 1], fill=col, outline=outline)


def poly(img, pts, col, outline=None):
    ImageDraw.Draw(img).polygon(pts, fill=col, outline=outline)


def get(img, x, y):
    if 0 <= x < img.width and 0 <= y < img.height:
        return img.getpixel((int(x), int(y)))
    return CLEAR


def blend(c1, c2, t):
    t = max(0.0, min(1.0, t))
    a = c1[3] if len(c1) > 3 else 255
    return tuple(int(round(c1[i] * (1 - t) + c2[i] * t)) for i in range(3)) + (a,)


def tint_px(img, x, y, col, t):
    p = get(img, x, y)
    if p[3] == 0:
        return
    px(img, x, y, blend(p, col, t))


BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def bayer(x, y):
    return (BAYER4[y % 4][x % 4] + 0.5) / 16.0


def speckle(img, x, y, w, h, cols, density=0.08, rng=R, only_opaque=True):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            if rng.random() < density:
                if only_opaque and get(img, xx, yy)[3] == 0:
                    continue
                px(img, xx, yy, rng.choice(cols))


def dither_v(img, x, y, w, h, c_top, c_bot):
    for yy in range(h):
        t = yy / max(1, h - 1)
        for xx in range(w):
            px(img, x + xx, y + yy, c_bot if t > bayer(x + xx, y + yy) else c_top)


def gradient_v(img, x, y, w, h, stops, dither=True):
    """multi-stop vertical gradient; stops = [(t, colour), ...]; ordered dither between neighbouring stops"""
    for yy in range(h):
        t = yy / max(1, h - 1)
        for i in range(len(stops) - 1):
            if stops[i][0] <= t <= stops[i + 1][0]:
                a, b = stops[i], stops[i + 1]
                f = (t - a[0]) / max(1e-6, b[0] - a[0])
                break
        for xx in range(w):
            if dither:
                col = b[1] if f > bayer(x + xx, y + yy) else a[1]
            else:
                col = blend(a[1], b[1], f)
            px(img, x + xx, y + yy, col)


def light_radial(img, cx, cy, r, col, strength=0.5, x0=0, y0=0, x1=None, y1=None, steps=4, dither=True):
    """warm pool of light: tints existing opaque pixels toward col, quantized into `steps` bands with dithered edges"""
    x1 = img.width if x1 is None else x1
    y1 = img.height if y1 is None else y1
    for yy in range(max(y0, int(cy - r)), min(y1, int(cy + r) + 1)):
        for xx in range(max(x0, int(cx - r)), min(x1, int(cx + r) + 1)):
            d = math.hypot(xx - cx, (yy - cy) * 1.0) / r
            if d >= 1:
                continue
            k = (1 - d) * steps
            band = int(k)
            if dither and (k - band) > bayer(xx, yy):
                band += 1
            if band <= 0:
                continue
            tint_px(img, xx, yy, col, strength * band / steps)


def light_cone(img, x, y, w_top, w_bot, h, col, strength=0.35, steps=3, dither=False):
    """downward lamp cone (trapezoid) with hard banded falloff (classic pixel-art light)"""
    for yy in range(h):
        t = yy / max(1, h - 1)
        half = (w_top + (w_bot - w_top) * t) / 2
        for xx in range(int(x - half), int(x + half) + 1):
            edge = min(1.0, 1.6 * (1 - abs(xx - x) / max(1, half)))
            k = (1 - t * 0.6) * edge * steps
            band = int(k + 0.35)
            if dither and (k - int(k)) > bayer(xx, y + yy):
                band = int(k) + 1
            if band > 0:
                tint_px(img, xx, y + yy, col, strength * min(band, steps) / steps)


def shade_rect(img, x, y, w, h, col, t):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            tint_px(img, xx, yy, col, t)


def ao_box(img, x, y, w, h, depth=4, col=None, strength=0.45):
    """darken towards the inner edges of a box (room corners / ceiling) — fake ambient occlusion"""
    col = col or c("ol0")
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            d = min(xx - x, x + w - 1 - xx, yy - y, (y + h - 1 - yy) * 2)
            if d < depth:
                k = (depth - d) / depth
                band = 2 if k > 0.6 else 1 if k > 0.25 else 0
                if band:
                    tint_px(img, xx, yy, col, strength * band / 2)


def outline_alpha(img, col=None, diag=False):
    col = col or OL
    out = img.copy()
    w, h = img.size
    a = img.load()
    nb = ((1, 0), (-1, 0), (0, 1), (0, -1)) + (((1, 1), (-1, -1), (1, -1), (-1, 1)) if diag else ())
    for y in range(h):
        for x in range(w):
            if a[x, y][3] == 0:
                for dx, dy in nb:
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and a[nx, ny][3] > 0:
                        out.putpixel((x, y), col)
                        break
    return out


def pad(img, l=1, t=1, r=1, b=1):
    out = new(img.width + l + r, img.height + t + b)
    out.paste(img, (l, t), img)
    return out


def ascii_sprite(rows, pal):
    h = len(rows)
    w = max(len(r) for r in rows)
    img = new(w, h)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch != "." and ch != " " and ch in pal:
                img.putpixel((x, y), pal[ch])
    return img


def rows_sprite(rows, key):
    """a sprite drawn as text rows at native size: each character maps to a master-palette name in `key`
    ("." = empty), materials only; the one-pixel ol0 exterior outline is added around them (MV-178)"""
    return outline_alpha(ascii_sprite(rows, {k: c(v) for k, v in key.items()}))


def flip(img):
    return img.transpose(Image.FLIP_LEFT_RIGHT)


def paste(dst, src, x, y):
    dst.paste(src, (int(x), int(y)), src)


# ------------------------------------------------------------------ palette snapping
_qcache = {}


def _nearest(rgb):
    v = _qcache.get(rgb)
    if v is not None:
        return v
    best = None
    bd = 1e18
    r, g, b = rgb
    for p in PALETTE:
        # perceptual-ish weights
        dr, dg, db = r - p[0], g - p[1], b - p[2]
        d = 2 * dr * dr + 4 * dg * dg + 3 * db * db
        if d < bd:
            bd = d
            best = p
    _qcache[rgb] = best
    return best


def quantize(img, alpha_cut=96, keep_alpha=False):
    """snap every pixel to the master palette; alpha becomes 0/255 unless keep_alpha"""
    out = img.copy()
    pix = out.load()
    w, h = out.size
    for y in range(h):
        for x in range(w):
            p = pix[x, y]
            if p[3] < alpha_cut and not keep_alpha:
                pix[x, y] = CLEAR
                continue
            if p[3] == 0:
                continue
            q = _nearest(p[:3])
            pix[x, y] = (q[0], q[1], q[2], 255 if not keep_alpha else p[3])
    return out


# ------------------------------------------------------------------ atlas
atlas_items = {}


OVERRIDES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "pixellab", "overrides")
# approved V2 scene art, cleaned to native size by tools/art/v2_native.py (MV-189): events, encounters,
# expedition interiors and landmarks use these committed files instead of the old procedural scenes
V2_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "v2")


def v2_art(key, size):
    """the committed V2 image for `key` (event_<name> / exp_<name> / lm_<name>), or None"""
    p = os.path.join(V2_DIR, key + ".png")
    if not os.path.exists(p):
        return None
    img = Image.open(p).convert("RGBA")
    if img.size != tuple(size):
        raise ValueError(f"V2 art {key}.png is {img.size}, the slot is {tuple(size)}")
    return img


def add(name, img, q=True):
    # a sprite redrawn with tools/pixellab.py and accepted replaces the drawn one (same size, so the
    # atlas layout and every hardcoded coordinate stay valid); MV_NO_OVERRIDES=1 builds the drawn set
    ov = os.path.join(OVERRIDES, name + ".png")
    if os.path.exists(ov) and not os.environ.get("MV_NO_OVERRIDES"):
        o = Image.open(ov).convert("RGBA")
        if o.size == img.size:
            img = o
        else:
            print(f"pixellab override {name}.png is {o.size}, sprite is {img.size}: ignored")
    if name.startswith("lm_"):
        v2 = v2_art(name, img.size)
        img = img if v2 is None else v2
    atlas_items[name] = quantize(img) if q else img


def pack_atlas(max_w=2048):
    import json
    items = sorted(atlas_items.items(), key=lambda kv: (-kv[1].height, -kv[1].width, kv[0]))
    rows = []
    y = 0
    padd = 1     # MV-473: nearest filtering never samples a neighbour; 1 px keeps the sheet at 2048 tall
    regions = {}
    for name, im in items:
        # First-fit decreasing shelves reclaim gaps in earlier rows. Small mod strips
        # must not double the 2048 atlas just because the final shelf is full (MV-565).
        row = next((r for r in rows if im.height <= r[2] and r[0] + im.width + padd <= max_w), None)
        if row is None:
            row = [0, y, im.height]
            rows.append(row)
            y += im.height + padd
        regions[name] = (row[0], row[1], im.width, im.height)
        row[0] += im.width + padd
    H = y - padd
    # Retain MV-563's 64px height rounding for the grown five-floor shells.
    H2 = (H + 63) // 64 * 64
    sheet = new(max_w, H2)
    for name, im in items:
        rx, ry, _, _ = regions[name]
        sheet.paste(im, (rx, ry))
    sheet.save(os.path.join(OUT_ATLAS, "atlas.png"), optimize=True)
    with open(os.path.join(OUT_ATLAS, "atlas.json"), "w") as f:
        json.dump({k: list(v) for k, v in sorted(regions.items())}, f, indent=0)
    print("atlas", sheet.size, len(regions), "regions")


def save(img, path, q=True):
    folder = os.path.basename(os.path.dirname(path))
    stem = os.path.splitext(os.path.basename(path))[0]
    key = {"events": "event_" + stem, "exp": stem}.get(folder)
    if key:
        v2 = v2_art(key, img.size)
        img = img if v2 is None else v2
    (quantize(img) if q else img).save(path, optimize=True)
