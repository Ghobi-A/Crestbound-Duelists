# Crestbound Duelists — RPG Transformation Plan

## Purpose

This document defines how to evolve **Crestbound Duelists** from its current state as a Python-based combat simulation and decision-system experiment into a playable tactical RPG with monster-collecting/JRPG DNA.

The goal is **not** to make a Pokemon clone.

The target identity is:

> **A tactical crest-collecting RPG where Duelists bind themselves to Crests, classes, spirits, and archetypal entities, then fight in strategic battles shaped by positioning, class identity, team composition, status effects, and long-term progression.**

The current repository should be treated as the **combat and balance laboratory**. The playable RPG should be built around it, not by throwing it away.

---

## Current Repository State

The repository currently contains a working turn-based combat simulation framework.

### Existing strengths

The current codebase already includes:

- Six asymmetric combat classes.
- Three move slots per class: Basic, Signature, and Gambit.
- Probabilistic speed resolution.
- Damage variance.
- Cooldowns.
- Buffs and debuffs.
- Temporary stat modifiers.
- Status effects such as Hex.
- A 1v1 battle loop.
- AI policies.
- Monte Carlo simulation tooling.
- Nash/maximin analysis for single-turn strategy.
- CSV battle log export for downstream analysis.
- Generated visual analysis outputs.

This is a strong systems foundation. Most indie RPG ideas start with worldbuilding and no combat model. Crestbound is the reverse: it already has a testable rules engine.

### Existing limitation

The repository is currently framed as:

> A data science case study in adversarial decision-making under stochastic execution.

It is **not yet a game project**.

There is no:

- Playable client.
- User interface.
- Game loop.
- Exploration layer.
- Party system.
- Progression system.
- Save/load system.
- Narrative content system.
- Asset pipeline.
- Map/dungeon/town structure.
- Animation or VFX layer.

That means the next step is not to “add graphics” directly. The next step is to define the RPG architecture around the existing simulation model.

---

## Core Design Pillars

### 1. Tactical identity over imitation

Crestbound should share some successful creature-RPG pillars:

- Collection.
- Team building.
- Progression.
- Rival battles.
- Rare encounters.
- Elemental/class affinities.
- Party customisation.

But it should avoid the obvious clone markers:

- No Pokeball-equivalent capture loop.
- No gym badge formula.
- No starter trio that maps one-to-one onto Grass/Fire/Water.
- No four-move-only monster battle template.
- No route-town-gym-route progression copy.

Instead, battles should be closer to:

- **Fire Emblem**: positioning, terrain, unit identity, squad-based tactics.
- **Final Fantasy**: jobs, limit breaks, summons, class fantasy, boss phases.
- **Pokemon**: collection, team composition, affinity systems, evolution/awakening.

### 2. The Crest system must be the differentiator

The word **Crestbound** should not just be branding. It should be the central mechanic.

A unit is not just a creature or a class. A unit is a **Duelist bound to a Crest**.

Each playable unit should be defined by:

```text
Duelist = Character + Class + Crest + Bonded Entity + Trait + Move Kit
```

Example:

```text
Name: Kael
Class: Guardian
Crest: Azure Crest
Bonded Entity: Storm Lion
Role: Defensive initiator
Passive: Brace also charges Counterforce
Signature: Thunder Rampart
Gambit: Lionfall Verdict
```

This lets one class behave differently depending on the Crest attached to it.

For example:

```text
Guardian + Azure Crest = defensive lightning counter-tank
Guardian + Eclipse Crest = curse/hex shield specialist
Guardian + Verdant Crest = sustain/regen wall
Guardian + Crimson Crest = reckless bruiser tank
```

This avoids the knockoff problem because collection is not just “catch monster, use monster”. It becomes:

> Find Crests, bind them to Duelists, unlock entity forms, and build tactical identities.

### 3. The current simulation stays valuable

The existing Python simulation should remain the **Balance Lab**.

Its role:

- Prototype moves.
- Simulate matchups.
- Evaluate win rates.
- Compare AI policies.
- Generate balance data.
- Detect dominant strategies.
- Export battle logs.
- Support tuning before implementing in the playable game.

The playable RPG should eventually consume data exported from this balance layer.

---

