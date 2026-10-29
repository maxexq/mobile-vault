"""Clean PixelLab shoot frames and overlay per-gun muzzle flash + ejected casings (MV-594).
usage: fx.py <clipdir> <gun> <shots comma list> <outdir>"""
import sys, os, math, json
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from PIL import Image
import common, pixelize
P = {k: v[:3] + (255,) for k, v in common.PAL.items()}
FLASHY = {P[k][:3] for k in ('lamp0', 'lamp1', 'lamp2', 'yellow3')}

def snap(im):
    out = im.copy(); px = out.load(); cache = {}
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            px[x, y] = (0, 0, 0, 0) if a < 128 else pixelize.nearest((r, g, b), common.PALETTE, cache) + (255,)
    return out

def keep_main(im):
    px = im.load(); W, H = im.size; seen = {}; comps = []
    for y in range(H):
        for x in range(W):
            if px[x, y][3] and (x, y) not in seen:
                st = [(x, y)]; seen[(x, y)] = len(comps); c = []
                while st:
                    p = st.pop(); c.append(p)
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            q = (p[0] + dx, p[1] + dy)
                            if 0 <= q[0] < W and 0 <= q[1] < H and q not in seen and px[q][3]:
                                seen[q] = len(comps); st.append(q)
                comps.append(c)
    big = max(comps, key=len)
    for c in comps:
        if c is not big:
            for p in c: px[p] = (0, 0, 0, 0)
    return im

CW, CH = 72, 60   # shoot canvas: the 60x60 start frame sits at x=0, leaving 12 px in front for the flash

