# Apocarlypse: Mobile Vault — Project Context (handoff)

> เอกสารนี้สรุปทุกอย่างที่ต้องรู้เพื่อทำงานต่อกับเกม Mobile Vault ในโปรเจกต์ใหม่
> สถานะ ณ 22 ต.ค. 2026 · เวอร์ชันเกม **v4.2** · commit ล่าสุด `dd19fc1` บน `main`

---

## 1. ภาพรวม

**Apocarlypse: Mobile Vault** (เดิมชื่อ Mobile Vault — Project: Survival) คือเกม idle survival / management บน **Mobile Web (HTML5)**
ผู้เล่นคุมรถบ้านหุ้มเกราะที่วิ่งข้ามโลกล่มสลาย ภายในรถแบ่งเป็นห้องแบบผ่าซีก (ฟีลเกม Fallout Shelter)

ระบบหลักในเกม:
- **บริหารลูกเรือและห้อง:** ผลิตอาหาร น้ำ ไฟ เศษเหล็ก น้ำมัน และ craft ของ
- **ต่อสู้ idle แบบ Taskbar Hero:** ทีม 3 ตำแหน่งยิงซอมบี้ที่ไล่หลังรถ มีเวฟและบอส
- **ของสวมใส่:** ลูกเรือมี 6 ช่อง ของมี rarity 6 ระดับ
- **การเดินทาง:** 6 Biome มีด่านตรวจและบอสด่าน มีอีเว้นต์สุ่มบนถนน
- **สภาพอากาศและภัย:** ระบบอากาศกับภัยประจำโซน
- **พัฒนาตัวละครและรถ:** skill tree, trait, มอดรถ
- **สำรวจ:** ส่งทีม 2–3 คนลงไปตามจุดสำรวจ
- **Prestige:** ไต่ลำดับรถ van → bus → rig 18 ล้อ → armoured train พ่วงได้สูงสุด 2 โบกี้

ภาษาในเกมเป็นไทยเป็นหลัก มีอังกฤษกำกับหัวข้อ

### ลิงก์
- Repo: https://github.com/maxexq/mobile-vault (branch `main`, push ได้)
- เล่นได้ทันที (claude.ai artifact, private): https://claude.ai/artifact/XZt7RMvDG7TFXjdH5MYmAU
- Vercel: ยังไม่ได้ deploy จาก session เพราะเข้าถึงไม่ได้ ให้ import repo ที่ vercel.com แล้ว `vercel.json` จะ serve โฟลเดอร์ `web/` เอง
- เจ้าของ: Parames (parames.ajh@gmail.com)

---

## 2. กฎที่ต้องทำตามเสมอ (จากเจ้าของโปรเจกต์)

1. **ใช้ Godot Stable เวอร์ชันล่าสุดเท่านั้น** ห้าม beta / rc / dev
   - ตอนนี้ใช้ **Godot 4.7.2-stable** (ออก 18 ส.ค. 2026) ซึ่งตรวจแล้วว่าเป็น stable ล่าสุด
   - ก่อนอัปเกรดให้เช็ก godotengine.org/download และ GitHub releases ก่อน
2. **อ้าง API จาก docs.godotengine.org (stable)** ถ้าไม่แน่ใจให้เปิดเอกสารเช็ก ห้ามเดา
   - เปิดด้วย WebFetch ไม่ได้ (หน้าเว็บโหลดไม่ครบ) ให้ใช้ไฟล์ rst ดิบแทน:
     `https://raw.githubusercontent.com/godotengine/godot-docs/stable/classes/class_<name>.rst`
3. **Addon ทุกตัวต้องรองรับเวอร์ชัน Godot ที่ใช้** ตรวจก่อนติดตั้ง (ตอนนี้ไม่มี addon)
4. **ขออนุญาตก่อนดาวน์โหลดซอฟต์แวร์**
5. งาน art ต้องเป็น **True Pixel Art 16-bit แนว apocalypse มืดหม่น** (ห้ามสไตล์ Kairosoft ซึ่งถูกปฏิเสธแล้ว)
   - รถมี **3 ห้องต่อชั้น**
6. Commit author: `Parames <parames.ajh@gmail.com>` ข้อความ commit ปิดท้ายด้วย attribution ตามที่ระบบกำหนด

---

## 3. Tech stack และโครงสร้าง

