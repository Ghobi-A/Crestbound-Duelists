# Visual Engineering Audit

Branch `claude/visual-engineering-audit`, stacked on PR #30. All evidence is
in-engine: Godot 4.3 renders captured through `tools/capture_screenshots.sh`
(software GL, 1280x720 and 640x360), plus the new cast line-up scene. Nothing
below is concept art or a mock-up.

## 0. Project state (Phase 0)

| Item | State |
| --- | --- |
| Overworld scale normalisation (`body_height`, `OverworldSprite.body_scale`) | **Merged** in PR #27 |
| Painted Outskirts and Town, battle HUD restyle | **Merged** in PR #28 |
| Painted interiors; townsfolk and trainers re-rendered on Kai's frame | **Merged** in PR #29 |
| Bonded Entity HD art (incl. Glass Mantis), painted route battle ground, title/footer overflow, creek under the bridge | **PR #30: open, CI green, not merged.** This branch is stacked on it and does not redo or overwrite any of that work. |

Sprite data paths inspected:

- `game/assets/overworld/authored.json`: the 4x4 magenta-keyed sheets that the runtime draws for the cast and townsfolk.
- `game/assets/rework/overworld_v2.json`: the 40x56 v2 registry. Shadowed by the authored aliases for everyone except the unused enemies.
- `game/assets/rework/characters.json`: battle records plus the trainers' overworld strips. The `kai_*` and almyra/liora overworld rows are shadowed by the authored sheets.

Tooling inspected: `tools/audit_character_scale.py`, `audit_walk_cycles.py`,
`rerender_overworld_sheets.py`, `build_overworld_metadata.py`,
`build_painted_terrain.py`, `capture_screenshots.sh` and
`scripts/tools/screenshot_capture.gd`, with its 35 targets.

The baseline (before this branch) was captured for all 35 targets. It is
retained in the PR description's evidence, and the before column of every
comparison below comes from it.

## 1. Main-character scale (Phase 1)

### Method

`game/scenes/tools/cast_lineup.tscn` draws 16 overworld characters through
the real `OverworldSprite.attach` path, with feet on one baseline per row. It
renders four rows: all four facings, then the walk phases for east, west and
down. `tools/cast_lineup.py` measures each character's opaque body in that
render, converted to logical (320x180) px. Spear shafts and torch handles
are excluded from the head, and the feet are searched across the whole
column so that a stride doesn't read as a lifted foot. The same scene was
run on the pre-normalisation commit (`506c88c`) for the "original" column.

### Results (logical px, Kai = reference)

| Character | Original height | vs Kai | Turn drift | Walk drift | Now height | vs Kai | Turn drift | Walk drift | Foot drift |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Kai | 23.3 | +0.0 | 0.7 | 1.2 | 23.8 | +0.0 | 0.8 | 1.2 | 0.3 |
| Kai (Guardian) | 23.2 | -0.2 | 0.7 | 0.8 | 23.8 | +0.0 | 0.7 | 0.8 | 0.2 |
| Almyra | 23.7 | +0.3 | 0.5 | 0.7 | 24.0 | +0.2 | 0.5 | 0.7 | 0.2 |
| Liora | 24.0 | +0.7 | 0.7 | 0.7 | 23.8 | +0.0 | 0.5 | 0.7 | 0.2 |
| Joey | 22.5 | -0.8 | 1.5 | 1.7 | 23.8 | +0.0 | 0.2 | 0.5 | 0.2 |
| Lena | 23.5 | +0.2 | 0.8 | 0.8 | 24.0 | +0.2 | 0.2 | 0.3 | 0.2 |
| Senna | 23.5 | +0.2 | 0.8 | 1.2 | 24.0 | +0.2 | 0.0 | 0.3 | 0.0 |
| Silas | 23.3 | +0.0 | 1.0 | 1.2 | 24.0 | +0.2 | 0.2 | 0.5 | 0.0 |
| Gell | 23.5 | +0.2 | 0.5 | 0.8 | 24.0 | +0.2 | 0.2 | 0.3 | 0.0 |
| Danfor | 23.2 | -0.2 | 0.8 | 1.0 | 23.7 | -0.2 | 0.3 | 0.7 | 0.0 |
| Orrin | 22.5 | -0.8 | 3.2 | 3.2 | 23.7 | -0.2 | 1.8 | 1.8 | 0.0 |
| Ferris | 23.7 | +0.3 | 1.0 | 1.2 | 24.0 | +0.2 | 0.3 | 1.0 | 0.0 |
| Stranger | 22.7 | -0.7 | 1.5 | 1.5 | 24.0 | +0.2 | 0.0 | 0.3 | 0.0 |
| Rowan | 21.7 | -1.7 | 0.2 | 0.2 | 23.8 | +0.0 | 0.2 | 0.2 | 0.0 |
| Squire | 21.7 | -1.7 | 0.3 | 0.3 | 23.8 | +0.0 | 0.2 | 0.0 | 0.0 |
| Challenger | 22.0 | -1.3 | 0.5 | 0.2 | 23.8 | +0.0 | 0.2 | 0.2 | 0.0 |

