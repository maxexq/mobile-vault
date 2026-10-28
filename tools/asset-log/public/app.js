// PixelLab asset log UI (MV-584). Talks to /api (functions/api/[[route]].js); no build step, no libraries.
"use strict";

const $ = (s, el = document) => el.querySelector(s);
const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
const img = (key) => (key ? `api/img?key=${encodeURIComponent(key)}` : "");
const when = (t) => (t ? new Date(t * 1000).toLocaleString("th-TH", { dateStyle: "short", timeStyle: "short" }) : "");
const usd = (v) => `$${(+v || 0).toFixed(4)}`;

const state = { meta: {}, palette: new Set(), atlas: null, atlasImg: null, offset: 0, current: null, items: new Map() };

async function api(path, opts = {}) {
  const r = await fetch(`api/${path}`, { credentials: "same-origin", ...opts });
  const data = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(data.error || `HTTP ${r.status}`);
  return data;
}

function toast(msg) {
  const t = $("#toast");
  t.textContent = msg;
  t.hidden = false;
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => (t.hidden = true), 2600);
}

function loadImage(src) {
  return new Promise((ok, bad) => {
    const im = new Image();
    im.onload = () => ok(im);
    im.onerror = () => bad(new Error(`image ${src}`));
    im.src = src;
  });
}

// --- tabs ----------------------------------------------------------------------------------------------------

const loaders = { gallery: () => loadGallery(true), review: loadReview, prompts: loadPrompts, dashboard: loadDashboard };

$("#tabs").addEventListener("click", (e) => {
  const b = e.target.closest("button[data-tab]");
  if (!b) return;
  for (const x of $("#tabs").children) x.classList.toggle("on", x === b);
  for (const s of document.querySelectorAll(".tab")) s.classList.toggle("on", s.id === `tab-${b.dataset.tab}`);
  try { localStorage.setItem("tab", b.dataset.tab); } catch {}
  loaders[b.dataset.tab]();
});

// --- gallery -------------------------------------------------------------------------------------------------

function card(g) {
  state.items.set(g.id, g);
  const scale = +$("#filters").scale.value;
  const warn = (g.off_palette > 0 ? ` <span class="warn" title="pixels outside the palette">●${g.off_palette}</span>` : "") +
    (g.size_ok === 0 ? ` <span class="warn" title="size mismatch">size</span>` : "");
  return `<button class="card" data-id="${esc(g.id)}">
    <div class="pix">${g.key_snapped ? `<img loading="lazy" src="${img(g.key_snapped)}" width="${g.w * scale}" height="${g.h * scale}" alt="">` : "<span class='muted'>no image</span>"}</div>
    <div class="name" title="${esc(g.sprite)}">${esc(g.sprite)}</div>
    <div class="sub"><span>seed ${g.seed} · ${usd(g.usd)}${warn}</span><span class="chip ${g.status}">${g.status}</span></div>
    <div class="sub"><span>${when(g.t)}</span><span>${esc(g.endpoint.replace("create-image-", ""))}</span></div>
  </button>`;
}

async function loadGallery(reset) {
  const f = $("#filters");
  if (reset) state.offset = 0;
  const q = new URLSearchParams({ limit: 60, offset: state.offset, order: f.order.value });
  for (const k of ["q", "prefix", "status"]) if (f[k].value) q.set(k, f[k].value);
  try {
    const { items, more } = await api(`generations?${q}`);
    const html = items.map(card).join("");
    $("#grid").innerHTML = reset ? html || `<p class="empty">ยังไม่มีภาพ รัน <code>python tools/asset_log.py sync</code> หลัง gen</p>` : $("#grid").innerHTML + html;
    state.offset += items.length;
    $("#more").hidden = !more;
  } catch (e) {
    $("#grid").innerHTML = `<p class="empty">${esc(e.message)}</p>`;
  }
}

let typing;
$("#filters").addEventListener("input", (e) => {
  clearTimeout(typing);
  typing = setTimeout(() => loadGallery(true), e.target.type === "search" ? 300 : 0);
});
$("#filters").addEventListener("submit", (e) => e.preventDefault());
$("#more").addEventListener("click", () => loadGallery(false));
document.addEventListener("click", (e) => {
  const c = e.target.closest(".card[data-id]");
  if (c) openDetail(c.dataset.id);
});

// --- review queue --------------------------------------------------------------------------------------------

