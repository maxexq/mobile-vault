# MOBILE VAULT — Project: Survival

Idle survival / management game in a giant roaming RV ("Mobile Vault") — 2D pixel art, built for **Mobile Web (HTML5)** with **Godot 4.7.2-stable** + GDScript.

> Godot version check (22 Oct 2026): **4.7.2-stable** (released 18 Aug 2026) is the latest stable on godotengine.org/download and GitHub releases (4.7.3 / 4.8 stable do not exist). No add-ons are used — nothing to version-match.

---

## 1. Install Godot 4.7.2-stable

Download only from official sources:

| OS | File |
|---|---|
| Windows | https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_win64.exe.zip |
| macOS | https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_macos.universal.zip |
| Linux | https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip |
| Export templates (needed for Web export) | https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz |

Checksums: `SHA512-SUMS.txt` in the same release. Godot needs no installer — unzip and run.
Install templates in the editor: **Editor → Manage Export Templates → Install from File** → pick the `.tpz`.

## 2. Run

1. Open Godot → **Import** → select `project.godot`.
2. Press **F5**. (First open imports textures; takes a few seconds.)

Controls (touch or mouse) — designed for **portrait 9:16** phones, landscape also works:
- **Tap a room** → camera zooms in (Tween to a whole-number zoom) + background blur → management terminal.
- **Tap the blurred area / "ปิด"** → zoom back out.
- **Swipe left/right** → look along the highway (springs back after 3 s).
- **Tap the weather chip / solar panel on the roof** → solar system window.
- Bottom bar: **Build / Squad / Map / Crew / Loot / Log**, above it the travel strip (**park / drive**, speed, hull).

## 3. Export to Web (HTML5)

Preset **"Web"** is already in `export_presets.cfg` (Compatibility renderer, *no threads* → works on any static host, no COOP/COEP headers needed, iOS Safari friendly).

- Editor: **Project → Export → Web → Export Project** → `build/web/index.html`
- CLI: `godot --headless --path . --export-release "Web" build/web/index.html`

Verified: this preset was exported with the official 4.7.2 templates and played in Chromium (WebGL 2, touch input, localStorage save → reload → CONTINUE).

Test locally: `python3 -m http.server 8000 -d build/web` → open `http://localhost:8000` (must be served over http, not file://).
Upload the whole `build/web` folder to itch.io (HTML game), GitHub Pages, Netlify, etc.

Save data: browser **localStorage** (key `mobile_vault_save_v1`), auto-saved every 15 s and when the tab is hidden/closed. Desktop builds fall back to `user://savegame.json`. With `cloud_config.json` present the save is also mirrored to Supabase (see 4i).

## 4. Gameplay loop

| System | What happens |
|---|---|
| Idle production | Rooms produce per minute: rate × room level × workers' stat (STR/INT/AGI) × happiness × science boost × weather. Floating "+N" numbers pop out of rooms. |
| Consumption | Every dweller eats & drinks; driving burns battery; rooms draw power. Starving = HP loss. |
| Crafting | Each room has recipes with pixel progress bars (stimpacks, RadAway, weapons, armor, ammo, meals, seeds, scrap refining, hull repair, SOS broadcast). |
| Dwellers | Assign / move / remove, equip gear, use stimpack / RadAway / antibiotics, level up from work (+stat). Each survivor has **traits** and a **skill tree** (see 4d). |
| Travel & biomes | 6 biomes: Industrial Ruins → Desert → Overgrown Forest → **Toxic Bayou** → Frozen Highway → **Signal Metropolis** → loop (lap +1 = harder, richer). Driving salvages scrap. Each biome ends at a **checkpoint** (warlord + Vault level). |
| Mobile Vault upgrade | Lv.1–6. Costs scrap: opens more room slots (**3 rooms per floor**; van 2 floors / 6 rooms → bus 3 / 9 → 18-wheel rig 4 / 12 → armoured train 4 / 12, plus up to 2 trailers / wagons of 6 rooms each), bigger storage, advanced rooms, next biome, full hull repair. |
| Weather | Clear / overcast / rain / storm (lightning + shake) / sandstorm / snow / fog / **acid rain** (eats hull unless plated) / **ashfall**. Affects solar, crops, rain water, speed, panel dirt. |
| Day/night | 6-minute day; CanvasModulate colour grade; rooms + headlight glow at night; solar panel tilts to follow the sun. |
| Random events | 19 events (new: sealed bunker, signal tower, stray dog "ข้าวตัง", ember cultists, gas station, gambler, HELIOS plane wreck, acid flood, rogue robot). Choices: fight, flee, bargain, ram, shelter, **stat checks** (INT/AGI vs difficulty), **gamble**, **adopt a pet**… Some choices unlock logbook records. |
| Lore | Logbook (Log button): world chapters (Ember Fall / HELIOS RING / MAMMOTH-7 / Overseer), records found on the road, crew dossiers. Every starting crew member has a hand-written bio; recruits get a generated one. |
| Idle chatter | Every 9–20 s a survivor says a context-aware line (their room, weather, biome, low food/water/power, hull, squad role, night, the dog, personal quirks) in a speech bubble. |
| Offline progress | Up to 4 h simulated on return (no events), summary toast. |

All tuning numbers live in `scripts/autoload/data.gd`.

## 4b. Idle combat & loot (Taskbar-Hero style)

| Part | How it works |
|---|---|
| Defence squad | 3 roles: **Roof Gunner** (AGI, ranged DPS, skill *Volley*), **Rear Bruiser** (STR, melee tank on the rear deck, skill *Ground Slam* + stun), **Field Medic** (INT, heals, skill *Patch Up* also repairs hull). Gunner + Bruiser from Vault Lv.1, Medic at Lv.2. Squad members leave their room job. |
| Waves | Enemies chase the van from behind. Enemy level = biome base + wave/2. Every 10th wave is a boss. **PUSH** advances after each clear, **FARM** repeats the wave. A wipe or a 90 s timeout sends you back 3 waves. |
| Checkpoint warlord | The end of every biome needs its warlord beaten (≈ biome base +28 levels) *and* the Vault level, then the road opens. "ท้าบอส" button retries. |
| Enemies | 18 mob types across 6 biomes (melee / ranged / flying) + 6 bosses drawn at native size (Junk Golem, Scorpion King, Alpha Rad-Wolf, Bog Queen, Frost Titan, Overseer Mech); elites (gold) hit harder and drop better. |
| Loot | 10 slots: **weapon / armor / helmet / boots / gadget / backpack** per dweller, turret / plating / engine / spikes on the vault. Boots give **dodge**, a better **backpack** = more drop chance + **supply** (kills drop food/water, expeditions bring more supplies and gear). 6 rarities (Common → Mythic), item level = enemy level, 0–4 random affixes, legendary names. Bosses always drop Rare+. |
| Forge | Enhance (+N up to the rarity cap, costs components + scrap), synthesize 3 → 1 of the next rarity, salvage (single / bulk / auto on drop), lock items. |
| Scaling | Enemies grow ×1.17 HP / ×1.145 dmg per level, gear ×1.12 per item level, so pushing hits a wall; rarity, enhancement, levels and skills move it. Balance sim (`-- --balance --minutes=480`) reaches desert ≈40 min, forest ≈2 h, bayou ≈3.7 h, tundra ≈5.6 h. |
| Offline | Like TBH: offline time gives XP + scrap only (no gear). With threat pacing it pays the measured raid kills/min × 0.6 × 1.6. |
| Threat pacing (v4.5, default) | Enemies come in **raids**, not non-stop. A **threat** meter (0–100) fills from the biome's danger, engine noise (speed), being parked (scent), night, noisy rooms (workshop, refinery, engine, armory, radio) and lit rooms (hydroponics, science, medical, quarters; ×2 at night), full trailers and fresh blood; storm/fog ×0.6, sandstorm ×0.5, snow ×0.8. Cycle: **quiet** (no enemies, roadside scavenging every 30 s) → **warning** (8 s of signs) → **raid** of 2–4 waves (more at high threat) → **salvage** (60 % of the raid's scrap + 30 % chance of an extra item) → threat ×0.35. Raid kills pay ×1.6 XP / scrap / drop chance so the hourly haul stays near the old pacing (autotest checks 80–120 %). The checkpoint warlord still comes at once. Settings → การต่อสู้ → จังหวะศัตรู: **คลาสสิก** brings back the back-to-back waves. HUD chip shows QUIET / INCOMING! / SALVAGE + the meter; tap-hold for the breakdown. |

