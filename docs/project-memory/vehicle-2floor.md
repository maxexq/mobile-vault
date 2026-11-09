---
name: vehicle-2floor
description: MV-736 Decker double-decker bus APPROVED (starts 2 decks, 3-deck scrap upgrade) in designs/vehicle-2floor/approved/, unlock route pick pending, not in game
metadata:
  type: project
---
2026-11-09 Parames: "ขอดีไซน์รถคันใหม่เลย ที่เริ่มต้นมามี 2 ชั้น". Read as concept + sample art (not in game). Plane MV-736 In Review.
- /mnt/project-files/designs/vehicle-2floor/: sketch.py (640x344 code sketch, 2 decks of L1 v3 rooms at y56/168, 448 + 16 px
  rear shaft (armory wall5), 45 px ambulance tyres, keep_<opt>.png = exact pixels), gen.py <opt> L|R <seed> (Pro inpaint-v3,
  two 512 windows, R paints x>=500 only, ~25 gens/call), cabfix.py (C cab repaint with approved B-double prime mover as bottom
  style ref; s3 picked), finish.py (bg clean, ground strip, 1 px outline) -> out/<opt>_{1x,2x}.png. page/index.html.
- Picks used: A_R_s1, B_R_s2 (s1 rear went 3/4 + white sky -> mask clipped x<632), C_cab_s3 (s1/s2/s4 3/4 or extra wheel).
- Artifact https://claude.ai/artifact/Eud8rt7MjYzmUYR6YgcKyd (publish from a scratchpad copy; Artifact refuses /mnt paths).
- Gens: 11 calls ~275; balance 19517 -> 19082 (other threads overlapped).
Related: [[vehicles-flat-2d]], [[road-train-approved-set]], [[ambulance-v3-ingame]].
- 2026-11-09 17:37 Parames PICKED A (Decker bus) -> approved/decker_2deck_{1x,2x} + README. 3-deck upgrade = deck3.py (scrap
  corrugated 3rd deck inserted under the roof, rows >=56 shift 112; L s1 + R s1 picked, ~75 gens) -> approved/decker_3deck. Page v2.
  Next: card asks how players get it (unlock); in-game plan = id decker, switch decker, shell_f2/f3 like ambulance v3, GOD, autotest.
- 2026-11-09 Parames: concept C (Bastion 42-B) becomes ANOTHER vehicle too (MV-738). Picked "เลือก 1 ใน 2": one tier_bus research
  unlocks Decker + Bastion, the next generation picks one. approved/bastion_2deck_{1x,2x}.png = C with cab "43-B" hand-fixed to
  42-B (no gens). In game behind switch `bastion` (id bastion, Data.BASTION, tools/art/bastion/shell.py, 3rd deck = top deck
  repeated in code), branch mv-738-bastion stacked on mv-736-decker.
