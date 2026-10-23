# Thai glossary & style (MV-93)

The one list of in-game Thai terms. When you add or change Thai text, use these words, and add new
terms here in the same PR. Autotest `--only=thai` checks the parts a script can check (unique names,
no "Overseer" for the player, Thai-only event buttons, biome names match the logbook).

## Voice

| Where | How it sounds |
|---|---|
| UI labels, buttons, toasts, tooltips | Short and neutral, no particles (ครับ/ค่ะ/นะ). Verb first on buttons: "ส่งทีมสำรวจ", "รับขึ้นรถ". |
| Crew chatter, bios, lore, stranger stories | Natural spoken Thai, each character in their own voice (below). Rough and dark is fine; no forced slang. |
| Tutorial | จ่ามาร์ค speaking to the player: polite soldier, ผม … ครับ, calls the player **ผู้บัญชาการ**. |
| Event / encounter descriptions | Third person, present tense, short sentences, like a field report. Spoken lines go in quotes `\"...\"`. |

Characters: **จ่ามาร์ค** ผม/ครับ, terse and military · **ลีโอ** ฉัน, casual street kid · **ต้น** ฉัน, talks to the engine
like a pet · **เชฟบ็อบ** ข้า, theatrical · **พยาบาลคลารา** ฉัน, calm and caring (นะทุกคน) · **บรูโน่** ข้า, few words.
Generic crew lines use ฉัน/เรา.

**เขา** is fine for a person of unknown gender (it is gender-neutral in Thai). Avoid "ชายหญิง…" constructions.

## The player and the world

| English | Thai | Notes |
|---|---|---|
| the player | ผู้บัญชาการ / คุณ | Never "Overseer": OVERSEER is the villain AI. |
| Mobile Vault (the vehicle) | รถ, รถบ้าน · "Mobile Vault" in UI labels | "Vault Lv." stays English. |
| crew member | ลูกเรือ | Anyone aboard. List title: รายชื่อลูกเรือ. |
| survivor (met outside) | ผู้รอดชีวิต | Before they board. Don't use ผู้ลี้ภัย in new text. |
| stranger at the door | คนแปลกหน้า | |
| joins the crew | ขึ้นรถมาร่วมทาง / ขึ้นรถแล้ว | Not "เข้าร่วมรถบ้าน". |
| bed / pop cap | เตียง | "+4 เตียงต่อเลเวล", "ต้องมีเตียงว่าง". |
| Ember Fall | วันไฟตก | |
| Ember Cult | ลัทธิเปลวสุริยะ | Same name in the event and the logbook. |
| HELIOS RING, OVERSEER, MAMMOTH-7, AURORA | keep English | Proper nouns. |
| The Last City of Light | นครแสงสุดท้าย | |
| signal 104.7 | สัญญาณ 104.7 | |

## Biomes (map, HUD and logbook use the same name)

| id | Thai | English |
|---|---|---|
| industrial | ซากนิคมอุตสาหกรรม | INDUSTRIAL RUINS |
| desert | ทะเลทรายแก้ว | DESERT BIOME |
| forest | ป่ารกร้าง | OVERGROWN FOREST |
| swamp | หนองน้ำพิษ | TOXIC BAYOU |
| tundra | ทางหลวงน้ำแข็ง | FROZEN HIGHWAY |
| metro | มหานครแห่งสัญญาณ | SIGNAL METROPOLIS |

In sentences say "พื้นที่" for biome, never "Biome".

## Resources & items

| English | Thai |
|---|---|
| power | ไฟ (ไฟฟ้า when "ไฟ" could read as fire) |
| water / food / fuel / scrap | น้ำ / อาหาร / เชื้อเพลิง (น้ำมัน in engine text) / เศษเหล็ก |
| components | ชิ้นส่วน (ชส. only where space is tight) |
| stimpack | สติมแพ็ก (not ยาสติมแพ็ก / ยารักษา) |
| RadAway | ยาต้านรังสี |
| antibiotics | ยาปฏิชีวนะ |
| ammo | กระสุน |
| blueprint | พิมพ์เขียว |
| item | ไอเทม |
| gear | อุปกรณ์ |

## Vehicle & systems

