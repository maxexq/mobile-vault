---
name: gear-sets-design
description: MV-689 equipment set system v1 (5 early sets x 4 pieces, 2/3/4-piece bonuses) + PixelLab icons, artifact Gear Sets v1, awaiting picks; not in game
metadata:
  type: project
---

2026-11-02 Parames: redesign equipment with set items (room work / damage / boss / ...), 2/3/4-piece set effects, early game + room for future, PixelLab item art. Plane MV-689 (Needs Decision).
- Page: https://claude.ai/artifact/48ycCAGrBUuEsjeKZpftmi ; source /mnt/project-files/designs/gear-sets/ (gen.py PixelLab, build.py picks PICKS + frame tiles, half.py 32->16 reduce, page/make.py + template.html).
- Design: keep 6 hero slots (Loot.HERO_SLOTS); each set = 4 pieces in 4 themed slots so 4+2 / 2+2+2 / 3+3 builds work; sets: tinker (armor/helmet/gadget/backpack, room output), hunter (weapon/helmet/gadget/boots, dmg/crit), titan (weapon/armor/helmet/gadget, boss), bulwark (armor/helmet/boots/backpack, tank), scav (weapon/gadget/boots/backpack, loot/expedition). Bonus same at every rarity; per-source drops 15% + pity 25; duplicates -> set parts, 30 crafts a missing piece. Van sets (4 van slots) + Tier II/III/biome/festival sets planned. Set emblem bottom-right on the Vault hatch tile.
- PixelLab lessons: generate-image-v2 at 16 or 24 px returns broken fragments; use 32. A grid style_image (4x4 icons) makes it draw 2x2 sprite sheets per take; use ONE 32 px icon as style_image (STYLE32 env, raw/bulwark_helmet_32/690_00.png). 10 gens = 64 takes. Tile recess is 16 px so 32 masters get auto-reduced (mushy) -> hand cleanup needed after picks.
Related: [[item-frame-redesign]], [[loot-economy-design]], [[pixellab-usage-report]]
- 2026-11-02 23:57 Parames: no 16 px reduction. Item tile = Vault hatch frame x2 (64 px, recess 32) + full 32 px icon, then scale the whole tile down only at display (mixed pixel size on purpose, like [[crew-scale-2-3]]). build.py tile64(). Artifact v2.
- 2026-11-03 00:05 Parames: frame needs more pixels -> native 64 px Vault hatch redraw (frame64.py, gen-v2 64x64 = 16 takes/10 gens, ref = approved frame x2, style = vault_v3 crop), 20 gens, options F1-F5 (frame64_page.py, recess holes filled dark). After pick: redraw tier ladder/+N/anims of build3.py at 64. Artifact v3.
- 2026-11-03 00:05 Parames PICKED F5 (frame64/801_01.png, grey steel). Tier ladder ported to 64 px in frame64/build64.py (out/: idle, same, grey, reveal0-5, tap, equip, empty; dogs 5x8 clamps on ring r21, pips 4x3 lamps left edge, badge Silkscreen 16). build.py tile64 now uses build64.F. Artifact v4; ladder awaiting OK, icon A/B/C picks pending. Replaces the 32 px hatch frame for item tiles if approved.
- 2026-11-03 00:11 Parames asked to redesign the in-game equip screen -> mock at native 360x640 (equip-screen/mock.py, out/): paper doll (helmet/armor/weapon left, gadget/backpack/boots right, Ren still x2 centre), set bonus panel with 4 lamps + 2/3/4 lines, stats strip with deltas, stash 5/row 64 tiles + slot filter, compare sheet warns when a set drops a tier, set emblem = bottom-right bolt as set-colour diamond. Current game: squad_panel _role_card gear row + loot_panel pick/detail. Artifact v5, awaiting feedback.
