import math,random,sys
from PIL import Image,ImageChops
from gen import frames
FPS=12; T=96  # 8 s loop
# per-image anchors (native px): lamps, pots (steam origin), burners, floor y, extra glows
ROOMS={
 "L1":dict(img="out/k_L1_s1_0.png",lamps=[(65,9)],pots=[(44,40)],burners=[(44,51)],floor=90,glows=[],stove_x=34),
 "L2":dict(img="out/kitchen_7d_0.png",lamps=[(65,3)],pots=[(27,34)],burners=[(27,51),(46,51)],floor=90,glows=[],stove_x=18),
 "L3":dict(img="out/k_L3_s2_0.png",lamps=[(66,3)],pots=[(28,33)],burners=[(28,51),(47,51)],floor=90,
           glows=[((84,47),(80,255,120),"blink"),((102,46),(80,170,255),"steady")],stove_x=18),
 "B2":dict(img="out/k_B2_s2_0.png",lamps=[(66,3),(202,15),(234,15),(268,15)],pots=[(28,33)],burners=[(28,51),(47,51)],floor=94,
           glows=[((84,47),(80,255,120),"blink"),((102,46),(80,170,255),"steady"),((270,44),(255,120,60),"blink")],stove_x=18,walk=[(150,262,"teen_scrap_runner")],T=192),
 "B3":dict(img="out/k_B3full_s1_0.png",lamps=[(66,3),(205,14),(277,14),(349,14)],pots=[(28,33)],burners=[(28,51),(47,51)],floor=94,
           glows=[((84,47),(80,255,120),"blink"),((102,46),(80,170,255),"steady")],stove_x=18,walk=[(150,290,"teen_scrap_runner"),(285,412,"lounge_singer")],T=192),
 "W3":dict(img="out/k_X3i_s1_0.png",lamps=[(39,9),(93,13),(149,10),(281,14),(376,9)],pots=[(14,47)],burners=[(30,58)],floor=91,glows=[],stove_x=22),
}
CACHE={}
def clip(c,n):
    k=(c,n)
    if k not in CACHE: CACHE[k]=frames(c,n)
    return CACHE[k]
def add_glow(px,W,H,cx,cy,r,col,a):
    for y in range(max(0,cy-r),min(H,cy+r)):
        for x in range(max(0,cx-r),min(W,cx+r)):
            d=math.hypot(x-cx,(y-cy)*1.2)/r
            if d<1:
                k=a*(1-d)**2; p=px[x,y]
                px[x,y]=(min(255,int(p[0]+col[0]*k)),min(255,int(p[1]+col[1]*k)),min(255,int(p[2]+col[2]*k)),255)
def darken(im,f,tint=(0.75,0.85,1.15)):
    r,g,b,a=im.split()
    r=r.point(lambda v:int(v*f*tint[0])); g=g.point(lambda v:int(v*f*tint[1])); b=b.point(lambda v:min(255,int(v*f*tint[2])))
    return Image.merge("RGBA",(r,g,b,a))
class Steam:
    def __init__(s,origins,rate,rng): s.o=origins; s.rate=rate; s.p=[]; s.rng=rng
    def step(s):
        for ox,oy in s.o:
            for _ in range(s.rate):
                if s.rng.random()<0.5: s.p.append([ox+s.rng.uniform(-3,3),oy,0,s.rng.uniform(14,22)])
        for q in s.p: q[1]-=0.45; q[0]+=math.sin(q[2]*0.35+q[0])*0.25; q[2]+=1
        s.p=[q for q in s.p if q[2]<q[3]]
    def draw(s,px,W,H,bright=1.0):
        for x,y,age,life in s.p:
            xi,yi=int(x),int(y)
            if 0<=xi<W and 0<=yi<H:
                k=0.55*(1-age/life)*bright; p=px[xi,yi]
                px[xi,yi]=tuple(int(p[i]+(225-p[i])*k) for i in range(3))+(255,)
