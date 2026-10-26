// MV-499: the Godot engine (web/index.wasm, ~39.5 MB) is larger than the 25 MiB a Cloudflare Pages file may be, so the
// Pages build command drops it from the upload and this function streams it from the R2 bucket bound as ENGINE, on
// the game's own origin (the loader and the audio worklet need same-origin files). The object key is the Godot
// version in config/engine_wasm.json (ENGINE_KEY can override it); the engine only changes with the Godot version, so
// it is uploaded once per Godot upgrade. ETag / If-None-Match give 304s, and the edge caches it for a day.
import engine from "../config/engine_wasm.json";

function headers(obj) {
  const h = new Headers();
  h.set("Content-Type", "application/wasm");
  h.set("Cache-Control", "public, max-age=86400");
  h.set("ETag", obj.httpEtag);
  if (obj.size !== undefined) h.set("Content-Length", String(obj.size));
  return h;
}

async function serve(context, withBody) {
  const key = context.env.ENGINE_KEY || engine.r2_key;
  if (!context.env.ENGINE) {
    return new Response("R2 bucket binding ENGINE missing (docs/hosting-cloudflare.md)", { status: 500 });
  }
  const etag = context.request.headers.get("If-None-Match");
  const obj = withBody ? await context.env.ENGINE.get(key) : await context.env.ENGINE.head(key);
  if (!obj) {
    return new Response(`engine not in R2: ${key} (docs/hosting-cloudflare.md)`, { status: 404 });
  }
  if (etag && etag === obj.httpEtag) {
    return new Response(null, { status: 304, headers: headers(obj) });
  }
  return new Response(withBody ? obj.body : null, { headers: headers(obj) });
}

export function onRequestGet(context) {
  return serve(context, true);
}

export function onRequestHead(context) {
  return serve(context, false);
}
