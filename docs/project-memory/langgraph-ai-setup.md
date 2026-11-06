---
name: langgraph-ai-setup
description: LangGraph multi-model setup (MV-85..90): Opus 5.5 + gemini-4-argon + local gemma4:12b via Ollama; port 8188 is ComfyUI not an LLM
metadata:
  type: project
---
2026-10-23 Parames asked for a LangGraph setup with Claude Opus + "Gemini 4 Argon" + local "GWEN3_4B at 127.0.0.1:8188". Plane ticket MV-85 (child of RAG MV-77).
- 127.0.0.1:8188 on Soba is ComfyUI 0.42.1 (portable, F:\AI\ComfyUI_windows_portable). The qwen_3_4b.safetensors there is the Flux-2-klein text encoder, NOT a chat LLM.
- Soba: RTX 4070 Ti SUPER 16GB, 34GB RAM, no system Python (only ComfyUI's embedded one: never install into it).
- Parames approved (decision card) installing Ollama + qwen3:4b + uv on Soba. Local LLM endpoint = Ollama OpenAI-compatible http://127.0.0.1:11434/v1.
- Verified ids: Claude `claude-opus-5-5`; Gemini `gemini-4-argon` (stable, 1M ctx, google-genai `client.interactions.create`, thinking_level low/medium/high, sampling params ignored, key env GEMINI_API_KEY).
- Code lives in repo `ai/` (with .gdignore so Godot skips it). API keys only in local .env, never chat.
Related: [[drawdy-systems-map]], [[plane-setup]].
- 2026-10-23 installed on Soba: Ollama 0.40.9, qwen3:4b (always thinks; think:false/reasoning_effort/no_think don't stop it, so router needs big max_tokens), uv 0.13.5. PR #25 cloned at C:\Users\param\Downloads\mobile-vault with ai\.venv; 9 tests pass, local route ~22s per answer.
- Gotcha: uv run from the Claude desktop (MSIX) Remote Control breaks under AppData\Roaming redirect; set UV_PYTHON_INSTALL_DIR/UV_CACHE_DIR to %USERPROFILE%\.uv\... and --python 3.13. Normal terminal is fine.
- Option not yet approved: qwen3:4b-instruct-2507 (non-thinking, faster router) needs a new download.
- 2026-10-23 agent team (MV-87, PR #26 stacked on #25): `uv run python -m mv_ai.team "task"`; Opus 5.5 lead delegates to coder/tester (Opus, repo tools), scout (Gemini), scribe (Qwen). File writes pause via LangGraph interrupt for y/N; no git write tools. Tester needs MV_GODOT_BIN.
- 2026-10-23 Parames chose own local web UI over LangGraph Studio (Studio needs LangSmith account/key, hosted at smith.langchain.com). MV-88 PR #28: `uv run python -m mv_ai.ui` -> 127.0.0.1:8765, per-agent cards/timeline/approve buttons, stdlib server. Screenshots in /mnt/project-files/screens/agent-ui/.
- 2026-10-23 Parames set roles (MV-89, PR #29): Opus 5.5 = main dev (lead/coder/tester); Gemini 4 Argon = analyst (whole repo, logs, screenshot review); local gemma4:12b (Parames installed it) = writer for lore/story and Thai localization QA. Local default model is now gemma4:12b.
- MV-89 PR #29: roles = Opus 5.5 lead/coder/tester, analyst=Gemini 4 Argon (repo + screenshots), writer=local gemma4:12b (lore + Thai localization QA). UI redesigned Claude-style (Parames wants it pretty/simple, and per-agent detail of what each is doing): team emits llm_start/tool_start; POST /api/runs/<id>/message for follow-ups.
- MV-90 PR #30: Parames's Anthropic key is org-level (not workspace-scoped) -> set ANTHROPIC_WORKSPACE_ID in ai/.env (sent as anthropic-workspace-id header). Their ai/.env still had MV_LOCAL_MODEL=qwen3:4b (env overrides code default); told them to change it to gemma4:12b.
- MV-91 PR #31: MV_TEAM=local (or web UI team picker per run) makes the local model do every role via llms.local_turn (Ollama tools, JSON fallback). Parames chose this because Claude API had no credit; app Pro/Max quota cannot be used by mv_ai (only Claude Code).
