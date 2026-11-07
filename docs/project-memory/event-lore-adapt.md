---
name: event-lore-adapt
description: MV-635 proposal to adapt all events to Dr. Ren lore (Claude Doc with per-row picks), awaiting Parames picks
metadata:
  type: project
  modified: 2026-10-30T13:36:48.781Z
---

2026-10-30 (Plane MV-635, Needs Decision): Parames asked to adapt every event to the new Dr. Ren lore ([[dr-ren-lore]], option A "Ren wrote TRIAGE-9" locked; age/timeline, Ren every generation / can die, REN-T9 Herald, ending still open).
Doc: https://claude.ai/artifact/7UcLE6UNDNM3kqFXHD3LWh (Thai, tables with a "เลือก" dropdown รับ/ปรับก่อน/ไม่เอา per row).
- Inventory (staging fb50071): 21 road events in Data.EVENTS, 6 Encounter encounters, 5 inspection kinds, 6 warlords + 9 wave bosses (combat.gd), 3 prestige stories (meta.gd STORIES), 7 event-unlocked logbook entries. Festivals not in code.
- Biggest lore conflicts: rogue_bot (OVERSEER shoots an ambulance despite rule 4) and meta.gd prestige stories ("ศูนย์บัญชาการ" + rescue helicopter). "รถบ้าน" appears 4x in data.gd/encounter.gd.
- Plan: phase 1 S text pass (one PR, no balance), phase 2 M new choices behind a feature flag (rogue_bot transponder, signal per Act, cultists Ren reveal, prestige rewrite), phase 3 one-shot "story event queue" ahead of the shuffle bag + 6 new events (drone_flyby, isha_memory, registered_convoy, mirror_glint, herald_omen, cryo_pod; needs 6 new event images).
**How to apply:** read the doc's picks before implementing; road events still go through [[random-event-selection]] bag, story events must not.
