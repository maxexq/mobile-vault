---
name: vault-room-v3
description: MV-638 secure supply vault (คลังเสบียงนิรภัย) v3 L1-L3 per Room guide v3, Claude picked all, anim + hotspots fmt 2 (room "vault"), APPROVED + saved (vault_v3/approved/), Done; files vault_v3/, page Secure Supply Vault v3
metadata:
  type: project
---

2026-10-30 Parames: "ทำคลังเสบียงนิรภัย L1-L3 ตาม Guide v3 เลือกห้องเองได้เลย". From [[new-rooms-10-ideas]] #8. Plane MV-638 Done. 14:23 Parames "เซฟ" = APPROVED, saved to vault_v3/approved/ (id 980599cf-1d0d-4c9a-9799-77e4df766e66).
- Zones left -> right: water drums + fuel jerrycans chained (L3 locked tank cabinet + gauge) | locked chain-link cage + strongbox (L2 mesh cage + combination safe, L3 round vault door + keypad) with ration ledger desk in front (L3 counter + amber terminal) | food shelves.
- Folder /mnt/project-files/designs/room-redesign-preview/vault_v3/: gen_vault3.py A <seed> (power pattern), edit_vault3.py L2|L3 <seed>, anim_vault3.py (retired_teacher keeps ledger at desk, truck_driver unlocks safe / L3 keypad + vault wheel spin, restocks shelves; power-out: vault stays locked, keypad red blink, soldier guards, teacher writes by candle; emergency_light; crew_blend), hotspots_vault3.py (NEW actions open_vault, check_ledger -> add to tools/hotspots.py ACTIONS in repo PR; L3 terminal + gauge needs_power, vault door not), page_vault_v3.html, plane_mv.py.
- Picks: L1 out/vault3_A_11_0, L2 vault3_L2_s1_0, L3 vault3_L3_s2_0 (s1 lost one-point side walls); gamma 0.93/0.88 -> luma 40/42/43. final/vault_L{1,2,3}.png + hotspots.json.
- ~60 gens (generate-image-v2 2x, edit-images-v2 4x); balance 3849 -> 3719 in window (other room threads spending concurrently).
- Page https://claude.ai/artifact/CHbG6DV9YPgVpX1RdB7QMb (scratchpad vault_site/), card on index v54.
**How to apply:** Not in game yet (waits for [[world-v2-scale-plan]]). Related: [[room-guide-v3]], [[room-hotspots]], [[room-v3-emergency-light]], [[crew-room-blend]].
