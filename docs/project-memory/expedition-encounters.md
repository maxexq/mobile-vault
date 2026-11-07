---
name: expedition-encounters
description: Expedition special encounters (จุดพิเศษ) system, PR #7: Encounter autoload, hooks, defaults, and coordination notes
metadata:
  type: project
  modified: 2026-10-22T18:15:27.839Z
---

PR #7 (branch feat/expedition-encounters, opened 2026-10-22) adds rare mid-expedition choices. Autoload `Encounter` (scripts/autoload/encounter.gd, registered after Expedition): 6 encounters (survivor, wounded, cry, vault, floor, toxic), chance 14% + 1.5%/danger, state in Game.s.exp.enc, anti-repeat list Game.s.enc_recent (last 3). If unanswered when the team returns, the last ("leave") choice is used. UI: scripts/ui/encounter_popup.gd, HUD chip "สั่งการ", radio button in the expedition panel. Art: tools/art/encounters.py → assets/events/enc_*.png.

**Why:** Parames asked for rare special events during expeditions (meet survivors, risky loot that can injure explorers).
**How to apply:** the "stranger inspection" thread is adding `Game.offer_recruit(source)` (returns {} when the candidate is queued for inspection). Whichever of the two PRs merges second must switch the Game.recruit_random() call in Encounter.apply() to offer_recruit("exp_special") and skip the infection step on {}. The artifact build shared by all threads must include every open PR's work (merge them locally before exporting), or one thread's publish wipes another's. Related: [[json-int-float-ids]], [[godot-download-approval]]
