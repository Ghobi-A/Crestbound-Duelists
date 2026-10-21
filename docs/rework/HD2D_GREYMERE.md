# Greymere HD-2D pass: Outskirts and Town

Greymere Outskirts (`route_01`) and Greymere Town (`greymere`) now render
in a cinematic, painterly style modelled on the Greymere concept references.
Gameplay, collision, encounters, NPCs, props, transitions and saves are
unchanged. Every new layer is presentation only.

## Rendering architecture (decision)

**Enhanced 2D on the existing Compatibility (WebGL 2) renderer.** No 3D,
no engine upgrade, no new runtime dependency.

| Option | Visual fidelity | Web / Pages | Effort and risk |
| --- | --- | --- | --- |
| Hybrid 2.5D (3D scene, billboarded sprites, DOF) | Highest (true depth, DOF) | Compatibility has no SSAO/DOF; glow and shadows are limited and costly in WebGL | Rebuilds the map, camera, y-sort and collision presentation; breaks the grid-locked 320x180 look |
| **Enhanced 2D (chosen)** | Most of the reference look: organic ground, light, grading, depth blur | Single-threaded Web export unchanged and verified | New nodes beside the existing ones; WorldLocation, collision and the grid stay as they are |

The layout is 320x180 drawn at an integer multiple of the window, so
shaders already run at full output resolution. That makes the following
cheap 2D techniques enough:

1. **PaintedTerrain** (`painted_terrain.gd/.gdshader`): the whole ground in
   one draw call. Offline material *fields* (`fields_<location>.png`, 8 px
   per tile, Gaussian-blurred by `tools/build_painted_terrain.py`) are
   thresholded through tileable noise. Paths wind and meander through a
   domain warp, corners round off and shorelines read as natural. Materials
   are sampled twice (rotated, rescaled) and blended by broad noise to hide
   repetition. Water is animated: drifting ripples, depth tint, sky
   reflection, glints and a foam line. It sits inside its own tiles; a test
   guarantees walkable tiles never render as water.
2. **PaintedDressing**: shrubs on forest edges and rocks on the shoreline,
   placed by a coordinate hash and only on blocked tiles.
3. **PaintedAtmosphere**, all presentation:
   - multiply pass: canopy shade and wind-driven leaf dapples
   - additive pass: drifting sun shafts and dappled highlights
   - lantern halos with flicker, and fountain shimmer
   - a screen-space grade (cool shadows, warm highlights, S-curve, vignette)
     with tilt-shift and bloom on High
   - pre-blurred foreground foliage at the frame corners with sway and
     camera drift

   Characters sit under the light passes, so they share the scene's light.
   Existing contact shadows, y-sort and anchors are untouched.

A location opts in with a `painted` block (`path_symbols`,
`path_material`) in the world builder.

### Interiors

Every room (inn, study, shop and the three homes) has a
`painted_interior` block and renders through **PaintedInterior**
(`painted_interior.gd/.gdshader`):

- **Room shader:** one draw for the whole room. Long warm planks with contact
  shadow along the walls, a stone-and-timber back-wall face, timber wall caps
  and a stone threshold at the door. Rooms are rectangles, so all of this
  derives from the floor and door rects; no fields texture is needed.
- **Back-wall decor:** arched windows, crest banners and candle sconces fill
  the stretches of wall that furniture leaves free.
- **Floor decor:** a rug under the room's centre, and potted plants on the
  side-wall tiles.
- **Light:** a multiply pass for ambient darkness, and an additive pass for
  flickering candle pools (room lights plus sconces) and diagonal window
  shafts with drifting dust. Characters sit under both passes.
- **Finish:** a warmer screen grade with a deeper vignette, candle bloom and
  out-of-focus candle bokeh in the foreground on High.

The camera stops at the room's bottom wall, so the back wall stays in frame.
Furniture props and their collision are unchanged.

## Graphics presets

`GraphicsSettings` (`user://settings.cfg`, pause menu → *Graphics*; applies
when you next enter an area):

| Preset | Contents |
| --- | --- |
| High (desktop default) | Everything: light passes, grade, tilt-shift, bloom, foreground foliage |
| Medium (web default) | Light passes and colour grade/vignette; no blur, bloom or foreground layer |
| Low | Painted terrain and dressing only; static water |

## Performance

`route_01` at 1280x720, `--print-fps`, Xvfb with **llvmpipe (CPU
software GL)**. A floor for comparison, not real GPU numbers:

