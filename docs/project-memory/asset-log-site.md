---
name: asset-log-site
description: PixelLab asset log web app mobile-vault-asset-log.pages.dev (MV-584): how it is fed, why script gens were missing, backfill command (MV-606, PR #184 merged to staging 2026-10-29)
metadata:
  type: project
  modified: 2026-10-29T19:21:08.762Z
---

- Site https://mobile-vault-asset-log.pages.dev = repo `tools/asset-log/` (Cloudflare Pages + Functions, D1 `mobile-vault-asset-log` + R2 bucket of same name), behind Cloudflare Access (team tomorrowismonday.cloudflareaccess.com). Deployed by hand with `npx wrangler@4.151.0 pages deploy --branch main` from that folder (no CI). Built MV-584.
- Fed ONLY by `tools/asset_log.py sync` (auto after `pixellab.py gen --yes`, reads candidates/usage.jsonl) using an Access service token from `.asset-log.json` (git-ignored, on Parames's PC) or env ASSET_LOG_URL / CF_ACCESS_CLIENT_ID / CF_ACCESS_CLIENT_SECRET.
- 2026-10-29 cause of missing art: v2 rooms, pets, crew gun anims, Dr. Ren ambulance were made by one-off scripts in /mnt/project-files/designs/* calling PixelLab directly -> never synced. Also the cloud env proxy denies the domain (403 CONNECT) and has no token.
- Fix MV-606 / PR #184: `python tools/asset_log.py backfill DIR [--group G] [--dry-run]` (frame folders -> lossless GIF, skips compare/sheet/mask/hotspot, idempotent via DIR/.asset_log_backfill.json). CLAUDE.md rule: every script gen batch ends with backfill.
- Backfill targets: designs/room-redesign-preview (351 imgs, 227 MB), pets-preview, crew-gun-anim, crew-anim-preview, dr-ren-ambulance, pixellab. Not PixelLab: comfy-pilot, logo, scene-prompts, parallax-prompts, crew-roster.
- 2026-10-29 DONE from cloud (env vars + allowed domain now set in the cloud env): 2255 gens on the site after backfilling all 6 folders. Big room folder can hit SSL EOF mid-upload; just re-run (state file makes it resume).
**How to apply:** cloud sessions can now run sync/backfill directly; otherwise run backfill on a PC that has `.asset-log.json`. Related: [[pixellab-api]], [[plane-setup]].
