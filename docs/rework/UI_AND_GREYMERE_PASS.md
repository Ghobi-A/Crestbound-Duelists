# 720p interface system and Greymere rendering rebuild

Baseline: the 1280x720 migration in `RESOLUTION_MIGRATION.md`. The battle
presentation established there is the quality floor; this pass brings the
interface and the overworld up to it.

**No image generation was available in this environment.** That is a hard
constraint on the outcome, and it shapes what this pass is. Rather than
mass-producing procedural pixel art to fill the gap, the work went into
the rendering and composition architecture — layering, depth, occlusion,
lighting, shadows, terrain treatment, atmosphere, interaction
presentation and the interface system. Section 7 specifies the artwork
that a later multimodal pass should author, and every slot it names is
already wired: dropping the assets in requires no code change.

---

## 1. Visual direction established

**Artwork is the subject; the interface is glass laid over it.** The old
interface was a set of opaque boxes bolted under the picture, which is
what an opaque fill on a 320x180 canvas forced. At 720p the artwork is
worth seeing, so panels became translucent gradient surfaces with a soft
cast shadow, a hairline edge, and the role accent confined to a single
lit rule along the top edge.

**Accent means something.** Gold is the player's own agency, violet is
what an action affects, slate recedes. Confining the accent to one rule
per panel — rather than a full accent border on every box — is what stops
the interface reading as a stack of frames.

**Portraits break their container.** On the party cards and in dialogue
the portrait crosses the panel's top edge, so the character reads as the
subject and the panel as the surface behind them. This is now the
signature move of the interface and it appears in both places.

**Greymere is composited, not painted.** Depth comes from ordered bands —
ground, terrain treatment, decals, shadows, y-sorted actors, foreground,
light, atmosphere — not from more detailed tiles. That ordering is the
part that no amount of new art would have supplied on its own.

**Restraint.** No bloom, no glowing rectangles, no oversized chrome. The
mist is a low-amplitude additive wash; the light pools are warm and
local; ornament is two corner ticks per panel.

---

## 2. UI architecture changes

### One surface, every screen

`UiStyle` gained surface tokens (`SURFACE_TOP/BOTTOM`,
`SURFACE_RAISED_*`, `EDGE`, `SHADOW`, a `SPACE_*` scale) and three
primitives every screen now draws through:

| Primitive | Use |
| --- | --- |
| `draw_panel` | The standard framed surface, with role accent |
| `draw_surface` | Gradient body with no accent — cards, HUD bands |
| `draw_scrim` | Vertical fade behind text sitting over artwork |

Because `UiPanel` and the custom-drawn battle widgets both route through
`UiStyle`, modernising `draw_panel` restyled boot, party setup, dialogue,
onboarding, the action menu, the target panel and the round preview in
one change. `test_every_screen_draws_through_the_shared_surface` pins
that they keep doing so.

`draw_selection_band` became a wash that fades away from an accent tick,
rather than a flat indigo block.

### Battle HUD

- The Hollow Court plate now fills the whole canvas. The HUD floats over
  real artwork instead of over a flat slate bar. Combatant staging still
  uses `BATTLE_HEIGHT`, so the composition is unchanged and the 70/30
  split holds.
- The header and message strip became fading scrims; only the HUD band
  itself stays near-opaque, because it carries the densest text.
- **Party cards were rebuilt.** Portrait in a cut-out breaking the top
  edge, HP as the largest type on the card, the name spanning the full
  width beneath, status as coloured pips rather than a row of words, and
  bars tying the two columns together. The card measures every band from
  its own `size`, so it does not know what resolution it is on.
- The acting unit is marked by a lighter surface and a gold top rule
  rather than another border.

### Dialogue

Portrait enlarged to 168x195 and raised to cross the panel's top edge;
speaker name in bright gold at heading size; the continue prompt is now a
drawn, bobbing chevron. It had been typeset as `▼`, which the bitmap face
has no glyph for and which rendered as a tofu box showing its own
codepoint — a defect only visible by looking at the screen.

### Boot

The menu frame is derived from the menu band and pitch and now fits the
number of options actually shown; sized for the maximum four, it left a
dead band whenever the save-dependent "Continue" row was absent.

### Typography

The 8px face is retained deliberately — it is Crestbound's identity, and
a foreign scalable face would not belong. Hierarchy now comes from the
`Typography` scale (16/24/32/48, all whole multiples of the native size),
colour, weight of surface, and spacing, rather than from one
undifferentiated size everywhere. A true 16px-native bitmap face is
specified in section 7 as the next typographic step.