## Recommended Product Shape

### Working title

**Crestbound Duelists: Proving Grounds**

This keeps the first playable release scoped. It does not promise the full world immediately.

### Target format

A tactical RPG vertical slice with collection and party-building systems.

Recommended first format:

```text
2D or 2.5D tactical RPG
Grid-based battles
Small overworld/hub structure
Data-driven combat rules
Python balance lab retained separately
```

### Recommended engine

For the first playable version, the recommended engine is:

```text
Godot 4
```

Reasoning:

- Lightweight.
- Solo-dev friendly.
- Strong for 2D/2.5D.
- Fast iteration.
- Good for grid-based tactical RPGs.
- Easier to keep scope under control than Unreal.

Alternative:

```text
Unity
```

Use Unity if marketplace assets, tutorials, or external contractors become more important.

Avoid Unreal for the first slice unless the project pivots heavily toward 3D cinematic presentation. Unreal would increase the asset burden too early.

---

## MVP Scope

The first playable version should be a **vertical slice**, not a full RPG.

### Vertical slice target

```text
1 hub area
1 route/field area
1 dungeon/combat arena
6 base classes
12 Crests
12-18 bonded entities
3 playable party slots
8-12 enemy archetypes
3 boss fights
1 rival character
1 major story objective
Level cap around 10-15
30-60 minutes of polished gameplay
```

The aim is to prove:

- Is the battle loop fun?
- Does the Crest system feel different from Pokemon?
- Does team-building have depth?
- Is the world identity strong enough?
- Can the current combat engine scale into a real game?

### What should not be in the MVP

Do not include these at first:

- Online PvP.
- Open world.
- Hundreds of Crests/entities.
- Procedural world generation.
- Massive dialogue trees.
- Romance/support systems.
- Crafting.
- Multiplayer trading.
- Complex economy.
- Dozens of towns.
- Full voice acting.
- 3D cinematic cutscenes.

These are expansion features, not slice features.

---

## Game Concept

### Premise

In the world of Crestbound, certain people are born capable of binding with ancient symbolic powers known as **Crests**. A Crest is not just magic; it is a pact, inheritance, burden, and combat identity.

Crests can awaken bonded entities: beasts, spirits, weapons, masks, saints, devils, machines, or mythic avatars depending on the Crest line.

A Duelist does not “own” their power. They negotiate with it.

### Core fantasy

The player builds a squad of Duelists and Crest-bound entities, then uses them in tactical battles where class, positioning, speed, buffs, debuffs, and risk management matter.

The player is not collecting pets. The player is assembling combat identities.

### Tone

The tone should sit between:

- Stylish JRPG.
- Tactical dark fantasy.
- Competitive dueling culture.
- Mythic coming-of-age.

Avoid making the world too cute or too grim. It should have edge, but still be colourful and playable.

---

## Combat Evolution

The current combat engine is 1v1. A tactical RPG needs squad combat.

### Current combat model

Currently:

```text
Unit A vs Unit B
Each unit selects one move
Speed determines action order
Moves apply damage/status/stat changes
Cooldowns and modifiers tick down
Winner decided by HP state
```

### Target tactical combat model

Target:

```text
Player squad vs enemy squad
Grid-based positioning
Each unit has movement range
Each unit chooses one action per turn
Speed influences initiative or turn queue
Moves may have range, area, targeting rules, and terrain interaction
Cooldowns persist across turns
Statuses and stat modifiers affect tactical decisions
Victory condition may vary by encounter
```

### Combat loop proposal

```text
1. Encounter starts
2. Units placed on grid
3. Initiative order calculated
4. Active unit turn begins
5. Player/AI selects move or action
6. Targeting preview shown
7. Move resolves
8. Damage/status/effects applied
9. Cooldowns/status durations tick according to rules
10. Next unit acts
11. Battle ends when objective is complete
12. Rewards and progression are applied
```

### Battle objectives

Not every battle should be “defeat all enemies”.

Use objectives such as:

- Defeat commander.
- Survive X turns.
- Protect an NPC.
- Capture a Crest node.
- Escape the arena.
- Break a shield before the boss ultimate.
- Win a formal duel with restricted rules.

This helps distinguish Crestbound from pure creature battling.

---

