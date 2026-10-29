# Living room micro-animation layer (same idea as kitchen/anim.py): lamp glow + flicker, dust motes, TV screen flicker,
# device LEDs; power-out = darken + slow red emergency light + lamp flicker. Crew walk on the front floor strip.
import math,random,sys,os
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
from anim import add_glow,darken,clip,FPS
ROOMS={
 "L1":dict(img="out/lv_A_7_0.png",lamps=[(65,9)],tv=None,leds=[],floor=90),
 "L2":dict(img="out/lv_L2_s1_0.png",lamps=[(65,10),(95,46)],tv=(119,43,8),leds=[],floor=90),
 "L3":dict(screen=(124,47),img="out/lv_L3_s1_0.png",lamps=[(67,11),(91,14)],tv=(124,43,9),leds=[((133,58),(80,255,120))],floor=90),
 "M2":dict(screen=(124,47),img="out/m2_s2_0.png",lamps=[(65,11),(91,14),(197,14),(225,12)],tv=(124,43,9),leds=[((133,58),(80,255,120))],floor=94,
           walk=[(20,140,"teen_scrap_runner"),(150,270,"lounge_singer")],T=192),
 "M3":dict(screen=(122,47),img="out/m3_s1_0.png",lamps=[(65,10),(90,16),(258,6),(350,25)],tv=(122,47,9),leds=[],floor=94,
           walk=[(20,200,"teen_scrap_runner"),(200,410,"lounge_singer")],T=192),
}
def screen_mask(im,seed,er=2):
    # flat-screen TV: dark pixels connected to seed, eroded so the bezel stays
    px=im.load(); m=set(); st=[seed]
    while st:
        a,b=st.pop()
        if (a,b) in m or not(110<=a<140 and 30<=b<64) or sum(px[a,b][:3])/3>=16: continue
        m.add((a,b)); st+=[(a+1,b),(a-1,b),(a,b+1),(a,b-1)]
    for _ in range(er): m={(x,y) for x,y in m if {(x+1,y),(x-1,y),(x,y+1),(x,y-1)}<=m}
    return m
