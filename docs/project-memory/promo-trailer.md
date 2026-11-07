---
name: promo-trailer
description: 45s promo trailer made 2026-10-23 from real gameplay (Godot Movie Maker + ffmpeg); files, how to re-make it, gotchas
metadata:
  type: project
  modified: 2026-10-23T10:30:31.022Z
---

2026-10-23: Prompt doc (3 variants) https://claude.ai/artifact/1TGpQYeuyuQk5ip7TfFP8Z. Parames asked for the 45s trailer after game modes (PR #21, feat/game-modes); delivered /mnt/project-files/videos/mobile_vault_trailer_45s.mp4 (1080p30, H.264+AAC, 18.8 MB) built from feat/game-modes 4a2e6f0.
Sources in /mnt/project-files/videos/trailer-src/: trailer.gd (scripted shots, prints `[trailer] seg name from to` frame ranges; `--part=combat` re-shoots only raid/boss), music.py (numpy chiptune + SFX synced to the edit), cards.py (TH/EN caption PNGs, Chakra Petch + Silkscreen, PIL has raqm so Thai shapes OK), edit.py (EDL -> ffmpeg).
NOT committed to the repo: needs local hooks: main.gd `--trailer` branch, and "--trailer" added to the test-arg lists in cloud.gd + features.gd.
Gotchas: Movie Maker records at the window override size, `--resolution` is ignored -> put override.cfg with window_width/height_override 1920x1080. Expedition/feed use wall-clock time (runs ~10x fast at ~3 fps render) -> drive Game.s.exp.start from movie time. Combat lane is tiny at the bottom in the default camera -> lock camera zoom 2 on the truck's rear; debug_spawn clears the queue, so put boss + mobs in ONE call. Don't `pkill -f Godot...` from a shell whose command line contains that string (kills itself).
Related: [[game-modes-design]], [[god-mode]].
