# mv_ai: LangGraph ผู้ช่วยหลายโมเดลของ Mobile Vault

LangGraph pipeline ที่ค้นโค้ด/เอกสารใน repo แล้วเลือกโมเดลที่เหมาะกับคำถาม (ฐานของงาน RAG ใน Plane MV-77, ใช้ทำผู้ช่วยบาลานซ์ MV-78 ต่อ)

```
START → retrieve → route ─┬→ local   local model บน Ollama (gemma4:12b): งานสั้น/งานกลไก ฟรีและไม่ออกจากเครื่อง
                          ├→ opus    Claude Opus 5.5: บาลานซ์ ตัวเลข ดีไซน์ บั๊ก รีวิวโค้ด
                          └→ gemini  Gemini 4 Argon: อ่านเยอะทั้ง repo / log ยาว (context 1M)
```

- **retrieve**: ค้นแบบ BM25 ใน `scripts/`, `tools/*.gd`, `docs/`, `README.md`, `config/` (ไม่ต้องใช้ embedding) ถ้าไป Gemini จะดึง context กว้างขึ้น 10 เท่า
- **route**: ให้ local model ตอบคำเดียวว่า `local/opus/gemini` ถ้า Ollama ไม่ทำงานหรือตอบมั่ว ใช้กฎ keyword แทน และถ้าโมเดลที่เลือกไม่มี key จะส่งต่อให้ตัวถัดไปอัตโนมัติ
- โฟลเดอร์นี้มี `.gdignore` ให้ Godot ข้าม จึงไม่กระทบการ export เกม

## ติดตั้ง (Windows, ใช้ uv)

```powershell
cd ai
copy .env.example .env      # แล้วใส่ ANTHROPIC_API_KEY / GEMINI_API_KEY ในไฟล์เอง ห้ามส่ง key ในแชท
uv sync
ollama pull gemma4:12b      # ครั้งเดียว (ถ้ายังไม่มี)
uv run python -m mv_ai --ping
uv run python -m mv_ai "ดรอปของบอส warlord โหดเกินไหม ดูจาก loot table"
uv run python -m mv_ai --model gemini "สรุปทุกระบบใน repo ว่าเชื่อมกันยังไง"
uv run pytest               # เทสออฟไลน์ ไม่เรียก API จริง
```

> หมายเหตุ: `127.0.0.1:8188` คือ ComfyUI (gen ภาพ) ไม่ใช่ LLM ไฟล์ `qwen_3_4b.safetensors` ในนั้นเป็น text encoder ของ Flux ใช้แชทไม่ได้ local LLM ใช้ Ollama ที่พอร์ต 11434 แทน (ตั้งที่ `MV_LOCAL_BASE_URL` ใช้กับ server แบบ OpenAI-compatible ตัวไหนก็ได้)

## โมเดลและค่าตั้ง (`.env`)

| ตัวแปร | ค่าเริ่มต้น | หมายเหตุ |
|---|---|---|
| `MV_CLAUDE_MODEL` | `claude-opus-5-5` | Anthropic SDK, adaptive thinking, streaming, refusal fallback ฝั่ง server |
| `MV_CLAUDE_EFFORT` | `high` | `low`…`max` (Opus 5.5 ปิด thinking ไม่ได้ คุมด้วย effort) |
| `MV_GEMINI_MODEL` | `gemini-4-argon` | google-genai Interactions API |
| `MV_GEMINI_THINKING` | `high` | `low` / `medium` / `high` |
| `MV_LOCAL_BASE_URL` | `http://127.0.0.1:11434/v1` | Ollama |
| `MV_LOCAL_MODEL` | `gemma4:12b` | lore, เนื้อเรื่อง, ตรวจคำแปล และเลือกเส้นทางใน `mv_ai` |
| `MV_LONG_CONTEXT_CHARS` | `60000` | context ยาวเกินนี้ส่ง Gemini |

ราคาโดยประมาณต่อ 1M token (ต.ค. 2026): Opus 5.5 $4 in / $20 out · Gemini 4 Argon $2 / $10 ถึง 30 พ.ย. แล้วเป็น $4 / $20 · local model ฟรี

## ทีม Agent (Opus 5.5 เป็นหัวหน้า)

```
START → lead (Claude Opus 5.5 ผู้พัฒนาหลัก) ─delegate→ coder   (Opus 5.5: อ่าน/ค้น/แก้ไฟล์ใน repo)
          ↑                                           tester  (Opus 5.5: รัน autotest / balance sim)
          │                                           analyst (Gemini 4 Argon: วิเคราะห์ทั้ง repo, log ยาว, ตรวจภาพหน้าจอ)
          │                                           writer  (gemma4:12b local: lore, เนื้อเรื่อง, ข้อความอีเว้นท์, ตรวจคำแปล)
          └───────────────────────── ผลกลับมาที่ lead ─────────────────────────────┘
lead จบงาน → END พร้อมรายงานว่าแก้ไฟล์อะไร ทดสอบอะไรแล้ว เหลืออะไร
```

