// PixelLab asset log API (MV-584). Bindings: DB (D1), BUCKET (R2). Every request needs a Cloudflare Access JWT
// (browser cookie or service token); see ../../README.md. Local `wrangler pages dev` may skip it with DEV_NO_AUTH=1.

const KEY_RE = /^(gen|current|atlas)\/[A-Za-z0-9_.~\/-]+$/;
const STATUSES = ["new", "approved", "rejected", "accepted"];
const META_FIELDS = ["sprite", "prefix", "endpoint", "seed", "t", "w", "h", "gen_w", "gen_h", "usd", "prompt", "negative",
  "prompt_guess", "params", "key_raw", "key_snapped", "key_current", "off_palette", "size_ok"];

const json = (data, status = 200) =>
  new Response(JSON.stringify(data), { status, headers: { "content-type": "application/json", "cache-control": "no-store" } });
const fail = (status, error) => json({ error }, status);

// --- Cloudflare Access ---------------------------------------------------------------------------------------

let certs = null, certsAt = 0;

function b64url(s) {
  s = s.replace(/-/g, "+").replace(/_/g, "/");
  return Uint8Array.from(atob(s + "===".slice((s.length + 3) % 4)), (c) => c.charCodeAt(0));
}

async function accessUser(request, env) {
  const host = new URL(request.url).hostname;
  if (env.DEV_NO_AUTH === "1" && (host === "localhost" || host === "127.0.0.1")) return "dev@localhost";
  const team = (env.ACCESS_TEAM_DOMAIN || "").replace(/^https?:\/\//, "").replace(/\/$/, "");
  if (!team || !env.ACCESS_AUD) return null;  // not configured: fail closed
  const token = request.headers.get("cf-access-jwt-assertion");
  if (!token) return null;
  const [h, p, sig] = token.split(".");
  if (!sig) return null;
  const header = JSON.parse(new TextDecoder().decode(b64url(h)));
  const claims = JSON.parse(new TextDecoder().decode(b64url(p)));
  if (Date.now() - certsAt > 3600e3 || !certs) {
    const r = await fetch(`https://${team}/cdn-cgi/access/certs`);
    if (!r.ok) return null;
    certs = (await r.json()).keys || [];
    certsAt = Date.now();
  }
  const jwk = certs.find((k) => k.kid === header.kid);
  if (!jwk) return null;
  const key = await crypto.subtle.importKey("jwk", jwk, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
  const ok = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, b64url(sig), new TextEncoder().encode(`${h}.${p}`));
  if (!ok) return null;
  const aud = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
  if (!aud.includes(env.ACCESS_AUD) || claims.iss !== `https://${team}` || claims.exp * 1000 < Date.now()) return null;
  return claims.email || claims.common_name || "service-token";
}

// --- routes --------------------------------------------------------------------------------------------------

async function listGenerations(url, env) {
  const q = url.searchParams;
  const where = [], args = [];
  if (q.get("q")) {
    where.push("(sprite LIKE ? OR prompt LIKE ? OR note LIKE ?)");
    const like = `%${q.get("q")}%`;
    args.push(like, like, like);
  }
  for (const f of ["sprite", "prefix", "status", "endpoint"]) {
    if (q.get(f)) { where.push(`${f} = ?`); args.push(q.get(f)); }
  }
  const limit = Math.min(200, Math.max(1, parseInt(q.get("limit") || "60", 10)));
  const offset = Math.max(0, parseInt(q.get("offset") || "0", 10));
  const order = q.get("order") === "old" ? "t ASC" : "t DESC";
  const sql = `SELECT * FROM generations ${where.length ? "WHERE " + where.join(" AND ") : ""} ORDER BY ${order}, seed LIMIT ? OFFSET ?`;
  const { results } = await env.DB.prepare(sql).bind(...args, limit + 1, offset).all();
  return json({ items: results.slice(0, limit), more: results.length > limit });
}

async function review(id, request, env, user) {
  const body = await request.json().catch(() => ({}));
  if (body.status !== undefined && !STATUSES.includes(body.status)) return fail(400, "bad status");
  const row = await env.DB.prepare("SELECT status, note FROM generations WHERE id = ?").bind(id).first();
  if (!row) return fail(404, "no such generation");
  const status = body.status ?? row.status;
  const note = typeof body.note === "string" ? body.note.slice(0, 2000) : row.note;
  await env.DB.prepare("UPDATE generations SET status = ?, note = ?, reviewed_by = ?, reviewed_at = ? WHERE id = ?")
    .bind(status, note, user, Math.floor(Date.now() / 1000), id).run();
  return json(await env.DB.prepare("SELECT * FROM generations WHERE id = ?").bind(id).first());
}

async function ingest(request, env) {
  const form = await request.formData();
  const rows = JSON.parse(form.get("meta") || "[]");
  let files = 0;
  for (const [name, value] of form.entries()) {
    if (name === "meta" || typeof value === "string") continue;
    if (!KEY_RE.test(name) || name.includes("..")) return fail(400, `bad key ${name}`);
    await env.BUCKET.put(name, value.stream(), { httpMetadata: { contentType: value.type || "application/octet-stream" } });
    files++;
  }
  const stmts = [];
  for (const r of rows) {
    if (!r.id || !r.sprite) return fail(400, "row needs id and sprite");
    const vals = META_FIELDS.map((f) => (f === "params" ? JSON.stringify(r.params || {}) : r[f] ?? null));
    stmts.push(env.DB.prepare(
      `INSERT INTO generations (id, ${META_FIELDS.join(", ")}) VALUES (?${", ?".repeat(META_FIELDS.length)})
       ON CONFLICT(id) DO UPDATE SET ${META_FIELDS.map((f) => `${f} = excluded.${f}`).join(", ")}`,
    ).bind(r.id, ...vals));
  }
  if (stmts.length) await env.DB.batch(stmts);
  return json({ rows: rows.length, files });
}

async function snapshot(request, env) {
  const { kind, value } = await request.json();
  if (!["balance", "palette", "atlas", "prompts"].includes(kind)) return fail(400, "bad kind");
  await env.DB.prepare("INSERT OR REPLACE INTO snapshots (kind, t, value) VALUES (?, ?, ?)")
    .bind(kind, Math.floor(Date.now() / 1000), JSON.stringify(value)).run();
  return json({ ok: true });
}

async function meta(env) {
  const { results } = await env.DB.prepare(
    "SELECT s.kind, s.t, s.value FROM snapshots s JOIN (SELECT kind, MAX(t) t FROM snapshots GROUP BY kind) m USING (kind, t)",
  ).all();
  const out = {};
  for (const r of results) out[r.kind] = { t: r.t, value: JSON.parse(r.value) };
  const { results: prefixes } = await env.DB.prepare("SELECT prefix, COUNT(*) n FROM generations GROUP BY prefix ORDER BY prefix").all();
  out.prefixes = prefixes;
  return json(out);
}

async function stats(env) {
  const q = (sql) => env.DB.prepare(sql).all().then((r) => r.results);
  const [days, sprites, statuses, total] = await Promise.all([
    q("SELECT date(t, 'unixepoch') day, COUNT(*) n, ROUND(SUM(usd), 4) usd FROM generations GROUP BY day ORDER BY day DESC LIMIT 60"),
    q(`SELECT sprite, COUNT(*) n, ROUND(SUM(usd), 4) usd, MAX(t) last,
         SUM(status IN ('approved', 'accepted')) ok FROM generations GROUP BY sprite ORDER BY usd DESC LIMIT 100`),
    q("SELECT status, COUNT(*) n FROM generations GROUP BY status"),
    q("SELECT COUNT(*) n, ROUND(SUM(usd), 4) usd, MIN(t) first, MAX(t) last FROM generations"),
  ]);
  return json({ days, sprites, statuses, total: total[0] });
}

async function prompts(url, env) {
  const like = `%${url.searchParams.get("q") || ""}%`;
  const { results } = await env.DB.prepare(
    `SELECT prompt, negative, COUNT(*) n, SUM(status IN ('approved', 'accepted')) ok, SUM(status = 'rejected') bad,
       MAX(t) last, GROUP_CONCAT(DISTINCT sprite) sprites,
       (SELECT key_snapped FROM generations g2 WHERE g2.prompt = g.prompt ORDER BY (status IN ('approved', 'accepted')) DESC, t DESC LIMIT 1) key
     FROM generations g WHERE prompt LIKE ? AND prompt != '' GROUP BY prompt, negative ORDER BY last DESC LIMIT 200`,
  ).bind(like).all();
  return json({ items: results });
}

async function image(url, env) {
  const key = url.searchParams.get("key") || "";
  if (!KEY_RE.test(key) || key.includes("..")) return fail(400, "bad key");
  const obj = await env.BUCKET.get(key);
  if (!obj) return fail(404, "no such object");
  return new Response(obj.body, {
    headers: { "content-type": obj.httpMetadata?.contentType || "image/png", "cache-control": "private, max-age=86400", etag: obj.httpEtag },
  });
}

export async function onRequest({ request, env, params }) {
  const user = await accessUser(request, env).catch(() => null);
  if (!user) return fail(401, "Cloudflare Access login required");
  const url = new URL(request.url);
  const route = (params.route || []).join("/");
  const m = request.method;
  try {
    if (m === "GET" && route === "me") return json({ user });
    if (m === "GET" && route === "generations") return listGenerations(url, env);
    if (m === "GET" && route.startsWith("generations/")) {
      const row = await env.DB.prepare("SELECT * FROM generations WHERE id = ?").bind(decodeURIComponent(params.route[1])).first();
      return row ? json(row) : fail(404, "no such generation");
    }
    if (m === "POST" && params.route?.length === 3 && params.route[0] === "generations" && params.route[2] === "review")
      return review(decodeURIComponent(params.route[1]), request, env, user);
    if (m === "POST" && route === "ingest") return ingest(request, env);
    if (m === "POST" && route === "snapshot") return snapshot(request, env);
    if (m === "GET" && route === "meta") return meta(env);
    if (m === "GET" && route === "stats") return stats(env);
    if (m === "GET" && route === "prompts") return prompts(url, env);
    if (m === "GET" && route === "img") return image(url, env);
    return fail(404, "no such route");
  } catch (e) {
    return fail(500, String(e && e.message || e));
  }
}
