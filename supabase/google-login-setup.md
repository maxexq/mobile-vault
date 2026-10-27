# ตั้งค่า Google Login ให้ Mobile Vault (ทำครั้งเดียว)

## 1) Google Cloud Console: สร้าง OAuth Client
1. เปิด https://console.cloud.google.com/ แล้วสร้างหรือเลือกโปรเจกต์ (เช่น "Mobile Vault")
2. ไปที่ **APIs & Services → OAuth consent screen** (บางเวอร์ชันชื่อ **Google Auth Platform → Branding / Audience**)
   - User type: **External**
   - App name: Mobile Vault, ใส่อีเมลของคุณในช่อง support / developer
   - Scopes: ใช้ค่าเริ่มต้น (`openid`, `email`, `profile`) ไม่ต้องเพิ่ม
   - ช่วงทดสอบให้อยู่ในโหมด **Testing** และเพิ่มอีเมลที่ใช้ทดสอบลงใน **Test users** (เปลี่ยนเป็น **In production** ได้ตอนจะเปิดให้คนทั่วไปใช้)
3. ไปที่ **APIs & Services → Credentials → Create credentials → OAuth client ID**
   - Application type: **Web application**
   - **Authorized JavaScript origins:** ไม่ต้องใส่
   - **Authorized redirect URIs:** ใส่ค่านี้ค่าเดียว
     `https://phcylgdikidhunjclppr.supabase.co/auth/v1/callback`
   - กด Create แล้วเก็บ **Client ID** กับ **Client secret** ไว้

## 2) Supabase: เปิด Google provider
1. **Authentication → Sign In / Providers → Google** แล้วเปิด Enable
2. วาง **Client ID** และ **Client secret** จากขั้นที่ 1 แล้วกด Save
   (Client secret ใส่ใน Supabase เท่านั้น **ไม่ต้องส่งมาให้ผม**)
3. ในหน้าเดียวกันให้เปิด **Allow manual linking** (ใช้ผูกบัญชี guest เดิมเข้ากับ Gmail ทำให้เซฟไม่หาย)
   ถ้าไม่เจอในหน้านี้ ให้ดูที่ **Authentication → Settings / Policies**
4. ตรวจว่า **Allow anonymous sign-ins** ยังเปิดอยู่

## 3) Supabase: URL Configuration (ทำทั้งสองโปรเจกต์)
**Authentication → URL Configuration** หลัง Google แล้ว Supabase จะส่งผู้เล่นกลับหน้าเดิมก็ต่อเมื่อโดเมนนั้นอยู่ใน
**Redirect URLs** ถ้าไม่อยู่ จะส่งไป **Site URL** แทน (ล็อกอินหาย เพราะ token ไปตกที่เว็บอื่น)

**โปรเจกต์ prod** (`phcylgdikidhunjclppr`, production)
- **Site URL:** `https://apocarlypse-mobile-vault.vercel.app`
- **Redirect URLs:**
  - `https://apocarlypse-mobile-vault.vercel.app/**`
  - `https://*-maxexqs-projects.vercel.app/**` (Vercel branch `main` และ preview)
  - `https://apocarlypse-mobile-vault.pages.dev/**` (Cloudflare Pages production, MV-499)
  - `https://main.apocarlypse-mobile-vault.pages.dev/**`
  - ห้ามใส่ `https://*.apocarlypse-mobile-vault.pages.dev/**` ในโปรเจกต์ prod เพราะ `staging.` / `uat.` เป็นของโปรเจกต์ test

**โปรเจกต์ test** (`bedslajlrtwmfyxrppcq`, staging / uat / preview)
- **Site URL:** `https://staging.apocarlypse-mobile-vault.pages.dev/` (ค่าเริ่มต้นของ Supabase คือ `http://localhost:3000` ซึ่งทำให้ล็อกอินพัง, MV-551)
- **Redirect URLs:**
  - `https://staging.apocarlypse-mobile-vault.pages.dev/**`
  - `https://uat.apocarlypse-mobile-vault.pages.dev/**`
  - `https://*.apocarlypse-mobile-vault.pages.dev/**` (preview ของ Cloudflare Pages)
  - `https://*-maxexqs-projects.vercel.app/**` (Vercel staging / uat / preview)

Google Cloud ไม่ต้องแก้ redirect เพิ่ม (redirect URI ของทั้งสองโปรเจกต์อยู่ใน OAuth client แล้ว) แต่ถ้า
**Google Auth Platform → Audience → Publishing status** ยังเป็น **Testing** จะล็อกอินได้เฉพาะอีเมลใน **Test users**
ถ้าจะให้ผู้เล่นทดสอบ (uat) ล็อกอินได้ ให้กด **Publish app** หรือเพิ่มอีเมลผู้เล่นทดสอบทุกคน

## 4) ตรวจ (ไม่ต้องใช้บัญชี Google)
```
python tools/oauth_check.py
```
ต้องขึ้น `OK` ทุกบรรทัด บรรทัด `FAIL` จะบอกว่าโดเมนนั้นถูกส่งไปที่ไหนแทน (เช่น `http://localhost:3000` = ยังไม่ได้ตั้ง Site URL / Redirect URLs ของโปรเจกต์ test)
ตอนเพิ่มโดเมนใหม่ใน `config/environments.json` ให้เพิ่มใน Redirect URLs ของโปรเจกต์ที่ตรงกันด้วย

## ส่งกลับมาให้ผม
- บอกว่าทำครบแล้ว และ `python tools/oauth_check.py` ขึ้น OK ทุกบรรทัด
- **ไม่ต้องส่ง Client secret**

หมายเหตุ: Google ไม่อนุญาตให้ล็อกอินภายใน iframe ดังนั้นปุ่ม Google จะใช้ได้บนเว็บ Vercel ส่วนใน artifact จะเปิดหน้าเกมในแท็บใหม่ให้แทน
