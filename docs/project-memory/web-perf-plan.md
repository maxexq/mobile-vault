---
name: web-perf-plan
description: MV-562 web smoothness: analysis + PR #188 (perf_cache economy step cache, dpr_cap screen cap 2, per-frame trims), merged to staging 2026-10-30 (Awaiting Verify)
metadata:
  type: project
---

2026-10-28 analysis doc https://claude.ai/artifact/2oQvsPd8XQQe4Qnqq5E7S5 (Plane MV-562). 2026-10-29 Parames picked "fixes 1-3 in one PR" -> PR maxexq/mobile-vault#188 (branch mv-562-web-perf, base staging), MV-562 merged 2026-10-30 -> Awaiting Verify, playable artifact v56.
- `perf_cache` switch: during `Game._sim_world` (`_prod_begin/_prod_end`) prod_globals, room_workers index and room_span are frozen per step (like Synergy); Crew.room_mult looks up pair bonuses once. World half-step 4.6 -> 2.9 ms desktop on 24 rooms/35 crew, bit-identical results (autotest compares). Remaining cost: Crew.room_mult (~25 us/room), Synergy.room_mult, EngineBay.tick 0.5 ms, crew half untouched.
- `dpr_cap` switch + tune perf.dpr_cap 2 + Settings render_res saver/full: web_shell.html overrides window.devicePixelRatio (shell fitCanvas + Godot read it every frame; input maps by canvas/CSS size). Verified Playwright 3x: canvas 1236x2745 -> 824x1830, live switch works.
- Per-frame: hull_alert edge redraw only while pulsing, HUD regen label 4x/s, background speed 10x/s.
- Bench trick: throwaway tools/bench.gd (git-excluded) + `--bench` hook in main.gd; call `_process(1/60)` 60x per node for per-script cost; GDScript lambdas capture locals by value (use a dict holder for timers).
- Gotcha: `pkill -f <pattern>` inside a Bash call kills that call's own shell (exit 144).
- Templates tpz: SHA512-SUMS has mono line too; grep the exact name before `sha512sum -c`.
- Audio crossfade autotest ("both share the tail") flakes under heavy CPU load; passes alone.
Related: [[resources-changed-every-frame]], [[ci-autotest]], [[web-boot-shell]]
