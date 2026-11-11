---
name: weather-v2
description: MV-770 Weather v2 picks (rain/storm/acid/fog/snow/ash/overcast A, sandstorm D) in game behind switch weather_v2
metadata:
  type: project
---

2026-11-10 Parames: "ให้ pixellab ช่วยทำบรรยากาศในเกมใหม่ (weather) ให้สวยขึ้น details มากขึ้น". Preview page (artifact
https://claude.ai/artifact/MbpYUNRcoCgZ5PqYeVoXP4) source: project files designs/weather-v2/ (template.html + build.py).
PixelLab: 160 gens (v1 sheets) + 47 (fog D) + 58 (sand D); everything else code only.

Decisions while iterating (Parames):
- The road scrolls RIGHT (the ambulance faces left). Rain = slender 1 screen px streaks, varied length/speed/brightness,
  slant = wind + 0.26 x speed and drops travel along it. No storm clouds, no splash sheets, acid = green drops only.
- Fog floating in the sky has no flat cut underside; fog rolls (2 px column sine waves) and breathes.
- Sandstorm D: PixelLab walls with very small motion (3 frames ping-pong), graded to the road haze; flying debris
  rare and random (4-12 s gap, max 2, shuffle bag); sand bits in varied sizes + the old game's sand stream.
- Snow: many flake patterns of uneven size, heavier; big crystals now and then drift past the camera.
- Ash: irregular tumbling flakes reacting to speed; rare big charred scraps with only a little fire.
- Overcast: NO big cloud ceiling, only faint scattered clouds; sun rays through a gap every ~20 s; cloud shadows.
  Tall phones show more sky: anything drawn there must be scattered or reach the camera top, never a fixed strip.

PICKS 2026-11-11: rain A, storm A, acid A, fog A, sandstorm D, snow A, ash A, overcast A.

In game (PR mv-770-weather-v2): `WeatherV2` (scripts/world/weather_v2.gd) inside WeatherFX (under / over the haze) +
ParallaxV2Backdrop.wx_slots (sky/far/mid/ground/rays). Art assets/weather/v2/*.png + sheets.json baked from the page by
designs/weather-v2/export/export.js (re-run after any preview change). Tune weather_v2.density. GOD ทั่วไป อากาศ v2.
Autotest --only=weather_v2.
Related: [[parallax-v2-ingame]], [[pixellab-usage-report]]
