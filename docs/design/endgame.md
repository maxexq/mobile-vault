# End-game design + combat style decision

Draft for Parames (28 Oct 2026), ticket MV-572. Nothing here is built yet; every part below is its own
Backlog ticket (MV-573..MV-582) with the usual feature switch, GOD button and autotest group.

## 1. Turn-based or auto-battler?

**Recommendation: stay an auto-battler, PriConne-style (real-time auto + optional manual ultimate),
and put the depth into the planning before the fight, not into each turn.**

| Question | Turn-based (FF, Another Eden, E7, Summoners War) | Auto-battler (CRK, PriConne, AFK Arena) |
|---|---|---|
| Fits idle + 4 h offline? | No. A turn needs a decision; "auto" in E7/SW is a bolt-on, the game is balanced around manual play. | Yes. It already is how raids, offline kills and the balance bot work. |
| Fits the 3-role defence squad on the rear deck while the truck drives? | No. Turn-based means leaving the road for a separate battle screen; the vehicle stops being the stage. | Yes. The fight happens on the truck, in the world, with weather / night / threat around it. |
| Characters | Needs a hand-made hero roster with unique kits (E7 has 200+). Our survivors are procedural (traits, skill tree, 20 traits) and can die. | Procedural survivors + gear + traits is exactly the AFK / Taskbar-Hero build model. |
| Art cost (16-bit, PixelLab credits) | Every hero needs idle / attack / skill / hit / death sheets plus skill VFX, at battle-screen size. | Reuses the existing crew sprites and combat_view. |
| Web, single-threaded, phone | Fine either way. | Fine. |
| Rewrite size | `combat.gd`, `threat.gd`, offline, balance bot, squad, deck tag-in, boss mechanics: all of it. | Additive. |

What turn-based games do well, and how to get it without turns:

1. **Readable counter-play** (E7 / SW: "this boss punishes X, bring Y"). Keep boss mechanics (enrage,
   armour, summon, burrow, acid, solar dive) and *tell the player before the fight* with a boss card:
   "armour above 60 % → bring armour-break". Prep screen = the decision point.
2. **Skill timing** (PriConne UB, CRK skills). Each squad role's skill (Volley, Ground Slam, Patch Up)
   stays auto, but during a boss the player may tap the portrait to fire it at the right moment
   (e.g. Ground Slam stun the boss as it starts a burrow). Auto still clears normal content; manual
   adds ~10–20 % on bosses and is required only in the top end-game tier.
3. **Behaviour rules** (FF12 gambits, light version). 2–3 rule slots per squad member:
   "medic: heal at < 40 % HP / repair hull at < 50 %", "gunner: target flyers first / target elites".
   Unlocked by the Combat skill branch. This is turn-based depth that still runs offline.
4. **Formation** grows from 3 to 5: roof (gunner + spotter), rear deck (bruiser + second melee),
   medic. The roof deck reserve already shows the hook.

Not recommended: a turn-based side mode. Two combat systems = two balance sheets and two sets of art,
for a team of one human plus AI agents.

## 2. Where the game ends today

The balance sim reaches the tundra at ~5.6 h; one loop of 6 biomes is roughly 1–2 days of idle play.
After that the content is: lap +1 (harder, richer), the Next Generation (new vehicle tier), and the
coming time-limited event vehicles (MV-159). There is no *goal* after the Overseer, and lap 3 looks
like lap 1 with bigger numbers. End game needs three things: a **story finale**, **a reason to build
stronger** (a ladder with visible tiers) and **things that change week to week**.

Time targets: loop 1 = days 1–3, generations 1–3 (bus → rig → train) = weeks 1–3, end game = month 1+.

## 3. End-game pillars

### 3.1 Story finale: "ปิดวงแหวน / Shut down HELIOS" (one-time, per account)

The lore already sets it up: OVERSEER runs HELIOS RING, the 104.7 signal is a trap, Signal Metropolis
is its capital. After the first Overseer kill on lap 2+:

- Radio chapter: a transmitter key is split into **4 shards**, each held by a "Herald" boss that only
  appears on lap 2+ in 4 different biomes (new mechanics, not reskins).
- With 4 shards: **The Spire** (a 5-phase boss fight on the HELIOS spire landmark). Win → ending story
  screen (same typewriter style as the prestige stories), the sky stops burning: a new
  **"after the fire"** visual variant for all biomes (stars visible, no ash), title + logbook chapter.
- Afterwards the Spire stays as a repeatable top-tier fight (3.3).

### 3.2 Road Pacts (ข้อตกลงบนถนน): self-chosen difficulty for reward (Hades Heat / Diablo Torment)

From lap 2 the player signs pacts for the current lap; each adds **pact points**, more points = more
research, better rarity weights, higher item level cap. Reuse `Modes` mutators (horde, fuel_scarce,
glass_cannon, lean_rations…) plus new ones: night lasts longer, elites ×2, bosses get a 2nd mechanic,
acid rain every storm, strangers lie more. Personal best pact score per biome = account record.
This is the main "build stronger" ladder and costs almost no art.

