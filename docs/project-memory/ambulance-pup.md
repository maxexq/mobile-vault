# Ambulance pup trailer (MV-737)

- 2026-11-09 Parames asked to redo sample 1 (Rigid + pup) flat 2D: `designs/road-train/pup2/pup2.py` (ambulance v3 head,
  inpaint-v3 2 seeds), picked **B**, then asked for a sturdier, more realistic coupling -> `pup2/joint.py` (code, 0 gens:
  tow plate + pintle hook, thick towing eye, box-section drawbar tapering into a gusset under the pup, 2 safety chains,
  red/blue air lines). APPROVED as `designs/road-train/approved/12_ambulance_pup_{1x,2x}.png`.
- "ใส่ได้เลย" -> in game behind switch `ambulance_pup`: `pup2/game_shell.py` stretches the approved art to the trailer grid
  (3 rooms x 2 floors, Data.TRAILER_SLOTS 6) -> `assets/vehicles/ambulance_pup/pup_f2.png` + `pup.json`. Unit i at
  ambulance x 600 + 542 i, cells x 86 + 152 col, y 88 / 200, bottom on the road. v3 interior `InteriorV3Panel.pup()`,
  world v2 `Vehicle.v2_pup_trailers()` (`v2_shell_trailers()` = road train containers or pups). Shells front to rear
  above the ambulance shell so each tow plate sits on the unit in front.
- Gotcha: don't tell shells apart by node name (a re-added "PupShell0" gets renamed while the old one waits for
  queue_free) -> `Vehicle._pups_up` flag.
- Approved vehicles gallery: https://claude.ai/artifact/2R19jA4rkB7qkM43bAxPsV (designs/vehicles-approved-page/).