| เรื่อง | รายละเอียด |
|---|---|
| Engine | Godot 4.7.2-stable, GDScript, **Compatibility renderer** (WebGL2), web export **single-threaded** (ไม่ต้องใช้ COOP/COEP) |
| Resolution | `canvas_items` stretch + **integer scale**; design 360×640 portrait / 560×320 landscape; 1 art px = S screen px |
| World render | SubViewport ที่ design res → TextureRect nearest |
| Wide zoom | ขยายขนาด viewport (`view_k = S / world_scale`) แทนการย่อภาพ ภาพจึงยังเป็นพิกเซลเต็มเม็ด |
| Art | สร้างด้วย Python + Pillow (`tools/generate_pixel_art.py` → `tools/art/*.py`) ทุกภาพผ่าน `quantize` เข้าพาเลตกลาง `common.RAMPS` |
| Atlas | atlas เดียวขนาด 2048×2048 (~410 regions รวมห้องกว้าง 2–3 ช่อง) |
| Fonts | Chakra Petch (ไทย) + Silkscreen (pixel) **Silkscreen ไม่มีตัวไทย** ข้อความไทยต้องใช้ font_main |
| Save | `Game.s` (Dictionary เดียว) → JSON → `localStorage["mobile_vault_save_v1"]` (desktop: `user://savegame.json`) |
| Autosave | ทุก 15 วินาที และตอน `visibilitychange` / `pagehide` |
| Audio | ยังไม่มีเสียง |

### Autoload (ลำดับสำคัญ)
`Data, Atlas, Save, Loot, Game, Combat, Lore, Crew, Skills, Mods, Env, Expedition, Meta, Haul, Synergy, Trace, Dev`

| ไฟล์ | หน้าที่ |
|---|---|
| `data.gd` | ข้อมูลออกแบบทั้งหมด: ห้อง, สูตร, ไอเท็ม, biome, อากาศ, อีเว้นต์ 20+, VEHICLES, slot layout |
| `game.gd` | simulation, เศรษฐกิจ, อีเว้นต์, offline progress (สูงสุด 4 ชม.), save/load + `_migrate*` |
| `combat.gd` | ระบบรบ idle: MOBS, mutants, BOSSES (บอสด่าน), WAVE_BOSSES 8 ตัวพร้อม mechanic, `debug_spawn` |
| `loot.gd` | ไอเท็ม, rarity, affix, forge |
| `crew.gd` | traits, morale/strike/desert, infection, kill |
| `skills.gd` | skill tree 3 สาย × 5 โหนด |
| `mods.gd` | มอดภายนอก/ภายใน, blueprint, trailers |
| `env.gd` | ภัยตาม biome (หนาว, รังสี, กรด, ทราย) |
| `expedition.gd` | จุดสำรวจ 13 แห่ง, ทีม 2–3 คน, รางวัล/ความเสี่ยง, `seed` ต่อการสำรวจ |
| `meta.gd` | prestige, perk, ลำดับรถ, ฉากเนื้อเรื่อง |
| `haul.gd` | น้ำหนัก / กำลังเครื่อง / ความเร็ว / การกินน้ำมัน |
| `synergy.gd` | ผลของห้องที่อยู่ติดกัน |
| `trace.gd` | event log ในเครื่อง |
| `dev.gd` | God mode |

### UI และ world
- `scripts/main.gd`: กล้อง, ซูม, ปัด, แตะห้อง (close-up + blur), วางห้อง, X-ray peek
- `scripts/world/vehicle.gd`: เปลือกรถตาม tier, โบกี้, ล้อ, มอดที่เห็นบนตัวรถ, สัตว์เลี้ยง
- `scripts/world/room_view.gd`: ห้อง, synergy marker, ไฟดับ + ไฟฉายหัว
- `scripts/world/dweller_actor.gd`: ลูกเรือ (idle/walk/work/sit/guitar/coffee/clean, ป้ายประท้วง)
- `scripts/world/combat_view.gd`: ฉากรบ, gore, debris, ram
- `scripts/world/expedition_view.gd`: ทีมเดินลงจากรถไปจุดสำรวจ
- `scripts/world/background.gd`: Parallax2D ต่อ biome + ราง
- `scripts/ui/hud.gd`: HUD (BossBar, ปุ่มตา/ซูม/GOD) และ registry ของ panel
- `scripts/ui/*_panel.gd`: หน้าต่างทั้งหมด extends `ModalPanel`
- `scripts/ui/expedition_feed.gd`: กล้องสดตอนสำรวจ
- `scripts/ui/god_panel.gd`: แผงผู้ทดสอบ
- `tools/autotest.gd`: smoke test + screenshot ~60+ ภาพ
- `tools/balance.gd`: บอทจำลองสมดุล
- `tools/migrate_test.gd`: ทดสอบย้ายเซฟเก่า

