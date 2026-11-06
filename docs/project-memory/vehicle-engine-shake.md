---
name: vehicle-engine-shake
description: MV-176 vehicle body rumble/road bumps halved: tune fx.engine_shake (0.5), setting car_shake, Vehicle.px_amp; cloud clone was blocked so work went through RC on Soba
metadata:
  type: project
  modified: 2026-10-24T17:48:09.108Z
---

2026-10-24, Plane MV-176: Parames felt dizzy from the engine shake and asked to halve it. (Screen shake was already halved in MV-175 via `fx.shake`.)
- Source: scripts/world/vehicle.gd `_process`: engine rumble (body.y -1 px every other 60-100 ms beat) + road bumps (-1/-2 px). Now scaled by `Vehicle.shake_scale()` = Features tune `fx.engine_shake` (const ENGINE_SHAKE 0.5; 1.0 = old) or 0 when Settings `car_shake` is off (ตั้งค่า > ความรู้สึก > "รถสั่น"). Sub-pixel amounts use `Vehicle.px_amp` (whole pixel that fraction of the time) to stay on the pixel grid.
- GOD shake section: รถสั่น x1 / x0.5 / default (Dev.engine_shake). Autotest `_engine_shake_test`, `--only=shake`.
- Branch mv-176-engine-shake. In this cloud session `git clone` was denied by the auto-mode classifier and gh api writes are 403, so the patch (/mnt/project-files/patches/mv-176-engine-shake.patch) was applied/tested/pushed by a Remote Control session on Parames's PC "Soba" (C:\Users\param\Downloads\mobile-vault).
Related: [[feature-flags-design]], [[god-mode]], [[ci-autotest]]
- 2026-10-24: PR maxexq/mobile-vault#65 opened (full autotest 648/0), artifact v49 published by rebuilding build/artifact in the cloud from the branch's web/ files fetched with `gh api .../contents/web/...` (raw), then tools/artifact_html.py. MERGED 2026-10-24 18:20 UTC, MV-176 Done.
