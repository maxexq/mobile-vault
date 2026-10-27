extends Node
## Feature switches, per-event switches and balance numbers in one place, read in layers (later wins):
##  1. res://config/features.json           shipped defaults (exported into the pck)
##  2. res://config/features.<tag>.json     only when the export preset has that custom feature tag
##                                          (OS.has_feature, e.g. "demo" / "staging")
##  3. remote features.json                 web only: <page folder>/features.json on the same host (Vercel
##                                          serves web/features.json), cached in localStorage; a failed fetch
##                                          keeps the cache, no cache keeps layer 1-2. Outside production
##                                          features.<env>.json is tried first (MV-112, BuildInfo.env)
##  4. game mode                          Modes.apply(): the run's mode / mutators (Game.s.mode) switch systems off
##  5. tester overrides                     GOD MODE tab "ฟีเจอร์" (user://dev.cfg) or the page URL
##                                          ?ff=raids:off,event.raiders:off,tune.threat.rate_scale:1.5 (session only)
## The remote file can only switch off / re-time / re-weight / re-tune what the build already contains:
## unknown keys are ignored, numbers are clamped to TUNE, a broken file changes nothing. Switching a feature
## off hides it from play but never deletes save data; switching it back on brings everything back.
## Schema (every block optional):
##  {"min_game": "4.3", "max_game": "", "tz_hours": 7,
##   "features": {"raids": false},
##   "events": {"raiders": {"on": false}, "trader": {"weight": 2.0}, "gas_station": {"biomes": ["*"], "from": "2026-11-14", "to": "2026-11-16 23:59"}},
##   "tune": {"threat.rate_scale": 1.5},
##   "announce": [{"id": "s1-open", "text": "ข้อความไทย", "text_en": "optional", "from": "2026-11-01", "to": "2026-11-03",
##                 "loops": 3, "repeat_hours": 6}]}   (MV-188: top-of-screen marquee, each id once per browser or
##                 again every repeat_hours, see Announce)
## Event dates are local time at tz_hours (default 7 = Thailand); "to" without a time means the end of that day.

signal changed

const DEFAULT_PATH := "res://config/features.json"
const BUILD_TAGS := ["demo", "staging"]
const CACHE_KEY := "mobile_vault_features_v1"
const CACHE_PATH := "user://features_remote.json"
const DEV_CFG := "user://dev.cfg"
const TIMEOUT_SEC := 10.0

