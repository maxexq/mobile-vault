---
name: large-rooms
description: Large rooms (merge 2-3 same-type cells) in Mobile Vault, PR #13 branch feat/large-rooms — data model, numbers, art keys, atlas size
metadata:
  type: project
  modified: 2026-10-22T20:12:02.988Z
---

Built 2026-10-22 (PR maxexq/mobile-vault#13). Anchor = left cell keeps the room; other cells `type: "annex"` (has a stub entry in Data.ROOMS so room_def never crashes). Use `Game.room_anchor/room_cells/room_span/room_scale/room_capacity/room_power_pm`, `merge_rooms/split_room/merge_block`. Merge is a construction job `build.kind == "merge"` (room keeps working, no bonus till done). Numbers in data.gd: SPAN_EFFICIENCY [1,1,1.10,1.25], MERGE_* costs, SPAN_UPGRADE_DISCOUNT 0.8.
Art: `room_<type>_x<gaps>` (x2, x10, x2_2, x10_2; gap 10 = ladder shaft between main-body cols 0|1). Atlas packed at 2048x2048 since then.
View: anchor RoomView spans cells; Vehicle._sync_large_rooms draws seam strips above the shell.

**Why:** Parames asked for rooms using 2-3 slots.
**How to apply:** any new code looping rooms must skip `"annex"` (or use anchors) and use room_capacity not Data.ROOM_WORKERS; future chassis modules stay out of Data.MERGEABLE. Autotest `-- --autotest --only=large` runs these checks fast. Related: [[construction-system-v43]], [[modular-chassis-design]], [[json-int-float-ids]].
