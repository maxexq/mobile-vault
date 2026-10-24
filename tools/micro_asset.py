#!/usr/bin/env python3
"""Micro-asset specs: small art pieces planned by the Codex art analyst, built by Claude (Opus).

One micro asset = one sprite (or one short animation strip) with its size, palette, layer, anchor
and acceptance checks written down before anyone draws it. The spec is a JSON file (format in
docs/micro-assets.md) that is validated here and posted as a Plane ticket with label `micro-asset`.

Analyst side (Codex CLI, or by hand):
  python tools/micro_asset.py ref [--prefix room_]          # palette ramps + atlas sprites and sizes
  python tools/micro_asset.py sheet room_medical            # x8 PNG with a pixel grid, for `codex --image`
  python tools/micro_asset.py new prop_med_iv_drip --parent room_medical
  python tools/micro_asset.py check tools/art/micro/drafts/prop_med_iv_drip.json
  python tools/micro_asset.py post  tools/art/micro/drafts/prop_med_iv_drip.json [--epic MV-170] [--dry-run]

Builder side (Claude):
  python tools/micro_asset.py queue                         # Todo micro-asset tickets
  python tools/micro_asset.py pull MV-171                   # spec from the ticket -> drafts/<id>.json
  python tools/micro_asset.py verify MV-171                 # after generate_pixel_art.py: size/palette/frames

Stdlib only for everything except `sheet` and `verify`, which need Pillow (already used by tools/art).
"""
import argparse, html, json, os, re, sys

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(TOOLS)
DRAFTS = os.path.join(TOOLS, "art", "micro", "drafts")
SHEETS = os.path.join(TOOLS, "art", "micro", "sheets")
ATLAS_JSON = os.path.join(ROOT, "assets", "atlas", "atlas.json")
ATLAS_PNG = os.path.join(ROOT, "assets", "atlas", "atlas.png")
SPEC_VERSION = "micro-asset/1"
LABELS = ["micro-asset", "art"]

KINDS = ["prop", "decal", "overlay", "fx", "anim", "icon", "ui", "portrait", "bg"]
LAYERS = ["behind_parent", "on_parent", "above_dwellers", "fx", "ui"]
PIVOTS = ["top-left", "top-center", "center", "bottom-center", "bottom-left", "bottom-right"]
METHODS = ["drawn", "pixellab", "hand"]
LIGHTS = ["none", "top-left", "top", "top-right", "lamp", "emissive"]
SCREENS = ["screen", "ui", "world"]  # parents that are not an atlas sprite
DESIGN = {"screen": (360, 640), "ui": (360, 640), "world": (560, 320)}


# ------------------------------------------------------------------ reference data
def palette():
    """master palette straight from tools/art/common.py (RAMPS), without importing Pillow"""
    src = open(os.path.join(TOOLS, "art", "common.py"), encoding="utf-8").read()
    block = src.split("RAMPS = {", 1)[1].split("\n}", 1)[0]
    pal = {}
    for m in re.finditer(r'"(\w+)":\s*\[([^\]]*)\]', block):
        for i, h in enumerate(re.findall(r'"([0-9a-fA-F]{6})"', m.group(2))):
            pal[f"{m.group(1)}{i}"] = h.lower()
    return pal


def atlas():
    with open(ATLAS_JSON, encoding="utf-8") as f:
        return json.load(f)


def frame_names(spec):
    n = int((spec.get("frames") or {}).get("count", 1))
    return [spec["id"]] if n <= 1 else [f"{spec['id']}_{i}" for i in range(n)]


