---
name: roof-rest-deck
description: Roof rest deck (ดาดฟ้าพักทีมป้องกัน) mod + reserve defender, PR #14 (2026-10-22): state, hooks, gotchas
metadata:
  type: project
  modified: 2026-10-22T20:23:06.213Z
---

Parames picked "reserve rests on the deck" (2026-10-22). PR maxexq/mobile-vault#14, branch feat/roof-deck.
- Mod `roof_deck` (ext, 3 lv) in Mods.MODS; art `mod_roof_deck_1..3` 76x60 at Vehicle.ROOF_DECK_X=182, planks 26px above roof (`Vehicle.deck_lift()`); roof crew stands on it (CombatView.DECK_HERO_X).
- Reserve = `Game.s.deck` (dweller id). `Game.deck_dweller()` self-validates (room<0, not in squad, not away) so no clean-up hooks are needed; `Game.set_deck(did)`, `Game.is_deck(d)`; idle_dwellers excludes them.
- Combat: tag-in for first fallen hero per wave (`Combat.sub`, `sub_out`, `slot_did(i)`, signal `tagged_in`), restored by `_end_subs()` on wave clear/wipe/reset/squad change. Wipe is held while a reserve can still come down.
- Gotchas: after regenerating art run `godot --headless --path . --import` or the game uses the stale atlas.png with new atlas.json regions; autotest can find squad slots empty (earlier checks send people away), so set up the squad inside your own test.

- Autotest tag-in checks hold the wave open with `_deck_hold_wave()` (debug_spawn of one 999 s spawn); a real wave can be cleared by the turret/threat pacing before the 6 s tag delay (flake fixed in PR #17). `_clear_enemies()` ends subs.

**How to apply:** new squad/defence features must keep `Combat.heroes[i]` either {} or a full hero dict (never add keys to an empty one). Related: [[modular-chassis-design]], [[json-int-float-ids]], [[construction-system-v43]].
