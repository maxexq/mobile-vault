---
name: pixellab-room-gen-rules
description: MV-605 Parames's 5 PixelLab rules for generating (merged) v2 rooms, documented in room-style-reference-v2.md + CLAUDE.md + AGENTS.md (PR #183)
metadata:
  type: feedback
  modified: 2026-10-29T19:14:59.828Z
---

2026-10-29 Parames rules for every PixelLab room gen, above all merged/multi-slot rooms:
1. Source image = style + equipment reference, but furniture may be moved anywhere in the room.
2. Remove walls, pillars, doors and gaps left by old room edges (one continuous room).
3. Decide use zones left to right before gen (grow e.g. seedlings -> main growing -> water system + equipment storage).
4. 3-slot rooms add real working/planting area + support gear; only the small gaps needed for use.
5. 6 px front walkway along the full width; every furniture base intact (no cut legs/bases).
**Why:** earlier merged rooms were mirror/inpaint of single slots and kept seams, empty strips, cut furniture.
**How to apply:** plan zones + mask before any merged gen and check candidates against all 5. Written into docs/art/room-style-reference-v2.md section "PixelLab generation rules for rooms (MV-605)", CLAUDE.md and AGENTS.md via PR #183 (mv-605-pixellab-room-rules -> staging), Plane MV-605 Done (PR #183 merged 2026-10-29). Related: [[room-redesign-preview]], [[grow-room-redesign]], [[pixellab-api]].
