"""Drop pixels left of column X whose colour is not near any colour of the hold pose (PixelLab speed-line
artefacts that touch the body). usage: declutter.py dir hold.png x [tol]"""
import sys, os
from PIL import Image
d, hold, X = sys.argv[1], sys.argv[2], int(sys.argv[3]); tol = int(sys.argv[4]) if len(sys.argv) > 4 else 40
pal = {p[:3] for p in Image.open(hold).convert('RGBA').get_flattened_data() if p[3]}
near = lambda c: any(abs(c[0]-p[0]) + abs(c[1]-p[1]) + abs(c[2]-p[2]) <= tol for p in pal)
for f in os.listdir(d):
    if not f[0].isdigit(): continue
    im = Image.open(f'{d}/{f}').convert('RGBA'); px = im.load(); n = 0
    for y in range(im.height):
        for x in range(min(X, im.width)):
            if px[x, y][3] and not near(px[x, y]): px[x, y] = (0, 0, 0, 0); n += 1
    im.save(f'{d}/{f}'); print(f, n)
