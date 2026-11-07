---
name: room-sample-pages
description: Room Redesign Samples split into one artifact per room (2026-10-29, 256 MiB cap); URLs + how to add a room
metadata:
  type: reference
  modified: 2026-10-29T21:53:13.597Z
---

2026-10-29 Parames picked "split per room" after Room Redesign Samples hit the 256 MiB per-version artifact cap. The old URL is now an INDEX of cards (thumbs/<room>.png 144x96 + link):
- Index: https://claude.ai/artifact/SpjgTwP7hzkvF64zc3Hcww (v35; the old room files are still stored there but no longer referenced)
- Armory (MV-609): https://claude.ai/artifact/XESV26vyRFRtz6abLTqMYz
- Water purifier (MV-607): https://claude.ai/artifact/Eno8e1SBrximF4QZ9uL3YD
- Infirmary (MV-600): https://claude.ai/artifact/Qmvp3dC71buzURAtFSXSAL
- Grow room A/B (MV-598): https://claude.ai/artifact/URzD6bZWTDq48yPsm7TByi
- Living room (MV-597): https://claude.ai/artifact/MdBMgAsB6fmGRw5GLyidsU
- Kitchen + kitchen/living hotspots + first samples: https://claude.ai/artifact/9D4wPWjRU8j9T9PBY7FZEJ
- Empty cell v3 (MV-621): https://claude.ai/artifact/Swa1KdABNEcrBMSSUQkv1P (index v42)
- Empty cell (MV-603): https://claude.ai/artifact/NsyRD8c3u67HVWa6XCZNns
Page sources were built by the split script in the MV-609 thread (same head/CSS as the old page, header with a back link to the index). Read a page with Artifact read before republishing from a new session.
**How to apply:** a new room gets its own artifact (same style) + a card on the index. Copy files between artifacts server-side with files {path: {artifact, path}}; one publish may copy at most 64 MiB, so split big copies over two publishes. Related: [[room-redesign-preview]], [[armory-redesign]].
