#!/usr/bin/env python3
"""PixelLab (pixellab.ai) client for redrawing Mobile Vault sprites.

The generator in tools/generate_pixel_art.py still draws every sprite. This tool asks PixelLab for a
better-looking version of ONE atlas sprite, using the current sprite as the init image and the master
palette as a forced colour set, then snaps the result back to the exact sprite size and palette
(tools/art/pixelize.py). You pick the best candidate with `accept`; it becomes an override PNG in
tools/art/pixellab/overrides/ that common.add() uses instead of the drawn sprite, so re-running the
generator keeps it and the atlas layout stays the same.

  python tools/pixellab.py balance
  python tools/pixellab.py list [prefix]                    sprites and their sizes, e.g. list room_
  python tools/pixellab.py gen room_medical --seeds 3 --dry-run   payload + cost estimate, no call
  python tools/pixellab.py gen room_medical --seeds 3 --yes       real call, spends credits
  python tools/pixellab.py accept room_medical 2            candidate seed 2 -> override
  python tools/pixellab.py reject room_medical               remove the override (back to drawn sprite)
  python tools/pixellab.py spec create-image-pixflux        request schema from the live OpenAPI spec
  python tools/pixellab.py kit all --prefix ind_ [--yes]     standalone assets listed in tools/art/pixellab/kit.json

gen options: --prompt "..." (else tools/art/pixellab/prompts.json), --endpoint pixflux|bitforge,
--strength 1-999 (how much the init image is kept, default 300), --no-init, --style SPRITE
(bitforge style reference), --budget USD (stop when spent). Candidates and a side-by-side preview land in
tools/art/pixellab/candidates/<sprite>/ (git-ignored); every call is logged to usage.jsonl there.

API token, first match wins (never commit it, never paste it into a chat):
  1. env PIXELLAB_API_KEY
  2. file .pixellab-api-key in the repo root (git-ignored), first line
  3. none: the claude.ai cloud environment adds "Authorization: Bearer ..." through its proxy
API reference: https://api.pixellab.ai/v2/docs (OpenAPI: https://api.pixellab.ai/v2/openapi.json)
"""
import argparse, base64, io, json, math, os, re, ssl, sys, time, urllib.error, urllib.request

from PIL import Image

BASE = os.environ.get("PIXELLAB_BASE_URL", "https://api.pixellab.ai/v2")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HERE = os.path.join(ROOT, "tools", "art", "pixellab")
OVERRIDES = os.path.join(HERE, "overrides")
CANDIDATES = os.path.join(HERE, "candidates")
KIT = os.path.join(HERE, "kit")
ATLAS = os.path.join(ROOT, "assets", "atlas")
sys.path.insert(0, os.path.join(ROOT, "tools", "art"))
from pixelize import pixelize, load_palette  # noqa: E402

# endpoint -> (path, max area side, rough USD per call at 64x64 and at max size, from pixellab.ai/pixellab-api)
ENDPOINTS = {
    "pixflux": ("create-image-pixflux", 400, 0.008, 0.013),
    "bitforge": ("create-image-bitforge", 200, 0.008, 0.013),
}
MIN_AREA = 32 * 32

_ctx = ssl.create_default_context()
_ca = os.environ.get("SSL_CERT_FILE") or "/root/.ccr/ca-bundle.crt"  # cloud proxy CA
if os.path.exists(_ca):
    _ctx.load_verify_locations(_ca)


def _key():
    k = os.environ.get("PIXELLAB_API_KEY", "").strip()
    if k:
        return k
    p = os.path.join(ROOT, ".pixellab-api-key")
    if os.path.exists(p):
        with open(p, encoding="utf-8") as f:
            return f.readline().strip()
    return ""


def api(method, path, body=None, timeout=180):
    url = path if path.startswith("http") else f"{BASE}/{path.lstrip('/')}"
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Content-Type": "application/json", "Accept": "application/json"}
    key = _key()
    if key:
        headers["Authorization"] = f"Bearer {key}"
    for attempt in range(4):
        req = urllib.request.Request(url, data=data, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, context=_ctx, timeout=timeout) as r:
                raw = r.read()
                return r.status, (json.loads(raw) if raw else {})
        except urllib.error.HTTPError as e:
            msg = e.read().decode(errors="replace")
            if e.code in (429, 502, 503, 504) and attempt < 3:
                time.sleep(5 * (attempt + 1))
                continue
            hint = {401: "token missing or wrong (see the docstring: env, .pixellab-api-key or cloud Network secret)",
                    402: "not enough PixelLab credits", 403: "blocked: in the cloud, api.pixellab.ai must be an allowed host",
                    422: "request field rejected, compare with: python tools/pixellab.py spec <endpoint>"}.get(e.code, "")
            sys.exit(f"PixelLab {method} {path} -> HTTP {e.code} {hint}\n{msg[:800]}")
        except urllib.error.URLError as e:
            sys.exit(f"PixelLab {method} {path} -> network error: {e.reason} (cloud: is api.pixellab.ai allowed?)")


