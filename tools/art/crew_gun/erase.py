"""Erase a box in every frame of a clip (PixelLab artefacts). usage: erase.py dir x0 y0 x1 y1"""
import sys, os
from PIL import Image
d, box = sys.argv[1], tuple(int(v) for v in sys.argv[2:6])
for f in os.listdir(d):
    if f[0].isdigit():
        im = Image.open(f'{d}/{f}').convert('RGBA'); im.paste((0, 0, 0, 0), box); im.save(f'{d}/{f}')
