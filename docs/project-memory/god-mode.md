---
name: god-mode
description: GOD MODE tester console layout (PR #12) and the rule that every new feature adds Dev.* actions + a god tab entry
metadata:
  type: project
  modified: 2026-10-22T19:44:46.782Z
---

GOD MODE = scripts/ui/god_panel.gd (UI) + scripts/autoload/dev.gd (Dev.* actions, each calls act() → trace + stats.cheated). PR #12 (2026-10-22, branch feat/god-mode-update) brought it up to date: new tab "ระบบ" (version, tutorial replay/skip/goto, cloud sync/force upload/forget, settings reset); builders + construction traits, strangers kind×grade, squad auto, forge kit, event deck draw/reshuffle, encounter_anywhere (sends a free scav team). Autotest: `_god_update_test()` in tools/autotest.gd.

The deployed artifact build ships WITHOUT cloud_config.json (cloud OFF) — the pack had no config when checked on 2026-10-22; see [[backend-database-choice]].

**Why:** Parames asked "อัพเดท GOD mode ให้ล่าสุด" — testers need shortcuts for every system.
**How to apply:** when adding a feature, add its Dev.* action(s), a button in the matching god tab, a README §4f row update, and an autotest check. The "encounter: refugee joined on return" check was flaky (elite refugee may go to the door) and was fixed in #12.
