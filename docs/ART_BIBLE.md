# Crestbound Duelists art bible

## North star

A deliberate late-16-bit dark-fantasy RPG: moonlit slate stone, human warmth in
small pools, Crest-gold agency and spectral-violet supernatural pressure. Characters
are the first read, the landmark the second, and UI the quiet framing layer.

## Rendering and scale

* Compose natively at **320×180**; display only at integer nearest-neighbour scales.
  No subpixel sprite placement, filtered pixel art, mixed-resolution edges or
  post-effects that soften silhouettes.
* Overworld tiles use a 16×16 base. Hero walkers target 24×32 frames, but may use
  20–32 px widths and 28–40 px heights when their sidecar anchor is exact.
* Battle Duelists target 40×48 frames (32–56 wide, 40–64 tall allowed for silhouette).
  Entity manifestations may exceed that footprint but must remain subordinate.
* Portraits are 86×96 source crops displayed in a 38×40 dialogue window. Preserve
  one-pixel-safe facial features at the displayed crop; linear filtering is the
  intentional exception for painterly source portraits.

## Shape, value and light

* Identify each combatant from solid black at gameplay size: distinct head/weapon,
  stance and shoulder mass. Do not distinguish classes only by hue.
* Keep faces and action hands above adjacent background values. Reserve the darkest
  two ramps for cavities, undersides and separation, not blanket outlines.
* Key light comes from upper-left moonlight; Crest activation adds a local gold rim,
  Entity/Hex energy a violet lower or rear rim. Never reverse the base light between
  portrait, overworld and battle versions of one character.

## Palette grammar

Moon slate is structure and shadow; muted blue-grey is passive information;
desaturated earth/foliage grounds the mortal world. Gold means player agency,
confirmation and a true Crest response. Violet means target, hostile/unknown effect,
Hex and spectral presence. Steel blue means defence. Bright gold and near-white are
scarce impact values—do not spend them on decorative borders.

## Framing by asset type

* **Portrait:** head and upper shoulder three-quarter crop, eyes in the upper 42%,
  consistent upper-left light and transparent/quiet background. Expressions are
  `neutral`, `determined`, `injured`, `surprised`, `intense`; identity, costume and
  camera cannot drift between them.
* **Battle:** anchor at the weight-bearing foot midpoint. Keep weapons/effects inside
  the frame or explicitly enlarge every frame. Player silhouettes face right,
  opponents left. A readable anticipation pose precedes contact.
* **Overworld:** anchor at feet; head clears a 16×16 cell while feet communicate the
  occupied tile. Down/up/side walk directions share proportions and stride phase.
* **Environment/background:** reserve the bottom HUD boundary and combat safe area;
  place high-frequency detail around, never behind, faces and target rings. Use near,
  middle and far value groups, foreground occluders sparingly, and a unique landmark
  silhouette at every decision point.

## Animation

Idle is 2–4 restrained frames; walk is four frames per direction; attacks follow
anticipation → readable travel → one-frame contact → recovery. Hold the impact pose
for one native frame before recoil. Signature moves add a class-specific motion arc
and Crest motif; basic actions remain brief. Hit reactions move away from the source.
Defeat ends in a stable readable silhouette, never sudden disappearance.

Awakening is a staged transition: environment value drops, Crest glyph resolves,
Entity/character silhouette changes, gold releases, then gameplay clarity returns.
It may dominate the screen briefly but must not hide the resulting state.

## VFX

VFX carry direction and timing, not visual fog. Use a tight core, one readable
silhouette/motif, sparse particles and a short decay. Violet targets/effects and
gold player confirmation preserve the semantic grammar. Hex uses broken angular
loops; Brace uses low steel-blue planes; Resonance uses inward motes; damage uses
warm pale contact plus restrained red recoil. Effects never permanently cover HP,
faces, target rings or the action menu.

## Environment principles

Build terrain transitions before scatter detail. Paths use contrast at junctions;
doors, arches and stairs remain readable without labels. Separate background,
walk plane, props/characters, canopy/foreground and atmosphere. Greymere is worn,
lived-in and cool with small warm lamps; the Hollow Court is older, drowned, radial
and subtly oriented toward its dormant Crest node—not generic ruins.

## UI ornamentation

UI is carved nocturnal framing, not a web dashboard. Prefer open composition,
selection bands, tiny corner cuts, icon + short label and one divider over nested
rectangles. Gold invites/commits; violet identifies target/effect; slate explains.
Body text is 8 px minimum, critical labels 10–12 px, with short lines. Ornament may
suggest Crest arcs and broken Court geometry but cannot imitate a generic fantasy kit.

## Anti-patterns

No AI/procedural focal art presented as finished; arbitrary gradients; full-screen
bloom; noisy dithering on faces; inconsistent pixel density; floating feet; mirrored
text/weapons; hue-only status communication; tiny stat walls; repeated nested boxes;
decorative gold that looks selectable; generic heraldry; invented costumes, species,
symbols or lore; copied reference pixels; or fixed artwork dimensions in gameplay code.

## Delivery contract

PNG sheets use equal horizontal frames and a same-name JSON sidecar. Sidecars own
frame size/count, feet anchor, named states and optional stage offsets/crop focus.
Missing optional states and portrait expressions fall back safely. Review assets at
1× and 4×, against both light and dark staging, and validate with the asset tests.
