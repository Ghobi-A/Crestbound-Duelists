# Reference-led presentation rebuild

## Scope and plan

Preserve combat resolution, inputs, saves, encounter sizes and exported balance data.
Work on `visual/reference-led-rebuild`; do not publish an unverified build to main.

1. Audit current scenes and capture unchanged runtime baselines.
2. Centralise texture bounds, facing, foot anchors and battle formation geometry.
3. Repair dialogue pagination, portraits, party setup and UI safe areas.
4. Integrate original reference-led art only after transparency/geometry validation.
5. Run static, headless and rendered checks; report incomplete art separately.

## Audit findings

- `DialogueBox`, `PartySetup` and `RoundPreview` create TextureRects without
  `EXPAND_IGNORE_SIZE`. Source-image minimum dimensions override authored UI boxes.
- Dialogue has word wrapping but no pagination, so long entries can leave its panel.
- `DuelistSprite` reads foot anchors but never adjusts facing. Native asset direction
  must be explicit metadata; flipping also needs a mirrored foot anchor.
- `BattleController` owns presentation formation/background code alongside orchestration.
  `BattlePresentation` already consumes resolved events; retain that boundary.
- Overworld combines generated walk cycles with detailed static NPC art. This needs
  authored directional replacements, not static combat cutouts pretending to walk.
- The live client is 320x180 logical coordinates with integer canvas scaling. Changing
  that globally before migrating every screen would break existing layouts.
- UI primitives already share `UiStyle`; standardise their fitting rather than add
  another competing theme implementation.
- Existing stable IDs/asset paths use old names. Keep those IDs for save compatibility;
  apply authorised naming changes to display copy, not blanket identifier replacement.

## Reference direction

Greymere: reference 1's moonlit stone, warm windows, foliage and purple Crest accents.
Combat: reference 3's taller adult figures, slate armour, navy cloth, muted gold and
open floor. References 2 and 3 differ in proportions; do not mix their character art.
All UI must remain live text and all combatants independent nodes.

## Shared specification

- Logical canvas: 320x180; integer scaling; no arbitrary camera zoom changes.
- Combat safe floor: x=16..304, y=20..106; lower HUD begins at y=122.
- Two explicit team halves, dynamically spaced for encounter size.
- Sprite origin is the foot anchor; native facing is `left` or `right` metadata.
- Portrait boxes ignore texture minimum size, contain aspect ratio and clip children.
- Dialogue pages are measured with the actual font; advancing pages must not skip entries.
- Missing optional art stays empty; missing required character art emits diagnostics.
- No unapproved placeholder art may silently replace another character.

## Generated asset provenance

Built-in image generation was used for an original Hollow Court environment plate:
dark pixel-art ruined cathedral, broken concentric arches, suspended gold crest,
statues, cold blue mist, candles and open reflective battle floor. No characters or UI.
Saved as `game/assets/rework/hollow_court.png`.

Six-character atlas prompt: Kai, Almyra, Liora, raider, mercenary and adept, one
right-facing adult-proportion full-body pose each, 3x2 equal cells, slate/navy/gold
palette, transparent background. Initial output and a background-extraction edit
retained a painted backdrop; do not treat them as verified transparent sprites.

The selected `combat_cast.png` and `overworld_cast.png` use an explicit green key.
`colour_key.gdshader` removes that declared background at render time. This is a
runtime extraction contract, not a claim that the source PNG contains alpha.

## Kai class pass

`kai_classes.png` contains six original outfits in order Warrior, Guardian, Mage,
Sorcerer, Assassin, Neutral. `kai_overworld.png` contains the same six classes in
rows with front/back/right/left columns. Source dimensions are recorded from the
actual files, not assumed from the generation request. Battle regions include
weapons and effects; foot anchors are local to each region. Portraits crop each
class's face from the same atlas. Stable `aren/<class>` keys remain unchanged.

Built-in generation prompt set: preserve reference Kai's brown hair, youthful adult
face and proportions; create six material-led outfits with limited class accents;
Warrior asymmetric medium iron/crimson, Guardian symmetrical heavy steel/azure,
Mage cloth robes/amber, Sorcerer asymmetric robes/violet, Assassin fitted minimal
armour/ice-cyan, Neutral field jacket/emerald. Correct the extraction background to
flat magenta, remove excess Sorcerer armour and Assassin coat tails. Final targeted
edit gives Neutral a balanced sword-and-magic stance, emerald free-hand glyph and
fine blade enchantment. The other classes remain unchanged by that final edit.
Magenta extraction protects Verdant green. Full design: `KAI_CLASS_VISUALS.md`.

## Implementation report — 2026-09-06

- Shared geometry: `presentation_layout.gd`; formations/background: `battle_stage.gd`.
- Asset registry: `characters.json`, `character_presentation.gd`, keyed shader.
- Consumers: battle sprite, overworld sprite, boot class preview, dialogue, party
  setup, round preview and live party status cards.
- Dialogue measures pages with the actual font; portraits have bounded boxes and
  text-safe space. Overworld camera offsets during dialogue and restores afterward.
- Slate UI palette, horizontal party cards, bounded result ornament and header text.
- Authorised display names updated in YAML, generated character/encounter exports
  and opening dialogue; saved IDs and combat rules remain unchanged.
- New runtime smoke scene and class atlas geometry tests; screenshot capture now
  advances paginated conversations to completion.

### Verification

- Python suite: **240 passed**.
- Godot static validator: passed.
- Official Godot 4.3 import: passed without script errors.
- Headless presentation smoke: **0 failures** across six class registrations,
  four overworld directions, both battle sides, portrait bounds, long dialogue
  pagination, dialogue camera restoration, party setup, opening victory and defeat.
- Later encounters explicitly report unassigned enemy art: Archive Ambush (three
  units), Rin's first duel (one), paired Trial (two). They are not visually certified.

### Remaining limitations / release gate

- **Rendered gameplay QA remains blocked.** A locally extracted virtual display
  could not open display sockets in this environment. Headless node checks do not
  certify shader edges, artwork readability or screenshots at either viewport.
- New overworld art has one pose per direction, not full authored walk cycles.
  Combat uses existing motion/effect sequencing with static class poses.
- Greymere's environment tiles and townsfolk still use existing art. They have not
  been fully rebuilt to match the reference environment or new Kai proportions.
- Other encounter backgrounds, Bonded Entities and some decorative art remain old.
- Portrait expressions currently share a face crop. Custom saved names are preserved.
- Class magic motifs are visual only; no new abilities, damage or class balance.

### Visual QA checklist before release

- [ ] Render six class previews, party portraits and dialogue at 320x180 and smaller
  host windows; verify no clipping, text collision, edge key spill or stretched art.
- [ ] Inspect all four overworld directions and walking; author missing cycles.
- [ ] Inspect every class facing an enemy, each row and asymmetric formation.
- [ ] Inspect damage, selection, statuses, awakening, victory and defeat effects.
- [ ] Inspect all villagers and long speaker names over the active overworld.
- [ ] Complete coherent environment, NPC and remaining encounter art assignments.
- [ ] Capture and compare final gameplay screenshots against supplied references.
- [ ] Publish only after these visual gates pass; this branch is a work in progress.