### 3.3 Weekly Spire and the Convoy (async co-op, CRK guild boss / PriConne clan battle)

- **Convoy** (ขบวนรถ): up to 10–20 accounts. Needs Supabase tables only; no realtime.
- **Weekly world boss**: one of the 8 mutant bosses + the 4 Heralds, with a weekly modifier. Each
  member gets 3 attempts/day of 90 s, damage is summed into the convoy's shared HP bar. Tiered rewards
  (account research points, blueprint shards, cosmetics, titles). Leaderboard reads `Modes.ranked()`.
- Solo players get the same fight with a personal HP bar and smaller rewards.

### 3.4 Gear ceiling: Relic tier + sets + targeted farming

- **Relic** above Mythic: only from Spire / Heralds / weekly boss, built from Mythic via the Forge
  (synthesize 3 Mythic + boss core).
- **Set bonuses** (2 / 4 pieces) per boss: e.g. Frost Titan set = slows, Bog Queen set = poison
  immunity + damage over time. Sets give a reason to farm a particular boss.
- **Affix reroll** with a lock (costs boss cores), so the last 10 % of a build is a choice, not luck.
- Item level cap = lap + pact level, so pacts unlock the next gear step.

### 3.5 Crew mastery: Veteran ranks + named legends

- Past the level cap XP turns into **Veteran ranks** (small +% per rank, paragon-style), shown as
  chevrons on the sprite. Gives every kill value forever, also offline.
- **Legends** (ตำนานบนถนน): ~12 hand-written survivors with a fixed signature skill (the HELIOS pilot,
  a defected Overseer drone, an ember cultist who left…). Earned from Heralds, the Spire, the strangers
  inspection (very rare honest exceptional stranger) and convoy rewards. **No gacha**: each legend has
  a known source. They are the "hero collection" of E7/SW without a hero shop; they survive rebirth.

### 3.6 The Ark (มหายานพาหนะ): a multi-generation account project

MAMMOTH-7 was rebuilt from 17 trucks; the end-game version: build the **Land Ark** across generations.
5 stages (chassis, reactor, greenhouse deck, school, beacon), each needing large stocks of materials,
blueprints and legends. Each generation can donate when it retires. Each finished stage gives a
permanent account bonus and visibly changes the command-centre screen. Final stage = the account's
"true ending" + the Ark as the fifth vehicle tier (5 floors, rooms × 3 + modules).

### 3.7 Outposts (ด่านหน้า): what to do with too many survivors

At a cleared checkpoint, drop 2–4 survivors to found an **outpost** (max 1 per biome). It produces that
biome's specialty while the truck drives on (fuel in the desert, crops in the forest, components in
the industrial ruins), can be raided (threat meter), and is the place to retire old crew instead of
losing them. Outposts reset per generation; their best level goes to the account.

## 4. Weekly rhythm

| Cadence | Content |
|---|---|
| Daily | 3 convoy boss attempts, 1 "road contract" (kill 30 flyers / finish an expedition at danger 3+…), daily strangers |
| Weekly | Boss rotation + modifier, convoy reward tiers, pact leaderboard per biome |
| 2–4 weeks | Event vehicle (MV-159) with its own rules, rewards go to the account |
| Long term | Ark stages, legends collection, Relic sets, Veteran ranks |

## 5. Build order (proposed tickets)

| # | Plane | Ticket | Why first | Size |
|---|---|---|---|---|
| 1 | MV-573 | Boss prep card + manual skill tap on bosses | Makes the current fights deeper; needed by every later boss | S |
| 2 | MV-574 | Road Pacts (on top of `Modes`) | Biggest end-game value for least art | M |
| 3 | MV-575 | Squad behaviour rules (gambits light) | Depth that works offline | M |
| 4 | MV-576 | Heralds + The Spire + ending screen | Gives the game an end; 4–5 bosses of art | L |
| 5 | MV-577 | Relic tier, sets, affix reroll | Chase after the Spire | M |
| 6 | MV-578 | Veteran ranks + Legends | Long-term crew goals | M |
| 7 | MV-579 | Convoy + weekly boss | Social retention; needs Supabase schema + anti-cheat | L |
| 8 | MV-580 | Outposts | Uses surplus crew | M |
| 9 | MV-581 | The Ark | Account goal that ties everything together | L |
| 10 | MV-582 | Squad of 5 | Only once 1–3 show a need | M |

Open questions for Parames:

1. Auto-battler + manual ultimate on bosses: OK, or keep 100 % auto?
2. Convoy (async co-op) in scope, or solo only for now?
3. Legends: fixed sources only (proposed), or ever a shop / pull? (proposed: never gacha)
4. Does the story end at the Spire, or should the Ark be the true ending?
