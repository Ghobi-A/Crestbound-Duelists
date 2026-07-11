# Game Design Foundation

## What Crestbound Duelists is

A pixel-art turn-based party RPG where human Duelists bind themselves
to **Crests** (fragments of a dead god) and **Bonded Entities**
(manifestations of the Duelist–Crest relationship), producing distinct
builds, battle roles, and awakening paths — fought in variable-size
encounters (1v1 duels through 3v3 party battles and asymmetric fights).

Inspirations — collection/team-building readability (Pokémon),
party combat and spectacle (Final Fantasy) — inform the shape, not
the content. Nothing is copied; Crestbound is not "Pokémon with
different names", and after the combat pivot it deliberately no longer
plays like "Fire Emblem with Crests": there is no movement grid.

## Core pillars

1. **Builds over creatures.** A unit is
   `Character + Class + Crest + Bonded Entity + Trait + Move Kit`.
   Same class + different Crest/Entity = meaningfully different unit.
2. **Commitment over movement.** The tactical questions are: who do I
   bring, where do I position them before the fight, which action do
   I commit, who do I target, what will the enemy do, do I attack,
   Brace, set up, or gamble — and can I trigger my Crest?
3. **Simulation-backed balance.** Every number in the game is exported
   from a Balance Lab that can Monte Carlo it first.
4. **A world with weight.** Crests are politically dangerous; battles
   have narrative context (see LORE_BIBLE.md).

Battle mechanics in detail: `docs/BATTLE_SYSTEM.md`.

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

## Battle mechanics (prototype scope)

- Variable-size encounters (1v1 / 2v2 / 3v3 / asymmetric), data-defined
- Round-based: commit actions for the whole party, then resolution by
  initiative (Brace first, then probabilistic speed)
- Pre-battle **front/back positioning** with clear row rules — no
  in-battle movement, no grid
- **Brace**: a visible defensive commitment — defence multiplied for
  the round (Azure improves it, Iron Tortoise extends it)
- **Hex**: blocks buff actions and self-strengthening while active
- **Resonance**: per-crest 0-100 meter fed by crest-specific behaviour;
  gates awakening together with the crest's condition
- Cooldowns gate Signature/Gambit reuse
- Battlefield conditions affect the whole encounter (never tiles)
- Objective-driven wins (defeat-all now; hold/survive/protect in data)
