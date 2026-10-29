# Merged 2-slot grow rooms (rooms merge only at level 3 -> upgraded + clean). L1 + mirrored L1 on 288x96, then edit-images-v2.
import sys; sys.path.insert(0,"/mnt/project-files/designs/room-redesign-preview"); sys.path.insert(0,"/mnt/project-files/designs/room-redesign-preview/living")
from PIL import Image
from kitchen_edit import edit
D={
"A":("One single wide continuous upgraded clean indoor hydroponic grow room inside an armored vehicle (two rooms knocked through, no dividing wall), dark riveted steel walls. "
     "Keep the left half layout: a sturdy clean metal table with a row of neat planter pots of leafy green vegetables under a purple-pink LED grow light bar. "
     "The right half: a tall clean metal shelving rack with three tiers of planter trays of lettuce and herbs, each tier lit by its own purple LED strip, a clean water tank with a small pump and tidy tubes, a sealed seed cabinet. "
     "Level 3: repaired, organised, no junk on the floor. The bottom strip of the image is open empty clean floor across the whole width, for people to walk."),
"B":("One single wide continuous upgraded clean garden room inside an armored vehicle (two rooms knocked through, no dividing wall), dark riveted steel walls. "
     "Keep the left half layout: rain water barrel on a stand with drip hoses, a long wooden raised planter box with tomato plants and vegetables. "
     "The right half: more neat raised wooden planter beds with tomatoes, peppers and herbs on a trellis, a few painted tyre planters, a tidy tool rack, a compost bin, warm hanging bulbs. "
     "Level 3: repaired, clean, organised, no junk on the floor. The bottom strip of the image is open empty clean floor across the whole width, for people to walk."),
}
k,seed=sys.argv[1],int(sys.argv[2])
a=Image.open(f"out/gr{k}_s3.png").convert("RGBA"); b=Image.new("RGBA",(288,96)); b.paste(a,(0,0)); b.paste(a.transpose(Image.FLIP_LEFT_RIGHT),(144,0)); b.save(f"out/gr{k}_m2_base.png")
edit(f"out/gr{k}_m2_base.png",f"out/gr{k}_M2_s{seed}.png",D[k],seed)