## every switch the game knows; the remote file cannot invent new ones
const FEATURES := {
	"event_progression": "อีเว้นต์ยากขึ้นตามไบโอม รอบเล่น และ Vault (MV-553): โตตามอุปกรณ์ เช็กสเตตัสยากขึ้นแบบมีเพดาน ความเสียหายจำกัด",
	"warlord_progression": "บอสด่านตรวจผ่านได้ต่อเนื่อง (MV-550): ความแกร่งโตตามอุปกรณ์ รวมลูกน้อง จำกัดความเสียหายต่อครั้ง",

	"multi_salvage": "แยกอุปกรณ์หลายชิ้นพร้อมกัน (MV-554): ปุ่มเลือกแยกหลายชิ้นในคลัง แตะติ๊กหลายชิ้น แถบล่างบอกจำนวนและของที่ได้ แล้วยืนยันครั้งเดียว (ปิด = แยกทีละชิ้นหรือตามระดับในเตาหลอม)",
	"gear_detail_v2": "หน้าต่างรายละเอียดอุปกรณ์อ่านง่าย (MV-552): ตารางค่าสถานะพร้อมไอคอน ส่วนต่าง +/- เทียบของที่ใส่อยู่ และสิ่งที่จะเสียถ้าเปลี่ยน (ปิด = รายการข้อความแบบเดิม)",
	"individual_auto_equip": "สวมอุปกรณ์อัตโนมัติรายคน (MV-547): ปุ่มในหน้าลูกเรือและการ์ดทีม เลือกของที่ดีกว่าจากคลังให้เฉพาะคนนี้",
	"smooth_ui_text": "ตัวอักษร Chakra Petch เรียบคมตามความละเอียดจอ (MV-540): ปิด = ขอบพิกเซลแบบเดิม",
	"confirm_actions": "หน้าต่างยืนยันก่อนลบหรือแทนที่ข้อมูล (MV-422)",
	"desert_parallax": "ทะเลทรายแก้ว (MV-539): ฉากหลังยาว 5 ชั้น ท้องฟ้าตามเวลาในเกม (ปิด = ฉากเดิม)",
	"industrial_parallax": "ฉากนิคมอุตสาหกรรม 20 พาเนล (MV-548): ฉากหลังยาว ท้องฟ้าตามเวลาในเกม พระอาทิตย์/พระจันทร์ ควันและฝุ่นพิกเซล (ปิด = ฉากเดิม)",
	"road_events": "อีเว้นต์สุ่มบนถนน",
	"raids": "ศัตรูบุกรถ (บอสด่านตรวจยังขวางทางเสมอ)",
	"encounters": "จุดพิเศษระหว่างสำรวจ",
	"drive_help": "ช่วยเมื่อรถหยุด (MV-542): กลับเข้าเกมแล้วรถถึงปลายทางระหว่างที่ไม่อยู่ สรุปบอกว่าถึงแล้ว · ปุ่มออกรถเปิดแผนที่เมื่อต้องเลือกปลายทาง (ไอคอนแผนที่) และบอกเหตุผลเมื่อรถติดอย่างอื่น · แตะ STOPPED เพื่อดูเหตุผล (ปิด = ปุ่มสลับวิ่ง/จอดอย่างเดียว)",
	"vault_upgrade_v2": "อัปเกรดโครงรถที่ได้ผลจริง (MV-545): บอกห้องที่ได้จริง ถ้าห้องเต็มรถบอกให้เปลี่ยนรถคันใหญ่ขึ้น ทุกเลเวลตัวถังสูงสุด +15 การผลิต +5% และเลเวลที่ห้องเต็มรถได้การผลิต +10% แทน (ปิด = ข้อความ ห้อง +1 แบบเดิม ไม่มีโบนัส)",
	"build_room_effects": "บอกว่าห้องทำอะไรได้ (MV-557): เมนูสร้างและรายการสร้างจากช่องว่างโชว์ผลของแต่ละห้อง เช่น ผลิตอาหาร/น้ำ ฟื้นเลือด ป้องกันรถ (ปิด = ชื่อห้องกับราคาอย่างเดียวแบบเดิม)",
	"hull_repair_v2": "ค่าซ่อมตัวถังแบบใหม่ (MV-541): รถใหญ่จ่ายต่อ HP ถูกลง ซ่อมทีละ 25% ได้ ลูกเรือห้องเครื่อง/โรงช่าง ช่างเครื่อง skill ช่างซ่อม และอู่ซ่อมในรถช่วยลดค่าซ่อม (สูงสุด 40%) และโชว์ซ่อมเอง +HP/นาที ข้างแถบตัวถัง (ปิด = 0.6 เศษเหล็ก/HP ซ่อมเต็มอย่างเดียว)",
	"hull_warning": "เตือนก่อนรถพัง (MV-250): ตัวถังเหลือ 50/25/10% มีข้อความบอกผล จอสั่นเบาๆ สั่นมือถือ กรอบจอแดงกะพริบ และแถบซ่อมด่วน (ปิด = มีแค่แถบตัวถังเปลี่ยนสีแบบเดิม)",
	"morale_v2": "ขวัญกำลังใจแบบใหม่ (MV-127): หดหู่ (ทำงานช้าลง) → ใจสลาย (ร้องไห้ในห้องพัก ไม่รับคำสั่ง) → ลงจากรถตอนกลางคืน + ปุ่มคุยปลอบใจ (ปิด = ประท้วง/หนีพร้อมขโมยของแบบเดิม)",
	"fixed_sim": "จำลองเศรษฐกิจเป็นจังหวะคงที่ (MV-113): คำนวณทรัพยากร/ลูกเรือ/การเดินทาง 20 ครั้งต่อวิ ไม่ใช่ทุกเฟรม ช่วยให้ 60/120 FPS ลื่น (ปิด = ทุกเฟรมแบบเดิม)",
	"responsive_scale": "ขยาย UI ขึ้นอีกขั้นบนจอที่เกือบถึงขั้นถัดไป (MV-266): แท็บเล็ต 768x1024 / โน้ตบุ๊ก 1024x768 ได้ 2 เท่าแทนตัวเล็ก 1 เท่า (ปิด = ปัดลงแบบเดิม)",
	"window_still": "หน้าต่างอยู่นิ่งเมื่อเนื้อหาเปลี่ยนความสูง (MV-537): ขอบบนไม่ขยับ ไม่เลื่อน กล้องซูมห้องไม่เลื่อนตาม ไม่ทำให้มึนหัว (ปิด = เลื่อนนุ่มแบบ MV-482)",
	"window_fit": "หน้าต่างสูงพอดีเนื้อหา (MV-482): ไม่มีที่ว่างใต้เนื้อหา ยืด/หดนุ่มๆ เมื่อเนื้อหาเปลี่ยน (ปิด = สูงเต็มจอแบบเดิม)",
	"gear_slot_style": "ช่องอุปกรณ์เหล็กหมุดย้ำแบบใหม่ (MV-473): กรอบเหล็กตามความกว้างจริง ช่องว่างเป็นเงาเทา (ปิด = กรอบสีตามความหายากแบบเดิม)",
	"gear_slot_vfx": "แสงเคลื่อนไหวตามความหายากของอุปกรณ์ (MV-473): ขอบเรืองแสง ออร่า ประกายไฟ ต้องเปิดช่องเหล็กด้วย (ปิด = ขอบสีนิ่ง ไม่ขยับ)",
	"trait_card_style": "การ์ดนิสัยลูกเรือแบบกะทัดรัด (MV-483): ไอคอน ชื่อ ผลจริง ข้อเสียเป็นสีแดงพร้อมเครื่องหมายเตือน (ปิด = ชิปนิสัยแบบเดิม)",
	"trait_tiers": "ระดับนิสัยลูกเรือ (MV-497): ป้ายระดับและแสงตามคุณค่าของนิสัย ทั่วไป..ตำนาน ข้อเสียแรงขึ้นตามความเสี่ยง (ปิด = การ์ดไม่มีระดับ)",
	"trait_roll_weights": "โอกาสสุ่มนิสัยตามระดับ (MV-516): นิสัยระดับสูงสุ่มได้ยากขึ้น ทั่วไป 10 · ไม่ธรรมดา 7 · หายาก 4 · มหากาพย์ 2 · ตำนาน 1 · ข้อเสีย 5 (ปิด = ทุกนิสัยโอกาสเท่ากัน)",
	"trait_card_vfx": "แสงเคลื่อนไหวบนการ์ดนิสัยตามระดับ (MV-483): ต้องเปิดการ์ดแบบใหม่ และนิสัยต้องจัดระดับแล้ว (ปิด = ขอบนิ่ง)",
	"seeded_world_map": "แผนที่โลกแบบสุ่มด้วย seed (MV-500): ถนนเชื่อมจุดต่าง ๆ เลือกปลายทางแล้วขับไป ครบรอบได้โลกใหม่ (ปิด = รายชื่อพื้นที่เรียงกันแบบเดิม) ยังทำไม่ครบ: ระยะที่ 1 สร้างและเก็บโลกเท่านั้น",
	"world_map_detail": "แผนที่โลกอ่านง่ายขึ้น (MV-556): พื้นสีเรียบ ของประจำแต่ละพื้นที่ (โรงงาน เนินทราย ต้นไม้ บึง สนหิมะ ตึก) เส้นแบ่งพื้นที่ และป้ายชื่อพื้นที่มีพื้นหลัง (ปิด = ลายพื้นแบบเดิม)",
	"map_blueprint_caches": "กล่องพิมพ์เขียวบนแผนที่โลก (MV-546): สุ่มเกิดทีละกล่องบนจุดที่ไปถึงได้ ขับไปเก็บได้พิมพ์เขียวที่ยังไม่มี (ครบแล้ว = กล่องเสบียง) ต้องเปิดแผนที่โลกด้วย (ปิด = ไม่มีกล่อง)",
	"rooms_expansion": "ห้องใหม่ชุดขยาย 10 ห้อง (MV-428): ห้องที่สร้างได้เพิ่ม งานของห้อง และแอนิเมชันประจำห้อง (ปิด = ซ่อนจากเมนูสร้าง งาน/นาฬิกาหยุดไว้ ห้องและของที่เก็บได้ยังอยู่)",
	"strangers": "คนแปลกหน้าหน้าประตู (ตรวจคน)",
	"stop_for_strangers": "คนแปลกหน้าโบกรถตอนรถวิ่ง รถจะจอดก่อนแล้วเปิดหน้าต่างตรวจ เลือกขับผ่านได้ (MV-244) (ปิด = รถวิ่งต่อ คนรอหน้าประตูแบบเดิม)",
	"expeditions": "ส่งทีมสำรวจ",
	"roof_deck": "ดาดฟ้าพักทีมป้องกัน",
	"large_rooms": "ทุบผนังรวมห้องใหญ่",
	"tutorial": "บทสอนเกมใหม่",
	"cloud_save": "เซฟบนคลาวด์ (มีผลตอนเปิดเกมครั้งถัดไป)",
	"google_login": "ล็อกอิน / ผูกบัญชีด้วย Google (ปิด = เล่นแบบ Guest อย่างเดียว)",
	"player_id": "ไอดีผู้เล่นแบบสั้น ในตั้งค่า > เซฟ ไว้แจ้งปัญหา (ปิด = ไม่แสดงและไม่บันทึกลงเซฟ/log)",
	"cloud_logs": "ส่งบันทึกการเล่นขึ้นเซิร์ฟเวอร์ (ปิด = เก็บ log ไว้ในเครื่องอย่างเดียว)",
	"game_analytics": "สถิติการเล่นบน GameAnalytics (MV-423): เซสชัน แผนที่ที่ไปถึง ห้องที่สร้าง อีเว้นต์ สำรวจ และ error ไม่ระบุตัวตน (ปิด = ไม่ส่ง log บนเซิร์ฟเวอร์เกมยังส่งตามเดิม)",
	"server_outbox": "คิวส่งข้อมูลขึ้นเซิร์ฟเวอร์ (MV-424): ส่งทีละคำขอ เซฟก่อน log ถ้าเซิร์ฟเวอร์ล่มหรือตอบ 429/5xx จะพักแล้วค่อยลองใหม่ห่างขึ้นเรื่อย ๆ แบบสุ่มเวลา (ปิด = ส่งตรงและลองใหม่ทุก 30 วิแบบเดิม)",
	"barks": "ลูกเรือพูดตามสถานการณ์ (MV-427): ตอนถูกบุก เจอบอส บาดเจ็บ ทีมสำรวจออก/กลับ เจอจุดสำรวจ อากาศเปลี่ยน เข้าพื้นที่ใหม่ สร้างห้องเสร็จ (ปิด = มีแต่บทพูดสุ่มแบบเดิม)",
	"tutorial_tips": "คำแนะนำจากจ่ามาร์คครั้งแรกที่เปิดแต่ละระบบ (ปิด = ไม่มีคำแนะนำ บทสอนแรกยังอยู่)",
	"engine_bay":"ระบบห้องเครื่อง: ความร้อน สึกหรอ น้ำมันเครื่อง เครื่องยนต์หลายแบบ (ปิด = รถใช้ดีเซลเดิม ไม่มีพัก/เสีย)",
	"flee_guard": "ห้ามเร่งเครื่องหนีตอนรถออกตัวไม่ได้ (MV-243): จอดรอทีมสำรวจ ไฟหมด ตัวถังพัง เครื่องพัก/ดับ ด่านตรวจ ปุ่มหนีจะปิดพร้อมบอกเหตุผล หมดเวลาลูกเรือจะสู้แทน ไม่มีใครบนรถ = ปิดประตูตั้งรับ (ปิด = หนีได้ทุกเมื่อแบบเดิม)",
	"event_timer": "อีเว้นต์บนถนนจับเวลา หมดเวลาลูกเรือเลือกเอง (ปิด = รอผู้เล่นตลอด)",
	"english":"ภาษาอังกฤษในตั้งค่า (ปิด = ไทยอย่างเดียว ผู้ที่เลือกอังกฤษไว้จะกลับเป็นไทย)",
	"env_badge":"ป้าย STAGING / UAT / DEV SERVER บนหน้าแรกและหน้าเกี่ยวกับ (นอกเกมจริง)",
	"portrait_fit":"มือถือแนวตั้ง: กล้อง AUTO ซูมรถให้เต็มจอ ปัดดูโบกี้ (ปิด = เห็นทั้งขบวนแต่รถเล็ก)",
	"persistent_account": "ไอดีถาวร: มีเซฟแล้วไม่มีปุ่มเริ่มใหม่ (ปิด = มีปุ่ม NEW RUN ล้างทุกอย่างแล้วเริ่มใหม่)",
	"channel_badge": "ป้าย ALPHA / BETA บนหน้าเริ่มเกมและหน้าเกี่ยวกับ",
	"room_ambience": "แสงไฟและอนิเมชันเล็กๆ ในห้อง (ไฟกะพริบ, ไอน้ำ, ฟองน้ำ, เกจ)",
	"resume_on_reload": "รีเฟรชหน้าเว็บแล้วเข้าเกมต่อเลย ไม่ต้องกด เดินทางต่อ",
	"crew_roster_20": "ลูกเรือมีชื่อ 20 คน (MV-170) สุ่มมาขึ้นรถแทนผู้รอดชีวิตทั่วไป (ปิด = สุ่มแบบเดิม คนที่ขึ้นรถแล้วยังอยู่ครบ)",
	"anticheat": "กันโกงเวลา: คิดเวลาออฟไลน์ไม่เกินที่เซิร์ฟเวอร์เห็นเซฟล่าสุด (ฝั่งเซิร์ฟเวอร์ตรวจเสมอ)",
	"announce": "แถบประกาศตัวอักษรวิ่งบนจอ: ข่าวจาก features.json + แจ้งเวอร์ชันใหม่ระหว่างเล่น (MV-188)",
	"raw_food": "วัตถุดิบสมจริง (MV-247): ปลูกพืชผล ล่าเนื้อ แล้วห้องครัวใช้พืช/เนื้อ + น้ำทำอาหาร สูตรยา/เชื้อเพลิงใช้ของที่สมเหตุผล (ปิด = ครัวทำอาหารเองแบบเดิม สูตรใช้เศษเหล็ก)",
	"vehicle_ambience": "รถมีชีวิต (MV-388): ห้องเครื่องพัดลมหมุน ท่อสั่น ไอร้อนตอนเครื่องร้อน + ธงบนหลังคาสะบัด โซ่ท้ายแกว่ง บังโคลนพลิ้ว ควันท่อเป็นพุ่ย น้ำฝนหยดจากหลังคา (ปิด = ภาพนิ่ง ควันท่อแบบเดิม)",
	"vehicle_detail": "รายละเอียดช่วงล่างรถ (MV-388): แหนบเหนือล้อถนนของรถหลักและรถพ่วง (ปิด = ไม่มีแหนบ ลายสนิม/แผ่นปะบนตัวรถยังอยู่)",
	"roaming_boss_balance": "สมดุลบอสทุก 10 เวฟ (MV-544): ลด HP/ดาเมจ และให้เกราะรถลดความเสียหายพิเศษพร้อมเพดานต่อครั้ง",
	"boss_intro": "เปิดตัวบอส (MV-387): บอส/บอสด่านตรวจหล่นลงมาพร้อมฝุ่นและคำราม แถบ WARNING ชื่อบอส จอแฟลช อีลิทมีประกายทอง (ปิด = บอสเดินเข้ามาเฉยๆ)",
	"enemy_size": "มอนสเตอร์ตัวใหญ่ (MV-517): ศัตรูวาดใหญ่ขึ้นเป็นจำนวนเท่าเต็ม ตัวธรรมดา x2 อีลิท x3 บอส/บอสด่าน x3 โจรที่เป็นคนเล็กกว่าหนึ่งขั้น (ปิด = ขนาดเดิม)",
	"cozy_roof": "หลังคาอบอุ่น (MV-462): ถังน้ำสีเขียวหัวเป็ดมีสายรัดกับเกจน้ำ จานดาวเทียมแบบใหม่ กระบะปลูกผักมีไม้เลื้อย และดาดฟ้าพักแบบไม้มีผ้าใบปะ ม้านั่งกับผ้าห่ม กระจกกันลม โคมไฟ ถังน้ำ (ปิด = หลังคาแบบเดิม)",
	"driver_cab": "คนขับในห้องคนขับ (MV-519): วิกเตอร์นั่งขับรถทุกคัน แล้วขยับเล็กๆ เป็นระยะ กะพริบตา ไฟหน้าปัดกะพริบ มือขยับพวงมาลัย (ปิด = นั่งนิ่ง ภาพคนขับยังอยู่)",
	"audio_ambience": "เสียงบรรยากาศ (MV-536): เสียงประจำแต่ละพื้นที่ เสียงเครื่องยนต์ และเสียงอากาศ ฝนบนหลังคาเหล็ก พายุฟ้าร้อง พายุทราย หิมะ หมอก ฝนกรด เถ้าถ่าน (ปิด = เงียบ)",
	"audio_sfx": "เสียงเอฟเฟกต์ (MV-536): ยิง โดนตี บอส สร้าง/ทุบห้อง ของดรอป เครื่องติด/ดับ อีเว้นต์ ทีมสำรวจ ด่านตรวจ แจ้งเตือน และเสียงกดปุ่ม (ปิด = เงียบ)",
	"audio_bgm": "เพลงหน้าแรก (MV-536): เพลงโลไฟอบอุ่นตอนอยู่หน้าเริ่มเกม ค่อยๆ เบาลงเมื่อเข้าเกม (ปิด = ไม่มีเพลง)",
	"audio_clean": "เสียงใสไม่แตก (MV-555): เสียงวนบรรยากาศ/อากาศ/เพลงเล่นด้วยตัวเล่นสองตัวสลับกันแบบเฟดไขว้ บนเว็บจึงใช้เสียงของเบราว์เซอร์ ไม่ต้องมิกซ์บนเธรดหลัก (ต้นเหตุเสียงซ่า/แตกตอนเฟรมกระตุก) และมีลิมิตเตอร์กันเสียงพีคที่ช่องรวม (ปิด = เล่นวนแบบ MV-536)",
	"audio_cues": "เสียงเหตุการณ์ (MV-555): ได้ทรัพยากร อีเว้นต์ระหว่างทางสำเร็จ/ล้มเหลว ทีมสำรวจออกเดินทาง เจอจุดพิเศษ กลับถึงรถ ภารกิจล้มเหลว และขนของที่หาได้ขึ้นรถ (ปิด = เสียงทีมสำรวจแบบเดิม ไม่มีเสียงทรัพยากร/ผลอีเว้นต์)",
	"loot_pity": "การันตีของดี (MV-47): ดรอปครบจำนวนแล้วยังไม่ได้มหากาพย์/ตำนาน ชิ้นถัดไปได้แน่นอน (ปิด = สุ่มล้วนแบบเดิม ตัวนับยังเก็บไว้)",
}
## tune key: [min, max, label]; the code that reads one passes its own constant as the default
const TUNE := {
	"industrial_background.clouds_speed": [0.0, 0.2, "นิคมอุตสาหกรรม: ความเร็วเมฆเทียบถนน"],
	"industrial_background.far_speed": [0.0, 0.3, "นิคมอุตสาหกรรม: ความเร็วฉากไกลเทียบถนน"],
	"industrial_background.mid_speed": [0.0, 0.6, "นิคมอุตสาหกรรม: ความเร็วฉากกลางเทียบถนน"],
	"industrial_background.near_speed": [0.0, 1.0, "นิคมอุตสาหกรรม: ความเร็วข้างทางเทียบถนน"],
	"industrial_background.road_speed": [0.0, 2.0, "นิคมอุตสาหกรรม: ความเร็วถนนเทียบถนน"],
	"industrial_background.cloud_wind": [0.0, 12.0, "นิคมอุตสาหกรรม: ลมเมฆขณะจอด (พิกเซล/วิ)"],
	"desert_background.clouds_speed": [0.0, 0.2, "ทะเลทราย: ความเร็วเมฆเทียบถนน"],
	"desert_background.far_speed": [0.0, 0.3, "ทะเลทราย: ความเร็วฉากไกลเทียบถนน"],
	"desert_background.mid_speed": [0.0, 0.6, "ทะเลทราย: ความเร็วฉากกลางเทียบถนน"],
	"desert_background.near_speed": [0.0, 1.0, "ทะเลทราย: ความเร็วข้างทางเทียบถนน"],
	"desert_background.road_speed": [0.0, 2.0, "ทะเลทราย: ความเร็วถนน"],
	"desert_background.cloud_wind": [0.0, 12.0, "ทะเลทราย: ลมเมฆขณะจอด (พิกเซล/วิ)"],
	"background.fps": [2.0, 12.0, "ฉากอุตสาหกรรม: เฟรมต่อวินาทีของควัน/ฝุ่น"],
	"background.smoke": [0.0, 1.0, "ฉากอุตสาหกรรม: ความหนาของควันปล่องไฟ"],
	"background.particles": [0.0, 48.0, "ฉากอุตสาหกรรม: จำนวนฝุ่นลอยสูงสุด"],
	"background.lights": [0.0, 1.0, "ฉากอุตสาหกรรม: ไฟส้มตอนกลางคืน (0 = ปิด)"],
	"events.gap_min": [20.0, 1800.0, "อีเว้นต์ถนน: เว้นขั้นต่ำ (วิ)"],
	"events.gap_max": [20.0, 3600.0, "อีเว้นต์ถนน: เว้นสูงสุด (วิ)"],
	"events.decide_scale": [0.25, 4.0, "อีเว้นต์ถนน: เวลาตัดสินใจ (เท่า)"],
	"vault.hull_per_level": [0.0, 100.0, "อัปเกรดโครงรถ: ตัวถังสูงสุดเพิ่มต่อเลเวล (MV-545)"],
	"vault.prod_per_level": [0.0, 0.5, "อัปเกรดโครงรถ: การผลิตเพิ่มต่อเลเวล"],
	"vault.prod_per_banked_room": [0.0, 0.5, "อัปเกรดโครงรถ: การผลิตเพิ่มต่อห้องที่ปลดล็อกแต่รถไม่มีที่"],
	"repair.base": [0.1, 2.0, "ค่าซ่อมตัวถัง: เศษเหล็กต่อ HP พื้นฐาน (MV-541)"],
	"repair.ref_hull": [50.0, 600.0, "ค่าซ่อมตัวถัง: ตัวถังสูงสุดที่จ่ายเต็มราคา ใหญ่กว่านี้ถูกลงตามรากที่สอง"],
	"repair.part": [0.05, 1.0, "ค่าซ่อมตัวถัง: ปุ่มซ่อมบางส่วน ซ่อมกี่ส่วนของตัวถังสูงสุด"],
	"repair.per_crew": [0.0, 0.25, "ค่าซ่อมตัวถัง: ส่วนลดต่อคนที่ทำงานห้องเครื่อง/โรงช่าง"],
	"repair.max_crew": [0.0, 8.0, "ค่าซ่อมตัวถัง: นับลูกเรือได้สูงสุดกี่คน"],
	"repair.mechanic": [0.0, 0.25, "ค่าซ่อมตัวถัง: ส่วนลดเพิ่มต่อช่างเครื่อง (Mechanic)"],
	"repair.skill": [0.0, 0.25, "ค่าซ่อมตัวถัง: ส่วนลดเพิ่มต่อระดับ skill ช่างซ่อม"],
	"repair.bay": [0.0, 0.5, "ค่าซ่อมตัวถัง: ส่วนลดต่อระดับอู่ซ่อมในรถ"],
	"repair.discount_cap": [0.0, 0.9, "ค่าซ่อมตัวถัง: ส่วนลดรวมสูงสุด"],
	"events.power_weight": [0.0, 1.0, "อีเว้นต์: สัดส่วนความยากต่อสเกลอุปกรณ์"],
	"events.vault_step": [0.0, 0.2, "อีเว้นต์: ความยากการสู้เพิ่มต่อ Vault level"],
	"events.vault_rank": [0.0, 1.0, "อีเว้นต์: ระดับความเสี่ยงเพิ่มต่อ Vault level"],
	"events.check_step": [0.0, 2.0, "อีเว้นต์: DC เพิ่มต่อระดับความก้าวหน้า"],
	"events.check_cap": [0.0, 10.0, "อีเว้นต์: DC เพิ่มสูงสุด"],
	"events.risk_step": [0.0, 0.3, "อีเว้นต์: ความเสียหายเพิ่มต่อระดับความก้าวหน้า"],
	"events.risk_max": [1.0, 4.0, "อีเว้นต์: ตัวคูณความเสียหายสูงสุด"],
	"events.hull_cap": [0.01, 0.5, "อีเว้นต์: ตัวถังเสียต่อผลลัพธ์สูงสุด (สัดส่วน HP)"],
	"events.injury_cap": [0.01, 0.8, "อีเว้นต์: ลูกเรือบาดเจ็บต่อผลลัพธ์สูงสุด (สัดส่วน HP)"],
	"events.rads_cap": [0.0, 60.0, "อีเว้นต์: รังสีที่ได้รับต่อครั้งสูงสุด"],
	"events.reward_vault": [0.0, 0.3, "อีเว้นต์: รางวัลทรัพยากรเพิ่มต่อ Vault level"],
	"warlord.hp": [1.0, 26.0, "บอสด่าน: ตัวคูณ HP ที่ระดับอุปกรณ์ประจำไบโอม"],
	"warlord.damage": [0.05, 3.2, "บอสด่านและลูกน้อง: ตัวคูณดาเมจ"],
	"warlord.add_hp": [0.1, 3.0, "ลูกน้องบอสด่าน: ตัวคูณ HP"],
	"warlord.hero_hit_cap": [0.005, 1.0, "บอสด่านและลูกน้อง: ดาเมจต่อครั้งสูงสุด (ส่วนของ HP ลูกเรือ)"],
	"warlord.hull_hit_cap": [0.005, 1.0, "บอสด่านและลูกน้อง: ดาเมจต่อครั้งสูงสุด (ส่วนของ HP รถ)"],
	"boss.wave_hp": [1.0, 26.0, "บอสเวฟ: ตัวคูณ HP"],
	"boss.wave_damage": [0.1, 6.0, "บอสเวฟ: ตัวคูณดาเมจ"],
	"boss.hull_hit_cap": [0.02, 1.0, "บอสเวฟ: ความเสียหายรถต่อครั้งสูงสุด (ส่วนของ HP รถสูงสุด หลังคิดเกราะ)"],
	"threat.rate_scale": [0.0, 10.0, "ความเร็วการสะสมภัย"],
	"threat.roll_k": [0.0, 1.0, "โอกาสบุกต่อรอบ"],
	"threat.min_quiet": [5.0, 600.0, "เงียบขั้นต่ำหลังบุก (วิ)"],
	"encounter.base_chance": [0.0, 1.0, "โอกาสจุดพิเศษพื้นฐาน"],
	"encounter.danger_chance": [0.0, 0.2, "โอกาสจุดพิเศษต่อกะโหลก"],
	"inspection.rare_chance": [0.0, 1.0, "โอกาสคนแปลกหน้า (หายาก)"],
	"inspection.very_rare_chance": [0.0, 1.0, "โอกาสคนแปลกหน้า (หายากมาก)"],
	"hull_warning.warn": [0.1, 0.9, "เตือนตัวถัง: ขั้นแรกเมื่อเหลือ (สัดส่วน)"],
	"hull_warning.danger": [0.05, 0.8, "เตือนตัวถัง: ขั้นอันตรายเมื่อเหลือ (สัดส่วน)"],
	"hull_warning.critical": [0.01, 0.5, "เตือนตัวถัง: ขั้นวิกฤตเมื่อเหลือ (สัดส่วน)"],
	"morale.depressed": [5.0, 80.0, "ขวัญ: หดหู่เมื่อความสุขต่ำกว่า"],
	"morale.depressed_clear": [5.0, 90.0, "ขวัญ: หายหดหู่เมื่อความสุขถึง"],
	"morale.broken": [1.0, 60.0, "ขวัญ: ใจสลายเมื่อความสุขต่ำกว่า (นาน 90 วิ)"],
	"morale.broken_clear": [5.0, 80.0, "ขวัญ: หายใจสลายเมื่อความสุขถึง"],
	"morale.work": [0.1, 1.0, "ขวัญ: คนหดหู่ทำงานได้ (สัดส่วน)"],
	"morale.leave_sec": [30.0, 1800.0, "ขวัญ: ใจสลายนานเท่านี้แล้วลงจากรถตอนกลางคืน (วิ)"],
	"morale.talk_gain": [1.0, 40.0, "ขวัญ: คุยปลอบใจได้ความสุข"],
	"morale.talk_sec": [0.0, 600.0, "ขวัญ: คนคุยพักงาน (วิ)"],
	"morale.talk_cd": [0.0, 3600.0, "ขวัญ: คู่เดิมคุยกันอีกได้หลัง (วิ)"],
	"perf.sim_hz": [5.0, 60.0, "ประสิทธิภาพ: คำนวณเศรษฐกิจกี่ครั้งต่อวินาที (fixed_sim)"],
	"barks.cooldown": [3.0, 120.0, "บทพูดตามสถานการณ์: เว้นก่อนพูดเรื่องเดิมซ้ำ (วิ)"],
	"saloon.food": [0.0, 100.0, "โรงเตี๊ยม: อาหารต่อมื้อเย็น"],
	"saloon.water": [0.0, 100.0, "โรงเตี๊ยม: น้ำต่อมื้อเย็น"],
	"saloon.sec": [5.0, 1800.0, "โรงเตี๊ยม: มื้อเย็นนาน (วิ)"],
	"saloon.level_speed": [0.0, 0.4, "โรงเตี๊ยม: มื้อเย็นสั้นลงต่อเลเวลห้อง (0.15 = Lv.3 เร็วขึ้น 30%)"],
	"saloon.happy": [0.0, 50.0, "โรงเตี๊ยม: ความสุขต่อคนที่ร่วมโต๊ะ"],
	"saloon.cooldown": [0.0, 3600.0, "โรงเตี๊ยม: พักก่อนคนเดิมกินมื้อต่อไป (วิ, ทุกโรงเตี๊ยม)"],
	"audio.fade_sec": [0.1, 10.0, "เสียง: เวลาเฟดเปลี่ยนพื้นที่/อากาศ (วิ)"],
	"audio.bed_gain": [0.0, 2.0, "เสียง: ความดังเสียงพื้นที่ (เท่า)"],
	"audio.weather_gain": [0.0, 2.0, "เสียง: ความดังเสียงอากาศ (เท่า)"],
	"audio.engine_gain": [0.0, 2.0, "เสียง: ความดังเครื่องยนต์ (เท่า)"],
	"audio.thunder_gap": [3.0, 120.0, "เสียง: ฟ้าร้องเฉลี่ยทุก (วิ) ตอนพายุ"],
	"audio.bgm_gain": [0.0, 2.0, "เสียง: ความดังเพลงหน้าแรก (เท่า)"],
	"audio.sfx_gap": [0.0, 0.5, "เสียง: เสียงเดียวกันเล่นซ้ำได้หลัง (วิ)"],
	"audio.res_gap": [0.2, 30.0, "เสียง: เสียงได้ทรัพยากรดังได้ไม่ถี่กว่าทุก (วิ)"],
	"audio.cue_gain": [0.0, 2.0, "เสียง: ความดังเสียงเหตุการณ์ (เท่า)"],
	"audio.limiter_db": [-12.0, 0.0, "เสียง: เพดานลิมิตเตอร์ช่องรวม (dB)"],
	"ambience.flicker": [0.0, 30.0, "ไฟห้องกะพริบ (ครั้ง/นาที ต่อดวง)"],
	"logs.flush_sec": [10.0, 3600.0, "ส่ง log ขึ้นเซิร์ฟเวอร์ทุก (วิ)"],
	"analytics.flush_sec": [5.0, 300.0, "GameAnalytics: ส่งสถิติทุก (วิ)"],
	"world.km_scale": [0.25, 4.0, "แผนที่โลก: คูณระยะทางถนน (1 = ข้ามหนึ่งพื้นที่ยาวเท่าเส้นทางเดิม)"],
	"world_map.props": [0.0, 1.0, "แผนที่โลก: ความหนาแน่นของของประจำพื้นที่ (0 = ไม่มี)"],
	"bpcache.first_km": [0.5, 50.0, "กล่องพิมพ์เขียว: กล่องแรกของโลกเกิดหลังขับ (กม.)"],
	"bpcache.every_km": [0.5, 50.0, "กล่องพิมพ์เขียว: หลังเก็บแล้ว สุ่มกล่องใหม่ทุก (กม.)"],
	"bpcache.chance": [0.0, 1.0, "กล่องพิมพ์เขียว: โอกาสเกิดต่อครั้งที่สุ่ม"],
	"bpcache.max_per_lap": [0.0, 20.0, "กล่องพิมพ์เขียว: มากสุดต่อรอบ (ต่อโลก)"],
	"logs.batch": [10.0, 500.0, "log ต่อครั้งที่ส่ง (รายการ)"],
	"outbox.base_sec": [5.0, 300.0, "คิวเซิร์ฟเวอร์: พักครั้งแรกหลังส่งไม่ผ่าน (วิ, สุ่ม 50-100%)"],
	"outbox.max_sec": [30.0, 3600.0, "คิวเซิร์ฟเวอร์: พักนานสุด (วิ)"],
	"fx.shake": [0.0, 2.0, "ความแรงจอสั่น (1 = แรงแบบเดิม, 0 = ไม่สั่น)"],
	"fx.engine_shake": [0.0, 2.0, "รถสั่นตามเครื่องยนต์และถนน (1 = แรงแบบเดิม, 0 = ไม่สั่น)"],
	"view.fit_cap":[1.0, 3.0, "มือถือแนวตั้ง: ซูมรถได้สูงสุดกี่เท่าของขนาดพิกเซล UI"],
	"crew.roster_chance": [0.0, 1.0, "โอกาสคนใหม่เป็นลูกเรือมีชื่อ (ไม่นับช่าง)"],
	"crew.trait_weight.common": [0.0, 50.0, "น้ำหนักสุ่มนิสัยระดับทั่วไป (MV-516)"],
	"crew.trait_weight.uncommon": [0.0, 50.0, "น้ำหนักสุ่มนิสัยระดับไม่ธรรมดา (MV-516)"],
	"crew.trait_weight.rare": [0.0, 50.0, "น้ำหนักสุ่มนิสัยระดับหายาก (MV-516)"],
	"crew.trait_weight.epic": [0.0, 50.0, "น้ำหนักสุ่มนิสัยระดับมหากาพย์ (MV-516)"],
	"crew.trait_weight.legendary": [0.0, 50.0, "น้ำหนักสุ่มนิสัยระดับตำนาน (MV-516)"],
	"crew.trait_weight.trade_off": [0.0, 50.0, "น้ำหนักสุ่มนิสัยข้อเสียแต่ละอัน (MV-516)"],
	"crew.cameo_weight": [0.0, 10.0, "น้ำหนักแขกรับเชิญ 5 คน เทียบลูกเรือออริจินัล (1 = เท่ากัน)"],
	"view.fit_margin": [0.0, 40.0, "มือถือแนวตั้ง: ขอบรอบตัวรถตอนซูม (พิกเซลภาพ)"],
	"announce.loops": [1.0, 5.0, "แถบประกาศ: วิ่งกี่รอบแล้วหาย"],
	"announce.speed": [10.0, 120.0, "แถบประกาศ: ความเร็วตัวอักษร (พิกเซล/วิ)"],
	"announce.poll_min": [1.0, 60.0, "แถบประกาศ: เช็กประกาศ/เวอร์ชันใหม่ระหว่างเล่นทุก (นาที)"],
	"food.cook_yield": [0.5, 4.0, "ห้องครัว: อาหารที่ได้ต่อพืช/เนื้อ 1 หน่วย"],
	"food.cook_water": [0.0, 1.0, "ห้องครัว: น้ำที่ใช้ต่ออาหาร 1 หน่วย"],
	"food.crop_water": [0.0, 1.0, "ห้องปลูกพืช: น้ำที่ใช้ต่อพืชผล 1 หน่วย"],
	"food.meat_kill": [0.0, 5.0, "เนื้อจากการฆ่าสัตว์กลายพันธุ์ (เท่า)"],
	"vehicle.fan_fps": [1.0, 4.0, "ห้องเครื่อง: พัดลมหมุน (เฟรม/วิ ตอนวิ่ง จอดอยู่ครึ่งหนึ่ง)"],
	"vehicle.vent_gap": [1.5, 6.0, "ห้องเครื่อง: ไอร้อนพุ่งทุก (วิ โดยเฉลี่ย)"],
	"vehicle.puff_gap": [0.5, 3.0, "ควันท่อไอเสีย: ระยะห่างระหว่างพุ่ย (เท่า)"],
	"vehicle.drip_gap": [1.5, 15.0, "น้ำฝนหยดจากหลังคา: ทุก (วิ โดยเฉลี่ย)"],
	"vehicle.driver_gap": [1.5, 12.0, "คนขับ: ขยับทุก (วิ โดยเฉลี่ย)"],
	"boss_intro.time": [0.3, 3.0, "เปิดตัวบอส: ความยาวแถบ WARNING (เท่า)"],
	"boss_intro.flash": [0.0, 1.0, "เปิดตัวบอส: ความแรงจอแฟลชขาว (0 = ไม่แฟลช)"],
	"enemy_size.normal": [1.0, 4.0, "มอนสเตอร์ตัวใหญ่: ตัวธรรมดา (เท่า จำนวนเต็ม)"],
	"enemy_size.elite": [1.0, 4.0, "มอนสเตอร์ตัวใหญ่: อีลิท (เท่า จำนวนเต็ม)"],
	"enemy_size.boss": [1.0, 4.0, "มอนสเตอร์ตัวใหญ่: บอส (เท่า จำนวนเต็ม ใหญ่เกินพื้นที่สู้จะลดลงเอง)"],
	"enemy_size.warlord": [1.0, 4.0, "มอนสเตอร์ตัวใหญ่: บอสด่านตรวจ (เท่า จำนวนเต็ม ใหญ่เกินพื้นที่สู้จะลดลงเอง)"],
	"loot.pity_epic": [5.0, 200.0, "การันตีมหากาพย์ขึ้นไป: ทุกกี่ดรอป"],
	"loot.pity_legend": [20.0, 1000.0, "การันตีตำนานขึ้นไป: ทุกกี่ดรอป"],
}
const LAYERS := ["default", "build", "remote", "mode", "dev"]

