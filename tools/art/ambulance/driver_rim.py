# MV-656: code-drawn steering wheel over the driver frames (side view: tall tilted ellipse rim + column to the dash), crop coords of the 64x64 cab crop.
from PIL import Image,ImageDraw
import math
def overlay(cx=31.0,cy=40.0,rx=2.6,ry=6.6,tilt=-14):
    big=Image.new("RGBA",(64*8,64*8),(0,0,0,0)); d=ImageDraw.Draw(big)
    def pts(rx_,ry_):
        a=math.radians(tilt); out=[]
        for i in range(72):
            t=2*math.pi*i/72; x,y=rx_*math.cos(t),ry_*math.sin(t)
            out.append(((cx+x*math.cos(a)-y*math.sin(a))*8,(cy+x*math.sin(a)+y*math.cos(a))*8))
        return out
    d.line([((cx+.5)*8,(cy+1)*8),((cx-2.5)*8,(cy+7.5)*8)],fill=(30,28,28,255),width=14)        # column down to the dash
    d.polygon(pts(rx+1.0,ry+1.0),fill=(16,14,14,255)); d.polygon(pts(rx-0.9,ry-0.9),fill=(0,0,0,0))   # rim with dark outline
    d.line(pts(rx,ry)[54:66],fill=(110,106,100,255),width=7)                                    # top-front highlight
    d.ellipse([(cx-1)*8,(cy-1)*8,(cx+1)*8,(cy+1)*8],fill=(60,58,56,255))                         # hub
    sm=big.resize((64,64),Image.BOX); px=sm.load()
    for y in range(64):
        for x in range(64):
            p=px[x,y]; px[x,y]=(p[0],p[1],p[2],255) if p[3]>110 else (0,0,0,0)
    return sm
RIM=overlay()
def apply(fr):
    """fr: 64x64 RGBA driver frame -> rim drawn over it, but skin (hand) pixels stay in front so the hand grips the rim"""
    out=fr.copy(); out.alpha_composite(RIM); po=out.load(); pf=fr.load(); pr=RIM.load()
    for y in range(64):
        for x in range(64):
            if pr[x,y][3]:
                r,g,b,_=pf[x,y]
                if r>140 and r-b>35 and r>g>b: po[x,y]=pf[x,y]
    return out
def ledge(fr):
    """A3: PixelLab wheel is in the frames already; pin the dash ledge + indicator lights so they don't drift between frames"""
    out=fr.copy(); px=out.load()
    for x in range(28,37): px[x,46]=(36,34,34,255)
    for x in range(28,35): px[x,45]=(58,56,54,255)
    px[30,45]=(236,170,60,255); px[33,45]=(120,210,110,255)
    return out
