# PixelLab walk integration

Eight flagged facings now use reviewed PixelLab v3 walk frames: Almyra west,
Ferris east/west, Gell west, Kai Assassin west, Kai Warrior west, Liora east,
and Hooded Stranger west. Existing standing poses and all other facings remain.

`tools/walk_sources/*.png` are four-frame 192px RGBA source strips. Their
source art came from the PR #24 production branch. The seven follow-up jobs
are recorded in `provenance.json`; Almyra's separately approved job is
`60b4289b-3575-4816-af54-897def10a755` (seed 42, four frames, three generations).
No credentials are stored in these files.

`python tools/materialize_overworld_v2.py` applies the strips before Godot
import/export. `apply_pixellab_walks.py` preserves standing pose zero and
uses generated frames 0, 1 and 3 for the remaining three slots. It resizes to
the existing cells and retains the magenta-key texture contract. Writes are
validated and replaced atomically. Running it again produces identical atlases.
The committed production PNGs remain the baseline; the build step materializes
the reviewed overlays. Regenerated `authored.json` contains the new foot anchors.

The eight previously flagged side walks now pass the existing display-scale
walk audit. Python regressions and Godot static validation pass locally.
Purple edge contamination from the original reference art remains a separate
cleanup task. Do not globally remove purple: some clothing and effects use it.
