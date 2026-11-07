---
name: pixel-32bit-upgrade
description: Plan to move art from 16-bit to "32-bit" true pixel at 1.5x density (rooms 96x78, chars 21x30); pending user approval of style-rule change
metadata:
  type: project
  modified: 2026-10-22T22:29:14.424Z
---

2026-10-22: User asked how to reach "32-bit true pixel art". Plan page: designs/pixel-32bit-plan.html (artifact https://claude.ai/artifact/AbW9TWQAQt7AHdN45cjKdd), mockup script designs/medical_room_32bit_mock.py.

Recommendation: 1.5x art density (room 64x52 -> 96x78, dweller 14x20 -> 21x30) because typical phone has S=3 and world_scale=2 then gives identical on-screen truck size; 2x density gives non-integer 1.5. UI stays at current scale. Palette v2 = 7-step hue-shifted ramps; generator gets material map + dithered light pass (shift ramp index). Hybrid production: generator for rooms/truck/bg/icons, hand-drawn characters (Aseprite/LibreSprite/Pixelorama — ask before download).

Engine notes: ~129 hardcoded pixel Vector2 coords in scripts (Vehicle.ROOM_SIZE, DECK, TURRET_POS...) must be converted to new units, not sprite-scaled (odd*1.5 = half pixel). Split atlas into multiple 2048 pages, keep lossless.

Phases: 0 style guide, 1 light/palette at current res, 2 ART_SCALE + coords + pilot, 3 convert all behind a flag (no mixed densities), 4 optional live lights.

**Why:** Project rule still says 16-bit; nothing changed until user approves.
**How to apply:** Don't start art-density work without approval; if approved, update the Art rule in CLAUDE.md and INDEX.md. Related: [[god-mode]], [[engine-bay-design]].

ComfyUI (user's PC "Soba", via Remote Control, 2026-10-23): F:\AI\ComfyUI_windows_portable, RTX 4070 Ti SUPER 16GB, only Flux.2 Klein 4B + qwen_3_4b + flux2-vae + pixel-art-lora-klein4b (4 steps, cfg 1, so negative prompt ignored). No ControlNet/IPAdapter; ReferenceLatent node usable for style ref. Side-view prompt ("flat side-scrolling cross-section, orthographic") needed; seed 2024 best pilot. Post-process with /mnt/project-files/tools/pixelize.py (grid mode + fixed palette).
