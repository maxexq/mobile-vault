---
name: vehicle-anim
description: MV-726 in-game vehicle micro animations on the world v2 ambulance (switch vehicle_anim): rolling tyres, suspension hops, lights, flag; code only, anim.json from tools/ambulance_anim.py
metadata:
  type: project
  modified: 2026-11-08T19:26:21.453Z
---

2026-11-08 Parames: "animate the vehicle: wheels spin, lights, shocks, micro animations on the body". Plane MV-726.
- Branch mv-726-vehicle-anim stacked on mv-715-ambulance-v3 (PR #196). Code only, 0 PixelLab gens.
- scripts/world/ambulance_motion.gd (AmbulanceMotion, RefCounted, owned by Vehicle as `amb`, `amb_on`): tyres + flag
  cloth cut out of the shell at load (get_image -> ImageTexture, cached per floor count), tyres drawn in
  _wheels_root (behind body, stay on road), dark wheel-well half discs ride with body.y; bump() hops tyres front->rear
  at road speed; lurch moves v2_root.x 2 shell px on start/brake. Lights = additive stepped GradientTexture2D glows.
- tools/ambulance_anim.py -> assets/vehicles/ambulance_v3/anim.json + wheel_spin.png (48 frames since MV-759, rolling edge via roll_strip). MUST rerun after
  the ambulance shells are rebuilt (mf/shell.py); AmbulanceMotion.ok(n) checks size and the autotest fails otherwise.
- Fixed on the way: exhaust puffs now from the ambulance stack and drawn over the body; old van driver_cab frames
  were floating beside the ambulance (hidden when v2).
- Vehicle.debug_speed (>=0 overrides speed factor) for GOD/autotest; Dev.vehicle_anim(mode); autotest --only=vehicle_anim.
- Preview clip /mnt/project-files/designs/vehicle-anim/ambulance_drive_brake.webp.
Related: [[ambulance-v3-ingame]], [[ambulance-drive-anim]], [[vehicle-engine-shake]], [[road-train-ingame]].