Summary of the three states:

| State | Worst height vs Kai | Worst turn drift | Worst walk drift |
| --- | ---: | ---: | ---: |
| Original, foot-anchor divisor (`506c88c`) | 1.7 px | 3.2 px | 3.2 px |
| After PR #27–#29 | 0.2 px | 2.7 px | 2.7 px |
| This branch | 0.2 px | 1.8 px | 1.8 px |

- **Accepted scale:** confirmed at 24 logical px. Kai renders at 23.8, the
  measurement rounding to whole display pixels. No character differs from
  Kai by more than 0.2 px in the front view, which is below one display
  pixel at 720p.
- **Turn drift fixed:** PixelLab returned each facing of a re-rendered NPC at
  a slightly different scale, so Joey grew 1.5 px when he turned and Danfor
  1.7 px. `rerender_overworld_sheets.match_facings` now scales every facing,
  with its walk frames, uniformly to the front view's body height. Drift for
  re-rendered characters is now at or below Kai's own 0.8 px.
- **Orrin's remaining 1.8 px** is his raised spear tip and helmet crest in
  profile, not body growth: his body is level, as `orrin.png` in the
  line-up shows. Accepted and documented.
- **Feet:** they stay within 0.3 px of the ground line in every facing and
  walk frame for every character, so there's no hopping or sliding.
- **Proportions preserved:** the scale is uniform in X and Y everywhere
  (`Vector2.ONE * factor`), and no sprite was stretched. The current
  characters' width and head-to-body ratios are frozen in
  `tools/character_proportions_baseline.json`. A test fails if any later
  edit stretches, crops or re-renders a sprite without re-baselining it.
  Head-ratio flags on Lena (long hair), Senna (bun) and Orrin (helmet) are
  hair and helmet silhouettes, not anatomy; they're confirmed visually.

Evidence: `docs/visual_audit/cast_scale_facings.jpg`, `cast_scale_walk_east.jpg`
and `cast_scale_walk_west.jpg` (before/after, with Kai's 24 px line in blue and
the ground in red), and `character_scale_table.md`, the source-pixel table from
`audit_character_scale.py --markdown`.

### Tooling added or extended

- `audit_character_scale.py`:
  - `validate()` raises a `ManifestError` naming the bad entry: a missing
    facing, a foot outside its rect, a body height outside its frame, an
    unknown alias or a zero display height.
  - Measures turn and walk drift per sheet.
  - Marks shadowed manifest entries, which the runtime never draws.
  - `--markdown` writes the table, and `--baseline` records the approved
    proportions.
  - Measures battle body heights.
- `tests/test_character_scale.py` checks that:
  - measurement is deterministic;
  - stored `body_height` matches the asset;
  - the runtime helper is uniform and body-based;
  - turning and walking stay within 1.5 px;
  - proportions match the baseline;
  - six kinds of malformed manifest data fail clearly;
  - battle bodies are measured and drawn at one height.
- `tests/test_rerendered_characters.py` checks that every facing matches the
  front view after composition.

## 2. Issue register (Phases 2 and 4)

Severity: **P0** broken presentation · **P1** major inconsistency ·
**P2** professional polish · **P3** future art direction.
Type: code / artwork / design. Complexity: S (hours) · M (a day or two) ·
L (a milestone).

### Fixed on this branch