## per layer: {"features": {k: bool}, "events": {id: {...}}, "tune": {k: float}, ...}
var layers := {"default": {}, "build": {}, "remote": {}, "mode": {}, "dev": {}}
var remote_status := "off"      # off | cached | loading | ok | failed | rejected
var remote_at := 0.0            # unix time of the remote copy in use
var remote_url := ""
## tests: fixed clock for event windows (0 = real time)
var now_override := 0.0
var _session_dev := {}          # ?ff= overrides: never written to dev.cfg


func _ready() -> void:
	layers.default = _read_json(DEFAULT_PATH)
	var b := {}
	for tag in BUILD_TAGS:
		if OS.has_feature(tag):
			b = _merge(b, _read_json("res://config/features.%s.json" % tag))
	layers.build = b
	if not _is_test_run():
		var text := Save.read_key(CACHE_KEY, CACHE_PATH)
		var cached = JSON.parse_string(text) if text != "" else null
		if cached is Dictionary and _accepts(cached.get("cfg", {})):
			layers.remote = _clean(cached.cfg)
			remote_at = float(cached.get("at", 0.0))
			remote_status = "cached"
	_load_dev()
	_read_url_overrides()
	if OS.has_feature("web") and not _is_test_run():
		fetch_remote.call_deferred()
	_trace.call_deferred("boot")


