---
name: survivor-spot-ref
description: RULE event survivor APPROVED = lounge_singer version; it is the reference for any crew character standing at the survivor spot (back view only, own wave)
metadata:
  type: feedback
---

2026-10-30 17:32 Parames (MV-642 Done): keep the Singer survivor and use it as the ref for other characters who stand there; "อยากให้เห็นแค่ด้านหลัง และท่าโบกมือตามคาแรคเตอร์ของตัวเอง".
**Why:** players should only see the back of whoever waits on the roadside, and each character waves in their own way.
**How to apply:** /mnt/project-files/designs/event-art-survivor/approved/README.md: char_at_spot.py <cast_name> "<identity>" "<wave>" (gen-v2 48, refs = cast still + pose_ref_singer_back.png), pick one with the back to camera facing left (mirror if it faces right), compose.py (feet row 76 x 142, shadow, warm grade on bg_clean.png), animate wave + relief (wave_singer.py pattern), render (anim_singer.py pattern). ~14 gens per character. Recipe history in [[event-vehicle-facing]]; page [[event-samples-page]].
