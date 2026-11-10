# MV-738 Bastion 42-B (ex-army 8x8 command truck, tier "bastion" under switch bastion): game shells from the approved
# art (claude.ai project designs/vehicle-2floor/approved/bastion_2deck_1x.png, PixelLab concept C with the cab number
# hand-fixed to 42-B). Same cell grid as the Decker but the box starts at x 158: cells 144x96 at x 158 + 152*col,
# y 56 + 112*row. The 3-deck body is made here in code (no new gens): the top deck band (rooms + riveted slab, 112 px)
# is repeated once under the roof, so the riveted box simply gets one storey taller.
#   python3 tools/art/bastion/shell.py <bastion_2deck_1x.png>  -> assets/vehicles/bastion_v3/
import json,os,sys
from PIL import Image
sys.path.insert(0,os.path.join(os.path.dirname(os.path.abspath(__file__)),"../decker"))
import shell as dk
OUT=os.path.join(os.path.dirname(os.path.abspath(__file__)),"../../../assets/vehicles/bastion_v3")
X0,Y0,FH=158,56,112
WHEELS=(60,116,492,548); WY=310; WR=24
def clean(src):
    """drop the concept's dust cloud behind the rear axles (the game draws its own dust): below y 306, outside the tyres"""
    im=Image.open(src).convert("RGBA"); px=im.load(); W,H=im.size
    for y in range(WY-4,H):
        for x in range(462,W):
            if all((x-cx)**2+(y-WY)**2>WR*WR for cx in WHEELS): px[x,y]=dk.BG+(255,)
    return im
def three(im):
    W,H=im.size
    out=Image.new("RGBA",(W,H+FH),dk.BG+(255,))
    out.paste(im.crop((0,0,W,Y0+FH)),(0,0))               # roof + top deck + slab
    out.paste(im.crop((0,Y0,W,H)),(0,Y0+FH))               # top deck again, then the rest (bottom deck, cab, wheels)
    # the cab, nose and wheels sit below y 150; anything left of the box in the inserted band is background
    px=out.load()
    for y in range(Y0+FH,Y0+2*FH):
        for x in range(0,X0-10):
            px[x,y]=dk.BG+(255,)
    return out
if __name__=="__main__":
    os.makedirs(OUT,exist_ok=True); tmp2=os.path.join(OUT,"_f2_src.png"); tmp=os.path.join(OUT,"_f3_src.png")
    two=clean(sys.argv[1]); two.save(tmp2); three(two).save(tmp); src=tmp2
    dk.X0,dk.Y0=X0,Y0
    meta={"cell":[dk.CW,dk.CH],"floors":{}}
    for n,s in ((2,src),(3,tmp)):
        im,cells=dk.shell(s,n); im.save(f"{OUT}/shell_f{n}.png"); meta["floors"][str(n)]={"size":list(im.size),"cells":cells}
        print(n,im.size)
    os.remove(tmp); os.remove(tmp2)
    json.dump(meta,open(f"{OUT}/shell.json","w"),indent=1)
