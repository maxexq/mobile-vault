// MV-499: Cloudflare Pages serves web/index.wasm from R2 (it is over the 25 MiB Pages file limit). This checks that the
// committed engine is the one recorded in config/engine_wasm.json, the object uploaded to R2, so a Godot upgrade can't
// ship against the old upload. Run: node tools/engine_wasm_check.mjs (CI: Autotest workflow). No packages.
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";

const rec = JSON.parse(readFileSync("config/engine_wasm.json", "utf8"));
const wasm = readFileSync("web/index.wasm");
const sha = createHash("sha256").update(wasm).digest("hex");
if (sha !== rec.sha256 || wasm.length !== rec.bytes) {
  console.log(`FAIL engine: web/index.wasm is ${sha} (${wasm.length} B), config/engine_wasm.json records ${rec.sha256} (${rec.bytes} B).`);
  console.log(`Upload the new web/index.wasm to R2 as a new key (e.g. godot-<version>/index.wasm), then update r2_key, sha256 and bytes.`);
  process.exit(1);
}
console.log(`PASS engine: web/index.wasm matches the R2 record ${rec.r2_key}`);
