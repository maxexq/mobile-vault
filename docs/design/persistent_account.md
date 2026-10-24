# Persistent account + mode events (MV-159)

Follows the MV-114 decision (24 Oct 2026, Parames): one account that keeps growing, no rules picker on
NEW RUN, and Sprint / Weekly / Hardcore become time-limited events whose rewards go back to the account.

Decisions taken for this design (Parames, 24 Oct 2026):

| Question | Decision |
|---|---|
| Next Generation (rebirth) | stays, **inside** the account: the account owns research points, perks, blueprints, vehicle tiers, collection; the vehicle is just the current generation |
| Where events are played | a **separate event vehicle** in its own slot; the main vehicle keeps idling; the slot is deleted when the event ends, rewards go to the account |
| Saves that picked peaceful / a difficulty / mutators | converted to **standard**, nothing lost; difficulty becomes a player setting |
| Map (MV-129) | a **new map per generation** (seed stored in the vehicle); places found and lore stay in the account |

## 1. What lives where

Today the whole save is one `Game.s` dictionary, and only `Game.s.meta` survives a rebirth (`Meta.next_generation`
rebuilds `Game.s` from scratch). Logbook lore, lifetime stats and the GOD MODE `cheated` flag are lost on every rebirth today.

**Account** (lives forever, one per player, cloud-synced):

| Key | From today's save | Notes |
|---|---|---|
| `meta` | `s.meta` (gen, legacy, perks, blueprints, best_km) | moved as is; `Meta.m()` reads the account |
| `lore` | `s.lore` | logbook entries now survive rebirth |
| `memorial` | `s.memorial` | already carried by `next_generation`, now simply account data |
| `seen` | `s.tutorial.done` | becomes `{tutorial: true, <system>: true}` so MV-150 can teach systems unlocked later |
| `places` | new | landmarks / special points ever visited (collection for MV-129); `s.sites_done` stays per vehicle |
| `life` | parts of `s.stats` | lifetime km, kills, generations, events joined; `cheated` moves here |
| `settings.diff` | `s.mode.diff` | easy / normal / hard / nightmare for the **main** vehicle, changeable any time (not ranked) |
| `tree` | new, empty | account skill tree (MV-126): `{points, nodes}` |
| `events` | new | `{<event_id>: {best, claimed, joined_at}}` so a reward is paid once |
| `created_at`, `v` | new | account birth (server time), envelope version |

**Vehicle** (one generation's run): everything else in `Game.s` as today (rooms, dwellers, res, items, km, biome,
lap, combat, mods, engine, squad, gear, exp, sites_done, weather, tod...) plus:

| Key | Notes |
|---|---|
| `mode` | kept, but written by the game, never picked: main = `{id: "standard", diff: <account setting>}`; event vehicle = the event's rules |
| `map_seed` | new, rolled per generation; MV-129 builds the procedural map from it |
| `kind` | `"main"` or `"event"`; `event_id` on event vehicles |

## 2. Save envelope (save v2)

```
{
  "v": 2,
  "account": { ...table above... },
  "main":    { ...vehicle... },
  "event":   { ...vehicle... }          // only while an event vehicle exists
}
```

- At runtime `Game.s` keeps pointing at the **active vehicle** dictionary and a new autoload `Account` holds
  `Account.a` (the `account` dictionary). The ~975 existing `Game.s` references stay unchanged.
  **Built (step 1):** the account keys `meta`, `lore`, `memorial`, `tutorial` (`Account.SHARED`) are put into
  `Game.s` as references to the same objects (`Account.attach`), so `Meta`, `Lore`, `Tutorial` and `Crew` did
  not change; `Account.envelope` stores them once, in the account. `stats.cheated` stays per vehicle (an event
  vehicle needs its own flag for the leaderboard).
- `Save.write` / `Save.read` work on the envelope; `Game.save_game()` writes the envelope, `Game.load_game()`
  unwraps it. Same localStorage key `mobile_vault_save_v1` / `user://savegame.json`, so no new storage keys.
- `Meta.next_generation()` replaces only `envelope.main`; the account is untouched (no more copying `meta` and
  `memorial` around).
- Switching vehicle (main ⇄ event) = save, point `Game.s` at the other dictionary, run its offline catch-up for the
  time it sat in the background (same `_offline_progress`, same cap `Data.OFFLINE_CAP_SEC × Modes.mul("offline")`),
  `game_started.emit()` and `_emit_all(true)`. Only the active vehicle simulates.

### Migration v1 → v2 (in `Game.load_game` before `_migrate`)

A save without `"v"` is v1:

1. `account.meta ← s.meta` (or default), `lore ← s.lore`, `memorial ← s.memorial`,
   `seen.tutorial ← s.tutorial.done`, `life.cheated ← s.stats.cheated`, `life.km ← s.stats.km_total`,
   `settings.diff ← s.mode.diff`, `created_at ← s.mode.started_at` (or now).
2. Those keys are removed from the vehicle; the rest becomes `main`.
3. `main.mode ← {id: "standard", diff: settings.diff, mut: []}`. Peaceful runs become standard (raids come back:
   show a one-time toast "ระบบเปลี่ยนเป็นไอดีถาวร ขบวนของคุณกลับสู่โหมดเอาชีวิตรอด"); mutators are dropped.
   The old mode is kept in `account.legacy_mode` for support.
4. `main.map_seed` rolled, `main.kind = "main"`.

The migration is idempotent and covered by an autotest with a frozen v1 fixture (standard, peaceful + mutators,
generation 3 with perks).

## 3. Cloud save (Supabase)