async function loadReview() {
  try {
    const { items } = await api("generations?status=new&order=old&limit=200");
    items.sort((a, b) => a.sprite.localeCompare(b.sprite) || a.t - b.t || a.seed - b.seed);
    $("#review-grid").innerHTML = items.map(card).join("") || `<p class="empty">ไม่มีงานรอตัดสิน</p>`;
    $("#review-count").textContent = items.length || "";
  } catch (e) {
    $("#review-grid").innerHTML = `<p class="empty">${esc(e.message)}</p>`;
  }
}

// --- detail / compare ----------------------------------------------------------------------------------------

function paint(canvas, source, w, h, sx = 0, sy = 0) {
  const scale = +$("#d-scale").value;
  canvas.width = w * scale;
  canvas.height = h * scale;
  const ctx = canvas.getContext("2d");
  ctx.imageSmoothingEnabled = false;
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  if (!source) return null;
  const sw = source.naturalWidth === w || sx || sy ? w : source.naturalWidth;
  const sh = source.naturalHeight === h || sx || sy ? h : source.naturalHeight;
  ctx.drawImage(source, sx, sy, sw, sh, 0, 0, canvas.width, canvas.height);
  return ctx;
}

function offPalette(source, w, h) {
  // counts and marks pixels whose RGB is not in the master palette (alpha 0 is ignored)
  if (!state.palette.size || !source) return { count: null, mask: [] };
  const c = document.createElement("canvas");
  c.width = w; c.height = h;
  const ctx = c.getContext("2d");
  ctx.drawImage(source, 0, 0, w, h);
  const d = ctx.getImageData(0, 0, w, h).data;
  const mask = [];
  let semi = 0;
  for (let i = 0; i < w * h; i++) {
    const a = d[i * 4 + 3];
    if (!a) continue;
    if (a < 255) semi++;
    const hex = ((d[i * 4] << 16) | (d[i * 4 + 1] << 8) | d[i * 4 + 2]).toString(16).padStart(6, "0");
    if (!state.palette.has(hex)) mask.push(i);
  }
  return { count: mask.length, mask, semi };
}

function overlay(ctx, mask, w) {
  const s = +$("#d-scale").value;
  if ($("#d-offpal").checked) {
    ctx.fillStyle = "rgba(255, 0, 255, .85)";
    for (const i of mask) ctx.fillRect((i % w) * s, Math.floor(i / w) * s, s, s);
  }
  if ($("#d-grid").checked && s >= 4) {
    ctx.fillStyle = "rgba(255, 255, 255, .08)";
    for (let x = 0; x < ctx.canvas.width; x += s) ctx.fillRect(x, 0, 1, ctx.canvas.height);
    for (let y = 0; y < ctx.canvas.height; y += s) ctx.fillRect(0, y, ctx.canvas.width, 1);
  }
}

async function ensureAtlas() {
  const a = state.meta.atlas?.value;
  if (!a || state.atlas) return;
  try {
    const [regions, im] = await Promise.all([fetch(img(a.json_key)).then((r) => r.json()), loadImage(img(a.png_key))]);
    state.atlas = regions;
    state.atlasImg = im;
  } catch { /* family strip stays empty */ }
}

async function renderDetail() {
  const g = state.current;
  if (!g) return;
  const [cur, snap, raw] = await Promise.all([g.key_current, g.key_snapped, g.key_raw].map((k) => (k ? loadImage(img(k)).catch(() => null) : null)));
  paint($("#c-current"), cur, g.w, g.h);
  const sctx = paint($("#c-snapped"), snap, g.w, g.h);
  const scale = +$("#d-scale").value;
  const rc = $("#c-raw");
  if (raw) {
    // raw is gen_w x gen_h; show it at the same on-screen size as the native sprites
    rc.width = g.w * scale; rc.height = g.h * scale;
    const ctx = rc.getContext("2d");
    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(raw, 0, 0, rc.width, rc.height);
  } else paint(rc, null, g.w, g.h);

  const pal = offPalette(snap, g.w, g.h);
  if (sctx) overlay(sctx, pal.mask, g.w);
  const sizeOk = snap && snap.naturalWidth === g.w && snap.naturalHeight === g.h;
  const checks = [
    [sizeOk, `ขนาด ${snap ? `${snap.naturalWidth}x${snap.naturalHeight}` : "?"} / ${g.w}x${g.h}`],
    [pal.count === 0, pal.count === null ? "palette: ยังไม่มี snapshot" : `สีนอก palette: ${pal.count} px`],
    [!pal.semi, `alpha ครึ่งโปร่ง: ${pal.semi ?? "?"} px`],
    [!g.prompt_guess, g.prompt_guess ? "prompt เดาจาก prompts.json (log เก่า)" : "prompt จาก log จริง"],
  ];
  $("#d-checks").innerHTML = checks.map(([ok, t]) => `<span class="${ok ? "pass" : "fail"}">${ok ? "✓" : "✕"} ${esc(t)}</span>`).join("");

  await ensureAtlas();
  const fam = $("#d-family");
  fam.innerHTML = "";
  if (state.atlas) {
    const names = Object.keys(state.atlas)
      .filter((n) => n !== g.sprite && n.startsWith(g.prefix) && state.atlas[n][2] === g.w && state.atlas[n][3] === g.h)
      .sort().slice(0, 14);
    for (const n of names) {
      const [x, y, w, h] = state.atlas[n];
      const f = document.createElement("figure");
      const c = document.createElement("canvas");
      f.append(c);
      f.insertAdjacentHTML("beforeend", `<figcaption title="${esc(n)}">${esc(n)}</figcaption>`);
      fam.append(f);
      paint(c, state.atlasImg, w, h, x, y);
    }
    if (!names.length) fam.innerHTML = `<span class="muted">ไม่มี sprite อื่นขนาด ${g.w}x${g.h} ในกลุ่ม ${esc(g.prefix)}</span>`;
  } else fam.innerHTML = `<span class="muted">ยังไม่มี atlas snapshot</span>`;
}

