---
name: game-modes-design
description: Game modes: design page + phase 1 built in PR #21 (Modes autoload, Features "mode" layer, picker, peaceful toll/salvage); phases 2-4 pending
metadata:
  type: project
  modified: 2026-10-23T09:32:27.377Z
---

2026-10-23 design page (Thai): https://claude.ai/artifact/E6psTiH3QsaiejYK8foN2C (copy /mnt/project-files/designs/game-modes.html). Parames picked phase 1 (offline modes).

MERGED 2026-10-23 as PR maxexq/mobile-vault#21 (branch feat/game-modes), README §4m, artifact v31 updated:
- Autoload `Modes` (scripts/autoload/modes.gd, after Meta). `Game.s.mode = {id, diff, mut, started_at}`; migrated to standard/normal; Meta.next_generation copies it. `Modes.mul(key)` multipliers (enemy_hp, enemy_dmg, threat, eat, offline, fuel_gain, hero_dmg, hero_hp), `legacy_mult()`, `ranked()` (ranked mode + not stats.cheated), `make()` cleans choices.
- Features LAYERS = default, build, remote, **mode**, dev (`Features.set_mode_layer`). Switch `modes` gates the picker.
- Peaceful: raids off, warlord_due false, squad salvage = scrap cap / 30 per min (needed: first sim deadlocked at checkpoint with no kill scrap), toll 45% scrap cap auto-paid when vault level ok. Balance: desert 51 min vs standard 39.
- TitleScreen: NEW RUN → `_new_run()` → picker (`open_picker/pick/close_picker`); `_go(true)` still starts directly (autotest relies on it). `Modes.pending` → `Game.new_game()` via `take_pending()`.
- GOD sys tab: Dev.mode_set(id, diff, toggle_mut), Dev.mode_toll_test. Autotest `_modes_test` (23 checks). Balance `--mode=peaceful,hard,fuel_scarce`.
- Flaky pre-existing autotests seen: "god: invincible refills hull", "chatter: no line said twice in a row".
**How to apply:** next phases: accounts + leaderboards (read Modes.ranked), seedable RNG for Sprint/weekly, save slots (migration 0002) before Hardcore/Seasons. Related: [[feature-flags-design]], [[backend-database-choice]], [[god-mode]].

**2026-10-24 direction change:** Parames chose Persistent + mode events (MV-114): picker at NEW RUN will be removed, modes become temporary events feeding the persistent account; phases 2-4 must be re-planned. Design ticket MV-159. See [[idea-backlog-2026-10-24]].