Files: `scripts/autoload/combat.gd` (simulation), `scripts/autoload/loot.gd` (items), `scripts/world/combat_view.gd` (visuals), `scripts/ui/squad_panel.gd`, `scripts/ui/loot_panel.gd`.

## 4d. Builds, hazards, mods, expeditions, prestige (v3)

| System | How it works |
|---|---|
| Skill tree | 3 branches × 5 nodes per survivor (**Combat**: damage, HP, attack speed, dodge, signature move · **Survival**: small stomach, rad resistance, scavenging, field medic, "survivor" · **Craft**: production, crafting speed, mentor XP, repair, master). 1 point per level (+2 with the *Skill Spark* legacy perk), respec costs scrap. `scripts/autoload/skills.gd`, `scripts/ui/skill_panel.gd`. |
| Traits & synergies | 20 traits (mechanic, cook, green thumb, healer, sharpshooter, brawler, tough, light eater, glutton, cold-blooded, rad-proof, night owl, scavenger, lucky, cheerful, grumpy, coward…). The right person in the right room gives an idle production bonus, two matching specialists in one room add a duo bonus; traits also change food use, combat stats, morale. `scripts/autoload/crew.gd`. |
| Biomes & hazards | Cold (tundra, desert nights, snow) burns **fuel for heating** — out of fuel the crew freezes and rooms slow; heat and **sandstorms cut solar output**; the Toxic Bayou is a **radiation zone** and random rad hotspots appear in other biomes; acid rain eats the hull; ashfall hurts morale. The map and route row show active hazards and the fix for each. `scripts/autoload/env.gd`. |
| Internal & external mods | Garage (Mods button). **Exterior, visible on the truck model**: spiked ram (3 levels), roof auto-turret (3), spare fuel drums (stacked on the front wall), snow tracks (replace the rear wheels, animated), armour plates (cab → lower floors → every floor), solar hoods, lead radiation skirt, rain catcher. **Interior**: insulation, boiler heater (chimney on the roof), air filter, storage racks, repair bay, water recycler. Some need blueprints. `scripts/autoload/mods.gd`, `scripts/ui/garage_panel.gd`. |
| Fuel & refinery | New resource: fuel (cap grows with fuel drums). Produced by the new **Fuel Refinery** room, used for heating and the backup generator. New **Workshop** room (blueprint) salvages parts and patches the hull. |
| Expeditions | 12 landmarks (2 per biome: hospital, military depot, dune gas stop, satellite array, ranger tower, research lab, chemical plant, stilt village, polar station, mine, mall, HELIOS spire) + "scavenge the area" anywhere. The truck **parks**, the landmark rolls in beside it, the chosen 1–3 survivors climb down from the rear deck and **walk into the building**; they walk back out when the timer ends (idle, works offline). Pack food/water/stimpacks/ammo/antibiotics; odds depend on team power vs danger. Rewards: blueprints, rare gear, recruits, lore. Risks: injury, **infection** (needs antibiotics / a medical room), death (names go on the memorial wall in the logbook). `scripts/autoload/expedition.gd`, `scripts/world/expedition_view.gd`. |
| The Next Generation | If the hull sits at 0 % for 2 minutes the truck is wrecked for good; you can also retire it voluntarily after beating the first warlord. Bank **legacy points**, buy permanent perks (head start, efficiency, quick frame, early rooms, veterans, training, skill spark, **vehicle research**: bus → rig → armoured train, each needs a blueprint), pick which high-level survivors escape (keep traits, weapon and part of their level), carry all blueprints and part of the scrap/components, and start again from the first biome in a bigger vehicle. See 4e for the story screens. `scripts/autoload/meta.gd`, `scripts/ui/nextgen_panel.gd`. |
| Tall vehicles | Extra floors stack upwards (cab, wheels and road line never move); drag down to look up at the roof when the screen is short. |

## 4e. v4 — vehicle ladder, synergy, weight, morale, mutants, juice