| ID | Sev | Scene / asset | Problem and why it hurts | Fix (type, complexity) | Validation |
| --- | --- | --- | --- | --- | --- |
| V-01 | P1 | Re-rendered NPCs, all facings | Bodies grew by up to 2.7 px when turning (Joey, Danfor, Orrin, the trainers). Sprites "popping" as they turn reads as broken animation. | The composer scales each facing to the front view's body height (code, S). | Cast line-up: worst drift 2.7 → 1.8 px, the remainder being Orrin's spear. Composer test. |
| V-02 | P1 | Battle: route trainers vs the cast | Battle sprites still used the foot-anchor divisor that PR #27 removed from the overworld. Trainer sheets have more headroom, so Rowan, the Squire and the Challenger stood 36.0–36.9 px against the cast's 38–39, making opponents look like children. | `DuelistSprite.battle_scale` uses the measured `battle_body_height`, with `battle_body_display` = 39 (Kai's existing height) (code, S). | `battle_route_before_after.jpg`. Test asserts measured heights and the formula. |
| V-03 | P1 | All tracked serif labels (encounter titles) | `UiStyle.text_width` measured whole strings with kerning, but tracked text is drawn glyph by glyph, so wide capitals overran. "APPRENTICE ROWAN" ran past its box even after PR #30's fallback. | Measure tracked text glyph by glyph, exactly as it's drawn (code, S). Fixes every tracked label in the game, not just this one. | Title is inside its box in the route battle; Hollow Court, boot and party setup unchanged. |
| V-04 | P2 | Battle: Bonded Entity placement | The 24 px default offset put a companion beside the *next* ally. Formation slots are ~42 px apart, so Almyra's Storm Lion read as Kai's. | 13 px offset, tucked just behind the bearer (code, S). | Route battle: the lion overlaps Almyra's rear, not the gap to Kai. |
| V-05 | P2 | Battle: objective label | "DEFEAT ALL ENEMIES" was dim, thin serif over bright foliage and barely legible (see the before image). | A soft dark plate behind it and full-strength text (code, S). | Before/after comparison. |
| V-06 | P2 | Battle: command-menu banner | The portrait strip showed hair only, so the banner didn't say *who* is acting. | Crop through the eyes (code, S). | Captures. |
| V-07 | P2 | Painted ponds and creek | Shorelines followed the tile grid in straight runs. | Fine domain warp on the water field (code, S). Partial: see V-14. | Captures; water-on-walkable test still passes. |

### Open findings (recommended, not changed here)

