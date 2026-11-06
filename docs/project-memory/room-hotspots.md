---
name: room-hotspots
description: MV-599 tap hotspots for v2 rooms (PR #177): <room>/hotspots.json rect per tappable object, tools/hotspots.py check/overlay, required for every new v2 room
metadata:
  type: project
---

2026-10-29 (MV-599: PR #177 merged into the #176 branch, but #175 hit staging 1s earlier, so the stack (living, hotspots, grow, infirmary) reached staging via PR #182; Done): Parames approved option 1 = tap hotspots on the existing PixelLab art (no extra gens) instead of cutting objects into sprites.
- PR #177 (mv-599-room-hotspots, stacked on #176 -> #175; retarget to staging when they merge). Files: docs/art/room-style-reference-v2/{kitchen,living}/hotspots.json, tools/hotspots.py (`check` / `overlay OUT`), *-hotspots-preview.png, "Tap hotspots" section in room-style-reference-v2.md, CLAUDE.md rule.
- Format: images.<L1|L2|L3|L3_x2|L3_x3> -> {file,size,hotspots:[{id,label,rect:[x,y,w,h] native px,kind,action,needs_power?}]}. Ids stable across levels (stove at L1..L3), later entries win on overlap, kinds/actions whitelisted in hotspots.py.
- Overlays in /mnt/project-files/designs/room-redesign-preview/hotspots/ and artifact Room Redesign Samples v10 (top section).
**How to apply:** every new v2 room (grow room MV-598 next) ships hotspots.json in the same commit, run check + look at overlay. Godot wiring waits for the move to v2 room size. Related: [[room-redesign-preview]], [[grow-room-redesign]], [[mobile-touch-input]].
