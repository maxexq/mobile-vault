# Changelog

All notable changes to **Apocarlypse: Mobile Vault**. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versions: [Semantic Versioning](https://semver.org/spec/v2.0.0.html) with a pre-release tag for the
test channel (`-alpha.N` → `-beta.N` → `-rc.N` → stable). The version lives in
`BuildInfo.GAME_VERSION`; `python tools/release.py` bumps it, fills `[Unreleased]` from merged PRs
and dates the section. Each `v<version>` tag gets a GitHub Release with this section as its notes.

## [Unreleased]

### Added
- English, part 1: menus, settings, panels and the tutorial (testers only for now; the game's content follows) (MV-151)
- Rooms come alive: ceiling lamps cast a soft light that flickers now and then, plus small animations in every room (pot steam, tank bubbles, ECG, radio LEDs, gauges, furnace fire, turning wheel) and in the cab engine bay (MV-167)
- Player ID: a short id (like `0G3SQ-MSKUU`) in Settings → Save with a copy button, to quote when reporting a problem; it stays the same on every device and after linking Gmail (MV-115)
- Play logs are sent to the game's server with your player ID to help fix bugs and balance the game; a one-time notice explains it and Settings → Privacy turns it off (MV-116)

### Changed
- Screen shake is half as strong, the same size on phones as on PC, and the boss bar now follows the screen-shake setting (MV-175)
- The vehicle's engine rumble and road bumps are half as strong (they made some players dizzy), and Settings → Feel has a new Vehicle shake switch to turn them off (MV-176)
- Test servers (staging / UAT) keep their own saves and logs, apart from the real game, and show a STAGING / UAT SERVER tag on the title screen (MV-112)
- Medical room redrawn with PixelLab (first AI-assisted sprite, snapped to the 16-bit palette) (MV-162)
- All other rooms redrawn with PixelLab: quarters, kitchen, hydroponics, water, armory, science, radio, engine, refinery, workshop, empty (MV-166)
- Portrait phones: the auto camera zooms the vehicle in to fill the screen width instead of showing the whole convoy small under a big sky; swipe to see the trailers, boss fights still pull back. Swiping follows your finger at every zoom (MV-148)

### Security
- Offline progress can no longer be stretched by editing the save time: once the game reaches the server it counts only the time since the server last received your save; the server also flags impossible progress for later leaderboards (MV-174)

### Fixed
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
