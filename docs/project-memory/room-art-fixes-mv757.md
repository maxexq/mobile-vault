---
name: room-art-fixes-mv757
description: MV-757 kitchen idle without the baked cook, rest room idle anim, grow room centre window shows the biome (switch room_window_bg)
metadata:
  type: project
---
2026-11-10 Parames (after the MV-756 "Rooms In Game Now" page): remove the cook painted into the kitchen, animate the
rest room, cut the grow room's centre window so the biome shows (centre window only).
- Kitchen: the cook came from the idle GIF (anim_kitchen.py draws street_cook in idle). Crew-free render
  kitchen_v3/kv3_L*_idle_room.gif (Blend.put patched to no-op), v3_import idle path points there.
- Rest room: rest/anim_rest.py (code only, 0 gens): stove fire + glow, candle, lantern / ceiling lamp, kettle steam,
  dust, L3 TV on (rolling scanline) + floor lamp -> rest/rs3_L*_idle.gif.
- Grow window: v3_import.py WINDOWS cuts pixels brighter than luma 140 inside the rect (L1/L2 [38,25,21,19] alpha 0 =
  slits between boards; L3 [37,27,70,20] alpha 40 = faint glass) in level + stage images and clears the idle overlay
  there; rooms.json level "window". RoomWindowView (behind RoomV3Cell.bg) draws biome v2 sky by hour + far + mid,
  bottom = farY + first solid far row + 6, slides with Game.speed_factor. Tunes room_window.speed / .horizon.
- GOD: Dev.room_window_preview(biome, lv), Dev.room_window_bg(on). Autotest --only=rooms_v3.
**How to apply:** another room with a window = add its rect to WINDOWS and re-run v3_import. L1/L2 slits are thin;
widen by opening the boards only if Parames asks. Related: [[rooms-crew-v3-ingame]], [[rooms-ingame-gallery]].
