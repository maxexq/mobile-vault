#!/usr/bin/env python3
"""Turn the Web export in web/ into the claude.ai playable artifact, so both show the same page.

The artifact host caps single files at 15 MB, so index.wasm and index.pck are published gzipped
as engine.wasm / pack.wasm, and a small fetch shim (put where the shell has <!--BOOT_SHIM-->)
answers Godot's own fetch("index.wasm"/"index.pck") with the decompressed stream. Everything
else, boot card included, comes from web/index.html, i.e. tools/web_shell.html.

    python3 tools/artifact_html.py [--web web] [--out build/artifact]

Then publish <out>/index.html with every other file in <out> (boot/ sprites included).
"""
import argparse
import gzip
import json
import os
import shutil

SHIM = """<script src="https://cdnjs.cloudflare.com/ajax/libs/pako/2.1.0/pako_inflate.min.js"></script>
<script>
// Artifact hosting shim (tools/artifact_html.py): index.wasm / index.pck are served gzipped.
(function () {
  const realFetch = window.fetch.bind(window);
  const MAP = %(map)s;
  const loaded = {};
  const fill = document.getElementById("fill");
  const bytes = document.getElementById("bytes");
  let totalGz = 0;
  for (const k in MAP) totalGz += MAP[k].gz;

  function report() {
    let sum = 0;
    for (const k in loaded) sum += loaded[k];
    fill.style.width = Math.min(100, sum / totalGz * 100).toFixed(1) + "%%";
    bytes.textContent = (sum / 1048576).toFixed(1) + " / " + (totalGz / 1048576).toFixed(1) + " MB";
  }
  window.bootShimProgress = report;

  function counted(body, key) {
    let n = 0;
    return body.pipeThrough(new TransformStream({
      transform(chunk, ctrl) { n += chunk.byteLength; loaded[key] = n; report(); ctrl.enqueue(chunk); },
    }));
  }

  async function inflate(key, entry) {
    const res = await realFetch(entry.file, { credentials: "same-origin" });
    if (!res.ok) throw new Error("โหลดไฟล์ " + entry.file + " ไม่สำเร็จ (HTTP " + res.status + ")");
    const headers = { "Content-Type": entry.type };
    if ("DecompressionStream" in window && "TransformStream" in window) {
      const stream = counted(res.body, key).pipeThrough(new DecompressionStream("gzip"));
      return new Response(stream, { status: 200, headers });
    }
    // older Safari: buffer + pako
    const buf = new Uint8Array(await res.arrayBuffer());
    loaded[key] = buf.byteLength; report();
    return new Response(window.pako.inflate(buf), { status: 200, headers });
  }

  window.fetch = function (input, init) {
    const url = typeof input === "string" ? input : (input && input.url) || "";
    const name = url.split("?")[0].split("/").pop();
    if (MAP[name]) return inflate(name, MAP[name]);
    return realFetch(input, init);
  };
  report();
})();
</script>"""

GZIPPED = {"index.wasm": ("engine.wasm", "application/wasm"), "index.pck": ("pack.wasm", "application/octet-stream")}
COPIED = ["index.js", "logo.png", "boot/sky.png", "boot/sun.png", "boot/far.png", "boot/mid.png",
          "boot/near.png", "boot/road.png", "boot/bus.png", "boot/walker.png", "features.json", "index.audio.worklet.js", "index.audio.position.worklet.js"]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--web", default="web")
    ap.add_argument("--out", default="build/artifact")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    html = open(os.path.join(a.web, "index.html"), encoding="utf-8").read()
    if "<!--BOOT_SHIM-->" not in html:
        raise SystemExit("web/index.html has no <!--BOOT_SHIM--> marker: export with tools/web_shell.html first")
    shim_map = {}
    for src, (dst, mime) in GZIPPED.items():
        out = os.path.join(a.out, dst)
        with open(os.path.join(a.web, src), "rb") as f, open(out, "wb") as raw, \
                gzip.GzipFile(fileobj=raw, mode="wb", compresslevel=9, mtime=0) as g:
            shutil.copyfileobj(f, g)
        shim_map[src] = {"file": dst, "type": mime, "gz": os.path.getsize(out)}
    for name in COPIED:
        if os.path.exists(os.path.join(a.web, name)):
            os.makedirs(os.path.dirname(os.path.join(a.out, name)), exist_ok=True)
            shutil.copy2(os.path.join(a.web, name), os.path.join(a.out, name))
    html = html.replace("<!--BOOT_SHIM-->", SHIM % {"map": json.dumps(shim_map)})
    # Google sign-in can't run inside the artifact frame; the game offers the Vercel page instead.
    html = html.replace('"ล็อกอินด้วย Gmail เพื่อเล่นต่อข้ามเครื่องได้ (หน้าแรก / ตั้งค่า > เซฟ)",',
                        '"ล็อกอินด้วย Gmail เพื่อเล่นต่อข้ามเครื่องได้ แต่ต้องเปิดเกมบนเว็บโดยตรง ไม่ใช่ในหน้านี้",')
    open(os.path.join(a.out, "index.html"), "w", encoding="utf-8").write(html)
    for k, v in shim_map.items():
        print(f"{k} -> {v['file']} {v['gz'] / 1048576:.1f} MB gz")
    print("wrote", os.path.join(a.out, "index.html"))


if __name__ == "__main__":
    main()