## Existing Mechanics to Preserve

### Basic / Signature / Gambit

The current three-move-slot model is strong and should be retained.

Suggested RPG interpretation:

```text
Basic = reliable low-cooldown action
Signature = class-defining tactical action
Gambit = high-risk/high-impact action
```

This is already more distinctive than a four-move Pokemon template.

### Probabilistic speed

Current speed resolution can evolve into either:

#### Option A: Initiative queue

Speed determines turn order probability and frequency.

#### Option B: Tactical advantage roll

Speed determines whether a unit acts before the opponent in direct clashes.

#### Option C: Hybrid

Speed controls initiative, but certain actions trigger contested speed checks.

Recommended:

```text
Use initiative queue for clarity, and preserve probabilistic speed for contested reactions, follow-ups, dodges, and clash actions.
```

### Brace

Brace is currently a defensive modifier for the second mover.

In the RPG, Brace should become a visible tactical state:

```text
Brace: reduce incoming damage or gain defensive scaling when waiting, guarding, or acting second.
```

This can become one of Crestbound's signature tactical mechanics.

### Hex

Hex already blocks buff usage in the current engine.

In the RPG, Hex should become a major anti-setup status:

```text
Hex: prevents self-buffs, Crest awakenings, or Gambit enhancement while active.
```

This gives Sorcerer-style units a clear tactical niche.

---

## Classes

The current six classes should become the first class set.

### Warrior

Role:

```text
Physical bruiser / frontline pressure
```

Identity:

- Strong direct damage.
- Armour break.
- High-risk charges.
- Punishes fragile enemies.

Potential tactical additions:

- Knockback.
- Guard break.
- Cleave attacks.
- Bonus damage after moving in a straight line.

### Mage

Role:

```text
Magical specialist / resistance breaker
```

Identity:

- Reliable magical damage.
- Resistance debuffs.
- Burst windows.

Potential tactical additions:

- Area-of-effect spells.
- Elemental terrain interaction.
- Charged casts.

### Assassin

Role:

```text
Fast attacker / debuff striker
```

Identity:

- Speed control.
- High crit/high risk finishers.
- Defence/resistance shred.

Potential tactical additions:

- Backstab bonuses.
- Flanking.
- Stealth/vanish.
- Bonus damage against isolated targets.

### Guardian

Role:

```text
Tank / protector / defensive anchor
```

Identity:

- Fortify.
- Damage mitigation.
- Adaptive bash.
- Defensive scaling.

Potential tactical additions:

- Intercept attacks.
- Taunt/provoke.
- Shield aura.
- Brace synergy.

### Neutral

Role:

```text
Flexible generalist / stance shifter
```

Identity:

- Adaptive damage.
- Flexible stat shifts.
- Wild Card risk/reward.

Potential tactical additions:

- Switch stance mid-battle.
- Copy minor effects.
- Change damage type based on target weakness.

### Sorcerer

Role:

```text
Fast caster / curse specialist
```

Identity:

- Hex.
- High magical speed.
- Risky burst.

Potential tactical additions:

- Curse zones.
- Buff denial.
- Cooldown extension.
- Status chaining.

---

## Crest System

The Crest system should be layered on top of class identity.

### Crest properties

Each Crest should define:

```text
id
name
affinity
rarity
passive_modifier
awakening_condition
awakening_effect
visual_theme
lore_fragment
compatible_classes
bonded_entity_pool
```

### Example Crest definitions

```yaml
id: crimson_crest
name: Crimson Crest
affinity: force
rarity: common
passive_modifier: +physical damage when below 50% HP
awakening_condition: take 3 hits in one battle
awakening_effect: unlocks Bloodline Gambit for 2 turns
visual_theme: red iron, cracked flame, pressure marks
compatible_classes: [Warrior, Assassin, Guardian]
```

```yaml
id: eclipse_crest
name: Eclipse Crest
affinity: curse
rarity: rare
passive_modifier: Hex effects last +1 turn
awakening_condition: apply 2 statuses in one battle
awakening_effect: enemy buffs are inverted for 1 turn
visual_theme: black-gold ring, moon shadow, violet flame
compatible_classes: [Sorcerer, Mage, Neutral]
```

