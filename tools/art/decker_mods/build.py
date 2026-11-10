# MV-760: cut the APPROVED Decker exterior mods (MV-739, /mnt/project-files/designs/vehicle-2floor/approved/ + mods/mock.py fits)
# into game layers: assets/vehicles/decker_v3/mods/<mod>_L<n>.png (trimmed RGBA) + mods.json {mod: {"<n>": [x, y]}} in shell_f2 pixels.
# "anchor": "body" parts move down 112 px per deck above 2 (the f3 shell adds its deck on top); "roof" parts stay on the roof (y 34).
#   python3 tools/art/decker_mods/build.py
import json,os,sys
from PIL import Image
REPO=os.path.abspath(os.path.join(os.path.dirname(__file__),"../../.."))
D="/mnt/project-files/designs/vehicle-2floor/"
OUT=os.path.join(REPO,"assets/vehicles/decker_v3/mods/")
sys.path.insert(0,D+"mods"); import mock; os.chdir(D+"mods")   # mock paths are relative to its folder
def diff_part(fn,L):
    """pixels the mock fit adds over the bare bus (both on the same padded canvas) -> (image, shell x, shell y)"""
    a=mock.base().im; b=mock.base(); fn(b,L); b=b.im
    pa,pb=a.load(),b.load(); out=Image.new("RGBA",a.size); o=out.load()
    for y in range(a.height):
        for x in range(a.width):
            if pa[x,y]!=pb[x,y]: o[x,y]=pb[x,y]
    bb=out.getbbox(); return out.crop(bb),bb[0]-mock.PAD,bb[1]-mock.PADY
def file_part(path,x,y):
    im=Image.open(path).convert("RGBA"); bb=im.getbbox(); return im.crop(bb),x+bb[0],y+bb[1]
A=D+"approved/"
JOBS={   # mod id: (anchor, {level: part})
    "spike_ram":   ("body",{L:(lambda L=L: diff_part(mock.ram,L)) for L in (1,2,3)}),
    "fuel_tanks":  ("body",{L:(lambda L=L: diff_part(mock.fuel,L)) for L in (1,2,3)}),
    "armor_plates":("body",{L:(lambda L=L: diff_part(mock.armor,L)) for L in (1,2,3)}),
    "roof_turret": ("body",{L:(lambda L=L: file_part(A+f"sponson/sponson_L{L}.png",560,48)) for L in (1,2,3)}),
    "rad_shield":  ("body",{L:(lambda L=L: file_part(A+f"lead/decker_lead_L{L}_part.png",0,0)) for L in (1,2)}),
    "heater":      ("roof",{L:(lambda L=L: file_part(A+f"chimney/chimney_L{L}.png",136,-48)) for L in (1,2)}),
    "solar":       ("roof",{L:(lambda L=L: file_part(A+f"solar/solar_L{L}.png",96,-48)) for L in (1,2,3)}),
}
if __name__=="__main__":
    os.makedirs(OUT,exist_ok=True); meta={}
    for mid,(anchor,lv) in JOBS.items():
        meta[mid]={"anchor":anchor}
        for L,f in lv.items():
            im,x,y=f(); im.save(OUT+f"{mid}_L{L}.png"); meta[mid][str(L)]=[x,y]
            print(mid,L,im.size,(x,y))
    json.dump(meta,open(OUT+"mods.json","w"),indent=1)