func _is_test_run() -> bool:
	var args := OS.get_cmdline_user_args()
	for a in ["--autotest", "--migrate-test", "--balance"]:
		if a in args:
			return true
	return false


# =================================================================== queries
func on(feature: String) -> bool:
	return bool(_value("features", feature, true))


func num(key: String, def: float) -> float:
	var v = _value("tune", key, null)
	if v == null or not TUNE.has(key):
		return def
	return clampf(float(v), float(TUNE[key][0]), float(TUNE[key][1]))


## the merged settings of one event (later layers override field by field)
func event_cfg(id: String) -> Dictionary:
	var out := {}
	for l in LAYERS:
		var e = _layer(l).get("events", {}).get(id)
		if e is Dictionary:
			out.merge(e, true)
	return out


## may this event show right now in this biome? base = it is in the biome's own list
func event_ok(id: String, biome: int, base: bool = true) -> bool:
	if not on("road_events"):
		return false
	var e := event_cfg(id)
	if not bool(e.get("on", true)):
		return false
	if e.has("biomes"):
		var bs: Array = e.biomes if e.biomes is Array else []
		if not (bs.has("*") or bs.has(str(Data.biome(biome).id)) or bs.has(biome) or bs.has(float(biome))):
			return false
	elif not base:
		return false
	var t := now()
	var tz := float(_value("", "tz_hours", 7.0))
	if e.has("from"):
		var a := parse_time(str(e.from), tz, false)
		if a < 0 or t < a:
			return false
	if e.has("to"):
		var z := parse_time(str(e.to), tz, true)
		if z < 0 or t > z:
			return false
	return true


