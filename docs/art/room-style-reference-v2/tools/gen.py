import json,sys,time,base64,io,urllib.request
from PIL import Image
G="/mnt/project-files/designs/crew-anim-preview/"
def frames(char,clip):
    im=Image.open(f"{G}{char}/{clip}.gif"); out=[]
    for i in range(im.n_frames):
        im.seek(i); f=im.convert("RGBA").resize((64,64),Image.NEAREST)
        px=f.load()
        for y in range(64):
            for x in range(64):
                if px[x,y][:3]==(34,32,30): px[x,y]=(0,0,0,0)
        out.append(f)
    return out
def b64(img):
    b=io.BytesIO(); img.save(b,"PNG"); return {"type":"base64","base64":"data:image/png;base64,"+base64.b64encode(b.getvalue()).decode()}
def api(m,p,body=None):
    r=urllib.request.Request("https://api.pixellab.ai/v2"+p,method=m,data=json.dumps(body).encode() if body else None,
        headers={"Content-Type":"application/json","Authorization":"Bearer x"})
    return json.load(urllib.request.urlopen(r,timeout=120))
STYLE="16-bit pixel art, dark gritty post-apocalyptic, muted desaturated colours, crisp dark outlines, flat side view (2D side-scroller cross-section), no perspective"
ROOMS={
 "quarters":"interior of a cramped crew sleeping quarters inside an armored survival bus, side view cross-section. Back wall of riveted rusty steel plates, metal bunk bed against the left wall, wall lockers on the right, small boarded window with faint light, hanging bulb lamp, scrap blankets. Flat metal floor strip along the bottom. Empty open floor space in the middle for people to walk.",
 "kitchen":"interior of a scavenged mess kitchen inside an armored survival bus, side view cross-section. Back wall of grimy tiles and steel plates, camping stove with steaming pot on the left counter, shelves of cans and jars, old fridge on the right, hanging pans, warm lamp glow. Flat floor strip along the bottom. Empty open floor space in the middle for people to walk.",
 "medical":"interior of a makeshift medical bay inside an armored survival bus, side view cross-section. Back wall of patched steel plates, a stained hospital cot on the left, IV stand, medicine cabinet with red cross on the wall, oxygen tank, cold flickering lamp. Flat floor strip along the bottom. Empty open floor space in the middle for people to walk.",
}
if __name__=="__main__":
    room=sys.argv[1]; seed=int(sys.argv[2]) if len(sys.argv)>2 else 7
    style=frames("medic","idle")[0]
    body={"description":ROOMS[room]+" "+STYLE,"image_size":{"width":144,"height":96},"seed":seed,"no_background":False,
          "style_image":{"image":b64(style),"size":{"width":64,"height":64},"usage_description":"match pixel size, outline and shading of this character; the room must use the same pixel scale"},
          "style_options":{"color_palette":False,"outline":True,"detail":True,"shading":True}}
    j=api("POST","/generate-image-v2",body); jid=j.get("background_job_id"); print("job",jid,flush=True)
    while True:
        time.sleep(8); r=api("GET",f"/background-jobs/{jid}"); st=r.get("status"); print(st,flush=True)
        if st in("completed","failed"): break
    json.dump(r,open(f"out/{room}_{seed}.json","w"))
    lr=r.get("last_response") or {}
    ims=lr.get("images") or ([lr["image"]] if "image" in lr else [])
    for i,im in enumerate(ims):
        s=im["base64"].split(",")[-1]
        Image.open(io.BytesIO(base64.b64decode(s))).save(f"out/{room}_{seed}_{i}.png")
    print(len(ims),"images")
