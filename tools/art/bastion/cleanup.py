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
# MV-738 round 3 (Parames 2026-11-10 "เพิ่มขอบแต่ละห้อง, โปะรู pixel ที่หาย, Solar cell งอกมาตรงหน้าโครงรถชั้น 2"):
#  5) every enclosed see-through hole in the body (not a room window, not the gaps under the roof rail, not the
#     bumper hoop) gets the darkest opaque neighbour, so no sky shows through the truck,
#  6) every room window gets the Decker's steel frame (MV-739): 1 px black + 2 px riveted steel around the opening
#     and a soft inner shadow, so the rooms sit in the box instead of floating,
#  7) a fold-out solar array grows from the box's front wall at deck 2 (above the cab): two framed panels on two
#     arms + a stay, flat side view (the panels face the viewer); its cells are SOLAR_CELL colours (anim.py finds them
#     for the glint),
#  8) a small red tail lamp + amber marker on the rear bumper (the art had none) for the code lights.
STEEL=(85,81,69,255); LIGHT=(128,122,104,255); SHADE=(52,47,38,255); RIVET=(158,150,126,255)
SOLAR_CELL=((28,34,52,255),(34,44,66,255),(52,64,88,255))
SOLAR_GRID=(78,84,90,255)
def holes(px,W,H,floors):
    seen=bytearray(W*H); q=deque()
    for x in range(W): q.extend(((x,0),(x,H-1)))
    for y in range(H): q.extend(((0,y),(W-1,y)))
    for r in range(floors):
        for c in range(3): q.append((X0+152*c+5,Y0+FH*r+5))
    while q:
        x,y=q.popleft()
        if not(0<=x<W and 0<=y<H) or seen[y*W+x] or px[x,y][3]: continue
        seen[y*W+x]=1; q.extend(((x+1,y),(x-1,y),(x,y+1),(x,y-1)))
    dy=H-344
    for y in range(H):
        for x in range(W):
            if px[x,y][3] or seen[y*W+x]: continue
            st=[(x,y)]; seen[y*W+x]=1; pts=[]
            while st:
                a,b=st.pop(); pts.append((a,b))
                for c,d in ((a+1,b),(a-1,b),(a,b+1),(a,b-1)):
                    if 0<=c<W and 0<=d<H and not seen[d*W+c] and px[c,d][3]==0: seen[d*W+c]=1; st.append((c,d))
            ys=[b for a,b in pts]; xs=[a for a,b in pts]
            if 31<=min(ys) and max(ys)<=36 and min(xs)>=X0: continue      # gaps between the roof rail and the roof
            if len(pts)>60: continue                                        # the bumper hoop and other real openings
            todo=set(pts)
            while todo:
                nxt=set()
                for a,b in todo:
                    nb=[px[a+i,b+j] for i,j in ((1,0),(-1,0),(0,1),(0,-1)) if 0<=a+i<W and 0<=b+j<H and px[a+i,b+j][3]]
                    if nb: px[a,b]=min(nb,key=lambda c:sum(c[:3]))[:3]+(255,)
                    else: nxt.add((a,b))
                if nxt==todo: break
                todo=nxt
def frame(px,floors):
    for row in range(floors):
        for col in range(3):
            x0,y0=X0+152*col,Y0+FH*row; x1,y1=x0+CW,y0+CH
            for d in (1,2,3):
                for x in range(x0-d,x1+d):
                    for y in (y0-d,y1+d-1): ring(px,x,y,d,y==y0-d,x0,y0,x1,y1)
                for y in range(y0-d,y1+d):
                    for x in (x0-d,x1+d-1): ring(px,x,y,d,x==x0-d,x0,y0,x1,y1)
            for x in range(x0,x1):
                for i,a in enumerate((150,90,40)): shade(px,x,y0+i,a)
                shade(px,x,y1-1,60)
            for y in range(y0+3,y1-1):
                for i,a in enumerate((90,35)): shade(px,x0+i,y,a); shade(px,x1-1-i,y,a)
def ring(px,x,y,d,tl,x0,y0,x1,y1):
    if d==1: px[x,y]=(8,8,10,255); return
    if d==2:
        c=LIGHT if tl else SHADE
        along=x if y in (y0-2,y1+1) else y
        if along%12==6 and x0-2<x<x1+1 and y0-2<y<y1+1: c=RIVET
        px[x,y]=c; return
    if px[x,y][3]==0 or sum(px[x,y][:3])>360: px[x,y]=STEEL
def shade(px,x,y,a):
    if px[x,y][3]==0: px[x,y]=(8,6,6,a)
