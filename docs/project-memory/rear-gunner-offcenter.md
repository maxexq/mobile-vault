---
name: rear-gunner-offcenter
description: MV-629 rear gunner room L1 as an OFF-CENTER one-point style test (VP shifted to the rear/right); generate-image-v2 ignores off-center guides, code scaffold + inpaint-v3 works
metadata:
  type: project
---

2026-10-30 Parames asked (with a reference screenshot where rooms show only one slanted side wall) for one still rear gunner room (crew shoot monsters chasing the vehicle) in off-center one-point perspective. Plane MV-629 (In Review). Files /mnt/project-files/designs/room-redesign-preview/gunner_offc/: guide_offc.py (VP (132,24), back wall x49-139 y9-65, 6 px walkway), gen_gunner.py (round 1), inp_gunner.py (round 2 scaffold + inpaint-v3), tone.py (match kitchen v3 L1 mean/std), compare.py (kitchen | water | gunner in the lineup_v3 hull).
- LESSON: generate-image-v2 with the off-center guide as reference_images gave 12/12 centred rooms (30 gens wasted). Code scaffold in the exact geometry + inpaint-v3 (mask = back wall + floor + inner wall body; ceiling, corner edges, thin rear wall kept) gave 3/3 correct. 10 gens per 144x96 inpaint call.
- Pick shown: out/gi_C_3_0 -> gunner_offc_L1.png (twin MG on tripod at rear slit, car seat, sandbags, ammo shelves, map). Alt out/gi_A_5_0. 60 gens total (4419 -> 4359).
- Conflict: v3 hull has the 16 px ladder shaft at the rear, where the firing port should be.
- Page: https://claude.ai/artifact/P8FkcuD8iNZ6Mxhzadmo9o (not yet on the room index).
- 12:13 Parames: right side must be a STRAIGHT vertical edge (no slant). v2 inp_offc2.py <gunner|living> <seed>: VP on right interior edge x=138, flat 5 px right wall section (gunner: firing slit). Picks living out/o2_living_3_0 (-> living_offc_L1.png), gunner out/o2_gunner_5_0 (-> gunner_v2_L1.png), tone2.py + compare_floor_v2.png. 40 gens (4359 -> 4319). Page v2.
- 12:17 Parames asked 3 vehicle REAR END caps like his mock-up crop (tail/ref_tail.png): tail/gen_tail.py A|B|C (generate-image-v2 64x128 transparent, ref = crop, style = gunner_v2_L1) -> picks tail_A_7_0 (arched door, awning, vines, stairs), tail_B_7_0 (armoured gunner end, ladder, sandbags), tail_C_7_1 (roll-up shutter + plank ramp). place_tail.py -> floor_tail_{A,B,C}.png. 30 gens (4319 -> 4289). Page v3. Awaiting pick.
**How to apply:** if Parames adopts off-center, use the scaffold+inpaint method, update Room guide v3 ([[room-guide-v3]], [[room-camera-one-point]]).
