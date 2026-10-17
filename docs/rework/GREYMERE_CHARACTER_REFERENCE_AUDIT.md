# Greymere character reference audit

Audit date: 2026-09-08. Scope: Kai's six classes and every resident in
`game/world/locations.json`. This is a reference-selection record, not approval
of newly generated sprites. No replacement character sheets were generated during
this audit. Existing artwork remains unchanged.

Explicit user confirmation after inspection: **Almyra retains her long silver
hair; Gell retains his green cap.** These are locked identity constraints, not
optional design proposals.

## Authority and inspection

Inspected the character, townsfolk, portrait, battle and rework asset directories;
the character and class bibles; visual-reference documentation and character
lineup; all 19 loose `ChatGPT Image ...` PNGs under `game/assets/`.
Inspected the eight legacy principal battle sprites, portraits and overworld
sheets, nine townsfolk portraits and sprites, and the authored rework atlases.
The generic procedural v2 walkers are not identity references.

Folder names are technical aliases, not current names. The character bible defines
roles and behaviour but does not authorize changing established physical designs.
Repository presence alone does not prove historical approval. Where approval
history is absent, the choice below uses the strongest existing authored image
consistent with current class canon and current runtime portrait selection.

Reference shorthand (all paths relative to repository root):

- **Classes:** `game/assets/rework/kai_classes.png`; portraits are source crops
  recorded in `game/assets/rework/characters.json`.
- **Cast:** `game/assets/rework/combat_cast.png`, with portrait crops in the same
  registry; directional corroboration in `game/assets/rework/overworld_cast.png`.
- **Town:** `game/assets/ChatGPT Image Aug 6, 2026, 02_02_04 AM (8).png`.
- **Torch:** `game/assets/ChatGPT Image Aug 6, 2026, 02_02_04 AM (5).png`.
- **Portrait(archetype):** `game/assets/portraits/townsfolk/<archetype>/neutral.png`.
- **Walker(archetype):** `game/assets/characters/townsfolk/<archetype>/overworld.png`.

## Required character classification

A = established design: preserve and translate. B = partial/conflicting design:
consolidate the specified references, never freely redesign. C = no established
artwork: new design required. **No required Greymere character is category C.**

| Current character | Class | Legacy identity | Existing references used | Identity to preserve |
| --- | --- | --- | --- | --- |
| Kai, all six classes | A | Aren, Aren Vale, `aren/<class>` | Classes; `rework/kai_overworld.png`; class bible | Same youthful face, warm light skin, tousled brown hair and build in every class; exact class outfit and equipment from Classes |
| Warden Almyra | A | Elara Thorne, `elara` | Cast; rework directional cast; Aug 6 02:02 (1); legacy elara portrait/battle | Long silver hair, light skin, steel plate, blue tabard/cape, sword and blue shield; preserve current gold details |
| Liora Sen | B | Mira Solen, `mira` | Cast and its portrait crop; rework directional cast; legacy mira sources compared, not blended | Long dark wavy hair, existing complexion, burgundy/cream scholar robes, gold trim and book from current Cast |
| Joey | A | Toby, `townsfolk/farmboy` | Portrait(farmboy); Town upper-left pair; Walker(farmboy) | Brown short tousled hair, youthful light face, cream sleeves, brown vest/tunic, belt, dark trousers and brown boots |
| Lena | A | Wren, `townsfolk/herbalist_woman` | Portrait(herbalist_woman); Town upper row second pair; Walker(herbalist_woman) | Brown hair gathered behind, light face, green dress, cream apron and sleeves, simple brown footwear; no mage redesign |
| Elder Silas | A | Elder Kassian, Kassius, `townsfolk/village_elder` | Portrait(village_elder); Town white-haired elder pairs; Walker(village_elder) | Elderly light face, white hair and beard, brown belted robe with cream front, modest boots; no invented wizard gear |
| Gell | B | Pell, `townsfolk/farmhand_capped` | Portrait(farmhand_capped); Town lower-left green-capped pair; Walker(farmhand_capped) | Green cap, brown hair, light face, green workwear, cream sleeves, brown belt/pouch/boots; merchant role does not imply a new costume |
| Danfor | A | Town Guard, `townsfolk/guard_sword` | Portrait(guard_sword); Town sword-guard pairs; Walker(guard_sword) | Ridged steel helmet, visible light face, blue tabard, steel shoulders, belt, sword and shield; retain helmet rather than invent hair |
| Watchman Orrin | A | `townsfolk/guard_spear` | Portrait(guard_spear); Town lower-right pair; Walker(guard_spear) | Same established guard uniform language, spear and shield; do not borrow Danfor's sword |
| Goodwife Senna | A | `townsfolk/elder_woman` | Portrait(elder_woman); Town middle-row third pair; Walker(elder_woman) | Elderly light face, white/grey hair, brown dress, cream apron and collar; distinguish from Silas's beard and robe |
| Old Ferris | B | `townsfolk/torch_bearer` | Portrait(torch_bearer); Torch; Walker(torch_bearer) | Existing dark hood, brown layered belted clothing, torch; face remains concealed, not a newly invented elderly face |
| Hooded Stranger | A | `townsfolk/hooded_stranger` | Portrait(hooded_stranger); Town lower-row second pair; Walker(hooded_stranger) | Brown hood and cloak, concealed face with existing pale eye marks, belt and boots; not a purple-robed new character |

