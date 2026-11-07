---
name: room-ambience
description: Room lighting + micro animation layer RoomAmbience (MV-167, PR #49 stacked on #47); positions tied to PixelLab room art
metadata:
  type: project
---

2026-10-24: Parames asked for an engine room, lighting and micro animation in every room, using PixelLab only if quota was left. The quota was 0, so Parames chose to do it in code. PR maxexq/mobile-vault#49 (branch mv-167-room-ambience, Plane MV-167) (stacked on #47) MERGED 2026-10-24 together with #47; artifact v45. MV-167 Awaiting Verify (phone perf check).
- `scripts/world/room_ambience.gd` is a child of RoomView (between interior and actors) and of CabView ("cab_<tier>"). Drawn at 12 fps. Features switch `room_ambience`, tune `ambience.flicker`, Dev.lamps_flicker (group "room_ambience"), autotest `--only=ambience`.
- Effect pixel positions match the 64x52 PixelLab overrides, so a redrawn room means moving its entries in `_draw_fx`. Wide rooms (_x2/_x10) get no ambience.
- Night strength comes from Vehicle.apply_light(night). Don't derive it from the glow colour, which gets brighter at night.
- Gotcha: after adding a new class_name script, run `godot --headless --import` before the autotest, otherwise the run hangs.
Related: [[pixellab-api]], [[engine-bay-design]], [[god-mode]]
