# Crestbound Duelists — RPG Transformation Plan

## Purpose

This document defines how to evolve **Crestbound Duelists** from its current state as a Python combat simulation and decision-system experiment into a playable tactical RPG.

The goal is **not** to make a Pokemon clone. The goal is:

> **A tactical crest-collecting RPG where Duelists bind themselves to Crests, classes, spirits, and mythic entities, then fight in strategic battles shaped by positioning, team composition, class identity, status effects, and long-term progression.**

The current repository should become the **Balance Lab** behind the future game.

---

## 1. Current Repository State

The repo currently contains a strong turn-based combat foundation:

- Six asymmetric classes: Warrior, Mage, Assassin, Guardian, Neutral, Sorcerer.
- Three move slots per class: Basic, Signature, Gambit.
- Damage variance.
- Probabilistic speed resolution.
- Cooldowns.
- Buffs and debuffs.
- Temporary stat modifiers.
- Status effects such as Hex.
- A 1v1 battle loop.
- AI policies: random, greedy, lookahead.
- Monte Carlo simulation tooling.
- Nash/maximin analysis.
- CSV battle log export.

The current repo is valuable because it already has a testable combat system. Most RPG concepts start with lore and no rules. Crestbound starts with rules, simulation, and balance analysis.

Current limitation:

- No playable client.
- No game UI.
- No maps.
- No party system.
- No progression.
- No save/load.
- No tactical grid.
- No RPG content pipeline.

Therefore the next step is not “add graphics”. The next step is to turn the repo into a proper **data-driven RPG balance layer**.

---

## 2. Target Game Identity

Crestbound should combine the strengths of:

- **Pokemon**: collection, team-building, affinities, progression.
- **Fire Emblem**: grid tactics, positioning, terrain, unit roles.
- **Final Fantasy**: jobs/classes, limit-break style moves, summons, boss phases, strong party identity.

Avoid direct Pokemon clone markers:

- No Pokeball-equivalent capture loop.
- No gym badge formula.
- No starter trio that maps directly to Grass/Fire/Water.
- No four-move-only monster template.
- No route-town-gym-route copy.

The distinct hook should be:

> **Crests modify Duelists, classes, bonded entities, moves, passives, and awakenings.**

