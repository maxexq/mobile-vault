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
4) (Parames 19:55-19:56) roof + lantern:
   - solar: the edge-on rail over the water tank becomes the PixelLab array solar_pl.png (Pro inpaint-v3 take s2 of
     the 256x64 crop at shell (286,0); only x 296..447, y 2..27 is used, its sky keyed out). Same spot on 1-5 floors.
   - the orange ghost arc (and the dash under it) floating left of the tank pipe is removed.
   - the lantern loses the dark brown disc behind it (it read as a box / dead glow) and hangs from a hook; its light
     is the game's additive glow + the PixelLab flame flicker (lantern_pl.png, tools/ambulance_anim.py).
The rear (x >= 592) is not touched apart from frames, so the pup trailer's tow plate (x 600-621) still lines up.
"""
import json, os, sys
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


HERE = os.path.dirname(os.path.abspath(__file__))
SKY = (46, 44, 48)


def solar(im, take=os.path.join(HERE, "solar_pl.png"), x0=286):
    tp = Image.open(take).convert("RGB").load(); sp = im.load()
    for y in range(2, 28):
        for x in range(296, 448):
            p = tp[x - x0, y]
            sky = sum(abs(a - b) for a, b in zip(p, SKY)) <= 18 or min(p) >= 190
            sp[x, y] = (0, 0, 0, 0) if sky else p + (255,)


def ghost_arc(im, box=(266, 28, 290, 48)):
    a = np.array(im)[:, :, 3] > 0
    lab, k = nd.label(a, structure=EIGHT)
    sub = lab[box[1]:box[3], box[0]:box[2]]
    ids = [i for i in np.unique(sub) if i and (lab == i).sum() <= 60]
    arr = np.array(im); arr[np.isin(lab, ids)] = 0
    return Image.fromarray(arr).copy()


YEL = lambda p: p[0] > 200 and p[1] > 160 and p[2] < 170 and p[0] - p[2] > 50
PLATE = lambda p: 140 < sum(p[:3]) < 215 and max(p[:3]) - min(p[:3]) < 40


def lantern(im):
    """removes the brown disc behind the roof lantern: flood from the sky through plate-coloured pixels (the lantern's
    black outline stops it), then the disc's own dark rim, then a hook up to the bracket"""
    px = im.load()
    pts = [(x, y) for y in range(60, 110) for x in range(100, 126) if px[x, y][3] and YEL(px[x, y])]
    cx = sum(p[0] for p in pts) / len(pts) + 0.5; cy = sum(p[1] for p in pts) / len(pts) + 0.5
    inside = lambda x, y: (x + .5 - cx) ** 2 + (y + .5 - cy) ** 2 <= 13 ** 2 and y >= cy - 8 and x < 124
    st = [(x, y) for y in range(int(cy) - 14, int(cy) + 15) for x in range(int(cx) - 14, int(cx) + 15) if inside(x, y) and px[x, y][3] == 0]
    seen = set()
    while st:
        x, y = st.pop()
        if (x, y) in seen or not inside(x, y): continue
        seen.add((x, y)); p = px[x, y]
        if p[3] and not (PLATE(p) and not p[1] > p[0] + 8): continue
        px[x, y] = (0, 0, 0, 0); st += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    for _ in range(2):                                  # the disc's dark rim: pixels left mostly alone in the sky
        kill = []
        for y in range(int(cy) - 13, int(cy) + 14):
            for x in range(int(cx) - 13, 124):
                if not inside(x, y) or not px[x, y][3] or px[x, y][1] > px[x, y][0] + 8: continue
                empty = sum(1 for dx in (-1, 0, 1) for dy in (-1, 0, 1) if (dx or dy) and px[x + dx, y + dy][3] == 0)
                if empty >= 5: kill.append((x, y))
        for q in kill: px[q] = (0, 0, 0, 0)
    hx = int(cx)                                        # hook: lantern top up to the bracket
    top = next(y for y in range(int(cy) - 12, int(cy)) if px[hx, y][3] and inside(hx, y))
    y = top - 1
    while y > top - 6 and px[hx, y][3] == 0:
        px[hx, y] = (14, 12, 10, 255); y -= 1
    return cx, cy


def swap_lantern(im, still=os.path.join(HERE, "lantern_still.png")):
    """(Parames 20:14 "swing it while driving") every shell gets the same approved lantern (lantern_still.png, 9x16,
    bail on top) hung right under its bracket, so AmbulanceMotion can cut it out and swing it from the bail.
    The bracket's underside is known per art: 1-2 floor shells (f1 art) 9 rows above the glass centre, 3-5 floor
    shells (f3 art, smaller old lantern) 7 rows above. Returns the still's top-left in the shell."""
    px = im.load(); st = Image.open(still).convert("RGBA"); sp = st.load()
    pts = [(x, y) for y in range(60, 110) for x in range(100, 126) if px[x, y][3] and YEL(px[x, y])]
    cx = (min(p[0] for p in pts) + max(p[0] for p in pts) + 1) // 2
    cy = (min(p[1] for p in pts) + max(p[1] for p in pts) + 1) // 2
    floors = (im.height - 240) // 112 + 1
    y0 = cy - (9 if floors <= 2 else 7); x0 = cx - 4
    for y in range(y0, cy + 9):                     # the old lantern goes
        for x in range(cx - 5, cx + 5): px[x, y] = (0, 0, 0, 0)
    for y in range(st.height):
        for x in range(st.width):
            if sp[x, y][3]: px[x0 + x, y0 + y] = sp[x, y]
    return x0, y0


