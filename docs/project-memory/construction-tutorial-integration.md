---
name: construction-tutorial-integration
description: Interface contract between the timed-construction/builder feature and the Tutorial feature (branches, signals, state keys)
metadata:
  type: project
  modified: 2026-10-22T15:42:00.623Z
---

Agreed 2026-10-22 between the two threads working in parallel on github.com/maxexq/mobile-vault:

- Construction branch `feat/construction`; Tutorial branch `feat/tutorial` (both off main v4.2). Whoever merges second rebases; append (don't reorder) in hud.gd / autotest.gd.
- Construction API: signals `Game.construction_started(slot, kind)` / `Game.construction_finished(slot, kind)` (kind "build"|"upgrade"); state `Game.s.rooms[i].build` = {} idle or {"kind","left","total"}; `Game.is_constructing(slot)`.
- Builders: dweller field `d.role == "builder"` (ช่างก่อสร้าง); traits `engineer`, `quick_hands`, `architect`, `clumsy` (bad); `Crew.build_speed(d)`.
- Tutorial merged to main 2026-10-22 (PR #1). Tutorial: autoload `Tutorial` (scripts/autoload/tutorial.gd), state `Game.s.tutorial` = {"step","done"}; it duck-types the construction API (has_method) so it works before/after the merge.

Related: [[mobile-vault-rules]]
