---
name: ambulance-fix
description: MV-741 Dr. Ren ambulance clean-up (code only): tools/art/ambulance/cleanup.py fills cab holes, drops strays, frames room windows; branch mv-741-ambulance-cleanup
metadata:
  type: project
---
2026-11-09 Parames: "แก้รถพยาบาลหมอ Ren" -> picked "Clean-up like Decker (code only)". Plane MV-741.
- Root cause of the holes: tools/art/ambulance_front/apply_front.py (MV-731) keys out every pixel within 24 of the
  front art's backdrop (38,36,42), which also punched the cab's own dark paint (grille, arch, door seams, tyre).
- Fix: tools/art/ambulance/cleanup.py (run AFTER apply_front.py, then tools/ambulance_anim.py): enclosed holes in the
  cab refilled from front_stock.png, small (<=20 px) pockets elsewhere get the darkest neighbour, specks <=3 px
  removed, every room opening framed like the Decker (MV-739). Rear x>=592 untouched (ladder + pup tow plate 600-621).
  anim.json anchors unchanged. Autotest: _amb_shell_flaws in _ambulance_v3_test (--only=ambulance_v3).
- Micro animation: the ambulance already has MV-726 (tyres, hops, lurch, beacon, lamps, lantern, mast, flag); the Decker's
  extra night headlight beam lives in PR #216's ambulance_motion.gd, so not ported here to avoid conflicts.
- Branch mv-741-ambulance-cleanup off staging. Never push to mv-737-ambulance-pup (PR #217).
- 19:55 Parames round 2: lantern disc removed + hook (cleanup.py lantern()), PixelLab flame flicker (animate-with-text-v3 take 3,
  tools/art/ambulance/lantern_pl.png 8x18x22) mapped onto glass pixels in anim.json lantern_px/frames/glow by ambulance_anim.py,
  drawn by AmbulanceMotion.flame (no new imported textures). Orange ghost arc (x266-290,y28-48) removed. Solar rail over tank =
  Pro inpaint-v3 take s2 (tools/art/ambulance/solar_pl.png, 10 gens/take, 30 spent); Parames PICKED B 20:09 (in PR).
  Roof-mods thread's solar_covers sit on the side band (x296-436,y63-92), not the tank. PR #219 first commit CI autotest green.
- 20:14 Parames APPROVED + saved ("เซฟเลย โคมไฟ ดีมาก"): /mnt/project-files/designs/ambulance-fix/approved/README.md. RULE: vehicle lamps have no baked backplate/halo; light = code additive glow.
- 20:14 swing: cleanup.swap_lantern puts the same approved lantern_still.png (9x16) under the bracket on all shells (pivot cy-9 for 1-2 floors, cy-7 for 3-5); anim.json lantern_still/lantern_pivot; AmbulanceMotion.lamp pendulum APPROVED 20:21 (LAMP_W 4.6, damp 1.1, max 0.35 rad), cut from the shell only when vehicle_anim is on.
- 20:22 Parames picked "Driver + micro anims (code)" (0 gens): tools/art/ambulance/driver.py -> driver.png/json (approved A2 from
  dr-ren-ambulance/drive/driver/approved, rows drive/chill/idle/still, 30x26 at shell (87, h-139)); cleanup.bake_driver bakes the
  still frame. ambulance_anim.roof_bits -> anim.json plant_px/plant_base (leaves above pot rims, x138-223 + 457-584), solar_px,
  pipe (459,5.5). AmbulanceMotion: driver state by speed/engine, leaves sway (breeze parked / lean east driving), glint by day, puffs.
  Rebuild order: checkout staging shells -> driver.py -> cleanup.py -> ambulance_anim.py. Previews designs/ambulance-fix/micro_*.gif.
- 20:32 round 3 "pl new flag, pots, birdhouses, mast + anim": Pro inpaint-v3 (15 takes, 150 gens) -> Parames PICKED 20:41 flag 3,
  potsL 2, birds 1, potsR 2, mast 3; animate-with-text-v3 (27 takes) flag s1, potsL s2, potsR a s1 + b s3, birds s1 (sparrow);
  mast PL anims broke the wires -> code blink only. Sources designs/ambulance-fix/roof2/ (parts.py, gen.py, anim.py, compose.py);
  repo tools/art/ambulance/roof/ (stills + strips + roof.json masks). cleanup.roof_parts runs LAST (after window frames);
  ambulance_anim template-matches each still -> anim.json clips; AmbulanceMotion clips replace the code flag wave + leaf shear.
  21:00 Parames APPROVED the roof set (saved designs/ambulance-fix/approved/roof/).
  21:04 cleanup.pipe_knob (floating rain-cap knob) + tail_hoods (lamp hoods x>=618 near tail lamps; hitch kept, pup thread told).
  21:10 staging merged Decker PR #216 -> AmbulanceMotion is keyed by dir + floors (DIR / DK_DIR); MV-741 code ported onto it.
  Previews: designs/ambulance-fix/full_anim_f{1,2}.gif (Python mirror incl. nose.png).
- 2026-11-09: downloading Godot 4.7.2 in the cloud was blocked by the auto-mode classifier this session (despite standing OK).
Related: [[ambulance-v3-ingame]], [[vehicle-upgrade-icons]], [[vehicle-anim]], [[vehicle-2floor]].
