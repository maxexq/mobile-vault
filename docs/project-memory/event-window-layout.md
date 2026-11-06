---
name: event-window-layout
description: Event/encounter popups use ChoiceButton + ModalPanel.media_layout; Thai web wrapping needs ICU data (PR #11)
metadata:
  type: project
  modified: 2026-10-22T19:20:45.006Z
---

PR #11/#16 (branches fix/event-choice-layout, fix/encounter-outcome, 2026-10-22) fixed clipped Thai text in the random event window.
- New choice-style buttons: use `ChoiceButton.new(th, en, sub, color)` (scripts/ui/choice_button.gd). It grows with wrapped text. A plain Button with child labels does NOT grow and overflows.
- Popups with 160x80 art: use `ModalPanel.media_layout(tex, line_color)` → returns the text VBox; `media` holds the art frame. Landscape (vp.x>vp.y and >=560) widens the window to 640 with the art beside the text. Otherwise the art goes on top.
- `internationalization/locale/include_text_server_data=true` in project.godot is REQUIRED for Thai word wrapping on the web (ICU dictionaries, adds ~4.8 MB to index.pck). Desktop/editor runs wrap fine without it, so autotest screenshots won't catch a regression.
- Outcome screens share `OutcomeKit` (scripts/ui/outcome_kit.gd: stamp, count-up rows, crew chips); used by EventPopup, EncounterPopup radio outcome and ExpeditionPanel report (PR #16). `Expedition.finish()` puts gain/want/gear/crew into the report dict.
- The event outcome screen diffs a before/after snapshot (`EventPopup._snapshot/_changes`), so new event actions get rows automatically.

**Why:** Parames reported unreadable/cut event choices and an empty outcome screen.
**How to apply:** when the artifact page is read via `path: index.html`, the saved copy is wrapped in a host skeleton. Strip everything before the 2nd `<!doctype html>` and the trailing `</body></html>` before republishing. Related: [[expedition-encounters]], [[random-event-selection]]
