# Infirmary micro-animation layer (same idea as kitchen/anim.py + living/anim_lv.py): lamp glow + flicker, dust motes,
# IV drip, heart monitor ECG trace (L3 + merged, dark at power-out), surgery lamp; power-out = darken + slow red emergency light.
import math,random,sys,os
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
from anim import add_glow,darken,clip,FPS
ROOMS={
 "L1":dict(img="out/inf_A_7_0.png",lamps=[(66,12)],drips=[(74,40)],ecg=None,floor=90),
 "L2":dict(img="out/inf_L2_s1_0.png",lamps=[(66,12),(116,48)],drips=[(74,40)],ecg=None,floor=90),
 "L3":dict(img="out/inf_L3_s1_0.png",lamps=[(64,10)],drips=[(74,36)],ecg=(87,45,97,53),floor=90),
 "M2":dict(img="out/inf_M2L3_s2_0.png",lamps=[(64,9),(222,25)],drips=[(74,33)],ecg=(87,45,97,53),floor=94,
           walk=[(20,140,"medic"),(150,270,"scientist")],T=192),
 "M3":dict(img="out/inf_M3_s2_0.png",lamps=[(64,9),(278,6)],drips=[(74,33),(305,45),(316,42)],ecg=(87,45,97,53),ecg2=(324,34,334,41),floor=94,
           walk=[(20,200,"medic"),(200,410,"scientist")],T=192),
}
def ecg_frame(px,box,t):
    x0,y0,x1,y1=box; w=x1-x0+1; mid=(y0+y1)//2
    for x in range(x0,x1+1):
        for y in range(y0,y1+1): px[x,y]=(8,22,14,255)
    head=t%w
    for i in range(w):
        k=(i-head)%w  # pulse shape travels left->right, older trace fades
        y=mid
        p=(i+ (t//w)*0)%w
        ph=(i*3)%18
        if ph==6: y=mid-3
        elif ph==7: y=mid+2
        elif ph==9: y=mid-1
        age=(head-i)%w
        if age>w-3: continue  # gap ahead of the sweep
        g=max(60,230-age*12)
        px[x0+i,y]=(40,g,90,255)
def render(lv,state,seed=3):
    R=ROOMS[lv]; rng=random.Random(seed)
    bg=Image.open(R["img"]).convert("RGBA"); W,H=bg.size; px0=bg.load()
    for x in range(W):  # PixelLab leaves a white bottom row
        if min(px0[x,H-1][:3])>240: px0[x,H-1]=px0[x,H-2]
    TT=R.get("T",96); working=state=="working"; dark=state=="powerout"
    flick={t for t in range(TT) if rng.random()<(0.10 if dark else 0.03)}
    motes=[[rng.choice(R["lamps"])[0]+rng.uniform(-18,18),rng.uniform(8,60),rng.uniform(-.08,.08),rng.uniform(.03,.1)] for _ in range(10*len(R["lamps"]))]
    walks=R.get("walk",[(16,W-16,"medic"),(16,W-16,"scientist")])
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
            f=clip("medic","idle")[(t//3)%4]; im.alpha_composite(f,(W//2-32,R["floor"]+1-53))
        px=im.load()
        if R["ecg"] and not dark: ecg_frame(px,R["ecg"],t)
        if R.get("ecg2") and not dark: ecg_frame(px,R["ecg2"],t+7)
        for dx,dy in R["drips"]:  # IV drip: one drop falls every 24 frames
            k=t%24
            if k<5: px[dx,dy+k]=(200,225,235,255)
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
            for lx,ly in R["lamps"]: add_glow(px,W,H,lx,ly+8,34 if working else 30,(255,215,160),amp)
            for m in motes:
                m[0]+=m[2]; m[1]+=m[3]
                if m[1]>62: m[1]=8
                xi,yi=int(m[0]),int(m[1])
                if 0<=xi<W and 0<=yi<H and rng.random()<0.85:
                    p=px[xi,yi]; px[xi,yi]=tuple(min(255,p[i]+40) for i in range(3))+(255,)
            if R["ecg"]:
                x0,y0,x1,y1=R["ecg"]; add_glow(px,W,H,(x0+x1)//2,(y0+y1)//2,10,(80,255,140),0.10+0.05*((t%18)<3))
        out.append(im.convert("RGB"))
    return out
def save(fr,path,scale):
    fr=[f.resize((f.width*scale,f.height*scale),Image.NEAREST) for f in fr]
    fr[0].save(path,save_all=True,append_images=fr[1:],duration=1000//FPS,loop=0,optimize=True)
if __name__=="__main__":
    if sys.argv[1:2]==["marks"]:
        ims=[]
        for lv,R in ROOMS.items():
            im=Image.open(R["img"]).convert("RGB"); px=im.load()
            for x,y in R["lamps"]+R["drips"]:
                for d in range(-2,3): px[x+d,y]=(255,0,255); px[x,y+d]=(255,0,255)
            if R["ecg"]:
                x0,y0,x1,y1=R["ecg"]
                for x in range(x0,x1+1): px[x,y0]=px[x,y1]=(255,255,0)
            for x in range(im.width): px[x,R["floor"]]=(0,255,0)
            ims.append(im.resize((im.width*3,im.height*3),Image.NEAREST))
        S=Image.new("RGB",(max(i.width for i in ims),sum(i.height+6 for i in ims)));y=0
        for i in ims: S.paste(i,(0,y)); y+=i.height+6
        S.save(sys.argv[2]); sys.exit()
    for lv in sys.argv[1:] or ROOMS:
        sc=3 if lv[0]=="M" else 4
        for st in ["idle","working","powerout"]:
            save(render(lv,st),f"inf_{lv}_{st}.gif",sc); print(lv,st,flush=True)
