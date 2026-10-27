# Industrial Ruins sources

MV-548 supersedes the MV-369 production panorama with the twenty approved native panels in
`source/`. See [source/README.md](source/README.md) for reproduction, exact dimensions and effect anchors.
The older approved-daylight.png remains as a historical style reference.

# MV-369 source artwork

`approved-daylight.png` is the 1,920×240 native daylight strip from Parames's approved wide industrial-background preview. It was generated through the built-in image tool from the room-style reference, industrial neutral preview and sunrise-gradient screenshot, then snapped to the master palette using nearest-neighbour sampling. No PixelLab credits or external API runner were used.

The integration request approved this direction for **one map: industrial**. The original MV-369 generator removed the baked sky and distant background from this input, retains the factory artwork, and deterministically authored separate long skyline, foreground, road, cloud, gradient and micro-effect assets. The other biome generators and all atlas sprites retain their existing inputs.

Sun and moon are independent palette-drawn sprites, not part of the panorama. Runtime placement and sky selection use `Game.s.tod`, with sunrise at 0.25, noon at 0.5, sunset at 0.75 and midnight at 0.0. Animation has a fixed node count, whole-pixel placement and bounded effect counts. Kill switch: `industrial_parallax`.

This source directory is excluded from Godot import and the web pack. Only `assets/bg/industrial_live/` production outputs ship. Regenerate through the normal art pipeline and validate with `python tools/verify_industrial_background.py --regenerate-check`.