def wait_job(job_id, every=4, limit=600):
    t0 = time.time()
    while time.time() - t0 < limit:
        _, j = api("GET", f"background-jobs/{job_id}")
        st = j.get("status")
        if st == "completed":
            return j.get("last_response") or j
        if st in ("failed", "cancelled"):
            sys.exit(f"PixelLab job {job_id} {st}: {json.dumps(j)[:600]}")
        time.sleep(every)
    sys.exit(f"PixelLab job {job_id} still running after {limit}s")


def call(path, body):
    status, res = api("POST", path, body)
    job = res.get("background_job_id")
    if status == 202 or (job and "image" not in res):
        res = wait_job(job)
    return res


# ------------------------------------------------------------------ images
def b64img(im):
    buf = io.BytesIO()
    im.save(buf, "PNG")
    return {"type": "base64", "base64": base64.b64encode(buf.getvalue()).decode()}


def from_b64(obj):
    s = obj["base64"] if isinstance(obj, dict) else obj
    if s.startswith("data:"):
        s = s.split(",", 1)[1]
    return Image.open(io.BytesIO(base64.b64decode(s))).convert("RGBA")


def regions():
    with open(os.path.join(ATLAS, "atlas.json"), encoding="utf-8") as f:
        return json.load(f)


def sprite(name):
    reg = regions()
    if name not in reg:
        sys.exit(f"no sprite '{name}' in assets/atlas/atlas.json (python tools/pixellab.py list {name.split('_')[0]}_)")
    x, y, w, h = reg[name]
    return Image.open(os.path.join(ATLAS, "atlas.png")).convert("RGBA").crop((x, y, x + w, y + h))


