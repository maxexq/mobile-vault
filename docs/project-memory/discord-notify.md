---
name: discord-notify
description: Discord notifications for PR/review/CI/Vercel deploy via GitHub Actions (PR #36, MV-96), secret DISCORD_WEBHOOK_URL
metadata:
  type: project
  modified: 2026-10-23T23:39:18.894Z
---

2026-10-24 MERGED (PR #36). 2026-10-23: Parames asked for Discord messages on PRs and CI/CD. PR maxexq/mobile-vault#36 (branch mv-96-discord-notify, Plane MV-96) adds `.github/workflows/discord-notify.yml` + `.github/scripts/discord-notify.sh` (bash/jq/curl, DRY_RUN=1 to test).
- First GitHub Actions workflow in the repo; there was no CI before. Vercel deploys arrive as commit status context "Vercel" (no GitHub deployments), handled via `status` trigger (PR #39, merged 2026-10-24); deployment_status never fires.
- Secret `DISCORD_WEBHOOK_URL` is created by Parames (never commit/paste it). Optional repo var SKIP_PREVIEW_SUCCESS=true.
- Any new CI workflow must be added to `workflow_run.workflows` (currently placeholders Autotest, Web export). Rule mirrored in CLAUDE.md.
- Triggers run from main. Webhook name/avatar come from Discord (no username override). Cloud proxy blocks gh secret set + discord.com, so Parames sets the secret in the GitHub UI.
Related: [[claude-cli-handover]], [[plane-setup]]