func event_weight(id: String) -> float:
	return clampf(float(event_cfg(id).get("weight", 1.0)), 0.0, 10.0)


## the road-event pool of a biome: its own list plus events a config window adds, minus the ones switched off
func event_pool(biome: int, base: Array) -> Array:
	var pool := []
	for e in base:
		if Data.EVENTS.has(e) and not pool.has(e) and event_ok(e, biome, true) and event_weight(e) > 0.0:
			pool.append(e)
	for l in LAYERS:
		for id in _layer(l).get("events", {}):
			if Data.EVENTS.has(id) and not pool.has(id) and not base.has(id) and event_ok(id, biome, false) and event_weight(id) > 0.0:
				pool.append(id)
	return pool


## MV-188: the "announce" messages of every layer (a later layer's entry replaces one with the same id) whose
## from/to window is open right now
func announcements() -> Array:
	var by_id := {}
	var order := []
	for l in LAYERS:
		var an = _layer(l).get("announce", [])
		for a in (an if an is Array else []):
			if not by_id.has(a.id):
				order.append(a.id)
			by_id[a.id] = a
	var out := []
	var t := now()
	var tz := float(_value("", "tz_hours", 7.0))
	for id in order:
		var a: Dictionary = by_id[id]
		if a.has("from") and (parse_time(str(a.from), tz, false) < 0.0 or t < parse_time(str(a.from), tz, false)):
			continue
		if a.has("to") and (parse_time(str(a.to), tz, true) < 0.0 or t > parse_time(str(a.to), tz, true)):
			continue
		out.append(a)
	return out


