---
name: online-anticheat-design
description: MV-174 online/anti-cheat: design F0-F4; Parames picked F0+F1, built in PR #59 (0006_anticheat.sql, server_seen cap, sim_sec, shadow flags)
metadata:
  type: project
---

2026-10-24 design page: https://claude.ai/artifact/QWiRy6Qd5hLx5MDq8DCAP5 (copy /mnt/project-files/designs/online-anticheat.html). Plane MV-174.
- Holes found on main 99d93ef: client owns all save data; rpc_save accepts any JSON; `saved_at` is client data (game.gd:129) so editing it back 4h + reload = free offline, repeatable; Cloud.now() falls back to phone clock before cloud answers; GOD `cheated` flag lives in the save (removable).
- Principle: protect by impact. Solo progress = plausibility flag only (never reject saves); ranked = server seed/window + replay verify; transferable rewards = server-owned tables.
- Phases: F0 player_state.last_seen + server away_sec, sticky server flags, save rate limit (~1-2 d). F1 rpc_save budget check vs server time using config/limits.json from Data + balance bot -> suspect_score (~3-5 d). F2 events table + join/submit RPC + decision log + GitHub Action headless Godot replay of top N (with MV-159 tickets 3-5, MV-50/51; risk float determinism wasm vs linux). F3 grants/wallet read-only RLS (before mail/trade/IAP, MV-67). F4 full server sim: not recommended.
- Rejected: client HMAC/save encryption, PCK encryption (custom templates break 4.7.2-stable rule), rejecting saves, banning on client flags.
**How to apply:** recommended F0+F1 first; open questions: shadow vs visible flag, unverified offline counts for ranked (recommend no). Related: [[backend-database-choice]], [[game-modes-design]], [[loot-economy-design]], [[error-spike-alerts]].

**2026-10-24 Parames picked F0 + F1 -> PR maxexq/mobile-vault#59 MERGED 2026-10-24 15:07 UTC, artifact v47 (main incl. #60), MV-174 Done: Parames ran 0006 and verified live 2026-10-24.**
- Client: `Game.offline_elapsed(saved_at, now, server_seen)` caps offline by `Cloud.server_seen` (= saves.updated_at from rpc_load, server_time after upload); switch `anticheat`. `Account.add_sim_time` -> `account.life.sim_sec`. Cloud handles `rate_limited` (stays dirty). GOD sys tab ANTI-CHEAT: time test + rate test (read-only, not cheated). Autotest `--only=anticheat`.
- SQL 0006 (Parames must run after merge): rpc_save now SECURITY DEFINER + 3 s rate limit + `anticheat_check` (player_state counters/suspect_score/reasons, sticky god_at), trigger on logs cat god -> god_log_at, `anticheat_limits` table (sim_sec 3960/h+900, km 40/h+5, kills 6000/h+500, gen 3/h+1), view `anticheat_suspects`. Never refuses saves for flags; first save = baseline only.
- SQL tests: tools/tests/anticheat_test.sql run by tools/test_error_spike.sh (local PostgreSQL 16 at /usr/lib/postgresql/16, runs in CI).
- web/index.pck conflicts on every merge to main: resolve by merging main, then re-export (never pick a side). Next steps if asked: F2 (events + leaderboard replay) with MV-159 tickets 3-5.
- cloud_config.json can be recovered from web/index.pck (find "anon_key" JSON block).
