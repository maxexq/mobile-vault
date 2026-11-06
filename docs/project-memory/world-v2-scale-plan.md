---
name: world-v2-scale-plan
description: MV-602 plan to move the in-game world to v2 room scale (144x96 rooms, 38 px crew); phase 1 slice pending approval
metadata:
  type: project
  modified: 2026-10-29T14:41:35.871Z
---

2026-10-29 Parames picked "scale the whole world" (option 1) for v2 rooms. Plan artifact https://claude.ai/artifact/7L9NzgAirLTPCcHkpeJYAX (source /mnt/project-files/designs/world-v2-plan.html), Plane MV-602 (Needs Decision).
- Finding: portrait_fit (main.gd _fit_ws) picks a lower whole world_scale for a bigger vehicle, so on phones rooms keep ~same screen size but ~2x detail. Budget: main body <= 520 art px wide (432 rooms + 88) so 1080 px phones stay at 2x; landscape needs a new height fit.
- v2 is 2.25x wide / 1.85x tall, not a clean 2x: all vehicle.gd position consts (COLS, ROOM_SIZE, FLOOR_H, ROW0, MAIN_W, SIZE, ROAD_Y...) go into a Layout v1/v2 picked by switch `world_v2`.
- Art status: kitchen, quarters(living), medical(infirmary) complete; hydroponics grow A/B lack x3 + A/B pick; missing water, armory, science, radio, refinery, workshop, engine bay, saloon, construct/empty/locked, 6 vehicle shells. ~140 PixelLab gens per full room set.
- Phase 1 slice proposed: van only, code-drawn shell, kitchen v2 + hotspots, 5 crew already in branch mv-595-room-v2-closeup (room_v2_view.gd), old rooms shown unscaled on a "refit" panel (no mixels), 0 credits.
Related: [[room-redesign-preview]], [[room-hotspots]], [[web-perf-plan]], [[feature-flags-design]].