### เรขาคณิตของรถ (v4)
- **เปลือกหลัก:** ขนาด 280×300, ห้อง 64×52, `COLS [44,118,184]`, `ROW0 = 210`, `FLOOR_H = 56`
- **Slot:** `slot = floor*3 + col` (ชั้นล่างก่อน) ห้องเครื่องอยู่ slot 0 เสมอ
- **โบกี้:** ขนาด 248 px, `TRAILER_COLS [22,88,154]`, ตู้ละ 6 slot ต่อท้าย
  - ปลดล็อกที่ Vault Lv 5+ และต้องมี `bp_trailer`
- **ลำดับรถ:**

  | Tier | ชั้น | ห้อง |
  |---|---|---|
  | van | 2 | 6 |
  | bus | 3 | 9 |
  | rig | 4 | 12 |
  | train | 4 | 12 |

  เซฟเก่าจะกลายเป็น rig หรือ train

---

## 4. ระบบสำคัญแยกตามเวอร์ชัน

### v1–v2
- Idle production, crafting, ลูกเรือ, biome 6 แห่ง, อากาศ, กลางวัน/กลางคืน, อีเว้นต์, lore/สมุดบันทึก, chatter
- ระบบรบแบบ TBH + loot 6 ช่อง

### v3
- ภาพแนว grim 16-bit, 3 ห้องต่อชั้น
- Skill tree, trait, ภัยตาม biome, มอดรถ
- เชื้อเพลิงและโรงกลั่น, สำรวจจุด landmark, prestige "The Next Generation"

### v4
- ลำดับรถ + ฉากเนื้อเรื่องตอน prestige ได้ "แต้มวิจัยพันธุกรรม"
- โบกี้พ่วง, Room Synergy, Power & Weight (ช่วงล่าง / ล้อออฟโรด / จูนเครื่อง)
- Morale: ประท้วง → ขโมยของแล้วหนี
- สัตว์เลี้ยงเดินทั่วรถ: หมา ข้าวตัง, แมว ส้มจี๊ด, ไก่ ไข่ดาว
- ไฟดับ + ไฟฉายหัว
- Mutants: พ่นกรด, ระเบิด, บินจิกโซลาร์, เกราะ
- บอสเวฟผลัดกัน 8 ตัวพร้อม mechanic (enrage / armor / summon / revive / burrow / acid / solar / explode) + หลอดเลือดบอสใหญ่
- Gore / ปลอกกระสุน / screen shake, wide zoom อัตโนมัติ, X-ray toggle
- Micro-animation (กีตาร์ / กาแฟ / เช็ดปืน)

### v4.1
- **Expedition live feed:**
  - ฉากภายในตามประเภทสถานที่ 7 แบบ อยู่ใน `assets/exp/`
  - ลูกเรือทำงานต่างกัน มีศัตรูโผล่ แสดงสถานะทีม และ field log
  - ทั้งหมดคำนวณจากเวลา + seed จึงต่อเนื่องแม้ปิด panel หรือออฟไลน์

### v4.2
- **God Mode (ซ่อน):**
  - เปิดด้วยการแตะชิป VAULT 7 ครั้งใน 5 วินาที หรือ `?god=1` (debug build เปิดเสมอ)
  - มี 7 แท็บ, สวิตช์โกงไม่ถูกเซฟ, ใช้แล้ว `stats.cheated = true`
- **Trace:**
  - session id, event หลัก, sample ทุก 30 วินาที
  - จับ error ผ่าน `Logger` / `OS.add_logger`
  - เก็บ 400 รายการล่าสุดใน `localStorage["mobile_vault_trace_v1"]`
  - export JSON ได้ และพิมพ์ `[trace] …` ลง console

---

