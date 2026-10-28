#!/usr/bin/env python3
"""PixelLab asset log (MV-584): sync local PixelLab candidates to the private web app and pull reviews back.

  python tools/asset_log.py sync               upload new generations (images, prompt, cost) + palette/atlas/prompts/balance
  python tools/asset_log.py sync --dry-run     show what would be uploaded
  python tools/asset_log.py pull [--dry-run]   approved on the web -> override PNG (like `pixellab.py accept`), marks it accepted
  python tools/asset_log.py status             counts by status from the server

`pixellab.py gen --yes` runs `sync` for its sprite by itself when the log is configured.
The web app (tools/asset-log, Cloudflare Pages + R2 + D1, behind Cloudflare Access) and its setup: tools/asset-log/README.md.

Config, first match wins (never commit it, never paste it into a chat):
  1. env ASSET_LOG_URL, CF_ACCESS_CLIENT_ID, CF_ACCESS_CLIENT_SECRET (Access service token)
  2. .asset-log.json in the repo root (git-ignored): {"url": ..., "client_id": ..., "client_secret": ...}
A local `wrangler pages dev` URL (http://127.0.0.1:8788) needs no token.
"""
import argparse, hashlib, io, json, os, ssl, sys, time, urllib.error, urllib.request, uuid

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import pixellab  # noqa: E402

CANDIDATES = pixellab.CANDIDATES
STATE = os.path.join(CANDIDATES, ".asset_log_state.json")
_ctx = pixellab._ctx


def config():
    cfg = {}
    p = os.path.join(ROOT, ".asset-log.json")
    if os.path.exists(p):
        with open(p, encoding="utf-8") as f:
            cfg = json.load(f)
    url = os.environ.get("ASSET_LOG_URL") or cfg.get("url") or ""
    return {"url": url.rstrip("/"), "client_id": os.environ.get("CF_ACCESS_CLIENT_ID") or cfg.get("client_id", ""),
            "client_secret": os.environ.get("CF_ACCESS_CLIENT_SECRET") or cfg.get("client_secret", "")}


def configured():
    return bool(config()["url"])


def request(method, path, body=None, content_type="application/json", timeout=120):
    cfg = config()
    if not cfg["url"]:
        sys.exit("asset log not configured: set ASSET_LOG_URL or write .asset-log.json (tools/asset-log/README.md)")
    headers = {"Accept": "application/json"}
    if body is not None:
        headers["Content-Type"] = content_type
    if cfg["client_id"]:
        headers["CF-Access-Client-Id"] = cfg["client_id"]
        headers["CF-Access-Client-Secret"] = cfg["client_secret"]
    if isinstance(body, (dict, list)):
        body = json.dumps(body).encode()
    req = urllib.request.Request(f"{cfg['url']}/api/{path}", data=body, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, context=_ctx, timeout=timeout) as r:
            raw = r.read()
            if "json" not in r.headers.get("Content-Type", ""):
                if path.startswith("img"):
                    return raw
                sys.exit(f"{path}: expected JSON, got {r.headers.get('Content-Type')} (Cloudflare Access login page? check the service token)")
            return json.loads(raw)
    except urllib.error.HTTPError as e:
        sys.exit(f"{method} /api/{path}: HTTP {e.code} {e.read()[:300].decode(errors='replace')}")


def multipart(fields, files):
    """fields: {name: str}, files: {name: (filename, bytes, type)} -> (body, content type)"""
    b = uuid.uuid4().hex
    out = io.BytesIO()
    for k, v in fields.items():
        out.write(f"--{b}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n".encode())
        out.write(v.encode() + b"\r\n")
    for k, (fn, data, typ) in files.items():
        out.write(f"--{b}\r\nContent-Disposition: form-data; name=\"{k}\"; filename=\"{fn}\"\r\nContent-Type: {typ}\r\n\r\n".encode())
        out.write(data + b"\r\n")
    out.write(f"--{b}--\r\n".encode())
    return out.getvalue(), f"multipart/form-data; boundary={b}"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read(path):
    with open(path, "rb") as f:
        return f.read()


def load_state():
    if os.path.exists(STATE):
        with open(STATE, encoding="utf-8") as f:
            return json.load(f)
    return {"synced": [], "snapshots": {}}


def save_state(st):
    os.makedirs(CANDIDATES, exist_ok=True)
    with open(STATE, "w", encoding="utf-8") as f:
        json.dump(st, f, indent=1)