| Build | FPS |
| --- | --- |
| main, old per-tile `WorldTerrain` | 19–20 |
| painted Low | 24–28 |
| painted Medium | 18–20 |
| painted High | 10–11 |

The terrain shader replaces thousands of per-tile rects that were redrawn at
4 Hz, so Low is faster than before. High's cost is the 17-tap tilt-shift and
bloom pass, which is negligible on a GPU and is why web builds default to
Medium.

Texture use: the material textures are 256 px, with mipmaps for the
materials and props. Fields and noise add under 0.5 MB.

## Web validation

The Godot 4.3 `Web` preset (single-threaded) was exported locally and driven
in headless Chromium with SwiftShader. `tools/verify_world_web.mjs` passed
(route travel and return, menu, four viewport sizes, no page errors), and a
longer scripted walk reached the painted Outskirts with no console or page
errors. SwiftShader is a software renderer, so its frame rate (5–6 fps) says
nothing about real browsers.

## Assets (PixelLab)

The materials and props were generated with PixelLab (pixflux) img2img from
crops of the supplied concept references, or from the existing cobble kit.
They were then reviewed. Raw outputs live in `tools/painted_sources/`. The
builder crops them, makes them seamless (a four-way roll blend), feathers or
rounds the props and pre-blurs the foreground foliage. Rebuild with:

    python tools/build_greymere_world.py
    python tools/build_painted_terrain.py

## Remaining differences from the references

- Interiors: the concept study's back wall is about three tiles tall, with
  shelves standing against it. Our rooms keep their two-row walls and
  furniture positions (collision), so shelves stand a little forward of the
  wall, and the wall is mostly visible when the player walks up the room.

- The references are painterly renders with real perspective, depth of
  field and baked global light. In-game we approximate them with
  screen-space blur and 2D light layers; there is no true parallax or
  occlusion depth.
- Town trees stay Greymere's established blue foliage (protected identity),
  while the concept shows green broadleaf trees. The route's pixel oaks are
  crisper than the concept's painted trees.
- The concept town has stone stairs, low walls, flower beds and lit windows
  that the current town layout and building art do not have; windows are
  not lit yet.
- The concept camera is higher and shows more of each building; the game
  keeps its 320x180 framing.
- Light shafts and dapples come from noise, not from actual tree
  silhouettes.

## Running and testing

    python -m pytest tests/test_painted_terrain.py
    python tools/validate_godot_project.py
    CRESTBOUND_CAPTURE_TARGETS="route_01 route_grass route_clearing overworld" tools/capture_screenshots.sh out/

The Godot smoke scenes (`world_smoke`, `route_smoke`, `presentation_smoke`,
`shop_smoke`) cover movement, collision, interactions, transitions,
encounters and battles.

## Characters re-rendered on Kai's proportions

The townsfolk are Joey, Lena, Senna, Silas, Gell, Danfor, Orrin, Ferris and
the Hooded Stranger, and the route trainers are Rowan, the Squire and the
Challenger. All of them were drawn stockier and bigger-headed (or, for the
trainers, adult-proportioned) than Kai, so each was redrawn on Kai's frame
with PixelLab:

1. **Kai-proportioned base:** `edit_image` text edit of the closest Kai
   class's standing frame (neutral, guardian, mage or warrior) into the
   character.
2. **Identity:** `edit_image` reference edit with the original sprite, which
   restores their face, hair and outfit details.
3. **Facings:** a `create_character` v3 rotation into four facings.
4. **Side walks:** four-frame walk-in-place `animate_character` cycles for
   the authored sheets, so the walk-cycle audit keeps passing. NPCs only
   ever stand.

The reviewed outputs live in `tools/overworld_sources/<name>/`.
`tools/rerender_overworld_sheets.py` composes them deterministically into
the authored 4x4 sheets (magenta key) and the trainers' 1x4 strips,
aligning frames by torso and feet and picking the two most different walk
frames as the contacts. Then run the metadata and scale audit:

    python tools/rerender_overworld_sheets.py
    python tools/materialize_overworld_v2.py
    python tools/build_overworld_metadata.py
    python tools/audit_character_scale.py --write

The superseded walk sources for Ferris, Gell and the Stranger were removed
so `apply_pixellab_walks.py` cannot paste old art over the new sheets. Kai,
Almyra and Liora, the main cast, are untouched. `tests/test_rerendered_characters.py`
checks that the sheets rebuild identically and that every body fills its
frame like Kai's.