func now() -> float:
	return now_override if now_override > 0.0 else Cloud.now()


## layer 4, owned by Modes (a run's mode is part of the save, not a tester override)
func set_mode_layer(d: Dictionary) -> void:
	layers.mode = _clean(d)
	changed.emit()


## where a value comes from: default | build | remote | mode | dev (the last layer that sets it)
func source(block: String, key: String) -> String:
	var src := "code"
	for l in LAYERS:
		var b = _layer(l).get(block, {})
		if b is Dictionary and b.has(key):
			src = l
	return src


func has_dev_overrides() -> bool:
	for blk in ["features", "events", "tune"]:
		if not (_layer("dev").get(blk, {}) as Dictionary).is_empty():
			return true
	return false


## "YYYY-MM-DD" or "YYYY-MM-DD HH:MM[:SS]" (or with a T) at UTC+tz -> unix time; -1 when malformed.
## Time.get_unix_time_from_datetime_string reads the text as UTC, so the zone offset is applied here.
func parse_time(text: String, tz_hours: float, end_of_day: bool) -> float:
	var re := RegEx.create_from_string("^(\\d{4}-\\d{2}-\\d{2})(?:[T ](\\d{2}):(\\d{2})(?::(\\d{2}))?)?$")
	var m := re.search(text.strip_edges())
	if m == null:
		return -1.0
	var hms := "00:00:00"
	var has_time := m.get_string(2) != ""
	if has_time:
		hms = "%s:%s:%s" % [m.get_string(2), m.get_string(3), m.get_string(4) if m.get_string(4) != "" else "00"]
	var t := float(Time.get_unix_time_from_datetime_string(m.get_string(1) + "T" + hms))
	if end_of_day and not has_time:
		t += 86399.0
	return t - tz_hours * 3600.0


