"""Animate the selected rarity frame artwork for review, without changing game files.
The source frames/items remain fixed; only code-rendered emissive overlays animate.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import hashlib
import json
import math

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
SOURCE = HERE.parent / "equipment-slots-v2-neon-aura/rarity-neon-aura-study.png"
source = Image.open(SOURCE).convert("RGB")
assert source.size == (1536, 1024)
N = 16
DURATIONS = [120, 130] * 8
NAMES = ["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY", "MYTHIC"]
COLORS = [(182,181,169), (65,231,77), (38,162,255),
          (183,53,248), (255,169,33), (249,47,65)]
HOT = [(231,229,212), (189,255,169), (179,239,255),
       (243,181,255), (255,239,159), (255,179,174)]
# Shared crop geometry from the top BASE row, with fixed 32px normalization.
BOXES = [(x,190,x+192,382) for x in (188,412,636,860,1084,1308)]
tiles = [source.crop(b).resize((32,32), Image.Resampling.NEAREST) for b in BOXES]
FONT = ROOT / "assets/fonts/Silkscreen-Regular.ttf"
font = ImageFont.truetype(str(FONT), 8)
title_font = ImageFont.truetype(str(FONT), 8)

def tint(color, amount):
    return tuple(round(c * amount) for c in color)

def mix(a, b, amount):
    return tuple(round(x + (y-x)*amount) for x,y in zip(a,b))

def path(vertices):
    pts = []
    for (x0,y0),(x1,y1) in zip(vertices, vertices[1:]+vertices[:1]):
        steps = max(abs(x1-x0), abs(y1-y0))
        for i in range(steps):
            p = (round(x0+(x1-x0)*i/steps), round(y0+(y1-y0)*i/steps))
            if not pts or pts[-1] != p:
                pts.append(p)
    return pts

rim = path([(7,4),(24,4),(27,7),(27,24),(24,27),(7,27),(4,24),(4,7)])
outer = path([(-1,-3),(32,-3),(35,0),(35,31),(32,34),(-1,34),(-4,31),(-4,0)])
corners = [(4,4),(27,4),(27,27),(4,27)]

def draw_text(draw, xy, text, fill, use_font=font, center=False):
    x,y = xy
    if center:
        box = draw.textbbox((0,0), text, font=use_font)
        x -= (box[2]-box[0])//2
    draw.fontmode = "1"
    draw.text((x,y), text, font=use_font, fill=fill)

def cell(rank, index, aura):
    frame = Image.new("RGB", (56,56), (15,14,18))
    px,py = 12,12
    base = tiles[rank]
    color, hot = COLORS[rank], HOT[rank]
    phase = (index + rank*2) % N
    # Five stepped light levels; no sprite scaling or camera movement.
    pulse = (1-math.cos(math.tau*phase/N))/2
    pulse = round(pulse*4)/4
    if rank == 5:
        # Two short heartbeat peaks for Mythic; finite, bounded light levels.
        pulse = [0.25,0.5,1,0.5,0.25,0.5,0.75,0.5,
                 0.25,0,0,0,0,0,0,0.25][phase]
    d = ImageDraw.Draw(frame)
    if aura:
        # Outside-only stepped aura; no blur and no changing item tint.
        reach = [1,2,3,3,4,5][rank]
        for ring in range(reach, 0, -1):
            glow = tint(color, (0.08+0.025*rank+0.09*pulse)*(reach-ring+1)/reach)
            v = [(px+3-ring,py+1-ring),(px+28+ring,py+1-ring),
                 (px+30+ring,py+3-ring),(px+30+ring,py+28+ring),
                 (px+28+ring,py+30+ring),(px+3-ring,py+30+ring),
                 (px+1-ring,py+28+ring),(px+1-ring,py+3-ring)]
            outline = path(v)
            for i,(x,y) in enumerate(outline):
                if (i+phase+ring)%3 != 0:
                    d.point((x,y), fill=glow)
    frame.paste(base, (px,py))
    d = ImageDraw.Draw(frame)
    strength = (0.42+0.12*pulse) if rank == 0 else (0.56+0.38*pulse)
    rim_col = tint(color, strength)
    for x,y in rim:
        d.point((px+x,py+y), fill=rim_col)
    # A highlight travels on the integer-pixel rim; higher ranks get a second.
    head = (phase*len(rim)//N) % len(rim)
    tails = 3 if rank == 0 else 4+rank
    for k in range(tails):
        x,y = rim[(head-k)%len(rim)]
        c = mix(rim_col, hot, (tails-k)/tails * (0.45 if rank == 0 else 0.9))
        d.point((px+x,py+y), fill=c)
    if rank >= 3:
        for k in range(4):
            x,y = rim[(head+len(rim)//2-k)%len(rim)]
            d.point((px+x,py+y), fill=mix(rim_col,hot,(4-k)/5))
    if rank >= 3:
        for k,(x,y) in enumerate(corners):
            c = mix(tint(color,0.4),hot,0.25+0.55*((phase+k*4)%N)/N)
            d.point((px+x,py+y), fill=c)
    if aura and rank > 0:
        # Persistent particle slots, sampled on closed integer paths.
        count = [0,1,2,3,4,6][rank]
        for particle in range(count):
            if rank >= 4:
                # Embers rise and reset outside the frame, never over the item.
                age = (phase + particle*5) % N
                x = px + (-3 if particle%2 == 0 else 34) + ((age//4+particle)%2)
                y = py + 30 - age*2
                size = 2 if rank == 5 and particle%3 == 0 else 1
                c = mix(tint(color,0.35),hot,1-age/N)
            else:
                x,y = outer[(phase*len(outer)//N + particle*len(outer)//count)%len(outer)]
                x,y = px+x,py+y
                size = 1
                c = mix(tint(color,0.5),hot,0.35+0.45*((phase+particle)%4)/3)
            d.rectangle((x,y,x+size-1,y+size-1),fill=c)
        if rank == 5:
            # Two short broken red arcs, outside the slot.
            for shift in (0, len(outer)//2):
                for k in range(7):
                    x,y = outer[(head+shift+k)%len(outer)]
                    if k%3 != 2:
                        d.point((px+x,py+y),fill=mix(color,hot,(7-k)/9))
    # Exact fixed center: never recolor, obscure or animate the item.
    frame.paste(base.crop((8,8,24,24)), (px+8,py+8))
    return frame

frames = []
individual = [[] for _ in NAMES]
for index in range(N):
    board = Image.new("RGB", (384,160), (15,14,18))
    d = ImageDraw.Draw(board)
    draw_text(d, (192,3), "RARITY ANIMATIONS", (178,168,138), title_font, True)
    for rank,name in enumerate(NAMES):
        draw_text(d, (48+rank*56+28,19), name, mix(COLORS[rank],(178,168,138),0.25), center=True)
    draw_text(d,(4,56),"NEON",(178,168,138))
    draw_text(d,(4,117),"AURA",(178,168,138))
    d.line((0,92,383,92),fill=(62,28,16))
    for rank in range(6):
        neon = cell(rank,index,False)
        aura = cell(rank,index,True)
        board.paste(neon,(48+rank*56,32))
        board.paste(aura,(48+rank*56,96))
        small = Image.new("RGB",(56,66),(15,14,18))
        small.paste(aura,(0,10))
        sd=ImageDraw.Draw(small)
        draw_text(sd,(28,0),NAMES[rank],mix(COLORS[rank],(178,168,138),0.25),center=True)
        individual[rank].append(small)
    frames.append(board)

# Check the item core stays exactly fixed in every cell and in every frame.
for rank in range(6):
    expected=tiles[rank].crop((8,8,24,24)).tobytes()
    for index in range(N):
        for aura in (False,True):
            actual=cell(rank,index,aura).crop((20,20,36,36)).tobytes()
            assert actual==expected, "Item core drift"
# Learn one shared palette across the complete loop, so decoded GIFs cannot flicker palettes.
samples=Image.new("RGB",(384,160*N))
for i,f in enumerate(frames):
    samples.paste(f,(0,i*160))
palette=samples.quantize(colors=256,method=Image.Quantize.MEDIANCUT)
def save_gif(images,filename,scale):
    expanded=[f.resize((f.width*scale,f.height*scale),Image.Resampling.NEAREST) for f in images]
    indexed=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in expanded]
    indexed[0].save(HERE/filename,save_all=True,append_images=indexed[1:],
                    duration=DURATIONS,loop=0,disposal=2,optimize=False)
    with Image.open(HERE/filename) as check:
        assert check.n_frames==N, (filename,check.n_frames)
        total=0
        for i in range(check.n_frames):
            check.seek(i)
            total+=check.info["duration"]
        assert total==2000, (filename,total)
save_gif(frames,"all-rarities-neon-aura.gif",4)
for rank,name in enumerate(NAMES):
    save_gif(individual[rank],name.lower()+"-aura.gif",6)
frames[4].resize((1536,640),Image.Resampling.NEAREST).save(HERE/"animation-poster.png")
strip=Image.new("RGB",(56*N,56*6),(15,14,18))
for rank in range(6):
    for index in range(N):
        strip.paste(cell(rank,index,True),(index*56,rank*56))
strip.save(HERE/"aura-contact-sheet-native.png")
manifest={
    "status":"Animated examples for Parames review; no ticket posted",
    "source":str(SOURCE.relative_to(ROOT)).replace("\\","/"),
    "source_sha256":hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    "method":"Fixed crops of image_gen artwork; native-grid emissive overlays and GIF packaging",
    "main_output":"all-rarities-neon-aura.gif",
    "individual_outputs":[name.lower()+"-aura.gif" for name in NAMES],
    "frames":N,"durations_ms":DURATIONS,"loop_ms":2000,
    "slot_preview_native":[32,32],"effect_cell":[56,56],
    "motion":{
        "common":"Quiet silver pulse and one short travelling rim glint",
        "uncommon":"Green pulse and one small outside mote",
        "rare":"Blue/cyan travelling rim highlight and two outside motes",
        "epic":"Violet opposing rim highlights and three outside motes",
        "legendary":"Amber rim shimmer, corner light and four rising embers",
        "mythic":"Crimson double-beat pulse, two broken arcs and six bounded sparks"
    },
    "verification":"Seven GIFs have 16 frames and 2000ms loops. All item-core pixels remain identical. Shared palette, bounded effects, integer movement and integer nearest display scale.",
    "qa":"Review-only animation from the selected generated reference. Exact production 28/32/36px appearance, master-palette mapping, clipping and engine integration are not approved or built.",
    "scope":"No game code, UI scenes, production art/atlas, tickets, commits or PRs changed."
}
(HERE/"preview-manifest.json").write_text(json.dumps(manifest,indent=2),encoding="utf-8")
print(json.dumps({"outputs":7,"frames":N,"loop_ms":2000,"item_cores":"fixed","scope":"preview only"}))