```yaml
id: azure_crest
name: Azure Crest
affinity: storm
rarity: uncommon
passive_modifier: increased initiative after bracing
awakening_condition: act second twice in one battle
awakening_effect: next Signature move triggers chain lightning
visual_theme: blue steel, rain, thunderline glow
compatible_classes: [Guardian, Mage, Warrior]
```

### Why this works

This gives collection value without copying monster capture directly.

Players collect and experiment with:

- Crests.
- Duelists.
- Bonded entities.
- Class combinations.
- Awakening conditions.
- Tactical synergies.

---

## Bonded Entities

Bonded entities are the closest equivalent to the creature/monster appeal, but they should not function as simple pets.

They can be:

- Spirits.
- Beasts.
- Weapons.
- Masks.
- Ancestral forms.
- Mythic avatars.
- Living contracts.
- Mechanical relics.

### Entity role

A Bonded Entity modifies the Duelist.

It can provide:

- Passive stat change.
- New move variant.
- Awakening form.
- Counterattack effect.
- Terrain interaction.
- Special animation/VFX identity.

### Example entities

```text
Storm Lion
- Works best with Guardian or Warrior
- Rewards bracing and counterattacking
- Awakening: Lionfall Verdict
```

```text
Glass Mantis
- Works best with Assassin
- Rewards flanking and finishing low-HP enemies
- Awakening: Mirror Cut
```

```text
Ash Seraph
- Works best with Mage or Sorcerer
- Rewards burn/curse stacking
- Awakening: Cinder Halo
```

```text
Iron Stag
- Works best with Guardian or Neutral
- Rewards holding ground and protecting allies
- Awakening: Antler Bastion
```

---

## Progression System

Progression should avoid simple linear stat inflation.

### Recommended layers

```text
Duelist Level
Class Rank
Crest Bond Level
Entity Awakening Stage
Move Mastery
Equipment/Relic Slot
```

### Duelist level

General stats and survivability.

### Class rank

Unlocks class-specific passives and move variants.

### Crest bond level

Unlocks Crest passive upgrades, awakening effects, and lore fragments.

### Entity awakening stage

Unlocks visual and mechanical transformations.

### Move mastery

Rewards repeated use without forcing grind.

Example:

```text
Armor Break I: -5 DEF
Armor Break II: -5 DEF and -1 movement for 1 turn
Armor Break III: if target is Braced, also delays initiative
```

---

## Data Model Expansion

The current `Unit` and `Move` models should be expanded conceptually.

### Current model essence

```text
Unit
- name
- class_name
- base_hp
- base_atk
- base_def
- base_mag
- base_res
- base_spd
- hp
- moves
- stat_modifiers
- status_effects
- cooldowns
```

### Target RPG model

```text
Duelist
- id
- display_name
- class_id
- level
- class_rank
- crest_id
- entity_id
- base_stats
- growth_profile
- current_hp
- current_resource
- learned_moves
- equipped_moves
- passives
- statuses
- stat_modifiers
- cooldowns
- position
- team_id
```

```text
Move
- id
- display_name
- move_type
- slot
- power
- accuracy
- range
- area_shape
- target_rule
- cooldown_turns
- resource_cost
- target_stat_mods
- self_stat_mods
- statuses_applied
- terrain_effects
- animation_key
- vfx_key
- ai_tags
```

```text
Crest
- id
- display_name
- affinity
- rarity
- passive_effects
- awakening_condition
- awakening_effect
- compatible_classes
- entity_pool
- lore
```

```text
Entity
- id
- display_name
- species_type
- crest_affinity
- passive_effect
- move_modifiers
- awakening_form
- visual_theme
```

---

## Architecture Plan

The project should split into two layers.

### Layer 1: Balance Lab

This is the current Python repo.

Responsibilities:

- Simulate combat rules.
- Analyse balance.
- Test AI policies.
- Generate matchup reports.
- Export tuned data.

Recommended future structure:

```text
crestbound-balance-lab/
  models.py
  combat.py
  ai.py
  simulation.py
  nash.py
  data/
    classes.yaml
    moves.yaml
    crests.yaml
    entities.yaml
  results/
  notebooks/
  tests/
```

### Layer 2: Game Client

This should be a new playable project.

