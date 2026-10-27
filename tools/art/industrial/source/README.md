# Industrial Ruins native source — MV-548

The twenty approved RGB panels are the production art source. Each layer uses the
panel-1 dimensions for all four panels; generic continuation sizes were superseded.
The manifest preserves panel hashes, approved stitched RGB hashes, palette names,
original image-generation provenance, and effect anchors measured on these panels.
Raw image-generation paths in provenance are archival references, not dependencies.

Run `python -m tools.art.industrial_bg` from the repository root with Pillow.
It stitches panels in order, keys only exact magenta to binary transparency, and
preserves all other RGB pixels. No resampling, quantization, network or paid API.
The existing sky and tiny effect sprites remain separately generated in code.
Clouds are the accepted sparse flat smog veils; the factory-scene cloud draft is rejected.

The continuous far/mid/cloud/road masters cross internal panel seams naturally;
their adjacent columns need not be identical. Verify exact reconstruction against
the approved RGB hashes, plus the quiet 4-to-1 wrap profiles. Near panel joins also
use matching quiet profiles. Do not alter accepted pixels to force column equality.

Effect anchors use local native coordinates: mid chimney rims (425,85), (1630,132),
(1646,123); near lamp heads (221,78), (1794,89). Lamps follow near parallax, smoke
follows mid parallax. Native ground rows align at world y=289, road at y=290.
