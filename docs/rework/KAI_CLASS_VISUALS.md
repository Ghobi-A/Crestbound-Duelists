# Kai: class visual contract

Approved direction: class changes equipment, silhouette and Crest expression, never
Kai's identity. Keep his brown tousled hair, youthful adult face, skin tone and body
proportions across portraits, overworld and combat. No helmets or hoods hiding him.
The six existing gameplay classes and their balance remain authoritative.

| Class | Crest | Accent | Weight | Principle |
| --- | --- | --- | --- | --- |
| Warrior | Crimson | Crimson red | Medium | Pressure |
| Guardian | Azure | Deep azure/cobalt | Heavy | Endurance |
| Mage | Ember | Burnt orange/amber | Light | Projection |
| Sorcerer | Eclipse | Violet-black | Very light | Manipulation |
| Assassin | Glass | Ice-cyan/silver-white | Very light | Precision |
| Neutral | Verdant | Deep emerald | Medium-light | Adaptation |

Colours belong in lining, stitching, straps, small cloth panels and Crest glow.
Base materials remain charcoal, cream cloth, dark leather and steel. Never tint the
entire character to identify a class.

## Equipment and silhouettes

- **Warrior:** shoulder/forearm emphasis, asymmetric dark iron pauldron, reinforced
  upper torso, short aggressive jacket, leather waist protection, lightly guarded
  knees and heavy boots. Exposed joints preserve mobility. Lean forward to apply
  pressure; crimson runs underneath armour. Advance, strike, break, overwhelm.
- **Guardian:** square, symmetrical brushed-steel shoulders and breastplate, large
  gauntlets, hip/shin armour, heavy boots, long split tabard. A narrow azure cloth
  panel runs vertically. Planted stance: anchor, intercept, endure, protect.
- **Mage:** long vertical cloth tunic/robe with split coat panels, cream protective
  underlayer, reinforced cloth shoulders, casting gloves, high boots and brass
  belt focus. No conventional plate suit. Amber geometry follows seams, subtle
  when idle and bright during casting. Channel, project, shape, overwhelm.
- **Sorcerer:** minimal armour, asymmetric layered tunic/robe, unequal sleeves and
  hanging cloth, one reinforced arm, focus attachments, blackened silver details.
  Violet Crest markings spread beyond their origin without body horror or an
  "evil Kai" transformation. Distort, infect, suppress, manipulate. Effects should
  bend existing auras, drain colour or reverse particles rather than copy Mage
  projectiles.
- **Assassin:** narrow fitted short jacket and trousers, segmented rib protection,
  slim bracers, gloves, light knees and flexible boots. Minimal shoulder armour,
  small crystalline sections, no oversized hood or decorative belts. Observe,
  accelerate, pierce, finish; exploit an opening rather than force one.
- **Neutral:** canonical field-jacket silhouette, modest shoulder guard, two bracers,
  light chest reinforcement, utility belt and reinforced boots. Modular equipment
  communicates adaptability. Sword in one hand, controlled Verdant glyph magic in
  the other: compact guard/pulse motifs and a fine blade enchantment. Balanced,
  responsive posture distinguishes this sword-and-magic hybrid from Warrior's
  forward pressure. These are presentation motifs, not new combat actions or
  balance changes. Assess, adjust, respond, exploit.

## Integration and acceptance

Stable `aren/<class>` save keys resolve to distinct canonical presentation records.
Each record owns its atlas, portrait crop, foot anchor and directional overworld
sheet. UI must ask the same registry rather than choose outfits independently.
Portraits use the face from the corresponding outfit, not unrelated portrait art.

Verify all six in class selection, party setup, dialogue, four overworld directions
and on both battle sides. Check bare-face identity, cloth-led magic outfits, subtle
accents, exact foot placement, transparent edges and viewport-scale readability.
Static directional poses are not authored walk cycles; generated battle poses are
not a full animation set. Those require separate animation and rendered QA passes.
