"""MV-741 Dr. Ren ambulance shell cleanup (Parames 2026-11-09 "fix Dr. Ren's ambulance", code only, 0 PixelLab gens).

Run from anywhere AFTER tools/art/ambulance_front/apply_front.py, then rerun tools/ambulance_anim.py:
    python3 tools/art/ambulance/cleanup.py      -> rewrites assets/vehicles/ambulance_v3/shell_f1..5.png + nose.png
1) see-through holes: apply_front.py keyed out every pixel within 24 of the front art's dark backdrop, which also
   punched ~1,600 px of the cab's own dark paint (grille, wheel arch, door seams, tyre) out of the shell. Every
   transparent pocket enclosed by the cab is filled back from the approved front art (front_stock.png), or with
   the darkest neighbour where that art has nothing. Elsewhere small enclosed pockets (<= 20 px: roof edge seam,
   foliage, chassis rail) are filled with their darkest opaque neighbour. Real see-through gaps stay: rear ladder
   (x >= 592), mast guy wires, roof flag bunting, tank railing, and the room openings.
2) stray pixels: specks of <= 3 px that touch nothing (dust over the roof garden / tank, dots under the cab) go.
3) room frames: every room opening gets the same frame as the Decker (MV-739): 1 px black lip + 2 px riveted
   steel around the opening and a soft inner shadow on its top / sides, so the rooms sit inside the body.
The rear (x >= 592) is not touched apart from frames, so the pup trailer's tow plate (x 600-621) still lines up.
"""
import os, sys
import numpy as np
from PIL import Image
from scipy import ndimage as nd

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../.."))
D = os.path.join(ROOT, "assets/vehicles/ambulance_v3")
FRONT = sys.argv[1] if len(sys.argv) > 1 else "/mnt/project-files/designs/vehicle-upgrades/ext/approved/front_stock.png"
PAD, NOSE, FRONT_W = 48, 12, 176           # front_stock canvas: 48 px pad on the left, shell x 0..175
STEEL = (85, 81, 69, 255); LIGHT = (128, 122, 104, 255); SHADE = (52, 47, 38, 255); RIVET = (158, 150, 126, 255)
LIP = (8, 8, 10, 255)
EIGHT = np.ones((3, 3), bool)


def darkest_neighbour(px, x, y, W, H):
    best = None
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            a, b = x + dx, y + dy
            if 0 <= a < W and 0 <= b < H and px[a, b][3] == 255:
                if best is None or sum(px[a, b][:3]) < sum(best[:3]):
                    best = px[a, b]
    return best


def fill_holes(im, front, top, x_off=0):
    """front: front_stock pixels, `top` = shell row of front_stock row 0, x_off = shell x of front_stock x PAD"""
    px = im.load(); W, H = im.size; fp = front.load()
    a = np.array(im)[:, :, 3] > 0
    tl, _ = nd.label(~a)
    edge = set(np.unique(np.concatenate([tl[0], tl[-1], tl[:, 0], tl[:, -1]])))
    filled = 0
    for i, sl in enumerate(nd.find_objects(tl)):
        lab = i + 1
        if sl is None or lab in edge:
            continue
        ys, xs = np.nonzero(tl[sl] == lab)
        ys = ys + sl[0].start; xs = xs + sl[1].start
        n = len(xs); x0 = xs.min()
        in_front = xs.max() < FRONT_W + x_off and ys.min() >= top
        if n > 400 or x0 >= 592 + x_off:                 # room openings / rear ladder
            continue
        if not in_front and n > 20:                     # mast wires, bunting, tank railing: real gaps
            continue
        pend = list(zip(xs.tolist(), ys.tolist()))
        for x, y in pend:                               # front art first
            fx, fy = x - x_off + PAD, y - top
            if in_front and 0 <= fy < front.height and 0 <= fx < front.width:
                px[x, y] = fp[fx, fy][:3] + (255,)
        rest = [p for p in pend if px[p[0], p[1]][3] == 0]
        while rest:                                     # then grow in from the edge
            nxt = []
            for x, y in rest:
                c = darkest_neighbour(px, x, y, W, H)
                if c is None: nxt.append((x, y))
                else: px[x, y] = c
            if len(nxt) == len(rest): break
            rest = nxt
        filled += n
    return filled