A unit is not just a creature. A unit is:

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
Passive: Brace charges Counterforce
Signature: Thunder Rampart
Gambit: Lionfall Verdict
```

This creates collection depth without copying Pokemon directly.

---

## 3. Recommended Product Shape

First playable release:

```text
Crestbound Duelists: Proving Grounds
```

Recommended format:

```text
2D or 2.5D tactical RPG
Grid-based battles
Small hub/dungeon structure
Data-driven combat rules
Python simulation retained as Balance Lab
```

Recommended first engine:

```text
Godot 4
```

Reason:

- Good for 2D/2.5D.
- Lightweight.
- Solo-dev friendly.
- Strong for tactical grid prototypes.
- Lower asset burden than Unreal.

Unity is a valid alternative. Unreal should be avoided for the first slice unless the project becomes heavily 3D/cinematic.

---

## 4. MVP Scope

The first goal should be a vertical slice, not a full RPG.

### Vertical Slice Content

```text
1 hub area
1 route/field area
1 dungeon or dueling court
6 base classes
12 Crests
12-18 bonded entities
3 playable party slots
8-12 enemy archetypes
3 boss fights
1 rival character
1 major story objective
Level cap: 10-15
Target playtime: 30-60 minutes
```

### Do Not Add Yet

```text
Online PvP
Open world
Hundreds of entities
Procedural world generation
Trading
Crafting
Romance/support system
Voice acting
Full 3D cinematics
Large economy
Dozens of towns
```

The objective is to prove the core loop:

```text
Explore -> acquire Crest/entity -> build squad -> tactical battle -> progress -> unlock new synergy
```

---

## 5. Combat Evolution

### Current Combat

```text
1v1 unit battle
Each unit selects a move
Speed determines action order
Damage/status/stat changes resolve
Cooldowns and modifiers tick down
Winner decided by HP
```

### Target Combat

```text
Squad vs squad tactical battle
Grid positioning
Movement range
Move range and area shapes
Terrain bonuses
Initiative order
Class/Crest/entity passives
Objective-based encounters
```

### Target Battle Loop

```text
1. Encounter starts
2. Units deploy on grid
3. Initiative queue is calculated
4. Active unit chooses move/action
5. Target preview appears
6. Move resolves
7. Damage/status/terrain effects apply
8. Cooldowns and modifiers tick
9. Next unit acts
10. Objective completion ends battle
11. Rewards/progression apply
```

### Preserve These Existing Mechanics

#### Basic / Signature / Gambit

Keep this as the core move identity:

```text
Basic = reliable action
Signature = class-defining tactical action
Gambit = high-risk/high-impact action
```

#### Probabilistic Speed

Current speed logic should evolve into an initiative or clash system:

```text
Speed controls initiative, reaction chance, follow-ups, and contested actions.
```

#### Brace

Brace should become a visible tactical state:

```text
Brace = defensive stance, counter setup, or bonus when acting second.
```

#### Hex

Hex should remain a powerful anti-setup status:

```text
Hex = blocks buffs, Crest awakening, or enhanced Gambits while active.
```

---

## 6. Class Direction

### Warrior

Role: physical bruiser/frontline pressure.

Possible additions:

- Knockback.
- Guard break.
- Cleave.
- Charge bonuses.

### Mage

Role: magical specialist/resistance breaker.

Possible additions:

- AoE spells.
- Elemental terrain effects.
- Charged casts.

### Assassin

Role: fast striker/debuff finisher.

Possible additions:

- Flanking bonuses.
- Backstab.
- Stealth.
- Isolated-target damage.

### Guardian

Role: tank/protector/defensive anchor.

Possible additions:

- Intercept.
- Taunt.
- Shield aura.
- Brace synergy.

### Neutral

Role: adaptive generalist/stance shifter.

Possible additions:

- Type adaptation.
- Stance switching.
- Hybrid scaling.
- Copy minor effects.

### Sorcerer

Role: fast caster/curse specialist.

Possible additions:

- Curse zones.
- Buff denial.
- Cooldown extension.
- Status chaining.

---

## 7. Crest System

The Crest system should be the main differentiator.

Each Crest should define:

```text
id
name
affinity
rarity
passive_modifier
awakening_condition
awakening_effect
compatible_classes
bonded_entity_pool
visual_theme
lore_fragment
```

Example:

```yaml
id: crimson_crest
name: Crimson Crest
affinity: force
rarity: common
passive_modifier: bonus physical damage below 50% HP
awakening_condition: take 3 hits in one battle
awakening_effect: next Gambit gains lifesteal
compatible_classes: [Warrior, Assassin, Guardian]
```

Example:

```yaml
id: eclipse_crest
name: Eclipse Crest
affinity: curse
rarity: rare
passive_modifier: Hex lasts +1 turn
awakening_condition: apply 2 statuses in one battle
awakening_effect: invert enemy buffs for 1 turn
compatible_classes: [Sorcerer, Mage, Neutral]
```

---

## 8. Bonded Entities

Bonded entities give the creature-collection appeal without making the game feel like a pet-catching clone.

Entities can be:

- Spirits.
- Beasts.
- Weapons.
- Masks.
- Ancestors.
- Mythic avatars.
- Machines/relics.

Entity effects:

- Passive stat modifiers.
- Move variants.
- Awakening forms.
- Counter effects.
- Terrain interactions.
- VFX/animation identity.

Examples:

```text
Storm Lion
- Guardian/Warrior synergy
- Rewards Bracing and counterattacking
- Awakening: Lionfall Verdict
```

```text
Glass Mantis
- Assassin synergy
- Rewards flanking and execution
- Awakening: Mirror Cut
```

```text
Ash Seraph
- Mage/Sorcerer synergy
- Rewards burn/curse stacking
- Awakening: Cinder Halo
```

---

## 9. RPG Progression

Progression should have multiple layers:

```text
Duelist Level
Class Rank
Crest Bond Level
Entity Awakening Stage
Move Mastery
Relic/Equipment Slot
```

### Duelist Level

General stats and survivability.

### Class Rank

Unlocks class passives and move variants.

### Crest Bond Level

Unlocks Crest passives, awakening effects, and lore.

### Entity Awakening Stage

Unlocks stronger forms and visual changes.

### Move Mastery

Rewards repeated tactical use.

Example:

```text
Armor Break I: -5 DEF
Armor Break II: -5 DEF and -1 movement
Armor Break III: if target is Braced, delay initiative
```

---

## 10. Technical Architecture

Split the project into two conceptual layers.

### Layer 1 — Balance Lab

This is the current Python repo.

Responsibilities:

- Simulate combat.
- Tune classes and moves.
- Test AI policies.
- Generate win-rate matrices.
- Export game-ready data.
- Detect dominant strategies.

Recommended future structure:

```text
Crestbound-Duelists/
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
    combat_config.yaml
  tests/
  results/
  notebooks/
```

### Layer 2 — Game Client

This should eventually be a separate Godot/Unity project.

Example Godot structure:

```text
crestbound-game/
  project.godot
  scenes/
    battle/
    ui/
    overworld/
  scripts/
    battle/
    data/
    progression/
    save/
    ai/
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

### Data Bridge

The Balance Lab should export JSON/YAML that the game client can consume.

```text
Python balance data -> JSON/YAML export -> game client import
```

---

## 11. Data Model Expansion

