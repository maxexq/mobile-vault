#!/usr/bin/env python3
"""MV-740 Road train shell cleanup (Parames 2026-11-09, code only, 0 PixelLab gens).

Run after designs/road-train/game/shell.py has written assets/vehicles/road_train_v3/{body_f1..3,trailer_f2..3}.png:
    python3 tools/art/road_train/cleanup.py          -> rewrites those shells in place
1) see-through pixel holes: every small transparent pocket inside the body (<= 14 px, not a room window) and every
   1-2 px slit below the roof line is filled from its neighbours; the cab windshield (keyed out with the background
   by shell.py) gets its glass back
2) the lead trailer's rear (the body ends at x 694): the caged ladder had no outer rail and the step bar ran off the
   edge -> outer rail + outline, bar capped. The air lines stay: they run on into the trailer behind (with no trailer
   the game caps their ends with couplers, scripts/world/rt_couplings.gd)
3) the dark far-side landing leg shadow behind the near leg (stray dark pixels) is removed
4) the container trailer's nose loses the lead trailer's ladder cage scraps that shell.py's cut left on it
6) trailer_link_f<n>.png: a container trailer with another behind it ends in a B-link beam, not a rear end (link())
5) every room window gets a steel frame like the Decker bus (MV-739): 1 px black + 2 px riveted steel around the
   opening, and a soft inner shadow on its top / sides so the rooms sit inside the box instead of floating
Coordinates are measured on the 2-deck shells; rows below the top deck shift 112 px per deck (the tractor and the
chassis are bottom-aligned), so y = y2 + dy with dy = 112 * (decks - 2).
"""
import json, os, sys
from collections import deque
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
D = os.path.join(ROOT, "assets", "vehicles", "road_train_v3")
CW, CH = 144, 96
OUT = (14, 12, 12, 255)
STEEL = (85, 81, 69, 255); LIGHT = (128, 122, 104, 255); SHADE = (52, 47, 38, 255); RIVET = (158, 150, 126, 255)
GLASS = (54, 58, 70, 255); GLASS_HI = (88, 94, 108, 255)
WHEELS = {"body": (80.0, 252.0, 303.5, 556.5, 600.5, 643.5), "trailer": (331.5, 377.5, 421.5)}
WHEEL_R = 24.0
ROOF2 = 97                     # the 2-deck roof slab top (box columns); gear above it keeps its gaps


def cells(kind, n):
    return json.load(open(os.path.join(D, "shell.json")))[kind][str(n)]["cells"]


def win_mask(kind, n, W, H):
    m = bytearray(W * H)
    for c in cells(kind, n):
        for y in range(c["y"], c["y"] + CH):
            for x in range(c["x"], c["x"] + CW):
                m[y * W + x] = 1
    return m


def in_wheel(kind, x, y, H):
    cy = H - 22.5
    return any((x + .5 - cx) ** 2 + (y + .5 - cy) ** 2 <= WHEEL_R ** 2 for cx in WHEELS[kind])


