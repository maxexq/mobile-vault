# Merged 3-slot infirmary (level 3): keep left 200 px of the chosen merged-2 (ward + supply shelf), inpaint-v3 x186-431 on a 432x96 canvas
import sys,time,base64,io,os
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from PIL import Image,ImageDraw
from gen import api,b64
src,seed=sys.argv[1],int(sys.argv[2])
w=Image.open(src).convert("RGBA")
b=Image.new("RGBA",(432,96),(40,44,52,255)); b.paste(w.crop((0,0,200,96)),(0,0))
m=Image.new("RGB",(432,96),(0,0,0)); ImageDraw.Draw(m).rectangle([186,0,431,95],fill=(255,255,255))
desc=("a big upgraded clean infirmary continuing from the ward and supply shelf: a larger surgery area with a steel operating table under a big round surgery lamp, an anaesthesia machine with a small monitor, "
      "a clean instrument trolley, a steel scrub sink with tap on the wall, then at the far right a recovery corner with a second clean hospital bed half behind a white privacy curtain on a ceiling rail and a folded stretcher on the wall. "
      "Same dark blue-grey riveted steel wall panels continuing from the left with no seam, cables and pipes along the ceiling. Everything clean, sterile and repaired. "
      "The bottom strip of the image is open empty clean floor with nothing on it. Same deep floor, same camera angle, 16-bit dark post-apocalyptic pixel art, crisp outlines, same pixel scale.")
b.save("out/inf_m3_base.png")
jid=api("POST","/inpaint-v3",{"description":desc,"inpainting_image":{"image":b64(b),"size":{"width":432,"height":96}},"mask_image":{"image":b64(m),"size":{"width":432,"height":96}},"seed":seed})["background_job_id"]
while True:
    time.sleep(8); r=api("GET",f"/background-jobs/{jid}")
    if r.get("status") in("completed","failed"): break
lr=r.get("last_response") or {}; ims=lr.get("images") or ([lr["image"]] if "image" in lr else [])
for i,x in enumerate(ims): Image.open(io.BytesIO(base64.b64decode(x["base64"].split(",")[-1]))).save(f"out/inf_M3_s{seed}_{i}.png")
print("m3",seed,len(ims))
