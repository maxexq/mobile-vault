---
name: backend-database-choice
description: Supabase cloud save for Mobile Vault (PR #8, 2026-10-22): project ref, config file, sync design, test notes
metadata:
  type: project
  modified: 2026-10-23T14:35:00.000Z
---

Parames chose Supabase (2026-10-22). PR maxexq/mobile-vault#8 (branch feat/cloud-save) adds autoload `Cloud` (scripts/autoload/cloud.gd, last in autoload list): anonymous sign-in via REST, local-first sync, `rpc_save` compare-and-set on `rev`, conflict choice in Settings > เซฟ, `Cloud.now()` = server clock for `saved_at`/offline time.
- Supabase project: https://phcylgdikidhunjclppr.supabase.co, uses the publishable key (sb_publishable_…). SQL `supabase/migrations/0001_cloud_save.sql` already run by Parames; anonymous sign-ins enabled.
- `cloud_config.json` {url, anon_key} is git-ignored but exported into web/index.pck (publishable key is meant for clients). New cloud containers must recreate it before a web export, or the build ships with cloud OFF.
- Test runners (--autotest/--migrate-test/--balance) never touch the real cloud; autotest uses tools/cloud_fake.gd.
- Cloud containers in this project cannot reach *.supabase.co (network policy 403), so live checks must be done by Parames in a browser.

- Accounts (PR #23, feat/cloud-login, 2026-10-23): guest = anonymous; Google sign-in or manual identity linking (guest keeps uid + save) via redirect flow, tokens read from URL fragment on boot; identity_already_exists -> offer switch; sign-out returns to a new guest. Gated by Features switch `google_login`. Needs Supabase "Allow manual linking" + Google provider (guide: supabase/google-login-setup.md). Google login can't run in the artifact iframe; game offers `site_url` (cloud_config.json) = https://apocarlypse-mobile-vault.vercel.app/ (Vercel prod domain since 2026-10-23) in a new tab.

- PR #24 (merged 2026-10-23): title asks Guest or Gmail once per browser (meta.chose); Gmail on a browser with no save signs in directly (no link); refused Google refresh -> need_login (never silent guest); refreshes serialized (Supabase rotates refresh tokens). Each origin (artifact / preview / prod) has its own localStorage session. Run tools/stamp_build.sh before every web export. Browser e2e rig: local HTTPS fake Supabase + Playwright (rebuild in /tmp if needed).

**Why:** future online features + account management.
**How to apply:** new save data goes in `Game.s` (synced automatically); don't add new localStorage keys for progress. Related: [[settings-and-version]], [[json-int-float-ids]].
