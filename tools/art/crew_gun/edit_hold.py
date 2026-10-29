"""Edit a 60x60 reference frame into a 'holding a gun' pose. usage: edit_hold.py src.png out.png seed "description" """
import sys
from pl import *
src, out, seed, desc = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
r = call('POST', '/edit-image-pro-flash', {'image': b64(Image.open(src).convert('RGBA')), 'method': 'text',
    'description': desc, 'no_background': True, 'use_color_palette_correction': True, 'seed': seed})
print('est gens', r.get('estimated_generations'))
j = job(r['background_job_id'])
lr = j.get('last_response') or {}
img = lr.get('image') or (lr.get('images') or [None])[0]
if img is None:
    print(json.dumps(j)[:1500]); sys.exit(1)
unb64(img).save(out); print('saved', out)