## Conflicts resolved explicitly

1. **Kai:** the six Aug 3 loose sheets and legacy portraits are earlier class
   designs. Their hooded Mage/Sorcerer and bow-carrying Neutral conflict with the
   explicitly approved bare-face, robe-led magic classes and sword-plus-Verdant
   magic contract. Use Classes as authority. `kai_overworld.png` corroborates
   hair and four facings but omits some equipment and over-armours Sorcerer;
   it must not override the class portrait/battle design. No blue-cape baseline
   from the older cast sheet replaces Neutral's green-accented field jacket.
2. **Liora:** original Aug 6 (2), legacy portrait and battle show dark-blue robes
   and a cyan staff. The current authored Cast portrait and directional sheet
   agree on burgundy/cream robes and a book. Choose that complete current version,
   not blue armour combined with a red book outfit. The procedural orange/brown
   walker is rejected as an identity source. This decision is recorded as B
   because two genuine authored versions exist.
3. **Almyra:** preserve long silver hair shown consistently in authored sources.
   The flat grey block/short-haired v2 walker is not a new canonical haircut.
4. **Gell:** Town includes more than one capped variant, including a white-backed
   cap. Choose the lower-left green-cap pair, consistent with his portrait; do not
   combine the white headwrap variant or the procedural bare head.
5. **Ferris:** story name suggests an older resident, but all assigned art has a
   concealed, glowing-eyed hooded face. Keep the documented hooded visual pending
   an explicit story/art decision. Do not invent skin, hair or a beard underneath.
   The portrait's eye treatment is reference, not evidence of a new supernatural
   story fact. Keep this as a visible review item.
6. **Silas:** the two white-haired elder variants on Town are consistent enough
   to use the existing portrait/Walker pair as tie-breaker. Never map him to the
   separate elder-woman design. His rename changes no physical identity.

## Loose artwork inventory

All files below have the prefix `game/assets/ChatGPT Image ` and suffix `.png`.

| Date/time and numbered suffix | Inspected contents | Relevance |
| --- | --- | --- |
| Aug 3, 2026, 07_44_40 PM (1) | Original crimson sword hero | Legacy Kai Warrior |
| Aug 3, 2026, 07_44_41 PM (2) | Original blue shield hero | Legacy Kai Guardian |
| Aug 3, 2026, 07_44_42 PM (3) | Gold hood/staff hero | Legacy Kai Mage, superseded |
| Aug 3, 2026, 07_44_42 PM (4) | Violet hood/staff hero | Legacy Kai Sorcerer, superseded |
| Aug 3, 2026, 07_44_43 PM (5) | Dark scarf/dual blades hero | Legacy Kai Assassin |
| Aug 3, 2026, 07_44_44 PM (6) | Green hood/bow hero | Legacy Kai Neutral, superseded |
| Aug 6, 2026, 02_02_04 AM (1) | Silver-haired blue-armoured sword/shield woman | Almyra |
| Aug 6, 2026, 02_02_04 AM (2) | Dark-haired blue-robed staff woman | Earlier Liora |
| Aug 6, 2026, 02_02_04 AM (3) | Cyan spectral quadruped | Entity, not a resident |
| Aug 6, 2026, 02_02_04 AM (4) | Horned dark raider | Enemy, not a resident |
| Aug 6, 2026, 02_02_04 AM (5) | Hooded torch bearer | Ferris's assigned archetype |
| Aug 6, 2026, 02_02_04 AM (6) | Hooded red-focus caster | Enemy, not Liora or Ferris |
| Aug 6, 2026, 02_02_04 AM (7) | Red-haired green-scarf fighter | Enemy, not Joey |
| Aug 6, 2026, 02_02_04 AM (8) | Townsfolk front/back reference pairs | Primary resident costume reference |
| Aug 6, 2026, 06_30_08 PM (1) | Cyan crystalline insect entity | Not a resident |
| Aug 6, 2026, 06_30_08 PM (2) | Ash winged entity | Not a resident |
| Aug 6, 2026, 06_30_09 PM (3) | Spectral antlered entity | Not a resident |
| Aug 6, 2026, 06_30_09 PM (4) | Blue spectral lion entity | Not a resident |
| Aug 6, 2026, 06_30_09 PM (5) | Armoured tortoise entity | Not a resident |

## Animation production gate

The reference audit is complete; replacement animation production is not.
For each replacement, attach the exact selected source image, name the character
and selected region, and preserve the whole design in four explicit facings.
Use a complete idle/step/contact/step cycle with consistent scale and foot pivot.
Do not simulate authored walking by copying one pose, rocking a static image or
mirroring equipment inconsistently. Do not upscale the procedural v2 pixels.

Before a new sheet can replace a runtime entry, inspect every frame at source
size and 320x180 gameplay size, compare its portrait and battle identity, test
all four movement directions, confirm alpha edges/feet and equipment continuity,
and capture the real town and each interior. No approval follows merely from a
valid atlas rectangle. Keep incomplete sheets off the production path.

The current procedural v2 assets remain a known visual limitation until these
replacement sheets pass this gate. Combat, class balance, portrait art and story
are not changed by this audit.