def usage_rows():
    p = os.path.join(CANDIDATES, "usage.jsonl")
    if not os.path.exists(p):
        return []
    rows = []
    for ln in open(p, encoding="utf-8"):
        ln = ln.strip()
        if ln:
            try:
                rows.append(json.loads(ln))
            except ValueError:
                pass
    return rows


PALETTE = None


def off_palette(im):
    global PALETTE
    if PALETTE is None:
        PALETTE = {tuple(c) for c in pixellab.load_palette(None)}
    d = im.convert("RGBA").tobytes()
    return sum(1 for i in range(0, len(d), 4) if d[i + 3] and (d[i], d[i + 1], d[i + 2]) not in PALETTE)


def build_row(r, rows):
    """One usage.jsonl line -> (row for /api/ingest, {r2 key: bytes})."""
    sprite, seed, t = r["sprite"], int(r["seed"]), int(r["t"])
    d = os.path.join(CANDIDATES, sprite)
    files, row = {}, {
        "id": f"{sprite}~{seed}~{t}", "sprite": sprite, "prefix": sprite.split("_")[0] + "_",
        "endpoint": r.get("endpoint", ""), "seed": seed, "t": t, "usd": float(r.get("usd") or 0),
        "gen_w": r.get("size", [0, 0])[0], "gen_h": r.get("size", [0, 0])[1],
        "prompt": r.get("prompt", ""), "negative": r.get("negative", ""), "params": r.get("params", {}), "prompt_guess": 0,
    }
    if not row["prompt"]:
        try:
            row["prompt"], row["negative"], _ = pixellab.prompt_for(sprite)
            row["prompt_guess"] = 1
        except SystemExit:
            pass
    # A later run with the same seed overwrites <seed>.png; only the owner of the file on disk gets the images.
    newest = max((x for x in rows if x["sprite"] == sprite and int(x["seed"]) == seed), key=lambda x: int(x["t"]))
    for kind, fn in (("snapped", f"{seed}.png"), ("raw", f"{seed}_raw.png")):
        p = os.path.join(d, fn)
        if not os.path.exists(p):
            continue
        data = read(p)
        want = r.get(f"sha_{kind}")
        if (want and want == sha(data)) or (not want and newest is r):
            key = f"gen/{sprite}/{t}_{seed}{'_raw' if kind == 'raw' else ''}.png"
            files[key] = data
            row[f"key_{kind}"] = key
    cur = os.path.join(d, "current.png")
    if os.path.exists(cur):
        data = read(cur)
        want = r.get("sha_current")
        if (want and want == sha(data)) or (not want and t >= int(os.path.getmtime(cur)) - 1):
            key = f"current/{sprite}/{sha(data)[:16]}.png"
            files[key] = data
            row["key_current"] = key
    try:
        native = pixellab.sprite(sprite)
        row["w"], row["h"] = native.size
    except SystemExit:
        row["w"], row["h"] = r.get("native", [row["gen_w"], row["gen_h"]])
    if row.get("key_snapped"):
        im = Image.open(io.BytesIO(files[row["key_snapped"]]))
        row["off_palette"] = off_palette(im)
        row["size_ok"] = int(im.size == (row["w"], row["h"]))
    return row, files


def snapshots(st, dry):
    """palette / atlas / prompts.json when they changed since the last sync, balance every time."""
    pal = ["%02x%02x%02x" % tuple(c) for c in pixellab.load_palette(None)]
    atlas_png = read(os.path.join(pixellab.ATLAS, "atlas.png"))
    atlas_json = read(os.path.join(pixellab.ATLAS, "atlas.json"))
    prompts = read(os.path.join(pixellab.HERE, "prompts.json"))
    h = {"palette": sha(",".join(pal).encode()), "atlas": sha(atlas_png + atlas_json), "prompts": sha(prompts)}
    todo = [k for k in h if st["snapshots"].get(k) != h[k]]
    if dry:
        print("snapshots to upload:", ", ".join(todo + ["balance"]))
        return
    if "atlas" in todo:
        a = h["atlas"][:16]
        body, ct = multipart({"meta": "[]"}, {f"atlas/{a}.png": ("atlas.png", atlas_png, "image/png"),
                                              f"atlas/{a}.json": ("atlas.json", atlas_json, "application/json")})
        request("POST", "ingest", body, ct)
        request("POST", "snapshot", {"kind": "atlas", "value": {"png_key": f"atlas/{a}.png", "json_key": f"atlas/{a}.json", "sha": h["atlas"]}})
    if "palette" in todo:
        request("POST", "snapshot", {"kind": "palette", "value": pal})
    if "prompts" in todo:
        request("POST", "snapshot", {"kind": "prompts", "value": json.loads(prompts)})
    for k in todo:
        st["snapshots"][k] = h[k]
    if pixellab._key():
        try:
            _, bal = pixellab.api("GET", "balance", timeout=30)
            request("POST", "snapshot", {"kind": "balance", "value": bal})
        except (SystemExit, Exception) as e:  # balance is nice to have; never fail a sync on it
            print("balance skipped:", e)


