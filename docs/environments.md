# สภาพแวดล้อม dev / staging / UAT / production (MV-112)

## ภาพรวม

| สภาพแวดล้อม | branch | ใครใช้ | URL (Vercel) | Supabase |
|---|---|---|---|---|
| **production** | `main` | ผู้เล่นจริง | `https://apocarlypse-mobile-vault.vercel.app/` | โปรเจกต์ **prod** (ของเดิม) |
| **UAT** | `uat` | เทสแบบเปิด (ผู้เล่นทดสอบ alpha / beta) | `https://apocarlypse-mobile-vault-git-uat-<ทีม>.vercel.app/` | โปรเจกต์ **test** |
| **staging** | `staging` | เทสภายใน (ทีม) | `https://apocarlypse-mobile-vault-git-staging-<ทีม>.vercel.app/` | โปรเจกต์ **test** |

> **กำลังย้ายไป Cloudflare Pages (MV-499):** ใช้คู่กับ Vercel จนกว่าจะตรวจผ่าน URL ของ Pages: `main` → `https://apocarlypse-mobile-vault.pages.dev/`, `uat` → `https://uat.apocarlypse-mobile-vault.pages.dev/`, `staging` → `https://staging.apocarlypse-mobile-vault.pages.dev/` ขั้นตอนตั้งค่า: [hosting-cloudflare.md](hosting-cloudflare.md)
| **dev** | branch งาน / PR preview / เครื่องตัวเอง | นักพัฒนา | URL preview ของแต่ละ PR | โปรเจกต์ **test** |

- **บิลด์เดียวใช้ได้ทุกที่:** เกมดูชื่อโดเมนของหน้าเว็บแล้วรู้เองว่าอยู่ env ไหน (`config/environments.json`) จึง merge `staging` → `uat` → `main` ได้โดยไม่ต้อง export ใหม่ และไม่มีทางเอาค่าของ staging หลุดไป production
- **ปลอดภัยไว้ก่อน:** เฉพาะโดเมน production ที่ระบุไว้เท่านั้นที่ต่อ Supabase prod ที่อื่นทั้งหมด (PR preview, เครื่องตัวเอง, editor, โดเมนแปลกๆ) เป็น dev และใช้โปรเจกต์ test เซฟ/log ทดสอบจึงไม่ปนกับผู้เล่นจริง
- นอก production หน้าแรกและหน้าเกี่ยวกับจะมีป้าย **STAGING / UAT / DEV SERVER** และหน้าเกี่ยวกับมีแถว `ENV` (สวิตช์ `env_badge`)
- ตั้งค่ารีโมตแยก env ได้: `web/features.staging.json`, `web/features.uat.json`, `web/features.dev.json` ถ้าไม่มีไฟล์ของ env นั้นจะใช้ `web/features.json`

## ลำดับงานประจำวัน

1. งานใหม่: แตก branch `mv-<n>-...` จาก `staging` แล้วเปิด PR เข้า `staging` (Autotest ต้องเขียว)
2. merge แล้วเทสบน URL staging ตั๋ว Plane → **Awaiting Verify**
3. พร้อมเปิดให้ผู้เล่นทดสอบ (alpha / beta): เปิด PR `staging` → `uat` พร้อม bump เวอร์ชันทดสอบ (`python tools/release.py bump alpha` หรือ `beta`) แล้ว **merge แบบ merge commit** (ไม่ squash) ส่งลิงก์ URL ของ uat ให้ผู้เล่นทดสอบ
4. พร้อมขึ้นจริง: bump เป็น `rc` หรือ `stable` ใน PR `uat` → `main` merge แบบ merge commit แล้วรัน Release workflow ตั๋วที่ขึ้นแล้ว → **Done**
5. hotfix: แตกจาก `main` → PR เข้า `main` → แล้วเปิด PR `main` → `uat` → `staging` ให้ไหลกลับลงมา