| System | How it works |
|---|---|
| Vehicle ladder | A new game starts in a **van** (2 floors × 3 rooms). Prestige research unlocks the **armoured bus** (3 floors), the **18-wheel rig** (4 floors) and the **armoured train** (4 floors, runs on rails laid over the road, rail wheels). Old saves become the rig (or the train if they had the MK-III chassis), rooms keep their position. `Data.VEHICLES`, `Game.tier()`. |
| Trailers | From Vault Lv.5 with the *trailer* blueprint (polar station): hitch up to **2 trailers** (wagons for the train), each 2 floors × 3 rooms, bought between runs in the garage. They add weight and power draw. `Mods.add_trailer()`. |
| Room synergy | Neighbours on the same vehicle unit matter: engine next to quarters = poor sleep (−10 happiness), engine + workshop = +15 % output and faster repairs, hydroponics + water = +15 %, kitchen + refinery = fumes (−10 %), radio next to the engine = static… Build mode colours each empty slot green / red with a preview, rooms show +/− markers, the close-up lists every effect. `scripts/autoload/synergy.gd`. |
| Power & weight | Weight = base vehicle + trailers + rooms + levels + mods + cargo + crew. Engine capacity = vehicle engine + engine room + **engine tune** (int. mod), **suspension** and **off-road wheels** (ext. mods, visible shocks + chunky tyres). Above 80 % load the vehicle slows and burns more fuel; the garage shows a weight bar. `scripts/autoload/haul.gd`. |
| Morale | New traits (afraid of the dark…). Low happiness → the survivor **goes on strike** (sits with a protest sign, no work). Left too long under 10 % they **steal food, water, scrap, parts and a stimpack and leave**. Pets, good synergy and full larders keep people happy; crowding, darkness and noisy neighbours don't. |
| Pets | Event pets live on the vehicle and roam every room: the dog ข้าวตัง, the cat ส้มจี๊ด (cuts food waste) and the mutant hen ไข่ดาว (lays food). Up to 2 pets, +happiness each. |
| Blackouts | Empty battery or a random short circuit blacks out a room: it goes pitch dark and only the crew's **head-torches** sweep around (additive pixel light cones); production drops until the mechanic fixes it. |
| Scavenging squads | Expeditions now need a team of **2–3**; new site: the dead **supermarket** (engine-tune blueprint). While the team is out, the expedition panel shows a **live helmet-cam feed**: a pixel interior per kind of site (store, hospital, bunker, plant, lab, mine, ruins) that scrolls deeper as they push in; each survivor searches shelves, does the site's job (pump fuel, crack the vault, hack the door…), guards, carries crates or catches a breath; creatures from that biome shamble in and get shot or brawled (muzzle flashes, blood); dark sites use head-torches. Coloured markers match the squad list, which says what each person is doing right now, plus a 3-line field log. It is a pure function of time + a per-expedition seed, so it survives closing the panel and offline time. `scripts/ui/expedition_feed.gd`, art in `tools/art/expedition.py` → `assets/exp/`. |
| Mutants & bosses | Further biomes mix in mutants: runners, **acid spitters** (corrode the hull: defence ×0.6), **bloaters** (explode), **screechers** that fly and peck the **solar panel**, armoured brutes. Every 10th wave rotates through **8 bosses** (Acid Matron, Bloat King, Sky Harpy, Bone Hulk, Drill Worm, Screamer, Necro Priest, Mech Spider) with mechanics: enrage below 30 %, armour above 60 %, summon, revive, burrow / erupt, acid, solar dive. The new **flak cannon** turret prioritises flyers. |
| Boss bar | A big segmented HP bar slams in under the HUD: name, level, mechanic tags, a white damage trail, phase markers at 60 % / 30 %, armour plating, shake + flash on heavy hits, ENRAGED / UNDERGROUND states. |
| Gore & juice | Blood sprays, gibs, scrap shards and brass casings fall onto the road and slide away with the road speed, splats, explosion frames, screen shake; road walkers get run over by the ram. |
| Micro-animations | Off-duty crew strum a guitar, sip coffee or clean their rifle. |
| Camera | Zoom button / mouse wheel / pinch: **auto** (goes wide during boss fights or when trailers are hitched), **wide**, **normal** — still whole-pixel scaling (the world viewport grows instead of being shrunk). |
| Cutaway / X-ray | The eye button toggles the closed armoured shell vs the cut-away interior; with the shell closed, the first tap on the vehicle peeks inside for a few seconds. |
| Prestige stories | Wreck → "the hull is gone, but the SOS got out", retire → "the blueprints reach the command centre": an illustrated, typewritten story screen before banking **genetic research points**. |

## 4g. v4.3 — construction time + builders

| System | How it works |
|---|---|
| Construction time | Building a room no longer finishes instantly: the slot becomes a **building site** (bare steel frame, tarp, sandbags) and the finished interior rises from the floor up behind scaffolding as work progresses. Time = `BUILD_BASE_SEC + BUILD_SEC_PER_SCRAP × cost` work-seconds (kitchen ≈ 1:22). A site produces nothing, draws no power and adds no beds until done. Room **upgrades** also take time (`UPGRADE_SEC`), but the room keeps working at its old level meanwhile. Progress keeps running offline. |
| Builders | Crew assigned to a site haul planks and swing hammers (new `hammer` / `carry` frames, dust puffs on every blow, welding sparks along the rising edge). Site speed = `BUILD_IDLE_SPEED` + Σ `Crew.build_speed(d)` (STR helps). Finishing gives STR XP. |
| Builder role | Refugees can arrive with the **ช่างก่อสร้าง / BUILDER** role (~25 %, hard hat + hi-vis vest outfit): ×2 construction speed, +50 % XP and happier on a site, and they head straight to an open site. Ton is the vault's first builder (old saves too). |
| Builder traits | **วิศวกร ENGINEER** +40 % build (+20 % workshop), **มือไว QUICK HANDS** +25 %, **สถาปนิก ARCHITECT** −15 % build/upgrade cost while on board, **ซุ่มซ่าม CLUMSY** −30 %; mechanics get +15 %. |
| Rush / cancel | The close-up shows progress, time left, the builder crew and their multipliers; **finish now** costs components (1 per 15 work-seconds left); cancelling a site refunds half the scrap. |
| Hooks | `Game.construction_started(slot, kind)` / `construction_finished(slot, kind)` (`kind` = `build` or `upgrade`), state in `Game.s.rooms[i].build` (`{kind, total, left}`, empty when idle). God mode: *instant build* switch + *finish all construction*. |

## 4j. Large rooms (knock-through, 2–3 cells)

Fallout-Shelter style: two or three rooms of the **same type and level**, side by side on one floor of the same unit (main body or one trailer), can be knocked through into one large room. Open a room → **ขยายห้อง** → *รวมกับห้องซ้าย/ขวา*.

