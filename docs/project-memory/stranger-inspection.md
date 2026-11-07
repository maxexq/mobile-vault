---
name: stranger-inspection
description: v4.4 stranger-at-the-door inspection (No I'm Not a Human style); all recruits go through Game.offer_recruit
metadata:
  type: project
  modified: 2026-10-22T18:25:51.722Z
---

Branch feat/stranger-inspection (2026-10-22). New autoload `Inspection` + `InspectionPanel` (hud panel key "door").
Every recruit source must call `Game.offer_recruit(source, elite_bonus=0)`: returns the dweller, or `{}` when a rare
(6%) / very rare (1.5%) high-stat stranger was queued at the door instead. Kinds: human / infected / mimic / thief /
raider; hidden `d.secret = {kind, t}` goes off after a few minutes. State in `s.insp` (queue + stats), `s.insp_log`.
Art: `tools/art/inspect.py` → `assets/inspect/` (run alone, not the whole generator).
Autotest `_inspection_test` must run BEFORE `_settings_test` (that one leaves the title screen up).

**Why:** Parames asked to adapt the door checks and that recruits can be thieves/bad people.
**How to apply:** new recruit hooks (e.g. PR #7 encounter.gd) should use offer_recruit and handle `{}`.
Related: [[json-int-float-ids]], [[random-event-selection]]