| English | Thai |
|---|---|
| hull | ตัวถัง (HULL label stays English) |
| plating (gear slot) | เกราะรถ |
| engine bay | ห้องเครื่อง |
| tune-up (engine job) | เช็กระยะ |
| engine tune (mod) | จูนเครื่องยนต์ |
| overhaul | ยกเครื่อง |
| coolant / oil | น้ำหล่อเย็น / น้ำมันเครื่อง |
| trailer / wagon | รถพ่วงท้าย / โบกี้ |
| checkpoint | ด่านตรวจ |
| toll | ค่าผ่านทาง |
| threat | ภัยคุกคาม · phases: เงียบสงบ / มีวี่แวว! / ถูกบุก / เก็บกวาดซาก |
| raid | การบุก, "ถูกบุก!" |
| expedition | การสำรวจ, ทีมสำรวจ |
| special encounter | จุดพิเศษ |
| research points (legacy) | แต้มวิจัย / แต้มวิจัยพันธุกรรม (not มรดก) |
| prestige / next generation | ส่งต่อรุ่น, รุ่นถัดไป |
| game mode / difficulty / mutators | โหมด / ความยาก / กฎพิเศษ |

## Crew stats & combat

| English | Thai |
|---|---|
| STR / INT / AGI, HP, XP, Lv., DPS | keep English |
| trait | นิสัย (not "Trait" in Thai sentences) |
| role (job before the fall) | อาชีพ |
| skill / skill tree | สกิล / ผังสกิล |
| damage | ดาเมจ |
| attack speed | ความเร็วโจมตี; stat row "โจมตี/วิ" (melee weapons too) |
| crit | คริติคอล |
| dodge | หลบหลีก |
| thorns | ดาเมจสะท้อน |
| heal | ฮีล in short stat text, รักษา in sentences |
| wave / boss / warlord | เวฟ / บอส / บอสด่านตรวจ |
| defence squad | ทีมป้องกัน: มือปืนหลังคา, นักสู้ท้ายรถ, แพทย์สนาม |
| reserve (roof deck) | ตัวสำรองบนดาดฟ้า |
| strike | ประท้วงหยุดงาน, ends with "เลิกประท้วง" |

Names a player chooses between must be unique across traits, skill nodes, squad roles and role
skills (the autotest checks this). Current skill nodes that were renamed for that: ว่องไว (attack
speed), ภูมิต้านรังสี (rad resist), รักษาไว (field medic node).

## Outcome screens: say what happened

The stamp and first line on a result screen must fit the choice, not just success/failure. Road
events take the stamp from `EventPopup.STAMPS` by action (ชนะแล้ว / หนีพ้น / จ่ายแล้ว / ตกลงกันได้ /
สมาชิกใหม่ / ไปต่อ …; failures: พ่ายแพ้ / พลาดท่า / แพ้พนัน). When the action's default doesn't fit the
scene, give the choice its own `"result"` line and `"stamp": [EN, TH]` in `Data.EVENTS`, e.g. tossing
food to the stray dog is "ใจดีจัง", not a survivor crying with thanks. Never a blanket "รอดมาได้".

## English labels

The small English tags (`"en"`, window titles like `GARAGE / อู่ปรับแต่งรถ`, stamps) follow the same rules:

- **US spelling**: ARMOR, ARMORED, ARMORY, DEFENSE (not ARMOURED / DEFENCE).
- **Same meaning as the Thai** next to it, and the same name as the thing it makes (CRAFT RADAWAY makes RadAway;
  GLASS DESERT = ทะเลทรายแก้ว).
- **Unique** across traits, skill nodes and squad roles in English too (skill nodes: SWIFT STRIKES, RAD TOLERANCE,
  FAST HEALER, HANDYMAN, SIGNATURE MOVE).
- Stamps read as plain words: MISSION SUCCESS, VICTORY, DEAL, NEW PET (no "MISSION OK"). A stamp wider than the
  1x picture wraps onto two lines by itself (`OutcomeKit.stamp`).

## Spelling

ทีมเวิร์ก, เช็ก, อัปเกรด, ไอเทม, สติมแพ็ก, แบตเตอรี่, ล็อกอิน. Use the Royal Institute spelling for loanwords
when one exists. ๆ goes after a space in prose ("ช้า ๆ"); existing UI text without the space is fine.
