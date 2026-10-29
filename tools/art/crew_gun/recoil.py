"""Build a shoot loop from one hold pose with code recoil (MV-594): the upper body leans back 1 px and the
arms + gun kick 1 more px back on each shot. usage: recoil.py hold.png outdir pattern
pattern = one digit per frame: 0 hold, 1 small kick, 2 full kick (e.g. pistol 02100210, smg 021212100)"""
import sys, os
from PIL import Image
src, dst, pat = sys.argv[1], sys.argv[2], sys.argv[3]
hold = Image.open(src).convert('RGBA')
WAIST, FRONT = 34, 36   # rows above WAIST lean back; columns from FRONT on are arms + gun

def shift(im, box, dx):
    part = im.crop(box); out = im.copy()
    out.paste((0, 0, 0, 0), box)
    out.alpha_composite(part, (box[0] + dx, box[1]))
    return out

def kick(level):
    im = hold
    if level >= 1: im = shift(im, (1, 0, hold.width, WAIST), -1)
    if level >= 2: im = shift(im, (FRONT - 1, 0, hold.width, 46), -1)
    return im

os.makedirs(dst, exist_ok=True)
for i, ch in enumerate(pat): kick(int(ch)).save(f'{dst}/{i}.png')
