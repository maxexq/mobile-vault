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

## 3) Supabase: URL Configuration
**Authentication → URL Configuration**
- **Site URL:** `https://apocarlypse-mobile-vault.vercel.app`
- **Redirect URLs:** เพิ่มสองบรรทัดนี้
  - `https://apocarlypse-mobile-vault.vercel.app/**`
  - `https://*-maxexqs-projects.vercel.app/**` (สำหรับลิงก์ preview ของแต่ละ PR)

## ส่งกลับมาให้ผม
- บอกว่าทำครบทั้ง 3 ข้อแล้ว
- **ไม่ต้องส่ง Client secret**

หมายเหตุ: Google ไม่อนุญาตให้ล็อกอินภายใน iframe ดังนั้นปุ่ม Google จะใช้ได้บนเว็บ Vercel ส่วนใน artifact จะเปิดหน้าเกมในแท็บใหม่ให้แทน
