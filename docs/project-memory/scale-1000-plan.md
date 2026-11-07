---
name: scale-1000-plan
description: MV-379 scale to ~1000 players: keep Supabase (Pro), move static host Vercel Hobby -> Cloudflare Pages + R2; logs table growth is the real bottleneck
metadata:
  type: project
  modified: 2026-10-25T13:34:15.731Z
---

2026-10-25 Parames asked where to deploy for ~1000 players. Plan doc https://claude.ai/artifact/KQ9Azbs3HNniR1sK4ZPhvE, Plane MV-379 (Needs Decision, waiting for Parames to pick).
- Measured on main: index.wasm 39.5 MB (gzip ~10.1), index.pck 6.4 MB (gzip ~4.2, cache 5 min), features/version.json polled every 5 min; rpc_save every 60 s while playing; rpc_log every 60 s.
- Estimates: 1000 DAU ~250 GB/mo static (over Vercel Hobby 100 GB, Hobby is also non-commercial); 1000 CCU ~1.5-2.5 TB/mo, ~35 req/s to Supabase.
- Cloudflare Pages max 25 MiB per file -> index.wasm must live in R2 (shell change in tools/web_shell.html, CORS). Domain move also touches og tags, cloud_config site_url, Google redirect, Discord Vercel notify.
- Biggest risk regardless of host: public.logs ~3-6 rows/min/player -> fills Free 500 MB in days. Fix: logs sampling tune + pg_cron retention (14 d) + cleanup of stale anon users; raise anon sign-in rate limit / Turnstile (CGNAT).
- Sub-tickets (Todo): MV-380 logs sampling+retention+guest cleanup (first), MV-381 Supabase Pro + anon rate limit, MV-382 Cloudflare Pages+R2 move, MV-383 load test.
- Cost: recommended $25-45/mo at 1000 CCU vs ~$210-300 staying on Vercel Pro.
Related: [[backend-database-choice]], [[online-anticheat-design]], [[announce-marquee]], [[error-spike-alerts]]
