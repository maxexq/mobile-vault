"""Copy approved gun clips into the repo + manifest entry (MV-594). usage: export.py"""
import json, os, shutil, hashlib, sys
sys.argv = ['x']
exec(open('fx.py').read().split("if __name__")[0])
REPO = os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../../docs/art/crew-style-reference/')
OUT = REPO + 'approved/gun_animations/'
# character, clip name, fx dir, gun preset, shot frames, fps, aim, gun description
CLIPS = [
 ('medic', 'pistol', 'medic/fx_A', 'pistol', [1, 5], 9, 'level', '9mm semi-automatic pistol, two hands'),
 ('medic', 'pistol_up', 'medic/fx_A_up', 'pistol', [1, 5], 12, 'up', '9mm pistol aimed 45 degrees up (code recoil)'),
 ('medic', 'pistol_down', 'medic/fx_A_down', 'pistol', [1, 5], 12, 'down', '9mm pistol aimed 45 degrees down (code recoil)'),
 ('medic', 'smg', 'medic/fx_B', 'smg', [2, 3, 4], 12, 'level', 'compact Uzi-style SMG, burst'),
 ('medic', 'smg_up', 'medic/fx_B_up', 'smg', [1, 3, 5], 12, 'up', 'SMG aimed 45 degrees up (code recoil)'),
 ('medic', 'smg_down', 'medic/fx_B_down', 'smg', [1, 3, 5], 12, 'down', 'SMG aimed 45 degrees down (code recoil)'),
 ('aviator_pilot', 'flare_pistol', 'aviator_pilot/fx_A', 'flare', [2], 10, 'level', 'orange flare pistol'),
 ('aviator_pilot', 'mauser', 'aviator_pilot/fx_B', 'pistol', [1, 5], 10, 'level', 'broomhandle Mauser C96, one hand'),
 ('biker', 'sawed_off', 'biker/fx_A', 'sawnoff', [2], 10, 'level', 'sawed-off double-barrel shotgun'),
 ('biker', 'revolver', 'biker/fx_B1', 'revolver', [1, 5], 10, 'level', 'chrome revolver, two-hand grip (take 1, big hair flip)'),
 ('biker', 'revolver_b', 'biker/fx_B2', 'revolver', [1, 5], 10, 'level', 'chrome revolver, two-hand grip (take 2, calmer)'),
 ('bus_mechanic', 'pump_shotgun', 'bus_mechanic/fx_A', 'shotgun', [2], 10, 'level', 'pump-action shotgun, shell ejects on the pump'),
 ('bus_mechanic', 'nail_gun', 'bus_mechanic/fx_B', 'nailgun', [1, 3, 5], 10, 'level', 'industrial nail gun'),
 ('construction_worker', 'ak_rifle', 'construction_worker/fx_A', 'rifle', [1, 3, 5], 10, 'level', 'AK-style rifle, 3-round burst'),
 ('construction_worker', 'pipe_shotgun', 'construction_worker/fx_B1', 'sawnoff', [2], 10, 'level', 'homemade pipe shotgun (take 1)'),
 ('construction_worker', 'pipe_shotgun_b', 'construction_worker/fx_B3', 'sawnoff', [2], 10, 'level', 'homemade pipe shotgun (take 2)'),
 ('firefighter', 'lever_rifle', 'firefighter/fx_A', 'rifle', [1, 5], 10, 'level', 'lever-action rifle'),
 ('firefighter', 'flamethrower', 'firefighter/fx_B', 'flamer', [1, 4], 10, 'level', 'tank flamethrower (flame drawn in code)'),
 ('fortune_teller', 'derringer', 'fortune_teller/fx_A', 'revolver', [1, 4], 10, 'level', 'gold derringer, one hand (legs pinned from frame 0)'),
 ('fortune_teller', 'flintlock', 'fortune_teller/fx_B', 'flintlock', [1], 10, 'level', 'antique flintlock pistol, smoke'),
 ('gunslinger', 'fan_revolver', 'gunslinger/fx_A', 'revolver', [1, 3, 5], 10, 'level', 'cowboy revolver fired from the hip, fanning the hammer'),
 ('gunslinger', 'dual_revolvers', 'gunslinger/fx_B', 'revolver', [1, '4b'], 10, 'level', 'two revolvers, alternating'),
 ('hunter', 'bolt_rifle', 'hunter/fx_A', 'boltrifle_smoke', [1], 10, 'level', 'scoped bolt-action rifle, bolt cycle ejects a brass casing, muzzle smoke'),
 ('hunter', 'over_under', 'hunter/fx_B', 'sawnoff_smoke', [2], 10, 'level', 'over-and-under hunting shotgun, big smoke puff'),
 ('lounge_singer', 'pearl_revolver', 'lounge_singer/fx_A', 'revolver', [1, 4], 10, 'level', 'small pearl-handled snub-nose revolver, one gloved hand'),
 ('lounge_singer', 'tommy_gun', 'lounge_singer/fx_B', 'smg', [2, 3, 4], 12, 'level', '1920s tommy gun from the hip, burst (flash spans the 2 px barrel)'),
 ('monk', 'net_launcher', 'monk/fx_A', 'airpuff', [2], 10, 'level', 'compressed-air net launcher, two hands (non-lethal: monks keep the precept against killing)'),
 ('monk', 'dart_pistol', 'monk/fx_B', 'airpuff', [1, 5], 10, 'level', 'wooden tranquiliser dart pistol, two-hand grip (PixelLab hold pose + code recoil)'),
 ('motorbike_courier', 'silver_pistol', 'motorbike_courier/fx_B2H', 'pistol', [1, 5], 10, 'level', 'silver pistol, two hands, ponytail whips with the recoil (legs pinned, hair detail drawn in code)'),
 ('motorbike_courier', 'silver_pistol_b', 'motorbike_courier/fx_B3H', 'pistol', [1, 5], 10, 'level', 'silver pistol, two hands, softer ponytail sway (take 2)'),
]
man = json.load(open(REPO + 'manifest.json'))
entry = {'how': 'MV-594. 1) edit_image_pro_flash on the character work/0 frame (60x60) -> holding-the-gun pose (5 gens). '
         '2) animate_character v3 east, frame_count 8, custom_start_frame = that pose (1 gen). 3) designs/crew-gun-anim/fx.py: '
         'PixelLab flashes removed, muzzle flash + casings drawn in code from master-palette colours per gun preset. '
         'Up/down aims: one more edit per aim + code recoil (recoil.py). Raw PixelLab colours like the other cast clips (medic snapped).',
         'canvas': [72, 60], 'feet_row': 48, 'direction': 'east (west = horizontal mirror)', 'playback': 'loop',
         'muzzle': 'per frame [x, y] of the barrel end in the 72x60 frame, for bullets and hit lines', 'clips': {}}
