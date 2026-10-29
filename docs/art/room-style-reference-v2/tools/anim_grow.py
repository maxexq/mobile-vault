# Grow room L1 animations (code layer over the PixelLab art), A = purple LED rack, B = tyres + tomatoes.
#   states: idle / working / powerout at the mature stage, plus a growth loop s1 -> s2 -> s3.
import sys,math,random
sys.path.insert(0,"/mnt/project-files/designs/room-redesign-preview/kitchen"); sys.path.insert(0,"/mnt/project-files/designs/room-redesign-preview")
from PIL import Image
from anim import add_glow,clip,darken,FPS
ROOMS={
 "A":{"lamps":[(65,20,34)],"col":(220,110,255),"plants":[(14,33,104,45)],"floor":90,"grower_x":58,"drip":None},
 "B":{"lamps":[(82,28,34)],"col":(255,180,90),"plants":[(54,22,128,62)],"floor":90,"grower_x":78,"drip":(38,50,61)},
 "A_L2":{"lamps":[(65,20,34),(80,28,26)],"col":(220,110,255),"plants":[(16,37,104,48)],"floor":90,"grower_x":58,"drip":None},
 "A_L3":{"lamps":[(66,22,38)],"col":(220,110,255),"plants":[(16,35,104,48)],"floor":90,"grower_x":58,"drip":None},
 "B_L2":{"lamps":[(82,18,34)],"col":(255,180,90),"plants":[(56,22,126,62)],"floor":90,"grower_x":78,"drip":(30,52,62)},
 "B_L3":{"lamps":[(83,28,36)],"col":(255,190,110),"plants":[(56,24,128,64)],"floor":90,"grower_x":78,"drip":(30,52,62)},
 # merged 2-slot (level 3): table + LED rack / raised beds with two bulbs
 "A_M2":{"lamps":[(56,14,34),(208,20,18),(208,40,18),(208,60,18)],"col":(220,110,255),"plants":[(8,30,104,47),(184,21,232,32),(184,41,232,52),(184,61,232,73)],"floor":92,"grower_x":200,"drip":None},
 "B_M2":{"lamps":[(82,24,34),(206,24,34)],"col":(255,180,90),"plants":[(54,28,96,66),(100,36,132,68),(156,26,234,70)],"floor":92,"grower_x":120,"drip":(27,50,60)},
}
def stage(k,s):
    return Image.open(f"out/gr{k}_s{s}.png").convert("RGBA")
def green(p): return p[1]>p[0]+8 and p[1]>p[2]+4
def frame(k,bg,t,state,rng,flick,spark=0.0):
    R=ROOMS[k]; im=bg.copy(); W,H=im.size; dark=state=="powerout"
    if state=="working":
        f=clip("plant_grower","work")[(t//2)%len(clip("plant_grower","work"))]
        im.alpha_composite(f,(R["grower_x"]-32,R["floor"]+1-53))
        span=W-32; ph=(t*2*span/96)%(2*span); x=16+(ph if ph<span else 2*span-ph); d=1 if ph<span else -1
        w=clip("teen_scrap_runner","walk")[t%8]; w=w if d>0 else w.transpose(Image.FLIP_LEFT_RIGHT)
        im.alpha_composite(w,(int(x)-32,R["floor"]+1-53))
    elif dark:
        f=clip("plant_grower","idle")[(t//3)%4]; im.alpha_composite(f,(W//2-32,R["floor"]+1-53))
    px=im.load()
    if dark:
        on=t in flick; im=darken(im,0.55 if on else 0.3); px=im.load()
        if on:
            for lx,ly,lr in R["lamps"]: add_glow(px,W,H,lx,ly+6,lr*3//4,R["col"],0.3)
        a=0.5+0.5*math.sin(t/FPS*2*math.pi*0.5)
        add_glow(px,W,H,6,6,34,(255,30,20),0.55*a)
        for x,y in [(5,5),(6,5),(5,6),(6,6)]: px[x,y]=(int(120+135*a),20,15,255)
        return im
    # grow light: steady with a rare flicker, leaves "breathe" a little under it
    on=t not in flick; amp=(0.26 if state=="working" else 0.22)*(0.93+0.07*math.sin(t*0.6)) if on else 0.06
    for lx,ly,lr in R["lamps"]: add_glow(px,W,H,lx,ly+8,lr,R["col"],amp)
    br=int(10*(0.5+0.5*math.sin(t/FPS*2*math.pi*0.25))) if on else 0
    for x0,y0,x1,y1 in R["plants"]:
        for y in range(y0,y1+1):
            for x in range(x0,x1+1):
                p=px[x,y]
                if green(p): px[x,y]=(p[0],min(255,p[1]+br),p[2],255)
    # B: water drips from the barrel hose into the seed box
    if R["drip"]:
        dx,dy0,dy1=R["drip"]; yy=dy0+(t%16)*(dy1-dy0)//15
        if t%16<15: px[dx,yy]=(150,200,230,255)
    # floating spores / pollen in the lamp light
    lx0,ly0,_=R["lamps"][0]
    for i in range(8):
        sx=(lx0-20+(i*13+t*0.3*(1+i%3))%40); sy=ly0+10+((i*7+t*0.15*(1+i%2))%28)
        xi,yi=int(sx),int(sy)
        if 0<=xi<W and 0<=yi<H and (t+i)%5: q=px[xi,yi]; px[xi,yi]=tuple(min(255,q[c]+45) for c in range(3))+(255,)
    # growth sparkle: green twinkles over the plant area while it changes stage
    if spark>0:
      for x0,y0,x1,y1 in R["plants"]:
        for _ in range(int(40*spark*(x1-x0)/90)):
            xi=rng.randint(x0,x1); yi=rng.randint(y0,y1)
            if green(px[xi,yi]) or rng.random()<0.3:
                px[xi,yi]=(200,255,170,255)
        add_glow(px,W,H,(x0+x1)//2,(y0+y1)//2,(x1-x0)//2+6,(150,255,120),0.25*spark)
    return im
def save(fr,path,scale=4):
    fr=[f.convert("RGB").resize((f.width*scale,f.height*scale),Image.NEAREST) for f in fr]
    fr[0].save(path,save_all=True,append_images=fr[1:],duration=1000//FPS,loop=0,optimize=True)
def states(k):
    for st in ("idle","working","powerout"):
        rng=random.Random(3); flick={t for t in range(96) if rng.random()<(0.10 if st=="powerout" else 0.03)}
        save([frame(k,stage(k,3),t,st,rng,flick) for t in range(96)],f"grow{k}_L1_{st}.gif")
def growth(k):
    rng=random.Random(5); fr=[]; HOLD=24; TR=8; bgs=[stage(k,s) for s in (1,2,3)]
    t=0
    for i in range(3):
        for _ in range(HOLD): fr.append(frame(k,bgs[i],t,"idle",rng,set())); t+=1
        nxt=bgs[(i+1)%3]
        for j in range(TR):
            src=bgs[i] if j<TR//2 else nxt; s=1-abs(j-(TR-1)/2)/(TR/2)
            fr.append(frame(k,src,t,"idle",rng,set(),spark=s)); t+=1
    save(fr,f"grow{k}_L1_growth.gif")
    for s in (1,2,3):  # each stage on its own, idle loop
        rng=random.Random(3); save([frame(k,bgs[s-1],t,"idle",rng,set()) for t in range(48)],f"grow{k}_L1_stage{s}.gif")
if __name__=="__main__":
    for k in sys.argv[1:] or "AB":
        states(k); growth(k); print(k)
