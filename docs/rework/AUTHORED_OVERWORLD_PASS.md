# Authored overworld pass

This pass replaces the Greymere cast's runtime walkers and all six Kai class walkers with 17 directionally authored sheets. `game/assets/overworld/authored.json` is generated from the sheets by `tools/build_overworld_metadata.py`; it records four facing rows, four poses per row, per-pose source rectangles and foot baselines. The shared `OverworldSprite` loader uses the authored registry first, preserves explicit facing without horizontal mirroring, keys the intentional magenta background, and fails clearly if a registered texture is missing. Remaining unregistered actors still use the older loader.

The character identities follow `GREYMERE_CHARACTER_REFERENCE_AUDIT.md`. Kai's face and brown hair carry through each class; Mage and Sorcerer have robes, Neutral has a green magical sword identity, Almyra retains long silver hair, and Gell retains his green cap. Joey was regenerated after a first pass copied Kai's hair and equipment. The Mage and Sorcerer sheets were edited after stray swords/metal appeared.

## Verification

- The registry covers every Greymere NPC key and all six `aren/<class>` save aliases.
- The metadata generator measures body height in a central strip so a raised torch or spear does not shrink its bearer. It writes an individual foot baseline for every frame.
- Static Godot validation, 17 focused Python tests, world movement/interior/save smoke, and battle presentation smoke pass locally. The battle smoke uses low-HP fixtures to exercise both result screens deterministically without changing combat rules.
- The branch workflow exports the browser game and captures all six class looks plus Greymere and interiors under an actual display. Review its render artifact before accepting the visual pass.

## Remaining review

The fourth side-view pose on several generated sheets resembles the second contact pose too closely. Each manifest entry is marked `animation_review: pending`; replace or hand-correct these source poses before treating walk animation as final. The generated art is more detailed and brighter than some environmental pixels. Review character scale, readability and colour balance against the CI screenshots at the game's native resolution. Battle and portrait assets still have their separate existing presentation contracts.
