---
name: mods-v3-only
description: MV-774 garage hides exterior mods with no v3 art on the current world v2 vehicle (switch mods_v3_only, Mods.V3_ART), branch mv-774-mods-v3-only
metadata:
  type: project
---
2026-11-11 Parames: "mods ของรถอันไหนที่ยังไม่ทำ v3? ให้ปิดไปก่อน". Plane MV-774. Branch mv-774-mods-v3-only (from staging 1d244cb).
- Mods.V3_ART per tier (van=ambulance, bus=Decker, rig=road train, bastion=[]), Mods.has_v3_art(id) inside Mods.enabled; only ext mods, only when Vehicle.v2_wanted(). Installed levels keep effect (Mods.val unchanged).
- Hidden: ambulance roof_deck/tracks/solar_covers/rain_catcher; Decker roof_deck/tracks/rain_catcher/suspension/offroad_wheels; road train roof_deck/tracks/rain_catcher. Heater is an internal mod (not hidden; flue drawn on Decker + road train only).
- Squad tab hides the roof deck reserve card while the deck can't be built. GOD row "มอดที่ยังไม่มีภาพ v3" (Dev.mods_v3_only). Autotest --only=mods_v3_only.
- When a mod's art lands in game, add its id to Mods.V3_ART (the test checks each listed id has art).
- Preview artifact (cloud-off) https://claude.ai/artifact/CsuMfUoDRKePz2kVrEJ9rD; main playable artifact untouched.
Related: [[ambulance-mods-ingame]], [[vehicle-2floor]], [[road-train-mods]], [[feature-flags-design]].
