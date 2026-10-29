import json,sys,time,base64,io
from PIL import Image,ImageDraw
from gen import api,b64
w=Image.open("out/k_B2_s2_0.png").convert("RGBA")
mode,seed=sys.argv[1],int(sys.argv[2])
b=Image.new("RGBA",(432,96),(40,36,32,255)); b.paste(w.crop((0,0,200,96)),(0,0))
m=Image.new("RGB",(432,96),(0,0,0)); d=ImageDraw.Draw(m)
if mode=="extend":
    b.paste(w.crop((144,0,288,96)),(288,0)); d.rectangle([186,0,299,95],fill=(255,255,255))
    desc="the same clean bar counter continues seamlessly to the left, making one very long polished wood and steel bar counter with more tall stools, a beer tap, more bottle shelves and pendant lamps on the same back wall. Clean and upgraded. The bottom strip of the image is open empty clean floor with nothing on it. Same deep floor, same camera angle, 16-bit dark post-apocalyptic pixel art"
else:
    d.rectangle([186,0,431,95],fill=(255,255,255))
    desc="a big upgraded clean bar lounge: one very long polished wood and steel bar counter with a brass foot rail and tall padded stools, a beer tap, a lit bottle wall with shelves of bottles and glasses, a chalkboard menu, warm pendant lamps, a small round high table at the far right. Everything clean and repaired. The bottom strip of the image is open empty clean floor with nothing on it. Same back wall continuing from the kitchen, same deep floor, same camera angle, 16-bit dark post-apocalyptic pixel art"
b.save(f"out/b3_{mode}_base.png")
body={"description":desc,"inpainting_image":{"image":b64(b),"size":{"width":432,"height":96}},"mask_image":{"image":b64(m),"size":{"width":432,"height":96}},"seed":seed}
jid=api("POST","/inpaint-v3",body)["background_job_id"]
while True:
    time.sleep(8); r=api("GET",f"/background-jobs/{jid}")
    if r.get("status") in("completed","failed"): break
lr=r.get("last_response") or {}
ims=lr.get("images") or ([lr["image"]] if "image" in lr else [])
for i,x in enumerate(ims):
    Image.open(io.BytesIO(base64.b64decode(x["base64"].split(",")[-1]))).save(f"out/k_B3{mode}_s{seed}_{i}.png")
print(mode,seed,len(ims))
