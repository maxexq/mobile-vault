---
name: crew-room-blend
description: Parames rule 2026-10-29: every crew sprite over a v2 room gets contact shadow + room tone grade via /mnt/project-files/designs/room-redesign-preview/crew_blend.py
metadata:
  type: feedback
  modified: 2026-10-29T20:44:21.820Z
---

2026-10-29 (MV-609 thread) Parames said crew looked floating and more saturated than the rooms, saw the before/after fix and said to keep the shadow and use it on the crew.
Rule: every crew sprite drawn over a v2 room (previews, walk GIFs, room anims, and later the game) uses the blend:
1. contact shadow ellipse under the feet (~20x3 px, alpha 110 + darker core),
2. desaturate to 70 % and multiply by the room's average colour cast,
3. light falloff by distance from the lamp x (0.95 -> 0.65), legs (frame rows > 40) x0.92,
4. crew outline pixels (luma < 40) -> the room's darkest colour.
Shared module: /mnt/project-files/designs/room-redesign-preview/crew_blend.py, `Blend(bg, lamp_x).put(im, frame64, x, feet_y)` (frame feet at row 53). First used in armory/walk_armory.py + guide_walk.py.
**Why:** crew read as stickers on top of the room art.
**How to apply:** import crew_blend in every new walk/anim script; for the game, port it as a CanvasItem shader on crew (room tint + lamp pos uniforms) + a shadow sprite, and add it to docs/art/room-style-reference-v2.md + CLAUDE.md in the next repo PR. Older room GIFs (kitchen, living, grow, infirmary, water) were made before this rule and are not re-rendered yet. Related: [[armory-redesign]], [[room-redesign-preview]], [[pixellab-room-gen-rules]].
