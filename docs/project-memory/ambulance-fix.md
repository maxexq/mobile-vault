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
- 2026-11-09: downloading Godot 4.7.2 in the cloud was blocked by the auto-mode classifier this session (despite standing OK).
Related: [[ambulance-v3-ingame]], [[vehicle-upgrade-icons]], [[vehicle-anim]], [[vehicle-2floor]].