# =================================================================== layers
func _layer(l: String) -> Dictionary:
	if l == "dev":
		return _merge(layers.dev, _session_dev)
	return layers[l]


func _value(block: String, key: String, def: Variant) -> Variant:
	# MV-113: switches and tunables are single values, so read each layer directly (session ?ff= overrides win over
	# dev.cfg, as in _merge) instead of _layer("dev"), which deep-copied the whole dev layer on every call. on() and
	# num() run hundreds of times a frame. Still reads the live layers, so a change is never missed.
	if block == "features" or block == "tune":
		var fv = def
		for l in LAYERS:
			var lb = (layers[l] as Dictionary).get(block)
			if lb is Dictionary and lb.has(key):
				fv = lb[key]
			if l == "dev":
				var sb = _session_dev.get(block)
				if sb is Dictionary and sb.has(key):
					fv = sb[key]
		return fv
	var v = def
	for l in LAYERS:
		var b = _layer(l) if block == "" else _layer(l).get(block, {})
		if b is Dictionary and b.has(key):
			v = b[key]
	return v


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not d is Dictionary:
		push_warning("%s is not a JSON object" % path)
		return {}
	return _clean(d)


## keep only what the game understands, with the right types
func _clean(d: Dictionary) -> Dictionary:
	var out := {}
	if d.get("features") is Dictionary:
		var f := {}
		for k in d.features:
			if FEATURES.has(k) and d.features[k] is bool:
				f[k] = d.features[k]
		out.features = f
	if d.get("events") is Dictionary:
		var ev := {}
		for id in d.events:
			var e = d.events[id]
			if not (Data.EVENTS.has(id) and e is Dictionary):
				continue
			var c := {}
			if e.get("on") is bool:
				c.on = e.on
			if e.get("weight") is float or e.get("weight") is int:
				c.weight = clampf(float(e.weight), 0.0, 10.0)
			if e.get("biomes") is Array:
				c.biomes = e.biomes
			for k in ["from", "to"]:
				if e.get(k) is String and parse_time(e[k], 0.0, false) >= 0.0:
					c[k] = e[k]
			ev[id] = c
		out.events = ev
	if d.get("tune") is Dictionary:
		var t := {}
		for k in d.tune:
			if TUNE.has(k) and (d.tune[k] is float or d.tune[k] is int):
				t[k] = clampf(float(d.tune[k]), float(TUNE[k][0]), float(TUNE[k][1]))
		out.tune = t
	if d.get("tz_hours") is float or d.get("tz_hours") is int:
		out.tz_hours = clampf(float(d.tz_hours), -12.0, 14.0)
	if d.get("announce") is Array:
		var an := []
		for a in d.announce:
			if not (a is Dictionary and a.get("id") is String and a.get("text") is String) or str(a.id) == "" or str(a.text).strip_edges() == "":
				continue
			var c := {"id": str(a.id).left(64), "text": str(a.text).strip_edges().left(300)}
			if a.get("text_en") is String and str(a.text_en).strip_edges() != "":
				c.text_en = str(a.text_en).strip_edges().left(300)
			for k in ["from", "to"]:
				if a.get(k) is String and parse_time(a[k], 0.0, false) >= 0.0:
					c[k] = a[k]
			if a.get("loops") is float or a.get("loops") is int:
				c.loops = clampi(int(a.loops), 1, 5)
			if a.get("repeat_hours") is float or a.get("repeat_hours") is int:
				c.repeat_hours = clampf(float(a.repeat_hours), 0.0, 720.0)
			an.append(c)
		out.announce = an
	return out


