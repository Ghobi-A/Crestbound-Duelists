# Visual references and baselines

This directory holds two different kinds of image, and they must not be
confused.

## 1. Captured baselines (generated — do not hand-edit)

Deterministic renders of the real project, used as the before/after evidence
for each visual phase and as the visual-regression baseline.

| File | Contents |
| --- | --- |
| `baseline_boot.png` | Title screen with the main menu (1280x720) |
| `baseline_party_setup.png` | Pre-battle roster and formation (1280x720) |
| `baseline_overworld.png` | Greymere at the default spawn tile (1280x720) |
| `baseline_battle.png` | Hollow Court, round 1, command menu open (1280x720) |
| `baseline_battle_target.png` | Hollow Court, first move aimed at the first target (1280x720) |

Layout lives on a 320x180 logical canvas, but Godot's `canvas_items` stretch
draws it at the window's integer multiple, so a 1280x720 capture is the game's
own 4x render with HD source art sampled at that size — never an OS-window or
browser grab, and not an enlargement of a 320x180 image.

Regenerate with:

```bash
tools/capture_screenshots.sh                           # 1280x720 into docs/visual_refs/
tools/capture_screenshots.sh /tmp/candidate            # writes elsewhere for comparison
tools/capture_screenshots.sh /tmp/hd 1920x1080         # any integer multiple of 320x180
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

## 2. External art-direction references (supplied manually)

| File | Purpose |
| --- | --- |
| `battle_art_style_reference.png` | Battle scale, opposing formations, grounding, depth layering, attack-effect readability, HUD hierarchy |
| `overworld_art_style_reference.png` | Environmental density, tile variation, terrain transitions, building readability, layering, character-to-environment scale, lighting |

These are third-party commercial screenshots kept purely as quality
benchmarks for the Phase 1 and Phase 3 art passes. They are **not** project
assets: never redistribute them as part of the game, and never copy any pixel
of either into it.

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
