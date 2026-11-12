---
name: lore-crew
description: MV-778 every crew member is a fixed lore character (switch lore_crew, LoreCrew.CAST 13 chars), recruits in story order, old saves migrated once
metadata:
  type: project
---

2026-11-12 Parames: "ระบบคน ไม่เอาสุ่มตัวมา ... ยึดตาม Lore ของแต่ละตัวเลย" (no random people; follow each character's lore). Plane MV-778.
- `scripts/autoload/lore_crew.gd` (class LoreCrew, static): CAST = ren, clara, bit, wan, tham, fah, ploy, noi, mali, pim, sorn, lin, krai (name, role, stats, old dw_* variant, act). Traits in Crew.FIXED, bios in Lore.BIOS, lines in Lore.LINES_PERSONAL (from designs/lore-crew-3/page/build.py + special-crew-3 concepts).
- Start crew in the old five slots: Fah (loader, was Mark), Tham (gunner, Leo), Bit (builder in cab, Ton), Auntie Wan (kitchen, Bob), Clara. Recruits = LoreCrew.ORDER (Act 1-3), the fallen only when nobody else is left; full cast -> offer_recruit {} with Game.recruit_fail "cast"; strangers skipped.
- Dr. Ren: tune lore_crew.ren_start (0 guide only = default, 1 sixth crew, 2 replaces Clara). Decision card posted 2026-11-12, recommended 0.
- Old saves: LoreCrew.migrate once (s.lore_crew = 1): Mark->Fah, Leo->Tham, Ton->Bit, Bob->Wan, Bruno->Krai, others next free char with the same best stat; stats/level/gear kept.
- Mali + PIM-3 (MV-742 approved sets) imported into assets/v3 via tools/v3_import.py (PORTRAIT_DIRS for their portraits).
- Cast size limits the crew to 12 (13 with Ren). More lore characters (Jaew/Dao/Tonkla MV-747 awaiting picks) need full anim sets + import to raise it.
- Autotest pins lore_crew off for the old tests; `--only=lore_crew` checks the cast.