Recommended structure if using Godot:

```text
crestbound-game/
  project.godot
  scenes/
    battles/
    ui/
    overworld/
    characters/
  scripts/
    battle/
    ai/
    data/
    progression/
    save/
  data/
    classes.json
    moves.json
    crests.json
    entities.json
    encounters.json
  assets/
    sprites/
    vfx/
    audio/
    ui/
```

### Data bridge

The balance lab should export game-ready data:

```text
Python simulation data -> JSON/YAML -> Game client loads it
```

This keeps the system data-driven and makes balancing easier.

---

## Fable / Agent Workflow

Fable should be used as an implementation accelerator, not as the designer.

### Good Fable tasks

Use Fable for:

- Refactoring data models.
- Creating JSON/YAML schemas.
- Writing parser/export scripts.
- Building test suites.
- Creating Godot/Unity scaffolding.
- Implementing grid movement.
- Implementing target previews.
- Implementing AI heuristics.
- Creating balance dashboards.
- Generating boilerplate content from templates.

### Poor Fable tasks

Do not rely on Fable alone for:

- Core game identity.
- Art direction.
- Final balancing judgement.
- Character voice.
- World tone.
- Moment-to-moment game feel.
- Whether the game is actually fun.

### First Fable prompt

Use this as the first implementation prompt once ready:

```text
You are working on the Crestbound Duelists repository. It currently contains a Python combat simulation with Unit, Move, ClassName, MoveType, MoveSlot, cooldowns, status effects, stat modifiers, AI policies, Monte Carlo simulation, and Nash analysis.

Convert the project structure toward a data-driven RPG balance lab without removing the existing simulation functionality.

Tasks:
1. Create a `data/` directory containing YAML or JSON files for classes, moves, crests, and entities.
2. Move hardcoded class and move definitions from `models.py` into data files.
3. Add a loader module that constructs Units from the data files.
4. Preserve the existing public API where possible so `combat.py`, `simulation.py`, `ai.py`, and `nash.py` still run.
5. Add tests to prove that existing six classes and their three moves load correctly.
6. Add placeholder Crest and Entity schemas but do not integrate them into combat yet.
7. Update the README to explain the new Balance Lab architecture.
8. Do not build a playable game client in this repo yet.

The goal is to prepare the simulation engine to become the balance layer for a future tactical RPG.
```

---

## Roadmap

### Phase 0 — Preserve current project

Goal:

```text
Keep the existing simulation stable.
```

Tasks:

- Add tests for current battle loop.
- Add tests for move availability and cooldown ticking.
- Add tests for Hex blocking buff moves.
- Add tests for stat modifier decay.
- Add tests for expected damage calculations.
- Pin a small deterministic simulation seed for regression testing.

Success condition:

```text
Current mechanics are protected before refactoring.
```

### Phase 1 — Data-driven refactor

Goal:

```text
Move classes, moves, and tuning values out of hardcoded Python definitions.
```

Tasks:

- Add `data/classes.yaml`.
- Add `data/moves.yaml`.
- Add `data/combat_config.yaml`.
- Add `loaders.py`.
- Update `create_unit()` to use loaded data.
- Preserve existing simulation outputs.

Success condition:

```text
Changing move power or class stats requires editing data, not Python code.
```

### Phase 2 — Crest and Entity prototypes

Goal:

```text
Add the systems that make Crestbound unique.
```

Tasks:

- Add Crest model.
- Add Entity model.
- Add compatibility rules.
- Add passive modifiers.
- Add awakening conditions.
- Simulate Crest + Class combinations.
- Generate matchup reports with and without Crests.

Success condition:

```text
Warrior + Crimson Crest plays differently from Warrior + Eclipse Crest.
```

### Phase 3 — Squad combat simulator

Goal:

```text
Expand from 1v1 combat to small-team tactical encounters.
```

Tasks:

- Add grid coordinate model.
- Add movement range.
- Add move range.
- Add targeting rules.
- Add area-of-effect shapes.
- Add team IDs.
- Add turn queue or initiative system.
- Add AI target selection.
- Add battle objectives.

Success condition:

```text
A 3v3 tactical battle can be simulated headlessly in Python.
```

### Phase 4 — Playable prototype client