# ------------------------------------------------------------------ validation
def validate(spec):
    """-> (errors, warnings). Errors block `post`; warnings are printed."""
    err, warn = [], []
    pal, reg = palette(), atlas()
    req = ["spec", "id", "title", "why", "parent", "kind", "size", "palette", "layer", "anchor",
           "generator", "acceptance"]
    for k in req:
        if k not in spec or spec[k] in (None, "", []):
            err.append(f"missing field: {k}")
    if err:
        return err, warn
    if spec["spec"] != SPEC_VERSION:
        err.append(f"spec must be {SPEC_VERSION!r}")
    sid = spec["id"]
    if not re.fullmatch(r"[a-z][a-z0-9_]{2,47}", sid):
        err.append("id: lowercase snake_case, 3-48 chars (it becomes the atlas sprite name)")
    prefixes = {k.split("_")[0] for k in reg}
    if sid.split("_")[0] not in prefixes | {"prop", "decal"}:
        warn.append(f"id prefix {sid.split('_')[0]!r} is new (existing: {', '.join(sorted(prefixes))})")
    if spec["kind"] not in KINDS:
        err.append(f"kind: one of {KINDS}")
    if spec["layer"] not in LAYERS:
        err.append(f"layer: one of {LAYERS}")
    if spec.get("light", "none") not in LIGHTS:
        err.append(f"light: one of {LIGHTS}")

    size = spec["size"]
    if not (isinstance(size, list) and len(size) == 2 and all(isinstance(v, int) and 1 <= v <= 400 for v in size)):
        err.append("size: [w, h] whole pixels, 1-400 (native art pixels, never scaled in game)")
        size = None

    fr = spec.get("frames") or {"count": 1}
    n = fr.get("count", 1)
    if not (isinstance(n, int) and 1 <= n <= 32):
        err.append("frames.count: 1-32")
    elif n > 1:
        if not isinstance(fr.get("fps"), (int, float)) or not 0 < fr["fps"] <= 24:
            err.append("frames.fps: needed for animations, 0-24")
        if "loop" not in fr:
            err.append("frames.loop: true/false")
        if spec["kind"] not in ("anim", "fx", "prop", "overlay"):
            warn.append(f"{n} frames on kind {spec['kind']!r}")

    replace = bool(spec.get("replace"))
    for name in frame_names(spec) if isinstance(n, int) else []:
        if name in reg:
            if not replace:
                err.append(f"{name} already exists in the atlas; pick a new id or set \"replace\": true")
            elif size and reg[name][2:] != size:
                err.append(f"replace: {name} is {reg[name][2]}x{reg[name][3]}; a replacement must keep the size")
        elif replace:
            err.append(f"replace: {name} is not in the atlas")

    cols = spec["palette"]
    bad = [p for p in cols if p not in pal]
    if bad:
        err.append(f"palette: unknown {bad}; use ramp+index names from `micro_asset.py ref` (e.g. orange2, lamp1)")
    if len(set(cols)) > 12:
        warn.append(f"{len(set(cols))} colours is a lot for a micro asset (aim for 4-8)")
    accents = [p for p in cols if p[:-1] in ("lamp", "toxic") or p in ("red3", "red4", "yellow3")]
    if len(accents) > 2:
        warn.append(f"several emissive accents {accents}: the style keeps saturated colour for light sources")
    ol = spec.get("outline")
    if ol and ol not in cols:
        err.append(f"outline {ol!r} must also be listed in palette")

    parent = spec["parent"]
    if parent in reg:
        pw, ph = reg[parent][2:]
    elif parent in SCREENS:
        pw, ph = DESIGN[parent]
    else:
        err.append(f"parent: an atlas sprite (see `ref`) or one of {SCREENS}")
        pw = ph = None
    an = spec["anchor"]
    if not (isinstance(an, dict) and isinstance(an.get("x"), int) and isinstance(an.get("y"), int)):
        err.append("anchor: {\"x\": int, \"y\": int, \"pivot\": ...} in the parent's pixels")
    elif an.get("pivot", "bottom-center") not in PIVOTS:
        err.append(f"anchor.pivot: one of {PIVOTS}")
    elif pw and size:
        x0, y0 = box(an, size)
        if not (0 <= an["x"] <= pw and 0 <= an["y"] <= ph):
            err.append(f"anchor ({an['x']},{an['y']}) is outside {parent} ({pw}x{ph})")
        elif x0 < 0 or y0 < 0 or x0 + size[0] > pw or y0 + size[1] > ph:
            warn.append(f"sprite box {x0},{y0} {size[0]}x{size[1]} sticks out of {parent} ({pw}x{ph})")

    g = spec["generator"]
    if not isinstance(g, dict) or g.get("method") not in METHODS:
        err.append(f"generator.method: one of {METHODS}")
    else:
        mod = g.get("module", "")
        if g["method"] == "drawn" and not os.path.exists(os.path.join(ROOT, mod)):
            err.append(f"generator.module {mod!r} not found (e.g. tools/art/rooms.py)")
        if g["method"] == "pixellab":
            warn.append("pixellab costs Parames's credits: Claude must show --dry-run and get an OK first")
    for r in spec.get("refs", []):
        if not r.startswith("http") and not os.path.exists(os.path.join(ROOT, r)):
            warn.append(f"ref {r!r} is not in the repo (fine if it is a Plane/project file)")
    if not isinstance(spec["acceptance"], list) or len(spec["acceptance"]) < 2:
        err.append("acceptance: at least 2 checkable bullet points")
    return err, warn


