---
name: gear-sets-ingame
description: MV-767 gear sets v1 + F5 64 px Vault hatch item frame in game (switches gear_sets, gear_frame64), branch mv-767-gear-sets-frames
metadata:
  type: project
---
2026-11-10 Parames "เอา set item ใหม่ และ frames ใหม่เข้าเกม" -> Plane MV-767, branch mv-767-gear-sets-frames (PR into staging).
- Icons: take A of every piece (designs/gear-sets/build.py PICKS) used because the A/B/C picks were never made; swap by editing PICKS take order + `python3 tools/gear64_import.py`.
- F5 frame tier ladder (designs/gear-sets/frame64/build64.py) baked into assets/gear64/frames.png (96 px cells, 16 frames, rows 0-5 rarity, row 6 empty); icon + badge drawn by the game (GearFrame64 + UIKit.gear_tile64). build64 needs repo symlinked at /home/user/maxexq/mobile-vault (font path).
- Logic: scripts/systems/gear_sets.gd (class GearSets, not an autoload), set bases in Loot.BASES "set_<set>_<slot>"; combat specials in combat.gd "MV-767 gear set specials". Set parts 3+2*rar per salvage, craft 30.
- Not done yet: drop reveal / equip animations of the frame, full equip-screen redesign mock (MV-689 v5) still awaiting Parames.
- Cloud: Godot download was blocked by the auto-mode classifier 2026-11-10; tests via CI, web export via RC on Soba.
Related: [[gear-sets-design]], [[item-frame-redesign]], [[icons-v2-approved]]
