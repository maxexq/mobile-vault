import json,sys,time,base64,io
from PIL import Image
from gen import api,b64
STYLE=" Keep the same camera angle, deep visible floor, 16-bit pixel art style, dark post-apocalyptic mood, crisp outlines, same pixel scale."
def edit(src,out,desc,seed,size=None):
    im=Image.open(src).convert("RGBA"); W,H=size or im.size
    body={"method":"edit_with_text","edit_images":[{"image":b64(im),"width":im.width,"height":im.height}],
          "image_size":{"width":W,"height":H},"description":desc+STYLE,"seed":seed,"no_background":False}
    jid=api("POST","/edit-images-v2",body)["background_job_id"]
    while True:
        time.sleep(8); r=api("GET",f"/background-jobs/{jid}")
        if r.get("status") in("completed","failed"): break
    lr=r.get("last_response") or {}
    ims=lr.get("images") or ([lr["image"]] if "image" in lr else [])
    if not ims: print("FAIL",out,json.dumps(r)[:400]); return
    for i,x in enumerate(ims):
        Image.open(io.BytesIO(base64.b64decode(x["base64"].split(",")[-1]))).save(out.replace(".png",f"_{i}.png"))
    print("ok",out,len(ims))
if __name__=="__main__":
    a=sys.argv; edit(a[1],a[2],a[3],int(a[4]))