SOLAR=dict(x0=100,x1=140,top=8,pan=46,gap=4)     # panels: x 100-139, from deck top + 8, 2 x 46 tall, 4 px hinge gap
def solar(px,floors):
    top=Y0+FH*(floors-2)                         # deck 2 counted from the road
    x0,x1=SOLAR["x0"],SOLAR["x1"]
    wall=146
    for k in range(2):
        py0=top+SOLAR["top"]+k*(SOLAR["pan"]+SOLAR["gap"]); py1=py0+SOLAR["pan"]
        for y in range(py0,py1):
            for x in range(x0,x1):
                e=x in (x0,x1-1) or y in (py0,py1-1)
                f=x in (x0+1,x1-2) or y in (py0+1,py1-2)
                if e: c=OUT
                elif f: c=LIGHT if (y==py0+1 or x==x0+1) else SHADE
                else:
                    cx,cy=x-(x0+2),y-(py0+2)
                    if cx%9==8 or cy%7==6: c=SOLAR_GRID
                    else:
                        band=(cx+cy//2)%9
                        c=SOLAR_CELL[2] if band<2 and cy%7<2 else (SOLAR_CELL[1] if (cx//9+cy//7)%2 else SOLAR_CELL[0])
                px[x,y]=c
        # arm from the panel's mid height to the wall: 3 px steel bar with an outline, bolt plate on the wall
        ay=py0+SOLAR["pan"]//2-1
        for x in range(x1,wall+1):
            px[x,ay-1]=OUT; px[x,ay]=LIGHT; px[x,ay+1]=STEEL; px[x,ay+2]=OUT
        for y in range(ay-4,ay+6):
            for x in (wall-2,wall-1):
                px[x,y]=OUT if y in (ay-4,ay+5) or x==wall-2 else STEEL
        px[wall-1,ay-2]=RIVET; px[wall-1,ay+3]=RIVET
    # hinge between the panels, rust on the frames, one cracked cell and a power cable drooping to the wall
    hy=top+SOLAR["top"]+SOLAR["pan"]
    for y in range(hy,hy+SOLAR["gap"]):
        for x in (x0+6,x0+7,x1-8,x1-7): px[x,y]=OUT if x in (x0+6,x1-8) else STEEL
    RUST=((112,62,36,255),(92,50,30,255))
    for k,(rx,ry) in enumerate(((x0+1,top+20),(x0+1,top+21),(x1-2,top+70),(x1-2,top+71),(x0+12,top+SOLAR["top"]+1),(x0+13,top+SOLAR["top"]+1),
                                (x0+25,hy+SOLAR["gap"]+SOLAR["pan"]-2),(x0+26,hy+SOLAR["gap"]+SOLAR["pan"]-2))):
        px[rx,ry]=RUST[k%2]
    cx0,cy0=x0+2+9*2,top+SOLAR["top"]+2+7*3        # crack across one cell of the upper panel
    for i in range(7):
        px[cx0+i,cy0+(i*5)//7]=(120,136,160,255)
    fy=top+SOLAR["top"]+2*SOLAR["pan"]+SOLAR["gap"]-6
    for i,x in enumerate(range(x1,wall)):
        y=fy+round(3*(1-((i-(wall-x1)/2)/((wall-x1)/2))**2))
        px[x,y]=OUT; px[x,y+1]=(30,28,26,255)
TAIL=(622,279); MARK=(622,272)                   # rear bumper end (2-deck coords; +dy below the top deck)
HEAD=(40,271)                                    # round headlamp in the fender arch beside the winch
def lamps(px,dy):
    hx,hy=HEAD[0],HEAD[1]+dy
    for y in range(hy-5,hy+6):
        for x in range(hx-5,hx+6):
            r=((x+.5-hx-.5)**2+(y+.5-hy-.5)**2)**.5
            if r<=2.6: px[x,y]=(255,252,232,255) if (x<hx and y<hy) else ((236,228,184,255) if y<=hy else (204,192,146,255))
            elif r<=3.7: px[x,y]=(140,134,114,255) if (x<=hx and y<=hy) else (70,66,56,255)
            elif r<=4.6: px[x,y]=OUT
    for (x0,y0),lit,dim in ((TAIL,(200,40,30,255),(120,20,16,255)),(MARK,(220,140,40,255),(140,84,24,255))):
        y0+=dy
        for y in range(y0-1,y0+4):
            for x in range(x0-1,x0+3):
                e=x in (x0-1,x0+2) or y in (y0-1,y0+3)
                px[x,y]=OUT if e else (lit if y==y0 else dim)
def clean(path,dy,floors):
    im=Image.open(path).convert("RGBA"); W,H=im.size; px=im.load()
    roof(px)
    pockets(px,W,H,dy)
    strays(px,W,H,floors)
    holes(px,W,H,floors)
    lamps(px,dy)
    frame(px,floors)
    solar(px,floors)
    im.save(path)
if __name__=="__main__":
    clean(f"{D}/shell_f2.png",0,2); clean(f"{D}/shell_f3.png",112,3); print("ok")