async function openDetail(id) {
  let g = state.items.get(id);
  try { g = await api(`generations/${encodeURIComponent(id)}`); } catch { /* use the list copy */ }
  if (!g) return;
  state.current = g;
  $("#d-title").textContent = `${g.sprite} · seed ${g.seed}`;
  $("#d-prompt").textContent = g.prompt || "(ไม่มี prompt)";
  $("#d-neg").textContent = g.negative ? `negative: ${g.negative}` : "";
  $("#d-neg-wrap").hidden = !g.negative;
  let params = {};
  try { params = JSON.parse(g.params || "{}"); } catch {}
  $("#d-params").textContent = [`${g.endpoint} · ${g.gen_w}x${g.gen_h} → ${g.w}x${g.h} · ${usd(g.usd)} · ${when(g.t)}`,
    ...Object.entries(params).map(([k, v]) => `${k}: ${typeof v === "object" ? JSON.stringify(v) : v}`)].join("\n");
  $("#d-cmd").textContent = `python tools/pixellab.py gen ${g.sprite} --seed ${g.seed} --seeds 1 --endpoint ${g.endpoint.replace("create-image-", "")}` +
    (params.strength ? ` --strength ${params.strength}` : "") + (params.no_init ? " --no-init" : "") + " --dry-run";
  $("#d-note").value = g.note || "";
  showReviewed(g);
  if (!$("#detail").open) $("#detail").showModal();
  renderDetail();
}

function showReviewed(g) {
  $("#d-reviewed").innerHTML = `<span class="chip ${g.status}">${g.status}</span> ${g.reviewed_by ? `${esc(g.reviewed_by)} · ${when(g.reviewed_at)}` : ""}`;
}

async function setReview(status) {
  const g = state.current;
  if (!g) return;
  try {
    const body = { note: $("#d-note").value };
    if (status) body.status = status;
    const row = await api(`generations/${encodeURIComponent(g.id)}/review`, {
      method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body),
    });
    state.current = row;
    state.items.set(row.id, row);
    showReviewed(row);
    const el = document.querySelector(`.card[data-id="${CSS.escape(row.id)}"] .chip`);
    if (el) { el.className = `chip ${row.status}`; el.textContent = row.status; }
    toast(status ? `${row.sprite} seed ${row.seed}: ${row.status}` : "บันทึกโน้ตแล้ว");
    if ($("#tab-review").classList.contains("on")) loadReview();
  } catch (e) {
    toast(e.message);
  }
}

$("#d-approve").addEventListener("click", () => setReview("approved"));
$("#d-reject").addEventListener("click", () => setReview("rejected"));
$("#d-reset").addEventListener("click", () => setReview("new"));
$("#d-save").addEventListener("click", () => setReview(null));
$("#d-close").addEventListener("click", () => $("#detail").close());
$("#detail").addEventListener("click", (e) => { if (e.target === $("#detail")) $("#detail").close(); });
for (const id of ["d-scale", "d-offpal", "d-grid"]) $(`#${id}`).addEventListener("change", renderDetail);

document.addEventListener("click", async (e) => {
  const b = e.target.closest("[data-copy]");
  if (!b) return;
  const el = document.getElementById(b.dataset.copy);
  const text = el ? el.textContent.replace(/^negative: /, "") : b.dataset.text;
  try { await navigator.clipboard.writeText(text); toast("คัดลอกแล้ว"); } catch { toast("คัดลอกไม่ได้"); }
});

