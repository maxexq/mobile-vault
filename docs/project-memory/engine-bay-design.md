---
name: engine-bay-design
description: Engine bay in the vehicle cab (engine menu, 8 engine types, heat/wear, noise->threat): implemented in PR #18 (v4.6), how it is wired
metadata:
  type: project
  modified: 2026-10-22T20:32:27.280Z
---

IMPLEMENTED 2026-10-22 in PR maxexq/mobile-vault#18 (branch feat/engine-bay, GAME_VERSION 4.6). Code: autoload EngineBay (scripts/autoload/engine_bay.gd), scripts/ui/engine_panel.gd (hud panel "engine"), scripts/world/cab_view.gd. Cab = Data.CAB_SLOT 99, room data in Game.s.cab, engine state Game.s.engine; ALWAYS use Game.room(slot)/has_room(slot) when a slot may be the cab (s.rooms[99] crashes). Engines never auto-equipped, so tools/balance.gd swaps in faster fitting engines itself. Every new feature touching rooms must handle CAB_SLOT. Rest of this file = the approved design.

Parames asked (2026-10-22) for an engine room in the front cab of every vehicle with a deep engine menu. Page (Thai): https://claude.ai/artifact/HizuW3xbABFf4YGvDTVX5Z (copy /mnt/project-files/designs/engine-bay.html). Read from main 28ff880. Mockup script in session scratch only (draws a 33x30 bay at cab x=3,y=236 on veh_* atlas sprites).
- Engines are the existing `van_gear.engine` item slot (no item = old diesel I4 = today's numbers exactly). 8 types: diesel4, v8 (rusty_v8), turbo6 (diesel_turbo), woodgas, electric, hybrid (diesel-electric), turbine, fusion (fusion_cell). Size S/M/L; van max M, others L.
- Rev 3 (Parames 2026-10-22, final layout): engine room ONLY inside the cab bottom floor (x2..37, y210..261, 36x52), must NOT take body cells. New Data.CAB_SLOT outside the 3-per-floor grid, cap 2 crew (auto-cool +15%/person >95C, else repair +0.3%/min x STR/5, mechanic x1.4); tap opens engine menu. Migration: old slot-0 engine room level+crew move to cab room, slot 0 becomes empty/buildable (+1 room). Rev 4: room shaped per cab (Data.VEHICLES[tier].cab_room): van 31x58 @(2,204) I4; bus 32x46 @(2,216) I6, lower windshield shortened to y194-214 with driver moved up; rig 33x41 @(2,222) turbo under the cab-over; train 35x66 @(3,196) yellow diesel-electric genset + catwalk, riveted frame. Mock script cab_room2.py (scratch only). Redraw front_* in tools/art/vehicles.py. Everything else in the page was OK by Parames.
- Heat: dT = P - k(T-amb); P = 6*heat*mode*(0.7+0.5*load)*weather, k = 0.10*(1+0.25*radiator). 95 hot, 110-120 power -30%, 120 forced stop (-5% cond, -5 water). Auto-rest default ON 110->80, forced ON offline.
- Condition/oil wear, breakdowns <35%, offline floor 25%. Drive modes eco/normal/boost (+silent for EV/hybrid). Cold start <5C. Alternator replaces engine room power 5/min.
- Threat hook: replace +0.08/kmh with 0.085*(dB-45) while moving (diesel 78 dB = same 2.8/min). Tow: engine tow_mult replaces item tow in [[modular-chassis-design]] formula.
- Phases: 1 core (2-2.5d), 2 cold start/biomes/swap/upgrades/events (1.5-2d), 3 chassis tie-in.
**How to apply:** don't implement until Parames approves; phase 1 depends on [[threat-director-design]] PR merging for the noise hook. Also [[god-mode]] rule applies.