def bake_driver(im, strip=os.path.join(D, "driver.png")):
    """Dr. Ren at the wheel (driver.py, approved A2 'still' frame 0) in the cab glass, so every view has a driver;
    AmbulanceMotion animates over it when vehicle_anim is on"""
    if not os.path.exists(strip):
        return
    st = Image.open(strip).convert("RGBA")
    cell = st.crop((0, 26 * 3, 30, 26 * 4))          # row 3 = still
    im.alpha_composite(cell, (87, im.height - 139))


ROOF = os.path.join(HERE, "roof")


def old_flag(im):
    """the old flag cloth: (rect x0, y0, x1, y1) of the opaque pixels right of the pole around the red cross"""
    px = im.load(); red = [(x, y) for x in range(133, 160) for y in range(0, 60)
                         if px[x, y][3] and px[x, y][0] > 135 and px[x, y][1] < 60 and px[x, y][2] < 55]
    cy = sum(y for _, y in red) // len(red)
    pts = [(x, y) for x in range(133, 165) for y in range(cy - 14, cy + 14) if px[x, y][3]]
    return min(x for x, _ in pts), min(y for _, y in pts), max(x for x, _ in pts) + 1, max(y for _, y in pts) + 1


def pipe_knob(im, box=(448, 0, 472, 6)):
    """MV-741 (Parames 21:04): the copper pipe's rain-cap knob floated 2 px above the cap (rows 0-3): removed"""
    px = im.load()
    for x in range(box[0], box[2]):
        for y in range(box[1], box[3]):
            px[x, y] = (0, 0, 0, 0)


def tail_hoods(im):
    """MV-741 (Parames 21:04): brown half-disc lamp hoods stuck out behind the rear ladder at every tail lamp (x >= 618):
    removed, the red lens on the rear wall stays. The tow hitch under the last lamp (pup coupling) is not touched."""
    px = im.load(); W, H = im.size
    reds = sorted({y for y in range(H) for x in range(600, 618)
                   if px[x, y][3] and px[x, y][0] > 170 and px[x, y][1] < 80 and px[x, y][2] < 80})
    done = 0
    for y in range(H):
        if not any(abs(y - r) <= 10 for r in reds):
            continue
        for x in range(618, W):
            if px[x, y][3]:
                px[x, y] = (0, 0, 0, 0); done += 1
    # the brown lamp housing between the rear wall and the ladder (x 612-614) above / beside each red lens
    for y in range(H):
        if not any(-8 <= y - r <= 6 for r in reds):
            continue
        for x in range(612, 615):
            q = px[x, y]
            if q[3] and not (q[0] > 170 and q[1] < 80) and q[:3] not in ((56, 5, 5), (83, 3, 3)):
                px[x, y] = (0, 0, 0, 0); done += 1
    return done


def roof_parts(im):
    """MV-741 round 3 (Parames 20:32 + picks 20:41): the PixelLab roof parts (roof/<part>_still.png, Pro inpaint-v3):
    flag 3, left pots 2, birdhouses 1, right pots 2, mast 3. Pots, birdhouses and mast replace their mask boxes
    (same place on every shell); the flag replaces the old cloth and sits as much lower as the old flag did (taller shells
    carry a shorter pole). AmbulanceMotion animates them from roof/<part>_anim.png (tools/ambulance_anim.py)."""
    meta = json.load(open(os.path.join(ROOF, "roof.json")))
    px = im.load(); mine = set()
    x0, y0, x1, y1 = old_flag(im)
    dy = y0 - 16                                                    # the f1 cloth top is row 16
    for x in range(x0, x1):
        for y in range(y0, y1):
            px[x, y] = (0, 0, 0, 0)
    for p, m in meta.items():
        st = Image.open(os.path.join(ROOF, p + "_still.png")).convert("RGBA"); sp = st.load()
        ax, ay = m["at"]
        if p == "flag":
            ay += dy
            for x in range(st.width):
                for y in range(st.height):
                    if sp[x, y][3]:
                        px[ax + x, ay + y] = sp[x, y]; mine.add((ax + x, ay + y))
            continue
        for bx0, by0, bx1, by1 in m["masks"]:          # where two parts' boxes overlap, an opaque pixel wins
            for x in range(bx0, bx1):
                for y in range(by0, by1):
                    if sp[x - ax, y - ay][3] or (x, y) not in mine:
                        px[x, y] = sp[x - ax, y - ay]
                    if sp[x - ax, y - ay][3]:
                        mine.add((x, y))
    return dy


def clean_shell(path, front):
    im = Image.open(path).convert("RGBA")
    solar(im)
    im = ghost_arc(im)
    lantern(im)
    swap_lantern(im)
    bake_driver(im)
    top = im.height - front.height
    holes = fill_holes(im, front, top)
    im, strays = drop_strays(im)
    rects = openings(im)
    frame(im, rects)
    pipe_knob(im)
    tail_hoods(im)
    roof_parts(im)                           # the window frames must not paint over the pot rows
    from pinholes import clean as pinholes
    pinholes(im)                             # last: no see-through pocket of <= 4 px anywhere (Parames 21:14)
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
