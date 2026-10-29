# Used: first version of this script (mask (133,0,155,87)+(118,0,170,22), seed 1, plain "continuous wall" prompt), then wall_blend below.
# B merged: replace the steel rib/strut in the middle with continuous back wall (inpaint only the gap between planters)
import sys,time,base64,io
sys.path.insert(0,"/mnt/project-files/designs/room-redesign-preview")
from gen_deep import api,b64
from PIL import Image,ImageDraw
M=[(133,0,155,87),(108,0,180,24)]
def mask():
    m=Image.new("RGB",(288,96),(0,0,0)); d=ImageDraw.Draw(m)
    for r in M: d.rectangle(r,fill=(255,255,255))
    return m
seed=int(sys.argv[1]); src=Image.open("out/grB_M2_s3.png").convert("RGBA")
desc=("the same dark riveted steel back wall continues flat and seamless across this area, one single continuous room, no pillar, no strut, no dividing wall, no doorway, no dark panel, lit softly by the warm bulbs on both sides, "
      "one horizontal pipe at mid height and a cable bundle running across, the ceiling is one continuous curved steel roof with evenly spaced thin ribs, same dark floor plates at the bottom. 16-bit dark post-apocalyptic pixel art, crisp outlines.")
jid=api("POST","/inpaint-v3",{"description":desc,"inpainting_image":{"image":b64(src),"size":{"width":288,"height":96}},"mask_image":{"image":b64(mask()),"size":{"width":288,"height":96}},"seed":seed})["background_job_id"]
while True:
    time.sleep(6); r=api("GET",f"/background-jobs/{jid}")
    if r.get("status") in("completed","failed"): break
lr=r.get("last_response") or {}; ims=lr.get("images") or ([lr["image"]] if "image" in lr else [])
for i,x in enumerate(ims):
    im=Image.open(io.BytesIO(base64.b64decode(x["base64"].split(",")[-1]))).convert("RGBA")
    out=src.copy(); out.paste(im,(0,0),mask().convert("L")); out.save(f"out/grB_M2_wall2_s{seed}.png")
print(seed,len(ims))

# # Even out the inpainted middle wall: per row, scale brightness so it ramps between the wall columns just outside the patch
# from PIL import Image
# im=Image.open("out/grB_M2_wall_s1.png").convert("RGBA"); px=im.load()
# X0,X1=133,155
# def lum(p): return 0.3*p[0]+0.59*p[1]+0.11*p[2]
# for y in range(0,88):
#     L=sum(lum(px[x,y]) for x in range(X0-4,X0))/4; R=sum(lum(px[x,y]) for x in range(X1+1,X1+5))/4
#     row=[lum(px[x,y]) for x in range(X0,X1+1)]; m=max(1,sum(row)/len(row))
#     for i,x in enumerate(range(X0,X1+1)):
#         t=i/(X1-X0); target=L*(1-t)+R*t; k=max(0.8,min(1.6,target/m))
#         p=px[x,y]; px[x,y]=tuple(min(255,int(p[c]*k)) for c in range(3))+(255,)
# im.save("out/grB_M2_wall_fix.png")
