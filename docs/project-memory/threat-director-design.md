---
name: threat-director-design
description: v4.5 threat pacing (PR #15): Threat autoload replaces non-stop waves with threat meter + raid cycle; phase 1 built, phases 2-3 pending
metadata:
  type: project
  modified: 2026-10-22T20:29:59.680Z
---

Parames asked (2026-10-22) for a more realistic idle loop without enemies attacking all the time; approved phase 1 ("ทำได้เลย"). Design page (Thai): https://claude.ai/artifact/W653znLDBsjaAFxC7J6TPa (copy /mnt/project-files/designs/threat-director.html).

Merged to main 2026-10-22 as PR #15 (branch feat/threat-pacing): autoload `Threat` (scripts/autoload/threat.gd, after Combat). Combat.tick calls Threat.tick(dt) for wave starts; Combat.warlord_due() factored out. Cycle quiet -> warning 8s -> raid 3-5 waves -> salvage 10s. Reward bonus = TARGET_PAY(0.75) / measured fight share (s.combat.fight_share, tau 900s), clamped 1.2-4.0 -> keeps hourly pay ~0.9x classic for any squad strength (a fixed multiplier swung 0.54-1.48x across runs). Offline = raid_kpm x share x bonus. Settings key "pacing" threat|classic. Save: combat.threat / raid_kpm / fight_share.
Tests: autotest `_threat_test()` sims 60 min classic vs threat, compares combat scrap only (kill+salvage+scavenge parts) because gear auto-salvage depends on stash fullness/order. Legacy combat screenshots call Threat.force_raid(). 275 PASS.
Phase 2 (not built): warning choices flee/go dark/fight, 4 postures (stealth/normal/fortify/bait), raid types by cause. Phase 3: tie to [[modular-chassis-design]] (watchtower, sound insulation) and [[strategic-depth-plan]] A3.
**How to apply:** new noisy/lit rooms go in Threat.NOISE / LIGHT; any test that needs enemies must call Threat.force_raid() (or set pacing classic). Related: [[god-mode]].
