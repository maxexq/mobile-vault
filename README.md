# APOCARLYPSE: Mobile Vault

> **Apo-CAR-lypse** = car + apocalypse. The game was called "Mobile Vault" up to v4.6; the vehicle is still the Mobile Vault, and the repo, Vercel domain, save keys and Supabase project keep the `mobile-vault` name. The player-facing title lives in `BuildInfo.GAME_NAME`, `project.godot` `config/name`, the Web preset `html/head_include` (og/twitter tags) and `UIKit.logo()` (title screen + Settings › About).

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
- **Swipe left/right** → look along the highway, as far as the end of the trailers and the fight behind them (springs back after 3 s). The road follows the finger at every zoom.
- **Portrait phones (MV-148):** the AUTO camera zooms the vehicle in to the largest whole-number scale at which the main body still fits the screen width (and the vehicle its height), so it fills the screen instead of sitting small under the sky; trailers are a swipe away and boss fights still pull back to the wide view. Switch `portrait_fit`, tune `view.fit_cap` (max ×2 the UI pixel scale) / `view.fit_margin` (4 art px).
- **Pinch** (two fingers) / **mouse wheel** / trackpad → one step farther or closer through the camera levels that look different right now (`Main.zoom_ladder`): กว้าง → ปกติ → อัตโนมัติ, where a level shared by two modes is taken by อัตโนมัติ. So spreading the fingers always gets back to auto (on a portrait phone: the vehicle fills the screen), and one step never moves the wrong way.
- **Drag a finger over any list** (map, build, squad…) → it scrolls, also when the finger lands on a button; a button only fires on a tap.
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
| Art | `tools/art/rooms.py` `gen_wide_rooms()`: the room's own wall at full width, its furniture left + mirrored right, a centre piece per type for 3 cells (couch & TV, stock pot, grow tower, settling tank, operating table, rifle wall, mainframe, transmitter, fractionating column, engine hoist), a steel post where the wall stood, also where the ladder shaft crosses cells 0|1 of the main body (the shaft never cuts through a large room, MV-146). Keys `room_<type>_x<gaps>` (`x2`, `x10`, `x2_2`, `x10_2`). The atlas is now 2048×2048. |
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
| Switch | `engine_bay` (MV-40): off = the game before v4.6. `EngineBay.on()` gates every read (stock diesel I4 numbers whatever engine is fitted, mode normal, heat 40 °C / condition 100 %, no rest or job holds the vehicle, alternator at level 1) and `tick()` simulates nothing; tapping the cab only says the engine bay is off. Crew in the cab still repair the hull like the old engine room. The saved engine state and fitted engine come back when it is turned on again. GOD → รถ → สวิตช์. |
| Art | `tools/art/engine_bay.py`: `cab_<tier>_<idle|run|hot|broken>` rooms + `eng_<type>` icons; `vehicles.py` cuts the cab hole. |

## 4i. Cloud save (Supabase)

Local-first: the game still reads and writes localStorage / `user://`; `scripts/autoload/cloud.gd` mirrors that save (plus Settings) to one row per player in Supabase, using `HTTPRequest` against the REST API (no addon).

- **Setup (once):** run `supabase/migrations/0001_cloud_save.sql` in the Supabase SQL Editor, enable *Authentication → Allow anonymous sign-ins*, then copy `cloud_config.example.json` to `cloud_config.json` (git-ignored) with the Project URL and the **anon / publishable** key. Never put the `service_role` / secret key in the game. Without the file the cloud is off and the game is offline-only, as before.
- **Accounts:** first launch signs in as a **Guest** (Supabase anonymous user); the session (refresh token) is kept in localStorage `mobile_vault_auth_v1` and reused on every visit until the player signs out. The first time on a browser the title asks **เล่นเลยแบบ Guest** or **ล็อกอินด้วย Gmail** (two buttons; the pick is `chose` in the sync meta). Gmail on a browser with no progress signs straight in to the account and pulls its save. A Google session the server refuses (refresh token rejected) is never replaced by a guest quietly: the title asks to log in again and the local save stays. Refreshes are serialized because Supabase rotates refresh tokens. The title menu shows the account and opens Settings → เซฟ, where:
  - a guest with progress taps **ผูกบัญชี Gmail** → Supabase *manual linking* (`GET /auth/v1/user/identities/authorize?provider=google&skip_http_redirect=true`) adds Google to the same user id, so the save stays put;
  - if that Google account already has its own user (`identity_already_exists`), **สลับไปบัญชี Google นั้น** signs in to it (`/auth/v1/authorize?provider=google`); when both this device and the account have progress the usual conflict choice appears;
  - a Google user can **ออกจากระบบ**: the save is uploaded first (refused when offline), the local copy is removed and a fresh guest starts.
  - Google uses the redirect (implicit) flow: the page goes to Google and comes back with the session in the URL fragment, read and cleared on boot. Google refuses to sign in inside a frame (the artifact view), so there the game offers to open `site_url` in a new tab.
  - Setup: Google Cloud OAuth client (Web) with redirect URI `https://<ref>.supabase.co/auth/v1/callback`; Supabase → Google provider on + **Allow manual linking**; URL Configuration → Site URL + Redirect URLs for the Vercel production and preview domains. Step-by-step (Thai): `supabase/google-login-setup.md`.