## ตั้งค่าครั้งแรก (Parames ทำ ทีละขั้น)

### 1. GitHub: สร้าง branch และกฎป้องกัน (ทำแล้ว 2026-10-26, MV-421)
สถานะตอนนี้: มี `staging` และ `uat` แล้ว (แตกจาก main), branch เริ่มต้นของ repo = `staging`, ลบ branch อัตโนมัติหลัง merge
และมี ruleset 2 ชุด: **Protect main, uat, staging** (ต้องผ่าน PR, เช็ก **autotest** ต้องเขียว, branch ต้องอัปเดตตาม base,
ห้าม force push / ลบ) และ **Promotions use merge commits: main, uat** (merge ได้แบบ merge commit อย่างเดียว)
ขั้นตอนด้านล่างเก็บไว้เป็นบันทึกว่าตั้งอย่างไร
1. สร้าง branch จาก main ปัจจุบัน (ทำครั้งเดียว):
   ```
   git fetch origin
   git push origin origin/main:refs/heads/staging origin/main:refs/heads/uat
   ```
2. GitHub → repo → **Settings → Rules → Rulesets** → แก้ ruleset ของ `main` (หรือสร้างใหม่) ให้ครอบ `main`, `uat`, `staging`:
   - Require a pull request before merging
   - Require status checks to pass → เลือก **autotest**
   - Block force pushes
   - (แนะนำ) ปิด "Allow squash merging" สำหรับ PR promotion หรืออย่างน้อยเลือก **Create a merge commit** ตอน merge `staging`→`uat` และ `uat`→`main`
3. (ถ้าอยากให้ PR ใหม่ชี้ staging อัตโนมัติ) Settings → General → **Default branch** → `staging`
   *Release workflow ยังรันบน `main` เหมือนเดิม*

### 2. Vercel
- Vercel deploy ทุก branch อยู่แล้ว: push `staging`/`uat` ครั้งแรกจะได้ URL `…-git-staging-<ทีม>.vercel.app` และ `…-git-uat-<ทีม>.vercel.app` (ดูใน Vercel → Project → Deployments)
- Production ยังเป็น `main` (Settings → Git → Production Branch = `main`)
- (ไม่บังคับ) ตั้งโดเมนสวยๆ ให้ branch: Settings → **Domains** → Add → พิมพ์โดเมน → เลือก **Git Branch** `staging` หรือ `uat`
  ถ้าตั้งโดเมนเอง ต้องเพิ่มโดเมนนั้นใน `config/environments.json` ใต้ `hosts` (เช่น `"staging.example.com": "staging"`) ไม่งั้นจะถูกนับเป็น dev

### 3. Supabase: โปรเจกต์ test (ฟรี แผนฟรีได้ 2 โปรเจกต์ที่ active)
1. supabase.com → **New project** ชื่อเช่น `mobile-vault-test` (region เดียวกับ prod)
2. SQL Editor → รันไฟล์ตามลำดับ: `supabase/migrations/0001_cloud_save.sql`, `0002_schema_guard.sql`, `0003_player_id.sql`, `0004_logs.sql`, `0005_log_alerts.sql`
3. Authentication → Sign In / Providers → เปิด **Allow anonymous sign-ins**
4. Google: เปิด provider Google ใส่ Client ID/Secret เดียวกับ prod และเปิด **Allow manual linking**
   แล้วไปที่ Google Cloud Console → OAuth client เดิม → **Authorized redirect URIs** → เพิ่ม `https://<test-ref>.supabase.co/auth/v1/callback`
