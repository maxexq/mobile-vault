---
name: ambulance-mods-ingame
description: MV-763 approved ambulance exterior mods in game via ShellMods (switch ambulance_mods), per-floor wheel-clipped layers, off-road tyres lift the body
metadata:
  type: project
---
2026-11-10 Parames: "เอา Mod ที่ approved ของรถพยาบาล เข้าเกมได้เลย". Plane MV-763, branch mv-763-ambulance-mods stacked on
mv-760-decker-mods (shared `ShellMods` layer, owned by the Decker thread; extras added here: optional 3rd entry element =
file, optional `"z"`).
- Layers: tools/art/ambulance_mods/build.py -> assets/vehicles/ambulance_v3/mods/. Parts = pixels differing from the shell
  they were painted on (git 228bdbe), specks dropped, holes filled. Rerun after any shell rebuild (wheel x per floor in anim.json).
- In game: spike_ram, roof_turret (z 1, hidden in room-squad mode), armor_plates (+armor_roof L3 band), rad_shield (L2 hides
  the driver), suspension (all rear wheels), fuel_tanks (fit 3/2/1 at 1/2/3+ floors, rest on fuel_rack), offroad_wheels
  (AmbulanceMotion.set_tyres + body lift R-22.5; still layer in the interior / without vehicle_anim).
- Not wired (not approved): tracks, heater flue, solar shutters, rain catcher.
Related: [[vehicle-upgrade-icons]], [[ambulance-v3-ingame]], [[vehicle-anim]].
