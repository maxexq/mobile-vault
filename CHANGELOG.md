# Changelog

All notable changes to **Apocarlypse: Mobile Vault**. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versions: [Semantic Versioning](https://semver.org/spec/v2.0.0.html) with a pre-release tag for the
test channel (`-alpha.N` → `-beta.N` → `-rc.N` → stable). The version lives in
`BuildInfo.GAME_VERSION`; `python tools/release.py` bumps it, fills `[Unreleased]` from merged PRs
and dates the section. Each `v<version>` tag gets a GitHub Release with this section as its notes.

## [Unreleased]

### Fixed
- The engine room's "park to rest" button works again when the engine is already cool; it now holds until you tap "set off again" (MV-419)

### Changed
- The vehicle moves a little even when parked: the roof flag waves, a rear chain sways, a mudflap flutters in the wind, the exhaust puffs instead of smoking non-stop (electric and fusion engines stay clean), and rain drips off the roof (MV-388)
- The engine room comes alive: a turning cooling fan, a quivering coolant hose, detailed engine castings, and wisps of steam when the engine runs hot (MV-388)
- More detailed vehicles: new tyre tread and rims on road, off-road and rail wheels, chipped and rusty pillars, weld patches, fuel-tank straps, a caged front lamp, riveted train bogies and leaf springs over the wheels (MV-388)
- Bosses make an entrance: they drop in with a dust burst and a roar, a WARNING band shows the checkpoint warlord's name, and elites flash gold when they appear (MV-387)
- Bad-luck protection for gear: after 40 drops without an Epic or better, the next one is guaranteed Epic+, and after 150 without a Legendary the next is Legendary+. The gear tab shows how close you are (MV-47)
- The industrial map has a wider layered background, dithered sky colours driven by game time, moving sun and moon, subtle chimney smoke, drifting dust and small amber lights (MV-369)
- Food is now grown and hunted: hydroponics grows crops, mutated animals drop meat, and the kitchen cooks crops or meat with water into meals (it stops when they run out). Medicine, biofuel and other recipes use sensible ingredients instead of scrap (MV-247)
- New artwork for every road event, expedition encounter, expedition interior and landmark (49 images), in the same dark 16-bit style with the crew and the truck as you know them (MV-189)

### Fixed
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
