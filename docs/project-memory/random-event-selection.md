---
name: random-event-selection
description: Road events use a per-biome shuffle bag + no-repeat-last-3 stored in the save (PR #6, 2026-10-22)
metadata:
  type: project
  modified: 2026-10-22T18:09:09.534Z
---

Since PR #6 (branch feat/event-variety), `Game.next_event_id()` deals road events from a shuffled bag per biome (each once per round), blocks the last `EVENT_NO_REPEAT`=3, and keeps `s.ev_bag`, `s.ev_bag_biome`, `s.ev_recent` in the save. `Lore.pick_line` avoids the last 12 chatter lines. Autotest `_event_variety_test` covers it (136 checks total).

**Why:** Parames reported events repeating / feeling patterned.
**How to apply:** new events just go in `Data.BIOMES[*].events`; the expedition special-events thread should add its own picker rather than reuse this bag. Web artifact update = gzip `web/index.pck` to `pack.wasm` and bump sizes in the artifact page; engine.wasm unchanged for the same template. Related: [[json-int-float-ids]], [[festival-minigame-plan]]
