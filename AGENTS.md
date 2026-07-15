# AGENTS.md

## Mission

Crestbound Duelists is a data-driven RPG with two coupled layers:

1. A Python balance and simulation engine.
2. A Godot 4 game client.

Agents should optimise for correctness, maintainability, reproducibility, and preservation of game-design intent. Do not treat the repository as a generic Godot project or a generic Python package.

## Repository invariants

These rules are non-negotiable unless the task explicitly changes the architecture.

1. `data/*.yaml` is the source of truth for balance and content data.
2. Do not hardcode class stats, move powers, accuracies, cooldowns, combat constants, Crest values, encounter composition, or other balance values in GDScript.
3. Godot consumes exported JSON from `game/data/`; exports are produced by `export_game_data.py`.
4. Python and GDScript may implement the same combat formulas, but both must derive their inputs from the shared data contract.
5. Preserve support for variable-size encounters: 1v1, 2v2, 3v3, and asymmetric battles. Do not introduce fixed-party assumptions without explicit approval.
6. Preserve deterministic validation paths. Randomised simulation code must expose or preserve seed control where applicable.
7. Do not silently rewrite lore, characterisation, game-design rules, or narrative content while performing technical tasks.

## Architecture map

### Python / balance layer

- `data/*.yaml`: source-of-truth game and balance data.
- `loaders.py`: data loading and validation.
- `models.py`: core combat dataclasses and compatibility surface.
- `combat.py`: combat rules and 1v1 engine logic.
- `ai.py`: simulation policies.
- `simulation.py`: Monte Carlo and policy evaluation.
- `nash.py`: game-theoretic analysis.
- `rpg_models.py`: RPG domain models.
- `export_game_data.py`: validated export to `exports/` and `game/data/`.
- `balance_report.py`: fast balance diagnostics.
- `tests/`: regression suite.

### Godot / game layer

- `game/scripts/data/game_data.gd`: central exported-data access path.
- `game/scripts/core/game_state.gd`: run state, party, formation, encounter and flags.
- `game/scripts/save/save_manager.gd`: versioned save/load.
- `game/scripts/battle/`: battle runtime and rules.
- `game/scripts/ui/battle/`: battle UI and player interaction.
- `game/scenes/`: playable scene graph.
- `game/assets/`: game art and generated assets.
- `tools/`: validation and asset-generation utilities.

Read the relevant files in `docs/` before changing a subsystem.

## Required workflow

Before editing:

1. Inspect the relevant implementation, tests, data files, and design documentation.
2. Identify whether the change belongs in data, Python, Godot, or multiple layers.
3. State the invariants at risk.
4. Prefer the smallest coherent change that solves the actual problem.

After editing:

1. Run the narrowest relevant tests first.
2. Run the full Python regression suite for engine, data, loader, export, or balance changes:
   `python -m pytest`
3. For balance-sensitive changes, also run:
   `python balance_report.py`
4. For data-contract changes, regenerate exports:
   `python export_game_data.py`
5. Run available Godot/static validation for game-client changes.
6. Verify generated files are intentional before committing them.
7. Summarise changed behaviour, validation performed, and residual risk.

## Change rules by task type

### Balance or content data

Prefer editing `data/*.yaml` rather than code. Update loader validation and tests when the schema changes. Regenerate exported JSON.

### Combat rules

Check both Python and Godot implementations for parity. Add or update regression tests. Do not change a formula in only one runtime unless the task explicitly calls for divergence.

### New game mechanic

Define the mechanic in this order where applicable:

1. Design contract in `docs/`.
2. Data schema.
3. Loader validation.
4. Python model/simulation support.
5. Tests.
6. Export contract.
7. Godot runtime.
8. UI/presentation.

Do not begin with UI hardcoding and backfill the architecture later.

### UI or presentation

Keep battle rules out of UI scripts. UI should render state and emit player intent; authoritative battle resolution belongs in battle-runtime code.

### Refactors

Preserve public behaviour unless the task explicitly changes it. Avoid unrelated cleanup. Add characterisation tests before risky structural refactors when existing coverage is insufficient.

### Narrative or lore

Treat `docs/LORE_BIBLE.md`, `docs/STORY_OUTLINE.md`, and related data as authored source material. Do not invent canon to fill gaps unless explicitly asked.

## Testing expectations

A task is not complete merely because the code looks plausible.

Minimum expectations:

- Bug fix: add a regression test when practical.
- New Python behaviour: add tests.
- Schema change: add validation and export tests.
- Combat change: test edge cases and cross-layer parity risk.
- Godot change: run available static validation and inspect affected scene/script references.

Never delete, weaken, skip, or broadly mock tests solely to make a change pass.

## Generated files

Treat `exports/` and `game/data/` as generated outputs. Edit their source data or exporter instead of manually patching generated JSON, unless the task is specifically about generated output inspection.

Treat generated art similarly: modify the generator or documented source process where possible rather than making unexplained one-off edits.

## Scope discipline

Agents must not:

- change unrelated systems during a focused task;
- introduce new frameworks or dependencies without a concrete need;
- duplicate existing abstractions without first inspecting the current architecture;
- assume grid-based combat: the current battle model is variable-size party combat without tactical grid movement;
- replace authored game design with generic RPG conventions;
- claim validation that was not actually run.

## Definition of done

A change is done when:

1. The requested behaviour works.
2. Repository invariants remain intact.
3. Relevant tests and validation pass, or failures are reported precisely.
4. Data exports are current when required.
5. Documentation is updated when architecture, data contracts, or game rules changed.
6. The final summary identifies files changed, tests run, and any remaining risks.

## Agent task template

For substantial tasks, use this structure:

- Objective
- Current behaviour
- Desired behaviour
- Relevant architecture and invariants
- Implementation plan
- Validation plan
- Changes made
- Validation results
- Residual risks / follow-ups

Prefer evidence from the repository over assumptions.
