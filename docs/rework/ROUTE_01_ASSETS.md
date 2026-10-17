# Route 01 artwork

Generated with the built-in image-generation tool on 17 October 2026. Original
RGBA outputs are committed unchanged as `game/assets/route01/trainers.png` and
`game/assets/route01/scenery.png`. Transparent pixels contain unused RGB; the
renderer uses alpha directly and never chroma-keys these new assets.

The three `*_overworld.png` sheets are lossless rectangular atlas extractions:
512×300 crops at (column×512,640), each containing four 128×300 facing cells.
No semantic image processing or background replacement was applied. Battle and
portrait rectangles are recorded in `game/assets/rework/characters.json`.

Trainer prompt specification: production medieval fantasy pixel-art atlas,
1536×1024, transparent background, dark slate outlines and muted colours. Three
equal columns: Apprentice Rowan (young adult, curly auburn hair, cream tunic,
teal cloak, wooden training sword); Travelling Squire (adult dark-skinned woman,
short black hair, steel armour, mustard tabard, round wooden shield, short sword);
Wandering Challenger (middle-aged olive-skinned man, grey-streaked tied-back hair,
short beard, moss cloak, rust sash, curved sword). Upper band has one complete
right-facing battle stance per identity. Lower band has front/back/right/left
compact top-down views, preserving each identity. No labels, grid or shadows.
The actual generated battle band extends to y620; metadata follows actual art.

Scenery prompt specification: matching transparent 1536×1024 six-prop atlas,
three columns and two rows: green oak, blank wooden direction sign, mossy boulder
with flowers, closed iron-banded oak chest, matching open chest, horizontal
split-rail fence. Classic three-quarter top-down pixel RPG view, crisp clusters,
slate outlines, natural green foliage and honey wood, no glow, text or shadows.
Metadata crops follow the actual generated positions rather than assuming an
exact 512px grid. New props use nearest filtering and preserve existing collision
footprints where replacing a previously placed object.

The legacy colour-key shader now suppresses magenta/green spill only beside
keyed or transparent pixels before premultiplied averaging. Interior violet
cloth stays coloured. Alpha-native artwork bypasses both keying and despill.

Native route, grass, chest-clearing and battle-menu captures are under
`docs/visual_refs/route_01/`. Generated artwork is integrated and locally reviewed;
stationary trainers have four idle facings, not new walking/attack frame sets.
