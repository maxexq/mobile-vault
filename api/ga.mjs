// GameAnalytics signing proxy (MV-426). The repo is public and the web build bundles cloud_config.json, so the
// GameAnalytics secret key must never be in either. The game (scripts/autoload/analytics.gd) posts its init / events
// body here: POST /api/ga?route=init|events&game=<game key>. This function signs the exact body with the secret from
// the Vercel environment (Authorization = base64 HMAC-SHA256, Collection API v2) and forwards it to GameAnalytics,
// passing the answer back unchanged.
//  * Vercel env vars (Project Settings > Environment Variables, all environments):
//    GA_GAME_KEY_PROD + GA_SECRET_PROD, GA_GAME_KEY_TEST + GA_SECRET_TEST
//  * only our own two game keys are signed: this is not an open signer for other games
//  * GameAnalytics unreachable = 502, which the game keeps queued like "offline"
// Local test (no network): node tools/ga_proxy_test.mjs

import { createHmac } from "node:crypto";

export const HOST = "https://api.gameanalytics.com";
export const ROUTES = new Set(["init", "events"]);
export const MAX_BYTES = 512 * 1024;

export function secretFor(gameKey, env) {
  for (const p of ["PROD", "TEST"]) {
    const gk = (env[`GA_GAME_KEY_${p}`] || "").trim();
    const sk = (env[`GA_SECRET_${p}`] || "").trim();
    if (gk !== "" && sk !== "" && gameKey === gk) return sk;
  }
  return "";
}

export function sign(body, secret) {
  return createHmac("sha256", secret).update(body, "utf8").digest("base64");
}

function reply(status, obj) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

export async function handle(request, env = process.env, send = fetch) {
  if (request.method !== "POST") return reply(405, { error: "POST only" });
  const url = new URL(request.url);
  const route = url.searchParams.get("route") || "";
  const game = url.searchParams.get("game") || "";
  if (!ROUTES.has(route)) return reply(400, { error: "unknown route" });
  const secret = secretFor(game, env);
  if (secret === "") return reply(403, { error: "unknown game key" });
  const body = await request.text();
  if (Buffer.byteLength(body, "utf8") > MAX_BYTES) return reply(413, { error: "body too large" });
  try {
    JSON.parse(body);
  } catch {
    return reply(400, { error: "body is not JSON" });
  }
  let r;
  try {
    r = await send(`${HOST}/v2/${game}/${route}`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: sign(body, secret) },
      body,
    });
  } catch {
    return reply(502, { error: "gameanalytics unreachable" });
  }
  return new Response(await r.text(), {
    status: r.status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

export default {
  fetch(request) {
    return handle(request);
  },
};