### v4.3 · Settings
- **เมนูตั้งค่า** (`scripts/ui/settings_panel.gd`) เปิดจากปุ่มเฟืองบน HUD และปุ่ม SETTINGS บนหน้าแรก มี 3 แท็บ:
  ตั้งค่า (เสียง Master/Music/SFX, ภาษา, ขนาดพิกเซล, มุมกล้อง, CRT, GPU/CPU FX, 30/60 FPS, เต็มจอ, จอสั่น, เลือด, สั่นเครื่อง, ดูบทแนะนำซ้ำ) ·
  เซฟ (บันทึก, ส่งออก/นำเข้าไฟล์ JSON, รีเซ็ตแบบแตะยืนยัน 2 ครั้ง) · เกี่ยวกับ (เวอร์ชันเกม, build, Godot, renderer, GPU, แพลตฟอร์ม, คัดลอกไว้แจ้งบั๊ก)
- **Autoload `Settings`** เก็บแยกจากเซฟใน `localStorage["mobile_vault_settings_v1"]` (desktop `user://settings.json`) รีเซ็ต/นำเข้าเซฟ/prestige แล้วค่ายังอยู่
- **`BuildInfo`** (`scripts/build_info.gd`) คือที่เดียวของเลขเวอร์ชัน (`GAME_VERSION`) ส่วน commit/branch/เวลา build อ่านจาก `res://build_info.json` ที่ `tools/stamp_build.sh` เขียนก่อน export (git-ignore ไว้ ถ้าไม่มีจะขึ้น `dev`)

## 5. Workflow / คำสั่ง

```bash
# (GODOT = path ของ Godot 4.7.2-stable linux binary)
# import + เช็ก script error (ต้องทำหลังเพิ่ม class_name ใหม่ ไม่งั้นหา class ไม่เจอ)
$GODOT --headless --path . --import
$GODOT --headless --path . --quit-after 120 2>&1 | grep -E "SCRIPT ERROR|^ERROR" -A1

# smoke test + screenshots (ต้องมี xvfb)
xvfb-run -a -s "-screen 0 2000x2000x24" $GODOT --path . --rendering-driver opengl3 \
  --resolution 720x1280 -- --autotest --out=OUTDIR

# balance sim / migration test
$GODOT --headless --path . -- --balance --minutes=480
$GODOT --headless --path . -- --migrate-test      # ใช้ savegame.json ที่วางไว้ใน user://

# regenerate art (deterministic)
python3 tools/generate_pixel_art.py

# web export → copy ไป web/ (Vercel serve โฟลเดอร์นี้)
sh tools/stamp_build.sh && $GODOT --headless --path . --export-release "Web" build/web/index.html && cp build/web/* web/
```

### Deploy ไป claude.ai artifact
- โฮสต์จำกัดไฟล์ละ 15 MB จึง gzip ไฟล์แล้วตั้งชื่อเป็น `engine.wasm` (จาก index.wasm 39.5 MB) และ `pack.wasm` (จาก index.pck)
  - หน้า `build/artifact/mobile_vault.html` มี shim ที่ตอบ `fetch("index.wasm"/"index.pck")` ด้วย DecompressionStream
- ทุกครั้งที่ pck เปลี่ยน ต้องอัปเดตค่า `gz:` ของ pack และ `fileSizes["index.pck"]` ใน html
  - engine.wasm ไม่ต้องอัปโหลดซ้ำถ้า engine ไม่เปลี่ยน
- ในการสนทนาใหม่ ต้อง Artifact **read** ก่อน แล้วจึง publish ไปที่ URL เดิมพร้อม `files: {"pack.wasm": ...}`
- `build/` อยู่ใน .gitignore ถ้าโคลนใหม่ต้องสร้าง artifact folder ใหม่: gzip engine + pck และใช้ html shim

### ทดสอบบนเว็บ
- `python3 -m http.server` ที่โฟลเดอร์ export แล้วใช้ Playwright (chromium + swiftshader) viewport 390×844 @3x
- ใน sandbox เฟรมช้ามาก การทดสอบแบบจับเวลาจึงเชื่อถือไม่ได้ ให้ทดสอบ logic ใน autotest แทน

---

## 6. ข้อควรระวัง (เคยเจอมาแล้ว)

- **GDScript type inference:**
  - `var x := dict.key` หรือ `Game.s.something` จะ error "Cannot infer the type" ให้ใส่ type ชัดเจน เช่น `var x: int = ...`
  - ถ้า autotest เจอ parse error มันจะค้างจน timeout ให้รันคำสั่งเช็ก `--quit-after` ก่อนทุกครั้ง