func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate(true)
	for blk in b:
		if b[blk] is Dictionary and out.get(blk) is Dictionary:
			for k in b[blk]:
				if b[blk][k] is Dictionary and out[blk].get(k) is Dictionary:
					out[blk][k] = (out[blk][k] as Dictionary).merged(b[blk][k], true)
				else:
					out[blk][k] = b[blk][k]
		else:
			out[blk] = b[blk]
	return out


## the remote file names the game versions it is meant for
func _accepts(d) -> bool:
	if not d is Dictionary:
		return false
	var v := BuildInfo.GAME_VERSION
	if d.get("min_game") is String and d.min_game != "" and BuildInfo.ver_cmp(v, d.min_game) < 0:
		return false
	if d.get("max_game") is String and d.max_game != "" and BuildInfo.ver_cmp(v, d.max_game) > 0:
		return false
	return true


# =================================================================== remote (layer 3)
## apply a downloaded config (also the test entry point); returns false when it was refused
func apply_remote(d, at: float = -1.0) -> bool:
	if not d is Dictionary:
		remote_status = "failed"
		changed.emit()
		return false
	if not _accepts(d):
		remote_status = "rejected"
		layers.remote = {}
		changed.emit()
		return false
	layers.remote = _clean(d)
	remote_at = Time.get_unix_time_from_system() if at < 0.0 else at
	remote_status = "ok"
	if not _is_test_run():
		Save.write_key(CACHE_KEY, CACHE_PATH, JSON.stringify({"at": remote_at, "cfg": d}))
	changed.emit()
	_trace("remote")
	return true


func clear_remote() -> void:
	layers.remote = {}
	remote_status = "off"
	Save.write_key(CACHE_KEY, CACHE_PATH, "")
	changed.emit()


func fetch_remote() -> void:
	if not OS.has_feature("web"):
		return
	var base = JavaScriptBridge.eval("location.origin + location.pathname.replace(/[^/]*$/, '')", true)
	if base == null or not str(base).begins_with("http"):
		return
	remote_status = "loading"
	changed.emit()
	# MV-112: each environment has its own file (features.staging.json ...); without one it uses features.json
	for file in remote_files(BuildInfo.env()):
		remote_url = str(base) + file
		var res := await _http_get(remote_url)
		if res.size() > 1 and int(res[0]) == HTTPRequest.RESULT_SUCCESS and int(res[1]) == 200:
			var raw: PackedByteArray = res[3]
			apply_remote(JSON.parse_string(raw.get_string_from_utf8()))
			return
		if res.size() > 1 and int(res[0]) == HTTPRequest.RESULT_SUCCESS and int(res[1]) == 404:
			continue      # no file for this environment: try the shared one
		break
	remote_status = "failed" if layers.remote.is_empty() else "cached"
	changed.emit()


## remote config files to try, in order: production reads features.json, other environments their own first
static func remote_files(env_id: String) -> Array:
	return ["features.json"] if env_id == "prod" else ["features.%s.json" % env_id, "features.json"]


## [result, code, headers, body] of one GET, [] if it could not start
func _http_get(u: String) -> Array:
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT_SEC
	add_child(req)
	# the query string skips any stale HTTP cache between deploys
	if req.request(u + "?t=%d" % int(Time.get_unix_time_from_system())) != OK:
		req.queue_free()
		return []
	var res: Array = await req.request_completed
	req.queue_free()
	return res


# =================================================================== tester overrides (layer 5)
func _load_dev() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(DEV_CFG) == OK:
		var d = cfg.get_value("features", "overrides", {})
		layers.dev = _clean(d) if d is Dictionary else {}


func _save_dev() -> void:
	var cfg := ConfigFile.new()
	cfg.load(DEV_CFG)     # keep Dev's own [dev] section
	cfg.set_value("features", "overrides", layers.dev)
	cfg.save(DEV_CFG)


## block = "features" | "tune" | "events" (value = the event's field dict); value null removes the override
func set_override(block: String, key: String, value: Variant) -> void:
	var d: Dictionary = layers.dev
	if not d.has(block):
		d[block] = {}
	if value == null:
		d[block].erase(key)
		_session_dev.get(block, {}).erase(key)
	else:
		d[block][key] = value
	layers.dev = _clean(d)
	_save_dev()
	changed.emit()


func set_event_on(id: String, v: bool) -> void:
	var e: Dictionary = (layers.dev.get("events", {}) as Dictionary).get(id, {}).duplicate()
	e.on = v
	set_override("events", id, e)


func clear_overrides() -> void:
	layers.dev = {}
	_session_dev = {}
	_save_dev()
	changed.emit()


## ?ff=raids:off,road_events:on,event.raiders:off,tune.threat.rate_scale:1.5
func _read_url_overrides() -> void:
	if not OS.has_feature("web"):
		return
	var q = JavaScriptBridge.eval("new URLSearchParams(location.search).get('ff') || ''", true)
	if q == null or str(q) == "":
		return
	parse_overrides(str(q))


func parse_overrides(text: String) -> void:
	var d := {}
	for part in text.split(",", false):
		var kv := part.split(":")
		if kv.size() != 2:
			continue
		var k := kv[0].strip_edges()
		var v := kv[1].strip_edges().to_lower()
		var b := v in ["on", "1", "true"]
		var blk := "events" if k.begins_with("event.") else ("tune" if k.begins_with("tune.") else "features")
		if not d.has(blk):
			d[blk] = {}
		if blk == "events":
			d[blk][k.trim_prefix("event.")] = {"on": b}
		elif blk == "tune":
			d[blk][k.trim_prefix("tune.")] = v.to_float()
		else:
			d[blk][k] = b
	_session_dev = _clean(d)
	changed.emit()


# =================================================================== trace
func snapshot() -> Dictionary:
	var off := []
	for k in FEATURES:
		if not on(k):
			off.append(k)
	var ev_off := []
	for id in Data.EVENTS:
		if not bool(event_cfg(id).get("on", true)):
			ev_off.append(id)
	var tune := {}
	for k in TUNE:
		if _value("tune", k, null) != null:
			tune[k] = num(k, 0.0)
	return {"off": off, "events_off": ev_off, "tune": tune, "remote": remote_status, "dev": has_dev_overrides()}


func _trace(why: String) -> void:
	Trace.rec("features", why, snapshot())
