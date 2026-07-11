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
       — a gap ≥ speed_band guarantees order; close speeds stay
         uncertain (preserves the Balance Lab's speed-band spirit)
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

The action menu shows cooldowns (`CD n`) and Hex blocks
(`Blocked by Hex`) explicitly. Target selection previews estimated
damage, hit chance, and rider effects.

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

Braced defence is multiplied by `brace_multiplier` (+ Azure bonus).
Hex blocks buff-type actions and self-strengthening while active.
Stat modifiers decay after `stat_decay_duration` rounds.

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
