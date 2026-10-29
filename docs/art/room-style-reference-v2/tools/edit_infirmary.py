# L2/L3 infirmary (option A) via edit-images-v2 from the picked L1 (inf_A_7_0)
import sys,os; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from edit import edit
D={
"L2":"Upgrade this infirmary sick bay to level 2: same layout, same bed position, same IV stand, same medicine cabinet position, same red cross on the wall. The bed is repaired with a cleaner mattress, pillow and a grey blanket, a proper IV stand with a fresh saline bag, the medicine cabinet is fixed and stocked with bottles and bandages, a small bedside table with a lamp and a first aid kit, a folding privacy screen, a clipboard chart on the wall, an oxygen tank on a cart. Still worn and post-apocalyptic but tidier, less junk on the floor. The bottom strip of the image is open empty floor for people to walk.",
"L3":"Upgrade this infirmary sick bay to level 3: same layout, same bed position, same IV stand, same medicine cabinet position, same red cross. Clean and fully equipped: a clean adjustable hospital bed with white sheets, a heart monitor screen with a green ECG line on a stand beside the bed, a modern IV pump stand, a clean white medicine cabinet full of labelled supplies, a defibrillator on the wall, a clean oxygen tank with a regulator, a bright clean ceiling lamp, painted clean metal wall panels with the red cross. Sterile, organised, no junk. The bottom strip of the image is open empty clean floor for people to walk.",
}
lv,seed=sys.argv[1],int(sys.argv[2])
edit("out/inf_A_7_0.png",f"out/inf_{lv}_s{seed}.png",D[lv],seed)
