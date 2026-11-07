---
name: item-frame-redesign
description: MV-687 item frame Vault hatch APPROVED + saved (designs/item-frames-v2/approved/README.md): PixelLab frame + code tier ladder, top-right +N badge, no level, Done; game impl not started
metadata:
  type: project
  modified: 2026-11-02T22:05:42.999Z
---

2026-11-02 Parames: "redesign กรอบไอเทมและอนิเมชัน ในเกม". Plane MV-687 (Needs Decision).
- Current live look = MV-473 (PR #106): riveted steel frame `ui_gear_slot_frame[_w]` + neon/aura rarity light masks `fx_gear_<rar>_<w>_<phase>` coloured by shaders/gear_fx.gdshader, GearFx node, all via `UIKit.gear_tile()` (squad/loot/dwellers/god panels), switches gear_slot_style + gear_slot_vfx. Tile widths 28/30/32/36/40.
- Preview: https://claude.ai/artifact/GwB7S2tB9f317TGN9gYaeK, source /mnt/project-files/designs/item-frames-v2/build.py (PIL, real atlas icons `ic_*`, 16 frames 8 fps). Options: A Scrap tag (hazard paint corner + 1-6 rank ticks), B Field crate (olive crate, light leaks from seams), C Geiger screen (CRT tint + scanline + LED), D Steel + lamp (keep MV-473 frame, caged lamp shows rarity). Shared events: drop reveal, tap, equip, empty. 0 PixelLab gens.
- 2026-11-02 round 2 (Parames asked for PixelLab): E vault hatch, F barricade, G hazard tape, H circuit board. generate-image-v2 at 32x32 returns 64 takes for 10 gens (good for UI frames); style_image = vault_v3 L2 crop, reference = ui_gear_slot_frame. Picks + rarity masks in designs/item-frames-v2/pl/build2.py (PICKS, masks()), raw takes pl/raw/<concept>/. ~50 gens (one 400 s timeout lost a job: gen.py now logs job ids to pl/jobs.txt, `gen.py finish` resumes).
- 2026-11-02 Parames PICKED E Vault hatch, asked for clearer tier differences beyond colour -> round 3 pl/build3.py (out3/): left-edge gauge lamps 1-6, locking dogs Rare 4 / Legendary 8, lit bolt caps Epic+, glass light Epic+, plate trim + embers Legendary, inner ring + cracks + broken arcs Mythic; greyscale check image. 0 gens. Awaiting OK to implement.
- 2026-11-02 Parames (with a reference image): +N enhance number = red pill badge on the TOP-RIGHT corner overlapping the frame; NO item level number on tiles any more; drop reveal = item lands, gauge lamps click on one per frame up to the tier, then frame wakes with a burst (build3.py reveal()). Artifact v4.
- 2026-11-02 22:48 Parames "เซฟไว้ใช้" = APPROVED. Saved to /mnt/project-files/designs/item-frames-v2/approved/ (frame png, build2/3.py, gen.py, anim/, README with the rules). Plane MV-687 Done. In-game implementation NOT started.
- Plan for implementation: new feature switch, GOD preview, autotest, old look as fallback.
Related: [[god-mode]], [[feature-flags-design]], [[ci-autotest]]