- One row per user stays; `saves.data` holds the envelope. `Cloud.SCHEMA` goes 1 → 2.
- **Guard against old clients:** a tab still running the old build would read a v2 envelope as "no save" and could
  upload a fresh v1 game over it. Migration `0002_schema_guard.sql` makes `rpc_save` refuse a write whose
  `p_schema` is lower than the stored `schema_version` (returns `{ok: false, reason: "old_client"}`); the old
  client then shows its existing error. The new client also refuses to load v1 data that is *newer* by rev than its
  local v2 save and asks the conflict question as today.
- Conflict picker compares envelopes; the summary line shows main vehicle + generation + research points.
- Size: a second vehicle roughly doubles the payload only while an event runs; still far under the jsonb limit.
- `tools/cloud_fake.gd` gets the same schema guard.

## 4. Modes becomes the event layer

- **Picker removed.** Title screen: first launch = "เริ่มเกม" straight into a standard game; afterwards
  "เล่นต่อ" only. Starting over from zero moves to Settings → เซฟ → "ลบไอดีแล้วเริ่มใหม่" with a typed confirmation.
- `Modes` keeps its data and maths (`mul`, `_calc_features`, `legacy_mult`, peaceful toll/salvage): it reads
  `Game.s.mode` of the **active** vehicle, so an event vehicle just carries different rules. Main vehicle rules
  are always standard + the difficulty setting.
- `Modes.ranked()` = active vehicle is an event vehicle with a ranked event and `account.life.cheated` is false.
  The main vehicle is never ranked.
- **Event definitions** come from remote config (`web/features.json`, new section `mode_events`) so they can be
  opened without an export, using the existing `from` / `to` windows and `Cloud.now()`:

```json
"mode_events": {
  "sprint_w45": {"kind": "sprint", "from": "2026-11-06", "to": "2026-11-12",
    "rules": {"id": "standard", "diff": "hard", "mut": ["horde"]},
    "seed": 4517, "tier": "van", "goal": {"km": 60}, "time_limit_h": 24,
    "rewards": {"legacy": 20, "bp": ["bp_solar_covers"], "title": "sprinter_w45"}}
}
```

- Kinds: `sprint` (reach the goal fastest, time limit), `weekly` (same seed for everyone, best score in the
  window), `hardcore` (one life: a wreck ends it, no offline catch-up beyond the normal cap), and later festival
  events (MV-157). Peaceful and the mutators live on as event rule sets.
- **Lifecycle:** join (event window open, no other event vehicle) → event vehicle built from `seed` / `tier` /
  standard starting crew (not the main crew, so everyone starts equal) → play, switch freely with a HUD button →
  ends at goal / time limit / wreck / window close → score + rewards paid **once** into the account
  (`account.events[id].claimed`) → `envelope.event` deleted.
- **Rewards only go into the account**: research points, blueprints, titles / cosmetics, later skill-tree points.
  No resources are moved into the main vehicle, so events cannot break the main economy.

## 5. Features, GOD MODE, tests (for the build tickets)

- Switch `modes` is renamed `mode_events` (off = no event cards, join refused; an existing event vehicle stays
  playable until it ends). Tunables: `events.catchup_cap_h`, `events.max_active` (1).
- GOD MODE: "สร้างอีเว้นท์ทดสอบ" (local event definition), "จบอีเว้นท์ทันที", "สลับรถ", "จำลองเซฟ v1".
- Autotest groups: `account` (migration fixtures, rebirth keeps lore/seen/life, difficulty setting), `mode_events`
  (join / switch / catch-up / end / reward once / window closed), cloud schema guard in `cloud_fake`.
- Balance bot (`--balance --mode=...`) keeps working: it runs an event-style vehicle with the given rules.

## 6. Build order (proposed tickets)

| # | Ticket | Depends on | Content |
|---|---|---|---|
| 1 | Account + save v2 envelope | – | `Account` autoload, envelope read/write, v1 → v2 migration, `Meta`/`Lore`/`Tutorial`/memorial/`cheated` move to the account, picker removed, difficulty setting, `0002_schema_guard.sql`, `Cloud.SCHEMA = 2` |
| 2 | Event vehicle slot | 1 | second vehicle in the envelope, switch main ⇄ event, background catch-up, HUD switch button, GOD actions |
| 3 | Mode events from remote config | 2 | `mode_events` section, event cards on the title/HUD, join / end / rewards once, `mode_events` switch |
| 4 | Sprint / Weekly / Hardcore | 3, MV-51 | seedable RNG (MV-51), scores, replaces MV-52 (save slots no longer needed) |
| 5 | Leaderboard | 4, MV-50 | reads `Modes.ranked()` of event vehicles only |
| – | MV-126 account skill tree | 1 | uses `account.tree` |
| – | MV-129 procedural map | 1 | uses `main.map_seed` + `account.places` |

Ticket 1 is the risky one (every save goes through it) and ships alone. **Built in MV-159.** The save format
itself is not behind a switch: the v1 → v2 migration is one-way, so an "off" that wrote v1 again would lose
account data. The switch `persistent_account` covers what the player sees (off = NEW RUN is back and starts
over from nothing).

## 7. Open points (small, decide while building)

- Event vehicle starting crew: standard five, or let the player bring 1 veteran from the account? (fairness vs fun)
- Does the main vehicle keep simulating at full rate while an event is in the foreground (two idle games at once),
  or only the normal offline cap? This design uses the offline cap; changing it is one tunable.
- Titles / cosmetics need a small UI (profile card in Settings) that does not exist yet.
