# MV-738 round 2 (Parames 2026-11-10 "ลบ stray pixel, รั้วและของบนหลังคาโดนตัด"), code only, 0 PixelLab gens.
# Run after shell.py:   python3 tools/art/bastion/cleanup.py   -> rewrites assets/vehicles/bastion_v3/shell_f{2,3}.png
# The approved art was made from two 512 px inpaint windows; their seam at x 499 cut the roof clean through:
# the roof rail stopped in mid air, the grey tarp and the red crate under it ended on a straight cut and a 1 px
# dark seam line ran down x 499. This script:
#  1) closes the tarp + red crate with a proper outline (rounded tarp corner) instead of the seam line,
#  2) carries the roof rail on to the rear ladder with two more posts and a bent end post (mirror of the front end),
#  3) clears backdrop-coloured (46,44,48) pockets the flood fill in shell.py could not reach (inside the roof rail,
#     between the rear ladder rungs, under the chassis),
#  4) sweeps strays like the Decker (MV-739): backdrop fringe touching see-through pixels, 1 px spikes / specks,
#     bits no longer joined to the truck.
# The roof (rows < 56) is the same in both shells; rows from the top deck down shift by 112 in the 3-deck shell.
import os
from collections import deque
from PIL import Image
D=os.path.join(os.path.dirname(os.path.abspath(__file__)),"../../../assets/vehicles/bastion_v3")
X0,Y0,FH,CW,CH=158,56,112,144,96
OUT=(1,1,2,255); BGC=(46,44,48)
WHEELS=((60,310),(116,310),(492,310),(548,310)); WR=24
SEAM=499
RAIL=((27,OUT),(28,(100,100,100,255)),(29,(81,81,80,255)),(30,(72,67,56,255)),(31,OUT))   # tube rows, top to bottom
RAIL_END=601          # last rail column before the bent end post (the rear ladder's posts start at x 605)
POSTS=(540,572)       # extra upright posts (x of their left outline), like the existing one at x 491
def dist(p): return sum(abs(a-b) for a,b in zip(p[:3],BGC))
def roof(px):
    # 1) the grey tarp roll (rows 15-26) and the red crate under the rail (rows 32-35) end 3 px before the seam with a
    #    real outline (round corners on the roll) instead of the straight cut + dark seam line
    E=SEAM-3
    for y in range(8,37):
        if 27<=y<=31: continue
        for x in range(E+1,SEAM+1): px[x,y]=(0,0,0,0)
    rows=[y for y in range(8,27) if px[E,y][3] and px[E-1,y][3]]
    for y in rows+[y for y in range(32,36) if px[E,y][3]]: px[E,y]=OUT
    if rows:                                 # round the roll's two right corners
        for y in (rows[0],rows[-1]):
            px[E,y]=(0,0,0,0); px[E-1,y]=OUT
    # 2) the rail goes on to the rear ladder
    for x in range(SEAM,RAIL_END):
        for y,c in RAIL: px[x,y]=c
        for y in range(32,36):
            if px[x,y][3] and x>SEAM: px[x,y]=(0,0,0,0)
    for x0 in POSTS:                         # 4 px post: outline, lit, shade, outline, from the rail to the slab
        for y in range(32,36):
            px[x0,y]=OUT; px[x0+1,y]=(97,96,92,255); px[x0+2,y]=(72,67,56,255); px[x0+3,y]=OUT
    # bent end post: the front end (x 154-158, rows 27-36) mirrored
    END={0:[(31,OUT),(32,OUT),(33,OUT),(34,OUT),(35,OUT)],
         1:[(29,(22,20,20,255)),(30,(3,3,2,255)),(31,(97,97,95,255)),(32,(93,99,96,255)),(33,(93,99,96,255)),(34,(93,99,96,255)),(35,(93,99,96,255))],
         2:[(28,(22,20,20,255)),(29,(41,41,40,255)),(30,(101,101,98,255)),(31,(105,103,90,255)),(32,(70,62,54,255)),(33,(77,85,82,255)),(34,(77,85,82,255)),(35,(77,85,82,255))],
         3:[(27,(22,20,20,255)),(28,(51,51,51,255)),(29,(94,100,96,255)),(30,(102,102,88,255)),(31,(85,81,69,255)),(32,(63,61,56,255)),(33,(64,64,60,255)),(34,(64,64,60,255)),(35,(62,58,47,255))]}
    for i,col in END.items():
        x=RAIL_END+3-i
        for y in range(24,36): px[x,y]=(0,0,0,0)
        for y,c in col: px[x,y]=c
    px[RAIL_END-1,32]=OUT                    # under-side of the bend
