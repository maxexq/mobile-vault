// Tests for api/ga.mjs (MV-426) with a fake GameAnalytics: no network, no npm packages. Run: node tools/ga_proxy_test.mjs
// Exits 1 on any failure.

import { handle, sign, secretFor } from "../api/ga.mjs";

const ENV = {
  GA_GAME_KEY_PROD: "5c6bcb5402204249437fb5a7a80a4959",
  GA_SECRET_PROD: "16813a12f718bc5c620f56944e1abc3ea13ccbac",
  GA_GAME_KEY_TEST: "00000000000000000000000000000001",
  GA_SECRET_TEST: "0000000000000000000000000000000000000002",
};
let fails = 0;
function check(name, ok) {
  console.log(`${ok ? "PASS" : "FAIL"} ga proxy: ${name}`);
  if (!ok) fails++;
}
function req(query, body, method = "POST") {
  return new Request(`https://game.test/api/ga?${query}`, { method, body: method === "POST" ? body : undefined });
}

// GameAnalytics' own test vector (same one tools/autotest.gd checks on the game side)
check("HMAC matches GameAnalytics' test vector", sign('{"test": "test"}', ENV.GA_SECRET_PROD) === "slnR8CKJtKtFDaESSrqnqQeUvp5FaVV7d5XHxt50N5A=");
check("secret only for our own game keys", secretFor(ENV.GA_GAME_KEY_TEST, ENV) === ENV.GA_SECRET_TEST && secretFor("ffff", ENV) === "");

const sent = [];
const fakeGA = async (url, opts) => {
  sent.push({ url, ...opts });
  return new Response('{"enabled":true,"server_ts":1}', { status: 200 });
};
const body = '[{"category":"design","event_id":"Test:Proxy"}]';
let r = await handle(req(`route=events&game=${ENV.GA_GAME_KEY_TEST}`, body), ENV, fakeGA);
check("signs the exact body with the matching secret and forwards it", r.status === 200 && sent.length === 1
  && sent[0].url === `https://api.gameanalytics.com/v2/${ENV.GA_GAME_KEY_TEST}/events`
  && sent[0].body === body && sent[0].headers.Authorization === sign(body, ENV.GA_SECRET_TEST));
check("passes GameAnalytics' answer back", (await r.json()).enabled === true);

r = await handle(req("route=events&game=ffffffffffffffffffffffffffffffff", body), ENV, fakeGA);
check("unknown game key refused (403), nothing sent", r.status === 403 && sent.length === 1);
r = await handle(req(`route=admin&game=${ENV.GA_GAME_KEY_TEST}`, body), ENV, fakeGA);
check("unknown route refused (400)", r.status === 400 && sent.length === 1);
r = await handle(req(`route=events&game=${ENV.GA_GAME_KEY_TEST}`, "not json"), ENV, fakeGA);
check("non-JSON body refused (400)", r.status === 400 && sent.length === 1);
r = await handle(req(`route=events&game=${ENV.GA_GAME_KEY_TEST}`, "x".repeat(600 * 1024)), ENV, fakeGA);
check("oversized body refused (413)", r.status === 413 && sent.length === 1);
r = await handle(req(`route=events&game=${ENV.GA_GAME_KEY_TEST}`, null, "GET"), ENV, fakeGA);
check("GET refused (405)", r.status === 405);
r = await handle(req(`route=events&game=${ENV.GA_GAME_KEY_TEST}`, body), {}, fakeGA);
check("no env vars = every key refused", r.status === 403 && sent.length === 1);

const status401 = async () => new Response("Unauthorized", { status: 401 });
r = await handle(req(`route=init&game=${ENV.GA_GAME_KEY_PROD}`, "{}"), ENV, status401);
check("GameAnalytics' 401 passed through", r.status === 401);
const down = async () => { throw new Error("ECONNRESET"); };
r = await handle(req(`route=events&game=${ENV.GA_GAME_KEY_PROD}`, body), ENV, down);
check("GameAnalytics unreachable = 502", r.status === 502);

console.log(`ga proxy: ${fails} failed`);
process.exit(fails ? 1 : 0);
