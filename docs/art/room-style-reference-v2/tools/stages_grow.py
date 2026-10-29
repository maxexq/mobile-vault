# Growth stages: inpaint-v3 only the plant areas of the L1 art, so pots/walls stay pixel-identical.
# stage 3 (mature) = the L1 art itself; s1 = just planted, s2 = half grown.
import sys,os,time,base64,io
sys.path.insert(0,"/mnt/project-files/designs/room-redesign-preview")
from gen_deep import api,b64
from PIL import Image,ImageDraw
MASK={"A_L2":{"add":[(16,37,104,48)],"cut":[]},
      "A_L3":{"add":[(16,35,104,48)],"cut":[]},
      "B_L2":{"add":[(56,22,126,62),(14,58,50,66)],"cut":[(78,12,88,32)]},
      "B_L3":{"add":[(56,24,128,64),(14,58,50,66)],"cut":[(72,14,96,34)]},
      "A_M2":{"add":[(8,30,104,47),(184,21,232,32),(184,41,232,52),(184,61,232,73)],"cut":[]},
      "B_M2":{"add":[(10,58,48,66),(54,28,96,66),(100,36,132,68),(156,26,234,70)],"cut":[(78,10,86,34),(200,10,210,34)]},
      "A_M3":{"add":[(8,30,104,47),(184,21,212,32),(184,42,212,52),(184,63,212,75),(225,21,249,32),(251,21,276,32),(225,42,249,52),(251,42,276,52),(225,63,249,75),(251,63,276,75),(296,53,348,62)],"cut":[]},
      "B_M3":{"add":[(10,58,48,66),(54,28,96,66),(100,36,132,68),(152,28,193,70),(194,30,237,69),(240,46,276,68),(279,14,366,70)],"cut":[(78,10,86,34),(205,10,218,32),(263,10,276,32),(335,10,348,32)]},
      "A":{"add":[(14,33,104,45)],"cut":[]},
      "B":{"add":[(54,22,128,62),(14,57,48,65)],"cut":[(76,10,88,34)]}}
CROP={"A_L2":"leafy green vegetables growing in matching planter tubs on a wooden workbench",
      "A_L3":"leafy green vegetables growing in neat matching planter pots on a clean metal grow table",
      "B_L2":"tomato plants tied to wooden stakes and vegetables growing in repaired planter boxes and painted tyres",
      "B_L3":"tomato and pepper plants on a wooden trellis growing in neat raised wooden beds and a tyre planter",
      "A_M2":"leafy green vegetables (lettuce, herbs) growing in neat planter pots on a table and in trays on a lit metal shelving rack",
      "B_M2":"tomato, pepper and herb plants growing in raised wooden planter beds and on a trellis",
      "A_M3":"leafy green vegetables (lettuce, herbs) growing in neat planter pots on a table, in trays on two lit metal shelving racks and in seedling trays",
      "B_M3":"tomato, pepper, bean and lettuce plants growing in a row of raised wooden planter beds and on wooden trellises",
      "A":"leafy green vegetables (lettuce, herbs) growing in cut plastic barrels and pots on a wooden table",
      "B":"tomato plants and vegetables growing in pallet planter boxes and stacked tyres"}
STAGE={"s1":"JUST PLANTED: the pots and planters show dark moist bare soil with only tiny two-leaf green seedlings sprouting, very small, low to the soil; nothing tall, no fruit, mostly soil visible.",
       "s2":"HALF GROWN: small young green plants only about half the height of mature plants, a few small leaves each, sparse, the rims of the pots and the soil between plants are clearly visible, no fruit or flowers yet."}
def SIZE(k): return (288,96) if k.endswith("_M2") else (432,96) if k.endswith("_M3") else (144,96)
def mask(k):
    m=Image.new("RGB",SIZE(k),(0,0,0)); d=ImageDraw.Draw(m)
    for r in MASK[k]["add"]: d.rectangle(r,fill=(255,255,255))
    for r in MASK[k]["cut"]: d.rectangle(r,fill=(0,0,0))
    return m
def run(k,st,seed):
    src=Image.open(f"out/gr{k}_s3.png" if "_" in k else f"out/gr{k}_L1.png").convert("RGBA"); W,H=SIZE(k)
    desc=(f"{CROP[k]}, {STAGE[st]} Same planters, same room, same lighting, 16-bit dark post-apocalyptic pixel art, crisp dark outlines.")
    body={"description":desc,"inpainting_image":{"image":b64(src),"size":{"width":W,"height":H}},"mask_image":{"image":b64(mask(k)),"size":{"width":W,"height":H}},"seed":seed}
    jid=api("POST","/inpaint-v3",body)["background_job_id"]
    while True:
        time.sleep(6); r=api("GET",f"/background-jobs/{jid}")
        if r.get("status") in("completed","failed"): break
    lr=r.get("last_response") or {}
    ims=lr.get("images") or ([lr["image"]] if "image" in lr else [])
    for i,x in enumerate(ims):
        im=Image.open(io.BytesIO(base64.b64decode(x["base64"].split(",")[-1]))).convert("RGBA")
        # paste back only the masked area so everything else stays identical
        out=src.copy(); out.paste(im,(0,0),mask(k).convert("L")); out.save(f"out/gr{k}_{st}_seed{seed}_{i}.png")
    print(k,st,seed,len(ims),r.get("status"))
if __name__=="__main__": run(sys.argv[1],sys.argv[2],int(sys.argv[3]))
