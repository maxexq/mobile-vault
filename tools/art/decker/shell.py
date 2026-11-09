# MV-736 Decker (double-decker bus, tier "bus" under switch decker): game shells from the approved PixelLab art
# (claude.ai project designs/vehicle-2floor/approved/decker_{2,3}deck_1x.png; since MV-739 round 3 the copies with the
# PixelLab front + headlight in designs/vehicle-2floor/front/out/). Background -> transparent, every room
# cell (144x96 at x 104 + 152*col, y 56 + 112*row) cut out so the v3 RoomV3Cell rooms show through, like ambulance_v3.
#   python3 tools/art/decker/shell.py <decker_2deck_1x.png> <decker_3deck_1x.png>  -> assets/vehicles/decker_v3/
import json,os,sys
from collections import deque
from PIL import Image
OUT=os.path.join(os.path.dirname(os.path.abspath(__file__)),"../../../assets/vehicles/decker_v3")
BG=(46,44,48); X0,Y0,FH,CW,CH=104,56,112,144,96
def shell(src,floors):
    im=Image.open(src).convert("RGBA"); W,H=im.size; px=im.load(); seen=bytearray(W*H)
    q=deque([(x,y) for x in range(W) for y in (0,H-1)]+[(x,y) for y in range(H) for x in (0,W-1)])
    while q:                                   # flood the flat background from the border
        x,y=q.popleft()
        if not(0<=x<W and 0<=y<H) or seen[y*W+x]: continue
        c=px[x,y]
        if sum(abs(a-b) for a,b in zip(c[:3],BG))>6: continue
        seen[y*W+x]=1; px[x,y]=(0,0,0,0); q.extend(((x+1,y),(x-1,y),(x,y+1),(x,y-1)))
    cells=[]
    for row in range(floors):
        for col in range(3):
            x,y=X0+152*col,Y0+FH*row
            im.paste((0,0,0,0),(x,y,x+CW,y+CH)); cells.append({"floor":floors-1-row,"col":col,"x":x,"y":y})
    return im,cells
if __name__=="__main__":
    os.makedirs(OUT,exist_ok=True); meta={"cell":[CW,CH],"floors":{}}
    for n,src in ((2,sys.argv[1]),(3,sys.argv[2])):
        im,cells=shell(src,n); im.save(f"{OUT}/shell_f{n}.png"); meta["floors"][str(n)]={"size":list(im.size),"cells":cells}
        print(n,im.size)
    json.dump(meta,open(f"{OUT}/shell.json","w"),indent=1)
