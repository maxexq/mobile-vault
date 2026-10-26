"""Animate the approved compact trait-card study; write review files only.
Only existing emissive rims/aura and bounded outside pixels change. Card content is fixed.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance
import hashlib
import json
import math

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[4]
SOURCE=HERE.parent/"traits-ui-v3-rarity-effects/trait-rarity-positive-negative-preview.png"
seed=Image.open(SOURCE).convert("RGB")
assert seed.size==(1536,1024)
N=16
DURATIONS=[120,130]*8
NAMES=["common","uncommon","rare","epic","legendary","mythic"]
COLORS=[(190,190,177),(88,225,65),(51,166,255),(190,58,252),(255,175,44),(255,59,86)]
HOT=[(238,236,217),(194,255,161),(181,239,255),(243,180,255),(255,236,165),(255,180,185)]
RED=(214,43,42)
RED_HOT=(255,118,83)
BOXES_POS=[(40,170,506,303),(545,170,993,303),(1034,170,1498,303),
           (40,337,506,470),(545,337,993,470),(1034,337,1498,470)]
BOXES_NEG=[(40,581,506,713),(545,581,993,713),(1034,581,1498,713),
           (40,758,506,890),(545,758,993,890),(1034,758,1498,890)]
BACKGROUND=(15,15,19)

def blend(a,b,t):
    return tuple(round(x+(y-x)*t) for x,y in zip(a,b))

def scaled(color,t):
    return tuple(round(c*t) for c in color)

def perimeter(box,expand=0):
    x0,y0,x1,y1=box
    x0-=expand; y0-=expand; x1+=expand; y1+=expand
    vertices=[(x0+4,y0),(x1-4,y0),(x1,y0+4),(x1,y1-4),
              (x1-4,y1),(x0+4,y1),(x0,y1-4),(x0,y0+4)]
    pts=[]
    for (ax,ay),(bx,by) in zip(vertices,vertices[1:]+vertices[:1]):
        steps=max(abs(bx-ax),abs(by-ay))
        for i in range(0,steps,4):
            pts.append((round(ax+(bx-ax)*i/steps),round(ay+(by-ay)*i/steps)))
    return pts

cards=[]
for negative,boxes in [(False,BOXES_POS),(True,BOXES_NEG)]:
    for rank,box in enumerate(boxes):
        x0,y0,x1,y1=box
        outer=(x0-14,y0-14,x1+14,y1+14)
        roi=seed.crop(outer)
        mask=Image.new("L",roi.size,0)
        pixels=roi.load()
        m=mask.load()
        inside=(x0+12,y0+12,x1-12,y1-12)
        for y in range(roi.height):
            gy=outer[1]+y
            for x in range(roi.width):
                gx=outer[0]+x
                if inside[0]<=gx<inside[2] and inside[1]<=gy<inside[3]:
                    continue
                r,g,b=pixels[x,y]
                emissive=(max(r,g,b)-min(r,g,b)>45 and max(r,g,b)>65)
                if negative:
                    emissive=emissive and r>g*1.45 and r>b*1.3
                elif rank==0:
                    # Common's bright silver rim is emissive; dark neutral border stays fixed.
                    emissive=max(r,g,b)>150 and max(r,g,b)-min(r,g,b)<65
                if emissive:
                    m[x,y]=255
        cards.append({"negative":negative,"rank":rank,"box":box,"outer":outer,
                      "roi":roi,"mask":mask,"inside":inside,
                      "rim":perimeter((x0+3,y0+3,x1-3,y1-3)),
                      "orbit":perimeter(box,8)})

frames=[]
for index in range(N):
    image=seed.copy()
    for card in cards:
        rank=card["rank"]
        negative=card["negative"]
        phase=(index+rank*2)%N
        pulse=round((1-math.cos(math.tau*phase/N))*2)/4
        if negative:
            # An uneven low-amplitude hazard flicker, never full-card flashing.
            flicker=[0.62,0.70,0.66,0.84,0.73,0.97,0.76,0.82,
                     0.68,0.73,0.92,0.80,0.66,0.71,0.78,0.68][phase]
            gain=0.86+(flicker-0.75)*(0.35+rank*0.13)
        else:
            gain=(0.88+0.10*pulse) if rank==0 else (0.68+0.32*pulse)
        lit=ImageEnhance.Brightness(card["roi"]).enhance(gain)
        image.paste(lit,card["outer"][:2],card["mask"])
        d=ImageDraw.Draw(image)
        rim=card["rim"]
        if negative:
            # Short disconnected hot edges, retaining the source cracked border.
            head=(phase*len(rim)//N+rank*11)%len(rim)
            length=3+rank
            for k in range(length):
                if k%3==2:
                    continue
                x,y=rim[(head+k)%len(rim)]
                d.rectangle((x,y,x+2,y+2),fill=blend(RED,RED_HOT,0.6-k/max(1,length)*0.4))
            count=[0,1,2,3,4,6][rank]
            x0,y0,x1,y1=card["box"]
            height=y1-y0
            for p in range(count):
                age=(phase+p*5)%N
                x=(x0-8 if p%2==0 else x1+5)+((age//4+p)%2)*2
                y=y0+(age*height//N)//4*4
                c=blend(scaled(RED,0.4),RED_HOT,(N-age)/N*0.75)
                side=3 if rank==5 and p%3==0 else 2
                d.rectangle((x,y,x+side,y+side),fill=c)
            if rank>=4:
                # Brief soot-dark breaks at fixed frame corners; no text distortion.
                x,y=rim[(rank*31+phase//2*4)%len(rim)]
                d.rectangle((x,y,x+3,y+3),fill=scaled(RED,0.25))
        else:
            head=phase*len(rim)//N
            length=3 if rank==0 else 5+rank
            for offset in ([0,len(rim)//2] if rank>=3 else [0]):
                for k in range(length):
                    x,y=rim[(head+offset-k)%len(rim)]
                    c=blend(COLORS[rank],HOT[rank],(length-k)/length)
                    side=2 if rank==0 else 3
                    d.rectangle((x,y,x+side-1,y+side-1),fill=c)
            count=[0,1,2,3,4,5][rank]
            orbit=card["orbit"]
            for p in range(count):
                # Clean closed-path motes rather than particles crossing the text.
                x,y=orbit[(phase*len(orbit)//N+p*len(orbit)//count)%len(orbit)]
                c=blend(COLORS[rank],HOT[rank],0.2+0.6*((phase+p)%4)/3)
                side=2 if rank<4 else 3
                d.rectangle((x,y,x+side-1,y+side-1),fill=c)
        # Restore the exact whole card interior, including title, tier tag, warning, icon and values.
        inside=card["inside"]
        image.paste(seed.crop(inside),inside[:2])
    frames.append(image)

for card in cards:
    expected=seed.crop(card["inside"]).tobytes()
    assert all(im.crop(card["inside"]).tobytes()==expected for im in frames), "Trait content moved"
    hashes={hashlib.sha256(im.crop(card["outer"]).tobytes()).hexdigest() for im in frames}
    assert len(hashes)>1, "A tier has no animation"

# One palette for all frames preserves all text/icon colors during GIF decoding.
sample=Image.new("RGB",(1536,1280),BACKGROUND)
sample.paste(seed,(0,0))
sd=ImageDraw.Draw(sample)
all_colors=COLORS+HOT+[RED,RED_HOT]
for index,c in enumerate(all_colors):
    for level in range(8):
        x=index*100; y=1024+level*30
        sd.rectangle((x,y,x+90,y+25),fill=scaled(c,0.3+0.1*level))
palette=sample.quantize(colors=256,method=Image.Quantize.MEDIANCUT)
def save_gif(images,path):
    indexed=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in images]
    indexed[0].save(path,save_all=True,append_images=indexed[1:],
                   duration=DURATIONS,loop=0,disposal=2,optimize=False)
    with Image.open(path) as check:
        assert check.n_frames==N,(path.name,check.n_frames)
        total=0
        for i in range(check.n_frames):
            check.seek(i); total+=check.info["duration"]
        assert total==2000,(path.name,total)

save_gif(frames,HERE/"traits-positive-negative-animated.gif")
save_gif([f.crop((0,104,1536,500)) for f in frames],HERE/"beneficial-traits-animated.gif")
save_gif([f.crop((0,505,1536,930)) for f in frames],HERE/"trade-off-traits-animated.gif")
frames[4].save(HERE/"animation-poster.png")
manifest={
 "status":"Approved static design; animated version pending Parames review",
 "source":str(SOURCE.relative_to(ROOT)).replace("\\","/"),
 "source_sha256":hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
 "method":"Existing image_gen card design plus fixed-content native-pixel light-overlay animation packaging",
 "outputs":["traits-positive-negative-animated.gif","beneficial-traits-animated.gif","trade-off-traits-animated.gif"],
 "frames":N,"durations_ms":DURATIONS,"loop_ms":2000,
 "beneficial_motion":"Clean tier-colored stepped pulses, travelling rim highlights and bounded outside motes",
 "trade_off_motion":"Irregular low-amplitude broken crimson edge flicker, soot gaps and downward embers; no body/text flicker",
 "verification":"All 12 card interiors remain byte-identical across 16 frames; every card animates; all three GIFs have 16 frames and exactly 2000ms duration; shared palette.",
 "rarity_model":"These are proposed visual tiers only. Individual trait rarity is not present in current gameplay; no tiers were assigned and no trait effects changed.",
 "qa":"Animation concept preview, not production sprite sheets. Native geometry, palette mapping, clipping and actual in-game UI need later validation.",
 "scope":"No game code, production art/atlas, balance, tickets, commits or PRs changed."
}
(HERE/"preview-manifest.json").write_text(json.dumps(manifest,indent=2),encoding="utf-8")
print(json.dumps({"animated_cards":12,"GIFs":3,"frames":N,"loop_ms":2000,"content":"fixed","scope":"preview only"}))