def render(level,state,seed=3):
    R=ROOMS[level]; rng=random.Random(seed)
    bg=Image.open(R["img"]).convert("RGBA"); W,H=bg.size
    working=state=="working"; dark=state=="powerout"
    steam=Steam(R["pots"],3 if working else 1,rng)
    motes=[[rng.choice(R["lamps"])[0]+rng.uniform(-18,18),rng.uniform(8,60),rng.uniform(-.08,.08),rng.uniform(.03,.1)] for _ in range(10*len(R["lamps"]))]
    cook=clip("street_cook","work"); walker=clip("teen_scrap_runner","walk"); widle=clip("teen_scrap_runner","idle")
    flick=set()
    TT=R.get("T",T)
    for t in range(TT):
        if rng.random()<(0.10 if dark else 0.03): flick.add(t)
    out=[]
    for _ in range(30): steam.step()
    for t in range(TT):
        im=bg.copy(); px=im.load()
        steam.step()
        # crew
        if working:
            f=cook[(t//1)%len(cook)]; im.alpha_composite(f,(R["stove_x"]+8-14,R["floor"]-53))
            for k,(x0,x1,ch) in enumerate(R.get("walk",[(30,W-40,"teen_scrap_runner")])):
                span=x1-x0; sp=2*span/TT if "walk" in R else 1.0
                ph=(t*sp+k*span)%(2*span); x=x0+(ph if ph<span else 2*span-ph); d=1 if ph<span else -1
                wf=clip(ch,"walk"); f=wf[t%8]; f=f if d>0 else f.transpose(Image.FLIP_LEFT_RIGHT)
                im.alpha_composite(f,(int(x)-14,R["floor"]+1-53))
        elif dark:
            f=widle[(t//3)%4].transpose(Image.FLIP_LEFT_RIGHT); im.alpha_composite(f,(W//2-6,R["floor"]+1-53))
        px=im.load()
        if dark:
            on = t in flick
            im=darken(im,0.6 if on else 0.3); px=im.load()
            if on:
                for lx,ly in R["lamps"]: add_glow(px,W,H,lx,ly+6,26,(255,190,90),0.35)
            # red emergency strobe top-left, slow pulse
            a=0.5+0.5*math.sin(t/FPS*2*math.pi*0.5)
            add_glow(px,W,H,6,6,34,(255,30,20),0.55*a)
            for x,y in [(5,5),(6,5),(5,6),(6,6)]: px[x,y]=(int(120+135*a),20,15,255)
            # gas burner keeps a tiny flame
            for bx,by in R["burners"][:1]:
                add_glow(px,W,H,bx,by,10,(60,120,255),0.35)
                for i in range(-2,3):
                    if rng.random()<0.7: px[bx+i,by-rng.randint(0,1)]=(90,160,255,255)
            steam.draw(px,W,H,0.35)
        else:
            on = not (t in flick)
            base=0.30 if working else 0.22
            amp=base*(0.92+0.08*math.sin(t*0.7)) if on else 0.05
            for lx,ly in R["lamps"]: add_glow(px,W,H,lx,ly+8,34 if working else 30,(255,180,90),amp)
            for m in motes:
                m[0]+=m[2]; m[1]+=m[3]
                if m[1]>62: m[1]=8
                xi,yi=int(m[0]),int(m[1])
                if 0<=xi<W and 0<=yi<H and rng.random()<0.85:
                    p=px[xi,yi]; px[xi,yi]=tuple(min(255,p[i]+40) for i in range(3))+(255,)
            nb=R["burners"] if working else R["burners"][:1]
            for bx,by in nb:
                add_glow(px,W,H,bx,by-2,12 if working else 8,(60,120,255),0.28 if working else 0.16)
                for i in range(-3,4):
                    if rng.random()<(0.8 if working else 0.4): px[bx+i,by-rng.randint(0,1 if working else 0)]=(110,180,255,255)
            steam.draw(px,W,H,1.0)
            for (gx,gy),col,mode in R["glows"]:
                lit = (t//6)%2==0 if mode=="blink" else True
                if lit:
                    add_glow(px,W,H,gx,gy,6,col,0.35)
                    px[gx,gy]=col+(255,)
        out.append(im.convert("RGB"))
    return out
def save(fr,path,scale=4):
    fr=[f.resize((f.width*scale,f.height*scale),Image.NEAREST) for f in fr]
    fr[0].save(path,save_all=True,append_images=fr[1:],duration=1000//FPS,loop=0,optimize=True)
if __name__=="__main__":
    for lv in sys.argv[1:] or ROOMS:
        sc=3 if lv[0] in "WB" else 4
        for st in ["idle","working","powerout"]:
            save(render(lv,st),f"out/kitchen_{lv}_{st}.gif",sc); print(lv,st,flush=True)
