---
name: vehicle-2floor
description: MV-736 Decker bus (PR #216) + MV-738 Bastion 42-B (other pick of the same tier_bus research), both start 2 decks, switches decker/bastion
metadata:
  type: project
  modified: 2026-11-09T18:55:03.439Z
---
2026-11-09 Parames: "ขอดีไซน์รถคันใหม่เลย ที่เริ่มต้นมามี 2 ชั้น". Concepts A Decker bus / B / C Bastion 42-B in
/mnt/project-files/designs/vehicle-2floor/ (sketch.py, gen.py Pro inpaint-v3 two 512 windows ~25 gens/call, cabfix.py,
finish.py, deck3.py). Artifact https://claude.ai/artifact/Eud8rt7MjYzmUYR6YgcKyd (publish from scratchpad copy; Artifact refuses /mnt).
- Picked A (Decker) -> approved/decker_{2,3}deck. Unlock = research tier_bus. In game: switch decker (needs road_train), id bus,
  Data.DECKER/DK_DECKS, assets/vehicles/decker_v3, PR #216 (branch mv-736-decker) In Review. Another Claude also merged
  staging into that branch (2026-11-09 18:43); fetch before pushing.
- Cloudflare 25 MiB pck limit: Parames picked "shrink export" -> project.godot webp compression_method=6 + lossless factor 100.
- MV-738: Parames wants concept C Bastion 42-B as ANOTHER vehicle. Picked "เลือก 1 ใน 2": one tier_bus research unlocks
  Decker + Bastion, next-gen screen picks one (Decker default). approved/bastion_2deck_{1x,2x} = C with cab 43-B hand-fixed
  to 42-B (no gens). Switch bastion (needs decker), id bastion, Data.BASTION (weight 40, hull 140), Game.dk_tier(),
  assets/vehicles/bastion_v3 via tools/art/bastion/shell.py (3rd deck = top deck repeated in code), branch mv-738-bastion
  stacked on mv-736-decker.
- Godot binary in cloud: /root/godot/Godot_v4.7.2-stable_linux.x86_64 (not on PATH; pass GODOT=... to ci_autotest.sh).
Related: [[vehicles-flat-2d]], [[road-train-approved-set]], [[ambulance-v3-ingame]].