shutil.rmtree(OUT, ignore_errors=True)
for ch, name, src, gun, shots, fps, aim, desc in CLIPS:
    d = f'{OUT}{ch}/{name}/'; os.makedirs(d)
    files = sorted((f for f in os.listdir(src) if f[0].isdigit()), key=lambda f: int(f[:-4]))
    muz = []
    for f in files:
        shutil.copy(f'{src}/{f}', d + f)
    mj = json.load(open(f'{src}/muzzle.json'))   # measured on the cleaned frames, before effects
    muz = mj['muzzle']
    entry['clips'].setdefault(ch, {})[name] = {'dir': f'gun_animations/{ch}/{name}/', 'frames': len(files), 'fps': fps,
        'aim': aim, 'gun': desc, 'fx_preset': gun, 'shot_frames': shots, 'muzzle': muz,
        **({'muzzle_second_gun': mj['muzzle2']} if mj.get('muzzle2') else {})}
    for f in files:
        man['files_sha256'][f'gun_animations/{ch}/{name}/{f}'] = hashlib.sha256(open(d + f, 'rb').read()).hexdigest()
man['gun_animations'] = entry
json.dump(man, open(REPO + 'manifest.json', 'w'), indent=1, ensure_ascii=False)
print(sum(len(v) for v in entry['clips'].values()), 'clips')
