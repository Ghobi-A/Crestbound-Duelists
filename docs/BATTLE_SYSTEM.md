# Battle System

Crestbound Duelists uses **variable-size, round-based party battles**.
There is no movement grid: positioning is decided before the fight,
and every in-battle decision is about action commitment, targeting,
and prediction.

## Encounter shapes

Encounters are data (`data/encounters.yaml` → `encounters.json`).
Each defines `player_slots` and `enemy_slots` (1–3 per side, symmetric
or not), the enemy party builds, pre-battle positioning, a battlefield
effect, an objective, and dialogue hooks. The engine instantiates
whatever the data asks for — the same code runs:

| Shape | Prototype encounter | Feel |
|-------|--------------------|------|
| 1v1 | `serin_first_duel` (debug/data) | Personal, prediction-heavy formal duel |
| 2v2 | `veyrhold_pair_trial` (debug/data) | Partnership and synergy |
| 3v3 | `hollow_court_battle` (story) | Full-party encounter |
| 2v3 | `archive_ambush` (debug/data) | Asymmetric ambush |

The battle scene, HUD status rows, staging layout, targeting, and AI
all scale from the encounter data — nothing assumes three panels.

## Round structure

```text
ROUND START
  Player commits one action per living Duelist
    (Basic / Signature / Gambit / Brace, then a target)
  Round plan shown  →  CONFIRM (or Back to revise)
  Enemy AI commits actions
RESOLUTION
  All actions resolve in initiative order:
    1. Brace commitments (always first — defensive stances set up)
    2. Everything else by probabilistic speed:
       score = SPD + U(0, speed_band)
       — v2.2 uses speed_band = 20
       — a gap ≥ speed_band guarantees order; closer speeds remain uncertain
ROUND END
  Cooldowns tick, stat modifiers decay, statuses tick,
  Brace expires, Resonance/awakening checks, victory/defeat check
```

Dead Duelists are removed from selection; committed actions against a
target that fell mid-round retarget to a random living enemy.

## Actions

| Action | Identity |
|--------|----------|
| **Basic** | Reliable, repeatable — 100% accuracy, no cooldown |
| **Signature** | Class-defining tactical action — debuffs, buffs, Hex; cooldown |
| **Gambit** | High-impact, higher-risk — more power, less accuracy; cooldown |
| **Brace** | Defensive commitment: multiplies defence until your next turn; feeds some Crests' Resonance. Using it costs your offensive action — that trade-off is the point. |

A configured cooldown of `1` means the move is **unavailable for the
next decision round**. Cooldowns are stored with one extra internal tick
because the lifecycle decrements them at round end; this prevents the
round of use from immediately consuming the entire cooldown.

The action menu shows cooldowns (`CD n`) and Hex blocks
(`Blocked by Hex`) explicitly. Target selection previews estimated
damage, hit chance, and rider effects.

### v2.2 class-action identities

- **Warrior — Armor Break:** stronger DEF break and a guard-breaking hit
  that ignores Brace for its own damage calculation.
- **Mage — Mind Pierce:** stronger RES break and the magical equivalent
  of a guard-breaking hit.
- **Assassin — Cripple:** now reduces SPD as well as DEF/RES, making
  initiative manipulation part of its precision/setup identity.
- **Guardian — Fortify:** larger DEF/RES gain so the defensive Signature
  produces material mitigation under the compressed damage formula.
- **Neutral — Focus Shift:** stronger offensive shift with an explicit
  defensive trade-off; under Hex the positive half is suppressed while
  the negative half still applies.
- **Sorcerer — Hex:** blocks dedicated buff moves, removes active positive
  stat modifiers when applied, and suppresses new positive stat changes
  while active.

Every Gambit is intentionally above its class Basic on raw
`power × accuracy` expected value. Its cost is instead expressed through
miss variance, the real cooldown window and, where applicable, a self-debuff.

## Positioning (pre-battle only)

The party setup screen assigns each Duelist to **FRONT** or **BACK**
and orders the party (the first N members fill the encounter's active
slots). In battle there is no movement.

Row rules (advantages and trade-offs, not hard punishment):

- Close-range moves (`range: 1`) deal **and** receive ×0.75 damage
  when crossing to/from the back row. Ranged moves ignore rows.
