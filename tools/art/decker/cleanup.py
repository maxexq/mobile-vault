# MV-739 Decker shell cleanup (Parames 2026-11-09, code only, 0 PixelLab gens), run after shell.py:
#   python3 tools/art/decker/cleanup.py   -> rewrites assets/vehicles/decker_v3/shell_f{2,3}.png in place
# 1) removes the upright rust plate standing in front of the headlight and re-outlines the nose,
# 2) removes stray pixels under the chassis and around the wheels: the dotted ground strip, the cast
#    shadow behind the rear axle and the cable ends hanging under the floor.
# 3) gives every room window a steel frame (MV-739 "add a border to each room"): 1 px black + 2 px riveted steel
#    around the opening on the shell, and a soft inner shadow on the opening's top / sides (the shell is drawn over
#    the rooms), so the rooms sit inside the bus instead of looking pasted on.
# 4) MV-739 round 2: background pockets the flood fill in shell.py could not reach (the PixelLab backdrop colour
#    46,44,48 left inside the roof rail, between the rear roof ladder rungs and between the cables / tanks under the
#    chassis, plus the sliver behind the rear tyre) become see-through; the "9 DEPOT" sign face keeps its colour.
# Rows below the 2-deck roof shift down 112 px in the 3-deck shell (deck3.py inserts a deck), so every
# coordinate is the 2-deck one + dy.
import os
from PIL import Image
D=os.path.join(os.path.dirname(os.path.abspath(__file__)),"../../../assets/vehicles/decker_v3")
WHEELS=((62.5,310.0),(452.5,310.0),(504.5,310.0)); R=23.0
OUT=(8,8,10,255)
BGC=(46,44,48)
def in_wheel(x,y):
    return any((x+.5-cx)**2+(y+.5-cy)**2<=R*R for cx,cy in WHEELS)
X0,Y0,FH,CW,CH=104,56,112,144,96
STEEL=(85,81,69,255); LIGHT=(128,122,104,255); SHADE=(52,47,38,255); RIVET=(158,150,126,255)
def frame(px,W,H,dy,floors):
    for row in range(floors):
        for col in range(3):
            x0,y0=X0+152*col,Y0+FH*row; x1,y1=x0+CW,y0+CH
            for d in (1,2,3):                     # rings outside the opening
                for x in range(x0-d,x1+d):
                    for y in (y0-d,y1+d-1):
                        ring(px,x,y,d,y==y0-d,x0,y0,x1,y1)
                for y in range(y0-d,y1+d):
                    for x in (x0-d,x1+d-1):
                        ring(px,x,y,d,x==x0-d,x0,y0,x1,y1)
            for x in range(x0,x1):                # inner shadow: the frame's lip over the room's top / sides
                for i,a in enumerate((150,90,40)): blend(px,x,y0+i,a)
                blend(px,x,y1-1,60)
            for y in range(y0+3,y1-1):
                for i,a in enumerate((90,35)): blend(px,x0+i,y,a); blend(px,x1-1-i,y,a)
def ring(px,x,y,d,tl,x0,y0,x1,y1):
    if d==1: px[x,y]=(8,8,10,255); return
    if d==2:
        c=LIGHT if tl else SHADE
        along=x if y in (y0-2,y1+1) else y
        if along%12==6 and x0-2<x<x1+1 and y0-2<y<y1+1: c=RIVET
        px[x,y]=c; return
    if px[x,y][3]==0 or sum(px[x,y][:3])>360: px[x,y]=STEEL   # d=3 only fills sky / pale body, keeps beams
def blend(px,x,y,a):
    if px[x,y][3]==0: px[x,y]=(8,6,6,a)
# MV-739 round 2: a new headlight drawn in code. The nose is rebuilt flat (x 9 = outline, body paint behind it) over the
# old glow blob, then an old bus headlamp: square housing 7x10 with a steel bezel and a pale lens, its top-left lit;
# the amber indicator next to it (x 15-18) stays. AmbulanceMotion's "head" glow sits on the lens centre (12.5, 269.5).
HL=dict(x0=9,y0=264,w=7,h=11)
PAINT=((110,120,94),(108,118,93),(104,114,90),(98,107,85))
def headlight(px,dy):
    for y in range(258,282):                     # flat nose: outline column + body paint
        for x in range(9,15):
            if x==9: px[x,y+dy]=OUT
            elif y==258 and x<12: px[x,y+dy]=OUT
            elif not (x==14 and 269<=y<=277): px[x,y+dy]=PAINT[(x+y)%4]+(255,)
    x0,y0,w,h=HL["x0"],HL["y0"],HL["w"],HL["h"]
    for y in range(y0,y0+h):
        for x in range(x0,x0+w):
            e=x in (x0,x0+w-1) or y in (y0,y0+h-1)
            b=x in (x0+1,x0+w-2) or y in (y0+1,y0+h-2)
            if e: c=OUT
            elif b: c=(140,134,114,255) if (y==y0+1 or x==x0+1) else (70,66,56,255)
            else:
                lx,ly=x-(x0+2),y-(y0+2)          # lens 3x7
                c=(255,252,232,255) if (lx==0 and ly<=1) else ((236,228,184,255) if ly<4 else (204,192,146,255))
            px[x,y+dy]=c
    px[x0+w-1,y0+h+dy]=OUT                       # mounting bolt shadow under the housing
def clean(path,dy,floors):
    im=Image.open(path).convert("RGBA"); W,H=im.size; px=im.load(); clear=(0,0,0,0)
    # 1) headlight plate: columns 0..8, rows 253..281 (the bumper starts at 282)
    for y in range(253,282):
        for x in range(0,9): px[x,y+dy]=clear
    headlight(px,dy)
    # 2) under the chassis / wheels
    for y in range(301,344):
        for x in range(W):
            if px[x,y+dy][3]==0 or in_wheel(x,y): continue
            if (y>=331 or (x>=528 and y>=309) or (264<=x<=276)): px[x,y+dy]=clear
            elif y>=304 and 512<=x<=545: px[x,y+dy]=clear      # mudflap shadow wedge behind the rear tyre
    for y in range(H):                           # 4) background pockets
        y2=y-dy if y>=56 else y                  # 2-deck coordinate (rows from the top deck down shift by dy)
        for x in range(W):
            p=px[x,y]
            if p[3]==0 or sum(abs(a-b) for a,b in zip(p[:3],BGC))>6: continue
            if (y<56 and not (18<=y<=38 and 22<=x<=76)) or y2>=286: px[x,y]=clear
    frame(px,W,H,dy,floors)
    im.save(path)
if __name__=="__main__":
    clean(f"{D}/shell_f2.png",0,2); clean(f"{D}/shell_f3.png",112,3); print("ok")
