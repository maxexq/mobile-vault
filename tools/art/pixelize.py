"""Turn an AI / painted image into true pixel art for Mobile Vault.

    python pixelize.py in.png out.png --size 96x78 [--palette palette.txt] [--alpha 128] [--preview 4]

1. crop to the target aspect ratio and cut the image into a size.w x size.h grid
2. each cell takes its most common colour (mode), not the average, so edges stay hard
3. every colour snaps to the locked palette (nearest in a perceptual-ish weighted RGB)
4. alpha becomes 0 or 255 (no soft fringe), stray single pixels with no same-colour neighbour are merged

Palette file: one hex colour per line (#rrggbb), '#' comments allowed. Without one, the master palette
from tools/art/common.py is used when the script sits in that folder.
"""
import argparse, collections, os, sys
from PIL import Image


def load_palette(path):
    if path:
        cols = []
        for ln in open(path, encoding="utf-8"):
            ln = ln.split("//")[0].strip()
            if len(ln.lstrip("#")) == 6:
                s = ln.lstrip("#")
                cols.append((int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16)))
        return cols
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
    from tools.art.common import PALETTE
    return list(PALETTE)


def nearest(rgb, pal, cache):
    if rgb in cache:
        return cache[rgb]
    r, g, b = rgb
    best, bd = pal[0], 1e18
    for p in pal:
        rm = (r + p[0]) / 2
        d = (2 + rm / 256) * (r - p[0]) ** 2 + 4 * (g - p[1]) ** 2 + (2 + (255 - rm) / 256) * (b - p[2]) ** 2
        if d < bd:
            best, bd = p, d
    cache[rgb] = best
    return best


def crop_aspect(img, w, h):
    iw, ih = img.size
    if iw * h > ih * w:
        nw = ih * w // h
        x = (iw - nw) // 2
        return img.crop((x, 0, x + nw, ih))
    nh = iw * h // w
    y = (ih - nh) // 2
    return img.crop((0, y, iw, y + nh))


def pixelize(img, w, h, pal, alpha_cut=128, keep_lines=0.0):
    img = crop_aspect(img.convert("RGBA"), w, h)
    iw, ih = img.size
    src = img.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dst = out.load()
    cache = {}
    for y in range(h):
        y0, y1 = y * ih // h, max(y * ih // h + 1, (y + 1) * ih // h)
        for x in range(w):
            x0, x1 = x * iw // w, max(x * iw // w + 1, (x + 1) * iw // w)
            # sample the inner 60% of the cell, edges of a cell are where AI blur lives
            mx, my = ((x1 - x0) // 5, (y1 - y0) // 5) if not keep_lines else (0, 0)
            cnt, alpha = collections.Counter(), []
            for yy in range(y0 + my, max(y0 + my + 1, y1 - my)):
                for xx in range(x0 + mx, max(x0 + mx + 1, x1 - mx)):
                    r, g, b, a = src[xx, yy]
                    alpha.append(a)
                    if a >= alpha_cut:
                        cnt[nearest((r, g, b), pal, cache)] += 1
            if not cnt or sorted(alpha)[len(alpha) // 2] < alpha_cut:
                continue
            pick = cnt.most_common(1)[0][0]
            if keep_lines:
                # thin dark strokes (outlines, cracks, poles) cover a small share of a cell but carry the shape
                tot = sum(cnt.values())
                lum = lambda c: 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]
                for col, n in cnt.most_common():
                    if n >= tot * keep_lines and lum(col) < lum(pick) - 45:
                        pick = col
                        break
            dst[x, y] = pick + (255,)
    return despeckle(out)


def despeckle(img):
    """a lone pixel whose colour appears in none of its 8 neighbours takes the most common neighbour colour"""
    w, h = img.size
    px = img.load()
    fix = []
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            c = px[x, y]
            if c[3] == 0:
                continue
            nb = [px[x + dx, y + dy] for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dx or dy]
            if c not in nb:
                common, n = collections.Counter(nb).most_common(1)[0]
                if n >= 5:
                    fix.append((x, y, common))
    for x, y, c in fix:
        px[x, y] = c
    return img


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--size", required=True, help="WxH in art pixels, e.g. 96x78")
    ap.add_argument("--palette")
    ap.add_argument("--alpha", type=int, default=128)
    ap.add_argument("--keep-lines", type=float, default=0.0, help="e.g. 0.2: a dark colour covering 20%% of a cell wins, keeps thin strokes")
    ap.add_argument("--preview", type=int, default=0, help="also write <dst>_xN.png upscaled with nearest")
    a = ap.parse_args()
    w, h = (int(v) for v in a.size.lower().split("x"))
    res = pixelize(Image.open(a.src), w, h, load_palette(a.palette), a.alpha, a.keep_lines)
    res.save(a.dst)
    if a.preview > 1:
        base, ext = os.path.splitext(a.dst)
        res.resize((w * a.preview, h * a.preview), Image.NEAREST).save(f"{base}_x{a.preview}{ext}")
    print(f"{a.dst}: {w}x{h}, {len({c for c in res.getdata() if c[3]})} colours")
