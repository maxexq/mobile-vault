---
name: resources-changed-every-frame
description: Game.resources_changed fires every sim frame; UI must not rebuild buttons on it (taps get lost) — PR #10 loot tab fix
metadata:
  type: project
  modified: 2026-10-22T19:03:16.271Z
---

`Game.resources_changed` is emitted every simulation frame (end of `Game._simulate`). A panel that calls `refresh()` (free + recreate children) on it destroys its buttons between touch-down and release, so taps never fire `pressed`. This was the "ไอเทม tab then other tabs can't be tapped" bug in LootPanel, fixed in PR #10 (branch fix/loot-tabs-tap, 2026-10-22): rebuild only when a layout signature changes, otherwise retext labels in place.

**Why:** Parames reported the items window tabs freezing after opening the items tab.
**How to apply:** in any panel, connect resources_changed only to in-place label/disabled updates. Autotest taps can be blocked by road-event popups fired during the run; call `panel.move_to_front()` before pushing input (`Viewport.push_input(ev, true)` for viewport coords). Related: [[expedition-encounters]]
