---
name: road-train-design
description: MV-672 road train vehicle system design doc (option B Consist builder recommended), awaiting Parames's 5 picks
metadata:
  type: project
---

2026-11-02 Parames asked to study road trains (Wikipedia) and propose a realistic vehicle system. Design only, no code. Claude Doc https://claude.ai/artifact/ArFFZvu2HQcfReC7SX59pX, Plane MV-672 Needs Decision.
- Key fit: v2 room 144 px ~4.2 m (crew 60 px = 1.75 m), so 3 rooms (448 px) ~13 m = one real 13.7 m semi-trailer: 1 trailer = 3 cells.
- Option B: prime mover (cab + engine bay) + 1-4 trailers; couplings B-link (sway 1.10, can reverse), converter dolly (1.45, no reverse), pup drawbar (1.60). Tow tonnes = 0.23 t/hp (engines: woodgas 110, diesel4 150, v8 300, electric 400, hybrid 420, turbo6 480, turbine 650, fusion 800 hp); replaces modular-chassis tow formula. Sway = prod(gain)*(v/80)^2; fuel x(GCM/12)^0.7; braking from NT table x sqrt(GCM/40). Road classes R1 city 1 trailer/B-double, R2 2, R3 3, R4 desert 4; assembly yards park trailers (raid targets). Trailer types box/pup/tanker/stock crate/flatbed/hopper+aux engine.
- Camera: follow one trailer at a time + code-drawn consist strip; phases P0 numbers (no art) .. P4 quad; P2 waits on [[world-v2-scale-plan]].
- Pending picks: strategy, trailer floors (1 recommended), replace tiers with progression, parked trailers raidable, max 4 trailers.
Related: [[modular-chassis-design]], [[engine-bay-design]], [[dr-ren-ambulance]], [[ambulance-drive-anim]], [[threat-director-design]].
- Samples (PixelLab) log: see [[road-train-samples]].
