# MV-528 van-reference vehicle fittings (MV-529..535)

Sources for the seven fittings baked into every vehicle shell by `tools/art/vehicles.py` (`FITTING_ROWS`, `fittings()`).

- `decal_*.json`: the approved micro-asset specs (exact native pixel rows, palette, hash, placements).
- `decal_*-draft.png`: the native drafts; `vehicles.py` reproduces them pixel for pixel.
- `*-native-proposal.png`, `all-vehicles-detail-proposal.png`, `micro-details-closeup.png`: the review proposal.
- `*-detail-study.png`, `prompts.json`, `build_native_proposal.py`, `proposal-manifest.json`: provenance.
  The studies are context only; the rows in the specs are authoritative.

On the train's cut-away the engine-room frame (riveted column x=38) stays on top of the lowest left pillar joint,
so the room edge is not broken; the closed train shell shows the full joint.
