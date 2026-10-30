"""Add strand lines, highlights and shading to flat hair in every frame of a clip (code, no gens).
usage: hairfx.py dir r,g,b [max_row]   (r,g,b = the flat hair colour)"""
import sys, os
from PIL import Image
d = sys.argv[1]; base = tuple(int(v) for v in sys.argv[2].split(',')); maxy = int(sys.argv[3]) if len(sys.argv) > 3 else 27
mix = lambda c, k: tuple(max(0, min(255, round(v * k))) for v in c)
HI, SPEC, SH, MID = mix(base, 1.75), mix(base, 2.3), mix(base, 0.6), mix(base, 1.3)
for f in sorted(os.listdir(d)):
    if not f[0].isdigit(): continue
    im = Image.open(f'{d}/{f}').convert('RGBA'); px = im.load(); src = im.copy().load()
    hair = lambda x, y: 0 <= x < im.width and 0 <= y < im.height and src[x, y][3] and src[x, y][:3] == base
    for x in range(im.width):
        top = None
        for y in range(maxy):
            if not hair(x, y): top = None; continue
            if top is None: top = y
            dd = y - top
            below = hair(x, y + 1)
            if dd == 0: px[x, y] = (*(SPEC if x % 3 == 1 else HI), 255)
            elif dd == 1 and x % 2 == 0: px[x, y] = (*HI, 255)
            elif not below: px[x, y] = (*SH, 255)          # underside shade
            elif dd >= 3 and x % 3 == 0: px[x, y] = (*SH, 255)   # strand lines
            elif dd == 2 and x % 3 == 2: px[x, y] = (*MID, 255)
    im.save(f'{d}/{f}')
