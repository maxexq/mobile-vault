---
name: loot-economy-design
description: Loot/drop reward analysis (2026-10-22) for Mobile Vault: cascading loot tables, pity, chase items; trading needs server; blockchain/NFT not recommended
metadata:
  type: project
---

2026-10-22 analysis (no code changed), page: https://claude.ai/artifact/5aqk93edTAsuzM1PhzgKT2
- Current: loot.gd rarity weights 600/250/100/40/9/1, luck scales rare+ weights AND drop chance; normal kill 6.5%; no pity; slot/base uniform; LEGEND_NAMES are names only (no effects); offline gives no gear; prestige wipes gear except carried weapons; forge 3->1 makes rarity cheap (~38 drops per mythic via synth vs ~435 natural at luck 30).
- Parames shared a video on loot tables (flat -> weighted -> rarity-first -> cascading rolls with locked per-tier odds, conditional sub-tables); recommended switching roll_rarity to cascading so luck/pity apply per tier and adding bases doesn't shift odds.
- Priority: pity+meter, biome/boss tables, unique-effect legendaries + codex, heirloom slot, offline crates; trading only after Supabase with server-rolled tradables ([[backend-database-choice]]). Blockchain/NFT: advised against.
**How to apply:** Awaiting Parames's pick; coordinate item effects with the strategic-depth/builds thread.