| ID | Sev | Scene / asset | Problem and why it hurts | Recommended correction (type, complexity) | Validation method |
| --- | --- | --- | --- | --- | --- |
| V-10 | P1 | Battle vs overworld art direction | Battle sprites are a different art generation from the overworld sheets: smaller-headed and more detailed, with heavier outlines. The cast reads as two sets of characters between exploring and fighting. | Regenerate overworld sheets from the battle art (or the reverse) on one spec; see the roadmap's character spec (artwork, L). | Side-by-side sheet of battle vs overworld per character, with the proportion baseline re-recorded. |
| V-11 | P1 | Battle: no authored attack, hit or defeat frames | Every combat state is a squash, stretch and lean tween on a single still frame. Hits lack anticipation and recovery poses, so impacts feel weightless. | Author three to four key poses per class (wind-up, strike, recoil, down) and keep tweens only for secondary motion (artwork, L). | Frame-by-frame capture of one attack. |
| V-12 | P2 | Battle HUD footer | The "CHOOSE ACTIONS" phase label and the battlefield effect both use faint gold on a dark gradient; they're hard to read at 640x360. | Raise to `TEXT_DIM`, or drop the phase label, which the menu already implies (code, S). | 360p capture. |
| V-13 | P2 | Party setup and formation | Enemy and encounter context is missing: the player picks rows without seeing what they face. | Add an enemy strip to the right panel (design, M). | Capture. |
| V-14 | P2 | Route 01 pond (north edge) | The pond runs straight up into the forest border, and its top rocks are cut by the tilt-shift band, so a hard vertical edge remains. | Feather the forest field into water, or add reed and rock dressing along that border (code/artwork, S). | `route_grass` capture. |
| V-15 | P2 | Town and route NPC idles | NPCs stand perfectly still, which reads as lifeless next to animated water and light. | Add a two-frame breathing idle (PixelLab `breathing-idle` template) on a slow, desynchronised clock (artwork, M). | Capture a short sequence. |
| V-16 | P2 | Interiors | All six rooms share one floor, wall, rug and decor set, so rooms look interchangeable (compare the Joey, Kai and Lena galleries). | Per-room palette and decor tables, e.g. herbs for Lena, ledger shelves for Gell (design/artwork, M). | Gallery. |
| V-17 | P2 | Dialogue box | The portrait well is cropped tight (Joey's head touches the frame) and the box is long and flat, with no speaker-side emphasis. | Add 2 px of portrait inset and a nameplate tab (code, S). | `dialogue_*` captures. |
| V-18 | P2 | Victory and defeat | Static centred cards over a dimmed field: no reward, no pose, no transition beat. | A victory pose plus a rewards line; defeat with a slow fade (design, M). | Captures. |
| V-19 | P2 | Shop and inventory | Monospace body text, wide rows, no item icons or affordability colour. | Icon column; grey out unaffordable lines (code, S–M). | `shop_*` captures. |
| V-20 | P3 | Hollow Court battle background | The painted backdrop is strong, but the combatants stand on its painted floor with no contact shading or reflections on the wet stone. | Add a floor contact-shadow and reflection pass (code, M). | Capture. |
| V-21 | P3 | Town tree canopy | Greymere's blue canopy is iconic but flat-shaded compared with the painted terrain under it. | Two-tone canopy light and wind sway, keeping the blue identity (artwork, M). | Captures. |
| V-22 | P3 | Spell and impact VFX | The effects are serviceable but generic: small sparks, with no screen-space light. | A per-Crest VFX kit with additive light pools on the ground (artwork, L). | Frame captures. |

Verified as **not** an issue:

- Bonded Entity art from PR #30 renders correctly in every battle capture:
  solid, scaled and facing the opponent, with no grey blocks.
- All six interiors, both outdoor maps and every UI screen render without
  missing textures, clipping or colour-key fringes. 35 of 35 targets
  captured with no script errors.
- At 640x360 the smallest UI text is still legible (`dialogue_long`, shop,
  battle).

## 3. Artistic consistency (Phase 2F)

Does it look like one game? **Mostly, with one clear seam.**

- **Coherent:** painted terrain, interiors, lighting and grading share one
  palette (warm sun with cool shade). The UI shares one vocabulary: navy
  glass, gold hairlines, Cinzel and Garamond. The overworld cast now shares
  one scale and one adult proportion system.
- **The seam (V-10):** battle sprites and overworld sprites come from
  different generations, with different outline weights, head ratios and
  detail density. This is the most visible inconsistency left, and the first
  milestone of the roadmap.
- **Pixel density:** overworld sprites (~210–260 source px drawn at 24) and
  terrain textures (256 px over two tiles) both minify cleanly with mipmaps.
  Battle sprites (~450 px drawn at 39) are the densest. The densities don't
  clash, but they should be specified (see the roadmap).
- **Strongest existing standard:** the painted Outskirts with the authored
  overworld cast. The roadmap uses it as the reference.

## 4. Validation (Phase 6)

| Check | Result |
| --- | --- |
| `python -m pytest` | 306 passed |
| `python tools/validate_godot_project.py` | Passed (65 scripts, 17 scenes, 50 JSON files) |
| `python tools/audit_walk_cycles.py` (after `materialize_overworld_v2.py`, as in CI) | No walk-cycle flags |
| `ruff` on changed Python files | Clean |
| Godot 4.3 presentation, world, route and shop smoke tests | 0 failures each |
| Screenshot capture, 35 targets at 1280x720 and 7 at 640x360 | All rendered; reviewed by eye, as above |
| Cast line-up (Godot render), before, after PR #29 and now | Table above |

Limitations:

- **Software GL:** all captures use llvmpipe, which renders correctly but
  says nothing about GPU frame rates.
- **No new web export:** this branch changes no rendering features that
  affect the browser, so the existing web build checks still apply, but I
  didn't re-export it.
- **No new art:** no PixelLab generations were needed. Every fix here is
  scaling, measurement or layout, and the existing art was kept.

Generated captures were written to the scratchpad. The canonical art is
regenerated only by the deterministic tools, and the walk-applied sheets that
the capture step produces are never committed.
