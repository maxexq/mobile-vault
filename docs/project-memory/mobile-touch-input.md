---
name: mobile-touch-input
description: Mobile web touch rules (PR #27, MV-86): touch index = browser Touch.identifier, ScrollContainer drag needs PASS children, autotest via Input.parse_input_event
metadata:
  type: project
  modified: 2026-10-23T17:50:09.272Z
---

2026-10-23 Parames reported: lists only scrolled via the scrollbar; vehicle swipe didn't pan and the camera flipped normal/wide. Fixed in PR maxexq/mobile-vault#27 (MERGED 2026-10-23), Plane MV-86, artifact v37.
- On Godot web, InputEventScreenTouch.index = browser Touch.identifier (iOS never reuses ids). Input dispatches the emulated mouse event BEFORE the touch event, so a tap that opens a panel makes the touch-up arrive while a modal is open. Book finger releases in `Main._input`, never behind the modal check.
- ScrollContainer drags only from emulated mouse events that propagate up through `Viewport._gui_call_input`; any MOUSE_FILTER_STOP child blocks it. `UIKit.touch_pass` (HUD hooks SceneTree.node_added) flips STOP->PASS inside scroll containers; buttons cancel their press on NOTIFICATION_SCROLL_BEGIN. New custom controls inside lists that need STOP must be in its exclusion list.
- ScrollContainer touch-drag requires DisplayServer.is_touchscreen_available(); desktop autotest sets Input.emulate_touch_from_mouse = true for that part.
- Autotest `_touch_test` (`-- --autotest --only=touch`) feeds InputEventScreenTouch/Drag via Input.parse_input_event in window coords (get_viewport().get_screen_transform() * design pos). Browser repro rig: Playwright Chromium isMobile+hasTouch + CDP Input.dispatchTouchEvent with distinct ids.
- Artifact page source is not in git: rebuild build/artifact/mobile_vault.html from an Artifact read, update `gz` of pack + fileSizes["index.pck"]. cloud_config.json can be recovered from the committed web/index.pck (plain JSON inside).

**How to apply:** any new world gesture or list UI should keep these rules and extend `_touch_test`. Related: [[resources-changed-every-frame]], [[backend-database-choice]], [[god-mode]]
