# Game Design Foundation

## What Crestbound Duelists is

A pixel-art tactical RPG where human Duelists bind themselves to
**Crests** (fragments of a dead god) and **Bonded Entities**
(manifestations of the Duelist–Crest relationship), producing distinct
builds, tactical roles, and awakening paths.

Inspirations — collection/progression (Pokémon), grid tactics/terrain
(Fire Emblem), classes/Gambits/awakenings (Final Fantasy) — inform the
shape, not the content. Nothing is copied; Crestbound is not
"Pokémon with different names".

## Core pillars

1. **Builds over creatures.** A unit is
   `Character + Class + Crest + Bonded Entity + Trait + Move Kit`.
   Same class + different Crest/Entity = meaningfully different unit.
2. **Tactics over stats.** Positioning, terrain, initiative, Brace,
   Hex, cooldowns, and objectives decide battles.
3. **Simulation-backed balance.** Every number in the game is exported
   from a Balance Lab that can Monte Carlo it first.
4. **A world with weight.** Crests are politically dangerous; battles
   have narrative context (see LORE_BIBLE.md).

## Move identity: Basic / Signature / Gambit

| Slot | Meaning | Properties |
|------|---------|-----------|
| Basic | Reliable, repeatable action | 100% accuracy, no cooldown |
| Signature | Class-defining tactical action | Effects (debuffs, buffs, Hex), cooldown |
| Gambit | High-impact, higher-risk action | High power, reduced accuracy, cooldown |

Classes must never collapse into generic attack buttons.

## Class identities

| Class | Role | Tactical direction |
|-------|------|--------------------|
| Warrior | Physical bruiser, frontline pressure | Guard breaking, charges, cleave |
| Mage | Magical specialist, area control | Resistance breaking, AoE, terrain effects |
| Assassin | Fast striker, flanker | Backstab/flanking bonuses, debuff finishing |
| Guardian | Tank, defensive anchor | Brace synergy, intercepts, protection |
| Neutral | Adaptive generalist (rare) | Adaptive damage, stance shifting |
| Sorcerer | Fast curse specialist | Hex, buff denial, cooldown interference |

## Crests

Crests carry an innate nature and **alter behaviour**, not just stats:

- Crimson — rewards fighting wounded (low-HP damage, empowered Gambit awakening)
- Azure — rewards patience (Brace bonus, counter-stance awakening)
- Eclipse — deepens curses (status duration, Hex saturation awakening)
- Ember — punishes the weakened (bonus vs debuffed, scorched-ground awakening)
- Glass — risk/reward edge (deal more/take more, perfect-edge awakening)
- Verdant — rewards variety (non-repeat bonus, overgrowth awakening)

**Awakening** is earned in battle (surviving hits, dropping below
thresholds, applying statuses, landing Gambits, varying actions) — an
expression of the bearer's relationship with the Crest, not a level-up.

## Bonded Entities

Not pets, not captures. Spirits, relic machines, ancestral beings,
living weapons — produced by the bond, unique to the relationship.
They grant passives and (later) moves; awakened forms exist in data.

Collection comes from Crests, Crest fragments, Entities, build
combinations, and rare synergies — not from filling a monster box.

## Tactical mechanics (prototype scope)

- 8x6 grid, 3v3, phase-based rounds (player phase / enemy phase)
- Movement by points over terrain costs; terrain grants DEF/RES
- **Brace**: a visible defensive action — defence multiplied until the
  unit's next activation (Azure improves it)
- **Hex**: blocks buff actions and self-strengthening while active
- Cooldowns gate Signature/Gambit reuse
- Objective-driven wins (defeat-all now; hold-the-node and others in data)
