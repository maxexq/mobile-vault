---
name: exp-scene-v2
description: MV-758 new expedition scene in game (switch exp_scene_v2): 7 approved interiors + ambience + v3 crew expedition clips (torchwalk/gunwalk/search/wall/carrywalk/shoot)
metadata:
  type: project
---

2026-11-10 Parames: "เพิ่ม Expedition scene ใหม่เข้าไปในเกม" + "ใช้ท่า animation ใหม่ของตัวละครตอนสำรวจ (ไฟฉาย ขนของ หาของ ค้นของ เดินสำรวจ ยิงปืน เดินถือปืน)". Plane MV-758, branch mv-758-expedition-scene-v2. 0 PixelLab gens.
- `ExpeditionFeedV2` (scripts/ui/expedition_feed_v2.gd) extends ExpeditionFeed: same beats/plan/log, beat 16 s, squad walks hotspot groups (stands within 110 px), members 28 px apart, crew full pixel size, feet y 153, view 176 px tall.
- Assets: `tools/exp_scene_import.py` -> assets/exp/v2/ (strip, ambience overlay atlas cut by recursive XY cut, scenes.json). Generic kinds re-render effects with designs/exp-interior/amb.py (exact pixels); whole-scene "particles" (ruins ash, mine snow) are drawn in code, they made the atlas > 4096. Hospital uses its GIF.
- Clips: `tools/v3_import.py --crew-only` adds gunwalk/torchwalk/search/wall to every v3 crew sheet (rows 9-12); torchwalk has "lens" [x,y] per frame (beam origin rule MV-686).
- Clip rules: hotspot rect bottom < 130 -> wall (back view); force_door/mine_ore/salvage -> construct; hack_terminal/take_fuel/collect_sample -> work; else search. Dark kinds: even members torchwalk, odd gunwalk.
- Monsters: only BIOME_MOBS_V2 ids with EnemiesV2 art.
- Web export: cloud container can't rebuild cloud_config.json (reading it from web/index.pck is blocked as credential access), so the committed web/ was not re-exported; preview artifact built without cloud save.
Related: [[exp-interior-redraw]], [[expedition-25d]], [[enemies-v2-per-biome]], [[landmarks-v2]].