def sync(sprite=None, dry=False, quiet=False):
    st = load_state()
    rows = usage_rows()
    done = set(st["synced"])
    todo = [r for r in rows if (not sprite or r["sprite"] == sprite) and f"{r['sprite']}~{int(r['seed'])}~{int(r['t'])}" not in done]
    batch, files, size = [], {}, 0

    def flush():
        nonlocal batch, files, size
        if not batch:
            return
        body, ct = multipart({"meta": json.dumps(batch)},
                             {k: (os.path.basename(k), v, "image/png") for k, v in files.items()})
        request("POST", "ingest", body, ct)
        st["synced"].extend(r["id"] for r in batch)
        save_state(st)
        batch, files, size = [], {}, 0

    for r in todo:
        row, fs = build_row(r, rows)
        if dry:
            print(f"  {row['id']}: ${row['usd']:.4f}, {len(fs)} file(s){' (prompt guessed)' if row['prompt_guess'] else ''}")
            continue
        batch.append(row)
        files.update(fs)
        size += sum(len(v) for v in fs.values())
        if len(batch) >= 20 or size > 20 * 1024 * 1024:
            flush()
    if not dry:
        flush()
    snapshots(st, dry)
    if not dry:
        save_state(st)
    if not quiet or todo:
        print(f"{'would sync' if dry else 'synced'} {len(todo)} generation(s) to {config()['url']}")


def cmd_sync(a):
    sync(a.sprite, a.dry_run)


def cmd_pull(a):
    items = request("GET", "generations?status=approved&order=old&limit=200")["items"]
    if not items:
        print("nothing approved and waiting")
        return
    by_sprite = {}
    for g in items:
        best = by_sprite.get(g["sprite"])
        if not best or (g.get("reviewed_at") or 0) >= (best.get("reviewed_at") or 0):
            by_sprite[g["sprite"]] = g
    for sprite, g in sorted(by_sprite.items()):
        others = [x["seed"] for x in items if x["sprite"] == sprite and x["id"] != g["id"]]
        note = f" (also approved: seeds {others}; the newest review wins)" if others else ""
        if not g.get("key_snapped"):
            print(f"  {sprite}: seed {g['seed']} has no image on the server, skipped")
            continue
        print(f"  {sprite}: seed {g['seed']} -> tools/art/pixellab/overrides/{sprite}.png{note}")
        if a.dry_run:
            continue
        im = Image.open(io.BytesIO(request("GET", f"img?key={urllib.request.quote(g['key_snapped'])}"))).convert("RGBA")
        native = pixellab.sprite(sprite).size
        if im.size != native:
            print(f"    size {im.size} != sprite {native}, skipped")
            continue
        bad = off_palette(im)
        if bad and not a.force:
            print(f"    {bad} pixel(s) outside the master palette, skipped (--force to take it anyway)")
            continue
        os.makedirs(pixellab.OVERRIDES, exist_ok=True)
        im.save(os.path.join(pixellab.OVERRIDES, sprite + ".png"))
        for old in request("GET", f"generations?status=accepted&sprite={urllib.request.quote(sprite)}&limit=200")["items"]:
            request("POST", f"generations/{urllib.request.quote(old['id'], safe='')}/review", {"status": "approved"})
        request("POST", f"generations/{urllib.request.quote(g['id'], safe='')}/review", {"status": "accepted"})
    if not a.dry_run:
        print("now: python tools/generate_pixel_art.py, check in game, commit the overrides")


def cmd_status(a):
    s = request("GET", "stats")
    print(f"{s['total']['n']} generation(s), ${s['total']['usd'] or 0:.4f} spent")
    for x in s["statuses"]:
        print(f"  {x['status']}: {x['n']}")


def main():
    ap = argparse.ArgumentParser(description="PixelLab asset log sync")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("sync")
    p.add_argument("--sprite")
    p.add_argument("--dry-run", action="store_true")
    p.set_defaults(fn=cmd_sync)
    p = sub.add_parser("pull")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--force", action="store_true", help="accept images with off-palette pixels")
    p.set_defaults(fn=cmd_pull)
    sub.add_parser("status").set_defaults(fn=cmd_status)
    a = ap.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
