"""Mood faces for icons v4 (MV-775): one shared 16x16 circle, black outline, flat orange,
black features drawn per mood. No PixelLab. python3 moods.py [outdir]"""
import sys, os
from PIL import Image
K=(14,12,12,255); O=(242,163,58,255); D=(206,124,36,255); B=(80,170,235,255); W=(250,246,236,255)
def base():
    im=Image.new("RGBA",(16,16),(0,0,0,0)); p=im.load()
    spans=[(5,10),(3,12),(2,13),(1,14),(1,14)]+[(0,15)]*6+[(1,14),(1,14),(2,13),(3,12),(5,10)]
    for y,(a,b) in enumerate(spans):
        for x in range(a,b+1): p[x,y]=O
    for y in range(16):
        for x in range(16):
            if p[x,y]==O and any(not(0<=x+dx<16 and 0<=y+dy<16) or p[x+dx,y+dy][3]==0 for dx,dy in((1,0),(-1,0),(0,1),(0,-1))):
                p[x,y]=K
    return im
def put(im,pts,c=K):
    p=im.load()
    for x,y in pts: p[x,y]=c
FACES={
 # ^ ^ eyes + open grin
 "happy":[(K,[(4,6),(5,5),(6,6),(9,6),(10,5),(11,6),
              (4,9),(11,9),(4,10),(11,10),(5,11),(10,11),(6,12),(7,12),(8,12),(9,12),
              (5,9),(6,9),(7,9),(8,9),(9,9),(10,9)]),
          (W,[(5,10),(6,10),(7,10),(8,10),(9,10),(10,10)]),(D,[(6,11),(7,11),(8,11),(9,11)])],
 # dot eyes, flat mouth
 "neutral":[(K,[(5,5),(5,6),(10,5),(10,6),(5,10),(6,10),(7,10),(8,10),(9,10),(10,10)])],
 # dot eyes with sad brows, frown
 "sad":[(K,[(6,4),(9,4),(5,6),(5,7),(10,6),(10,7),
            (6,10),(7,10),(8,10),(9,10),(5,11),(10,11)])],
 # angry brows, gritted teeth, sweat drop
 "stressed":[(K,[(4,4),(5,5),(6,5),(11,4),(10,5),(9,5),(5,6),(10,6),
                 (4,9),(5,9),(6,9),(7,9),(8,9),(9,9),(10,9),(11,9),
                 (4,10),(11,10),(4,11),(5,11),(6,11),(7,11),(8,11),(9,11),(10,11),(11,11),(6,10),(9,10)]),
             (W,[(5,10),(7,10),(8,10),(10,10)]),(B,[(12,4),(12,5),(13,6)])],
 # crying: shut eyes, tear streams, wailing mouth
 "broken":[(K,[(4,6),(5,5),(6,5),(9,5),(10,5),(11,6),
               (6,9),(7,9),(8,9),(9,9),(5,10),(10,10),(5,11),(10,11),(6,12),(7,12),(8,12),(9,12)]),
           (D,[(6,10),(7,10),(8,10),(9,10),(6,11),(7,11),(8,11),(9,11)]),
           (B,[(4,7),(4,8),(4,9),(4,10),(4,11),(11,7),(11,8),(11,9),(11,10),(11,11),(3,12),(12,12)])],
}
def face(n):
    im=base()
    for c,pts in FACES[n]: put(im,pts,c)
    return im
if __name__=="__main__":
    out=sys.argv[1] if len(sys.argv)>1 else os.path.dirname(os.path.abspath(__file__))
    names=list(FACES); sheet=Image.new("RGBA",(len(names)*144+16,160),(26,24,28,255))
    for i,n in enumerate(names):
        f=face(n); f.save(os.path.join(out,n+".png"))
        sheet.alpha_composite(f.resize((128,128),Image.NEAREST),(16+i*144,16))
    sheet.save(os.path.join(out,"moods_x8.png")); print("ok",names)
