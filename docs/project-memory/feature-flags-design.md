---
name: feature-flags-design
description: Features autoload (PR #20): layered switches/event windows/tune + remote web/features.json; how to gate a new feature
metadata:
  type: project
  modified: 2026-10-23T08:27:44.468Z
---

2026-10-23 Parames picked phases 1+2 of the design doc https://claude.ai/artifact/3v3e53yzthVwLpaaBrK5Ea. MERGED to main 2026-10-23 as PR maxexq/mobile-vault#20 (branch feat/feature-flags, on top of #18), README §4l.
- Autoload `Features` (scripts/autoload/features.gd, right after Save). Layers: res://config/features.json → config/features.<demo|staging>.json (OS.has_feature) → remote web/features.json (same folder as the page, web only, cached in localStorage `mobile_vault_features_v1`, refused by min_game/max_game) → tester overrides (GOD tab "ฟีเจอร์", user://dev.cfg [features]; URL ?ff= session only). Dev.lock() clears overrides.
- API: Features.on(key), num(key, CONST) clamped by Features.TUNE, event_pool(biome, base), event_weight, event_ok, source(block,key), apply_remote(dict), parse_overrides(text), now_override for tests.
- Switches: road_events, raids (warlord still blocks checkpoint), encounters, strangers, expeditions, roof_deck, large_rooms, tutorial, cloud_save (boot-time). Events: on/weight/biomes ["*"]/from/to. Time.get_unix_time_from_datetime_string IGNORES timezone suffixes on 4.7.2, so parse_time applies tz_hours (default 7).
- Autotest `_features_test` (needs a started game: cloud test leaves the title screen up). Autotest must run under xvfb-run with --rendering-driver opengl3; --headless hangs on frame_post_draw.
- Next small follow-up: add an `engine_bay` switch (EngineBay from #18 is not gated yet).
**How to apply:** every new system adds a key to Features.FEATURES + config/features.json and guards its entry point with Features.on(); new tunable numbers go in TUNE. Festival events = Data.EVENTS entries with no biome, opened by a date window ([[festival-minigame-plan]]). Related: [[god-mode]], [[random-event-selection]].