5. Authentication → **URL Configuration** (MV-551: ถ้าข้ามขั้นนี้ Site URL จะค้างที่ `http://localhost:3000` แล้ว Gmail login บน staging / uat พาไป localhost):
   - Site URL: `https://staging.apocarlypse-mobile-vault.pages.dev/`
   - Redirect URLs: `https://staging.apocarlypse-mobile-vault.pages.dev/**`, `https://uat.apocarlypse-mobile-vault.pages.dev/**`, `https://*.apocarlypse-mobile-vault.pages.dev/**` และ `https://*-maxexqs-projects.vercel.app/**` (Vercel staging / uat / PR preview; ชื่อโปรเจกต์ Vercel คือ `mobile-vault`)
   - โปรเจกต์ **prod** ต้องมี `https://apocarlypse-mobile-vault.pages.dev/**` และ `https://main.apocarlypse-mobile-vault.pages.dev/**` ด้วย
   - ตรวจ: `python tools/oauth_check.py` ต้อง OK ทุกโดเมน (รายละเอียด: [google-login-setup.md](../supabase/google-login-setup.md))
6. Project Settings → API → คัดลอก **Project URL** และ **anon / publishable key** (ห้ามใช้ service_role)

### 4. `cloud_config.json` บนเครื่องที่ export (git-ignore ไม่ขึ้น git)
> MV-423 / MV-426: ใส่ **game key** ของ GameAnalytics ไว้ในไฟล์เดียวกันที่ `"analytics": {"prod": {"game_key"}, "test": {"game_key"}}` (สร้างเกม 2 เกมใน GameAnalytics: ของจริง + ทดสอบ) ดูตัวอย่างใน `cloud_config.example.json` ไม่ใส่ = ไม่ส่งสถิติ
> **ห้ามใส่ secret key ในไฟล์นี้** เพราะไฟล์นี้ถูกรวมเข้าไปในบิลด์ และ repo เป็นสาธารณะ ให้ใส่ใน Vercel → Project Settings → Environment Variables แทน (ทุก environment): `GA_GAME_KEY_PROD`, `GA_SECRET_PROD`, `GA_GAME_KEY_TEST`, `GA_SECRET_TEST` แล้ว `api/ga.mjs` จะเซ็นให้

เปลี่ยนเป็นรูปแบบใหม่ (ดู `cloud_config.example.json`):
```json
{
  "projects": {
    "prod": {"url": "https://<prod-ref>.supabase.co", "anon_key": "<prod anon key>", "site_url": "https://apocarlypse-mobile-vault.vercel.app/"},
    "test": {"url": "https://<test-ref>.supabase.co", "anon_key": "<test anon key>", "site_url": "<URL staging>"}
  }
}
```
- ค่า `prod` = ค่าในไฟล์เดิม (ไฟล์เก่าแบบแบนยังใช้ได้ แต่ **ใช้ได้เฉพาะบนโดเมน production** ที่อื่นคลาวด์จะปิด)
- export ใหม่หลังแก้ไฟล์นี้ แล้ว commit `web/`
- Claude Code CLI ทำตาม CLAUDE.md ซึ่งอัปเดตแล้ว

### 5. ตรวจว่าใช้ได้
- เปิด URL staging → หน้าแรกต้องมีป้าย **STAGING SERVER**, ตั้งค่า → เกี่ยวกับ → แถว `ENV` = `STAGING · server test`
- เล่นแบบ Guest แล้วดูใน Supabase **test** → Table Editor → `saves` ต้องมีแถวใหม่ และใน **prod** ต้องไม่มี
- เปิด production → ต้องไม่มีป้าย, `ENV` = `PROD · server prod`
- GOD → ระบบ → เวอร์ชัน: บรรทัด "สภาพแวดล้อม" บอก env, เซิร์ฟเวอร์ และไฟล์ตั้งค่ารีโมตที่ใช้

### 6. แจ้งเตือน Discord
- Deploy ของ `staging`/`uat` ขึ้นชื่อเป็น **Staging**/**UAT** (ไม่ถูกข้ามแม้ตั้ง `SKIP_PREVIEW_SUCCESS`)
- Error spike (MV-171) ยังอ่านจากโปรเจกต์ prod ตาม secret เดิม