```powershell
git checkout -b feature/ชื่องาน         # ให้ทีมทำงานบน branch แยก
uv run python -m mv_ai.team "เพิ่ม feature switch ให้ engine_bay แล้วรัน autotest แบบ large"
uv run python -m mv_ai.team --yes "..." # อนุมัติการแก้ไฟล์ทั้งหมดอัตโนมัติ (ระวัง)
```

- lead ส่งงานให้ทีละคน แล้วเอาผลมาตัดสินใจต่อ agent ลูกไม่เห็นบทสนทนาของ lead lead จึงต้องใส่ context ให้ครบในงานที่สั่ง
- **ทุกครั้งที่จะเขียนหรือแก้ไฟล์ graph จะหยุดรอให้กด y/N** (LangGraph interrupt) ถ้าตอบ N ก็ไม่แก้ และ coder จะรู้ว่าถูกปฏิเสธ
- ทีมไม่ commit และไม่ push ให้ ดูผลด้วย `git diff` แล้ว commit เองตามปกติ
- agent อ่าน `.env`, `.git`, `cloud_config.json` ไม่ได้ และแก้ไฟล์นอก repo ไม่ได้
- tester ต้องมี Godot 4.7.2: ใส่ path ไว้ใน `MV_GODOT_BIN` ใน `.env` ถ้าไม่มี tester จะรีวิวจากโค้ดแทน
- **analyst** ได้ส่วนของ repo ไปกว้างๆ (120 ชิ้น) ถ้าในงานมี path ของภาพ `.png/.jpg/.webp` (ใน repo หรือโฟลเดอร์ผล autotest) จะแนบภาพไปให้ Gemini ตรวจ layout, ตัวหนังสือล้น และ pixel art
- **writer** ได้ข้อความในเกมที่เกี่ยวข้องไปเป็นแนวอ้างอิง เพื่อใช้ชื่อ คำศัพท์ และน้ำเสียงเดิม ตรวจคำแปลจะตอบเป็นรายการ ต้นฉบับ → ที่แนะนำ → เหตุผล ส่วนการเอาข้อความไปใส่ไฟล์เป็นงานของ coder
- local model ตั้งที่ `MV_LOCAL_MODEL` (ค่าเริ่มต้น `gemma4:12b`) ถ้าไม่มี Gemini key หรือ Ollama ไม่ได้เปิด งานของ analyst/writer จะส่งให้ Opus ทำแทน
- ค่าใช้จ่าย: ทุกตาของ lead/coder/tester คือการเรียก Opus 5.5 หนึ่งครั้ง ($4/$20 ต่อ 1M token) งานแก้โค้ดหนึ่งงานมักใช้ 10–40 ตา จำกัดไว้ที่ lead 25 ตา และ agent ลูก 40 ตาต่องาน

### หน้าเว็บสั่งงานและดูการทำงานของแต่ละ agent

```powershell
uv run python -m mv_ai.ui        # เปิด http://127.0.0.1:8765/ ให้อัตโนมัติ
```

- พิมพ์งานทางซ้ายแล้วกด **เริ่มงาน** (ติ๊ก "อนุมัติอัตโนมัติ" ถ้าไม่อยากกดเอง)
- การ์ดของ lead / coder / tester / analyst / writer บอกสถานะ จำนวนตา จำนวน tool และ token กับค่าใช้จ่ายของแต่ละตัว กดการ์ดเพื่อกรอง timeline ให้เหลือแค่ agent นั้น
- **Timeline**: กดแต่ละแถวเพื่อดูความคิด (สรุป) ข้อความ tool call ที่ส่งไปพร้อม input และผลลัพธ์ที่ได้กลับมา
- ตอนที่ agent จะแก้ไฟล์ จะมีกล่องสีเหลืองโชว์ diff พร้อมปุ่ม **อนุมัติ / ปฏิเสธ** มีปุ่ม **หยุดงาน** ไว้ยกเลิกงานกลางคันได้
- server ฟังแค่ `127.0.0.1` (เปิดจากเครื่องอื่นไม่ได้) และข้อมูลไม่ออกจากเครื่อง ยกเว้นที่ส่งไปเรียก API ของโมเดล ประวัติงานอยู่ในหน่วยความจำ ปิด server แล้วหายหมด
- ค่าใช้จ่ายคิดเฉพาะส่วนของ Claude (ราคา Opus 5.5) ส่วน Gemini ยังไม่ได้นับ (local ฟรี)

## ต่อยอด
- MV-78 ผู้ช่วยบาลานซ์: เพิ่ม node ที่รัน `godot --headless -- --balance` แล้วส่งผลให้ Opus วิเคราะห์
- เปลี่ยน retrieve เป็น embedding (เช่น `qwen3-embedding` บน Ollama) เมื่อ repo ใหญ่ขึ้น