- **Player ID (MV-115):** every account has a short public id like `0G3SQ-MSKUU` for support, mail and problem reports: the first 48 bits of the Supabase auth user id in base32 (`Cloud.short_id`, alphabet = Crockford with U for D so nothing reads as 0 or 1). It is never stored on the server, so it is the same on every device and survives a guest linking Gmail. Shown in Settings → เซฟ (PLAYER ID + copy button) and in the About tab's bug-report copy; written into the save (`account.pid`), the trace (`session player` entry, `player` in the exported log). Support lookup: run `supabase/migrations/0003_player_id.sql` once, then `select * from public.find_player('<what the player typed>')` in the SQL Editor (forgives case, dashes, O/D for 0, I/L for 1). Switch `player_id`.
- **Player logs (MV-116):** `scripts/autoload/telemetry.gd` uploads Trace entries (session, errors, saves, 30 s economy samples, progression, combat, crew, expeditions, god actions) to `public.logs` through `rpc_log`, 100 per request every 60 s and when the tab hides. The server stamps each row with the user id and player id. Offline the entries wait in the Trace (last 400 kept across reloads) and go up later; the cursor is `log_t` + `log_k` in the sync meta. Only entries from the first session it runs in onwards are sent, never before the one-time in-game privacy notice; players turn it off in Settings → ตั้งค่า → ความเป็นส่วนตัว (`telemetry`). A failed batch never touches the save sync. Setup: run `supabase/migrations/0004_logs.sql` once (after 0003). **Where to watch:** Supabase dashboard → Table Editor → `logs`, or the SQL Editor: `log_errors_recent`, `log_errors_daily`, `log_players_daily` views and `select * from public.log_player('<player id>')` (one player's timeline). Players can't read the table. Switch `cloud_logs`, tune `logs.flush_sec` / `logs.batch`. Error spikes and new errors are posted to Discord every 15 min (MV-171, §9 "Error spike alerts").
- **Migration:** a browser that already has a save uploads it as revision 1 on the first online start. Schema 2 (account envelope, 4o) needs `supabase/migrations/0002_schema_guard.sql` run once so older builds can't overwrite it.
- **Sync:** upload at most once a minute while playing and on tab hide; offline keeps saving locally and retries every 30 s. Writes go through `rpc_save`, which rejects a stale revision, so when two devices both moved on the Settings → เซฟ tab asks which save to keep. Sync state lives in localStorage `mobile_vault_cloud_v1`.
- **Clock:** every reply carries `server_time`; `Cloud.now()` stamps `saved_at` and measures offline time, so moving the phone clock no longer grants offline progress once the cloud has answered.
- **Anti-cheat F0 + F1 (MV-174, design https://claude.ai/artifact/QWiRy6Qd5hLx5MDq8DCAP5):** the save stays client-owned; the server checks what it can without running the game. Setup: run `supabase/migrations/0006_anticheat.sql` once (after 0005; safe to re-run).
  - *Offline time:* `saved_at` sits in the editable save, so `Game.offline_elapsed()` caps the catch-up with `Cloud.server_seen` = the server time of the last accepted save (`saves.updated_at` from `rpc_load`, `server_time` after an upload). Moving `saved_at` back no longer buys extra hours once the cloud has answered. Switch `anticheat` (client cap only; the server always checks).
  - *Rate limit:* `rpc_save` refuses a write less than 3 s after the last accepted one (`{ok:false, rate_limited:true}`); the game keeps it dirty and sends it with the next upload round.
  - *Shadow flags* in `public.player_state` (players can't read or write it): `god_at` once a save says GOD MODE was used (sticky, editing the save can't clear it), `god_log_at` when real god actions reach the logs, and `suspect_score` + `reasons` when a counter grew faster than `public.anticheat_limits` allows for the real time between two saves: `account.life.sim_sec` (simulated seconds, counted by `Account.add_sim_time`, can't outrun the clock), km, kills, generations. Saves are never refused for this; the first save of a player is only the baseline. Each new flag also writes a `cat = 'anticheat'` row to `logs`.
  - *Where to look:* `select * from public.anticheat_suspects;` · change a limit live: `update public.anticheat_limits set per_hour = ... where key = 'km';` · tests: `bash tools/test_error_spike.sh` runs `tools/tests/anticheat_test.sql` on a throwaway PostgreSQL, autotest group `anticheat` covers the game side.
- **Tests:** the autotest runs the cloud against `tools/cloud_fake.gd` (same revision rules as the SQL, plus fake Google sign-in / linking / logout). Test runners never use `cloud_config.json`.

## 4l. Feature switches, event windows & remote config

Autoload `Features` (`scripts/autoload/features.gd`, right after `Save`) is the one place that decides which systems run, which road events can show, and a few balance numbers. Values come in layers, the later one wins:

| # | Layer | Where | When |
|---|---|---|---|
| 1 | default | `config/features.json` (exported into the pck) | every build |
| 2 | build | `config/features.<tag>.json` for the custom feature tags `demo` / `staging` ([feature tags](https://docs.godotengine.org/en/stable/tutorials/export/feature_tags.html), `OS.has_feature`) | only when the export preset sets that tag |
| 3 | remote | `web/features.json` (outside production `web/features.<env>.json` first, MV-112), fetched from the same folder as the game page (`HTTPRequest`, 10 s timeout) and cached in localStorage `mobile_vault_features_v1` | web builds; a failed fetch keeps the cache, no cache keeps 1–2; refused if `min_game`/`max_game` don't match `BuildInfo.GAME_VERSION` (semver compare, so `4.7.0-alpha.1` is below `4.7.0`) |
| 4 | mode | the run's game mode / mutators (`Game.s.mode`, set by `Modes`, see §4m) | per save |
| 5 | tester | GOD MODE tab **ฟีเจอร์** (kept in `user://dev.cfg`, cleared by "ซ่อนปุ่ม GOD") or the URL `?ff=raids:off,event.raiders:off,tune.threat.rate_scale:1.5` (this session only) | testers |

**Switches** (`Features.on(key)`): `road_events`, `raids` (no raids; the checkpoint warlord still blocks the road), `encounters`, `strangers` (recruits join directly), `expeditions`, `roof_deck`, `large_rooms`, `tutorial` (new games only), `cloud_save` (read at boot, so a remote kill switch bites on the next launch), `player_id` (the short player id in Settings, save and trace, §4i), `cloud_logs` (player logs to Supabase, §4i; off = logs stay on the device), `portrait_fit` (portrait phones zoom the vehicle to fill the screen, §2 Controls), `tutorial_tips` (Sgt. Mark's one-time tip the first time a system opens), `event_timer` (road events have a clock, the crew decides on time-out, §4l), `engine_bay` (engine heat / wear / oil / engine types; off = the stock diesel of v4.5, §4l), `persistent_account` (off = the title shows NEW RUN again, which erases the account and starts over), `channel_badge` (the ALPHA / BETA / RC tag under the logo, §9 Versioning), `env_badge` (STAGING / UAT / DEV SERVER tag outside production, §9 Environments), `resume_on_reload` (a web page reload with a save goes straight back into the game once the cloud has answered; the title stays when a Guest/Gmail choice, a new login or a save conflict needs the player), `room_ambience` (room lamp light + micro animation, §4n), `anticheat` (offline catch-up capped by the server's last accepted save, §4i), `crew_roster_20` (20 named crew can board instead of an ordinary recruit, §4c "Named crew"; off = the old outfit × hair recruits, crew already on board stay and still render), `announce` (the news / new-version strip at the top of the screen, see "Announcements" below). Switching one off hides it from play; save data is never deleted.

**Quick-time road events (MV-134):** an event window has a clock: `30 / (1 + 0.5 × danger)` seconds (a safe event 30 s, danger 2 = 15 s, the deadliest ~5 s), or the event's own `"decide"`; tune `events.decide_scale`, Settings → ตั้งค่า → เวลาตัดสินใจอีเว้นต์ ปกติ / นานขึ้น x2 / ไม่จับเวลา (`event_timer`). When it runs out the crew takes the cautious choice (`Game.event_auto_choice`: a choice marked `"auto": true`, else the first affordable of drive on → detour → shelter → flee → push → ram → pay → …; a fight goes out with the two strongest aboard). The clock only runs while the player has touched the screen in the last 20 s (`EventPopup.since_input`), so idle play or a dark screen leaves the event waiting with the vehicle parked, as before; a hidden browser tab doesn't run at all. Switch `event_timer`. GOD → โลก → "อีเว้นต์สุ่ม หมดเวลาใน 2 วิ". The autotest runs with the clock off except `_qte_test` (`--only=qte`).

**Road events** (`events.<id>`): `on`, `weight` (2 = two cards per shuffle-bag round, 0.5 = a card in about half the rounds, 0 = never), `biomes` (`["*"]` or biome ids, adds the event to roads it is not normally on), `from` / `to` (`"2026-11-14"` or `"2026-11-14 18:00"`, local time at `tz_hours`, default 7 = Thailand; a date-only `to` covers the whole day). Clock = `Cloud.now()` (server time when the cloud is on). This is the hook for festival events: put the event in `Data.EVENTS` without a biome and open it with a window.

**Tune** (`Features.num(key, CONST)`, clamped): `events.gap_min/gap_max`, `threat.rate_scale/roll_k/min_quiet`, `encounter.base_chance/danger_chance`, `inspection.rare_chance/very_rare_chance`, `ambience.flicker` (lamp flickers per minute per lamp, 0.6), `logs.flush_sec` (player logs upload interval, 60), `logs.batch` (entries per upload, 100), `view.fit_cap` (portrait zoom-in limit × UI pixel scale, 2), `view.fit_margin` (art px around the main body, 4), `events.decide_scale` (road-event decision time ×, 1), `fx.shake` (screen-shake strength, 0.5 = half the pre-MV-175 shake, 0 = none; also the boss bar), `fx.engine_shake` (vehicle body rumble + road bumps, 0.5 = half the pre-MV-176 jolts; below 1 px it is a whole pixel that many times as often, `Vehicle.px_amp`; Settings → รถสั่น off = none), `crew.roster_chance` (chance a non-builder recruit is one of the 20 named crew, 0.35), `crew.cameo_weight` (weight of the 5 cameo guests next to an original, 0.5; 0 = originals only), `announce.loops` (times each announcement scrolls across, 3), `announce.speed` (strip text px/s, 40), `announce.poll_min` (minutes between in-game checks of features.json + version.json on the web, 5).

The remote file can only switch off / re-time / re-weight / re-tune what the build already contains: unknown keys are dropped, numbers are clamped, a broken file changes nothing. Example `web/features.json` for a festival weekend with no raids:

```json
{
  "min_game": "4.3",
  "features": {"raids": false},
  "events": {"trader": {"weight": 3}, "bunker": {"biomes": ["*"], "from": "2026-11-14", "to": "2026-11-16"}},
  "tune": {"events.gap_min": 40, "events.gap_max": 80}
}
```

Edit `web/features.json`, push, and Vercel serves it; players pick it up the next time the page loads (no re-export), and players already in the game within `announce.poll_min` minutes (5) or when they bring the tab back to the front.

**Announcements + new-version notice (MV-188).** Autoload `Announce` + `Marquee` strip (`scripts/ui/marquee.gd`, its own CanvasLayer 45 over the HUD and every panel). A message scrolls across the top of the screen from right to left `announce.loops` times (3), then the strip hides and the next one starts. Two sources:

- `"announce"` in `web/features.json`: `[{"id": "maint-1101", "text": "ปิดปรับปรุง 1 พ.ย. 22:00-22:30 น.", "text_en": "optional", "from": "2026-10-31", "to": "2026-11-01 22:30", "loops": 2}]`. `id` and `text` are required (text up to 300 characters); `from` / `to` work like event windows; `loops` 1–5 overrides the tune. Each id shows once per browser (localStorage `mobile_vault_announce_seen_v1`), so give a new message a new id.
- `web/version.json` `{version, commit, built}`, written by `tools/stamp_build.sh` at every export and committed with `web/`. While the game runs on the web it fetches this file (and features.json) 30 s after boot, every `announce.poll_min` minutes and when the tab comes back to the front (at most once a minute). A `built` newer than the running build's stamp puts a green **UPDATE** notice first in line: "มีเวอร์ชันใหม่ vX แล้ว! แตะแถบนี้หรือรีโหลดหน้าเว็บเพื่ออัปเดต"; tapping the strip saves and reloads the page. A build without a stamp (editor, "dev") never asks. So players who keep a tab open for days still hear about a deploy.

Switch `announce` (off = the strip hides, nothing is fetched in game). GOD → ระบบ → ANNOUNCE. Autotest `_announce_test()` (`--only=announce`). The active switches go into every trace export (`features`) and a `features` trace entry at boot and after each remote load. Autotest `_features_test()` covers every gate.

## 4o. Persistent account (ไอดีถาวร, MV-159)

One account per player that keeps growing (decision MV-114). Design: `docs/design/persistent_account.md`.

- **Save = envelope v2** `{v: 2, account, main}` (same localStorage key / file). `Account.a` is the account: `meta` (generation, research points, perks, blueprints), `lore`, `memorial`, `tutorial`, `settings.diff`, plus empty `events` / `tree` / `places` / `life` for live-service features. `Game.s` is still the active vehicle; the account keys in `Account.SHARED` are put into `Game.s` as references to the same objects, so `Game.s.meta` / `Game.s.lore` keep working and are stored once.
- **Next Generation** only replaces the vehicle; logbook, memorial and tutorial now survive it (they were lost before).
- **No rules picker.** Title: CONTINUE with a save, START on a browser without one. Erasing the account is Settings → เซฟ → รีเซ็ตความคืบหน้า. The main vehicle always plays `standard`; **difficulty** is a setting (Settings → ตั้งค่า → ความยาก, `Account.set_diff`), changeable any time.
- **Migration v1 → v2** (`Account.migrate_v1`, on load): the old run becomes the main vehicle; peaceful / mutators turn into standard, the picked difficulty becomes the setting, the old rules stay in `account.legacy_mode` and the player gets a one-time toast.
- **Cloud:** `Cloud.SCHEMA = 2`; run `supabase/migrations/0002_schema_guard.sql` once: `rpc_save` refuses a write from an older build (`{ok:false, old_client:true}`) so a stale tab can't overwrite the account.
- Switch `persistent_account` (off = NEW RUN is back and starts over from nothing). GOD → ระบบ → ไอดีถาวร: account summary, "จำลองเซฟเก่า v1" (turns the running account into an old save and loads it). Autotest `_account_test()`.

## 4m. Game modes (โหมดเกม)

Modes are no longer picked by players (see 4o): they stay as **rule sets for a vehicle**, read from `Game.s.mode = {id, diff, mut, started_at}`, for the coming time-limited events (separate event vehicle), the balance bot and GOD MODE. The main vehicle is always `standard` at the account's difficulty. Original design page: https://claude.ai/artifact/E6psTiH3QsaiejYK8foN2C.

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

## 4n. Room lighting + micro animation (MV-167)

Every 64 px room and the cab engine bay get a `RoomAmbience` layer (`scripts/world/room_ambience.gd`) between the interior art and the crew. It is drawn in code on the 1 px grid at 12 fps, so it needs no new art or PixelLab credits.

| Part | What it does |
|---|---|
| Lamp | An additive light pool under the ceiling lamp, built as 3 dithered bands. It breathes slowly and is stronger at night (`Vehicle.apply_light` passes `night`). It flickers now and then (`ambience.flicker` per minute): the bulb goes grey and the room dips dark. Dust motes drift in the light. |
| Rooms | medical: ECG on the monitor · quarters: blinking alarm clock · kitchen: pot steam and stove flames · hydroponics: grow-light pulse and drips · water: tank bubbles and a pipe drip · armory: crate LED · science: flask bubbles, a glowing vial and a scanning screen · radio: LEDs and a VU meter · engine: gauge needles, warning lamp and exhaust puffs · refinery: furnace fire, gauges and a scrolling screen · workshop: turning wheel and vise sparks |
| Cab engine bay | Heat gauge needle from `EngineBay.heat()`, a status LED (green, or blinking red when hot or broken), rocker covers ticking while running, a hot glow on the block, and sparks when broken. |
| Off when | The Features switch `room_ambience` is off, during a blackout (the head-torches take over), on building sites, and in wide knock-through rooms (their art is still the old procedural one). |

Positions are pixels of the PixelLab room art (`tools/art/pixellab/overrides`). If a room is redrawn, move its entries in `_draw_fx`. Autotest: `--only=ambience`.

## 4c. True pixel art pipeline

- Window: `canvas_items` stretch + **integer** scale mode. `main.gd` picks the design size so it is exactly window ÷ S (S = whole number, base 360×640 portrait / 560×320 landscape) → full-bleed, no letterbox, 1 art pixel = S screen pixels.
- The whole world (parallax, truck, combat, weather, blur) renders inside a **SubViewport at design resolution** and is scaled up with nearest filtering, so particles, tweens and the close-up zoom all stay on one pixel grid. Close-up zoom ends on a whole number (×2/×3).
- World scale (`Main.target_ws`) is a whole number of screen px per art px: S normally, S−1 (or ⌊0.67·S⌋) in the wide view, and above S when a portrait phone zooms in (MV-148). Zoomed in, the viewport is rounded up and its texture drawn at exactly viewport × world scale screen px (top-left anchored), so pixels stay square.
- No sprite rotation or fractional scaling: solar panels use 5 pre-drawn tilt frames, bosses are drawn at native size, damage numbers use the 8 px Silkscreen font.
- **Creature redesign (MV-178):** the three pets (dog, cat, two-headed hen), three enemies (Rad-Wolf, Acid Spitter, Bone Brute) and three warlords (Alpha Rad-Wolf, Junk Golem, Scorpion King) are drawn as text rows at native size, one character per pixel, in `tools/art/chars.py` / `extra.py` (`rows_sprite()` in `common.py` adds the one-pixel ol0 outline). Same sizes, frame names, facing and timing as before; each sprite uses only its micro-asset spec palette (`micro_asset.py verify MV-179`…`MV-187`). Contact sheets and in-game 2x shots: `docs/micro-assets/mv-178/`. Autotest `--only=creatures`.
- Every texture is snapped to one **grim 16-bit apocalypse** master palette (`tools/art/common.py`): soot-black outlines, rust, grime, bone, smog — the only saturated colours are emissive accents (lamp amber, radioactive green, warning red). Rooms are dark with one caged bulb throwing a dithered warm pool of light; walls carry soot, damp stains, rust drips and cracks; the truck and landmarks get a rust/grime weathering pass; far parallax layers melt into a dithered horizon haze.
- **Named crew (MV-170, switch `crew_roster_20`)**: 20 hand-set survivors (5 cameo guests marked ★ in GOD MODE, 15 originals) on top of the 40 outfit × hair recruits. Each is one `dw_crew_<id>` region (280×20 = the same 20 frames of 14×20 as every crew sheet, so `Atlas.DW_FRAMES` / `DW_FPS` load them unchanged) plus a `pt_dw_crew_<id>` 20×20 portrait, drawn by `CREW` in `tools/art/chars.py`. Every pixel stays inside that character's Codex spec palette (`tools/art/crew_roster_20/specs/*.json`; shading steps along the palette's own ramps, props snap to the nearest spec colour). Reference concepts, catalogue and style sheet live in `tools/art/crew_roster_20/` (`.gdignore`, not exported). Names / roles / best stat: `Data.CREW_ROSTER`. `Game.recruit_random` rolls the roster after the normal outfit roll (so the switch off gives exactly the old rolls): a named member not on board yet, preferring their best stat (`Crew.roster_pick`). Builders keep their hard-hat look; named crew toggled to builder keep their own sprite.
- UI: rusted riveted-steel windows with a red title plate, soot-black panels, bone text and amber accents (9-slice frames in `assets/ui`); a mood shader (`shaders/crt.gdshader`) adds a heavy vignette and per-design-pixel grain; fonts rendered without anti-aliasing / oversampling.

## 4f. Tester tools: GOD MODE + trace log

**How to open (hidden from players)**
- Debug builds (running from the editor / debug export): always available.
- Release / web builds: tap the **VAULT** chip in the top bar **7 times** within 5 s, or open the page with `?god=1` (e.g. `https://<your-vercel-app>/?god=1`). Remembered in `user://dev.cfg`. A **GOD** button appears next to the eye/zoom buttons (turns red while a cheat is active); F1 or ` toggles it on desktop. "ซ่อนปุ่ม GOD" locks it again.

**Tabs**
| Tab | What you can do |
|---|---|
| ทั่วไป | switches: invincible (hull / crew / squad), one-hit kills, free build/upgrade/buy, resources always full, no random road events, instant construction · game speed ×1/2/5/10/20 · fast-forward +10 min / +1 h / +4 h (offline simulation) · time of day · any weather · shake: strength (`fx.shake`) + light / hardest test shake, vehicle rumble `fx.engine_shake` x1 / x0.5 / default · screen: window size + UI / world scale readout, desktop presets (phones 720×1280 / 780×1688 / 1170×2532, landscape 1280×640, tablet 1366×1024) to preview layouts · FPS/debug overlay |
| ทรัพยากร | fill / empty everything, set each resource and every usable/material item, all items +10/+100 · forge: test kit (3 items of every rarity + scrap/components), max +level on everything equipped, clear the stash · all blueprints, +100 research points |
| รถ | swap chassis van/bus/rig/train in place, 0–2 trailers, Vault Lv 1–6, hull 100/50/10/0 %, engine bay: switch on/off (`engine_bay`), heat 40/100/115 °C, condition 100/30/0 %, oil / coolant full or low, every engine into the stash, force a breakdown, rest on/off, finish the engine job, build every empty slot, max room levels, every lamp flickers for 2 s (room ambience) · construction: finish now / +50 % / instant-build switch · all mods max / none, weight readout, short circuit / dead battery, acid, solar damage, radiation, infection |
| ลูกเรือ | recruit, heal, happiness 100/20/0 for everyone, pets · spawn a builder (hard hat) plain or with engineer / quick hands / architect / clumsy · strangers at the door: every kind (human / infected / mimic / thief / raider mole) × rare / very rare, clear the queue · named crew (MV-170): every one of the 20 playing any animation (idle / walk / sit / work / guitar / coffee / clean / hammer / carry) next to its portrait, board one or all, roster chance 100 % / 0 % / default · per survivor: traits shown, builder on/off, reroll traits, +5 levels, force strike, desert now, kill |
| ต่อสู้ | set wave, kill all enemies, heal squad · force a raid (warning first), set threat 0 / 90 · defence squad: auto-fill with the strongest idle crew, auto-equip best gear, clear · spawn the biome warlord or any mutant boss, spawn 3 of any mob (mutants highlighted), drop 3 items of any rarity |
| ฟีเจอร์ | every Features switch with where its value comes from (ค่าเริ่มต้น / บิลด์ / รีโมต / ผู้ทดสอบ), tap to flip · every road event on/off (biome's own marked *, weight and date window shown) · tune numbers ÷2 / ×2 / back to code · reload remote, clear tester overrides |
| โลก | jump to any biome, go to checkpoint, mark warlord beaten, lap +1 · road events: trigger any, a random one that times out in 2 s (quick-time clock), draw the next card from the shuffle bag, reshuffle (bag size + last 3 shown) · expedition: force any special encounter (sends a free scavenging team when none is out), clear the no-repeat history, arrive at any site, finish the trip · open the next-generation screen, wreck the vehicle in 3 s |
| ระบบ | account: generation / difficulty / logbook / memorial summary, "จำลองเซฟเก่า v1" to test the migration · game mode: switch mode / difficulty / mutators of the running save (marks it cheated = unranked), peaceful "go to checkpoint + toll money" · version rows (game / channel / build / engine) + copy, preview the alpha / beta / rc / stable badge (ของจริง = the real one) · environment line (env, Supabase project, remote config file, host) + preview the prod / uat / staging / dev badge (servers never change) · tutorial: replay from the start, skip, jump to any step · tips: seen count, reset, show any tip · cloud save: status/rev, player id + "copy player id + user id" (for support lookups, does not mark the save cheated), sync now, force upload, forget the link, resolve a conflict · cloud logs: queued / sent / last error / why it is off, "ส่ง log ตอนนี้", "ส่ง error ทดสอบ" (a fake error straight to `public.logs`) · anti-cheat (MV-174): server's last accepted save time, lifetime simulated hours, refused-too-soon count, "ทดสอบโกงเวลา" (what moving `saved_at` back 4 h would give with and without the server cap) and "อัปโหลดซ้อน 2 ครั้ง" (the server should refuse the second); both are read-only and don't mark the save cheated · announcements (MV-188): features.json messages open now / seen / queued + last version.json, "ประกาศทดสอบ", "แจ้งเวอร์ชันใหม่" (the update notice; tapping it saves and reloads), "เช็กตอนนี้" (fetch features.json + version.json now), "ลืมที่เคยเห็น" · settings: save size, reset to defaults |
| LOG/เซฟ | trace viewer with category filter, download JSON / copy / clear; export the save as JSON (copied to the clipboard) and load a pasted save — testers can hand each other exact situations |

Cheat switches are never saved; any god action marks the save `stats.cheated = true` and is written to the trace.

**Data & logging**
- Save: one JSON document (`Game.s`) in browser `localStorage` key `mobile_vault_save_v1` (desktop: `user://savegame.json`), autosaved every 15 s and when the tab is hidden/closed. When the cloud is configured it is also uploaded to Supabase (section 4i); otherwise nothing leaves the device.
- Trace (`scripts/autoload/trace.gd`): every session gets an id; events (build/upgrade/demolish, road events + choices, boss waves / boss deaths / squad wipes, strikes, desertions, deaths, expeditions with odds and loot, mods, trailers, vault level, biome, generation, wreck, save/load with offline time, warnings/bad toasts, every god action) + a state sample every 30 s (FPS, resources, hull, km, wave, enemies, crew, happiness, load, node count). Engine/script errors are captured with a Godot `Logger` (`OS.add_logger`). The last 400 entries persist across reloads (`localStorage` key `mobile_vault_trace_v1` / `user://trace.json`) and every entry is also printed to the browser console as `[trace] …`.
- Remote: player logs go to Supabase `public.logs` (§4i "Player logs", MV-116) when the player allows it; watch them in the Supabase dashboard.

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
  world/room_ambience.gd      lamp light pools + flicker, per-room micro animation, cab engine bay gauges (MV-167)
  world/pet_actor.gd          roaming pets
  autoload/haul.gd            weight / engine capacity / speed / fuel burn
  autoload/modes.gd           game modes: mode / difficulty / mutators of a run (Game.s.mode)
  autoload/engine_bay.gd      engine in the cab: types, drive modes, heat / auto-rest, wear, jobs, noise
  autoload/synergy.gd         room adjacency rules
  autoload/dev.gd             tester switches + god actions (hidden unlock)
  autoload/trace.gd           local event trace, state sampler, error capture, export
  autoload/telemetry.gd       player logs: Trace entries to Supabase public.logs in batches (opt-out, MV-116)
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
tools/pixellab.py             redraws single atlas sprites with the PixelLab API -> tools/art/pixellab/overrides/
tools/autotest.gd             smoke test (excluded from export)
tools/ci_autotest.sh          runs the autotest like CI does (xvfb, fails on FAIL / SCRIPT ERROR / hang)
tools/test_error_spike.sh     tests the error spike alerts (script + SQL on a throwaway PostgreSQL, MV-171)
tools/balance.gd              4-hour headless balance bot (`godot --headless --path . -- --balance --minutes=240`)
```

## 6. Notes on choices vs. the brief

- **ParallaxBackground / ParallaxLayer are deprecated** in the current stable docs ("Use the Parallax2D node instead"), so the background uses **Parallax2D** (`scroll_scale`, `repeat_size`, `repeat_times`, `autoscroll`) — same multi-speed effect, the supported API.
- Web export only supports the **Compatibility renderer (WebGL 2)** per the docs, so the project is set to it everywhere. `WorldEnvironment` glow isn't used; the colour grade is a `CanvasModulate`.
- Particles default to **GPUParticles2D** (docs recommendation). Title screen has a **CPU (ประหยัด)** toggle that switches the same configs to CPUParticles2D for weak phones.
- **Close-up mode** = management mode: the road, travel and random events pause; production and crafting keep running so progress bars stay live.
- Pixel art is crisp: project-wide `default_texture_filter = Nearest`; the atlas means one texture download and batched draws.
- **Touch on mobile web** (v4.6 fix): finger releases are booked in `Main._input`, before the GUI and the modal check, because on the web a finger's index is the browser `Touch.identifier` (never reused on iOS) and a release that hit an open panel used to leave a ghost finger that turned the next swipe into a pinch. Lists scroll by drag because every `MOUSE_FILTER_STOP` control inside a `ScrollContainer` is switched to `MOUSE_FILTER_PASS` (`UIKit.touch_pass`, hooked to `SceneTree.node_added`): [Viewport](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html) stops pointer events at the first STOP control, and `ScrollContainer` drags from the emulated mouse events ([`scroll_deadzone`](https://docs.godotengine.org/en/stable/classes/class_scrollcontainer.html#class-scrollcontainer-property-scroll-deadzone) = 8 via `gui/common/default_scroll_deadzone`). Autotest `--only=touch` feeds real `InputEventScreenTouch/Drag` through `Input.parse_input_event`.
- Portrait is the primary layout (360 px wide terminal UI); landscape moves the tool buttons into a right-hand column.
- **Tutorial + contextual tips (MV-8, MV-150):** a new account gets Sgt. Mark's first-run tutorial (resources, rooms, building, crew, combat, travel; `scripts/autoload/tutorial.gd`). Every other system is taught **the first time its window opens**: a one-time radio card from Sgt. Mark (`TipCard`, `Tutorial.TIPS`) for the map, squad, solar, loot / forge, logbook, garage, skill tree, expeditions, next generation, strangers at the door, engine bay, and the first road event / special encounter. A system that isn't unlocked can't be opened, so it is never taught early; one switched off by its Features switch gets no tip; tips never show over the first-run tutorial. Seen tips are account data (`Game.s.tutorial.tips`), kept across generations. Settings → ตั้งค่า → บทแนะนำ: tips on/off (`tips`) and "show every tip again". Switch `tutorial_tips`. GOD → ระบบ: seen count, reset, show any tip. Autotest `--only=tips`.
- **Languages (MV-151):** Thai is the source; the Thai text in the code is the translation key, English is in `i18n/en.json` (`{"<thai>": "<english>"}`, `""` = not translated, `"@<ctx>:<thai>"` = the same word with another meaning, e.g. `@slot:ว่าง` = Empty vs. `ว่าง` = Idle). `scripts/autoload/loc.gd` (`Loc`) loads it into a `Translation` and sets the `TranslationServer` locale from Settings → ภาษา while the switch `english` is on (off by default until the game data and lore are translated too). Labels / Buttons whose text is a key are translated by Godot itself; text built in code uses `Loc.t("… %d …") % n` (translate the template, then fill it). The fallback locale is `th` (project setting), so anything without English stays Thai. `python tools/i18n.py`: `wrap FILE…` puts `Loc.t()` around Thai literals (skips const / comparison / key lines and lists them), `extract` adds new keys, `check --phase N` lists what is untranslated, `csv` / `import-csv` for review in a spreadsheet. Phases: 1 = UI chrome, settings, tutorial (done), 2 = game data, 3 = lore / chatter / stories. The GOD panel stays Thai. GOD → ระบบ → ภาษา: switch and translated count. Autotest `--only=english`: Thai mode stays Thai, English settings screens have no Thai left, placeholders survive.
- **Thai text** (MV-93): every in-game term, the voice of each character and the spelling rules are in [`docs/glossary_th.md`](docs/glossary_th.md). The player is ผู้บัญชาการ (never "Overseer", the villain AI), crew are ลูกเรือ, biomes use the same name on the map and in the logbook. Autotest `--only=thai` checks that trait / skill / role names stay unique and event buttons stay Thai-only.

## 7. Dev smoke test

```
godot --path . -- --autotest --out=/absolute/output/dir
```
Visits every screen, fires events, fast-forwards 30 min, round-trips the save, rotates to portrait, and writes screenshots.
Add `--only=large` (after `--`) to run just the large-room checks (~30 s), `--only=thai` for the Thai wording checks.

**CI (MV-110):** GitHub Actions workflow **Autotest** (`.github/workflows/autotest.yml`) runs the whole autotest on every PR into `main` and every push to `main`, on Godot 4.7.2-stable (download checked against the release SHA-512, then cached) under `xvfb-run` with the opengl3 driver. The run fails on any `[autotest] FAIL` line, any `SCRIPT ERROR`, a crash before `[autotest] DONE` or a hang (20 min). The autotest itself exits with code 1 when a check failed. Screenshots + `autotest.log` are uploaded as the run's artifact (7 days) and the PASS/FAIL table goes into the job summary. The Discord notify workflow (MV-96) reports each run. Same thing on a Linux machine: `bash tools/ci_autotest.sh [--only=touch]` (env `GODOT`, `OUT`, `TIMEOUT`).
**Docs-only PRs (MV-173):** when every file a PR changes is a `.md` (except `CHANGELOG.md`, which the autotest reads) or under `docs/` / `.claude/`, the job still runs the version check and the error spike tests but skips Godot (about 30 s instead of ~4 min) and reports success, so the required **autotest** check doesn't block the merge. Pushes to `main` and manual runs always run everything. It's done inside the job on purpose: `paths-ignore` would leave a required check stuck on *pending*.
To block merging a red PR: repo **Settings → Rules → Rulesets** (or Branches → branch protection) for `main` → *Require status checks to pass* → add **autotest**.

## 8. Replacing the art

Every PNG is generated by `tools/generate_pixel_art.py` (deterministic): `tools/art/rooms.py` (64×52 room interiors, three per floor), `truck.py` (280×300/356/412 truck shells for 4/5/6 floors, wheels, snow tracks, solar frames, turrets, exterior mod overlays), `landmarks.py` (expedition sites), `chars.py` (dwellers, 20×20 portraits, enemies, bosses), `bg.py` (parallax layers), `events.py` (160×80 illustrations), `encounters.py` (160×80 expedition encounter scenes), `ui.py` (icons, terminal frames). Swap any file for hand-drawn art with the same size (atlas regions are listed in `assets/atlas/atlas.json`). Dweller sheets are 14×20 frames: idle(0-1) walk(2-5) sit(6) work(7-8).

### Micro-asset specs (Codex art analyst → Claude)

Codex CLI (rules in `AGENTS.md`) reads the code, atlas and art style and breaks art work into
**micro assets**: one sprite or short animation each, with size, frames, palette names, parent,
layer, anchor and acceptance checks. `tools/micro_asset.py` validates a spec against the master
palette and `atlas.json`, posts it to Plane (label `micro-asset`), lets Claude `pull` it and
`verify` the built sprite. Format, commands and Codex setup: [`docs/micro-assets.md`](docs/micro-assets.md).

### Redrawing sprites with PixelLab (AI pixel art)

`tools/pixellab.py` asks [PixelLab](https://www.pixellab.ai/pixellab-api) (API v2) for a better version of one atlas sprite. The current sprite is sent as the init image and the master palette as a forced colour set; the answer is snapped back to the exact sprite size and palette with `tools/art/pixelize.py`, so the 16-bit look, the atlas layout and every hardcoded coordinate stay the same.

```
python tools/pixellab.py list room_                        # sprites + sizes, *override marks redrawn ones
python tools/pixellab.py gen room_medical --dry-run        # prompt, payload, cost estimate; nothing sent
python tools/pixellab.py gen room_medical --seeds 3 --yes  # spends credits (~$0.008 per 64x64 call)
python tools/pixellab.py accept room_medical 2025          # candidate -> tools/art/pixellab/overrides/
python tools/generate_pixel_art.py                         # rebuild atlas with the override
python tools/pixellab.py reject room_medical               # back to the drawn sprite
```

- Prompts: `tools/art/pixellab/prompts.json` (shared style + per-prefix templates + per-sprite text). Small sprites are generated at a whole-number scale that meets PixelLab's 32×32 minimum and snapped back down.
- Candidates, the before/after `preview.png` and a `usage.jsonl` cost log go to `tools/art/pixellab/candidates/` (git-ignored). Only accepted overrides are committed.
- `common.add()` uses `overrides/<sprite>.png` when the size matches; `MV_NO_OVERRIDES=1` builds the drawn set.
- Token: env `PIXELLAB_API_KEY` or `.pixellab-api-key` in the repo root (git-ignored). In the claude.ai cloud environment a Network secret for `api.pixellab.ai` adds the `Authorization: Bearer` header, so no key is needed there.
- Not for `dw_*` dweller strips (20-frame animation sheets) or sprites over 400 px; those need PixelLab's character/animation endpoints.

Fonts: Chakra Petch & Silkscreen — SIL Open Font License (see `assets/fonts/OFL_*.txt`).

## 9. Deploy (GitHub + Vercel)

`web/` holds the ready-to-serve Web export (Godot 4.7.2, single-threaded, so no COOP/COEP headers are needed). `vercel.json` tells Vercel to skip the build step and serve `web/` as static files with the right `application/wasm` header.

1. Push this folder to a GitHub repository.
2. On vercel.com → **Add New → Project → Import** the repository → keep the defaults (Framework: Other) → **Deploy**. Every push to the main branch redeploys automatically.
3. After changing the game, re-export into `web/`: `godot --headless --path . --export-release "Web" web/index.html`, commit, push.

### Environments: staging / UAT / production (MV-112)

Branches `staging` (internal test) → `uat` (open test) → `main` (production) are promoted by PR with merge commits; feature PRs go into `staging`, hotfixes into `main` and back down. Each branch deploys its own Vercel URL. **One build serves every environment**: `BuildInfo.env()` reads the page's host name against `config/environments.json` (exact production hosts → `prod`, Vercel `*-git-uat-*` / `*-git-staging-*` → `uat` / `staging`, anything else incl. PR previews, desktop and the editor → `dev`), so promotions never re-export and staging config can't leak into production.

| | prod | uat / staging / dev |
|---|---|---|
| Supabase (`cloud_config.json` → `projects`) | `prod` | `test` (shared, free plan) |
| Remote config | `web/features.json` | `web/features.<env>.json`, else `web/features.json` |
| Badge (switch `env_badge`) | none | **UAT / STAGING / DEV SERVER** on the title + About, `ENV` row in About, `env` in the trace session start |

An old flat `cloud_config.json` holds production keys and is used **only in prod**; elsewhere the cloud stays off until the `test` project is configured (`Cloud.pick_config`). Setup step by step (Thai): `docs/environments.md`. Autotest `--only=env`.

### Versioning & releases (MV-111)

`BuildInfo.GAME_VERSION` is [semver](https://semver.org/spec/v2.0.0.html): `MAJOR.MINOR.PATCH` plus a pre-release tag for the test channel, `-alpha.N` → `-beta.N` → `-rc.N` → stable. Numbering continues from the old two-part versions (4.6 → `4.7.0-alpha.1`). The channel comes from the tag: the title screen and Settings › About show an **ALPHA TEST** / **BETA TEST** / **RC TEST** badge (switch `channel_badge`, nothing on a stable release) and About has a `CHANNEL` row; `BuildInfo.ver_cmp` (also used by the remote `min_game`/`max_game` gate) sorts `4.7.0-alpha.2 < 4.7.0-alpha.10 < 4.7.0-beta.1 < 4.7.0`.

| Step | Command |
|---|---|
| Collect merged PRs since the last `v*` tag into `CHANGELOG.md` `[Unreleased]` | `python tools/release.py changelog` |
| Bump (also updates `tools/web_shell.html` and dates the changelog section) | `python tools/release.py bump alpha` (next alpha), `beta`, `rc`, `stable`, `patch`, `minor`, `major` or an exact `4.8.0-beta.1` |
| Check version, shell line and changelog agree (CI runs this in Autotest) | `python tools/release.py check` |
| Print one version's notes | `python tools/release.py notes 4.7.0-alpha.1` |

Release flow: bump in the feature/release PR (edit the generated `CHANGELOG.md` lines into Added / Changed / Fixed), re-export, merge. Then **Actions → Release → Run workflow** on `main` (or push the tag `v<version>`): `.github/workflows/release.yml` checks the tag matches `GAME_VERSION`, tags `main`, and publishes a GitHub Release titled `Apocarlypse: Mobile Vault v<version>` with that changelog section + GitHub's generated PR list, marked **pre-release** for alpha/beta/rc, with the committed `web/` build attached as a zip. A version can be released once; bump before the next one. The game is **alpha** until the persistent account (MV-159) and P1 beta-ready items land; the switch to beta is `release.py bump beta` (→ `4.8.0-beta.1`).

### Discord notifications (PRs + CI/CD)

`.github/workflows/discord-notify.yml` posts to a Discord channel when a PR is opened, reopened, ready for review, asked for review, reviewed (approve / changes requested / comment) or merged/closed, when Vercel finishes a Preview or Production deploy (success or failure, with the link; Vercel reports it as the `Vercel` commit status), and when a CI workflow listed under `workflow_run` finishes. The message text is built by `.github/scripts/discord-notify.sh` (bash + jq + curl, test locally with `DRY_RUN=1`).

1. Discord: channel → ⚙️ **Edit Channel → Integrations → Webhooks → New Webhook** → **Copy Webhook URL**.
2. GitHub: repo **Settings → Secrets and variables → Actions → New repository secret**, name `DISCORD_WEBHOOK_URL`, paste the URL. Never commit the URL.
3. Test: **Actions → Discord notify → Run workflow**.
4. Optional: repository variable `SKIP_PREVIEW_SUCCESS` = `true` mutes successful Preview deploys (failures and Production still post).

When you add a CI workflow (autotest, web export), put its `name:` in the `workflow_run.workflows` list so its result is posted too.

### Error spike alerts (player logs → Discord #alerts, MV-171)

`.github/workflows/error-spike.yml` runs every 15 minutes (GitHub may start it a few minutes late) and asks Supabase `public.log_alert_check()` (`supabase/migrations/0005_log_alerts.sql`) about the player errors in `public.logs` (§4i "Player logs"). It posts to Discord when:

- **🚨 Error พุ่ง (spike):** in the last `ERROR_SPIKE_WINDOW_MIN` (60) minutes there were at least `ERROR_SPIKE_MIN_ERRORS` (20) errors from at least `ERROR_SPIKE_MIN_PLAYERS` (2) players, and at least `ERROR_SPIKE_RATIO` (3) × the usual amount (average per window over the `ERROR_SPIKE_BASELINE_HOURS` (24) hours before). Lists the top errors, the usual rate and the game versions hit. Not posted again for `ERROR_SPIKE_COOLDOWN_MIN` (60) minutes.
- **🆕 Error ใหม่ (new error):** an error message that never appeared in the `ERROR_SPIKE_NEW_DAYS` (7) days before (numbers are folded to `#`, so a different line number or id is the same error). Each one is posted once. `ERROR_SPIKE_NEW_ALERTS=false` turns these off.

Only kinds `ERROR_SPIKE_KINDS` (`error,script,shader`) count: warnings and the GOD "ส่ง error ทดสอบ" errors (kind `test`) don't, unless a manual run ticks **include_test**. All `ERROR_SPIKE_*` are optional repository variables; empty = the default in brackets. `ERROR_SPIKE_MENTION` (e.g. `<@&role id>`) pings a role with each alert. What was posted is kept in `public.log_alerts` (`truncate public.log_alerts;` forgets it).

Alerts go to their own channel, not the PR/CI feed: a production problem must not drown in PR messages, and the channel can have its own notification setting (all messages + a role ping) while the busy dev feed stays muted. Without `DISCORD_ALERTS_WEBHOOK_URL` they fall back to `DISCORD_WEBHOOK_URL`. Discord notify reports the Error spike workflow only when it fails (successful runs, manual ones too, stay out of the dev feed). The **dry_run** box only prints the message in the run log (`Dry run: not sent`); leave it off to really post.

Setup:
1. Supabase → SQL Editor: run `supabase/migrations/0005_log_alerts.sql` once (after 0004).
2. Discord: create a channel (e.g. `#alerts`) → **Edit Channel → Integrations → Webhooks → New Webhook** → copy the URL.
3. GitHub → **Settings → Secrets and variables → Actions**: secrets `DISCORD_ALERTS_WEBHOOK_URL` (step 2) and `SUPABASE_SERVICE_KEY` (Supabase → Project Settings → API Keys → a **secret** key `sb_secret_…`, or the legacy `service_role` key); variable `SUPABASE_URL` = `https://<ref>.supabase.co`. The secret key bypasses row level security: never put it in the game, `cloud_config.json` or a commit.
4. Test: **Actions → Error spike → Run workflow** with mode `test` (sample alert, shows which channel it lands in), then mode `check` + **include_test** after pressing "ส่ง error ทดสอบ" in GOD → ระบบ a few times (lower `ERROR_SPIKE_MIN_ERRORS` / `ERROR_SPIKE_MIN_PLAYERS` to 1 for that test, or expect only the 🆕 message).

Tests: `bash tools/test_error_spike.sh` (script with saved answers + the SQL on a throwaway local PostgreSQL), also run by the Autotest workflow. Local dry run: `DRY_RUN=1 CHECK_JSON=tools/tests/error_spike_check.json bash .github/scripts/error-spike.sh`. GitHub pauses scheduled workflows after 60 days without commits in the repo: re-enable it in the Actions tab if that happens.

### Link preview (Open Graph / Twitter card)

### Boot / loading screen

The loading page is the Web preset's **custom HTML shell** (`html/custom_html_shell` = `res://tools/web_shell.html`, [docs](https://docs.godotengine.org/en/stable/tutorials/platform/web/customizing_html5_shell.html)): the rusted-steel Apocarlypse card with `web/logo.png` (a copy of `assets/ui/logo.png`, committed because Godot doesn't export it), a progress bar fed by `Engine.startGame({onProgress})`, a pixel driving scene (the Mobile Vault crossing the desert, walkers shot by the roof turret; tap to fire, kill counter) drawn on a 240×112 canvas from `web/boot/*.png` (made by `python3 tools/boot_art.py` from the atlas and the desert backdrop, committed; rerun after art regen), flavour lines on the status label, and one random gameplay tip every 6 s from `TIPS`. No patch notes on this page during the test phase (autotest checks). The scene stops when the game starts and honours `prefers-reduced-motion`. Godot fills `$GODOT_URL`, `$GODOT_CONFIG`, `$GODOT_HEAD_INCLUDE` (the share tags below) and `$GODOT_THREADS_ENABLED`. Edit the tips in `TIPS`; the `v<version>` line is bumped together with `BuildInfo.GAME_VERSION` by `tools/release.py` (autotest and CI check it).

The claude.ai playable artifact is built from the same export, so both show the same page: `python3 tools/artifact_html.py --out build/artifact` gzips `index.wasm`/`index.pck` to `engine.wasm`/`pack.wasm` (the artifact host caps files at 15 MB) and puts a fetch shim where the shell has `<!--BOOT_SHIM-->`. Publish `build/artifact/index.html` with the other files in that folder.

Shared links show a title, a Thai/English description and a 1200×630 pixel-art card. The tags are in the Web preset's **`html/head_include`** (Project → Export → Web → HTML → Head Include; [docs](https://docs.godotengine.org/en/stable/classes/class_editorexportplatformweb.html#class-editorexportplatformweb-property-html-head-include)), so every export writes them into `index.html`. The favicon comes from `html/export_icon` (the project icon).

- Image: `web/og-image.png`, made from the game art by `python3 tools/og_image.py` (rerun after regenerating art). Godot does not export it, so it stays committed in `web/`.
- Crawlers need an **absolute** URL: `og:url`, `og:image`, `twitter:image` and `canonical` point at `https://apocarlypse-mobile-vault.vercel.app/`. If the production domain changes, update those four in `html/head_include` and re-export (the autotest checks the image URL is absolute https).
- Check with the [Facebook Sharing Debugger](https://developers.facebook.com/tools/debug/) (press **Scrape Again** after a deploy, since Facebook/LINE cache previews), [opengraph.xyz](https://www.opengraph.xyz/) or by pasting the link into a LINE / Discord / X draft.
