---
name: icons-v2
description: MV-694 all 92 ic_* icons redrawn at 32 px (PixelLab) + moods neutral/stressed/broken, APPROVED + saved, PR #191 MERGED to staging 2026-11-04 (CI green), web export pending
metadata:
  type: project
---
2026-11-03 Parames: "ปรับ icons ทั้งหมดในเกม ขอตัวอย่างก่อน". Plane MV-694 (Needs Decision, work item id 3dbf502a-d5de-4b32-87fa-5075f605ca26).
- Current: 92 `ic_*` icons in assets/atlas (tools/generate_pixel_art.py), all 16x16, used via Atlas.icon(name) / UIKit.icon_rect(name, px) (mostly px 16, some 32/12/10) and "icon" keys in data.
- Gear/item icons are NOT part of this (gear sets thread MV-689 owns them, Vault hatch F5 64 px tile + 32 px icon).
- Proposed v2 style: 32 px salvage-object icons (dented can = food, car battery = power, jerry can = fuel), 1 px outline, warm top rim, colour keeps meaning; style_image = gear icon raw/bulwark_helmet_32/690_00.png so UI matches gear.
- Source /mnt/project-files/designs/icons-v2/: gen.py (generate-image-v2 32x32, 10 gens -> 64 takes per icon, reference = old icon x2), build.py PICKS/ALTS, page/make.py + template.html. 10 samples = 100 gens.
- Page: https://claude.ai/artifact/FU8fyA1AES9gT7oi8BUVCf
- Open question: icons shown at 16 px in many places; 32 px masters need bigger slots or display downscale (mixed pixel like [[crew-scale-2-3]]).
Related: [[gear-sets-design]], [[pixellab-usage-report]]
- 2026-11-03 00:48 Parames APPROVED style: "ปรับทั้งหมด" + add moods เครียด (stressed) / แตกสลาย (broken). Gear ic_* icons included (base items still use them).
- All 94 picks (picks_all.json; laser redone seed 695) -> repo tools/art/icons_v2/<name>.png -> atlas ic2_<name> (quantized, atlas stays 2048x2816). Asset log group icons-v2_.
- PR #191 (branch mv-694-icons-v2, base staging): switch icons_v2 (default on), scripts/ui/icon_tex.gd IconTex reports 16x16 and draws 32 px (canvas_items stretch keeps detail), Atlas.icon/icon_v1/mood_icon(happy, stage) (happy>=50, sad>=morale.depressed, stressed>=morale.broken, broken; Depressed->stressed, Broken->broken), HUD chip + dwellers_panel MoodIcon, Dev.icons_v2 + GOD Icons buttons, autotest --only=icons_v2.
- Godot download was denied by the cloud auto-mode classifier (2026-11-03) despite [[godot-download-approval]]; Soba offline -> web export not in PR yet.
- PixelLab total: 10 samples (100) + 84 (840) + laser redo (10) = 950 gens.
- 2026-11-03 06:58 Parames added neutral mood (หน้าเฉย): pick raw/neutral/694_03, mood_icon happy >= tune mood.happy_icon 70, neutral >= 50; V2_ONLY neutral->happy. Commit ff4405b. Total 960 gens.
- 2026-11-03 08:37 Parames APPROVED (เซฟไว้ใช้): saved to designs/icons-v2/approved/ (icons/, picks_all.json, gen/review/export scripts, README rules, sheet_x2.png). Plane MV-694 Done. See [[icons-v2-approved]].
- 2026-11-04 Parames: str icon = ONE flexed arm only. Gen-v2 with the old fist ref kept drawing a two-arm loop (seed 696, now raw/str_696/); NOREF=1 gen.py str 697 worked, pick 697_05. Commit a746149 on PR #191. 20 gens.
