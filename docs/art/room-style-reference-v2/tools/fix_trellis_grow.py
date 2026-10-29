# B merged-3 stages 1/2: the inpaint left the right trellis bed fully grown, so copy the left trellis bed of the same stage over it,
# then put the hanging bulb (bright pixels + cord) back from the mature art.
from PIL import Image
s3=Image.open("out/grB_M3_s3.png").convert("RGBA")
for st in ("s1","s2"):
    im=Image.open(f"out/grB_M3_{st}_seed1_0.png").convert("RGBA")
    im.paste(im.crop((279,12,323,71)),(322,12))
    for y in range(12,31):
        for x in range(335,350):
            p=s3.getpixel((x,y))
            if p[0]>140 or (y<21 and 340<=x<=342): im.putpixel((x,y),p)
    im.save(f"out/grB_M3_{st}.png")
