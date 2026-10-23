# mv_ai: LangGraph ผู้ช่วยหลายโมเดลของ Mobile Vault

LangGraph pipeline ที่ค้นโค้ด/เอกสารใน repo แล้วเลือกโมเดลที่เหมาะกับคำถาม (ฐานของงาน RAG ใน Plane MV-77, ใช้ทำผู้ช่วยบาลานซ์ MV-78 ต่อ)

```
START → retrieve → route ─┬→ local   Qwen3-4B บน Ollama: งานสั้น/งานกลไก ฟรีและไม่ออกจากเครื่อง
                          ├→ opus    Claude Opus 5.5: บาลานซ์ ตัวเลข ดีไซน์ บั๊ก รีวิวโค้ด
                          └→ gemini  Gemini 4 Argon: อ่านเยอะทั้ง repo / log ยาว (context 1M)
```

- **retrieve**: ค้นแบบ BM25 ใน `scripts/`, `tools/*.gd`, `docs/`, `README.md`, `config/` (ไม่ต้องใช้ embedding) ถ้าไป Gemini จะดึง context กว้างขึ้น 10 เท่า
- **route**: ให้ Qwen local ตอบคำเดียวว่า `local/opus/gemini` ถ้า Ollama ไม่ทำงานหรือตอบมั่ว ใช้กฎ keyword แทน และถ้าโมเดลที่เลือกไม่มี key จะส่งต่อให้ตัวถัดไปอัตโนมัติ
- โฟลเดอร์นี้มี `.gdignore` ให้ Godot ข้าม จึงไม่กระทบการ export เกม

## ติดตั้ง (Windows, ใช้ uv)

```powershell
cd ai
copy .env.example .env      # แล้วใส่ ANTHROPIC_API_KEY / GEMINI_API_KEY ในไฟล์เอง ห้ามส่ง key ในแชท
uv sync
ollama pull qwen3:4b        # ครั้งเดียว
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
| `MV_LOCAL_MODEL` | `qwen3:4b` | |
| `MV_LONG_CONTEXT_CHARS` | `60000` | context ยาวเกินนี้ส่ง Gemini |

ราคาโดยประมาณต่อ 1M token (ต.ค. 2026): Opus 5.5 $4 in / $20 out · Gemini 4 Argon $2 / $10 ถึง 30 พ.ย. แล้วเป็น $4 / $20 · Qwen local ฟรี

## ต่อยอด
- MV-78 ผู้ช่วยบาลานซ์: เพิ่ม node ที่รัน `godot --headless -- --balance` แล้วส่งผลให้ Opus วิเคราะห์
- เปลี่ยน retrieve เป็น embedding (เช่น `qwen3-embedding` บน Ollama) เมื่อ repo ใหญ่ขึ้น