- **ห้ามตั้งชื่อเมธอด `log`:** ไปชนกับ global math `log()` (Trace ใช้ `rec()`)
- **Lambda:** ห้ามเขียน multiline lambda ตามด้วย argument ต่อในวงเล็บเดียวกัน ให้แยกเป็น method หรือตัวแปร
- **Parallax2D:** `repeat_times` กระจายสำเนาทั้งซ้ายและขวา ถ้า wide zoom ต้องตั้งให้พอ (ตอนนี้ครอบคลุม ±1300 px)
- **Touch บนเว็บ:** การแตะหนึ่งครั้งจะมาเป็น touch + emulated mouse ถ้านับการแตะต้อง dedupe (80 ms)
- **Release build:** `OS.is_debug_build()` เป็น false จึงปิด God mode ไว้จนกว่าจะปลดล็อก
- **Panel refresh:** อย่า rebuild ทั้ง panel ทุกเฟรม (มี animation ที่จะหาย) ให้ build ครั้งเดียวแล้วอัปเดต label (ดู expedition_panel)
- **Threads / Logger:** ฟังก์ชัน `Logger._log_error` ถูกเรียกจาก thread อื่น ต้องใช้ Mutex และห้าม print ข้างใน
- **โฟลเดอร์ `web/`:** มี `.gdignore` และ export filter ตัด `web/*`, `build/*`, `tools/*` ออก

---

## 7. งานค้าง / ไอเดียถัดไป

- [ ] **Remote monitoring:** เลือกระหว่าง Vercel Function + DB / PostHog / Sentry แล้วต่อที่ `Trace.sink_url` พร้อมหน้าขอความยินยอมผู้เล่น
- [ ] **Deploy Vercel:** import repo แล้วตั้งค่า output `web`
- [ ] **ยืนยันบนมือถือจริง:** การแตะ VAULT 7 ครั้ง, ประสิทธิภาพ (FPS) บนเครื่องระดับกลาง
- [ ] **รถไฟ + 2 โบกี้บนจอแนวตั้ง:** แม้ wide zoom ยังเห็นไม่ครบ (ต้องปัด) อาจเพิ่มซูมกว้างพิเศษหรือ minimap
- [ ] **เสียง / ดนตรี:** ยังไม่มีเลย
- [ ] **Balance:**
  - ผลจาก sim (เริ่มรถตู้): ทะเลทราย ~45 นาที → ป่า ~3 ชม. → หนองน้ำพิษ ~6.6 ชม.
  - ยังไม่ได้ปรับ economy ของ trailer หรือน้ำหนักกับโบกี้
- [ ] **ศึกบอสตอนซูมกว้าง:** บอสตัวเล็กและอยู่ไกลทางขวา อาจเพิ่ม camera focus ตอนบอสโผล่
- [ ] **Localization:** ตอนนี้ไทยเป็นหลัก ถ้าทำอังกฤษเต็มต้องรวม string ออกมา

---

## 8. ประวัติคำขอสำคัญ (ย่อ)

1. สร้างเกม idle survival รถบ้านบน mobile web ด้วย Godot stable ล่าสุด แล้วเพิ่ม TBH combat, biome, lore, chatter, gear 6 ช่อง
2. เปลี่ยนภาพเป็น True Pixel 16-bit แนว apocalypse มืดหม่น (เลิก Kairosoft) และให้รถมี 3 ห้องต่อชั้น
3. v3: skill tree, hazards, mods, expeditions, prestige
4. Push ขึ้น GitHub (Vercel ต้องทำเองที่ dashboard)
5. v4: บอสหลากหลาย + หลอดเลือดที่มี impact, สัตว์เลี้ยงเดินบนรถ, synergy, น้ำหนัก, morale, scavenging squad, ลำดับรถ + โบกี้, mutants, micro-animation, ไฟดับ + ไฟฉาย, gore, zoom, X-ray
   - ตัวเลือกที่เจ้าของเลือก: เริ่มจากรถตู้, ซื้อโบกี้ระหว่างรอบ, ประท้วงแล้วขโมยของหนี
6. หน้าต่างสำรวจแบบมี animation ว่าใครไปและกำลังทำอะไร
7. God mode สำหรับ tester + ระบบ log / trace
