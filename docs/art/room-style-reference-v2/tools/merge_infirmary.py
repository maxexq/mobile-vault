# Merged 2-slot infirmary (merge only at level 3 -> upgraded + clean). Option A sick bay left + option B field surgery right on 288x96, then edit-images-v2.
import sys,os; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
from edit import edit
D=("One single wide continuous upgraded clean infirmary inside an armored vehicle (two rooms knocked through, no dividing wall, no pillar in the middle), the SAME dark blue-grey riveted steel wall panels continue across the whole width with no seam, a painted red cross on the left wall. "
   "Left half: a ward with a clean repaired hospital bed with white sheets, an IV drip stand, a clean wall medicine cabinet, an oxygen tank, a heart monitor with a green ECG line, a caged ceiling lamp. "
   "Right half: a tidy surgery corner with a proper steel operating table under a bright round surgery lamp, a clean instrument trolley, shelves of labelled medical supply boxes with red crosses, a folded stretcher and a clean privacy curtain on a rail. "
   "Level 3: repaired, sterile, organised, no junk or blood on the floor. The bottom strip of the image is open empty clean floor across the whole width, for people to walk.")
seed=int(sys.argv[1])
a=Image.open(sys.argv[2] if len(sys.argv)>2 else "out/inf_L3_s1_0.png").convert("RGBA"); bb=Image.open("out/inf_B_7_2.png").convert("RGBA")
b=Image.new("RGBA",(288,96)); b.paste(a,(0,0)); b.paste(bb,(144,0)); b.save("out/inf_m2_base.png")
edit("out/inf_m2_base.png",f"out/inf_M2L3_s{seed}.png",D,seed)
