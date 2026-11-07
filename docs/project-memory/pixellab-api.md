---
name: pixellab-api
description: PixelLab API (pixellab.ai) sprite redraw tool tools/pixellab.py + atlas overrides (PR #41, MV-161); auth via Network secret; ask before spending credits
metadata:
  type: project
---

2026-10-24: Parames wants PixelLab API to improve game art. PR maxexq/mobile-vault#41 (MERGED 2026-10-24, branch mv-161-pixellab-api, Plane MV-161):
- `tools/pixellab.py` (stdlib+Pillow): balance/list/spec/gen/accept/reject. gen sends the current atlas sprite as init_image + master palette as color_image to v2 `create-image-pixflux` (or bitforge), snaps back with tools/art/pixelize.py. Candidates in tools/art/pixellab/candidates/ (git-ignored), accepted PNGs in tools/art/pixellab/overrides/ which `common.add()` uses (same size only; MV_NO_OVERRIDES=1 disables). Prompts: tools/art/pixellab/prompts.json.
- API facts: base https://api.pixellab.ai/v2, header `Authorization: Bearer <token>`, many endpoints async -> `background_job_id`, poll GET /background-jobs/{id}, result in last_response.image.base64 (data URL). Base64Image = {"type":"base64","base64":...}. Pixflux min area 32x32, max 400x400; bitforge max 200. ~$0.008 per 64x64 call. Field names (outline/shading/detail/view enums) were taken from the v1 python SDK; verified 2026-10-24 against live openapi.json: all match.
- Network secret for api.pixellab.ai set by Parames 2026-10-24, works. Account is on trial: $0 credits, 35/40 free generations left (each gen call likely uses 1).
**Why:** credits are Parames's money. **How to apply:** always show --dry-run cost and get OK before `gen --yes`; dw_* strips need PixelLab character/animation endpoints, not gen. Related: [[pixel-32bit-upgrade]], [[plane-setup]].
- 2026-10-24 pilot (MV-162): room_medical 3 seeds at strength 300 -> layout kept, more grime/texture, but outlines softer/noisier than the drawn sprite. Comparison: /mnt/project-files/designs/pixellab/room_medical_pilot.png. Trial now 32 generations left. Awaiting Parames's pick.
- 2026-10-24: Parames picked A (seed 2024) -> PR #43 (mv-162-pixellab-medical-room), autotest 527/0, web export + artifact v41 published. Knock-through variants room_medical_x2/_x10 still old art (follow-up). tools/art/pixellab/.gdignore stops Godot importing override PNGs.
- 2026-10-24 MV-166 / PR #47 (mv-166-pixellab-rooms): Parames dropped bg-v2 (PR #45 closed, [[bg-v2-layers]]) and said "improve rooms until the quota runs out". The 11 other rooms were redrawn (strength 300-450, seeds 2024/2030/2031), autotest 527/0, artifact v43. **Trial quota is now 0**: new gens need paid credits (402 = no credits), so ask first. 502s can still consume a gen; retry is built in. Comparison: /mnt/project-files/designs/pixellab/rooms_mv166.png. Still old art: room_*_x2/_x10 knock-through variants.
- 2026-10-29 balance check: account now on subscription "Tier 2: Pixel Artisan" (active), 3654/5000 generations left, $0 pay-as-you-go credits. GET /v2/balance returns {credits, subscription}.
- 2026-10-29 MV-611 animation cost table (live openapi /v2/openapi.json): v3 text animate 1 gen/take (recommended, 4-16 frames); skeleton-v3 beta 2-4 gens/direction (3f=2, 8f=3, 15f=4), steadiest identity; PixMiniMax beta 64px 4-8f=1, 16f=2, 40f=6; template 1/direction; pro legacy 10-25/direction (avoid); estimate-skeleton 0.1; edit-animation-v2 / interpolation-v2 cost not documented. Account Tier 3 (9839 gens/month).
