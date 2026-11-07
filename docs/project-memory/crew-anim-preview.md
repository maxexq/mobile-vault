---
name: crew-anim-preview
description: MV-590 GIF preview of all approved staging crew animations (179 GIFs), artifact + project files copy, render script recipe
metadata:
  type: project
  modified: 2026-10-29T00:06:42.185Z
---

2026-10-29 (MV-590, Done): Parames asked for GIF previews of every confirmed crew animation.
- Source = staging @ b332622 (MV-585, PR #167/#171): docs/art/crew-style-reference/approved/animations/<clip> (medic, 11 clips, fps in manifest `animations`) + approved/cast_animations/<name>/<clip> (24 cast x 7 clips, fps in manifest `cast_animations.fps`).
- Output: artifact "Crew Animation Reel" https://claude.ai/artifact/S2pzmW5t5wYBfL19U1nqiB; GIFs in /mnt/project-files/designs/crew-anim-preview/<char>/<clip>.gif + index.json.
- Recipe: pad to 64x64 dark tile (34,32,30), feet aligned to row 54 (lowest opaque row of the whole clip), centred, nearest 4x, one-shot clips hold last frame 1.2 s. Verified pixel-exact vs source frames.
**How to apply:** when new clips/characters land on staging, re-render the same way and republish the same artifact URL. Related: [[crew-roster-20]], [[pixellab-api]].
- 2026-10-29 MV-591 / PR #173 (branch mv-591-fortune-teller-work -> staging): fortune_teller work clip regenerated (v3 east seed 2, 1 gen each x3 seeds), Parames picked B. Preview sheet cells patched in place: cast-animations.png grid x=150+col*122, y=16+row*122, sprite at +4,+8 scale 2. Reel v2 already shows the new clip.
- 2026-10-29 MV-592 / PR #174 (mv-592-scientist-work -> staging): scientist work rebuilt with custom_start_frame = work/0 with flask erased (frame 0 empty hands), seed 1 (Parames picked A, the hoe-like swing). Scientist is row 18 in cast-animations.png. #173 and #174 both edit that binary PNG: the second to merge needs base merge + cells redrawn. Gotcha: render.py renders from whatever branch is checked out, so restore other unmerged clips' GIFs before republishing the reel.
- 2026-10-29 16:11 both merged into staging (PR #173, #174); MV-591 + MV-592 Done. Gotcha: after a merge the branch is auto-deleted; a later `git push -u` recreates it (happened once, stray remote branch mv-592-scientist-work left for Parames to delete). Check PR state before pushing.
