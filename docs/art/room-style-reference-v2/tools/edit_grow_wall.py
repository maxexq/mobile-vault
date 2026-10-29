# B back wall -> riveted steel bus wall like A (edit-images-v2 keeps the layout)
import sys; sys.path.insert(0,"..")
from kitchen_edit import edit
D=("Same room, same layout, keep every planter, tyre, water barrel, plant and the hanging bulb exactly where they are. "
 "Replace the back wall windows and plastic sheeting with a solid dark wall of rusty riveted steel plates of an armored bus interior, "
 "with pipes and cables running along it, arched steel ribs on the ceiling, no windows. Dim, gritty, the only light is the warm hanging bulb. "
 "The bottom strip of the image is open floor for people to walk.")
seed=int(sys.argv[1]); edit("out/gr_B_7_1.png",f"out/grB_wall_s{seed}.png",D,seed)