def drop_strays(im, max_px=3):
    a = np.array(im)[:, :, 3] > 0
    lab, k = nd.label(a, structure=EIGHT)
    sizes = nd.sum(a, lab, range(1, k + 1))
    small = [i + 1 for i, s in enumerate(sizes) if s <= max_px]
    arr = np.array(im); m = np.isin(lab, small); arr[m] = 0
    return Image.fromarray(arr).copy(), int(m.sum())


def openings(im):
    a = np.array(im)[:, :, 3] > 0
    tl, _ = nd.label(~a)
    out = []
    for i, sl in enumerate(nd.find_objects(tl)):
        if sl is None: continue
        h, w = sl[0].stop - sl[0].start, sl[1].stop - sl[1].start
        if 120 <= w <= 160 and 80 <= h <= 100:
            out.append((sl[1].start, sl[0].start, sl[1].stop, sl[0].stop))
    return sorted(out, key=lambda r: (r[1], r[0]))


def frame(im, rects):
    px = im.load()
    for x0, y0, x1, y1 in rects:
        for d in (1, 2, 3):
            for x in range(x0 - d, x1 + d):
                for y in (y0 - d, y1 + d - 1):
                    ring(px, x, y, d, y == y0 - d, x0, y0, x1, y1)
            for y in range(y0 - d, y1 + d):
                for x in (x0 - d, x1 + d - 1):
                    ring(px, x, y, d, x == x0 - d, x0, y0, x1, y1)
        for x in range(x0, x1):                         # the lip's shadow over the room's top / bottom
            for i, al in enumerate((150, 90, 40)): blend(px, x, y0 + i, al)
            blend(px, x, y1 - 1, 60)
        for y in range(y0 + 3, y1 - 1):
            for i, al in enumerate((90, 35)): blend(px, x0 + i, y, al); blend(px, x1 - 1 - i, y, al)


def ring(px, x, y, d, tl, x0, y0, x1, y1):
    if d == 1: px[x, y] = LIP; return
    if d == 2:
        c = LIGHT if tl else SHADE
        along = x if y in (y0 - 2, y1 + 1) else y
        if along % 12 == 6 and x0 - 2 < x < x1 + 1 and y0 - 2 < y < y1 + 1: c = RIVET
        px[x, y] = c; return
    if px[x, y][3] == 0 or sum(px[x, y][:3]) > 360: px[x, y] = STEEL   # d=3: only gaps / pale paint, keeps beams


def blend(px, x, y, al):
    if px[x, y][3] == 0: px[x, y] = (8, 6, 6, al)


def clean_shell(path, front):
    im = Image.open(path).convert("RGBA")
    top = im.height - front.height
    holes = fill_holes(im, front, top)
    im, strays = drop_strays(im)
    rects = openings(im)
    frame(im, rects)
    im.save(path)
    return holes, strays, len(rects)


def clean_nose(path, front):
    im = Image.open(path).convert("RGBA")
    pad = Image.new("RGBA", (im.width + 2, im.height + 2)); pad.alpha_composite(im, (1, 1))
    holes = 0
    px = pad.load(); fp = front.load()
    a = np.array(pad)[:, :, 3] > 0
    tl, _ = nd.label(~a); edge = tl[0, 0]
    for y in range(pad.height):
        for x in range(pad.width):
            if tl[y, x] and tl[y, x] != edge:
                p = fp[PAD - NOSE + x - 1, y - 1]; px[x, y] = p[:3] + (255,); holes += 1
    pad, strays = drop_strays(pad)
    pad.crop((1, 1, im.width + 1, im.height + 1)).save(path)
    return holes, strays


if __name__ == "__main__":
    front = Image.open(FRONT).convert("RGBA")
    for n in range(1, 6):
        print(f"shell_f{n}: holes filled, strays removed, frames =", clean_shell(f"{D}/shell_f{n}.png", front))
    print("nose: holes, strays =", clean_nose(f"{D}/nose.png", front))
