---
name: game-name-apocarlypse
description: Game renamed to "Apocarlypse: Mobile Vault" (PR #22, 2026-10-23); where the title lives, what kept the old name, name-clash findings
metadata:
  type: project
  modified: 2026-10-23T14:25:45.826Z
---

2026-10-23 Parames renamed the game to **Apocarlypse: Mobile Vault** (car + apocalypse pun). PR maxexq/mobile-vault#22 (branch feat/rename-apocarlypse), Plane MV-84.
- Title source: `BuildInfo.GAME_NAME` (scripts/build_info.gd), `project.godot` config/name, Web preset head_include og/twitter tags, `UIKit.logo(caption)` (pixel logo texture, below), used on title screen + Settings > About. og-image drawn by tools/og_image.py with the same logo.
- Kept "Mobile Vault": the vehicle itself in-game ("upgrade Mobile Vault Lv.X"), repo, save/localStorage keys, Supabase. Production domain moved to apocarlypse-mobile-vault.vercel.app (see [[og-share-preview]]).
- 2026-10-23 logo picked by Parames (AI art) -> assets/ui/logo.png 192x60 true pixel (tools/art/pixelize.py --size 192x60 --keep-lines 0.2, subtitle redrawn in Silkscreen 8). UIKit.logo(caption) = that TextureRect 1:1. Sources in /mnt/project-files/designs/logo/.
- #22 merged 2026-10-23 15:06 before its web re-export; the cloud thread re-exported web/ with cloud_config.json in PR #24 (needs merge for production). Lesson: a container without cloud_config.json keeps main's web/ and hands the export to a thread that has it. Playable artifact https://claude.ai/artifact/XZt7RMvDG7TFXjdH5MYmAU (v36, boot card shows logo.png). Logo prompt doc https://claude.ai/artifact/3mqnM2ALLawks9ExeGU7x3; 
- Name check: itch.io dev account "ApoCarLypse" (small action games), an old iOS app "Apocarlypse" id1500138489, German drive-in festival "apoCARlypse" 2020, Carmageddon 2 subtitle "Carpocalypse Now". No trademark search done.
Related: [[og-share-preview]], [[settings-and-version]], [[promo-trailer]]