CH=[((40,70,120),(200,170,90)),((30,90,60),(230,230,210)),((120,40,40),(250,200,80)),((50,50,90),(120,220,255))]
def tv_frame(px,mask,t,rng):
    xs=[p[0] for p in mask]; ys=[p[1] for p in mask]; x0,x1,y0,y1=min(xs),max(xs),min(ys),max(ys)
    ch=(t//32)%len(CH); bgc,fg=CH[ch]; k=t%32
    for x,y in mask:
        u=(x-x0)/max(1,x1-x0); v=(y-y0)/max(1,y1-y0)
        if k<2:  # channel change: static
            g=rng.randint(40,200); c=(g,g,g)
        else:
            c=tuple(int(bgc[i]*(1.05-0.45*v)) for i in range(3))
            if ch%2==0:  # moving shape
                cx=0.2+0.6*((t%64)/64); 
                if (u-cx)**2*4+(v-0.55)**2*3<0.05: c=fg
            else:  # bars/text lines scrolling
                if int(v*8+t*0.25)%3==0 and 0.15<u<0.85: c=fg
            if (y+t)%3==0: c=tuple(int(q*0.8) for q in c)  # scanlines
        px[x,y]=c+(255,)
def render(lv,state,seed=3):
    R=ROOMS[lv]; rng=random.Random(seed)
    bg=Image.open(R["img"]).convert("RGBA"); W,H=bg.size; px0=bg.load()
    for x in range(W):  # PixelLab leaves a white bottom row
        if px0[x,H-1][:3]==(255,255,254): px0[x,H-1]=px0[x,H-2]
    mask=screen_mask(bg,R["screen"]) if R.get("screen") else None
    TT=R.get("T",96); working=state=="working"; dark=state=="powerout"
    flick={t for t in range(TT) if rng.random()<(0.10 if dark else 0.03)}
    motes=[[rng.choice(R["lamps"])[0]+rng.uniform(-18,18),rng.uniform(8,60),rng.uniform(-.08,.08),rng.uniform(.03,.1)] for _ in range(10*len(R["lamps"]))]
    walks=R.get("walk",[(16,W-16,"teen_scrap_runner"),(16,W-16,"lounge_singer")])
    out=[]
    for t in range(TT):
        im=bg.copy()
        if working:
            for k,(x0,x1,ch) in enumerate(walks):
                span=x1-x0; ph=(t*2*span/TT+(k*span if "walk" not in R else k*span*0.5))%(2*span)
                x=x0+(ph if ph<span else 2*span-ph); d=1 if ph<span else -1
                f=clip(ch,"walk")[t%8]; f=f if d>0 else f.transpose(Image.FLIP_LEFT_RIGHT)
                im.alpha_composite(f,(int(x)-32,R["floor"]+1-53))
        elif dark:
            f=clip("teen_scrap_runner","idle")[(t//3)%4]; im.alpha_composite(f,(W//2-32,R["floor"]+1-53))
        px=im.load()
        if mask and not dark: tv_frame(px,mask,t,rng)  # TV on unless power is out
        if dark:
            on=t in flick; im=darken(im,0.6 if on else 0.3); px=im.load()
            if on:
                for lx,ly in R["lamps"]: add_glow(px,W,H,lx,ly+6,26,(255,190,90),0.35)
            a=0.5+0.5*math.sin(t/FPS*2*math.pi*0.5)
            add_glow(px,W,H,6,6,34,(255,30,20),0.55*a)
            for x,y in [(5,5),(6,5),(5,6),(6,6)]: px[x,y]=(int(120+135*a),20,15,255)
        else:
            on=t not in flick; base=0.30 if working else 0.22
            amp=base*(0.92+0.08*math.sin(t*0.7)) if on else 0.05
            for lx,ly in R["lamps"]: add_glow(px,W,H,lx,ly+8,34 if working else 30,(255,180,90),amp)
            for m in motes:
                m[0]+=m[2]; m[1]+=m[3]
                if m[1]>62: m[1]=8
                xi,yi=int(m[0]),int(m[1])
                if 0<=xi<W and 0<=yi<H and rng.random()<0.85:
                    p=px[xi,yi]; px[xi,yi]=tuple(min(255,p[i]+40) for i in range(3))+(255,)
            if R["tv"] and (working or mask):  # TV on: cold flickering screen glow
                tx,ty,r=R["tv"]; c=(90,140,255) if (t//4)%3 else (160,200,255)
                add_glow(px,W,H,tx,ty,r+10,c,0.18+0.08*rng.random())
            for (gx,gy),col in R["leds"]:
                if (t//6)%2==0: add_glow(px,W,H,gx,gy,5,col,0.35); px[gx,gy]=col+(255,)
        out.append(im.convert("RGB"))
    return out
def save(fr,path,scale):
    fr=[f.resize((f.width*scale,f.height*scale),Image.NEAREST) for f in fr]
    fr[0].save(path,save_all=True,append_images=fr[1:],duration=1000//FPS,loop=0,optimize=True)
if __name__=="__main__":
    if sys.argv[1:2]==["marks"]:
        for lv,R in ROOMS.items():
            im=Image.open(R["img"]).convert("RGB"); px=im.load()
            for x,y in R["lamps"]+([R["tv"][:2]] if R["tv"] else [])+[g for g,_ in R["leds"]]:
                for d in range(-2,3): px[x+d,y]=(255,0,255); px[x,y+d]=(255,0,255)
            for x in range(im.width): px[x,R["floor"]]=(0,255,0)
            im.resize((im.width*3,im.height*3),Image.NEAREST).save(f"/tmp/claude-0/-home-user/84730026-32f3-5580-877d-5d1e398ff3f9/scratchpad/mk_{lv}.png")
        sys.exit()
    for lv in sys.argv[1:] or ROOMS:
        sc=3 if lv[0]=="M" else 4
        for st in ["idle","working","powerout"]:
            save(render(lv,st),f"living_{lv}_{st}.gif",sc); print(lv,st,flush=True)
