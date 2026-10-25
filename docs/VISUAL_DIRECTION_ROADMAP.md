# Visual Direction Roadmap

Where Crestbound Duelists should go visually, built from what already works
(the painted Outskirts with the authored adult cast) and the concept
references supplied for Greymere Town, the Outskirts, Silas's study and the
battle screen. The game stays **2D**: there are no 3D characters, and nothing
semi-realistic replaces the pixel-painted style.

The references show four things the game doesn't do yet:

- **Depth:** layered foreground, midground and background, real occlusion
  and a tilt-shift falloff.
- **Light:** sunbeams cut by actual canopy shapes, lit windows, and contact
  shadows that pool under objects.
- **Density:** handcrafted dressing at a consistent scale (flower beds, stone
  stairs, fences) rather than scattered props.
- **Battle staging:** combatants grounded in their environment, with spell
  light falling on the ground.

## 1. Character sprite specification

| Property | Overworld | Battle |
| --- | --- | --- |
| Visible body height (logical px) | 24 (Kai, head to foot) | 39 (Kai) |
| Proportions | Adult: head/body 0.26–0.32, frozen per character in `character_proportions_baseline.json` | Same proportions as overworld (closes V-10) |
| Source resolution | 200–270 px body, drawn with mipmapped linear filtering | 420–560 px body |
| Facings | Down, up, east, west; bodies within 1 px of the front view | Facing the opponent; flipped only if authored for it |
| Frames | Idle, plus 4-frame walk per side; idle breathing (2 frames, V-15) | Idle (2), wind-up, strike, recoil, down (V-11) |
| Anchor | Foot centre; body height measured, never assumed from the frame | Same |
| Outline | One dark outline weight per tier; no halos; hard alpha or magenta key | Same |

**Gate:** `audit_character_scale.py` and `cast_lineup.py` must pass. A
re-render has to re-baseline its proportions in a reviewed commit.

## 2. Environment asset specification

- **Ground:** painted material fields plus shader (`PaintedTerrain`), 256 px
  seamless materials, two tiles per texture repeat, anti-tiling sampling.
  New materials go through `build_painted_terrain.py`.
- **Props:** a bottom-centre anchor and collision footprint in
  `environment.json`, scaled to world units, with soft contact shadows.
  Scale props against the 24 px character: a door is about 1.4 character
  heights.
- **Layers:**
  - ground, drawn by the shader;
  - y-sorted props and characters;
  - canopy and foreground, which occlude the player and fade when the
    player is behind them;
  - screen-space depth on the High preset.
- **Density:** dressing is authored per area as handcrafted clusters, not a
  uniform scatter. Procedural dressing only fills blocked tiles.

## 3. Camera and pixel-rendering conventions

- **Resolution:** logical 320x180 at an integer window scale. UI is
  vector-font MSDF, never bitmap.
- **Filtering:** sprites and props use linear filtering with mipmaps for
  painted art. Nearest filtering is only for legacy tiny sheets.
- **Camera:** follows the player with a look-ahead and integer rounding; no
  rotation and no zoom changes during play.
- **Post-processing:** gated by preset (High, Medium, Low). Web builds
  default to Medium.

## 4. Palette and lighting rules

- **Key light:** warm sun from the upper left (yellow-white). Shade is cool
  (blue-violet), and canopy shade is cooler still.
- **Interiors:** candles at 2700K-equivalent orange, window light warm white.
- **Hollow Court:** cold blue key with gold candle accents. It is the only
  cold-keyed location.
- **Saturation:** highest on characters and interactables, then foliage,
  then ground. Sprites must out-contrast their background, which the grade
  preserves.
- **Bloom:** only on emissive sources (fire, glyphs, water glints), never on
  skin or UI.

## 5. Battle composition guidelines

- **Staging:** allies on the left, enemies on the right, front row lower on
  screen and closer to the camera. Companions sit just behind their own
  bearer.
- **Grounding:** each combatant gets a contact shadow plus environment-lit
  floor, with reflections on wet stone (V-20).
- **Background:** the location's own painted look. The route uses painted
  terrain and the Court uses its backdrop. Battles never use a flat tile
  floor.
- **HUD footprint:** the HUD stays at the top rail and bottom cards; the
  middle third of the screen is reserved for combatants and VFX.
- **Impact:** at least one authored strike pose plus hit-stop (2–3 frames),
  light flash on the target, and a screen shake proportional to the move.

## 6. UI and typography standards

- **Faces:** Cinzel for titles, place names and phases; EB Garamond for
  commands; IBM Plex Mono for numbers and body copy. All MSDF, minimum 5
  logical px.
- **Measurement:** always use `UiStyle.text_width`, which measures tracked
  text exactly as drawn. Fit by stepping tracking, then size; never truncate
  a name.
- **Colour roles:** gold means command and agency, violet means target,
  slate means passive. Glow only marks the current focus.
- **Spacing:** a 2 px panel inset, 1.5 px hairlines, and rows at least
  8 px high.

## 7. Animation and effects principles

- **Sprite frames carry the motion;** tweens only add follow-through
  (squash, lean, drift).
- **Timing:**
  - walk cycles are tied to tile progress;
  - idles run at 1.5–2 fps, desynchronised per NPC;
  - UI reveals ease out over 0.12 s;
  - scene fades take 0.16 s to close and 0.18 s to open.
- **Effects never obscure gameplay:** effect light pools sit on the ground,
  and particles stay under the HUD.

## 8. Asset approval and quality control

1. **Generation is reproducible.** Raw generator output goes into
   `tools/*_sources/`, and committed game assets are rebuilt by
   deterministic scripts.
2. **Automated gates:**
   - `audit_character_scale.py` (scale, drift, proportions, manifest
     validity)
   - `audit_walk_cycles.py`
   - `test_painted_terrain.py` (seams, water versus walkability)
   - `test_entity_art.py`
3. **In-engine review:** capture the affected screens and the cast line-up,
   compare against the previous capture and the reference, and attach both to
   the PR. A passing test suite is not visual approval.
4. **Art-direction sign-off** is needed for any change to proportions, palette
   roles or a character's identity.

## Milestones

| # | Milestone | Scope | Exit criteria |
| --- | --- | --- | --- |
| 1 | **One cast** (V-10, V-15) | Rebuild overworld sheets from the battle art (or the reverse) for Kai, Almyra and Liora, then the townsfolk. Add breathing idles. | Line-up passes and proportions are re-baselined; side-by-side battle vs overworld sheet approved. |
| 2 | **Combat feel** (V-11, V-20, V-22) | Author key poses for each class, hit-stop, ground-lit VFX and floor contact in battle. | A frame-by-frame capture of each class's signature move is approved. |
| 3 | **Greymere depth pass** | Canopy occlusion and fade, lit windows, stone stairs and garden beds from the Town concept, handcrafted dressing clusters, pond border (V-14). | Town and Outskirts captures reviewed against the references; web Medium preset still holds 60 fps on a mid-range laptop GPU. |
| 4 | **Room identity** (V-16) | Per-room decor and palette tables; Silas's study matched to its concept (taller back wall, shelves against it). | Six interior captures are distinguishable at a glance. |
| 5 | **Interface finish** (V-12, V-13, V-17–V-19) | Dialogue nameplate, party-setup enemy strip, shop icons, victory and defeat beats. | 720p and 360p captures pass the legibility review. |
| 6 | **New regions** | Apply milestones 1–5 as the standard for Bellgrave, Evershade and the rest. | Each new area ships with its gallery and line-up evidence. |