// --- prompts library -----------------------------------------------------------------------------------------

async function loadPrompts() {
  const q = $("#prompt-filter").q.value;
  try {
    const { items } = await api(`prompts?q=${encodeURIComponent(q)}`);
    $("#prompt-list").innerHTML = items.map((p, i) => `<div class="prompt-item">
      ${p.key ? `<img loading="lazy" src="${img(p.key)}" alt="">` : ""}
      <div class="body">
        <pre id="p-${i}">${esc(p.prompt)}</pre>
        ${p.negative ? `<pre class="muted">negative: ${esc(p.negative)}</pre>` : ""}
        <div class="muted">${p.n} ครั้ง · approved ${p.ok || 0} · rejected ${p.bad || 0} · ล่าสุด ${when(p.last)}</div>
        <div class="muted">${esc((p.sprites || "").split(",").join(", "))}</div>
        <button class="ghost" data-copy="p-${i}">Copy prompt</button>
      </div></div>`).join("") || `<p class="empty">ยังไม่มี prompt</p>`;
  } catch (e) {
    $("#prompt-list").innerHTML = `<p class="empty">${esc(e.message)}</p>`;
  }
}
$("#prompt-filter").addEventListener("input", () => { clearTimeout(typing); typing = setTimeout(loadPrompts, 300); });
$("#prompt-filter").addEventListener("submit", (e) => e.preventDefault());

// --- cost dashboard ------------------------------------------------------------------------------------------

async function loadDashboard() {
  try {
    const s = await api("stats");
    const bal = state.meta.balance?.value;
    const by = Object.fromEntries(s.statuses.map((x) => [x.status, x.n]));
    const balText = bal ? (bal.usd ?? bal.credits ?? bal.balance ?? JSON.stringify(bal)) : "–";
    $("#kpis").innerHTML = [
      [usd(s.total.usd), "ใช้ไปทั้งหมด"],
      [s.total.n || 0, "จำนวน generation"],
      [typeof balText === "number" ? `$${balText.toFixed(2)}` : esc(balText), `เครดิตคงเหลือ${state.meta.balance ? ` (${when(state.meta.balance.t)})` : ""}`],
      [by.new || 0, "รอตัดสิน"],
      [(by.approved || 0) + (by.accepted || 0), "approved / accepted"],
      [by.rejected || 0, "rejected"],
    ].map(([v, l]) => `<div class="kpi"><b>${v}</b><span>${l}</span></div>`).join("");
    const days = [...s.days].reverse();
    const max = Math.max(0.0001, ...days.map((d) => d.usd || 0));
    $("#day-chart").innerHTML = days.map((d) =>
      `<div class="bar" style="height:${Math.max(1, ((d.usd || 0) / max) * 100)}%" title="${d.day}: ${usd(d.usd)} · ${d.n} calls"></div>`).join("") ||
      `<span class="muted">ยังไม่มีข้อมูล</span>`;
    $("#sprite-table tbody").innerHTML = s.sprites.map((r) =>
      `<tr><td>${esc(r.sprite)}</td><td>${r.n}</td><td>${r.ok || 0}</td><td>${usd(r.usd)}</td><td>${when(r.last)}</td></tr>`).join("");
  } catch (e) {
    $("#kpis").innerHTML = `<p class="empty">${esc(e.message)}</p>`;
  }
}

// --- boot ----------------------------------------------------------------------------------------------------

(async function boot() {
  try {
    const me = await api("me");
    $("#me").textContent = me.user;
  } catch (e) {
    $("#me").textContent = e.message;
  }
  try {
    state.meta = await api("meta");
    for (const hex of state.meta.palette?.value || []) state.palette.add(hex.replace("#", "").toLowerCase());
    const sel = $("#filters").prefix;
    for (const p of state.meta.prefixes || []) sel.insertAdjacentHTML("beforeend", `<option value="${esc(p.prefix)}">${esc(p.prefix)} (${p.n})</option>`);
  } catch { /* meta is optional */ }
  let tab = "gallery";
  try { tab = localStorage.getItem("tab") || tab; } catch {}
  const b = document.querySelector(`#tabs button[data-tab="${tab}"]`) || document.querySelector("#tabs button");
  b.click();
  api("generations?status=new&limit=200").then(({ items, more }) => ($("#review-count").textContent = items.length ? `${items.length}${more ? "+" : ""}` : "")).catch(() => {});
})();
