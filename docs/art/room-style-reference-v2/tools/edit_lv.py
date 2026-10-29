# L2/L3 living room via edit-images-v2 from the picked L1 (lv_A_7_0)
import sys
from edit import edit
D={
"L2":"Upgrade this living room to level 2: same layout, same sofa position, same TV position, same lamp. The sofa is repaired with a patched cover and cushions, a real low wooden coffee table with a lamp and mugs, a working old CRT television with glowing screen on a proper wooden TV stand, a worn rug, a small bookshelf, a framed photo and a clock on the riveted wall, a cable-strung lamp. Still worn and post-apocalyptic but cozier and tidier, less junk on the floor. The bottom strip of the image is open empty floor for people to walk.",
"L3":"Upgrade this living room to level 3: same layout, same sofa position, same TV position. Clean and fully repaired: a comfortable clean leather sofa with cushions and a throw blanket, a nice wooden coffee table with a board game and mugs, a flat screen TV on a clean TV cabinet with a small speaker and a game console with a green LED, a potted plant, a clean rug, warm wall lamp and a pendant lamp, a bookshelf full of books, framed pictures, clean painted metal wall panels. Upgraded and cozy, no junk. The bottom strip of the image is open empty clean floor for people to walk.",
}
lv,seed=sys.argv[1],int(sys.argv[2])
edit("out/lv_A_7_0.png",f"out/lv_{lv}_s{seed}.png",D[lv],seed)
