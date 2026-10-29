# Tap hotspots for v2 room art: check the <room>/hotspots.json files and draw overlay previews.
#   python hotspots.py check            -> exit 1 on any problem
#   python hotspots.py overlay OUT_DIR  -> <room>_<level>_hotspots.png (3x, labelled boxes)
import json,sys,os,colorsys
from PIL import Image,ImageDraw
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KINDS={"station","storage","device","screen","seat","game","light","info","decor"}
ACTIONS={"open_cook_menu","open_bar_menu","open_storage","use_device","watch_tv","play_game","play_music",
         "play_pool","play_darts","read_book","water_plant","sit","toggle_light","show_info","inspect"}
MIN=6  # smallest side in native px; the game pads tap areas, but the art box must be findable
def rooms():
    for d in sorted(os.listdir(ROOT)):
        p=os.path.join(ROOT,d,"hotspots.json")
        if os.path.isfile(p): yield d,p,json.load(open(p))
def check():
    bad=[]
    for d,p,data in rooms():
        for lv,img in data["images"].items():
            f=os.path.join(ROOT,d,img["file"]); W,H=img["size"]
            if not os.path.isfile(f): bad.append(f"{d}/{lv}: missing {img['file']}"); continue
            if Image.open(f).size!=(W,H): bad.append(f"{d}/{lv}: size {Image.open(f).size} != {W}x{H}")
            ids=set()
            for h in img["hotspots"]:
                tag=f"{d}/{lv}/{h.get('id')}"
                if h["id"] in ids: bad.append(f"{tag}: duplicate id")
                ids.add(h["id"])
                x,y,w,hh=h["rect"]
                if x<0 or y<0 or x+w>W or y+hh>H: bad.append(f"{tag}: rect {h['rect']} outside {W}x{H}")
                if min(w,hh)<MIN: bad.append(f"{tag}: rect smaller than {MIN}px")
                if h["kind"] not in KINDS: bad.append(f"{tag}: unknown kind {h['kind']}")
                if h["action"] not in ACTIONS: bad.append(f"{tag}: unknown action {h['action']}")
                if not h.get("label"): bad.append(f"{tag}: no label")
    for b in bad: print(b)
    print("hotspots ok" if not bad else f"{len(bad)} problem(s)")
    return not bad
def colour(i):
    r,g,b=colorsys.hsv_to_rgb((i*0.13)%1,0.85,1); return (int(r*255),int(g*255),int(b*255))
def overlay(out,sc=3):
    os.makedirs(out,exist_ok=True)
    for d,p,data in rooms():
        for lv,img in data["images"].items():
            im=Image.open(os.path.join(ROOT,d,img["file"])).convert("RGB")
            im=im.resize((im.width*sc,im.height*sc),Image.NEAREST)
            dim=Image.new("RGB",im.size,(0,0,0)); im=Image.blend(im,dim,0.25)
            dr=ImageDraw.Draw(im,"RGBA")
            for i,h in enumerate(img["hotspots"]):
                x,y,w,hh=[v*sc for v in h["rect"]]; c=colour(i)
                dr.rectangle([x,y,x+w-1,y+hh-1],fill=c+(40,),outline=c+(255,),width=2)
            for i,h in enumerate(img["hotspots"]):  # labels after boxes so they stay readable
                x,y=h["rect"][0]*sc,h["rect"][1]*sc; c=colour(i); t=h["id"]
                tw=dr.textlength(t); ty=y+2
                dr.rectangle([x+2,ty,x+4+tw,ty+11],fill=(0,0,0,190)); dr.text((x+3,ty),t,fill=c)
            im.save(os.path.join(out,f"{d}_{lv}_hotspots.png")); print(d,lv,len(img["hotspots"]))
if __name__=="__main__":
    if sys.argv[1:2]==["overlay"]: overlay(sys.argv[2] if len(sys.argv)>2 else "out")
    else: sys.exit(0 if check() else 1)
