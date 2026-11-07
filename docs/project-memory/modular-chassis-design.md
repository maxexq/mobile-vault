---
name: modular-chassis-design
description: v4.4 candidate design (2026-10-22): vehicle cells as utility room / turret bay / defense module + engine tow rating for trailers; awaiting Parames's decision
metadata:
  type: project
---

Design only, no code. Page: https://claude.ai/artifact/AbTJnFQm3dZwWDp7xxjJaf (copy at /mnt/project-files/designs/modular-chassis.html). Read from main 031c2f3.
- Modules are new room types in `s.rooms[i]` (no save format change): bay_mg, bay_flak (top floor), bay_flame (bottom or rear col), bay_rail; def_bulkhead, def_wire (bottom), def_shield, def_drone; plus aux_engine (front col, +12 tow). 1 seat each, 60% unmanned. Uses v4.3 construction (time = 40 + scrap*0.35 + comp*2).
- Col 2 = rear (enemies come from the right) +15% range, col 0 -25%; top floor +10%. New breach -> outage 30s on rear cell unless bulkhead neighbour. Pattern bonuses: gun deck, rear wall, citadel, peaceful caravan (A4).
- Tow rating (Parames asked 2026-10-22: more carriages need an engine that can tow, else penalties): tow = 0.35*tier engine*(1+0.2 tune) + 6*engine room lv + 1.5*avg STR + item tow (v8 4/turbo 10/fusion 18) + 12*aux_engine; load = trailers (14t + rooms) x1.2 snow/mud. Not a hard block; over 100%: speed, fuel, stall chance per 10 km, engine power down, hitch wear, morale. tow_grace 20 min for old saves.
- Phases: 1T tow (1-1.5d), 1A MVP mg/flak/bulkhead/wire (3-4d), 1B rest (2-3d), 2 patterns/breach/refit/layout presets (3d), 3 festival skins & loot.
**How to apply:** don't implement until Parames picks; ties to [[strategic-depth-plan]], [[loot-economy-design]], [[festival-minigame-plan]], [[construction-system-v43]].
