# Changelog

All notable changes to **Apocarlypse: Mobile Vault**. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versions: [Semantic Versioning](https://semver.org/spec/v2.0.0.html) with a pre-release tag for the
test channel (`-alpha.N` → `-beta.N` → `-rc.N` → stable). The version lives in
`BuildInfo.GAME_VERSION`; `python tools/release.py` bumps it, fills `[Unreleased]` from merged PRs
and dates the section. Each `v<version>` tag gets a GitHub Release with this section as its notes.

## [Unreleased]

### Added
- Exterior mods: worn steel, welds, straps and readable upgrade details across every vehicle, with small cloth/shock movements, roof-turret recoil, contact grit and rain runoff (MV-565).
- Finer exterior mod art: the ram, roof turret, fuel drums, snow tracks, armour plates, solar hoods, lead skirt, rain funnel, shocks and heater chimney now show rivets, welds, chipped paint and rust (MV-566).
- Squad: the AUTO button is now "Auto-assign crew" (จัดคนอัตโนมัติ): it puts the crew whose stats best fit each slot into the squad, skipping anyone away, sick or badly hurt (MV-561).
- Vehicles grow taller with the Mobile Vault: the van starts with 2 floors, the bus 3, the rig 4 and the armoured train 5, and Vault Lv.2 / 4 / 6 each add a floor up to 5. The upgrade card shows the new floor on the vehicle before you buy it (MV-563).
- The Build menu and the build list of an empty room slot say what each room does (food, water, healing, defence...) (MV-557).
- New sounds: getting resources, a road event won or lost, and the expedition moments (team heads out, finds something, comes home, fails, unpacks the haul) (MV-555).
- World map (test builds): clearer, calmer ground with region borders and name plates, and each region dotted with its own landmarks: factories, dunes and glass, forests, swamp pools and shacks, snowy pines, city towers (MV-556).
- Salvage several gear items at once: tick them in the stash and confirm once (MV-554).
- Auto Equip for one survivor in Crew details and Squad / roof-reserve cards (MV-547).
- World map (test builds): random blueprint caches appear on the map one at a time; drive there to get a blueprint you don't own yet (a supply crate once you have them all), also while you are away (MV-546)

### Changed
- Next Generation brings every survivor with full levels, XP, skills and all equipment (worn, stash, vehicle gear and mods); obsolete crew/level research is refunded (MV-559).
- Clearer sound: fixed the hiss and crackle (most of all on the web), and reworked rain, storm, sandstorm, snow, fog, acid rain, ashfall, overcast and thunder (MV-555).
- Road-event fights and stat checks now grow gently with biome, laps and Vault upgrades, with bounded risks, matching resource rewards and visible stat-check targets/odds (MV-553).
- Checkpoint Warlords and their summons now scale with ordinary gear, have much less HP/damage and bounded hits, letting armed squads keep progressing without boss wipes (MV-550).
- Item details in the loot window show stats as a table with icons, +/- against the equipped item, and what a swap would lose (MV-552).
- Industrial Ruins now uses twenty approved native pixel-art panels: pale broken skyline, rusted factories, roadside wrecks, thin smog and cracked asphalt, with smoke and lamp effects anchored to the new scenery (MV-548)

- Every-10th-wave bosses have one-third less HP and damage; their special hull hits now respect vehicle armor and each hit is limited to 12% of maximum hull, helping prevent boss wins from turning into a scrap-draining repair bill (MV-544)
- Upgrading the Mobile Vault frame always does something now: +15 max hull and +5 % production per level, and when your vehicle has no space for the room a level unlocks, you get +10 % production instead until a bigger vehicle can use it. The upgrade card shows the real number of rooms and tells you which vehicle to switch to when this one is full (MV-545)

### Fixed
- The announcement background now matches the NEWS / UPDATE tag height and shows HUD resources faintly through its 70% opaque background while keeping text fully opaque (MV-564).
- Web: no sound at all after the sound update; the game is audible again (MV-560).

## [4.7.0-alpha.4] - 2026-10-27

### Merged pull requests
- MV-499: release 4.7.0-alpha.3 (web export with the Cloudflare hosts) ([#109](https://github.com/maxexq/mobile-vault/pull/109))
- MV-497: trait tiers by value (benefits) and severity (trade-offs) ([#112](https://github.com/maxexq/mobile-vault/pull/112))
- MV-516: weight trait rolls by tier (rarer high-tier traits) ([#113](https://github.com/maxexq/mobile-vault/pull/113))
- MV-517: bigger monsters - whole-number size per enemy kind (normal x2 / elite x3 / boss x3) ([#114](https://github.com/maxexq/mobile-vault/pull/114))
- MV-518: crew stats easy to read (base STR/AGI/INT vs what gear adds) ([#115](https://github.com/maxexq/mobile-vault/pull/115))
- MV-462: cozy roof art (water tank, dish, planters, rest deck) ([#116](https://github.com/maxexq/mobile-vault/pull/116))
- MV-129 (MV-500 phase 1): seeded world map generation + save + GOD ([#117](https://github.com/maxexq/mobile-vault/pull/117))
- MV-130 (MV-500 phase 2): drive the seeded world map ([#118](https://github.com/maxexq/mobile-vault/pull/118))
- MV-519: Viktor drives every vehicle + cab micro animation (MV-520..523) ([#119](https://github.com/maxexq/mobile-vault/pull/119))
- MV-514 (MV-500 phase 4): migrate old saves onto the world map ([#120](https://github.com/maxexq/mobile-vault/pull/120))
- MV-528 (MV-529..535): van-reference hardware fittings on every vehicle ([#122](https://github.com/maxexq/mobile-vault/pull/122))
- MV-524..526: main-stat icons (STR fist, INT lightbulb, AGI zigzag) ([#123](https://github.com/maxexq/mobile-vault/pull/123))
- MV-536: sound: biome ambience, weather layers, gameplay effects ([#124](https://github.com/maxexq/mobile-vault/pull/124))
- MV-536: softer sound, new acid rain / swamp swarm, lo-fi title BGM, web loop fix ([#125](https://github.com/maxexq/mobile-vault/pull/125))
- MV-515 + MV-501..513 (MV-500 phase 3): world map screen and its art (supersedes #121) ([#126](https://github.com/maxexq/mobile-vault/pull/126))
- MV-537: windows stay still when their content changes height ([#127](https://github.com/maxexq/mobile-vault/pull/127))
- MV-538: stuck acid-rain preview fixed, cozy lo-fi biome ambience ([#129](https://github.com/maxexq/mobile-vault/pull/129))
- MV-541: fairer hull repair (size curve, 25 % repair, crew discount, free regen shown) ([#132](https://github.com/maxexq/mobile-vault/pull/132))
- MV-540: render Chakra Petch UI text smoothly ([#131](https://github.com/maxexq/mobile-vault/pull/131))
- MV-543: Forge synthesis spends components ([#133](https://github.com/maxexq/mobile-vault/pull/133))
- MV-542: vehicle stuck after coming back; map stops tappable after continuing a save ([#135](https://github.com/maxexq/mobile-vault/pull/135))
- MV-539: Glass Desert wide parallax panorama ([#134](https://github.com/maxexq/mobile-vault/pull/134))

### Fixed
- Forge synthesis now spends components instead of scrap; affordability and Thai/English cost descriptions match the components icon (MV-543)
- On the world map you can tap stops again after continuing a saved game (the map was drawn but its stops didn't respond until a new world was made) (MV-542)
- Coming back to the game after the vehicle reached its map destination while you were away no longer leaves it stuck: the away summary says it arrived, the go button turns into a map button that opens the map to pick the next stop, and tapping STOPPED (or go) tells you why the vehicle isn't moving (MV-542)
- Windows no longer slide around when what's inside them changes: the title and the button you just tapped stay where they are, and the room close-up keeps the room still when you switch tabs, so nothing moves under your finger (MV-537)
- Acid rain could be heard on the first map without any acid rain, after a weather sound had been previewed in the tester panel (MV-538)

### Added
- The game has sound: every area has its own ambience (factory wind and clanks, desert wind with glass chimes, forest crickets and crows, swamp frogs, icy wind, a dead city's radio) over the engine's rumble, and the weather is heard too, from calm rain on the metal roof to thunderstorms, sandstorms, snow, fog, acid rain and ashfall. Fights, bosses, building, loot, road events, expeditions and buttons have sound effects. The title screen plays a cozy lo-fi theme. Settings has volume sliders for music, ambience, effects and buttons; on the web sound starts after your first tap. High, sharp sounds were softened so nothing stings your ears (MV-536)

### Changed
- The Glass Desert now has a wide pixel-art panorama: pale mesas and satellite dishes, ruined pylons and aircraft, cold blue blast-glass, dusty roadside wrecks and sand-blown asphalt. Five layers scroll independently beneath a sky that follows the game clock (MV-539)
- Every area's background sound is softer and cozier, with a lo-fi, retro warmth: a quiet chord in the background, dusty vinyl and gentle tape wobble, and no sharp highs, while each area keeps its own character (factory knocks, desert glass chimes, forest crickets and creek, swamp frogs, icy wind, the dead city radio) (MV-538)
- New icons for the three main stats so they are told apart at a glance: STR is a fist, INT a lightbulb, AGI a zigzag (MV-524..526)
- Every vehicle got small hardware details in the first van's style: bolted pillar joints, roof seam caps, fuel caps, and a door handle, vent, latch or hinges per vehicle (MV-528)
- Viktor now drives: every vehicle's cab shows him at the wheel with a dash, seat and little lamp, and now and then he blinks, the dash light flickers or he nudges the wheel (MV-519)
- Crew stats are easier to read: STR, AGI and INT always in that order and colour, a bar with one segment per point, each person's best stat boxed in gold (with the rooms it suits), and a separate green line for what their equipment adds (MV-518)
- Monsters look bigger and more threatening: normal monsters ×2, elites ×3, bosses and checkpoint warlords ×3, still in crisp whole pixels (MV-517)
- A cozier roof: a strapped teal water tank with a level gauge, a clearer satellite dish, herb planter trays, and a timber rest deck with a patched canvas, a bench and blanket, a glass windbreak, a water can and a little lamp (MV-462)
- Crew trait cards now show how valuable a trait is: Common, Uncommon, Rare, Epic or Legendary, with a light that grows with the tier (Architect and Lucky are Legendary). Downsides glow harder the more they hurt, with Fears the Dark the harshest (MV-497)
- Valuable traits are rarer now: a new survivor is far more likely to bring a Common or Uncommon trait, and only about 1 in 35 brings a Legendary one (Architect or Lucky). Survivors you already have keep their traits, and downsides are as common as before (MV-516)
- Hull repairs are fairer on big vehicles: the bigger your hull, the less each point costs (a train pays about a third less than before, the van the same), you can patch up 25 % at a time instead of paying for a full repair, and crew in the engine room or a workshop, Mechanics, the Handyman skill and the Repair Bay knock up to 40 % off. The build menu and the hull bar now show how fast the crew repairs the hull for free (MV-541)
- In-game Chakra Petch UI text now renders smoothly at the screen resolution for clearer Thai and English menus. Silkscreen tags and world pixel art retain their crisp pixel edges; a player anti-aliasing setting will come later (MV-540)

## [4.7.0-alpha.3] - 2026-10-26

### Merged pull requests
- MV-275: refine all 92 native game icons ([#74](https://github.com/maxexq/mobile-vault/pull/74))
- MV-189: approved V2 scene art (23 events, 6 encounters, 7 interiors, 13 landmarks) ([#75](https://github.com/maxexq/mobile-vault/pull/75))
- MV-247: raw food (crops + meat) and sensible recipe inputs ([#76](https://github.com/maxexq/mobile-vault/pull/76))
- MV-369: industrial map: wide parallax, game-clock sky, sun/moon and pixel ambience ([#77](https://github.com/maxexq/mobile-vault/pull/77))
- MV-378: checkpoint boss no longer respawns forever after a save load ([#78](https://github.com/maxexq/mobile-vault/pull/78))
- MV-47: loot pity - guaranteed Epic+ / Legendary+ after bad luck ([#79](https://github.com/maxexq/mobile-vault/pull/79))
- MV-387: boss / warlord / elite entrance animation and effects ([#80](https://github.com/maxexq/mobile-vault/pull/80))
- MV-388: vehicle detail phase 1 - wheels, shell wear, leaf springs ([#81](https://github.com/maxexq/mobile-vault/pull/81))
- MV-388: vehicle detail phase 3 - flag, chain, mudflap, exhaust puffs, roof drip ([#83](https://github.com/maxexq/mobile-vault/pull/83))
- MV-388: vehicle detail phase 4 - environment micro sprites (art only) ([#84](https://github.com/maxexq/mobile-vault/pull/84))
- MV-419: engine panel park-to-rest works on a cool engine ([#85](https://github.com/maxexq/mobile-vault/pull/85))
- MV-420: block demolishing living quarters when the crew would outnumber the beds ([#86](https://github.com/maxexq/mobile-vault/pull/86))
- MV-418: improve button skins while preserving existing UI ([#87](https://github.com/maxexq/mobile-vault/pull/87))
- MV-421: document the live branching strategy (staging / uat / main) ([#88](https://github.com/maxexq/mobile-vault/pull/88))
- MV-423: GameAnalytics dashboards via the Collection API (keep Supabase logs) ([#90](https://github.com/maxexq/mobile-vault/pull/90))
- MV-424: shared server outbox (backoff with jitter on 429/5xx) ([#91](https://github.com/maxexq/mobile-vault/pull/91))
- MV-425: staging cloud: build with prod + test Supabase projects ([#92](https://github.com/maxexq/mobile-vault/pull/92))
- MV-426: signing function's 403 says what the deployment sees ([#94](https://github.com/maxexq/mobile-vault/pull/94))
- MV-422: confirm destructive player actions before applying them ([#95](https://github.com/maxexq/mobile-vault/pull/95))
- MV-243: no "speed up and flee" while the vehicle can't move ([#96](https://github.com/maxexq/mobile-vault/pull/96))
- MV-427: situational speech bubbles for fights, exploring and travel ([#97](https://github.com/maxexq/mobile-vault/pull/97))
- MV-244: a stranger flags the vehicle down; it pulls over before the door opens ([#98](https://github.com/maxexq/mobile-vault/pull/98))
- MV-429: room expansion foundation + permanent room art-style reference ([#99](https://github.com/maxexq/mobile-vault/pull/99))
- MV-430: Salvagers' Saloon room (shared supper, bonds, steam) ([#100](https://github.com/maxexq/mobile-vault/pull/100))
- MV-250: clear hull warning before the vehicle breaks down ([#101](https://github.com/maxexq/mobile-vault/pull/101))
- MV-127: morale stages (Depressed, Broken, leaving) and talk action ([#102](https://github.com/maxexq/mobile-vault/pull/102))
- MV-266: responsive layout for phones, tablets, laptops and large screens ([#103](https://github.com/maxexq/mobile-vault/pull/103))
- MV-113: hold 60 fps on busy vehicles, 30/60/120 fps setting ([#104](https://github.com/maxexq/mobile-vault/pull/104))
- MV-482: windows fit their content height; room close-up shows the whole room ([#105](https://github.com/maxexq/mobile-vault/pull/105))
- MV-473: approved steel equipment slots and animated rarity light ([#106](https://github.com/maxexq/mobile-vault/pull/106))
- MV-483: compact trait cards with positive / trade-off light ([#107](https://github.com/maxexq/mobile-vault/pull/107))
- MV-499: Cloudflare Pages hosting alongside Vercel ([#108](https://github.com/maxexq/mobile-vault/pull/108))

### Added
- Crew morale has stages now: a Depressed survivor works slower, a Broken one sits crying in the quarters and won't take orders, and if nobody helps they slip away from the vehicle at night (they no longer steal on the way out). Open a survivor's dossier and have a friend talk them up; the Salvagers' Saloon supper helps the Depressed too (MV-127)
- A clear warning before the vehicle breaks down: at 50 %, 25 % and 10 % hull you get a message saying what happens next and a light screen shake; from 25 % the phone buzzes, a red frame pulses round the screen and a strip offers a one-tap repair. The hull bar now drops with every hit and blinks when it's critical (MV-250)
- New room: the Salvagers' Saloon (Vault Lv.2). Seat one or two crew for a shared supper (8 food, 4 water): they take a break from work, come back happier and closer, and have a little chat afterwards. Steam rises from a cup while they eat (MV-430)
- Confirmation windows explain what will be lost before room demolition, construction cancellation, gear salvage/synthesis, save replacement/reset and other irreversible actions (MV-422).
- The crew now speaks up when things happen: raid warnings, a boss showing up, someone badly hurt, a kill, the van taking hits, the expedition team leaving and coming back, a new area, finished rooms; the main characters say it in their own voice, and bubbles no longer cover each other (MV-427)

### Changed
- Equipment slots are riveted worn-steel frames now, and gear glows by rarity: a quiet silver rim for Common, a green pulse, cyan motes, violet highlights, amber embers and a crimson double-beat with sparks for Mythic. Empty slots show a grey silhouette of what goes there (MV-473)
- Crew traits show as compact cards in the dossier: icon, name and the real effect; a downside trait is marked with a warning and shows its cost in red while keeping its upside (MV-483)
- Smoother play: the game does its economy maths 20 times a second instead of on every frame and much more cheaply, so busy vehicles hold 60 FPS, and Settings now offers 30 / 60 / 120 FPS (120 on high-refresh screens) (MV-113)
- Windows are as tall as what they show (no empty space at the bottom) and grow or shrink smoothly when their content changes. Zooming into a room now shows the whole room with nothing on top of it, centred on phones above the room panel (MV-482)
- Anonymous play statistics (maps reached, rooms built, events, play time) now also go to GameAnalytics so we can see how the game is played; the privacy notice and the Settings switch cover it, and turning it off stops both (MV-423)
- Buttons use worn painted-steel faces with small fasteners and matching hover, pressed and disabled states; existing windows, layouts, fonts and hit areas stay the same (MV-418)
- The vehicle moves a little even when parked: the roof flag waves, a rear chain sways, a mudflap flutters in the wind, the exhaust puffs instead of smoking non-stop (electric and fusion engines stay clean), and rain drips off the roof (MV-388)
- The engine room comes alive: a turning cooling fan, a quivering coolant hose, detailed engine castings, and wisps of steam when the engine runs hot (MV-388)
- More detailed vehicles: new tyre tread and rims on road, off-road and rail wheels, chipped and rusty pillars, weld patches, fuel-tank straps, a caged front lamp, riveted train bogies and leaf springs over the wheels (MV-388)
- Bosses make an entrance: they drop in with a dust burst and a roar, a WARNING band shows the checkpoint warlord's name, and elites flash gold when they appear (MV-387)
- Bad-luck protection for gear: after 40 drops without an Epic or better, the next one is guaranteed Epic+, and after 150 without a Legendary the next is Legendary+. The gear tab shows how close you are (MV-47)
- The industrial map has a wider layered background, dithered sky colours driven by game time, moving sun and moon, subtle chimney smoke, drifting dust and small amber lights (MV-369)
- Food is now grown and hunted: hydroponics grows crops, mutated animals drop meat, and the kitchen cooks crops or meat with water into meals (it stops when they run out). Medicine, biofuel and other recipes use sensible ingredients instead of scrap (MV-247)
- New artwork for every road event, expedition encounter, expedition interior and landmark (49 images), in the same dark 16-bit style with the crew and the truck as you know them (MV-189)

### Fixed
- Windows fit every screen: the build menu no longer slides off to the right on wide screens, no window can run past a screen edge, the room close-up never covers the room on narrow laptops, and tablets / smaller laptop windows get a readable 2× interface instead of tiny 1× (MV-266)
- A stranger who turns up while you drive now flags the vehicle down: it pulls over and the door window opens; let them in, turn them away, or "drive past" and leave them by the road (MV-244)
- You can no longer "speed up and flee" from wolves or bugs while the vehicle can't move (waiting for the expedition team, out of power, broken hull, engine resting, parked); the button says why, the crew fights instead when time runs out, and with nobody aboard they lock the doors and brace. The stray dog's "drive away" is now "leave it be" (MV-243)
- The engine room's "park to rest" button works again when the engine is already cool; it now holds until you tap "set off again" (MV-419)
- You can no longer tear down (or split) living quarters when your crew would end up with fewer beds than people; the button says how many beds would be left (MV-420)
- Beating the checkpoint boss at the end of a map now opens the road to the next map; after reloading the game it used to respawn forever. Saves stuck at a checkpoint are repaired on load (MV-378)

## [4.7.0-alpha.2] - 2026-10-24

### Merged pull requests
- MV-164: web reload goes straight back into the game ([#46](https://github.com/maxexq/mobile-vault/pull/46))
- MV-166: redraw all other rooms with PixelLab ([#47](https://github.com/maxexq/mobile-vault/pull/47))
- MV-159: persistent account (save v2), no rules picker, difficulty setting ([#48](https://github.com/maxexq/mobile-vault/pull/48))
- MV-167: room lighting + micro animation ([#49](https://github.com/maxexq/mobile-vault/pull/49))
- MV-168: Codex art analyst writes micro-asset tickets for Claude ([#50](https://github.com/maxexq/mobile-vault/pull/50))
- MV-146: ladder shaft no longer cuts through merged rooms ([#51](https://github.com/maxexq/mobile-vault/pull/51))
- MV-115: short public player id (Settings, save, trace, SQL lookup) ([#52](https://github.com/maxexq/mobile-vault/pull/52))
- MV-116: player logs to Supabase (batched, offline queue, privacy opt-out) ([#53](https://github.com/maxexq/mobile-vault/pull/53))
- MV-171: post player error spikes from cloud logs to Discord #alerts ([#54](https://github.com/maxexq/mobile-vault/pull/54))
- MV-171: keep manual Error spike runs out of the dev feed, clearer dry run ([#55](https://github.com/maxexq/mobile-vault/pull/55))
- MV-148: portrait phones zoom the vehicle to fill the screen ([#56](https://github.com/maxexq/mobile-vault/pull/56))
- MV-173: skip the Godot autotest run on docs-only PRs ([#57](https://github.com/maxexq/mobile-vault/pull/57))
- MV-148: pinch / mouse wheel can zoom back to auto ([#58](https://github.com/maxexq/mobile-vault/pull/58))
- MV-174: anti-cheat F0 + F1 (server time cap, rate limit, shadow flags) ([#59](https://github.com/maxexq/mobile-vault/pull/59))
- MV-112: staging / UAT / production environments (one build, env from host) ([#60](https://github.com/maxexq/mobile-vault/pull/60))
- MV-151 (1/3): English for menus, settings and tutorial + i18n system ([#61](https://github.com/maxexq/mobile-vault/pull/61))
- MV-172: make the flaky autotest checks deterministic ([#62](https://github.com/maxexq/mobile-vault/pull/62))
- MV-40: Features switch engine_bay (off = stock diesel, nothing simulated) ([#63](https://github.com/maxexq/mobile-vault/pull/63))
- MV-175: half-strength screen shake, same size on phone and PC ([#64](https://github.com/maxexq/mobile-vault/pull/64))
- MV-176: halve engine rumble + Vehicle shake setting ([#65](https://github.com/maxexq/mobile-vault/pull/65))
- MV-150: Sgt. Mark explains each system the first time it opens ([#66](https://github.com/maxexq/mobile-vault/pull/66))
- MV-134: quick-time road events (clock by danger, crew decides on time-out, idle-safe) ([#67](https://github.com/maxexq/mobile-vault/pull/67))
- MV-170: 20 named crew variants + matching portraits (crew_roster_20) ([#68](https://github.com/maxexq/mobile-vault/pull/68))
- MV-178: approved creature redesigns (3 pets, 3 enemies, 3 bosses, 24 frames) ([#69](https://github.com/maxexq/mobile-vault/pull/69))
- MV-188: Announcement marquee strip + new-version notice ([#70](https://github.com/maxexq/mobile-vault/pull/70))
- MV-188: first announcement in web/features.json ([#71](https://github.com/maxexq/mobile-vault/pull/71))
- MV-188: announcements can repeat every repeat_hours ([#72](https://github.com/maxexq/mobile-vault/pull/72))

### Added
- News strip at the top of the screen: announcements scroll across 3 times, and players already in the game are told when a new version is live (tap the strip to save and reload); a message can come back every few hours (MV-188)
- 20 new named survivors can join the crew, each with their own look, animations and portrait: 15 originals and 5 guest cameos (MV-170)
- Sgt. Mark explains each system the first time you open it (map, squad, solar, loot, garage, skills, expeditions, strangers, engine bay and more); turn tips off or see them again in Settings (MV-150)
- Road events have a clock (about 5–30 seconds by danger); if you don't choose in time the crew takes the safe option. The clock waits while you're away; Settings can double it or turn it off (MV-134)
- English, part 1: menus, settings, panels and the tutorial (testers only for now; the game's content follows) (MV-151)
- Rooms come alive: ceiling lamps cast a soft light that flickers now and then, plus small animations in every room (pot steam, tank bubbles, ECG, radio LEDs, gauges, furnace fire, turning wheel) and in the cab engine bay (MV-167)
- Player ID: a short id (like `0G3SQ-MSKUU`) in Settings → Save with a copy button, to quote when reporting a problem; it stays the same on every device and after linking Gmail (MV-115)
- Play logs are sent to the game's server with your player ID to help fix bugs and balance the game; a one-time notice explains it and Settings → Privacy turns it off (MV-116)

### Changed
- Refined all 92 resource, equipment, weather and action icons with clearer native-pixel silhouettes, material edges and useful detail; their meanings and UI sizes are unchanged (MV-275)
- Redrawn creatures: the pets Khao Tang, Som Jeed and two-headed Khai Dao, the Rad-Wolf, Acid Spitter and Bone Brute, and the Alpha Rad-Wolf, Junk Golem and Scorpion King warlords (MV-178)
- Screen shake is half as strong, the same size on phones as on PC, and the boss bar now follows the screen-shake setting (MV-175)
- The vehicle's engine rumble and road bumps are half as strong (they made some players dizzy), and Settings → Feel has a new Vehicle shake switch to turn them off (MV-176)
- Test servers (staging / UAT) keep their own saves and logs, apart from the real game, and show a STAGING / UAT SERVER tag on the title screen (MV-112)
- Medical room redrawn with PixelLab (first AI-assisted sprite, snapped to the 16-bit palette) (MV-162)
- All other rooms redrawn with PixelLab: quarters, kitchen, hydroponics, water, armory, science, radio, engine, refinery, workshop, empty (MV-166)
- One persistent survivor per account (save v2): no rules picker at the start any more, a Difficulty setting in Settings instead (MV-159)
- Reloading the web page goes straight back into your game instead of the title screen (MV-164)
- Portrait phones: the auto camera zooms the vehicle in to fill the screen width instead of showing the whole convoy small under a big sky; swipe to see the trailers, boss fights still pull back. Swiping follows your finger at every zoom (MV-148)

### Security
- Offline progress can no longer be stretched by editing the save time: once the game reaches the server it counts only the time since the server last received your save; the server also flags impossible progress for later leaderboards (MV-174)

### Fixed
- Adopting several pets at once no longer drops one of them from the vehicle (MV-178)
- The ladder shaft no longer cuts through a knocked-through large room; a steel post marks the old wall instead (MV-146)

## [4.7.0-alpha.1] - 2026-10-24

First tagged release. The game is in **alpha**: systems still change and saves may be reset.

### Added
- Semver versioning, release channel badge (ALPHA / BETA / RC) on the title screen and in
  Settings › About, `CHANGELOG.md`, `tools/release.py` and the GitHub Release workflow (MV-111)
- Game modes: rules picker on NEW RUN, peaceful, difficulty, mutators ([#21](https://github.com/maxexq/mobile-vault/pull/21))
- Cloud accounts: Guest or Google login, link guest → Google ([#23](https://github.com/maxexq/mobile-vault/pull/23), [#24](https://github.com/maxexq/mobile-vault/pull/24))
- Feature switches, per-event config and remote `features.json` ([#20](https://github.com/maxexq/mobile-vault/pull/20))
- Link preview (Open Graph + Twitter card) with a pixel-art share image ([#19](https://github.com/maxexq/mobile-vault/pull/19))
- Apocarlypse boot card on the web build: driving scene + gameplay tips while loading ([#38](https://github.com/maxexq/mobile-vault/pull/38))

### Changed
- Game renamed to **Apocarlypse: Mobile Vault** ([#22](https://github.com/maxexq/mobile-vault/pull/22))
- Natural Thai + clean English text, glossary, context-fitting outcome stamps ([#34](https://github.com/maxexq/mobile-vault/pull/34))

### Fixed
- Mobile touch: finger scroll in lists, swipe pan, pinch zoom flipping ([#27](https://github.com/maxexq/mobile-vault/pull/27))

### Tooling
- Autotest on GitHub Actions for every PR ([#37](https://github.com/maxexq/mobile-vault/pull/37))
- Discord notifications for PRs, CI and Vercel deploys ([#36](https://github.com/maxexq/mobile-vault/pull/36), [#39](https://github.com/maxexq/mobile-vault/pull/39))
- `CLAUDE.md` + `tools/plane.py` for the Claude Code CLI; CLI opens PRs with `gh` ([#33](https://github.com/maxexq/mobile-vault/pull/33), [#35](https://github.com/maxexq/mobile-vault/pull/35))
- LangGraph assistant and local agent team with web UI ([#25](https://github.com/maxexq/mobile-vault/pull/25), [#26](https://github.com/maxexq/mobile-vault/pull/26), [#28](https://github.com/maxexq/mobile-vault/pull/28), [#29](https://github.com/maxexq/mobile-vault/pull/29), [#30](https://github.com/maxexq/mobile-vault/pull/30), [#31](https://github.com/maxexq/mobile-vault/pull/31))

## [4.6] - 2026-10-23

Versions up to 4.6 used a two-part number and were not tagged.

### Added
- Engine bay: walk-in engine room in the cab + engine menu ([#18](https://github.com/maxexq/mobile-vault/pull/18))
- Roof rest deck: reserve defender on the roof ([#14](https://github.com/maxexq/mobile-vault/pull/14), [#17](https://github.com/maxexq/mobile-vault/pull/17))
- Large rooms: knock 2–3 same-type rooms through into one ([#13](https://github.com/maxexq/mobile-vault/pull/13))
- Threat pacing: enemies raid when drawn in, not non-stop (v4.5) ([#15](https://github.com/maxexq/mobile-vault/pull/15))
- GOD MODE covers every recent system ([#12](https://github.com/maxexq/mobile-vault/pull/12))
- Strangers at the door: inspect rare high-stat strangers before they board (v4.4) ([#9](https://github.com/maxexq/mobile-vault/pull/9))
- Cloud save on Supabase: anonymous accounts, local-first sync ([#8](https://github.com/maxexq/mobile-vault/pull/8))

### Fixed
- Event choices fit on screen, livelier event, radio and expedition outcome screens ([#11](https://github.com/maxexq/mobile-vault/pull/11), [#16](https://github.com/maxexq/mobile-vault/pull/16))
- Item window tabs could not be tapped after opening the items/forge tab ([#10](https://github.com/maxexq/mobile-vault/pull/10))

## [4.3] and earlier

Construction time + builders (4.3), vehicle ladder, synergy, weight, morale and mutants (4.x),
builds, hazards, mods, expeditions and prestige (3.x). See README §4.