def norm(im):
    """PixelLab pads wider outputs evenly on both sides; put every frame back where the 60x60 start frame was"""
    im = im.convert('RGBA'); out = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
    out.paste(im, (-((im.width - 60) // 2), CH - im.height), im)
    return out

AIM = {'level': (1, 0), 'up': (1, -1), 'down': (1, 1)}

def flashy(c):
    r, g, b = c[:3]
    return (r > 215 and g > 140 and b < 110) or min(r, g, b) > 235

SNAP = os.environ.get('SNAP') == '1'   # medic was approved snapped: its coat is the same colour as PixelLab's flash
REF_IMG = norm(Image.open(os.environ['HOLD'])) if os.environ.get('HOLD') else None   # hold pose: colours allowed in front of the body

def clean(im, aim='level'):
    # raw PixelLab colours are kept like the approved clips (the master-palette snap happens in production)
    im = snap(im.convert('RGBA')) if SNAP else im.convert('RGBA'); px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            px[x, y] = px[x, y][:3] + (255,) if px[x, y][3] >= 128 else (0, 0, 0, 0)
    # drop PixelLab's own flash/tracer pixels in front of the body
    for y in range(0, 46):
        for x in [*range(0, 26), *range(36, im.width)]:   # in front of the gun and behind the back
            if px[x, y][3] and (px[x, y][:3] in FLASHY if SNAP else flashy(px[x, y])): px[x, y] = (0, 0, 0, 0)
    return keep_main(im)

def strip_new(im, ref, tol=40):
    """drop bright pixels in front of the body whose colour the hold pose never uses (PixelLab's own casings/tracers)"""
    cols = {ref.getpixel((x, y))[:3] for x in range(ref.width) for y in range(ref.height) if ref.getpixel((x, y))[3]}
    px = im.load()
    for y in range(0, 46):
        for x in [*range(0, 22), *range(36, im.width)]:
            c = px[x, y]
            if c[3] and sum(c[:3]) > 330 and min(sum(abs(a - b) for a, b in zip(c[:3], k)) for k in cols) > tol:
                px[x, y] = (0, 0, 0, 0)
    # bright bits just above the barrel or past its tip are PixelLab casings / tracers too
    mx, my = muzzle(ref)
    for y in range(max(0, my - 8), my - 1):
        for x in range(mx - 12, im.width):
            if px[x, y][3] and sum(px[x, y][:3]) > 330: px[x, y] = (0, 0, 0, 0)
    for y in range(max(0, my - 4), my + 5):
        for x in range(mx + 3, im.width):
            if px[x, y][3] and sum(px[x, y][:3]) > 330: px[x, y] = (0, 0, 0, 0)
    return keep_main(im)

def muzzle(im, aim='level', second=False):
    """barrel tip: the opaque pixel in front of the body furthest along the aim direction.
    second=True: the other gun of a two-gun pose (tip at least 3 rows away from the first)"""
    px = im.load(); d = AIM[aim]; best = None
    skip = muzzle(im, aim)[1] if second else None
    for y in range(0, 46):
        if skip is not None and abs(y - skip) < 3: continue
        for x in range(36 if aim == 'down' else 32, im.width):
            if px[x, y][3]:
                k = (x * d[0] + y * d[1], -abs(y - 28) if aim == 'level' else 0)
                if best is None or k > best[0]: best = (k, (x, y))
    if not best: return None
    x, y = best[1]
    if aim != 'level': return x, y
    top = bot = y   # centre of the barrel end, so the flash sits on the bore
    while top > 0 and px[x, top - 1][3]: top -= 1
    while bot < im.height - 1 and px[x, bot + 1][3]: bot += 1
    return x, (top + bot + 1) // 2

def rot(dx, dy, aim):
    """turn a flash stamp drawn for a level shot to the aim angle (45 degree steps)"""
    if aim == 'level': return dx, dy
    s = -1 if aim == 'up' else 1
    return round((dx - s * dy) * 0.7071), round((s * dx + dy) * 0.7071)

# flash stamps: list of (dx, dy, colour) relative to the muzzle tip, per frame after the shot
def stamp(rows, key):
    out = []
    for dy, row in enumerate(rows):
        for dx, ch in enumerate(row):
            if ch != '.': out.append((dx, dy - len(rows) // 2, P[key[ch]]))
    return out
K = {'w': 'lamp2', 'y': 'lamp1', 'o': 'lamp0', 'r': 'dusk3', 'g': 'gray4'}
FK = {'w': 'lamp2', 'o': 'red4', 'r': 'red3', 'g': 'gray4'}
GUNS = {
  'pistol': dict(flash=[stamp(['.y..', 'wwyo', '.y..'], K), stamp(['wo'], K)],
                 casing=[('yellow3', 'yellow2')], eject_back=4, vx=-1.0, vy=-3.0, size=(2, 1)),
  'smg': dict(flash=[stamp(['.o.y..', 'ywwwyo', '.o.y..'], K), stamp(['.y.', 'wyo', '.y.'], K)],
              casing=[('yellow3', 'yellow2')], eject_back=5, vx=-1.4, vy=-2.4, size=(2, 1)),
  'shotgun': dict(flash=[stamp(['..o.r', '.yyo.', 'wwwyyo', '.yyo.', '..o.r'], K), stamp(['.o.', 'wyo', '.o.'], K), stamp(['g.g', '.g.'], K)],
                  casing=[('red3', 'yellow2')], eject_delay=3, eject_back=8, vx=-1.2, vy=-2.2, size=(3, 1)),
  'sawnoff': dict(flash=[stamp(['..o..r', '.yyo..', 'wwwyyo', 'wwwyyo', '.yyo..', '..o..r'], K), stamp(['.o.', 'wyo', 'wyo', '.o.'], K), stamp(['g.g', '.g.', 'g..'], K)],
                  casing=[], eject_back=0, vx=0, vy=0, size=(3, 1)),
  'nailgun': dict(flash=[stamp(['w.y', '.wo', 'y.w'], K), stamp(['.o', 'y.'], K)],
                  casing=[], eject_back=0, vx=0, vy=0, size=(2, 1)),
  'flamer': dict(flash=[stamp(['..o.....', '.oyyo...', 'oywwyo..', '.oyyo...', '..o.....'], K),
                        stamp(['....o.o..r..', '..ooyyoo.r..', '.oyyyyyyoo.r', 'oywwwwyyyoor', '.oyyyyyyoo.r', '..ooyyoo.r..', '....o.o..r..'], K),
                        stamp(['...o..o..r..r.', '..ooyyyoooo.r.', '.oyyyywyyyoorr', 'oywwwwwwyyyoor', '.oyyyywyyyoorr', '..ooyyyoooo.r.', '...o..o..r..r.'], K),
                        stamp(['....r..g.g..', '..ooo.r..g.g', '.oyyoorr.g..', 'oyyyoorg.g.g', '.oyyoorr.g..', '..ooo.r..g.g', '....r..g....'], K)],
                 casing=[], eject_back=0, vx=0, vy=0, size=(2, 1)),
  'flintlock': dict(flash=[stamp(['..y..', '.wwyo', 'owwwyo', '.wwyo', '..y..'], K),
                           stamp(['.g.g..', 'gyog.g', '.g.g..'], K),
                           stamp(['..g.g...', '.g.g.g..', 'g.g.g.g.', '.g.g.g..', '..g.g...'], K),
                           stamp(['...g.g...', '..g...g..', '.g..g..g.', '..g...g..'], K)],
                    casing=[], eject_back=0, vx=0, vy=0, size=(2, 1)),
  'revolver': dict(flash=[stamp(['..y..', '.wwyo', 'oywwyo', '.wwyo', '..y..'][1:4], K), stamp(['wo'], K)],
                   casing=[], eject_back=0, vx=0, vy=0, size=(2, 1)),
  'boltrifle': dict(flash=[stamp(['.y..o', 'wwwyyo', '.y..o'], K), stamp(['wyo'], K), stamp(['g.g', '.g.'], K)],
                    casing=[('yellow3', 'yellow2')], eject_delay=3, eject_back=9, vx=-1.3, vy=-2.2, size=(2, 1)),
  'rifle': dict(flash=[stamp(['.y..o', 'wwwyyo', '.y..o'], K), stamp(['wyo'], K)],
                casing=[('yellow3', 'yellow2')], eject_back=7, vx=-1.3, vy=-2.2, size=(2, 1)),
  'flare': dict(flash=[stamp(['..o...', '.owo.r', 'owwwor', '.owo.r', '..o...'], FK),
                       stamp(['g.....', '.g..rr', 'g..rwwr', '.g..rr'][:3] + [], FK),
                       stamp(['.g.......', 'g.g....ro', '.g......'], FK)],
                casing=[], eject_back=0, vx=0, vy=0, size=(2, 1)),
}

def render(frames, gun, shots, aim, floor):
    g = GUNS[gun]; n = len(frames); d = AIM[aim]
    frames = [clean(f, aim) for f in frames]
    if REF_IMG is not None: frames = [strip_new(f, REF_IMG) for f in frames]
    out = [f.copy() for f in frames]
    for s in shots:
        two = isinstance(s, str)   # '4b' = the second gun fires on frame 4
        s = int(s[:-1]) if two else s
        for k, st in enumerate(g['flash']):
            fi = (s + k) % n; m = muzzle(frames[fi], aim, two)
            if not m: continue
            for dx, dy, col in st:
                rx, ry = rot(dx + 1, dy, aim)
                x, y = m[0] + rx, m[1] + ry
                if 0 <= x < CW and 0 <= y < CH: out[fi].putpixel((x, y), col)
        if not g['casing']: continue
        s = (s + g.get('eject_delay', 0)) % n   # pump guns throw the shell when racked, not on the shot
        m = muzzle(frames[s], aim)
        k = g['eject_back'] * (0.7071 if aim != 'level' else 1)
        x, y = m[0] - k * d[0], m[1] - k * d[1] - 1
        vx, vy = g['vx'], g['vy']; bounced = False
        for t in range(1, n):
            fi = (s + t) % n
            x += vx; y += vy; vy += 1.1
            if y >= floor:
                y = floor
                if not bounced: vy = -1.3; vx *= 0.5; bounced = True
                else: vx = vy = 0
            hi, lo = g['casing'][0]
            w, h = g['size'] if t % 2 else (g['size'][1], g['size'][0])
            if y >= floor: w, h = g['size']
            for i in range(w):
                for j in range(h):
                    X, Y = int(round(x)) + i, int(round(y)) - j
                    if 0 <= X < CW and 0 <= Y < CH and not out[fi].getpixel((X, Y))[3]:
                        out[fi].putpixel((X, Y), P[hi if i == 0 and j == 0 else lo])
            if t >= n - 2 or (bounced and vx == 0 and t > 5): break
    return out

if __name__ == '__main__':
    src, gun, shots, dst = sys.argv[1], sys.argv[2], [s if s.endswith('b') else int(s) for s in sys.argv[3].split(',')], sys.argv[4]
    aim = sys.argv[5] if len(sys.argv) > 5 else 'level'
    drop = [int(v) for v in sys.argv[6].split(',')] if len(sys.argv) > 6 else []
    n = len([f for f in os.listdir(src) if f.endswith('.png')])
    frames = [norm(Image.open(f'{src}/{i}.png')) for i in range(n) if i not in drop]
    floor = max(max(y for x in range(CW) for y in range(CH) if f.getpixel((x, y))[3]) for f in frames)
    os.makedirs(dst, exist_ok=True)
    for i, f in enumerate(render(frames, gun, shots, aim, floor)): f.save(f'{dst}/{i}.png')
    muz = [muzzle(clean(f, aim), aim) for f in frames]
    json.dump({'muzzle': muz, 'muzzle2': [muzzle(clean(f, aim), aim, True) for f in frames] if any(isinstance(s, str) for s in shots) else None},
              open(f'{dst}/muzzle.json', 'w'))
    print('floor', floor, 'muzzles', muz)
