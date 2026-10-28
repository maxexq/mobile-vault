"""MV-565 contract verification and exact-atlas PNG/GIF review previews."""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
SPECS=ROOT/'tools/art/exterior_mods/contracts.json'


def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--preview',type=Path,default=ROOT/'build/exterior-mods')
    args=ap.parse_args(); out=args.preview; out.mkdir(parents=True,exist_ok=True)
    specs=json.loads(SPECS.read_text()); reg=json.loads((ROOT/'assets/atlas/atlas.json').read_text())
    atlas=Image.open(ROOT/'assets/atlas/atlas.png').convert('RGBA')
    assert atlas.width==2048 and atlas.height<=2816 and atlas.height%64==0,'Five-floor atlas GPU budget grew'
    boxes=list(reg.items())
    for i,(name,(x,y,w,h)) in enumerate(boxes):
        assert min(x,y)>=0 and x+w<=atlas.width and y+h<=atlas.height,name
        for other,(a,b,c,d) in boxes[:i]:
            assert not (x<a+c+1 and x+w+1>a and y<b+d+1 and y+h+1>b),(name,other,'atlas padding overlap')
    import sys
    sys.path.insert(0,str(ROOT/'tools'))
    from art.common import PAL
    def crop(name,before=False):
        r=oldreg if before else reg; a=oldatlas if before else atlas
        x,y,w,h=r[name]; return a.crop((x,y,x+w,y+h))
    count=0
    for s in specs:
        n=s['frames']['count']; palette={PAL[k][:3] for k in s['palette']}
        for f in range(n):
            name=s['id'] if n==1 else f"{s['id']}_{f}"
            im=crop(name)
            assert list(im.size)==s['size'],name
            colors={p for _,p in im.getcolors(im.width*im.height)}
            assert {p[3] for p in colors} <= {0,255},name
            assert {p[:3] for p in colors if p[3]} <= palette,name
            count+=1
        if s['kind']=='fx' and not s['frames'].get('loop'):
            assert crop(f"{s['id']}_{n-1}").getbbox() is None,s['id']
    print(f'PASS {len(specs)} contracts / {count} cells: dimensions, binary alpha, palette and clear FX tails')
    print(f'PASS {len(reg)} atlas regions: bounds, one-pixel padding and five-floor GPU budget {atlas.size}')
    oldreg=json.loads((out/'before.json').read_text()) if (out/'before.json').exists() else reg
    oldatlas=Image.open(out/'before.png').convert('RGBA') if (out/'before.png').exists() else atlas
    replaces={s['id'] if s['frames']['count']==1 else f"{s['id']}_{f}" for s in specs if s.get('replace') for f in range(s['frames']['count'])}
    changed=[]
    for name in oldreg:
        if name not in replaces and crop(name).tobytes()!=crop(name,True).tobytes(): changed.append(name)
    assert not changed, 'Unrelated sprites changed: '+str(changed)
    print(f'PASS {len(oldreg)-len(replaces)} unrelated original sprites preserved pixel-for-pixel')
    samples=[('mod_spike_ram_3','RAM Lv3'),('mod_roof_turret_3','ROOF TURRET Lv3'),('mod_fuel_tank','FUEL DRUM'),('mod_tracks_0','TRACKS'),('mod_armor_wall','ARMOR PILLAR'),('mod_solar_cover','SOLAR HOOD'),('mod_rad_shield','LEAD SKIRT'),('mod_rain_catcher','RAIN FUNNEL'),('mod_shock_3','HEAVY SHOCK Lv3'),('bwheel_0','OFF-ROAD RIM Lv3'),('mod_heater','HEATER COWL')]
    sheet=Image.new('RGB',(920,len(samples)*130+58),(24,24,28)); d=ImageDraw.Draw(sheet)
    d.text((20,12),'MV-565 / actual atlas sprites / nearest pixels',fill='#d8ae44')
    d.text((200,34),'BEFORE',fill='white');d.text((560,34),'AFTER',fill='white')
    for i,(name,label) in enumerate(samples):
        y=58+i*130; d.text((12,y+8),label,fill='#b2a88a')
        for j,old in enumerate([True,False]):
            im=crop(name,old)
            if name=='bwheel_0' and not old: im.alpha_composite(crop('anim_ext_offroad_lv3_rim_0'),(8,8))
            scale=min(4,330//im.width,110//im.height)
            im=im.resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST)
            sheet.paste(im,(195+j*355,y+4),im)
    sheet.save(out/'before-after.png')

    def vehicle(tier,floors,frame=0,before=False,tracks=False,animate=False):
        canvas=Image.new('RGBA',(310,412),(32,32,36,255)); dy=56*(4-floors); ry=36+dy
        def put(name,x,y,im=None): canvas.alpha_composite(im if im is not None else crop(name,before),(x+24,y+84))
        wx={'van':[26,214],'bus':[34,214],'rig':[22,182,222],'train':[16,36,150,170,214,234]}[tier]
        for x in wx:
            if tracks and tier!='train' and x>100: continue
            rail=tier=='train'; f=frame%4
            put(('rwheel_' if rail else 'bwheel_')+str(f),x-(10 if rail else 16),280 if rail else 268)
            if not before and not rail: put(f'anim_ext_offroad_lv3_rim_{f}',x-8,276)
        grown=f'vehf{floors}_{tier}'
        shell=grown if grown in reg else 'veh_'+tier
        put(shell,0,300-crop(shell,before).height)
        for slot in range(floors*3): put('room_empty',[44,118,184][slot%3],210-56*(slot//3))
        if tracks and tier!='train': put('mod_tracks_'+str(frame%4),(202 if tier=='rig' else 200)-42,265)
        for name,x,y in [('mod_spike_ram_3',-20,242),('mod_roof_turret_3',200,ry-18),('mod_roof_deck_cozy_3',182,ry-60),('mod_rad_shield',42,268),('mod_rain_catcher',146,ry-36),('mod_heater',130,ry-20)]:
            if not before and name=='mod_roof_turret_3': name=f'anim_ext_turret_lv3_recoil_{frame%4}'
            if not before and name=='mod_roof_deck_cozy_3': name='ext_base_mod_roof_deck_cozy_3'
            if not before and name=='mod_heater': name='ext_base_mod_heater'
            if not before and name=='mod_rain_catcher': name=f'anim_ext_catcher_hem_{frame%4}'
            put(name,x,y)
        for k in range(3):
            fy=140-24*k
            own_ry=36+56*(4-{'van':2,'bus':3,'rig':4,'train':4}[tier])
            wall=tier in ('rig','bus') and fy>own_ry+6
            x=(20 if tier=='rig' else 40) if wall else 232-16*k; fy=fy if wall else ry-22
            put('mod_fuel_tank',x,fy)
            if not before: put(f'anim_ext_fuel_strap_{frame%4}',x+10,fy+2)
        for fb in range(floors):
            for x in [37,247]: put('mod_armor_wall',x,208-56*fb)
        for x in [79,105]:
            put('solar_2',x-15,14+dy); put('mod_solar_cover',x-17,8+dy)
            if not before: put(f'anim_ext_solar_latch_{frame%4}',x+9,11+dy)
        if tier!='train':
            for x in wx: put('mod_shock_3' if before else f'anim_ext_shock_lv3_{frame%4}',x-4,252)
        if not before:
            put('prop_ext_catcher_lv2',162,ry-24)
            for x in [22,74,126,178]: put(f'anim_ext_shield_tab_{frame%4}',42+x,272)
            put(f'fx_ext_deck_brazier_{frame%4}',232,ry-34)
            put(f'anim_ext_deck_lamp_{frame%4}',245,ry-60)
            put(f'anim_ext_heater_cap_{frame%4}',130,ry-20)
            if animate and frame%8<2: put(f'fx_ext_turret_muzzle_{frame%2}',224-(1 if frame%4 in (1,2) else 0),ry-15)
        return canvas
    vehicles=[('van',5),('bus',5),('rig',5),('train',5)]
    board=Image.new('RGBA',(1240,868),(24,24,28,255));d=ImageDraw.Draw(board)
    for i,(tier,floors) in enumerate(vehicles):
        x=i*310
        d.text((x+24,8),tier.upper()+' / 5 FLOORS / BEFORE',fill='#b2a88a');board.alpha_composite(vehicle(tier,floors,before=True),(x,24))
        d.text((x+24,442),tier.upper()+' / 5 FLOORS / AFTER',fill='#d8ae44');board.alpha_composite(vehicle(tier,floors),(x,458))
    board.convert('RGB').save(out/'all-vehicles.png')
    frames=[]
    for f in range(16):
        panel=Image.new('RGBA',(620,426),(24,24,28,255))
        panel.alpha_composite(vehicle('rig',5,frame=f,animate=True),(0,14))
        panel.alpha_composite(vehicle('van',5,frame=f,tracks=True,animate=True),(310,14))
        ImageDraw.Draw(panel).text((24,6),'ACTUAL ATLAS CELLS / motion sampler (not gameplay timing)',fill='#d8ae44')
        frames.append(panel.convert('RGB').resize((1240,852),Image.Resampling.NEAREST))
    frames[0].save(out/'motion-preview.gif',save_all=True,append_images=frames[1:],duration=125,loop=0,disposal=2,optimize=False)
    report={'contracts':len(specs),'cells':count,'unrelated_sprites_preserved':len(oldreg)-len(replaces),'atlas_size':list(atlas.size),'previews':['before-after.png','all-vehicles.png','motion-preview.gif']}
    (out/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Previews:',out)


if __name__=='__main__': main()
