# Infirmary room L1 (single cell 144x96, deep floor) via generate-image-v2, style ref = approved kitchen L1
import json,sys,time,base64,io,os
from PIL import Image
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__))+"/..")
from gen_deep import api,b64
HERE=os.path.dirname(os.path.abspath(__file__))
STYLE=("16-bit pixel art, dark gritty post-apocalyptic, muted desaturated colours, crisp dark outlines, front view of a room cross-section "
 "with the camera slightly above eye level, the floor is a visible deep plane of worn metal floor plates receding to the back wall and fills the bottom quarter of the image. "
 "Level 1 room: crude, makeshift, scavenged junk, dim, dirty. Furniture stays against the back wall; the front floor strip across the whole width is empty for people to walk.")
ROOMS={
 "A":"interior of a crude makeshift infirmary sick bay inside an armored survival bus. Back wall of rusty riveted steel plates with a hand-painted red cross, a stained metal hospital cot with a thin mattress and blanket, a bent IV drip stand with a saline bag, a dented wall medicine cabinet with jars and bandage rolls, a small oxygen tank, a cold flickering caged lamp.",
 "B":"interior of a crude makeshift field surgery and triage room inside an armored survival bus. Back wall of patched steel plates, a scrap metal operating table made from a door on trestles under a hanging adjustable surgery lamp, a rolling cart with surgical tools and a pot of boiling water, shelves of ammo-crate medical supplies with red crosses, a folded stretcher leaning on the wall, a blood-stained curtain on a rail.",
}
if __name__=="__main__":
    k=sys.argv[1]; seed=int(sys.argv[2]) if len(sys.argv)>2 else 7
    ref=Image.open(HERE+"/../kitchen/k_L1_s1_0.png").convert("RGBA")
    body={"description":ROOMS[k]+" "+STYLE,"image_size":{"width":144,"height":96},"seed":seed,"no_background":False,
          "style_image":{"image":b64(ref),"size":{"width":144,"height":96},"usage_description":"approved level 1 kitchen of the same game: match its pixel scale, camera angle, deep floor, outline, shading and dark palette"},
          "style_options":{"color_palette":True,"outline":True,"detail":True,"shading":True}}
    j=api("POST","/generate-image-v2",body); jid=j.get("background_job_id"); print("job",jid,flush=True)
    while True:
        time.sleep(8); r=api("GET",f"/background-jobs/{jid}"); st=r.get("status")
        if st in("completed","failed"): break
    print(st)
    lr=r.get("last_response") or {}
    ims=lr.get("images") or ([lr["image"]] if "image" in lr else [])
    if not ims: print(json.dumps(r)[:600])
    for i,im in enumerate(ims):
        Image.open(io.BytesIO(base64.b64decode(im["base64"].split(",")[-1]))).save(f"{HERE}/out/inf_{k}_{seed}_{i}.png")
    print(len(ims),"images")