def avg_fill(px, pts, W, H):
    todo = set(pts)
    while todo:
        done = []
        for x, y in todo:
            nb = [px[a, b] for a, b in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))
                  if 0 <= a < W and 0 <= b < H and (a, b) not in todo and px[a, b][3] > 0]
            if nb:
                done.append(((x, y), tuple(sum(c[i] for c in nb) // len(nb) for i in range(3)) + (255,)))
        if not done:
            break
        for p, c in done:
            px[p] = c; todo.discard(p)


def pockets(px, W, H, win):
    seen = bytearray(W * H); out = []
    for sy in range(H):
        for sx in range(W):
            if seen[sy * W + sx] or px[sx, sy][3] > 0:
                continue
            q = deque([(sx, sy)]); seen[sy * W + sx] = 1; pts = []; edge = inwin = False
            while q:
                x, y = q.popleft(); pts.append((x, y))
                edge |= x in (0, W - 1) or y in (0, H - 1); inwin |= bool(win[y * W + x])
                for a, b in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= a < W and 0 <= b < H and not seen[b * W + a] and px[a, b][3] == 0:
                        seen[b * W + a] = 1; q.append((a, b))
            if not edge and not inwin:
                out.append(pts)
    return out


def holes(kind, n, im):
    px = im.load(); W, H = im.size; win = win_mask(kind, n, W, H); dy = 112 * (n - 2)
    roof = ROOF2                                           # the roof slab top never moves (decks grow downwards)
    filled = 0
    for pts in pockets(px, W, H, win):
        big = len(pts) > 14
        cx = sum(p[0] for p in pts) / len(pts); cy = sum(p[1] for p in pts) / len(pts)
        if kind == "body" and 118 <= cx <= 150 and 225 + dy <= cy <= 275 + dy:      # cab windshield
            for x, y in pts:
                px[x, y] = GLASS_HI if (x + y) % 9 == 0 else GLASS
            filled += len(pts); continue
        if big:
            continue                                                                # roof gear, bull bar, couplers
        avg_fill(px, pts, W, H); filled += len(pts)
    # 1-2 px slits below the roof line (open to the outside, so not pockets): both sides opaque
    for _ in range(4):
        add = []
        for y in range(roof + 4, H - 1):
            for x in range(1, W - 1):
                if px[x, y][3] or win[y * W + x] or in_wheel(kind, x, y, H):
                    continue
                if kind == "body" and x < 216 and y < 200 + dy:
                    continue
                lr = px[x - 1, y][3] and px[x + 1, y][3]
                ud = px[x, y - 1][3] and px[x, y + 1][3]
                if lr or ud:
                    add.append((x, y))
        avg_fill(px, add, W, H); filled += len(add)
    return filled


def cab_glass(im, n):
    """the windshield + side glass were keyed out with the sky: fill every row of the cab top between its pillars"""
    px = im.load(); dy = 112 * (n - 2)
    for y in range(226 + dy, 268 + dy):
        xs = [x for x in range(122, 190) if px[x, y][3]]
        if not xs:
            continue
        for x in range(xs[0], xs[-1]):
            if px[x, y][3] == 0:
                px[x, y] = GLASS_HI if (x + y) % 9 == 0 else GLASS


def body_rear(im, n):
    px = im.load(); W, H = im.size; dy = 112 * (n - 2)
    top = 102                                              # the roof never moves, the chassis rows do
    cage_bot = 321 + dy
    for y in range(top, cage_bot + 1):                     # the cage's outer rail: steel + outline
        if px[691, y][3] or px[692, y][3]:
            if not px[692, y][3]:
                px[692, y] = STEEL
            px[693, y] = OUT
    for x in range(682, 694):                              # cap the cage on top
        if px[x, top + 1][3]:
            px[x, top] = OUT
    for y in range(cage_bot + 21, H):                      # step bar: closed end
        if px[692, y][3]:
            px[693, y] = OUT


def leg_shadow(im, n):
    px = im.load(); dy = 112 * (n - 2)
    for y in range(363 + dy, 374 + dy):
        for x in range(352, 372):
            c = px[x, y]
            if c[3] and sum(c[:3]) <= 90:
                px[x, y] = (0, 0, 0, 0)
    for y in range(356 + dy, 363 + dy):                    # dark rim left over right of the brace
        for x in range(356, 372):
            c = px[x, y]
            if c[3] and sum(c[:3]) <= 90 and not any(sum(px[a, y][:3]) > 90 and px[a, y][3] for a in range(x - 2, x)):
                px[x, y] = (0, 0, 0, 0)


def trailer_nose(im, n):
    """the trailer canvas starts with a strip of the lead trailer's ladder cage + a 1 px edge line (shell.py cut the
    B-double at x 694): they float in the air behind another container trailer -> cleared (the body has its own rail)"""
    px = im.load(); dy = im.size[1] - 380
    for y in range(99, 305 + dy):
        for x in range(0, 9):
            px[x, y] = (0, 0, 0, 0)


def ring(px, x, y, d, tl, x0, y0, x1, y1):
    if d == 1:
        px[x, y] = (8, 8, 10, 255); return
    c = LIGHT if tl else SHADE
    along = x if y in (y0 - 2, y1 + 1) else y
    if along % 12 == 6 and x0 - 2 < x < x1 + 1 and y0 - 2 < y < y1 + 1:
        c = RIVET
    px[x, y] = c


def blend(px, x, y, a):
    if px[x, y][3] == 0:
        px[x, y] = (8, 6, 6, a)


def frames(kind, n, im):
    px = im.load()
    for c in cells(kind, n):
        x0, y0 = c["x"], c["y"]; x1, y1 = x0 + CW, y0 + CH
        for d in (1, 2):
            for x in range(x0 - d, x1 + d):
                for y in (y0 - d, y1 + d - 1):
                    ring(px, x, y, d, y == y0 - d, x0, y0, x1, y1)
            for y in range(y0 - d, y1 + d):
                for x in (x0 - d, x1 + d - 1):
                    ring(px, x, y, d, x == x0 - d, x0, y0, x1, y1)
        for x in range(x0, x1):
            for i, a in enumerate((150, 90, 40)):
                blend(px, x, y0 + i, a)
            blend(px, x, y1 - 1, 60)
        for y in range(y0 + 3, y1 - 1):
            for i, a in enumerate((90, 35)):
                blend(px, x0 + i, y, a); blend(px, x1 - 1 - i, y, a)


LINK_BEAM = (342, 358)                                    # the nose beam rows (2 decks) that sit on the unit in front


def link(n):
    """MV-740 round 3 (Parames: redo the joint between container trailers): a container trailer with another one behind
    it ends in a B-link instead of a truck's rear end -> trailer_link_f<n>.png. The ROAD TRAIN plate, the lower tail
    lamp, the bumper legs and the tow hook go; the side lip runs on to the end post, a dark underframe fills below it,
    and the chassis beam (the same steel as the nose beam of the unit behind, rows 342-357) runs out to the canvas edge
    with a fifth-wheel plate on its tail, so the next trailer's nose sits on it like the lead trailer's joint."""
    im = Image.open(os.path.join(D, f"trailer_f{n}.png")).convert("RGBA")
    W, H = im.size; px = im.load(); dy = H - 380
    src = im.copy().load()
    b0, b1 = LINK_BEAM[0] + dy, LINK_BEAM[1] + dy
    for y in range(325 + dy, H):                          # 1) clear the rear end under the last window
        for x in range(446, W):
            if not (x >= 475 and y <= 337 + dy):
                px[x, y] = (0, 0, 0, 0)
    for y in range(325 + dy, 334 + dy):                   # 2) the side lip runs on to the end post
        for x in range(446, 475):
            px[x, y] = src[416 + (x - 446) % 28, y]
    for y in range(334 + dy, b0):                         # 3) underframe in shadow between the lip and the beam
        for x in range(446, 475):
            px[x, y] = (28, 27, 21, 255) if (x + y) % 5 else (35, 32, 26, 255)
    for y in range(b0, b1):                               # 4) the B-link beam, tiled from the nose beam
        for x in range(446, W):
            px[x, y] = src[21 + (x - 446) % 9, y]
    for y in range(b0, b1):                               # left end cap of the beam
        px[446, y] = OUT
    for x in range(446, W):                               # top / bottom outline rows stay crisp
        px[x, b0] = OUT; px[x, b1 - 2] = OUT
    for x in range(483, W):                               # 5) fifth-wheel plate on the tail of the beam
        px[x, b0 - 4] = OUT; px[x, b0 - 3] = LIGHT; px[x, b0 - 2] = STEEL; px[x, b0 - 1] = SHADE
    px[483, b0 - 3] = OUT; px[483, b0 - 2] = OUT; px[483, b0 - 1] = OUT
    for x in range(448, 470, 7):                          # bolts along the beam
        px[x, b0 + 4] = RIVET
    for y in range(284 + dy, 310 + dy):                   # 6) the upper tail lamp stays as an unlit marker lamp
        for x in range(480, W):
            r, g, b, al = px[x, y]
            if al and r > 140 and g < 90:
                px[x, y] = (r * 9 // 20, g // 2, b // 2, al)
    im.save(os.path.join(D, f"trailer_link_f{n}.png"))
    print("trailer_link", n)


def run(kind, n):
    p = os.path.join(D, f"{kind}_f{n}.png")
    im = Image.open(p).convert("RGBA")
    f = holes(kind, n, im)
    if kind == "body":
        cab_glass(im, n); leg_shadow(im, n)
        if n >= 2:                                         # (the 1-deck body has no rear ladder cage)
            body_rear(im, n)
            f += holes(kind, n, im)                        # slits the new rail closed off between the air lines
    else:
        trailer_nose(im, n)
    frames(kind, n, im)
    im.save(p)
    print(kind, n, "filled", f)


if __name__ == "__main__":
    if sys.argv[1:] != ["link"]:
        for n in (1, 2, 3):
            run("body", n)
    if sys.argv[1:] != ["link"]:                           # `cleanup.py link` only rebuilds the B-link variants
        for n in (2, 3):
            run("trailer", n)
    for n in (2, 3):
        link(n)