def box(an, size):
    w, h = size
    pv = an.get("pivot", "bottom-center")
    ox = {"top-left": 0, "bottom-left": 0, "bottom-right": w}.get(pv, w // 2)
    oy = 0 if pv.startswith("top") else (h // 2 if pv == "center" else h)
    return an["x"] - ox, an["y"] - oy


# ------------------------------------------------------------------ ticket text
SPEC_TAG = "micro-asset-spec"


def to_html(spec):
    e = html.escape
    fr = spec.get("frames") or {"count": 1}
    pal = palette()
    w, h = spec["size"]
    an = spec["anchor"]
    rows = [
        ("Sprite", ", ".join(frame_names(spec))),
        ("Size", f"{w}x{h} px native" + (f", {fr['count']} frames @ {fr.get('fps')} fps, loop={fr.get('loop')}"
                                         if fr.get("count", 1) > 1 else "")),
        ("Parent / layer", f"{spec['parent']} / {spec['layer']}"),
        ("Anchor", f"x={an['x']} y={an['y']} pivot={an.get('pivot', 'bottom-center')} (parent pixels)"),
        ("Palette", ", ".join(f"{p} #{pal.get(p, '??????')}" for p in spec["palette"])),
        ("Outline / light", f"{spec.get('outline') or 'none'} / {spec.get('light', 'none')}"),
        ("Generator", f"{spec['generator'].get('method')} {spec['generator'].get('module', '')} "
                      f"{spec['generator'].get('function', '')}".strip()),
        ("Feature gate", spec.get("feature") or "none (art-only change)"),
    ]
    out = [f"<p><strong>{e(spec['title'])}</strong></p>", f"<p>{e(spec['why'])}</p>", "<ul>"]
    out += [f"<li><strong>{e(k)}:</strong> {e(str(v))}</li>" for k, v in rows]
    out.append("</ul><p><strong>Acceptance</strong></p><ul>")
    out += [f"<li>{e(a)}</li>" for a in spec["acceptance"]]
    out.append("</ul>")
    if spec.get("refs"):
        out.append("<p><strong>References:</strong> " + ", ".join(e(r) for r in spec["refs"]) + "</p>")
    if spec.get("notes"):
        out.append(f"<p><strong>Notes:</strong> {e(spec['notes'])}</p>")
    out.append(f"<p>Spec by {e(spec.get('author', 'Codex art analyst'))}. Build: "
               "<code>python tools/micro_asset.py pull MV-n</code>, then docs/micro-assets.md.</p>")
    out.append(f"<pre><code>{SPEC_TAG}\n{e(json.dumps(spec, ensure_ascii=False, indent=1))}</code></pre>")
    return "".join(out)


def from_html(desc):
    m = re.search(r"<code[^>]*>\s*" + SPEC_TAG + r"\s*(.*?)</code>", desc or "", re.S)
    if not m:
        raise SystemExit("no micro-asset-spec block in this ticket")
    txt = html.unescape(re.sub(r"<br\s*/?>", "\n", re.sub(r"</?(p|span)[^>]*>", "", m.group(1))))
    return json.loads(txt)


# ------------------------------------------------------------------ commands
def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def report(spec):
    err, warn = validate(spec)
    for w in warn:
        print("  warn:", w)
    for x in err:
        print("  ERROR:", x)
    return not err


def cmd_ref(a):
    pal = palette()
    ramps = {}
    for k, v in pal.items():
        ramps.setdefault(k.rstrip("0123456789"), []).append(f"{k}=#{v}")
    print("master palette (dark -> light), use these names in \"palette\":")
    for r, v in ramps.items():
        print(f"  {r:7} " + " ".join(v))
    print("\natlas sprites (name WxH):")
    for k, v in sorted(atlas().items()):
        if not a.prefix or k.startswith(a.prefix):
            print(f"  {k:28} {v[2]}x{v[3]}")


def cmd_sheet(a):
    from PIL import Image, ImageDraw
    reg = atlas()
    if a.sprite not in reg:
        raise SystemExit(f"{a.sprite} not in the atlas (see `ref`)")
    x, y, w, h = reg[a.sprite]
    s = a.scale
    im = Image.open(ATLAS_PNG).convert("RGBA").crop((x, y, x + w, y + h))
    big = Image.new("RGBA", (w * s + 1, h * s + 1), (40, 40, 44, 255))
    big.alpha_composite(im.resize((w * s, h * s), Image.NEAREST))
    grid = Image.new("RGBA", big.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(grid)
    for i in range(0, w + 1):
        d.line([(i * s, 0), (i * s, h * s)], fill=(255, 255, 255, 140 if i % 8 == 0 else 22))
    for j in range(0, h + 1):
        d.line([(0, j * s), (w * s, j * s)], fill=(255, 255, 255, 140 if j % 8 == 0 else 22))
    big.alpha_composite(grid)
    os.makedirs(SHEETS, exist_ok=True)
    out = os.path.join(SHEETS, f"{a.sprite}_x{s}.png")
    big.save(out)
    print(f"{out}\n{w}x{h} px, scale x{s}, bright grid line every 8 px (pixel 0,0 = top-left)")


def cmd_new(a):
    spec = {
        "spec": SPEC_VERSION, "id": a.id, "title": "", "why": "", "parent": a.parent, "kind": "prop",
        "size": [8, 8], "frames": {"count": 1}, "palette": ["ol0"], "outline": "ol0", "light": "lamp",
        "layer": "on_parent", "anchor": {"x": 32, "y": 46, "pivot": "bottom-center"},
        "generator": {"method": "drawn", "module": "tools/art/rooms.py", "function": ""},
        "feature": None, "refs": [], "acceptance": [], "notes": "", "author": "Codex art analyst",
    }
    os.makedirs(DRAFTS, exist_ok=True)
    out = os.path.join(DRAFTS, a.id + ".json")
    if os.path.exists(out):
        raise SystemExit(f"{out} exists")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(spec, f, ensure_ascii=False, indent=2)
    print(out)


def cmd_check(a):
    ok = True
    for p in a.files:
        print(p)
        ok = report(load(p)) and ok
    print("ok" if ok else "fix the errors above")
    sys.exit(0 if ok else 1)


def cmd_post(a):
    spec = load(a.file)
    if not report(spec):
        raise SystemExit("not posted: fix the errors above")
    title = f"[micro] {spec['id']}: {spec['title']}"
    if a.dry_run:
        print(f"would create (state Todo, labels {LABELS}): {title}\n{to_html(spec)}")
        return
    sys.path.insert(0, TOOLS)
    import plane
    lb = plane.labels()
    missing = [l for l in LABELS if l not in lb]
    if missing:
        raise SystemExit(f"Plane labels missing: {missing}")
    body = {"name": title, "state": plane.state_id("Todo"), "priority": spec.get("priority", "medium"),
            "labels": [lb[l] for l in LABELS], "description_html": to_html(spec),
            "external_source": plane.SRC, "external_id": f"micro-{spec['id']}"}
    if a.epic:
        body["parent"] = plane.item(a.epic)["id"]
    i = plane.api("POST", f"{plane.PJ}/work-items/", body)
    spec["plane"] = plane.ref_of(i)
    with open(a.file, "w", encoding="utf-8") as f:
        json.dump(spec, f, ensure_ascii=False, indent=2)
    print(f"{plane.ref_of(i)} created: {plane.url_of(i)}")


def cmd_queue(a):
    sys.path.insert(0, TOOLS)
    import plane
    lid = plane.labels().get("micro-asset")
    st = {v: k for k, v in plane.states().items()}
    for i in plane.results(plane.api("GET", f"{plane.PJ}/work-items/?per_page=100&order_by=-updated_at")):
        s = st.get(i.get("state"), "?")
        if lid in (i.get("labels") or []) and (a.all or s == "Todo"):
            print(f"{plane.ref_of(i):7} {s:12} {i['name']}")


def fetch(ref):
    sys.path.insert(0, TOOLS)
    import plane
    i = plane.item(ref)
    spec = from_html(i.get("description_html"))
    spec["plane"] = plane.ref_of(i)
    return spec


def cmd_pull(a):
    spec = fetch(a.ref)
    os.makedirs(DRAFTS, exist_ok=True)
    out = os.path.join(DRAFTS, spec["id"] + ".json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(spec, f, ensure_ascii=False, indent=2)
    print(json.dumps(spec, ensure_ascii=False, indent=2))
    print(f"\nsaved {out}")


def cmd_verify(a):
    from PIL import Image
    spec = load(a.ref) if a.ref.endswith(".json") else fetch(a.ref)
    reg, pal = atlas(), palette()
    allowed = {tuple(int(pal[p][i:i + 2], 16) for i in (0, 2, 4)) for p in spec["palette"] if p in pal}
    sheet = Image.open(ATLAS_PNG).convert("RGBA")
    ok = True
    for name in frame_names(spec):
        if name not in reg:
            print(f"  FAIL {name}: not in the atlas (run tools/generate_pixel_art.py)")
            ok = False
            continue
        x, y, w, h = reg[name]
        if [w, h] != spec["size"]:
            print(f"  FAIL {name}: {w}x{h}, spec says {spec['size'][0]}x{spec['size'][1]}")
            ok = False
        used = {p[:3] for _, p in sheet.crop((x, y, x + w, y + h)).getcolors(w * h) if p[3] > 0}
        extra = used - allowed
        if extra:
            inv = {tuple(int(v[i:i + 2], 16) for i in (0, 2, 4)): k for k, v in pal.items()}
            names = sorted(inv.get(c, "#%02x%02x%02x" % c) for c in extra)
            print(f"  FAIL {name}: colours outside the spec palette: {names}")
            ok = False
        else:
            print(f"  ok   {name}: {w}x{h}, {len(used)} colours, all in spec palette")
    print("verified" if ok else "not matching the spec")
    sys.exit(0 if ok else 1)


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    p = argparse.ArgumentParser(description="Micro-asset specs (Codex analyst -> Plane -> Claude)")
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("ref"); s.add_argument("--prefix"); s.set_defaults(f=cmd_ref)
    s = sub.add_parser("sheet"); s.add_argument("sprite"); s.add_argument("--scale", type=int, default=8)
    s.set_defaults(f=cmd_sheet)
    s = sub.add_parser("new"); s.add_argument("id"); s.add_argument("--parent", default="room_empty")
    s.set_defaults(f=cmd_new)
    s = sub.add_parser("check"); s.add_argument("files", nargs="+"); s.set_defaults(f=cmd_check)
    s = sub.add_parser("post"); s.add_argument("file"); s.add_argument("--epic"); s.add_argument("--dry-run", action="store_true")
    s.set_defaults(f=cmd_post)
    s = sub.add_parser("queue"); s.add_argument("--all", action="store_true"); s.set_defaults(f=cmd_queue)
    s = sub.add_parser("pull"); s.add_argument("ref"); s.set_defaults(f=cmd_pull)
    s = sub.add_parser("verify"); s.add_argument("ref", help="MV-n or a spec .json"); s.set_defaults(f=cmd_verify)
    a = p.parse_args()
    a.f(a)


if __name__ == "__main__":
    main()
