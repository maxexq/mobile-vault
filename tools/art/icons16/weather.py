"""Weather icons for icons v4 (MV-775), code-drawn like the moods: one shared 16 px cloud, dark outline,
flat fills, simple precipitation under it (Parames ref 2026-11-13). No PixelLab. python3 weather.py [outdir]"""
import sys, os
from PIL import Image
T=(0,0,0,0); K=(30,32,44,255)
CW=(244,246,252,255); CS=(196,202,220,255)           # cloud white + underside
GW=(150,156,172,255); GS=(110,116,134,255)           # grey storm cloud
YW=(255,214,64,255); YS=(240,160,40,255)             # sun / bolt
BL=(96,170,240,255); GR=(130,214,70,255); SN=(236,242,255,255)
AS=(120,116,124,255); EM=(240,130,50,255); SA=(214,170,104,255); SD=(168,122,70,255); FG=(176,182,198,255)

def disc(cx,cy,r):
    return {(x,y) for y in range(16) for x in range(16) if (x+.5-cx)**2+(y+.5-cy)**2<=r*r}
CLOUD=["......####....",
       ".....######...",
       "..###.#######.",
       ".############.",
       "##############",
       "##############",
       ".############."]
def cloud_mask(dy=0):
    y0=1 if dy<0 else 4
    return {(1+x,y0+y) for y,r in enumerate(CLOUD) for x,c in enumerate(r) if c=="#"}
def outline(px):
    out={}
    for (x,y) in px:
        for dx,dy in((1,0),(-1,0),(0,1),(0,-1)):
            q=(x+dx,y+dy)
            if q not in px and 0<=q[0]<16 and 0<=q[1]<16: out[q]=K
    return out
def draw_cloud(px,dy=0,body=CW,shade=CS):
    m=cloud_mask(dy); bot=max(y for _,y in m)
    for (x,y) in m:
        px[(x,y)]=shade if (y>=bot or (x,y+1) not in m) else body
    return m
def finish(px,extra=()):
    o=outline(px); o.update({p:K for p in extra})
    for p,c in o.items(): px.setdefault(p,c)
    im=Image.new("RGBA",(16,16),T); P=im.load()
    for (x,y),c in px.items():
        if 0<=x<16 and 0<=y<16: P[x,y]=c
    return im
def drops(px,col,pts):
    for x,y in pts:
        px[(x,y)]=col; px[(x,y+1)]=col
def sun():
    px={}
    for p in disc(8,8,3.6): px[p]=YW
    for (x,y) in disc(8,8,3.6):
        if (x+1,y+1) not in disc(8,8,3.6) or (x,y+1) not in disc(8,8,3.6): px[(x,y)]=YS
    im=finish(px); P=im.load()
    for x,y in [(7,1),(8,1),(7,14),(8,14),(1,7),(1,8),(14,7),(14,8),(3,3),(12,3),(3,12),(12,12)]: P[x,y]=YW
    return im
def moon():
    px={}
    full=disc(7.5,8,5.6); cut=disc(10.6,6.2,4.4)
    for p in full-cut: px[p]=YW
    for (x,y) in list(px):
        if (x+1,y+1) not in px: px[(x,y)]=YS
    im=finish(px); P=im.load()
    for x,y in [(13,6),(14,2)]: P[x,y]=YW
    return im
def rain(col=BL):
    px={}; draw_cloud(px,-2.5)
    drops(px,col,[(3,11),(7,11),(11,11),(5,13),(9,13),(13,13)]); return finish(px)
def storm():
    px={}; draw_cloud(px,-2.5,GW,GS)
    bolt=[(9,6),(8,7),(8,8),(7,9),(8,9),(9,9),(9,10),(8,11),(8,12),(7,13),(7,14)]
    for p in bolt: px[p]=YW
    drops(px,BL,[(4,11),(12,11),(11,13)]); return finish(px)
def snow():
    px={}; draw_cloud(px,-2.5)
    im=finish(px); P=im.load()
    for cx,cy in [(4,11),(11,11),(7,13)]:
        for dx,dy in((0,0),(1,0),(-1,0),(0,1),(0,-1)): P[cx+dx,cy+dy]=SN
        for dx,dy in((1,1),(-1,-1),(1,-1),(-1,1)):
            if P[cx+dx,cy+dy][3]==0: P[cx+dx,cy+dy]=K
    return im
def fog():
    px={}; draw_cloud(px,-2.5)
    im=finish(px); P=im.load()
    for y,(a,b) in [(11,(2,13)),(13,(0,9)),(13,(11,14)),(15,(4,15))]:
        for x in range(a,b+1): P[x,y]=FG
    return im
def ash():
    px={}; draw_cloud(px,-2.5,GW,GS)
    im=finish(px); P=im.load()
    for x,y,c in [(3,11,AS),(4,11,AS),(8,12,EM),(12,11,AS),(12,12,AS),(5,14,AS),(6,14,AS),(10,14,EM),(13,15,AS)]: P[x,y]=c
    return im
def sand():
    px={}
    # wind streaks with a curl at the end, darker grains
    for y,(a,b) in [(3,(1,10)),(7,(4,13)),(11,(0,9))]:
        for x in range(a,b+1): px[(x,y)]=SA
        px[(b+1,y-1)]=SA; px[(b+1,y-2)]=SA; px[(b,y-2)]=SA
    im=finish(px); P=im.load()
    for x,y in [(13,4),(2,9),(12,13),(6,14),(14,10)]: P[x,y]=SD
    return im
ICONS={"sun":sun,"moon":moon,"fog":fog,"rain":rain,"acid":lambda:rain(GR),"storm":storm,"snow":snow,"ash":ash,"sand":sand}
if __name__=="__main__":
    out=sys.argv[1] if len(sys.argv)>1 else os.path.dirname(os.path.abspath(__file__))
    n=list(ICONS); sheet=Image.new("RGBA",(len(n)*144+16,160),(26,24,28,255))
    for i,k in enumerate(n):
        f=ICONS[k](); f.save(os.path.join(out,k+".png"))
        sheet.alpha_composite(f.resize((128,128),Image.NEAREST),(16+i*144,16))
    sheet.save(os.path.join(out,"weather_x8.png")); print("ok",n)