def pockets(px,W,H,dy):
    """backdrop-colour pockets on the roof, the rear ladder and under the chassis become see-through"""
    seen=bytearray(W*H)
    for y in range(H):
        for x in range(W):
            if seen[y*W+x] or not px[x,y][3] or dist(px[x,y])>6: continue
            q=deque([(x,y)]); seen[y*W+x]=1; pts=[]
            while q:
                a,b=q.popleft(); pts.append((a,b))
                for c,d in ((a+1,b),(a-1,b),(a,b+1),(a,b-1)):
                    if 0<=c<W and 0<=d<H and not seen[d*W+c] and px[c,d][3] and dist(px[c,d])<=6:
                        seen[d*W+c]=1; q.append((c,d))
            def zone(a,b):
                b2=b-dy if b>=Y0+FH else b
                if 27<=b<=31: return False      # the rail tube's own dark underside row
                return b<36 or b2>=286 and not any((a-cx)**2+(b2-cy)**2<=WR*WR for cx,cy in WHEELS) or a>=600
            if len(pts)>=3 and all(zone(a,b) for a,b in pts):
                for a,b in pts: px[a,b]=(0,0,0,0)
    for _ in range(3):                       # specks of backdrop left on the roof: see-through next to the sky, else the
        for y in range(36):                  # darkest neighbour (holes in the tarp roll / crates)
            if 27<=y<=31: continue
            for x in range(W):
                if not px[x,y][3] or dist(px[x,y])>6: continue
                nb=[px[x+a,y+b] for a,b in ((1,0),(-1,0),(0,1),(0,-1)) if 0<=x+a<W and 0<=y+b<H]
                if any(n[3]==0 for n in nb): px[x,y]=(0,0,0,0); continue
                ok=[n for n in nb if dist(n)>6]
                if ok: px[x,y]=min(ok,key=lambda n:sum(n[:3]))
def strays(px,W,H,floors):
    cl=[(X0+152*c,Y0+FH*r,X0+152*c+CW,Y0+FH*r+CH) for r in range(floors) for c in range(3)]
    skip=lambda x,y: any(a-1<=x<c+1 and b-1<=y<d+1 for a,b,c,d in cl)
    opn=lambda x,y: not(0<=x<W and 0<=y<H) or px[x,y][3]==0
    N4=((1,0),(-1,0),(0,1),(0,-1))
    for _ in range(4):                       # backdrop fringe peels one ring per pass
        hit=[(x,y) for y in range(H) for x in range(W) if px[x,y][3] and not skip(x,y) and dist(px[x,y])<=20
             and any(opn(x+a,y+b) for a,b in N4)]
        for x,y in hit: px[x,y]=(0,0,0,0)
    for _ in range(2):                       # 1 px spikes / specks
        hit=[(x,y) for y in range(H) for x in range(W) if px[x,y][3] and not skip(x,y)
             and sum(opn(x+a,y+b) for a,b in N4)>=3]
        for x,y in hit: px[x,y]=(0,0,0,0)
    seen=bytearray(W*H); comps=[]           # bits no longer joined to the truck
    for y in range(H):
        for x in range(W):
            if px[x,y][3]==0 or seen[y*W+x]: continue
            st=[(x,y)]; seen[y*W+x]=1; pts=[]
            while st:
                a,b=st.pop(); pts.append((a,b))
                for c,d in ((a+1,b),(a-1,b),(a,b+1),(a,b-1),(a+1,b+1),(a-1,b-1),(a+1,b-1),(a-1,b+1)):
                    if 0<=c<W and 0<=d<H and not seen[d*W+c] and px[c,d][3]:
                        seen[d*W+c]=1; st.append((c,d))
            comps.append(pts)
    comps.sort(key=len,reverse=True)
    for c in comps[1:]:
        for x,y in c: px[x,y]=(0,0,0,0)
def clean(path,dy,floors):
    im=Image.open(path).convert("RGBA"); W,H=im.size; px=im.load()
    roof(px)
    pockets(px,W,H,dy)
    strays(px,W,H,floors)
    im.save(path)
if __name__=="__main__":
    clean(f"{D}/shell_f2.png",0,2); clean(f"{D}/shell_f3.png",112,3); print("ok")