- Back row suits Mages/Sorcerers; front row suits melee and Guardians.

Future row-touching abilities (Intercept, Vanguard, Displace) are
special combat effects, not a movement system.

## Combat math

Identical to the Python Balance Lab, from exported data only:

```text
damage = power × 2·ATK/(ATK+DEF) × U(variance_low, variance_high)
         × crest passives × row rules × entity/battlefield modifiers,
         minimum 1
```

Braced defence is multiplied by `brace_multiplier`; v2.2 uses **1.20×**
(+ any Azure bonus). At equal attacking and defending stats this is
roughly a 9% incoming-damage reduction rather than the ~2% produced by
the old 1.05 multiplier.

Hex blocks dedicated buff actions, strips active positive stat modifiers
when applied, and suppresses positive stat changes while active. Negative
trade-off modifiers are not erased by Hex. Stat modifiers decay after
`stat_decay_duration` rounds.

## Stateful balance / Nash model

The original v2.1 research matrix used

```text
A[i,j] = E[damage_A(move_i)] - E[damage_B(move_j)]
```

which has the separable form `f(i) - g(j)`. That construction makes each
player's best action independent of the opponent's chosen action, so its
pure equilibria were not evidence that execution randomness itself
eliminated strategic mixing.

v2.2 instead estimates a finite-horizon state-action value:

```text
Q(s, a_i, a_j)
```

by forcing each joint opening action pair and running seeded three-round
continuations through the real combat transition system. The state carries
HP, cooldowns, stat modifiers, statuses/Hex and initiative/Brace effects.
The resulting matrix can therefore be non-separable, and mixed policies —
when they appear — are an empirical property of interaction rather than a
mathematical artifact of the payoff definition.

## Resonance and awakening

Every Crest defines its own Resonance gains over canonical battle
events (`data/crests.yaml → resonance_gain`): Azure feeds on Bracing,
absorbing, and protecting; Crimson on fighting wounded; Glass on
landed Gambits; Ember on magical pressure against the weakened;
Eclipse on statuses; Verdant on variety. The 0–100 meter is visible
per Duelist.

**Awakening** = crest condition **and** `min_resonance`, once per
battle, presented with a screen flash and banner. Functional effects:

- **Crimson** — empowered Gambit: +25% power and 50% lifesteal.
- **Azure** — counter stance: +4 DEF/RES and 30% damage reflection.
- Eclipse (Hex saturation) and Glass (perfect edge) are wired in the
  resolver; Ember/Verdant effects are data-complete but inert.

Battlefield effects modify the whole encounter (never tiles): the
Hollow Court's dormant node multiplies Resonance gains after round 3;
the archive's Restricted Sigils shorten stat-modifier durations.

## Bonded Entities

Entities are manifestations (translucent sprites behind their
Duelist), not party slots. Functional passives: Storm Lion may
intercept a hit aimed at an ally; Iron Tortoise extends Brace by a
round; Ash Seraph gains damage on ruin-tagged battlefields. Other
entity passives are defined in data but dormant.

## Enemy AI

A greedy heuristic (in the spirit of the Balance Lab's greedy policy)
scoring every available move × target: expected damage × accuracy,
a large kill bonus, value for fresh statuses (Hex) and debuffs, and
reluctance to self-weaken when wounded. It reads the same exported
data as the player's UI and works at any party size.

## Current limitations

- The v2.2 balance pass deliberately leaves the six class statlines
  unchanged. Individual-stat tuning should follow the regenerated matchup
  matrix rather than precede the structural fixes.
- Ember's scorched-ground and Verdant's overgrowth awakening effects
  are not implemented (data only).
- Entity `granted_move` abilities and awakened entity forms are not
  yet usable in battle.
- Only the defeat-all objective is implemented; hold/survive/protect
  objectives exist in data.
- 1v1/2v2/2v3 encounters are engine-supported and defined in data but
  not reachable through the story flow yet.
- The old grid-tactics battle was **removed** (not archived) in the
  pivot commit `refactor: replace grid tactics with variable-size
  party battles`; it remains available in git history. Terrain data
  stays exported for future battlefield styling.
