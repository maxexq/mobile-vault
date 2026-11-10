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
- 2026-11-09 MV-739 round 2 (ee14f88): bg colour 46,44,48 pockets (roof rail, roof ladder, under chassis) cleared in cleanup.py,
  rear tyre wedge removed, headlight drawn in code (cleanup.headlight, lens 12.5,269.5), anim.json "swing" rect = cables
  under floor swing (AmbulanceMotion._swing_set/_tick_swing). Rebuild order: shell.py (approved art) -> cleanup.py -> anim.py.
  Another thread (MV-736) also pushes to mv-736-decker: fetch + merge before every push.
- 2026-11-09 MV-739 round 3 (a470237): PixelLab front + headlight = designs/vehicle-2floor/front/ (Pro inpaint-v3, 4 takes 40 gens,
  s4 picked, halo stripped) -> front/out/decker_{2,3}deck_1x.png are now the shell.py sources. cleanup.py strays() sweeps
  backdrop fringe / 1 px specks / detached bits, mesh backdrop -> dark glass; stray scan images in stray-check/. Front not yet
  copied into approved/ (await Parames OK).
- 2026-11-10 Bastion round 2 (Parames: stray pixels, roof rail + roof items cut): seam of the two 512 inpaint windows at x 499.
  tools/art/bastion/cleanup.py (0 gens) after shell.py: rail to rear ladder + 2 posts + bent end, tarp/crate outlined, pockets + strays.
  Before/after: /mnt/project-files/designs/vehicle-2floor/bastion-cleanup/.
- 2026-11-10 Bastion round 3 (Parames: room frames, pinholes, solar cell on the front of deck 2, micro anims): cleanup.py holes/frame/solar/lamps,
  anim.py -> anim.json + wheel_spin.png, AmbulanceMotion.BS_DIR, Dev.bastion_anim + GOD ขับ+ไฟ/เบรก. 0 gens; solar drawn in code (PixelLab redraw offered).
- 2026-11-10 (MV-764) Parames: "Bastion 42-B พักไว้ก่อน ซ่อนจากเกม" -> config/features.json bastion=false (parked). Code + art kept; Bastion saves drive the Decker, hull clamped on load (Game.clamp_parked_hull). Turn back on with the switch.
