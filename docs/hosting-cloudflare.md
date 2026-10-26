# Hosting on Cloudflare Pages (MV-499)

The game moves from Vercel to Cloudflare Pages. **Both run in parallel until Cloudflare is verified**; `vercel.json`
and the Vercel host names in `config/environments.json` stay until the cutover below.

## How it works

- Pages project **apocarlypse-mobile-vault**, Git integration (Cloudflare builds every push to every branch).
- Output directory `web/` (the committed Godot export; nothing is built).
- **The engine is too big for Pages:** `web/index.wasm` is ~39.5 MB, the Pages limit is 25 MiB per file. The build
  command deletes it, and `functions/index.wasm.js` serves it from the R2 bucket bound as `ENGINE` at the same URL
  (`/index.wasm`, `application/wasm`, ETag / 304, cached 1 day). The object key is `r2_key` in
  `config/engine_wasm.json`. CI (`node tools/engine_wasm_check.mjs`, Autotest workflow) fails when the committed
  wasm no longer matches that record, so a Godot upgrade can't ship against the old upload.
- `functions/api/ga.js` runs the same GameAnalytics signer as Vercel (`api/ga.mjs`, Web Crypto, MV-426).
- `web/_headers` = the headers from `vercel.json`.
- `web/404.html`: without it Pages answers any missing path with the game page and 200 (single-page-app fallback),
  so `features.<env>.json` lookups for environments without their own file would get HTML instead of a 404.
- Branch URLs: `main` → `https://apocarlypse-mobile-vault.pages.dev/` (prod),
  `uat` → `https://uat.apocarlypse-mobile-vault.pages.dev/`, `staging` → `https://staging.apocarlypse-mobile-vault.pages.dev/`.
  Other branches / PRs get `<hash>.` or `<branch>.apocarlypse-mobile-vault.pages.dev` → `dev`. Mapping: `config/environments.json`.
- Discord: Cloudflare reports each deploy as the check run **Cloudflare Pages**; `discord-notify.yml` posts it
  (Production / UAT / Staging / Preview, with the site link).

## One-time setup (Parames, in the dashboards)

1. **R2 bucket:** Cloudflare → R2 → Create bucket, e.g. `mobile-vault-engine`. Upload the committed `web/index.wasm`
   with the object key from `config/engine_wasm.json` (`godot-4.7.2-stable/index.wasm`). Wrangler alternative:
   `npx wrangler r2 object put mobile-vault-engine/godot-4.7.2-stable/index.wasm --file web/index.wasm --content-type application/wasm --remote`
2. **Pages project:** Workers & Pages → Create → Pages → Connect to Git → `maxexq/mobile-vault`.
   - Project name `apocarlypse-mobile-vault`, production branch `main`.
   - Framework preset: None. **Build command:** `rm -f web/index.wasm`. **Build output directory:** `web`.
   - Root directory: empty (repo root, so `functions/` is found).
3. **Settings → Bindings:** add an R2 bucket binding, variable name **`ENGINE`** → the bucket, for **Production and Preview**.
4. **Settings → Variables and Secrets** (Production and Preview, type Secret): `GA_GAME_KEY_PROD`, `GA_SECRET_PROD`,
   `GA_GAME_KEY_TEST`, `GA_SECRET_TEST` (the same values as on Vercel; see `~/.mobile-vault`).
5. **Settings → Builds → Branch control:** preview deployments for all branches (staging and uat need them).
6. **Supabase** (both projects) → Authentication → URL Configuration → Redirect URLs: add
   `https://apocarlypse-mobile-vault.pages.dev/**` (prod project) and `https://*.apocarlypse-mobile-vault.pages.dev/**` (test project).
7. Retry the latest deployment once the binding and variables exist (they apply to new deployments only).

## Verify

- `https://staging.apocarlypse-mobile-vault.pages.dev/` loads, shows the **STAGING SERVER** badge, cloud save works,
  Google sign-in returns to the same host.
- `curl -I https://staging.apocarlypse-mobile-vault.pages.dev/index.wasm` → `200`, `content-type: application/wasm`, ~39.5 MB.
- GOD → ระบบ → GAMEANALYTICS → send a test event → accepted (the signer on `/api/ga` works).
- A deploy notice appears in the Discord dev channel.

## Godot upgrade (new engine)

Upload the new `web/index.wasm` to R2 under a **new** key (`godot-<version>/index.wasm`), then update `r2_key`,
`sha256` and `bytes` in `config/engine_wasm.json` in the same PR as the export. Keep the old object until every branch
has moved on (older branches still point at it).

## Cutover (later, only when Parames says so)

- `export_presets.cfg` `html/head_include`: `canonical`, `og:url`, `og:image`, `twitter:image` → the pages.dev
  (or custom) domain; re-export. `cloud_config.json` `site_url` and the Supabase Site URL likewise.
- Remove `vercel.json`, the Vercel host names in `config/environments.json`, the `status` trigger in
  `discord-notify.yml`, and the Vercel project; update README §9, `docs/environments.md` and CLAUDE.md.
