# Merged living rooms (level 3 only). m2: L3 + mirrored L3 -> edit-images-v2 (288x96). m3: inpaint-v3 on 432x96 from the chosen m2.
import sys,time,base64,io
from PIL import Image,ImageDraw

from edit import edit
from gen import api,b64
L3="out/lv_L3_s1_0.png"
STY=" Same deep floor, same camera angle, 16-bit dark post-apocalyptic pixel art, crisp outlines, same pixel scale."
def m2(seed):
    a=Image.open(L3).convert("RGBA"); b=Image.new("RGBA",(288,96)); b.paste(a,(0,0)); b.paste(a.transpose(Image.FLIP_LEFT_RIGHT),(144,0)); b.save("out/m2_base.png")
    desc=("One single wide continuous upgraded clean living lounge (two rooms knocked through, no dividing wall). Keep the left half as it is: sofa, coffee table, TV cabinet. "
          "The right half becomes a clean game and music corner: a pool table or card table with chairs, a record player on a cabinet, a dartboard and framed posters on the wall, a second bookshelf, a potted plant, warm pendant lamps. "
          "The bottom strip of the image is open empty clean floor across the whole width with nothing on it, for people to walk.")
    edit("out/m2_base.png",f"out/m2_s{seed}.png",desc,seed)
def m3(src,seed):
    w=Image.open(src).convert("RGBA")
    b=Image.new("RGBA",(432,96),(40,36,32,255)); b.paste(w.crop((0,0,200,96)),(0,0))
    m=Image.new("RGB",(432,96),(0,0,0)); ImageDraw.Draw(m).rectangle([186,0,431,95],fill=(255,255,255))
    desc=("a big upgraded clean living lounge continuing from the sofa area: the game corner from before but bigger, a pool table with hanging lamp above it, a record player and speakers on a cabinet, "
          "a dartboard, a long wall shelf of books and board games, a cozy reading armchair with floor lamp at the far right, potted plants, framed posters, clean painted metal wall. "
          "Everything clean and repaired. The bottom strip of the image is open empty clean floor with nothing on it."+STY)
    jid=api("POST","/inpaint-v3",{"description":desc,"inpainting_image":{"image":b64(b),"size":{"width":432,"height":96}},"mask_image":{"image":b64(m),"size":{"width":432,"height":96}},"seed":seed})["background_job_id"]
    while True:
        time.sleep(8); r=api("GET",f"/background-jobs/{jid}")
        if r.get("status") in("completed","failed"): break
    lr=r.get("last_response") or {}; ims=lr.get("images") or ([lr["image"]] if "image" in lr else [])
    for i,x in enumerate(ims): Image.open(io.BytesIO(base64.b64decode(x["base64"].split(",")[-1]))).save(f"out/m3_s{seed}_{i}.png")
    print("m3",seed,len(ims))
if __name__=="__main__":
    if sys.argv[1]=="m2": m2(int(sys.argv[2]))
    else: m3(sys.argv[2],int(sys.argv[3]))
