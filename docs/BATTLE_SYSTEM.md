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

The same in both runtimes (`party_combat.py` and the Godot battle layer),
from exported data only:

```text
damage = floor(power × 2·ATK/(ATK+DEF) × multipliers
               × (variance_low + (variance_high − variance_low)·u)), minimum 1
multipliers = Crest passives (+ Verdant variety, awakening bonuses)
            × row rules (close moves into/out of the back row)
            + Entity and charm bonuses
            × affinity (weak ×1.3, resist ×0.75)
            × Grave Stag (a hexed attacker deals −10% to its bearer's side)
            × 0.5 for a telegraphed attack released into a Brace
```

`u` is one draw from the battle's dice stream. Braced defence is
multiplied by `brace_multiplier` (**1.15×**, plus any Azure bonus) unless
the move breaks guard or a charm pierces it.

Hex blocks dedicated buff actions, strips active positive stat modifiers
when applied, and suppresses positive stat changes while active. Negative
trade-off modifiers are not erased by Hex. Stat modifiers decay after
`stat_decay_duration` rounds.

## Combat System 3.0

Every rule here is implemented in the Python reference engine
(`party_combat.py`) and the Godot runtime (`game/scripts/battle/`), with
values in YAML. Replay parity (`tools/generate_combat_parity.py` →
`game/data/combat_replays.json`, checked by `combat_parity_smoke.gd`)
records whole seeded battles in Python and requires Godot to reproduce
them event for event.

- **Dice.** Every random draw (initiative, accuracy, damage, interception,
  retargeting, AI noise) comes from one stream of integers in [0, 2^24),
  in the same order in both runtimes.
- **Attack properties and affinities.** Each move is Impact, Edge or
  Arcane. A unit's affinity profile (weak and resist) comes from its
  Crest (`affinity_profile`), its charm, or an authored override for
  beasts and bosses. A weakness hit **Staggers**: the target loses Brace
  for the round and a pending telegraph slips a round. *Exposed* makes
  every property a weakness.
- **Loadouts.** Classes keep their default kit (`move_ids`) and gain one
  alternative per slot (`unlockable_moves`). Units equip up to four moves:
  Basic, Signature, Gambit and Flex. Alternatives trade power, accuracy,
  initiative (`speed`), riders and Resonance rather than strictly
  improving. Brace is always available.
- **Awaken** is a command, not an automatic trigger: available once the
  meter reaches the Crest's `min_resonance` and its condition holds,
  once per battle, at Brace priority, lasting `duration` rounds
  including the round it is used.
- **Telegraphs.** A move with `telegraph: true` winds up for a round
  (shown on screen) and lands the next. Brace halves it, a weakness hit
  delays it, and knocking out the caster cancels it.
- **Objectives.** `eliminate`, `defeat_target` (enemies tagged `target`),
  `survive` (`turns_required`) and `protect` (losing a `protected` unit
  loses the battle). Encounters override parameters with
  `objective_params`.
- **Bosses** have `stat_scale` and `phases`: HP- or round-triggered,
  each with its own moves, AI profile, rotation, affinity, entry move,
  entry statuses, an optional summon and a banner.
- **Items** in battle use the Item command (`data/items.yaml`
  `battle_effect`): heal, cure, Resonance or revive.
- **Charms** (`data/equipment.yaml`) change affinities, initiative,
  property damage or Resonance, or let Edge hits pierce Brace.
- **Named builds** (`data/cast.yaml`): Kai's provisional kits, allies,
  and the chapter's enemies and bosses. Encounters reference them with
  `build:`.

## Resonance and awakening

Every Crest defines its own Resonance gains over canonical battle
events (`data/crests.yaml → resonance_gain`): Azure feeds on Bracing,
absorbing, and protecting; Crimson on fighting wounded; Glass on
landed Gambits; Ember on magical pressure against the weakened;
Eclipse on statuses; Verdant on variety. The 0–100 meter is visible
per Duelist.

**Awakening**: the Awaken command, once the Crest's condition holds and
the meter reaches `min_resonance`. Once per battle, presented with a
screen flash and banner. Effects:

- **Crimson:** empowered Gambit, +25% power and 50% lifesteal.
- **Azure:** counter stance, +4 DEF/RES and 30% damage reflection.
- **Eclipse:** Hex saturation; Hex also pushes back used cooldowns.
- **Ember:** scorched ground; hits leave the target Scorched (4 per round).
- **Glass:** perfect edge; never miss, +15% power.
- **Verdant:** overgrowth; +initiative and a +3 stat bloom rotating each
  round.
- **Unsettled** (Kai before Civara): Resonance surge; +20% power, the next
  hit Exposes, and 5% max HP recoil each round.

Generic Resonance (`combat_config.yaml generic_resonance`) rewards every
Crest-bearer for a weakness hit (+10) and for Bracing a telegraph (+8).

Battlefield effects modify the whole encounter (never tiles): the
Hollow Court's dormant node multiplies Resonance gains after round 3;
the archive's Restricted Sigils shorten stat-modifier durations.

## Bonded Entities

Entities are manifestations (translucent sprites behind their Duelist),
not party slots. All six passives work:
- Storm Lion may intercept a hit aimed at an ally.
- Iron Tortoise extends Brace by a round.
- Ash Seraph hits harder on ruin- or scorched-tagged battlefields.
- Glass Mantis presses a target already hit this round.
- Mirror Fox copies a buff the other side gives itself.
- Grave Stag weakens hexed attackers.

Granted moves (equipped when the bearer's build doesn't specify moves):
Lionfall Verdict, Bulwark Protocol, Procession of Antlers and Prism
Severance. Ash Seraph's and Mirror Fox's granted moves, and awakened
Entity forms, are later work.

## Enemy AI

Behaviour profiles in `combat_config.yaml ai_profiles` weight each
(move, target) candidate:
- **legacy:** the original greedy policy.
- **aggressive:** damage and finishing.
- **defensive:** Braces when hurt.
- **disruptive:** statuses, debuffs, and targeting high Resonance.
- **opportunistic:** finishes wounded targets, punishes Exposed or
  Staggered ones.
- **boss:** follows the phase rotation.

Profiles react to a repeat Bracer (guard-break value), protected units
and buffs (dispel value), with a small seeded noise term. It reads the
same exported data as the player's UI and works at any party size.

## Current limitations

- The class statlines are unchanged from v2.3; vertical-slice tuning is
  driven by the party-engine simulations in the snapshot.
- Ash Seraph's and Mirror Fox's granted moves and awakened Entity forms
  are not implemented.
- The `hold_tile` objective is grid-era data and not used.
- The old grid-tactics battle was **removed** (not archived) in the
  pivot commit `refactor: replace grid tactics with variable-size
  party battles`; it remains available in git history. Terrain data
  stays exported for future battlefield styling.
