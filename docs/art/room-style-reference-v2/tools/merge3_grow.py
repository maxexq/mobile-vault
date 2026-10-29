# Merged 3-slot grow rooms (level 3 only): inpaint-v3 on 432x96 keeping the left 200 px of the chosen merged-2 room.
import sys,time,base64,io
from PIL import Image,ImageDraw
sys.path.insert(0,"/mnt/project-files/designs/room-redesign-preview")
from gen_deep import api,b64
STY=(" The same continuous dark riveted steel back wall across the whole width, no pillar, no dividing wall, no door. Same deep floor, same camera angle, "
     "16-bit dark post-apocalyptic pixel art, crisp outlines, same pixel scale.")
D={
"A":("a big upgraded clean hydroponic grow area continuing from the left: more tall clean metal shelf racks with three tiers of planter trays of lettuce and herbs, "
     "each tier lit by purple-pink LED grow light strips, a seedling station table with small sprout trays, a clean water tank with a pump and tidy tubes, a sealed seed cabinet. "
     "Everything clean and repaired. The bottom strip of the image is open empty clean floor with nothing on it."),
"B":("a big upgraded clean vegetable garden continuing from the left, lit evenly like the left side: one single row of neat raised wooden planter beds standing against the back wall with tomatoes, peppers and leafy vegetables, a tall trellis of climbing beans, "
     "a harvest corner with a crate of picked vegetables and a compost bin, a tidy tool rack on the wall, warm hanging bulbs. "
     "Everything clean and repaired. The bottom strip of the image is open empty clean floor with nothing on it."),
}
k,seed=sys.argv[1],int(sys.argv[2])
w=Image.open(f"out/gr{k}_M2_s3.png").convert("RGBA")
b=Image.new("RGBA",(432,96),(40,36,32,255)); b.paste(w.crop((0,0,200,96)),(0,0))
m=Image.new("RGB",(432,96),(0,0,0)); ImageDraw.Draw(m).rectangle([186,0,431,95],fill=(255,255,255))
jid=api("POST","/inpaint-v3",{"description":D[k]+STY,"inpainting_image":{"image":b64(b),"size":{"width":432,"height":96}},"mask_image":{"image":b64(m),"size":{"width":432,"height":96}},"seed":seed})["background_job_id"]
while True:
    time.sleep(8); r=api("GET",f"/background-jobs/{jid}")
    if r.get("status") in("completed","failed"): break
lr=r.get("last_response") or {}; ims=lr.get("images") or ([lr["image"]] if "image" in lr else [])
for i,x in enumerate(ims): Image.open(io.BytesIO(base64.b64decode(x["base64"].split(",")[-1]))).save(f"out/gr{k}_M3_seed{seed}_{i}.png")
print("m3",k,seed,len(ims),r.get("status"))
