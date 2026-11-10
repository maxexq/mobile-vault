---
name: road-train-fix-anim
description: MV-740 road train shell cleanup (pinholes, cab glass, rear cage, room frames) + micro animation (tyres, landing legs, lamps) + code air lines between units (PR #221)
metadata:
  type: project
  modified: 2026-11-09T20:09:40.479Z
---
2026-11-09 Parames: fill see-through pixel holes, rear looks cut off, frame the rooms, micro animation for the whole rig
(wheels spin, landing legs up while driving / down when fully stopped, the shock-looking part over the tandem, etc.). Plane MV-740.
- Branch mv-740-road-train-fix stacked on mv-736-decker (PR #216) to reuse the Decker's AmbulanceMotion/frames code. Code only, 0 PixelLab gens.
- tools/art/road_train/cleanup.py (in place on assets/vehicles/road_train_v3 after designs/road-train/game/shell.py):
  pockets <=14 px + 1 px slits below roof filled, cab glass row-fill, body rear ladder cage outer rail (body ends x 694), far-side leg shadow removed,
  Decker-style window frames. Rerun order: shell.py -> cleanup.py -> anim.py.
- tools/art/road_train/anim.py -> anim.json {"floors": body per deck, "trailer": per deck}: wheels, legs rects, head, roof_lamps, tails, search, mast; wheel_spin.png.
- AmbulanceMotion gained unit ("" | "trailer"), shell_file(), legs (cut from shell, in `behind` node at v2_root index 0, LEG_LIFT 6), bump(speed, lead). Vehicle.rt_units = one AmbulanceMotion per container trailer. Dev.road_train_anim(mode), GOD row โร้ดเทรน buttons.
- Preview webps (real game code at 1 shell px): /mnt/project-files/designs/road-train/fix-1109/.
Related: [[road-train-ingame]], [[vehicle-anim]], [[vehicle-2floor]], [[vehicles-flat-2d]].
- PR #221 (base mv-736-decker). 20:34 Parames: REMOVE the shocks drawn on the wheels (done, Shock class deleted) + air lines must connect
  unbroken -> body keeps its original air lines (they run into the trailer art), scripts/world/rt_couplings.gd draws trailer->trailer
  hoses (4) + tow link and coupler caps when no trailer; cleanup clears the cage scraps on the trailer nose (x 0-8).
- 21:20 Parames round 3: redo the joint between container trailers 2-3 -> cleanup.py link() writes trailer_link_f2/f3.png (plate/hook/lower tail lamp cut, lip + B-link beam tiled from the nose beam rows 342-357 to the canvas edge, fifth-wheel plate, upper lamp unlit); unit "trailer_link" in anim.json (no tails), InteriorV3Panel.rt_trailer_kind(u, count, decks) picks it for every trailer but the last (road + interior). RtCouplings tow-link bar removed. `cleanup.py link` rebuilds only the variants.
- 2026-11-10 round 4: (1) trailer nose looked cut (thin post under wider roof band) -> cleanup.nose_post (post widened x3-9, outline x2), `cleanup.py nose`. (2) Parames RULE: never reuse the same trailer twice -> new 2nd trailer: designs/road-train/trailer2/t2.py (sketch|gen|finish; only the box redrawn, windows/wheels/legs/beam kept pixel-identical). 3 samples reefer/military/scrap (Pro inpaint-v3 ~27 gens each, balance 17366), compare_all_1x.png, pick pending (recommended B military).
- 2026-11-10 14:01 Parames: "ตัดพ่วง 2 ออก เอาเป็น patch แรก พ่วงได้แค่ 1" -> Data.MAX_TRAILERS = 1 (MAX_SLOTS 21), Game.fit_trailers() on load folds 2-trailer saves (rooms rehomed or refunded), GOD trailer row 0/1. 2nd trailer design samples PARKED (trailer2/ kept for later). B-link shells kept but unused with 1 trailer.
