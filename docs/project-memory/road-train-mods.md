# Road train exterior mods (MV-748 design, MV-762 in game)

- Design: /mnt/project-files/designs/road-train-mods/approved/README.md (9 mods approved by Parames 2026-11-10, page "Road Train Mods").
- In game (switch `road_train_mods`, MV-762): `tools/art/road_train_mods/build.py` cuts the approved art into
  `assets/vehicles/road_train_v3/mods/` (+ mods.json for the shared `ShellMods` layer from MV-760, `_base_floors` 2,
  body parts move 112 px a deck incl. a `@1` override for the 1-deck body; roofs fixed).
- `scripts/world/road_train_mods.gd` (RoadTrainMods): body parts on the body shell, `solar_covers_t` on every trailer,
  `roof_turret` on the rearmost trailer's roof (stock tyres + cans cleared on a copy of the texture, `_clear_turret`),
  heavy suspension = AmbulanceMotion.set_under_part (inside `wells`: rides the body, under the tyres), off-road wheels =
  AmbulanceMotion.wheel_lv -> `mods/offroad_wheels_spin_L<n>.png` (48 frames, MV-759 base).
- GOD รถ row "อัปเกรดภายนอกโร้ดเทรน" (`Dev.road_train_mods(lv)`), autotest in `_road_train_test` (`--only=road_train`).
