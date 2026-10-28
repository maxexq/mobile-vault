# PixelLab asset log (MV-584)

A private web app that keeps every PixelLab generation: the snapped image, the raw image, the sprite before it,
the prompt, seed, settings and cost. Parames reviews there, and `tools/asset_log.py pull` turns approvals into
overrides. Not part of the game build (`.gdignore`).

| Tab | What it does |
|---|---|
| Gallery | every generation, newest first; search sprite / prompt / note, filter by group and status, 2x/4x/8x nearest |
| Review | the `new` queue sorted by sprite. Detail: before / snapped / raw at the same integer scale, size + palette + alpha checks, off-palette pixels highlighted in magenta, pixel grid, the same-size sprites of its family from the atlas, prompt (copy), settings, a `pixellab.py gen` command to redo it, Approve / Reject / note |
| Prompts | prompt library: each distinct prompt with its best image, uses, approved / rejected counts, copy |
| Cost | total spent, credits left (last sync), spend per day and per sprite, status counts |

## How it fits together

```
pixellab.py gen --yes  ->  candidates/ + usage.jsonl (prompt, params, sha256)  ->  asset_log.py sync
        -> POST /api/ingest (R2: gen/, current/, atlas/ · D1: generations, snapshots)
web: Approve  ->  asset_log.py pull  ->  tools/art/pixellab/overrides/<sprite>.png (status accepted)
```

- `public/`: static UI (no build, no libraries). `functions/api/[[route]].js`: the API (Pages Functions).
- `migrations/`: D1 schema. `wrangler.toml`: bindings `DB` (D1) and `BUCKET` (R2), Access settings.
- `pixellab.py gen --yes` syncs its sprite by itself when the log is configured; a failed sync only prints a hint.
- `pull` downloads the approved image from R2 (works from any PC), checks size and palette (`--force` to take
  off-palette pixels anyway), writes the override and marks it `accepted`; an older accepted seed of the same sprite
  goes back to `approved`. Then run `python tools/generate_pixel_art.py` and commit the override as usual.

## Security

The whole site sits behind **Cloudflare Access**. The API also checks the Access JWT itself (signature against
`https://<team>/cdn-cgi/access/certs`, `aud` = `ACCESS_AUD`, issuer, expiry) and refuses everything while
`ACCESS_TEAM_DOMAIN` / `ACCESS_AUD` are empty, so a missing Access policy never exposes data.
`asset_log.py` uses an Access **service token** (`CF-Access-Client-Id` / `-Secret`).
`DEV_NO_AUTH=1` (`.dev.vars`) only works on `localhost` / `127.0.0.1`.

## One-time setup

All from this folder, with `npx wrangler@4.151.0` (no global install):

```
npx wrangler@4.151.0 login                                   # Parames, in the browser
npx wrangler@4.151.0 d1 create mobile-vault-asset-log        # put the database_id into wrangler.toml
npx wrangler@4.151.0 r2 bucket create mobile-vault-asset-log
npx wrangler@4.151.0 d1 migrations apply DB --remote
npx wrangler@4.151.0 pages project create mobile-vault-asset-log --production-branch main
npx wrangler@4.151.0 pages deploy --branch main
```

Then in the Cloudflare dashboard (Parames):

1. **Zero Trust → Access → Applications → Add → Self-hosted**: domains `mobile-vault-asset-log.pages.dev` and
   `*.mobile-vault-asset-log.pages.dev`. Policy **Allow**, include your e-mail(s).
2. Same application, second policy **Service Auth**, include a new service token
   (**Access → Service credentials → Service Tokens → Create**, e.g. `asset-log-cli`). Copy its ID and secret.
3. Copy the application's **AUD tag** and the team domain (`<team>.cloudflareaccess.com`) into `[vars]` in
   `wrangler.toml`, then `npx wrangler@4.151.0 pages deploy --branch main` again.
4. On each PC that generates art, write `.asset-log.json` in the repo root (git-ignored):
   `{"url": "https://mobile-vault-asset-log.pages.dev", "client_id": "...", "client_secret": "..."}`
   (or env `ASSET_LOG_URL`, `CF_ACCESS_CLIENT_ID`, `CF_ACCESS_CLIENT_SECRET`). Check: `python tools/asset_log.py status`.

Schema change: add `migrations/000N_*.sql`, then `d1 migrations apply DB --remote` before deploying.

## Local development

```
cp .dev.vars.example .dev.vars
npx wrangler@4.151.0 d1 migrations apply DB --local
npx wrangler@4.151.0 pages dev --port 8788 --ip 127.0.0.1
ASSET_LOG_URL=http://127.0.0.1:8788 python tools/asset_log.py sync      # from the repo root
```

Local D1 / R2 live in `.wrangler/` (git-ignored).
