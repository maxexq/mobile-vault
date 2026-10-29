"""One review GIF: rows = guns, columns = aim up / level / down. usage: grid.py char out.gif fps gun1 [gun2]"""
import sys, os, math
from PIL import Image
ch, out, fps, guns = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4:]
S = 4; T = 72 * S; TH = 60 * S
clips = [[[Image.open(f'{ch}/fx_{g}{a}/{i}.png').convert('RGBA') for i in range(len(os.listdir(f'{ch}/fx_{g}{a}')))]
          for a in ('_up', '', '_down')] for g in guns]
lens = [len(c) for row in clips for c in row]; N = math.lcm(*lens)
frames = []
for t in range(N):
    W = Image.new('RGBA', (T * 3, TH * len(guns)), (34, 32, 30, 255))
    for r, row in enumerate(clips):
        for c, clip in enumerate(row):
            f = clip[t % len(clip)]; W.alpha_composite(f.resize((f.width * S, f.height * S), Image.NEAREST), (c * T, r * TH))
    frames.append(W.convert('RGB'))
frames[0].save(out, save_all=True, append_images=frames[1:], duration=int(1000 / fps), loop=0)
