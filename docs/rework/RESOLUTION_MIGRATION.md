# 320x180 to 1280x720 resolution migration

Baseline for this work: PR #16 (`Fix corrupted party setup text and unblock
rendered QA`). Gameplay, combat resolution, story logic, save format,
controls and art direction are unchanged; this is a rendering and layout
migration only.

The 320x180 canvas was the bottleneck. The character atlases are
1536x1024 and the Hollow Court plate is 1672x941, but a combatant was
drawn 44px tall — a region roughly 460px tall sampled down by about ten
times, discarding ~90% of the authored detail before it reached the
screen. The interface had the matching problem: an 8px bitmap face was
the only type size that fit, so every screen used one undifferentiated
size and copy had to be abbreviated to fit its panel.

---

## 1. Every major 320x180 assumption removed

| Assumption | Was | Now |
| --- | --- | --- |
| Viewport | `viewport_width/height = 320x180` | `1280x720`; window override unchanged |
| Canvas constant | `PresentationLayout.CANVAS = (320, 180)` | `(1280, 720)`, and everything else derives from it |
| Battlefield height | `BATTLE_HEIGHT = 122` (67.8%) | `504` (70.0%), with `HUD_TOP`/`HUD_HEIGHT` derived |
| HUD share | 58 of 180 rows (32.2%) | 216 of 720 (30.0%), and cards take a smaller slice of it |
| Team centres | literals `82` / `238` | `CANVAS.x * 0.256` / `* 0.744` |
| Feet lines | literals `98` / `80` | fractions of `BATTLE_HEIGHT`, so moving the HUD does not drag combatants |
| Formation spread | `minf(42, 94 / (n-1))` | `MAX_SPACING` / `TEAM_SPAN`, pinned to stay on each team's half |
| Combatant height | `display_height: 44` | `176`; the atlas is now sampled at ~0.38 rather than ~0.095 |
| Effect scale | authored 48px sheets drawn 1:1 | `EFFECT_SCALE`, derived from the combatant height change |
| Dialogue panel | `Rect2(8, 126, 304, 50)` | `Rect2(32, 496, 1216, 208)` |
| Dialogue portrait | `34x40` box for a 138x160 crop | `136x160` — very nearly 1:1 with the source |
| HUD panels | literal `Vector2(320, …)` positions and sizes | derived from `hud_rect()`, `PAD`, `GUTTER`, `CONTEXT_PANEL_WIDTH` |
| Party card | fixed `192x54`, portrait `18x22` | sized by the HUD from the party count; all bands measured from the card's own `size` |
| Action menu | `122x56`, rows every 9px, description pinned at y=46 | `420x192`, row pitch from the type scale, description anchored to the panel's bottom |
| Round preview | `200x110`, portraits `16x18` | `680x400`, portraits `69x80`, centred on the battlefield |
| Party setup | three panels at hand-placed offsets | one grid from `MARGIN`/`PAD`/`ROSTER_WIDTH` |
| Boot menu frame | `UiPanel` at `(36,56) 248x98` | derived from `MENU_BAND` and `MENU_PITCH`, so it cannot drift off the rows |
| Overlays | `Vector2(320, 180)` veil/shade/flash | `PresentationLayout.CANVAS` |
| Combat floats | `44x12` label box | sized from the type it carries |
| Chrome strokes | hardcoded `1px` rules | `UiStyle.LINE` |
| UI icons | 7px atlas drawn 1:1 | `UiIcons.DISPLAY_SCALE` (4x, whole-number) |
| Sprite markers | fixed 3/4/5px status marks | scaled from the drawn body |
| Overworld camera | zoom 1 | `OVERWORLD_ZOOM = 4` |
| Screenshot capture | asserted exactly 320x180, wrote a `_4x` upscale | verifies integer scaling at any window; canvas is the delivery size |
| Font sizes | 6, 7, 8, 9, 10, 12, 14 | `Typography`: whole multiples of 8 only |

Text width also stopped being a constraint. Party setup no longer has to
say `ACT`/`RES` or drop "Duelists" from the start row, and the control
hint reads in full again — at body size it measures 963px of a 1168px
footer, where at 320x180 it did not fit even shrunk below the font's
native size.

---

## 2. The new rendering and layout architecture

### One canvas, everything derived

`PresentationLayout` owns `CANVAS` and every region derived from it
(`battlefield_rect()`, `hud_rect()`, the stage geometry, the dialogue
box). Screens position against those, or against their own `size`, and
not against literals. `UnitStatusPanel` is the clearest case: it computes
its portrait box, bar heights and tag band from the card size the HUD
hands it, so it does not know what resolution it is on.

Tests read these constants directly — including the ones written as
arithmetic — through `tests/gdscript_consts.py`, which evaluates a
GDScript `const` block in declaration order. The previous tests scraped
literals with a regex and would have silently stopped checking anything
the moment a constant became an expression.

### Two asset classes, filtered differently

This is the core of the art direction, and conflating the two is what
would either blur the pixel art or stipple the paintings:

- **Pixel art** — authored at final size: the 8px typeface, the 7px icon
  atlas, Greymere's 16px tiles, the ~20x30 townsfolk.
  `PresentationLayout.use_pixel_art_filter()` (nearest), scaled only by
  whole numbers. `snap_2d_transforms_to_pixel` remains on.
- **Source art** — painted at high resolution and sampled down: the
  1536x1024 cast atlases, the 1672x941 Hollow Court plate.
  `use_source_art_filter()` (linear). Nearest at a non-integer ratio
  drops texels unevenly and stipples these into noise.

### Typography

`Typography` defines the scale: `CAPTION` 16, `BODY` 24, `HEADING` 32,
`DISPLAY` 48 — all whole multiples of the 8px native face, because a
bitmap glyph survives only integral rescaling. Below native, whole pixel
rows vanish (party setup once rendered `ACTIVE` as `NCTIVE`); at a
fractional multiple, stems land on uneven pixel counts and one letter's
strokes differ in weight from the next.
`test_all_ui_text_uses_whole_multiples_of_the_bitmap_font` enforces this
across all three routes a size reaches the renderer: a theme override, a
size forwarded through a label helper, and a `draw_string` argument. It
scans whole files rather than single lines, because these calls wrap —
a per-line scan silently skipped them, which is how a 6px caption
survived the first version of the check.

### Battle composition

The battlefield takes 70% of the canvas (504px), the HUD 216px. Within
the HUD the contextual panel (action menu / target info) is a fixed
420px on the right and the party cards share what remains, so cards
occupy materially less of the screen than the full-width strip they used
to. Portraits went from an 18x22 thumbnail to roughly 92x107 on the card
and 136x160 in dialogue — at or near the atlas crop's authored size.

### Overworld

Greymere's tiles are drawn procedurally at `TILE = 16` and its townsfolk
are ~20x30 sprites. Neither holds detail beyond that, so the overworld
keeps its authored scale and the camera zooms by a whole number instead.
The registered cast still gains real detail, because the GPU samples
their atlas at final screen scale rather than at the sprite's logical
size.

`OVERWORLD_ZOOM = 4` is not arbitrary: it is the smallest whole zoom
whose view fits inside the 24x14 tile map. At 3 the camera framed
427x240 world units against a 384x224 map and rendered the empty space
beyond its edges. `test_camera_zoom_keeps_the_view_inside_the_map` pins
this, so a future map or zoom change fails loudly rather than shipping a
grey void.

### Window scaling

Stretch stays `canvas_items` + `integer`, which keeps the typeface and
tile art exactly crisp at every window size. Verified: a 2560x1440
capture downscales to the 1280x720 capture with a mean delta of 0.00/255
on boot and 0.02 on party setup — the layout is identical, with no
reflow or clipping. The battle screens differ by ~1.2/255, entirely in
the painted art, which resolves at genuinely higher detail at 2x.

The trade is that a window between 1x and 2x (1920x1080) renders
1280x720 letterboxed rather than filling the screen. Fractional
scaling would fill it, at the cost of uneven pixel stems on the font and
tile art. That is a deliberate choice in favour of the stated art
direction. It is recorded here rather than in `project.godot`, because
running Godot's importer rewrites that file and strips its comments.

---

## 3. Assets still genuinely too low-resolution for 720p

Measured, not assumed. The main cast is **not** on this list: Kai,
Almyra, Liora and all three Hollow Court enemies resolve through the
1536x1024 atlas, so the 37-59x44 PNGs under `assets/characters/` and
`assets/enemies/` are the unused legacy fallback path.

| Asset | Native | Drawn at | Note |
| --- | --- | --- | --- |
| `characters/townsfolk/*/overworld.png` | 16-20 x 30 | 4x (nearest) | Authored pixel art. Crisp, but the chunkiest thing on screen beside the painted cast. |
| `portraits/townsfolk/*/neutral.png` | 86x96 | 136x152 box | Upscaled ~1.6x, so villager portraits are soft where the main cast is sharp. |
| `entities/*/idle.png` | 64x32 | `EFFECT_SCALE` | Bonded Entity manifestations. |
| `tiles/greymere_props.png` | 112x24 | 4x (nearest) | Props share the tile grid's authored resolution. |
| `assets/battle/backgrounds/hollow_court.png` | 320x122 | full battlefield | Generated fallback only — the live Hollow Court uses the 1672x941 plate. Would need regenerating at 1280x504 if a non-registered location ever uses it. |
| `ui/icons.png` | 7px cells | 4x (nearest) | Blocky by design; consistent with the typeface. |
| Greymere's procedural tiles | `TILE = 16` | 4x (nearest) | Drawn in `greymere.gd` with sub-tile offsets baked to a 16px grid. |

---

## 4. Remaining visual defects that need artwork, not code

1. **Residual key fringe on the cast atlases.** The atlases ship with the
   key baked into RGB and no alpha channel; about 3% of texels sit
   between the subject and pure magenta. The shader now keys
   proportionally and subtracts the key back out of the RGB
   (see `colour_key.gdshader`), which cut the fringe on Kai's dialogue
   portrait from 620 to 185 pixels and turned a bright magenta halo into
   a thin dark outline. Removing the rest means giving the atlases a real
   alpha channel; no shader can recover a dark edge pixel from a dark
   violet garment without also eating the Hexbound Adept's robes.
2. **Greymere's environment does not match its cast.** The ground is a
   flat untextured field and the buildings are simple blocks, beside
   painted characters that now show far more detail. This reads as a
   style clash at 720p that was hidden when everything was reduced to
   320x180. It needs authored tiles, not a scaling change.
3. **Villager portraits are softer than the main cast.** Same dialogue
   box, half the source resolution (86x96 against 138x160).
4. **Overworld sheets are still one pose per direction**, not walk
   cycles. Unchanged by this work.
5. **Bonded Entities and remaining encounter backgrounds** are still the
   older, smaller art.

---

## 5. Rendered QA results

Godot 4.3, `gl_compatibility` on llvmpipe under `xvfb-run`.

- Python suite: **248 passed**.
- Godot static validator: passed (43 scripts, 6 scenes, 38 JSON files).
- Rendered capture: all five targets at 1280x720, no script or shader
  errors.
- Captured again at 2560x1440; layout identical (see Window scaling).

Baselines committed in `docs/visual_refs/`: `baseline_boot.png`,
`baseline_party_setup.png`, `baseline_overworld.png`,
`baseline_battle.png`, `baseline_battle_target.png`.

### Defects found by rendering and fixed in this work

Each of these was invisible to static checks and to the old canvas:

| Defect | Cause | Fix |
| --- | --- | --- |
| Phase label ("ROUND 1 — choose actions") absent | label box shorter than its own line height, so `clip_text` erased it | box height derived from the type size |
| Action menu description overprinted its last entry | 4 rows plus a description did not fit 168px | battlefield 504 / HUD 216, row pitch from the type scale |
| Grey void around Greymere | camera zoom 3 framed more world than the map contains | zoom 4, pinned by a test |
| Empty panel floating at boot's top-left | menu frame left at 320x180 coordinates | derived from the menu band |
| Magenta halo on portraits and combatants | key removed from alpha only, never from RGB; latent until the art was drawn near authored size | proportional key plus despill, brightness-gated to protect violet cloth |

### Verified in the captures

Combatant facing (players right, enemies left), z-order (front row over
back), portrait bounds, panel containment, no clipping or overlap, no
stretched artwork, camera bounds, and the violet-robed Hexbound Adept
surviving the magenta key intact.

Not covered: animation, transitions, damage/status/awakening effects in
motion, and dialogue over the overworld. Those need a moving capture.
