"""Animate a character (v3, east) from a custom start frame. usage: anim.py char_id start.png outdir seed "action" [frames]"""
import sys, os
from pl import *
cid, start, outdir, seed, action = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), sys.argv[5]
n = int(sys.argv[6]) if len(sys.argv) > 6 else 8
end = len(sys.argv) > 7 and sys.argv[7] == 'loop'
r = call('POST', '/characters/animations', {'character_id': cid, 'mode': 'v3', 'directions': ['east'], 'frame_count': n,
    'custom_start_frame': b64(Image.open(start).convert('RGBA')), 'action_description': action, 'seed': seed,
    'animation_name': os.path.basename(outdir), **({'end_frame': b64(Image.open(start).convert('RGBA'))} if end else {})})
j = job(r['background_job_ids'][0])
lr = j.get('last_response') or {}
imgs = lr.get('images') or lr.get('frames')
if not imgs:
    print(j.get('status'), json.dumps(lr)[:1500]); sys.exit(1)
os.makedirs(outdir, exist_ok=True)
for i, im in enumerate(imgs): unb64(im).save(f'{outdir}/{i}.png')
print('saved', len(imgs), 'frames to', outdir)
