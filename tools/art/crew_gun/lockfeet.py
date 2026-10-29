"""Pin the legs: copy rows from <row> down out of frame 0 into every frame (no stepping). usage: lockfeet.py srcdir dstdir row"""
import sys, os
from PIL import Image
src, dst, row = sys.argv[1], sys.argv[2], int(sys.argv[3])
n = len([f for f in os.listdir(src) if f[0].isdigit()])
fr = [Image.open(f'{src}/{i}.png').convert('RGBA') for i in range(n)]
legs = fr[0].crop((0, row, fr[0].width, fr[0].height))
os.makedirs(dst, exist_ok=True)
for i, f in enumerate(fr):
    f = f.copy(); f.paste((0, 0, 0, 0), (0, row, f.width, f.height)); f.paste(legs, (0, row)); f.save(f'{dst}/{i}.png')
