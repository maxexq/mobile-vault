---
name: construction-system-v43
description: v4.3 timed construction + builder role/traits in Mobile Vault (PR #2, branch feat/construction) — hooks, art, test gotchas
metadata:
  type: project
  modified: 2026-10-22T16:29:41.091Z
---

v4.3 (2026-10-22, PR maxexq/mobile-vault#2): building/upgrading rooms takes time. State in `Game.s.rooms[i].build` {kind build|upgrade, total, left}; signals `Game.construction_started/finished(slot, kind)`; `Game.is_site()` = new room not working yet (room_workers() returns [] there, builders are `site_crew()`). Role `d.role == "builder"` (outfit `dw_builder_*`, Ton is builder), traits engineer/quick_hands/architect/clumsy, `Crew.build_speed(d)`. Art: `room_construct`, `scaffold_front`, `fx_weld_0..3`, `fx_dust_0..2`, dweller frames hammer 15-17 / carry 18-19 (tools/art/rooms.py, chars.py). Tutorial (PR #1) listens to these hooks.

**Why:** later threads touch rooms/crew and must respect sites.
**How to apply:** any new code counting rooms by type should skip `Game.is_site(i)`. Autotest's "combat kills enemies" relies on a ranged shooter in the squad (fixed by re-squading the explorer). Art generator: `assets/exp/exp_ruins.png` and `tools/art/__pycache__` change on every run — `git checkout` them. Artifact XZt7RMvDG7TFXjdH5MYmAU v9 = v4.3 incl. tutorial. See [[mobile-vault-workflow]].