---

## 3. Greymere rendering changes

### Compositing bands

`EnvironmentLayers` names the order everything renders in. Props, NPCs
and the player deliberately share `ACTORS`, because Godot y-sorts *within*
a z_index — a prop on its own band would stop sorting against the player
and characters would walk through it.

### Depth

- **Contact shadows** on every character and prop
  (`OverworldDepth.attach`), anchored at the foot point y-sorting already
  uses, so no per-asset tuning is needed and it works for both the
  high-resolution cast and the 20x30 townsfolk. This is the single
  clearest reason characters no longer look pasted onto the map.
- Per-prop ground footprints, because a tree's trunk meets the ground
  over a much narrower span than its canopy.
- Props are centred on their cell rather than pinned to its left edge.

### Terrain treatment

`terrain_treatment.gdshader` adds broad damp patches, worn ground and a
moonlight gradient over the tile layer. The signal it supplies is
*lower-frequency than a tile*, which is precisely why no tile set could
supply it: a field of grass tiles reads flat because it repeats one 16px
cell with no variation above that scale. Everything is a function of
world position, so it neither shimmers when the camera moves nor differs
between capture runs.

### Lighting

Lit windows and doors now cast warm spill onto the ground, and lantern
pools were rescaled for 720p. Houses read as occupied rather than as
painted facades.

### Atmosphere

`atmosphere.gdshader` provides drifting mist as a single scrolling noise
field with a soft vertical envelope, plus deterministic motes. An earlier
version drew mist as translucent rectangles and put hard horizontal seams
across the town — the edge of a mist band is exactly the thing that must
not be visible.

### Interaction presentation

The gold diamond outline read as a debug annotation because it was drawn
at full contrast whether or not it was relevant. It is now a two-state
Crest spark: dim and gently bobbing at rest, brightening and steadying
with a closing ring when the player faces it. Focus is derived from
`_player.tile + _player.facing` — the same expression `_try_interact`
acts on — so the prompt cannot highlight something the button would not
activate.

---

## 4. Assets generated or replaced

**None.** No image generation was available, and nothing existing was
replaced. Two procedural additions were made in code because they are
rendering behaviour rather than artwork: `terrain_treatment.gdshader` and
`atmosphere.gdshader`.

## 5. Assets deliberately retained

Inspected at native resolution before deciding, per the lesson from the
previous pass:

| Asset | Why retained |
| --- | --- |
| `rework/*.png` cast atlases (1536x1024) | Production-worthy; now shown near authored size |
| `rework/hollow_court.png` (1672x941) | Production-worthy; now fills the canvas |
| `tiles/greymere_atlas.png` | Competent authored 16px pixel art with working autotiling. Its ceiling is detail density, not correctness — replacing it procedurally would not have improved it |
| `tiles/greymere_props.png` | As above |
| `tiles/vignette.png`, `glow.png` | Smooth falloff ramps; correct at any size, now scaled and filtered appropriately |
| `ui/crestbound_font.fnt` | The game's typographic identity |
| `ui/icons.png` | Consistent with the typeface at 4x integer scale |
| Townsfolk sheets and portraits | Authored, coherent; their ceiling is source resolution |

---

## 6. Gameplay invariants verified

Nothing in this pass touches rules, and the following were checked
explicitly:

- **Collision and topology unchanged.** `MAP`, `BLOCKING_TILES`, spawn
  tiles, NPC tiles, triggers and exits are byte-identical.
  `_validate_decor` still enforces that props may only stand on tiles
  that already block, so dressing the town cannot change where the player
  walks — and no props were added to walkable ground.
- **Interaction locations unchanged.** `INDICATOR_TILES` and
  `_try_interact` are untouched; only the marker's appearance changed.
- **Combat, story, saves, controls, class mechanics** untouched.
- Runtime smoke: facing, foot anchors, portrait bounds, team halves,
  combatants staying out of the HUD, dialogue pagination, party setup,
  victory and defeat — **0 failures**.

---

## 7. Remaining visual debt, and what a multimodal art pass should author

These are the items whose quality ceiling is set by missing artwork
rather than by code. Each slot below is already wired.

