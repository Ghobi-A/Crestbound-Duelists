# Visual references and baselines

This directory holds two different kinds of image, and they must not be
confused.

## 1. Captured baselines (generated — do not hand-edit)

Deterministic renders of the real project, used as the before/after evidence
for each visual phase and as the visual-regression baseline.

| File | Contents |
| --- | --- |
| `baseline_overworld.png` | Greymere at the default spawn tile (320x180, canonical) |
| `baseline_overworld_4x.png` | Same frame, nearest-upscaled to 1280x720 for viewing |
| `baseline_battle.png` | Hollow Court, round 1, command menu open (320x180, canonical) |
| `baseline_battle_4x.png` | Same frame, nearest-upscaled to 1280x720 for viewing |

The 320x180 file is the canonical artifact: it is the internal game viewport
captured at 1:1, never an OS-window or browser grab. The `_4x` copy is derived
from it by nearest-neighbour upscaling, so it adds no information and
introduces no filtering.

Regenerate with:

```bash
tools/capture_screenshots.sh                 # writes into docs/visual_refs/
tools/capture_screenshots.sh /tmp/candidate  # writes elsewhere for comparison
```

Compare a candidate run against the committed baselines:

```bash
python tools/compare_screenshots.py --dir-a docs/visual_refs --dir-b /tmp/candidate
```

### Determinism and tolerance

Capture is deterministic by construction: a pinned Godot build, `--fixed-fps 60`,
frame-counted waits instead of wall-clock timing, `seed(41)`, a canonically
seeded `GameState` (warrior, both onboarding flags set), and scripted `interact`
presses on fixed frame numbers. Repeat runs in one environment are byte-identical.

Byte equality is deliberately **not** the pass condition. Driver, Mesa version
and font rasterisation differences can shift a few pixels between machines, so
`compare_screenshots.py` judges two measures instead:

- mean absolute error <= 1.0 (per channel, 0-255)
- changed-pixel ratio <= 0.002, where a pixel counts as changed if any channel
  differs by more than 8

These pass on identical renders and on the same scene re-rendered by a
different Mesa build, while failing on any real art change.

## 2. External art-direction references (supplied manually — not in git yet)

| Expected file | Purpose |
| --- | --- |
| `battle_composition_reference.png` | Battle scale, opposing formations, grounding, depth layering, attack-effect readability, HUD hierarchy |
| `overworld_composition_reference.png` | Environmental density, tile variation, terrain transitions, building readability, layering, character-to-environment scale, lighting |

**These files are not present.** They were supplied as conversation
attachments and cannot be written to disk from the build environment; no
placeholder images have been fabricated in their place. Add the real images at
these paths before the Phase 1 and Phase 3 art passes.

### Rules for using the references

They inform **visual principles and quality targets only**: scale, density,
composition, grounding, layering, readability and interface hierarchy.

Do not copy characters, enemy designs, sprite poses or animations, tiles or
environmental assets, UI frame shapes, fonts, colour palettes, background
compositions, attack effects, or any identifiable copyrighted artwork.

Every asset shipped in Crestbound Duelists must be original and cleared for
commercial portfolio use, expressed in the game's own identity: dark fantasy,
moonlit ruined stone, desaturated foliage, warm Crest gold, spectral violet
manifestations, strong original silhouettes, restrained dramatic effects, and
a cohesive late-16-bit presentation.
