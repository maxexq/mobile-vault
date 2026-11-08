---
name: road-train-ingame
description: MV-721 two vehicles only (ambulance van + road train rig, switch road_train), B-double v2 shells in the v3 interior, body 2-3 decks
---

2026-11-08 Parames: "put this vehicle (approved B-double v2) in the game, cut the game's vehicles to 2 for now".
- Branch mv-721-road-train stacked on mv-715-ambulance-v3 (ambulance = van, other thread). Ids kept: van = ambulance,
  rig = road train; bus / train saves map to rig in `Game.tier()`; research tier_bus / tier_train hidden, tier_rig has no req.
- Body = lead trailer: `Data.RT_DECKS` [2, 3] (3rd deck at vault.floor_gain_1). Shrinking body keeps rooms
  (`Game._rehome_room`: empty cell else scrap refund).
- v3 interior: `assets/vehicles/road_train_v3/` body_f1-3 + trailer_f2-3 + shell.json, built by
  /mnt/project-files/designs/road-train/game/shell.py from approved/b_double_v2 + full/deck1B/deck2B (110 px decks
  re-pitched to 112). Trailers have no gap (container nose on the unit in front).
- Pending pick (card 2026-11-08): road train trailers 3 decks (27 rooms, recommended) vs 2 decks (21) vs old body 4-5.
- Outside world: still the old rig art until world v2 (MV-602; the ambulance thread's Vehicle.v2 handles the van).
Related: road-train-samples, ambulance-v3-ingame, world-v2-scale-plan.

On the road (world v2): `Vehicle.v2_wanted()` also takes the rig when `road_train` is on (1-3 floors, `body_f<n>.png`),
`v2_rt()` picks the RT_* cell grid, `V2_W_RT` 347, roof slab 48 px under the shell top, smoke (-9,-16) and headlight
(-109,36) from cell (0,0). Trailers stay old art (phase 2). GOD `Dev.road_train_world(2|3)`.
