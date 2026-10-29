"""strip.png + gif for a clip dir. usage: prev.py dir fps [scale]"""
import sys, os
from PIL import Image
d, fps = sys.argv[1], int(sys.argv[2]); s = int(sys.argv[3]) if len(sys.argv) > 3 else 4
n = len([f for f in os.listdir(d) if f[0].isdigit()])
fr = []
for i in range(n):
    im = Image.open(f'{d}/{i}.png').convert('RGBA'); W, H = im.size
    bg = Image.new('RGBA', (W, H), (34, 32, 30, 255)); bg.alpha_composite(im)
    fr.append(bg.resize((W * s, H * s), Image.NEAREST))
st = Image.new('RGBA', (W * s * n, H * s)); [st.paste(f, (i * W * s, 0)) for i, f in enumerate(fr)]
st.save(d + '.strip.png')
fr[0].convert('RGB').save(d + '.gif', save_all=True, append_images=[f.convert('RGB') for f in fr[1:]], duration=int(1000 / fps), loop=0)
