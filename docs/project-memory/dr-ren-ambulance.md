---
name: dr-ren-ambulance
description: MV-596 Dr. Ren starting vehicle concepts (welded ambulance around 3-wide kitchen), PixelLab inpaint-v3 pipeline, awaiting pick
metadata:
  type: project
---

2026-10-29 (Plane MV-596, Needs Decision): Parames wants Dr. Ren's starting vehicle: front = ambulance cab, body welded from several ambulances (weld seams all round, especially roof), gear for travelling to find survivors, room = 3-wide merged kitchen per [[room-redesign-preview]] / docs/art/room-style-reference-v2.md. Preview only.
- Pipeline (/mnt/project-files/designs/dr-ren-ambulance/: base2.py, inp.py, rear.py): crude PIL blocking sketch on 512x208 (cab left facing left like the game, three mismatched box panels white/cream/faded orange, roof band + skirt), kitchen_L3_x3 pasted at x76,y56, POST /v2/inpaint-v3 with mask = everything except the room (room pixels kept exactly). inpaint-v3 max 512 px wide, so rear end added by a 2nd inpaint on the right 472 px shifted + 44 px masked strip -> final 552x208.
- Cost ~16 gens per 512x208 inpaint call. Total ~130 (8 calls); balance 3257 -> 3121 also included the concurrent crew-gun thread. Count own calls, not balance diff.
- Options: A Rescue Beacon (antenna, loudspeakers, searchlights), B Long-Range Scout (roof rack tyres/jerrycans, lookout seat, winch; gear touches top edge), C Field Clinic (awning, water tank, string lights, red cross flag, solar, dish; plain cab). Artifact https://claude.ai/artifact/UKoxMznXL9M7gDoVUEc22U
Related: [[pixellab-api]], [[modular-chassis-design]].
- 02:11 Parames PICKED C, rear must be flat 2D (no rear door / no 3/4 view) -> rear2.py with flat sketch + "strict flat 2D orthographic" prompt, seed 2 used (steel end wall). Closed side = closed.py (sketch panels/windows/door over room, inpaint mask x76..511 y56..151), seed 1 used. See-through = code blend closed over cutaway at 70 % opacity (no gens). Files C_cutaway/C_closed/C_seethrough_70.png. ~64 gens this round, ~195 total. MV-596 In Review.