Goal:

```text
Create a small playable tactical battle using exported data.
```

Tasks:

- Start Godot or Unity project.
- Import class/move/Crest data.
- Implement grid movement.
- Implement battle UI.
- Implement target preview.
- Implement simple enemy AI.
- Implement win/loss state.
- Implement combat log display.

Success condition:

```text
A player can complete one tactical battle manually.
```

### Phase 5 — RPG vertical slice

Goal:

```text
Build the first 30-60 minute playable demo.
```

Tasks:

- Add hub area.
- Add first dungeon/arena.
- Add dialogue system.
- Add party management.
- Add level progression.
- Add Crest acquisition.
- Add 3 boss fights.
- Add save/load.
- Add music and basic VFX.

Success condition:

```text
A player can start a new game, recruit/receive Crests, fight multiple encounters, beat a boss, and save progress.
```

---

## Minimum Technical Tasks

### Required tests

Add tests for:

```text
- Unit creation
- Move loading
- Damage calculation
- Accuracy miss/hit handling
- Cooldown application
- Cooldown ticking
- Stat modifier application
- Stat modifier expiry
- Hex blocking buff moves
- Battle result validity
- Policy returns legal moves
- Simulation matrix shape
```

### Required tooling

Add:

```text
pytest
ruff or equivalent linting
pre-commit optional
CI workflow optional
```

### Required docs

Add:

```text
README.md update
RPG_TRANSFORMATION_PLAN.md
BALANCE_LAB_ARCHITECTURE.md
DATA_SCHEMA.md
```

---

## Recommended First Playable Battle

### Scenario

```text
The player enters a ruined dueling court to recover a dormant Crest.
```

### Player squad

```text
Guardian + Azure Crest
Mage + Ember Crest
Assassin + Glass Crest
```

### Enemy squad

```text
Warrior raider
Sorcerer hex-caster
Neutral duelist
```

### Objective

```text
Defeat the enemy commander or hold the Crest node for 3 turns.
```

### Tutorial mechanics introduced

- Movement.
- Basic attacks.
- Signature moves.
- Gambits.
- Brace.
- Hex.
- Crest awakening.
- Objective tiles.

This battle should teach the game better than a long text tutorial.

---

## Anti-Knockoff Rules

Use these rules to protect the game's identity.

### Avoid

```text
Three elemental starters
Gym leaders
Badge collection
Throwing devices to capture monsters
Four-move monster templates
Cute pet-first framing
Elite Four-style endgame
Route numbering
Professor intro structure
```

### Emphasise

```text
Crest binding
Human/entity partnership
Tactical squad battles
Class/Crest fusion
Awakening conditions
Risk-reward Gambits
Terrain and positioning
Rival dueling houses
Mythic contracts
Data-driven balance identity
```

---

## Portfolio Angle

This project can become stronger than a normal game prototype because it connects game design with data science.

Portfolio framing:

> Built a stochastic tactical RPG combat engine and balance lab using Monte Carlo simulation, AI policy evaluation, and game-theoretic analysis, then extended it into a data-driven RPG prototype.

This is useful for:

- Game analytics roles.
- Data science portfolio work.
- Simulation-heavy engineering roles.
- AI/game systems roles.
- Technical design roles.

The unique selling point is not just “I made a game”.

It is:

> I built a game system that can be simulated, analysed, tuned, and expanded using data-driven workflows.

---

## Immediate Next Steps

Recommended next tasks:

1. Add regression tests around the current combat engine.
2. Refactor class/move definitions into data files.
3. Add placeholder Crest and Entity schemas.
4. Simulate Class + Crest combinations.
5. Design one tactical 3v3 encounter on paper.
6. Build the first grid-combat prototype separately.

The next code milestone should be:

```text
Crestbound Duelists v3.0 — Data-driven Balance Lab
```

Not:

```text
Full RPG
```

The RPG becomes realistic only after the balance lab can export clean, game-ready combat data.

---

## Final Direction

Crestbound Duelists should become:

> **A tactical crest-collecting RPG where the fun comes from class identity, Crest binding, tactical positioning, and high-risk Gambit decisions.**

The current repository is already valuable. It should not be abandoned. It should become the simulation brain behind the future playable game.
