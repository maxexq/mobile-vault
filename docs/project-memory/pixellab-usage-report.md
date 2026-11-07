---
name: pixellab-usage-report
description: Parames rule 2026-10-29: after every PixelLab ("pl") use, report what it was for, gens used, and gens remaining (check balance)
metadata:
  type: feedback
  modified: 2026-10-29T22:45:23.076Z
---

2026-10-29 22:44 Parames: every time a PixelLab job finishes, tell them what it was used for, how many gens it used, and how many are left. "pl" = PixelLab.
**Why:** gens are Parames's paid subscription (Tier 3 Pixel Architect, ~9839/month); a run once cost ~2x the estimate.
**How to apply:** read GET https://api.pixellab.ai/v2/balance (subscription.generations) before and after each job; in the reply add one line: "PixelLab: <purpose> · <model/endpoint, e.g. Pro generate-image-v2, Pro inpaint-v3, Pro edit-images-v2, Pixen create-image-pixen> · used N gens · left M / total". Note if other threads may have spent gens in the same window. Still ask before big spends ([[pixellab-api]]). Related: [[armory-redesign]].

- 2026-10-30 12:19 Parames added: every PixelLab report must also name the model / API endpoint used.