Current `Unit` should eventually become `Duelist`.

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
- current_hp
- learned_moves
- equipped_moves
- passives
- statuses
- stat_modifiers
- cooldowns
- grid_position
- team_id
```

Current `Move` should expand to:

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

Add:

```text
Crest
Entity
Encounter
BattleObjective
TerrainTile
ProgressionReward
```

---

## 12. Roadmap

### Phase 0 — Protect Current Engine

- Add tests for current unit creation.
- Add tests for move availability.
- Add tests for damage calculation.
- Add tests for cooldown ticking.
- Add tests for stat modifier expiry.
- Add tests for Hex blocking buffs.
- Add deterministic regression tests with seeded RNG.

Success condition:

```text
The current engine can be safely refactored.
```

### Phase 1 — Data-Driven Refactor

- Create `data/classes.yaml`.
- Create `data/moves.yaml`.
- Create `data/combat_config.yaml`.
- Add `loaders.py`.
- Refactor `create_unit()` to load from data.
- Preserve current simulation behaviour.

Success condition:

```text
Balance changes are made in data files, not hardcoded Python.
```

### Phase 2 — Crest and Entity Prototype

- Add Crest model.
- Add Entity model.
- Add compatibility rules.
- Add passive modifiers.
- Add awakening conditions.
- Simulate class + Crest combinations.

Success condition:

```text
Warrior + Crimson Crest plays differently from Warrior + Eclipse Crest.
```

### Phase 3 — Squad Combat Simulator

- Add team model.
- Add grid coordinate model.
- Add movement range.
- Add move range.
- Add AoE shapes.
- Add initiative queue.
- Add targeting AI.
- Add battle objectives.

Success condition:

```text
A 3v3 tactical battle can be simulated headlessly in Python.
```

### Phase 4 — Playable Prototype

- Create Godot/Unity project.
- Import exported combat data.
- Implement grid movement.
- Implement battle UI.
- Implement target preview.
- Implement simple enemy AI.
- Implement win/loss conditions.

Success condition:

```text
A player can manually complete one tactical battle.
```

### Phase 5 — RPG Vertical Slice

- Add hub area.
- Add first dungeon/dueling court.
- Add dialogue.
- Add party management.
- Add progression.
- Add Crest acquisition.
- Add 3 boss fights.
- Add save/load.
- Add audio and basic VFX.

Success condition:

```text
A player can play a 30-60 minute demo from start to finish.
```

---

## 13. First Playable Encounter

Scenario:

```text
The player enters a ruined dueling court to recover a dormant Crest.
```

Player squad:

```text
Guardian + Azure Crest
Mage + Ember Crest
Assassin + Glass Crest
```

Enemy squad:

```text
Warrior Raider
Sorcerer Hex-Caster
Neutral Duelist
```

Objective:

```text
Defeat the enemy commander OR hold the Crest node for 3 turns.
```

Tutorial mechanics:

- Movement.
- Basic moves.
- Signature moves.
- Gambits.
- Brace.
- Hex.
- Crest awakening.
- Objective tiles.

---

## 14. Fable / Agent Implementation Prompt

Use this as the first agent prompt:

```text
You are working on the Crestbound Duelists repository. It currently contains a Python combat simulation with Unit, Move, ClassName, MoveType, MoveSlot, cooldowns, status effects, stat modifiers, AI policies, Monte Carlo simulation, and Nash analysis.

Convert the project toward a data-driven RPG Balance Lab without removing existing simulation functionality.

Tasks:
1. Add tests for current combat behaviours.
2. Create a `data/` directory with class, move, Crest, entity, and combat config files.
3. Move hardcoded class and move definitions from `models.py` into data files.
4. Add a loader module that constructs Units from data.
5. Preserve the existing simulation API so `main.py`, `simulation.py`, `ai.py`, and `nash.py` still run.
6. Add placeholder Crest and Entity schemas but do not integrate them into combat yet.
7. Add README documentation for the Balance Lab architecture.
8. Do not build the playable game client yet.

Goal: prepare the simulation engine to become the balance layer for a future tactical RPG.
```

---

## 15. Portfolio Framing

This project can become stronger than a normal game prototype because it connects game design with data science.

Portfolio line:

```text
Built a stochastic tactical RPG combat engine and balance lab using Monte Carlo simulation, AI policy evaluation, and game-theoretic analysis, then extended it toward a data-driven RPG prototype.
```

Unique selling point:

```text
The game system can be simulated, analysed, tuned, and expanded with data-driven workflows.
```

---

## 16. Immediate Next Step

The next milestone should be:

```text
Crestbound Duelists v3.0 — Data-Driven Balance Lab
```

Not:

```text
Full RPG
```

The RPG becomes realistic once the simulation layer can export clean, game-ready data.

Final direction:

> **Crestbound Duelists should become a tactical crest-collecting RPG where the fun comes from class identity, Crest binding, tactical positioning, and high-risk Gambit decisions.**