| Part | How it works |
|---|---|
| Data | The left-most cell (anchor) keeps the room; the other cells become `type: "annex"` (`Game.room_anchor / room_cells / room_span`). No new save keys; `_fix_large_rooms()` clears an annex with no valid room on load and moves crew to anchors. Crew always work on the anchor slot. |
| Cost / time | Scrap `room cost × 0.6 × level × (span − 1)` + `6 × (span − 1)` components; `45 + 35 × level × (span − 1)` work-seconds as a normal construction job (`kind: "merge"`, builders and rush work). The room **keeps working as its parts** meanwhile; the bonus starts when the walls are down. |
| Bonus | 2 seats per cell (4 / 6). Output = cells × efficiency: **2 cells ×1.10, 3 cells ×1.25** (production, crafting speed, healing, science boost, armory, radio, beds: 2-wide quarters = +9 pop at Lv1). Power 90 % per cell. Pair perks (cheerful, mentor) don't stack per seat. |
| Upgrade | One upgrade levels every cell: `span × 80 %` of the single price, `+50 %` work per extra cell. |
| Synergy | A large room touches everything around all its cells; each neighbouring room counts once (a 3-wide kitchen under a 3-wide hydroponics = one +10 %). |
| Split / demolish | *แยกกลับ* turns it back into single rooms (free, instant, same level, crew shared out); demolish clears every cell and refunds half the build cost per cell. |
| Art | `tools/art/rooms.py` `gen_wide_rooms()`: the room's own wall at full width, its furniture left + mirrored right, a centre piece per type for 3 cells (couch & TV, stock pot, grow tower, settling tank, operating table, rifle wall, mainframe, transmitter, fractionating column, engine hoist), a steel post where the wall stood and the **ladder shaft running through** when it crosses cells 0|1 of the main body. Keys `room_<type>_x<gaps>` (`x2`, `x10`, `x2_2`, `x10_2`). The atlas is now 2048×2048. |
| View | The anchor's `RoomView` spans the cells (actors wander and use equipment across it); the strips the hull's partition / shaft would hide are redrawn above the shell by `Vehicle._sync_large_rooms()`. The close-up frames the whole room (drops to 1× zoom if 3 cells don't fit). |
| Modules (planned) | Turret bays / defence modules from the modular-chassis design are not in `Data.MERGEABLE`, so they stay single-cell. |

## 4i. v4.4 — strangers at the door (inspection)

Inspired by the door checks in *No, I'm Not a Human*. Every way a refugee joins (radio, road event, SOS broadcast, expedition loot, boss captive, expedition encounters) goes through `Game.offer_recruit(source)`. Usually they board at once; **rarely (~6 % rare, ~1.5 % very rare)** the stranger is exceptional (top stat 7–9 / 9–11, +2/+4 levels, 2–3 good traits) and waits at the door for inspection instead.

| Part | How it works |
|---|---|
| The knock | A blinking red strip above the travel bar ("มีคนเคาะประตู!") opens the door window. Up to 2 strangers wait; one left unanswered for 10 min walks away. |
| What they really are | **Human** (≈55 %, less each lap), **infected** (hid a bite), **mimic** (not human), **thief**, **raider mole**. |
| Checks | 7 checks, 1 point each, **3 points** (+1 staffed medical room, +1 a healer aboard), so you never see everything: eyes (bloodshot / glassy), teeth (rotten / too perfect), hands & nails (black veins / spotless / gang tattoo), forearm (bitten bandage / raider brand), bag (lockpicks + other people's IDs / live radio + our route on a map — may be refused), temperature (fever / cold), story (shaky). Each check shows a flashlit 96×48 pixel close-up. |
| Circumstantial | Tells are probabilities: impostors never show all signs (but always at least one), honest people sometimes look tired, feverish or have an old biker tattoo. The field guide in the window lists what each sign may mean. |
| The call | **Let in** (joins with the hidden secret), **turn away** (never know), **shoot** (right: their loot — antibiotics / components / scrap + stimpack / ammo; wrong: everyone −20 happiness and a name on the memorial wall). |
| Later | Admitted impostors go off after a few minutes: infected fall sick and may infect a roommate, a mimic drags someone off at night (a strong rear bruiser may fight it off), a thief disappears with 20–35 % of food/water/scrap/fuel and 30 % of meds/components, a raider opens the rear door (hull −30, scrap −30 %, 2 people hurt). Logged in `s.insp_log` + Trace. |
| Code | `scripts/autoload/inspection.gd`, `scripts/ui/inspection_panel.gd`, art `tools/art/inspect.py` → `assets/inspect/`. God mode → ลูกเรือ: spawn any kind of stranger. |
## 4h. Expedition special encounters

| System | How it works |
|---|---|
| Rare encounters | Each expedition has a small chance (`14 % + 1.5 % × danger`, so 15.5 % at a danger-1 site and 24.5 % at HELIOS) that somewhere between 30 % and 65 % of the trip the team radios back about something worth a decision. A pop-up shows a 160×80 illustration, who is out there with their HP, and 2–3 choices with odds and costs. |
| The six encounters | **ผู้รอดชีวิตหลบซ่อน HIDDEN SURVIVOR** (invite aboard: may hide an infection / share food for a stash tip / leave), **คนแปลกหน้าบาดเจ็บ WOUNDED STRANGER** (patch up with a packed stimpack: he joins / rob his pack: he may stab back / walk away), **เสียงร้องขอความช่วยเหลือ CRY FOR HELP** (danger 2+: rush in: refugee + supplies or a raider ambush that injures and costs 30 % of the site loot / warning shots with packed ammo / ignore), **ตู้เซฟใต้ซากตึก BURIED SAFE** (pry: rare gear or crushed, +60 s / shoot the lock with ammo / leave), **ลังเสบียงบนพื้นที่กำลังถล่ม SAGGING FLOOR** (the nimblest climbs (AGI): big supplies or a fall + infection / leave), **คลังยาในห้องปนเปื้อน TOXIC PHARMACY** (danger 2+: hold your breath (INT): meds or an infection / dose up with packed antibiotics / leave). |
| Rules | Costs come out of the **packed supplies** (so they also lower the trip's odds), injuries hit the team member best at the job (lower HP = lower team power and a higher death risk on a failed trip), refugees need a free bunk, and rewards (scaled by site danger and lap) come home with the team. If everyone dies, nothing comes back. The clock keeps running: close the pop-up and answer later from the HUD chip ("สั่งการ") or the expedition panel. If nobody answers before the team returns (or the game was closed), the team plays it safe and picks the last choice. The last 3 encounters are never rolled again, so the same one never shows up twice in a row. |
| Hooks | `scripts/autoload/encounter.gd` (`Encounter`, autoload after `Expedition`): data in `ENCOUNTERS`, state in `Game.s.exp.enc` (`{id, at, st: wait/open/done, bonus, recruits, lose, text}`), anti-repeat list in `Game.s.enc_recent`; signals `encounter_ready(id)` / `encounter_resolved(id, result)`. UI `scripts/ui/encounter_popup.gd`, art `tools/art/encounters.py` → `assets/events/enc_*.png`. God mode → EXPEDITION: trigger any encounter on the running trip. |

## 4k. Roof rest deck (ดาดฟ้าพักทีมป้องกัน)

A rooftop rest spot for the defence squad, bought as an exterior mod (MODS → **ดาดฟ้าพักทีมป้องกัน / ROOF REST DECK**, 3 levels: 160 scrap + 6 comp / 380 + 18 / 800 + 40, 1.5 t). It is a plank deck on stilts over the rear roof (fuel drums fit underneath); the roof gunner and the field medic stand on it.

| Part | How it works |
|---|---|
| Reserve seat | The deck adds one **reserve** to the defence squad (Squad panel → ROOF DECK RESERVE, or Crew → ตัวสำรองดาดฟ้า). The reserve doesn't work a room: they doze on the cot (HP +0.6 %/s per level, happiness target +19/22/25, little "z"s), and pick up 40 % of the kill XP (also offline). Squad members get +2 happiness per level (a place to sit between waves). |
| Tag-in | When a squad member falls in a wave, the reserve jumps down after **6 / 4 / 2.5 s** (Lv1/2/3) with **60 / 80 / 100 %** HP and fights in that role (role stats + that role's skill); the fallen one is carried up to the cot. Once per wave. While a reserve can still come down, a squad that is all down is not wiped yet. When the wave ends (cleared, wiped or reset) the original line-up returns, rested. |
| Roof cover | Gunner + medic only: Lv1 shade = regen +0.3 HP/s per level, Lv2 sandbags = DEF ×1.15 and dodge +3, Lv3 lookout mast + searchlight = range ×1.1 and crit +5. The rear bruiser gets nothing. |
| State | `Game.s.deck` = reserve dweller id (-1 none). `Game.deck_dweller()` validates it every time, so working in a room, joining the squad, an expedition, death or desertion takes the reserve off the deck by itself (no save migration needed). Runtime swap in `Combat.sub` / `Combat.sub_out`, signal `Combat.tagged_in(slot, did, out_did)`. |
| Modular chassis | Independent of the pending modular-chassis cells (`s.rooms`): the deck is a roof mod, so a later "turret bay / defense module" can sit below it. |
| Art | `tools/art/truck.py` `mod_roof_deck()` → atlas `mod_roof_deck_1..3` (76×60). |

## 4l. Engine bay (ห้องเครื่องหน้ารถ, v4.6)

The engine now lives in a walk-in room inside the cab of every vehicle (van / bus / rig / train each have their own cut-out, `Data.VEHICLES[tier].cab`). It sits behind the shell (the cab art has a hole there) and never takes a body cell: the old engine room on cell 0 became a free room cell. Tap it to open the **engine menu**.

| Part | How it works |
|---|---|
| Engine = item | The van-gear **engine** item is the installed engine (`Loot` base key `engine`). No item = the stock **diesel I4**, whose numbers equal the game before v4.6. 8 types: diesel I4, V8, turbo-diesel I6, wood-gas gasifier, EV conversion, diesel-electric, gas turbine, fusion cell. Each has a size (S/M/L; the van takes up to M), tow ×, speed %, fuel kind (fuel / scrap / power / none), noise dB, heat ×, wear ×, alternator power, weight. Engines are never auto-equipped. |
| Drive modes | Silent (diesel-electric / EV only, battery), eco, normal, boost: speed, fuel, noise, heat and wear multipliers. |
| Heat | Driving heats it toward `ambient + P / k` (P: engine × mode × load × weather, k: cooling + 15 % per crew, ×0.5 with no coolant; parked cools ×1.5). Biome air temperature day/night (desert 45 °C by day). **Auto-rest** (default 110 °C, or 100 °C) parks the vault until 80 °C; turned off it drives on until **120 °C**, stalls on its own and loses 5 % condition + coolant. Offline always auto-rests. Above 110 °C: speed / tow ×0.7. |
| Wear | Condition drops while running (×1.5 hot, ×2 with oil < 20 %, overload ×4); oil burns down. Under 60 %: −10 % speed / tow, +3 dB; under 35 %: random breakdowns (45 s stall); 0 % = seized (×0.3 speed). Offline never drops it below 25 %. |
| Crew | Up to 2 crew work in the cab (Crew → ย้ายห้อง → ห้องเครื่อง): they cool it, repair a little (STR, mechanic ×1.4, repair skill), top up coolant from the water tank, and speed up jobs. |
| Jobs | Coolant (12 water), oil change (15 scrap + 5 fuel, parks), tune-up (+20 %, 40 scrap + 3 comp), overhaul (200 scrap + 20 comp, parks), engine room upgrade (alternator +25 % per level). |
| Links | Noise → threat: `0.12 × km/h × (dB − 45) / 33` (the stock diesel = the old term) + gasifier smoke by day. Tow × → `Haul` capacity, weight → load. Alternator → power while moving. Fuel burn replaces `Haul.fuel_pm` while driving. |
| State | `Game.s.cab` (the room: level, job) + `Game.s.engine` (heat, cond, oil, coolant, mode, auto_rest, rest_at, resting, job). `Data.CAB_SLOT` (99) is the cab's slot id; use `Game.room(slot)` for any slot that may be the cab. Saves before v4.6 migrate (`Game._migrate_cab`): cell 0 is freed, the level and 2 of its crew move into the cab. |
| Art | `tools/art/engine_bay.py`: `cab_<tier>_<idle|run|hot|broken>` rooms + `eng_<type>` icons; `vehicles.py` cuts the cab hole. |

## 4i. Cloud save (Supabase)

Local-first: the game still reads and writes localStorage / `user://`; `scripts/autoload/cloud.gd` mirrors that save (plus Settings) to one row per player in Supabase, using `HTTPRequest` against the REST API (no addon).

- **Setup (once):** run `supabase/migrations/0001_cloud_save.sql` in the Supabase SQL Editor, enable *Authentication → Allow anonymous sign-ins*, then copy `cloud_config.example.json` to `cloud_config.json` (git-ignored) with the Project URL and the **anon / publishable** key. Never put the `service_role` / secret key in the game. Without the file the cloud is off and the game is offline-only, as before.
- **Accounts:** first launch signs in as a **Guest** (Supabase anonymous user); the session (refresh token) is kept in localStorage `mobile_vault_auth_v1`. The title menu shows the account and opens Settings → เซฟ, where:
  - a guest taps **ล็อกอินด้วย Gmail** → Supabase *manual linking* (`GET /auth/v1/user/identities/authorize?provider=google&skip_http_redirect=true`) adds Google to the same user id, so the save stays put;
  - if that Google account already has its own user (`identity_already_exists`), **สลับไปบัญชี Google นั้น** signs in to it (`/auth/v1/authorize?provider=google`); when both this device and the account have progress the usual conflict choice appears;
  - a Google user can **ออกจากระบบ**: the save is uploaded first (refused when offline), the local copy is removed and a fresh guest starts.
  - Google uses the redirect (implicit) flow: the page goes to Google and comes back with the session in the URL fragment, read and cleared on boot. Google refuses to sign in inside a frame (the artifact view), so there the game offers to open `site_url` in a new tab.
  - Setup: Google Cloud OAuth client (Web) with redirect URI `https://<ref>.supabase.co/auth/v1/callback`; Supabase → Google provider on + **Allow manual linking**; URL Configuration → Site URL + Redirect URLs for the Vercel production and preview domains. Step-by-step (Thai): `supabase/google-login-setup.md`.
- **Migration:** a browser that already has a save uploads it as revision 1 on the first online start.
- **Sync:** upload at most once a minute while playing and on tab hide; offline keeps saving locally and retries every 30 s. Writes go through `rpc_save`, which rejects a stale revision, so when two devices both moved on the Settings → เซฟ tab asks which save to keep. Sync state lives in localStorage `mobile_vault_cloud_v1`.
- **Clock:** every reply carries `server_time`; `Cloud.now()` stamps `saved_at` and measures offline time, so moving the phone clock no longer grants offline progress once the cloud has answered.
- **Tests:** the autotest runs the cloud against `tools/cloud_fake.gd` (same revision rules as the SQL, plus fake Google sign-in / linking / logout). Test runners never use `cloud_config.json`.

## 4l. Feature switches, event windows & remote config

Autoload `Features` (`scripts/autoload/features.gd`, right after `Save`) is the one place that decides which systems run, which road events can show, and a few balance numbers. Values come in layers, the later one wins:

| # | Layer | Where | When |
|---|---|---|---|
| 1 | default | `config/features.json` (exported into the pck) | every build |
| 2 | build | `config/features.<tag>.json` for the custom feature tags `demo` / `staging` ([feature tags](https://docs.godotengine.org/en/stable/tutorials/export/feature_tags.html), `OS.has_feature`) | only when the export preset sets that tag |
| 3 | remote | `web/features.json`, fetched from the same folder as the game page (`HTTPRequest`, 10 s timeout) and cached in localStorage `mobile_vault_features_v1` | web builds; a failed fetch keeps the cache, no cache keeps 1–2; refused if `min_game`/`max_game` don't match `BuildInfo.GAME_VERSION` |
| 4 | mode | the run's game mode / mutators (`Game.s.mode`, set by `Modes`, see §4m) | per save |
| 5 | tester | GOD MODE tab **ฟีเจอร์** (kept in `user://dev.cfg`, cleared by "ซ่อนปุ่ม GOD") or the URL `?ff=raids:off,event.raiders:off,tune.threat.rate_scale:1.5` (this session only) | testers |

**Switches** (`Features.on(key)`): `road_events`, `raids` (no raids; the checkpoint warlord still blocks the road), `encounters`, `strangers` (recruits join directly), `expeditions`, `roof_deck`, `large_rooms`, `tutorial` (new games only), `cloud_save` (read at boot, so a remote kill switch bites on the next launch), `modes` (off = NEW RUN skips the rules picker and starts a standard run). Switching one off hides it from play; save data is never deleted.

**Road events** (`events.<id>`): `on`, `weight` (2 = two cards per shuffle-bag round, 0.5 = a card in about half the rounds, 0 = never), `biomes` (`["*"]` or biome ids, adds the event to roads it is not normally on), `from` / `to` (`"2026-11-14"` or `"2026-11-14 18:00"`, local time at `tz_hours`, default 7 = Thailand; a date-only `to` covers the whole day). Clock = `Cloud.now()` (server time when the cloud is on). This is the hook for festival events: put the event in `Data.EVENTS` without a biome and open it with a window.

**Tune** (`Features.num(key, CONST)`, clamped): `events.gap_min/gap_max`, `threat.rate_scale/roll_k/min_quiet`, `encounter.base_chance/danger_chance`, `inspection.rare_chance/very_rare_chance`.

The remote file can only switch off / re-time / re-weight / re-tune what the build already contains: unknown keys are dropped, numbers are clamped, a broken file changes nothing. Example `web/features.json` for a festival weekend with no raids:

```json
{
  "min_game": "4.3",
  "features": {"raids": false},
  "events": {"trader": {"weight": 3}, "bunker": {"biomes": ["*"], "from": "2026-11-14", "to": "2026-11-16"}},
  "tune": {"events.gap_min": 40, "events.gap_max": 80}
}
```

Edit `web/features.json`, push, and Vercel serves it; players pick it up the next time the page loads (no re-export). The active switches go into every trace export (`features`) and a `features` trace entry at boot and after each remote load. Autotest `_features_test()` covers every gate.

## 4m. Game modes (โหมดเกม)

NEW RUN opens a rules picker on the title screen: **mode**, **difficulty** and any number of **mutators**. The choice is locked into the save as `Game.s.mode = {id, diff, mut, started_at}`, carried over to the next generation, and shown in Settings → ตั้งค่า → RUN. Saves from before modes migrate to `standard / normal`. Design page: https://claude.ai/artifact/E6psTiH3QsaiejYK8foN2C (phase 1 of it).

| Choice | Effect |
|---|---|
| เอาชีวิตรอด `standard` | the full game, unchanged |
| ขบวนสงบ `peaceful` | `raids` off (Features layer "mode"); with no kill scrap, the defence squad scavenges the roadside instead: one scrap cap per 30 min (×1.5 per lap); no checkpoint warlord: the vault waits at the checkpoint and pays a toll of 45 % of the scrap cap on its own once the Vault level is high enough and the scrap is there; research points ×0.5; not ranked |
| ง่าย / ปกติ / ยาก / ฝันร้าย | enemy HP 0.7 / 1 / 1.35 / 1.8, enemy damage 0.7 / 1 / 1.25 / 1.5, threat build-up 0.75 / 1 / 1.25 / 1.5, food + water 0.8 / 1 / 1.15 / 1.3, offline cap ×0.5 on nightmare, research 0.75 / 1 / 1.4 / 2.0 |
| น้ำมันขาดแคลน `fuel_scarce` | every fuel gain ×0.5 (spending unchanged), research +20 % |
| ปันส่วนอด `lean_rations` | food + water ×1.4, +15 % |
| ถนนเปลี่ยว `lone_road` | `expeditions`, `encounters`, `strangers` off, +20 % |
| ปืนแก้ว `glass_cannon` | squad damage ×2, squad HP ×0.5, +15 % (not in peaceful) |
| ฝูงคลั่ง `horde` | threat build-up ×1.6, enemy HP ×1.2, +25 % (not in peaceful) |

Research multiplier = mode × difficulty × (1 + mutator bonuses). Multipliers stack by product (`Modes.mul(key)`), switches go into the Features "mode" layer (after remote, before tester overrides, so GOD can still flip them). `Modes.ranked()` = a ranked mode and `stats.cheated` never set; it is the flag the online leaderboards will read. Balance bot: `-- --balance --mode=peaceful,hard,fuel_scarce`. Autotest `_modes_test()`.

## 4c. True pixel art pipeline

- Window: `canvas_items` stretch + **integer** scale mode. `main.gd` picks the design size so it is exactly window ÷ S (S = whole number, base 360×640 portrait / 560×320 landscape) → full-bleed, no letterbox, 1 art pixel = S screen pixels.
- The whole world (parallax, truck, combat, weather, blur) renders inside a **SubViewport at design resolution** and is scaled up with nearest filtering, so particles, tweens and the close-up zoom all stay on one pixel grid. Close-up zoom ends on a whole number (×2/×3).
- No sprite rotation or fractional scaling: solar panels use 5 pre-drawn tilt frames, bosses are drawn at native size, damage numbers use the 8 px Silkscreen font.
- Every texture is snapped to one **grim 16-bit apocalypse** master palette (`tools/art/common.py`): soot-black outlines, rust, grime, bone, smog — the only saturated colours are emissive accents (lamp amber, radioactive green, warning red). Rooms are dark with one caged bulb throwing a dithered warm pool of light; walls carry soot, damp stains, rust drips and cracks; the truck and landmarks get a rust/grime weathering pass; far parallax layers melt into a dithered horizon haze.
- UI: rusted riveted-steel windows with a red title plate, soot-black panels, bone text and amber accents (9-slice frames in `assets/ui`); a mood shader (`shaders/crt.gdshader`) adds a heavy vignette and per-design-pixel grain; fonts rendered without anti-aliasing / oversampling.

## 4f. Tester tools: GOD MODE + trace log

**How to open (hidden from players)**
- Debug builds (running from the editor / debug export): always available.
- Release / web builds: tap the **VAULT** chip in the top bar **7 times** within 5 s, or open the page with `?god=1` (e.g. `https://<your-vercel-app>/?god=1`). Remembered in `user://dev.cfg`. A **GOD** button appears next to the eye/zoom buttons (turns red while a cheat is active); F1 or ` toggles it on desktop. "ซ่อนปุ่ม GOD" locks it again.

**Tabs**
| Tab | What you can do |
|---|---|
| ทั่วไป | switches: invincible (hull / crew / squad), one-hit kills, free build/upgrade/buy, resources always full, no random road events, instant construction · game speed ×1/2/5/10/20 · fast-forward +10 min / +1 h / +4 h (offline simulation) · time of day · any weather · FPS/debug overlay |
| ทรัพยากร | fill / empty everything, set each resource and every usable/material item, all items +10/+100 · forge: test kit (3 items of every rarity + scrap/components), max +level on everything equipped, clear the stash · all blueprints, +100 research points |
| รถ | swap chassis van/bus/rig/train in place, 0–2 trailers, Vault Lv 1–6, hull 100/50/10/0 %, engine bay: heat 40/100/115 °C, condition 100/30/0 %, oil / coolant full or low, every engine into the stash, force a breakdown, rest on/off, finish the engine job, build every empty slot, max room levels · construction: finish now / +50 % / instant-build switch · all mods max / none, weight readout, short circuit / dead battery, acid, solar damage, radiation, infection |
| ลูกเรือ | recruit, heal, happiness 100/20/0 for everyone, pets · spawn a builder (hard hat) plain or with engineer / quick hands / architect / clumsy · strangers at the door: every kind (human / infected / mimic / thief / raider mole) × rare / very rare, clear the queue · per survivor: traits shown, builder on/off, reroll traits, +5 levels, force strike, desert now, kill |
| ต่อสู้ | set wave, kill all enemies, heal squad · force a raid (warning first), set threat 0 / 90 · defence squad: auto-fill with the strongest idle crew, auto-equip best gear, clear · spawn the biome warlord or any mutant boss, spawn 3 of any mob (mutants highlighted), drop 3 items of any rarity |
| ฟีเจอร์ | every Features switch with where its value comes from (ค่าเริ่มต้น / บิลด์ / รีโมต / ผู้ทดสอบ), tap to flip · every road event on/off (biome's own marked *, weight and date window shown) · tune numbers ÷2 / ×2 / back to code · reload remote, clear tester overrides |
| โลก | jump to any biome, go to checkpoint, mark warlord beaten, lap +1 · road events: trigger any, draw the next card from the shuffle bag, reshuffle (bag size + last 3 shown) · expedition: force any special encounter (sends a free scavenging team when none is out), clear the no-repeat history, arrive at any site, finish the trip · open the next-generation screen, wreck the vehicle in 3 s |
| ระบบ | game mode: switch mode / difficulty / mutators of the running save (marks it cheated = unranked), peaceful "go to checkpoint + toll money" · version rows (game / build / engine) + copy · tutorial: replay from the start, skip, jump to any step · cloud save: status/rev, sync now, force upload, forget the link, resolve a conflict · settings: save size, reset to defaults |
| LOG/เซฟ | trace viewer with category filter, download JSON / copy / clear; export the save as JSON (copied to the clipboard) and load a pasted save — testers can hand each other exact situations |

Cheat switches are never saved; any god action marks the save `stats.cheated = true` and is written to the trace.

**Data & logging**
- Save: one JSON document (`Game.s`) in browser `localStorage` key `mobile_vault_save_v1` (desktop: `user://savegame.json`), autosaved every 15 s and when the tab is hidden/closed. When the cloud is configured it is also uploaded to Supabase (section 4i); otherwise nothing leaves the device.
- Trace (`scripts/autoload/trace.gd`): every session gets an id; events (build/upgrade/demolish, road events + choices, boss waves / boss deaths / squad wipes, strikes, desertions, deaths, expeditions with odds and loot, mods, trailers, vault level, biome, generation, wreck, save/load with offline time, warnings/bad toasts, every god action) + a state sample every 30 s (FPS, resources, hull, km, wave, enemies, crew, happiness, load, node count). Engine/script errors are captured with a Godot `Logger` (`OS.add_logger`). The last 400 entries persist across reloads (`localStorage` key `mobile_vault_trace_v1` / `user://trace.json`) and every entry is also printed to the browser console as `[trace] …`.
- Remote monitoring is not enabled. `Trace.sink_url` is the hook for an opt-in endpoint (Vercel function, PostHog, Sentry…) once one is chosen; add a consent prompt before sending anything.

## 5. Project layout

```
project.godot                 Compatibility renderer, 360x640 canvas_items + integer scale, Nearest filter, autoloads
export_presets.cfg            Web preset (no threads)
scenes/main.tscn              root -> scripts/main.gd builds the scene tree
scripts/
  autoload/data.gd            design data: rooms, recipes, items, biomes, weather, events
  autoload/game.gd            simulation, economy, events, offline progress, save/load
  autoload/save_system.gd     localStorage (JavaScriptBridge) / user:// fallback
  autoload/cloud.gd           Supabase cloud save: anonymous auth, rpc_load / rpc_save, conflicts, server clock
  autoload/atlas.gd           texture atlas -> AtlasTexture / SpriteFrames cache
  autoload/lore.gd            logbook entries, crew bios, idle chatter lines
  world/chatter.gd            speech bubbles above survivors
  main.gd                     camera fit, swipe, tap, room close-up zoom + blur, build placement, floating numbers, shake
  world/background.gd         Parallax2D layers per biome (sky, clouds, far, mid, near, road) + cross-fade
  world/vehicle.gd            van / bus / rig / train shells + trailers, exterior shell (X-ray), wheels per tier, mods, pets, dust/mud, smoke, solar tilt frames, headlight, body bob
  world/cab_view.gd           the engine room in the cab (state art, crew, steam)
  world/room_view.gd          room interior, level pips, synergy markers, craft strip, build highlight, night glow, blackout + head-torches
  world/pet_actor.gd          roaming pets
  autoload/haul.gd            weight / engine capacity / speed / fuel burn
  autoload/modes.gd           game modes: mode / difficulty / mutators of a run (Game.s.mode)
  autoload/engine_bay.gd      engine in the cab: types, drive modes, heat / auto-rest, wear, jobs, noise
  autoload/synergy.gd         room adjacency rules
  autoload/dev.gd             tester switches + god actions (hidden unlock)
  autoload/trace.gd           local event trace, state sampler, error capture, export
  ui/god_panel.gd             GOD MODE console
  ui/engine_panel.gd          engine menu (status / engines / jobs)
  ui/expedition_feed.gd       live helmet-cam view of the scavenging squad
  autoload/threat.gd          threat meter + raid director (quiet / warning / raid / salvage), classic toggle
  autoload/encounter.gd       rare special encounters during an expedition (choices, risks, refugees)
  ui/encounter_popup.gd       encounter decision pop-up
  ui/boss_bar.gd              boss HP bar
  world/dweller_actor.gd      idle / walk / sit / work state machine (AnimatedSprite2D)
  world/weather_fx.gd         rain, snow, sand, fog, leaves, lightning, haze, day/night CanvasModulate
  world/fx.gd                 particle factory: GPUParticles2D (default) / CPUParticles2D (Low FX)
  ui/*.gd                     UIKit theme + HUD, close-up, dwellers, build, map, inventory, solar, events, title
shaders/focus_blur.gdshader   single-pass blur outside the focused room (WebGL2-safe)
assets/atlas/                 atlas.png + atlas.json (all sprites in ONE texture)
assets/bg/                    tall seamless 480 px parallax layers per biome (sky strip, sun, clouds, far, mid, near, road)
assets/ui/                    rusted-steel 9-slice frames, buttons, speech bubble
assets/events/                event illustrations
assets/fonts/                 Chakra Petch (Thai) + Silkscreen (pixel), SIL OFL
tools/generate_pixel_art.py   regenerates every PNG (python3 + Pillow) via tools/art/*.py
tools/autotest.gd             smoke test (excluded from export)
tools/balance.gd              4-hour headless balance bot (`godot --headless --path . -- --balance --minutes=240`)
```

## 6. Notes on choices vs. the brief

- **ParallaxBackground / ParallaxLayer are deprecated** in the current stable docs ("Use the Parallax2D node instead"), so the background uses **Parallax2D** (`scroll_scale`, `repeat_size`, `repeat_times`, `autoscroll`) — same multi-speed effect, the supported API.
- Web export only supports the **Compatibility renderer (WebGL 2)** per the docs, so the project is set to it everywhere. `WorldEnvironment` glow isn't used; the colour grade is a `CanvasModulate`.
- Particles default to **GPUParticles2D** (docs recommendation). Title screen has a **CPU (ประหยัด)** toggle that switches the same configs to CPUParticles2D for weak phones.
- **Close-up mode** = management mode: the road, travel and random events pause; production and crafting keep running so progress bars stay live.
- Pixel art is crisp: project-wide `default_texture_filter = Nearest`; the atlas means one texture download and batched draws.
- Portrait is the primary layout (360 px wide terminal UI); landscape moves the tool buttons into a right-hand column.

## 7. Dev smoke test

```
godot --path . -- --autotest --out=/absolute/output/dir
```
Visits every screen, fires events, fast-forwards 30 min, round-trips the save, rotates to portrait, and writes screenshots.
Add `--only=large` (after `--`) to run just the large-room checks (~30 s).

## 8. Replacing the art

Every PNG is generated by `tools/generate_pixel_art.py` (deterministic): `tools/art/rooms.py` (64×52 room interiors, three per floor), `truck.py` (280×300/356/412 truck shells for 4/5/6 floors, wheels, snow tracks, solar frames, turrets, exterior mod overlays), `landmarks.py` (expedition sites), `chars.py` (dwellers, 20×20 portraits, enemies, bosses), `bg.py` (parallax layers), `events.py` (160×80 illustrations), `encounters.py` (160×80 expedition encounter scenes), `ui.py` (icons, terminal frames). Swap any file for hand-drawn art with the same size (atlas regions are listed in `assets/atlas/atlas.json`). Dweller sheets are 14×20 frames: idle(0-1) walk(2-5) sit(6) work(7-8).

Fonts: Chakra Petch & Silkscreen — SIL Open Font License (see `assets/fonts/OFL_*.txt`).

## 9. Deploy (GitHub + Vercel)

`web/` holds the ready-to-serve Web export (Godot 4.7.2, single-threaded, so no COOP/COEP headers are needed). `vercel.json` tells Vercel to skip the build step and serve `web/` as static files with the right `application/wasm` header.

1. Push this folder to a GitHub repository.
2. On vercel.com → **Add New → Project → Import** the repository → keep the defaults (Framework: Other) → **Deploy**. Every push to the main branch redeploys automatically.
3. After changing the game, re-export into `web/`: `godot --headless --path . --export-release "Web" web/index.html`, commit, push.

### Link preview (Open Graph / Twitter card)

Shared links show a title, a Thai/English description and a 1200×630 pixel-art card. The tags are in the Web preset's **`html/head_include`** (Project → Export → Web → HTML → Head Include; [docs](https://docs.godotengine.org/en/stable/classes/class_editorexportplatformweb.html#class-editorexportplatformweb-property-html-head-include)), so every export writes them into `index.html`. The favicon comes from `html/export_icon` (the project icon).

- Image: `web/og-image.png`, made from the game art by `python3 tools/og_image.py` (rerun after regenerating art). Godot does not export it, so it stays committed in `web/`.
- Crawlers need an **absolute** URL: `og:url`, `og:image`, `twitter:image` and `canonical` point at `https://mobile-vault-three.vercel.app/`. If the production domain changes, update those four in `html/head_include` and re-export (the autotest checks the image URL is absolute https).
- Check with the [Facebook Sharing Debugger](https://developers.facebook.com/tools/debug/) (press **Scrape Again** after a deploy, since Facebook/LINE cache previews), [opengraph.xyz](https://www.opengraph.xyz/) or by pasting the link into a LINE / Discord / X draft.
