"""MV-565: deterministic exterior-mod detail and local motion strips.

Runs after truck/extra generation. It touches only the named mod sprites, never
the approved vehicle shell, wheel tread, roof furniture or background artwork.
"""
import math
import json
from pathlib import Path
from .common import *

CONTRACTS = Path(__file__).with_suffix('') / 'contracts.json'


def restricted(img, names):
    """Exact contract palette and binary alpha; never changes the alpha silhouette."""
    colors = [c(n) for n in names]
    cache = {}
    out = img.copy()
    for y in range(img.height):
        for x in range(img.width):
            p = get(img, x, y)
            if p[3] < 128:
                px(out, x, y, CLEAR)
            else:
                if p[:3] not in cache:
                    cache[p[:3]] = min(colors, key=lambda q: sum((p[k]-q[k])**2 for k in range(3)))
                px(out, x, y, cache[p[:3]])
    return out


def bolt(img, x, y):
    rect(img, x, y, 2, 2, c('gray2'))
    px(img, x, y, c('gray5'))


def gen_exterior_mods():
    specs = {s['id']: s for s in json.loads(CONTRACTS.read_text(encoding='utf-8'))}
    old = {n: im.copy() for n, im in atlas_items.items()
           if n.startswith(('mod_', 'bwheel_'))}

    def emit(sid, im, f=None):
        spec = specs[sid]
        assert list(im.size) == spec['size'], (sid, im.size, spec['size'])
        result = restricted(im, spec['palette'])
        add(sid if f is None else f'{sid}_{f}', result, q=False)
        return result

    # Static material pass. Changes are masked to the original opaque silhouette.
    static = [s for s in specs.values() if s.get('replace') and s['frames']['count'] == 1]
    for s in static:
        sid = s['id']
        src = old[sid]
        source = src.copy()
        swaps = {c(a): c(b) for a,b in [('yellow3','yellow1'),('yellow2','yellow1'),('teal3','teal2'),('red2','red1')] if b in s['palette']}
        for y in range(source.height):
            for x in range(source.width):
                p = get(source,x,y)
                if p in swaps: px(source,x,y,swaps[p])
        im = restricted(source, s['palette'])
        if sid.startswith('mod_spike_ram_'):
            for y in range(5, 31, 4):
                rect(im, 24, y, 2, 2, c('gray2'))
                px(im, 25, y, c('gray5'))
            for x,y in [(21,7),(21,25)]:
                bolt(im,x,y); px(im,x,y+3,c('orange2'))
            line(im,17,19,21,22,c('gray2'))
            if sid.endswith('_3'):
                rect(im,20,15,4,4,c('orange2'))
        elif sid.startswith('mod_roof_turret_'):
            bolt(im,6,14); px(im,12,15,c('gray1'))
            vline(im,13,10,3,c('gray1'))
            for y in ([8] if sid.endswith('_1') else [7,10]):
                for x in (17,20): px(im,x,y,c('gray1'))
            px(im,6,0,c('red1'))
        elif sid == 'mod_fuel_tank':
            for y in (5,15):
                hline(im,2,y,11,c('gray2')); px(im,3,y,c('gray4'))
            rect(im,8,16,3,2,c('orange1')); px(im,8,16,c('orange2'))
            rect(im,5,8,6,5,c('red1')); frame(im,5,8,6,5,OL)
            px(im,7,10,c('gray4'))
            # A fixed buckle; only the added loose end is animated.
            rect(im,13,16,2,3,c('gray2')); px(im,13,16,c('gray4'))
        elif sid == 'mod_armor_wall':
            for y0 in (0,28):
                for yy in (3,23):
                    bolt(im,2,y0+yy); px(im,3,y0+yy+2,c('orange1'))
                for yy in range(y0+5,y0+22,4): px(im,6,yy,c('gray3'))
                px(im,1,y0+14,c('gray2')); px(im,2,y0+15,c('orange2'))
        elif sid == 'mod_solar_cover':
            for x in (5,27):
                rect(im,x,4,2,3,c('gray3')); px(im,x,4,c('gray5'))
            hline(im,5,7,24,c('sand1'))
        elif sid == 'mod_rad_shield':
            for x in range(25,207,26):
                vline(im,x,2,7,c('gray1')); px(im,x-1,2,c('gray4'))
            for x in range(4,207,26):
                rect(im,x,2,2,2,c('gray1')); px(im,x,2,c('gray4'))
                px(im,x+1,6,c('orange1'))
        elif sid == 'mod_rain_catcher':
            rect(im,8,5,4,3,c('cream1')); px(im,9,6,c('teal1'))
            hline(im,8,4,4,c('gray3'))
            for x in (2,36): px(im,x,3,c('gray3'))
            hline(im,18,12,4,c('teal0'))
        elif sid == 'mod_heater':
            hline(im,2,3,8,c('gray1'))
            px(im,2,1,c('gray4')); px(im,9,1,c('gray1'))
            for y in (8,16): px(im,8,y,c('orange2'))
        elif sid.startswith('mod_shock_'):
            w=im.width
            vline(im,w//2,2,16,c('gray5'))
            for yy in (0,18):
                px(im,1,yy,c('gray1')); px(im,w-2,yy,c('gray4'))
            px(im,w//2+1,16,c('orange1'))
        # Source silhouette stays exact, including transparent joints between armor plates.
        im.putalpha(src.getchannel('A'))
        emit(sid,im)

    # Recoil is baked into cells; the mount and receiver never translate at runtime.
    for lv in (1,2,3):
        base=atlas_items[f'mod_roof_turret_{lv}']
        for f in range(4):
            im=base.copy()
            if f in (1,2):
                for y in ([7] if lv==1 else [6,9]):
                    barrel=base.crop((15,y,24,y+3))
                    rect(im,15,y,9,3,CLEAR)
                    rect(im,15,y,2,3,c(['green2','blue2','purple2'][lv-1]))
                    im.alpha_composite(barrel,(14,y))
            emit(f'anim_ext_turret_lv{lv}_recoil',im,f)

    for f in range(4):
        im=old[f'mod_tracks_{f}'].copy()
        # Clear the old rectangular top/bottom blocks before tracing linked belt motion.
        rect(im,18,3,48,4,c('gray1')); rect(im,18,33,48,4,c('gray1'))
        for k in range(24):
            phase=(k+f/4)/24
            perimeter=96+math.tau*15
            s=phase*perimeter
            if s<48: x,y=18+s,4
            elif s<48+math.pi*15:
                a=-math.pi/2+(s-48)/15; x,y=66+15*math.cos(a),19+15*math.sin(a)
            elif s<96+math.pi*15: x,y=66-(s-48-math.pi*15),34
            else:
                a=math.pi/2+(s-96-math.pi*15)/15; x,y=18+15*math.cos(a),19+15*math.sin(a)
            x,y=round(x),round(y)
            rect(im,x-1,y-1,3,2,c('gray3'))
            if y<10: px(im,x-1,y-1,c('gray4'))
        for x in (16,40,64): bolt(im,x,13)
        for wx in (12,32,52,72):
            ellipse(im,wx-2,20,5,5,c('yellow1'))
            for k in range(4):
                a=k*math.pi/2+f*math.pi/8
                px(im,round(wx+3*math.cos(a)),round(22+3*math.sin(a)),c('gray2'))
        im.putalpha(old[f'mod_tracks_{f}'].getchannel('A'))
        emit('mod_tracks',im,f)

    for lv in (1,2,3):
        base=atlas_items[f'mod_shock_{lv}']
        for f in range(4):
            im=base.copy()
            if f in (1,2):
                # Re-space only inner coil pixels, preserving mount/piston endpoints.
                for y in (6,9,12):
                    strip=base.crop((0,y,base.width,y+2))
                    rect(im,0,y,base.width,2,CLEAR)
                    vline(im,base.width//2,y,2,c('gray5'))
                    im.alpha_composite(strip,(0,y+1))
            emit(f'anim_ext_shock_lv{lv}',im,f)

    # Higher-tier rims share the approved MV-390 tread and wheel phase, not an independent clock.
    for lv in (2,3):
        for f in range(4):
            im=old[f'bwheel_{f}'].crop((8,8,24,24))
            ellipse(im,0,0,16,16,OL)
            ellipse(im,1,1,14,14,c('yellow1'))
            ellipse(im,2,2,12,12,c('gray0'))
            ellipse(im,3,3,10,10,c('gray3'))
            if lv==3:
                ellipse(im,1,1,14,14,c('gray4'),OL)
                ellipse(im,3,3,10,10,c('gray0'))
                ellipse(im,4,4,8,8,c('gray3'))
            for k in range(6):
                a=k*math.tau/6+f*math.tau/24
                x,y=round(7.5+4.5*math.cos(a)),round(7.5+4.5*math.sin(a))
                px(im,x,y,c('gray4'))
                if lv==3: px(im,min(x+1,14),y,c('gray2'))
            ellipse(im,5,5,6,6,OL); ellipse(im,6,6,4,4,c('orange1'))
            px(im,8,8,c('gray0'))
            emit(f'anim_ext_offroad_lv{lv}_rim',im,f)

    # Small stand-alone level cues.
    im=new(8,6); rect(im,0,0,8,5,OL); rect(im,1,1,6,3,c('gray3'))
    hline(im,1,1,6,c('gray5')); bolt(im,3,2); px(im,6,4,c('orange1'))
    emit('prop_ext_armor_lv1',im)
    im=new(8,4); rect(im,0,0,8,4,OL); hline(im,1,1,6,c('gray4'))
    rect(im,2,2,4,2,c('teal1')); px(im,1,2,c('cream1')); px(im,6,2,c('cream1'))
    emit('prop_ext_catcher_lv2',im)

    # Sparse tie-down/latch/tab overlays: no baked duplicate of a loose moving tail.
    for sid,size,pin in [('anim_ext_fuel_strap',(6,18),(3,14)),('anim_ext_solar_latch',(6,5),(1,1)),('anim_ext_shield_tab',(6,5),(2,0))]:
        for f in range(4):
            im=new(*size); x,y=pin; dx=1 if f==1 else 0
            rect(im,x,y,2,2,OL); px(im,x,y,c('gray4'))
            for dy in range(2, min(5,size[1]-y)):
                px(im,x+dx,y+dy,c('gray2') if sid!='anim_ext_solar_latch' else c('gray3'))
            emit(sid,im,f)

    # Rain funnel changes only interior folds. Rim, post, outlet and collar stay fixed.
    base=atlas_items['mod_rain_catcher']
    for f in range(4):
        im=base.copy()
        if f==1:
            for x,y in [(14,8),(27,7)]:
                px(im,x,y,c('teal2')); px(im,x,y+1,c('teal1'))
        emit('anim_ext_catcher_hem',im,f)

    base=atlas_items['mod_heater']
    clean=base.copy(); rect(clean,0,0,12,5,CLEAR)
    add('ext_base_mod_heater',clean,q=False)
    for f in range(4):
        im=base.crop((0,0,12,5))
        if f==1:
            px(im,10,2,c('gray1')); px(im,10,3,c('gray3'))
        emit('anim_ext_heater_cap',im,f)

    # Reuse the approved cozy deck pixel-for-pixel outside the animation windows.
    for cozy in (False,True):
        for lv in (1,2,3):
            name=f'mod_roof_deck_{"cozy_" if cozy else ""}{lv}'
            clean=old[name].copy()
            if cozy and lv==1:
                rect(clean,0,12,38,13,CLEAR)
            if lv>=2: rect(clean,50,26,6,8,CLEAR)
            if lv==3: rect(clean,63,0,4,7,CLEAR)
            add('ext_base_'+name,clean,q=False)
    for f in range(4):
        im=old['mod_roof_deck_cozy_1'].crop((0,12,38,25))
        if f==1:
            for x,y in ((19,11),(29,12)):
                if get(im,x,y)[3]:
                    px(im,x,y,c('green2')); px(im,x,y-1,c('green1'))
        emit('anim_ext_deck_awning',im,f)
        im=old['mod_roof_deck_2'].crop((50,26,56,34))
        # Preserve metal; only replace the three flame rows.
        rect(im,0,0,6,4,CLEAR)
        for x,y in [(1,3),(2,2),(3,3),(4,1 if f in (1,2) else 3)]:
            px(im,x,y,c('lamp1') if (x+f)%2 else c('lamp0'))
        emit('fx_ext_deck_brazier',im,f)
        im=old['mod_roof_deck_3'].crop((63,0,67,7))
        rect(im,1,1,2,5,c('lamp0') if f==2 else c('lamp1'))
        emit('anim_ext_deck_lamp',im,f)

    # All short FX end completely transparent, with no runtime fades or scaling.
    for sid in ('fx_ext_ram_contact','fx_ext_armor_chip','fx_ext_track_grit','fx_ext_offroad_grit'):
        w,h=specs[sid]['size']
        for f in range(4):
            im=new(w,h)
            if f<3:
                for k in range(3):
                    x=min(w-2,2+k*3+f*2); y=max(0,h-3-k-f)
                    color='gray4' if sid in ('fx_ext_ram_contact','fx_ext_armor_chip') and k==0 else ('sand1' if 'grit' in sid else 'gray2')
                    rect(im,x,y,2 if f==0 else 1,1,c(color))
            emit(sid,im,f)
    for f in range(4):
        im=new(8,8)
        if f<2:
            for yy in (4,7):
                hline(im,0,yy,3-f,c('lamp1')); px(im,3-f,yy,c('lamp0'))
        emit('fx_ext_turret_muzzle',im,f)
    for f in range(5):
        im=new(4,10)
        if f<4:
            y=[0,2,5,8][f]; rect(im,1,y,1,2 if f==1 else 1,c('sky3'))
            if f==3: px(im,0,9,c('teal2')); px(im,2,9,c('sky2'))
        emit('fx_ext_catcher_runoff',im,f)
