"""Make one gun option for a cast character: padded 60x60 start -> hold edit -> v3 shoot -> fx.
usage: char.py <name> <opt> <gunkey> <shots> "<gun description>" "<shoot action>" [seed]"""
import sys, os, json, subprocess
from PIL import Image
from pl import REF
name, opt, gun, shots, gdesc, action = sys.argv[1:7]
seed = sys.argv[7] if len(sys.argv) > 7 else '1'
m = json.load(open(REF + 'manifest.json'))
cid = m['cast_animations']['characters'][name]['pixellab_character_id']
os.makedirs(name, exist_ok=True)
start = f'{name}/start.png'
if not os.path.exists(start):
    src = Image.open(f'{REF}approved/cast_animations/{name}/work/0.png').convert('RGBA')
    b = src.getbbox(); fig = src.crop(b)
    out = Image.new('RGBA', (60, 60), (0, 0, 0, 0))
    out.alpha_composite(fig, (30 - (b[2] - b[0]) // 2, 49 - (b[3] - b[1])))   # feet on row 48 like the medic
    out.save(start)
run = lambda *a: subprocess.run([sys.executable, *a], check=True)
hold = f'{name}/hold_{opt}.png'
if not os.path.exists(hold):
    run('edit_hold.py', start, hold, seed, "Same character, same art style, pixel size, outline, shading, colours, chibi proportions and side view facing right: now " + gdesc + ". No muzzle flash, no smoke.")
run('anim.py', cid, hold, f'{name}/shoot_{opt}', seed, action + "; body steady, feet planted; no muzzle flash, no smoke, loop")
run('fx.py', f'{name}/shoot_{opt}', gun, shots, f'{name}/fx_{opt}', 'level')