| # | Gap | Specification | Slot |
| --- | --- | --- | --- |
| 1 | **Greymere terrain density** | A 64px-per-tile terrain set matching the existing `tiles_manifest.json` names: 6 grass variants with clumps/blades/flowers, 16-mask path with cobble and rut detail, 16-mask water with shore foam. | `assets/tiles/greymere_atlas.png` + `art_tile_size` in the manifest. `MapRenderer` needs the tileset's `texture_region_size` raised and the layer scaled by `TILE / art_tile_size`; cell coordinates are unaffected, so gameplay is untouched. |
| 2 | **Architecture** | Buildings currently span 4x2 tiles from 5 wall/roof parts, so every house looks alike. Author distinct structures: varied roof pitch, chimneys, timber framing, foundations, shutters, porch detail. | `roof_*`, `house_*`, `door` in the same manifest |
| 3 | **Prop vocabulary** | Only 6 props exist (tree x2, lamp, barrel, crate, well, fence). The brief's carts, signs, benches, tools, firewood, market stalls and vegetation clusters have no art. Note the real constraint: props may only stand on blocking tiles, so **new interior props also need new blocked cells**, which is a design decision requiring approval (section 8). | `assets/tiles/greymere_props.png` + `_prop_for` |
| 4 | **Foreground occlusion layer** | `EnvironmentLayers.FOREGROUND` exists and is used by markers, but nothing occludes the player yet — there is no canopy or eaves art to draw there. Author overhanging tree canopies and roof eaves. | `EnvironmentLayers.FOREGROUND` |
| 5 | **Villager portraits** | 86x96 against the main cast's 138x160, so villagers are visibly softer in the same dialogue box. | `assets/portraits/townsfolk/*/neutral.png` |
| 6 | **Townsfolk overworld sprites** | 16-20x30, the chunkiest thing on screen beside the painted cast. Also still one pose per direction, not walk cycles. | `assets/characters/townsfolk/*/overworld.png` |
| 7 | **Cast atlas alpha** | The atlases bake the chroma key into RGB with no alpha channel. The shader keys proportionally and despills, which cut the fringe by ~70%, but a thin dark outline remains and no shader can remove it without eating the Hexbound Adept's violet robes. | Re-export the atlases with a real alpha channel |
| 8 | **A 16px-native bitmap face** | Headings are currently the 8px face at integer multiples. A face authored at 16px would give genuinely different letterforms at heading sizes rather than scaled-up body glyphs. | `tools/generate_font.py` |
| 9 | **Bonded Entities and other encounter backgrounds** | Still the older, smaller art. | `assets/entities/`, `assets/battle/backgrounds/` |
| 10 | **Hollow Court landmark** | Currently one arch tile. Deserves a composed approach — larger structure, its own light, environmental cues leading toward it. | `court_arch` + `assets/landmarks/` |

---

## 8. Requires human art-direction approval

1. **Adding blocked cells to Greymere.** Real prop density needs
   somewhere to put props. The map is currently a large open field ringed
   by trees, and props may only occupy blocking tiles. Adding interior
   blocked cells changes the walkable topology, which this pass was
   explicitly forbidden from doing. Needs a decision on whether Greymere's
   layout may change.
2. **Overworld camera zoom.** `OVERWORLD_ZOOM = 4` reproduces the
   original framing exactly and is the smallest whole zoom that fits the
   24x14 map. A lower zoom would show more town but needs a larger map.
3. **Mist and terrain-treatment strength.** Currently tuned
   conservatively. The values are shader uniforms and trivially
   adjustable.
4. **Status pips versus words** on the party cards. Pips read faster and
   free the card, but drop the literal status names to the tooltip and
   the round plan.

---

## 9. Test results

- Python suite: **257 passed** (9 new contracts).
- Godot static validator: passed (46 scripts, 6 scenes, 38 JSON files).
- Runtime presentation smoke: **0 failures**.
- Rendered capture: 6 targets at 1280x720, no script or shader errors.

New contracts in `tests/test_presentation_layers.py`: band ordering,
props sharing the actor band, named bands over raw z-indices, source-art
smoothing, pixel-art hardness, absence of resurrected 320x180 constants,
shared-surface usage, marker z-band, and marker focus deriving from the
interact tile.

The legacy-constant guard is not hypothetical: the runtime smoke had
carried `position.y < 110` and `position.x < 160` through the resolution
migration and silently stopped checking anything real. That was found by
running the smoke scene, which the previous pass had not done — 41
failures were already present at `HEAD` before this work began, and are
fixed here.

**Known flake:** `check_battle_flow` drives a real battle under
`Engine.time_scale = 50` in a frame-stepped loop and reported
`Unexpected battle result` once in five runs. It is timing sensitivity in
the harness, not a rules change — combat code is untouched — but it
should be made deterministic rather than left to chance.

## 10. Baselines

`docs/visual_refs/` — boot, party setup, overworld, **dialogue** (new
target this pass), battle, battle target. All 1280x720.
