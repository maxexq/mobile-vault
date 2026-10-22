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

Save data: browser **localStorage** (key `mobile_vault_save_v1`), auto-saved every 15 s and when the tab is hidden/closed. Desktop builds fall back to `user://savegame.json`.

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
| Offline | Like TBH: offline time gives XP + scrap only (no gear). |

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
| ทั่วไป | switches: invincible (hull / crew / squad), one-hit kills, free build/upgrade/buy, resources always full, no random road events · game speed ×1/2/5/10/20 · fast-forward +10 min / +1 h / +4 h (offline simulation) · time of day · any weather · FPS/debug overlay |
| ทรัพยากร | fill / empty everything, set each resource and item, all blueprints, +100 research points |
| รถ | swap chassis van/bus/rig/train in place, 0–2 trailers, Vault Lv 1–6, hull 100/50/10/0 %, build every empty slot, max room levels, all mods max / none, weight readout, short circuit / dead battery, acid, solar damage, radiation, infection |
| ลูกเรือ | recruit, heal, happiness 100/20/0 for everyone, pets, per survivor: +5 levels, force strike, desert now, kill |
| ต่อสู้ | set wave, kill all enemies, heal squad, spawn the biome warlord or any of the 8 mutant bosses, spawn 3 of any mob (mutants highlighted), drop 3 items of any rarity |
| โลก | jump to any biome, go to checkpoint, mark warlord beaten, lap +1, trigger any road event, arrive at any expedition site, finish the current expedition, open the next-generation screen, wreck the vehicle in 3 s |
| LOG/เซฟ | trace viewer with category filter, download JSON / copy / clear; export the save as JSON (copied to the clipboard) and load a pasted save — testers can hand each other exact situations |

Cheat switches are never saved; any god action marks the save `stats.cheated = true` and is written to the trace.

**Data & logging**
- Save: one JSON document (`Game.s`) in browser `localStorage` key `mobile_vault_save_v1` (desktop: `user://savegame.json`), autosaved every 15 s and when the tab is hidden/closed. Nothing leaves the device.
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
  autoload/atlas.gd           texture atlas -> AtlasTexture / SpriteFrames cache
  autoload/lore.gd            logbook entries, crew bios, idle chatter lines
  world/chatter.gd            speech bubbles above survivors
  main.gd                     camera fit, swipe, tap, room close-up zoom + blur, build placement, floating numbers, shake
  world/background.gd         Parallax2D layers per biome (sky, clouds, far, mid, near, road) + cross-fade
  world/vehicle.gd            van / bus / rig / train shells + trailers, exterior shell (X-ray), wheels per tier, mods, pets, dust/mud, smoke, solar tilt frames, headlight, body bob
  world/room_view.gd          room interior, level pips, synergy markers, craft strip, build highlight, night glow, blackout + head-torches
  world/pet_actor.gd          roaming pets
  autoload/haul.gd            weight / engine capacity / speed / fuel burn
  autoload/synergy.gd         room adjacency rules
  autoload/dev.gd             tester switches + god actions (hidden unlock)
  autoload/trace.gd           local event trace, state sampler, error capture, export
  ui/god_panel.gd             GOD MODE console
  ui/expedition_feed.gd       live helmet-cam view of the scavenging squad
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

## 8. Replacing the art

Every PNG is generated by `tools/generate_pixel_art.py` (deterministic): `tools/art/rooms.py` (64×52 room interiors, three per floor), `truck.py` (280×300/356/412 truck shells for 4/5/6 floors, wheels, snow tracks, solar frames, turrets, exterior mod overlays), `landmarks.py` (expedition sites), `chars.py` (dwellers, 20×20 portraits, enemies, bosses), `bg.py` (parallax layers), `events.py` (160×80 illustrations), `ui.py` (icons, terminal frames). Swap any file for hand-drawn art with the same size (atlas regions are listed in `assets/atlas/atlas.json`). Dweller sheets are 14×20 frames: idle(0-1) walk(2-5) sit(6) work(7-8).

Fonts: Chakra Petch & Silkscreen — SIL Open Font License (see `assets/fonts/OFL_*.txt`).

## 9. Deploy (GitHub + Vercel)

`web/` holds the ready-to-serve Web export (Godot 4.7.2, single-threaded, so no COOP/COEP headers are needed). `vercel.json` tells Vercel to skip the build step and serve `web/` as static files with the right `application/wasm` header.

1. Push this folder to a GitHub repository.
2. On vercel.com → **Add New → Project → Import** the repository → keep the defaults (Framework: Other) → **Deploy**. Every push to the main branch redeploys automatically.
3. After changing the game, re-export into `web/`: `godot --headless --path . --export-release "Web" web/index.html`, commit, push.
