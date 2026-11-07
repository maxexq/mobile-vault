---
name: rooms-crew-v3-ingame
description: MV-711 v3 rooms + ref v3 crew in the game via InteriorV3Panel (switch rooms_v3 / rooms_v3_review), PR #193 stacked on #192, tools/v3_import.py
metadata:
  type: project
  modified: 2026-11-04T15:22:18.701Z
---

2026-11-04 Parames: "add crew v3 + room v3 to the game". Plane MV-711 (In Review), PR maxexq/mobile-vault#193 (branch mv-711-rooms-crew-v3, base mv-710-parallax-v2 = PR #192; retarget to staging after #192 merges). Playable artifact v59.
- Scope picked: a separate v3 interior view (HUD "v3" button, InteriorV3Panel + RoomV3Cell + CrewV3Actor + V3Art), NOT the world itself (world still 64x52 until v3 vehicle shells, [[world-v2-scale-plan]]).
- Parames chose (decision card 15:12) to include In Review sets too: switch rooms_v3_review on (grow, water, science, radio, refinery, workshop, empty). Approved: kitchen, medical, quarters (rest), armory.
- tools/v3_import.py: source paths per room (picked files, see ROOMS dict), idle overlay = changed pixels of idle GIF (GIFs bake old crew in working/powerout, so only idle used), crew sheets 64x64 rows per clip. Re-run after art changes + godot --import.
- Crew shader shaders/crew_v3_blend.gdshader ports [[crew-room-blend]]; emergency lamp drawn in RoomV3Cell per [[room-v3-emergency-light]].
- web/ NOT re-exported in #193: cloud container had no cloud_config.json (pck credential extraction blocked by the auto-mode classifier). Needs export from a machine with the config.
- Not in game: rooms with no game type (saloon, gunner, pen, quarantine, training, vault, drones, library, mushroom, nav, power, festival rooms), merged x2/x3 art, engine bay v3.