def palette_image(pal):
    """one pixel per master-palette colour, sent as color_image so PixelLab only uses those colours"""
    side = math.ceil(math.sqrt(len(pal)))
    im = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    for i, c in enumerate(pal):
        im.putpixel((i % side, i // side), tuple(c) + (255,))
    return im


def gen_scale(w, h, max_side):
    """smallest whole scale that meets PixelLab's 32x32 minimum area; the result is snapped back to w x h"""
    k = max(1, math.ceil(math.sqrt(MIN_AREA / (w * h))))
    if w * k > max_side or h * k > max_side:
        sys.exit(f"sprite {w}x{h} is bigger than this endpoint allows ({max_side}px); use --endpoint pixflux "
                 "or split the sprite (strips like dw_* are animation sheets)")
    return k


def prompt_for(name):
    with open(os.path.join(HERE, "prompts.json"), encoding="utf-8") as f:
        p = json.load(f)
    body = p["sprites"].get(name)
    if body is None:
        prefix = max((k for k in p["prefixes"] if name.startswith(k)), key=len, default=None)
        if prefix is None:
            sys.exit(f"no prompt for '{name}': pass --prompt or add it to tools/art/pixellab/prompts.json")
        # room_medical_x2_2 / en_rat_1 -> "medical" / "rat": size and frame suffixes are not part of the subject
        subject = re.sub(r"(_x\d+)?(_\d+)?$", "", name[len(prefix):]).replace("_", " ")
        body = p["prefixes"][prefix].format(subject=subject)
    return f"{body}, {p['style']}", p.get("negative", ""), p.get("defaults", {})


def preview(old, cands, out, zoom=4):
    """old sprite then each candidate, zoomed with nearest, on the game's dark backdrop"""
    w, h = old.size
    sheet = Image.new("RGBA", ((w + 2) * (len(cands) + 1) * zoom, (h + 2) * zoom), (24, 24, 28, 255))
    for i, im in enumerate([old] + cands):
        big = im.resize((w * zoom, h * zoom), Image.NEAREST)
        sheet.alpha_composite(big, (i * (w + 2) * zoom + zoom, zoom))
    sheet.save(out)


# ------------------------------------------------------------------ commands
def cmd_balance(a):
    _, res = api("GET", "balance")
    print(json.dumps(res, indent=1))


def cmd_list(a):
    for k, v in sorted(regions().items()):
        if k.startswith(a.prefix or ""):
            mark = " *override" if os.path.exists(os.path.join(OVERRIDES, k + ".png")) else ""
            print(f"{k:28s} {v[2]}x{v[3]}{mark}")


def cmd_spec(a):
    _, spec = api("GET", "openapi.json")
    op = spec["paths"].get("/" + a.endpoint.lstrip("/"), {}).get("post")
    if not op:
        sys.exit(f"no POST /{a.endpoint} in the spec")
    ref = op["requestBody"]["content"]["application/json"]["schema"].get("$ref", "")
    schema = spec["components"]["schemas"].get(ref.split("/")[-1], op["requestBody"])
    print(json.dumps(schema, indent=1))


def cmd_gen(a):
    path, max_side, usd_small, usd_big = ENDPOINTS[a.endpoint]
    if a.sprite.startswith("dw_"):
        sys.exit("dw_* are 20-frame animation strips; redraw them with PixelLab's character/animation tools instead")
    old = sprite(a.sprite)
    w, h = old.size
    k = gen_scale(w, h, max_side)
    gw, gh = w * k, h * k
    if a.prompt:
        desc, neg, defaults = a.prompt, "", {}
    else:
        desc, neg, defaults = prompt_for(a.sprite)
    pal = load_palette(None)
    body = {
        "description": desc,
        "negative_description": neg,
        "image_size": {"width": gw, "height": gh},
        "text_guidance_scale": a.guidance,
        "no_background": not a.sprite.startswith(("room_", "lm_")) if a.no_bg is None else a.no_bg,
        "color_image": b64img(palette_image(pal)),
    }
    for key in ("outline", "shading", "detail", "view", "direction"):
        val = getattr(a, key) or defaults.get(key)
        if val:
            body[key] = val
    if not a.no_init:
        body["init_image"] = b64img(old.resize((gw, gh), Image.NEAREST))
        body["init_image_strength"] = a.strength
    if a.endpoint == "bitforge" and a.style:
        st = sprite(a.style)
        body["style_image"] = b64img(st.resize((st.width * k, st.height * k), Image.NEAREST))
        body["style_strength"] = a.style_strength

    est = usd_small + (usd_big - usd_small) * min(1.0, max(0.0, (gw * gh - 64 * 64) / (max_side ** 2 - 64 * 64)))
    print(f"{a.sprite}: {w}x{h} -> generate {gw}x{gh} via /{path}, {a.seeds} seed(s), about ${est * a.seeds:.3f} total")
    print(f"prompt: {desc}")
    if a.dry_run or not a.yes:
        shown = {kk: (f"<png {vv['base64'][:16]}...>" if isinstance(vv, dict) and "base64" in vv else vv) for kk, vv in body.items()}
        print(json.dumps(shown, indent=1, ensure_ascii=False))
        if not a.dry_run:
            print("\nnot sent: add --yes to spend credits")
        return

    out_dir = os.path.join(CANDIDATES, a.sprite)
    os.makedirs(out_dir, exist_ok=True)
    old.save(os.path.join(out_dir, "current.png"))
    spent, cands = 0.0, []
    for i in range(a.seeds):
        if a.budget and spent >= a.budget:
            print(f"budget ${a.budget} reached, stopping")
            break
        seed = a.seed + i
        res = call(path, dict(body, seed=seed))
        usd = float((res.get("usage") or {}).get("usd") or 0.0)
        spent += usd
        raw = from_b64(res["image"])
        raw.save(os.path.join(out_dir, f"{seed}_raw.png"))
        snapped = pixelize(raw, w, h, pal, alpha_cut=128, keep_lines=0.2)
        snapped.save(os.path.join(out_dir, f"{seed}.png"))
        cands.append(snapped)
        with open(os.path.join(CANDIDATES, "usage.jsonl"), "a", encoding="utf-8") as f:
            f.write(json.dumps({"t": int(time.time()), "sprite": a.sprite, "endpoint": path, "seed": seed,
                                "size": [gw, gh], "usd": usd}) + "\n")
        print(f"  seed {seed}: {out_dir}/{seed}.png  (${usd:.4f})")
    preview(old, cands, os.path.join(out_dir, "preview.png"))
    print(f"spent ${spent:.4f}; compare {out_dir}/preview.png, then: python tools/pixellab.py accept {a.sprite} <seed>")


def cmd_kit(a):
    """new standalone asset (not an atlas sprite), e.g. a background building; text only, transparent background.
    Kept as drawn by PixelLab (no palette snap): tools/art/bg2.py tints and quantizes it per layer."""
    spec = json.load(open(os.path.join(HERE, "kit.json"), encoding="utf-8"))
    items = {k: v for k, v in spec["items"].items() if k == a.name or (a.name == "all" and k.startswith(a.prefix or ""))}
    if not items:
        sys.exit(f"no kit item '{a.name}' in tools/art/pixellab/kit.json")
    est = 0.0
    for name, it in items.items():
        w, h = it["size"]
        print(f"{name}: {w}x{h}  {it['prompt'][:90]}")
        est += 0.008 + 0.005 * min(1.0, w * h / 160000)
    print(f"{len(items)} call(s), about ${est:.3f} (or {len(items)} trial generations)")
    if not a.yes:
        print("not sent: add --yes to spend credits")
        return
    os.makedirs(KIT, exist_ok=True)
    for name, it in items.items():
        w, h = it["size"]
        if os.path.exists(os.path.join(KIT, f"{name}.png")) and not a.redo:
            print(f"  {name}: already in kit/, skipped (--redo to replace)")
            continue
        body = {"description": f"{it['prompt']}, {spec['style']}", "image_size": {"width": w, "height": h},
                "no_background": True, "view": "side", "seed": a.seed, "text_guidance_scale": 8.0}
        body.update(spec.get("defaults", {}))
        res = call("create-image-pixflux", body)
        out = os.path.join(KIT, f"{name}.png")
        from_b64(res["image"]).save(out)
        usd = float((res.get("usage") or {}).get("usd") or 0.0)
        os.makedirs(CANDIDATES, exist_ok=True)
        with open(os.path.join(CANDIDATES, "usage.jsonl"), "a", encoding="utf-8") as f:
            f.write(json.dumps({"t": int(time.time()), "kit": name, "seed": a.seed, "size": [w, h], "usd": usd}) + "\n")
        print(f"  {out}")


def cmd_accept(a):
    src = os.path.join(CANDIDATES, a.sprite, f"{a.seed}.png")
    if not os.path.exists(src):
        sys.exit(f"no candidate {src}")
    im = Image.open(src).convert("RGBA")
    if im.size != sprite(a.sprite).size:
        sys.exit(f"candidate is {im.size}, sprite is {sprite(a.sprite).size}")
    os.makedirs(OVERRIDES, exist_ok=True)
    im.save(os.path.join(OVERRIDES, a.sprite + ".png"))
    print(f"override saved: tools/art/pixellab/overrides/{a.sprite}.png; run python tools/generate_pixel_art.py")


def cmd_reject(a):
    p = os.path.join(OVERRIDES, a.sprite + ".png")
    if os.path.exists(p):
        os.remove(p)
        print(f"removed {p}; run python tools/generate_pixel_art.py")
    else:
        print("no override for", a.sprite)


def main():
    ap = argparse.ArgumentParser(description="PixelLab sprite redraws for Mobile Vault")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("balance").set_defaults(fn=cmd_balance)
    p = sub.add_parser("list")
    p.add_argument("prefix", nargs="?")
    p.set_defaults(fn=cmd_list)
    p = sub.add_parser("spec")
    p.add_argument("endpoint")
    p.set_defaults(fn=cmd_spec)
    p = sub.add_parser("gen")
    p.add_argument("sprite")
    p.add_argument("--prompt")
    p.add_argument("--endpoint", choices=sorted(ENDPOINTS), default="pixflux")
    p.add_argument("--seeds", type=int, default=3)
    p.add_argument("--seed", type=int, default=2024, help="first seed")
    p.add_argument("--strength", type=int, default=300, help="init_image_strength 1-999, higher keeps more of the old sprite")
    p.add_argument("--no-init", action="store_true", help="text only, ignore the current sprite")
    p.add_argument("--guidance", type=float, default=8.0)
    p.add_argument("--outline")
    p.add_argument("--shading")
    p.add_argument("--detail")
    p.add_argument("--view")
    p.add_argument("--direction")
    p.add_argument("--no-bg", dest="no_bg", action="store_true", default=None)
    p.add_argument("--with-bg", dest="no_bg", action="store_false")
    p.add_argument("--style", help="bitforge: atlas sprite used as the style reference")
    p.add_argument("--style-strength", type=float, default=40.0)
    p.add_argument("--budget", type=float, default=0.0, help="stop after this many USD")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--yes", action="store_true", help="really call the API (spends credits)")
    p.set_defaults(fn=cmd_gen)
    p = sub.add_parser("kit", help="standalone assets from tools/art/pixellab/kit.json -> tools/art/pixellab/kit/")
    p.add_argument("name", help="item name, or 'all' (with --prefix)")
    p.add_argument("--prefix")
    p.add_argument("--seed", type=int, default=2024)
    p.add_argument("--redo", action="store_true", help="regenerate items that already exist")
    p.add_argument("--yes", action="store_true", help="really call the API (spends credits)")
    p.set_defaults(fn=cmd_kit)
    for name, fn in (("accept", cmd_accept), ("reject", cmd_reject)):
        p = sub.add_parser(name)
        p.add_argument("sprite")
        if name == "accept":
            p.add_argument("seed", type=int)
        p.set_defaults(fn=fn)
    a = ap.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
