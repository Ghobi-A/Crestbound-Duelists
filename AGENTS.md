# Agent Operating Instructions

## Mission and architecture

Crestbound Duelists has three cooperating layers:

1. A Python balance and simulation engine.
2. A Godot 4 game client.
3. A Streamlit Balance Lab backed by a reproducible analytical snapshot.

Treat the Streamlit layer as a presentation and interaction layer over the Python
engine, not as a third combat implementation. Preserve clear ownership: Python
owns simulation and balance analysis, the Godot battle runtime owns playable-game
battle resolution, and YAML owns shared balance configuration.

## Repository map and ownership

### Shared data and Python engine

- `data/*.yaml` is the source of truth for class statistics, moves, combat
  configuration, Crests, Bonded Entities, encounters, terrain, objectives, and
  narrative data. Change balance values there rather than in consumers or
  generated JSON.
- `loaders.py` loads and validates core YAML data. `models.py` defines the core
  combat model; `combat.py` resolves 1v1 combat; `ai.py` owns decision policies;
  `simulation.py` owns Monte Carlo orchestration; and `nash.py` owns maximin/Nash
  analysis.
- `rpg_models.py` contains variable-size party and RPG models. Encounter code must
  support the sizes declared by data, including 1v1, 2v2, 3v3, and asymmetric
  battles. Do not reintroduce assumptions that every battle is a duel or fixed
  3v3 encounter.
- `export_game_data.py` validates YAML and produces JSON for the Godot client.
- `tests/` protects loaders, models, combat, policies, simulations, encounters,
  Nash analysis, RPG behavior, and exports.

### Godot client

- `game/` contains the Godot 4 project, scenes, scripts, original assets, and its
  exported data copy.
- Godot must consume exported data rather than hardcoding a parallel set of class,
  move, Crest, Entity, encounter, or combat-configuration values.
- When Python and Godot implement the same mechanic, preserve behavioral parity:
  damage, accuracy, cooldowns, initiative, Brace, Hex, modifier expiry,
  Resonance, awakening, targeting, and win conditions must not drift silently.
- Authoritative playable-battle state transitions belong in the Godot battle
  runtime, not in scene widgets or presentation scripts.

### Streamlit and recruiter analytics

- `streamlit_app.py` is the recruiter-facing Balance Lab and the Streamlit
  Community Cloud entrypoint. It provides bounded live simulation and presents
  precomputed analysis.
- `results/recruiter_snapshot.json` is the committed, precomputed analytical
  payload consumed by snapshot-backed views.
- `tools/generate_snapshot.py` is the seeded generator for the balance matrix,
  class averages, policy comparisons, and Nash/maximin results.
- `.github/workflows/balance-snapshot.yml` regenerates the snapshot when relevant
  balance data, engine, policy, analysis, or generator files change on `main`.
- `requirements.txt` contains the lean deployed-app dependencies.
- `requirements-dev.txt` includes the runtime requirements plus testing, Nash,
  notebook, and development dependencies.
- `.streamlit/config.toml` owns Streamlit theme and presentation configuration.
- `tools/` contains validation, asset-generation, and analytical snapshot-generation
  utilities. Keep utilities deterministic where their outputs are committed.

## Non-negotiable invariants

### YAML source of truth and cross-runtime parity

- Do not duplicate balance configuration in Python constants, Godot scripts,
  Streamlit code, tests, or prose when it can be loaded or derived from YAML.
- Extend loaders, validation, exports, consumers, and tests together when a YAML
  schema changes. Missing or malformed required data should fail clearly rather
  than silently falling back to a second source of truth.
- A change to a shared combat rule is incomplete until the Python engine and the
  corresponding Godot runtime behavior remain aligned, or the difference is
  explicitly scoped and documented as intentional.
- Preserve variable-size and asymmetric encounter support across data validation,
  models, battle logic, AI, and UI. Avoid fixed party counts and hardcoded unit
  slots.

### Streamlit invariants

- Streamlit must call the existing Python engine or read generated analytical
  output.
- Do not reimplement combat formulas, policies, class values, or balance logic in
  `streamlit_app.py`.
- Load expensive aggregate analytics from `results/recruiter_snapshot.json`; do
  not recompute them during initial page load.
- Live simulations may invoke the real Python engine, but simulation counts must
  remain bounded and results should be cached.
- Derive recruiter-facing numerical claims from the snapshot where practical
  instead of duplicating them as hardcoded prose.
- The app must degrade gracefully when the snapshot is absent. Snapshot-dependent
  views may explain how to generate it, while engine-backed features that do not
  require it should remain usable.
- Hide links to unfinished features, including the Godot web build. Do not render
  dead links or “coming soon” links.

### Lore and product identity

- Treat `docs/LORE_BIBLE.md`, `docs/STORY_OUTLINE.md`, and
  `docs/GAME_DESIGN_FOUNDATION.md` as protected product constraints. Do not rename
  established people, places, factions, Crests, or Bonded Entities, or rewrite
  canon incidentally to a technical task.
- Keep the game a variable-size, round-based Duelist RPG built around Crests,
  Bonded Entities, pre-battle positioning, Resonance, and awakening. Do not
  reintroduce grid movement or replace the established battle identity without an
  explicitly scoped design change.
- New lore or presentation copy must not contradict the protected documents. Keep
  narrative edits separate from balance or infrastructure work unless the task
  explicitly couples them.

## Generated files

The following are generated outputs, even though they are committed:

- `exports/*.json`, generated from YAML by `export_game_data.py`.
- `game/data/*.json`, the Godot-consumable copy generated by the same exporter.
- `results/recruiter_snapshot.json`, generated by
  `tools/generate_snapshot.py` from data and Python engine/policy code.

For generated outputs:

1. Modify the underlying YAML, engine, policy, exporter, or generator—not an
   individual generated value.
2. Regenerate the affected output and review the complete diff.
3. Never manually edit individual result values or analytical findings in
   `results/recruiter_snapshot.json`.
4. Verify whether a snapshot diff is a real analytical change or only metadata.
   Preserve the workflow's comparison of the analytical payload while excluding
   volatile fields such as generation time (`generated_at`), runtime
   (`runtime_seconds`), and source commit (`git_commit`).
5. Do not commit unrelated generated churn. If the task changes no relevant input,
   leave committed outputs untouched.

## UI and presentation boundaries

- Godot UI renders game state and emits player intent. Authoritative battle
  resolution belongs in the Godot battle-runtime layer.
- Streamlit invokes the Python engine or presents generated analytics.
  Authoritative simulation, AI-policy, and analytical logic belongs in the Python
  modules.
- Neither UI may duplicate balance configuration or combat formulas.
- Keep UI-only work separate from rules changes. If a control introduces a new
  action or option, route it through the authoritative layer and cover that
  behavior there.
- Preserve readable behavior at the project's target Godot presentation size and
  in Streamlit's configured layout. Avoid unrelated visual redesigns during
  engine, data, or documentation tasks.

## Dependencies

Install only the deployed Streamlit runtime dependencies with:

```bash
pip install -r requirements.txt
```

Install the complete toolchain for tests, snapshot generation, Nash analysis, and
notebook work with:

```bash
pip install -r requirements-dev.txt
```

Put a dependency in `requirements.txt` only if the deployed app imports it at
runtime. Put testing, generation, Nash, notebook, and other development-only
packages in `requirements-dev.txt`, which includes the runtime file.

## Validation workflow

Choose checks that cover the changed layer; do not replace focused checks with
manual inspection alone.

### Python and data

Run the regression suite for Python engine, loader, model, policy, simulation,
export, or YAML changes:

```bash
python -m pytest
```

For a quick balance smell check or reduced simulation suite, use:

```bash
python balance_report.py
python main.py --quick
```

When YAML or export behavior changes, regenerate and validate both committed JSON
destinations:

```bash
python export_game_data.py
python -m pytest tests/test_export.py
```

### Analytical snapshot

Changes affecting any of the following require an appropriate fixed-seed snapshot
validation: `data/*.yaml`, `combat.py`, `models.py`, `loaders.py`, `ai.py`,
`simulation.py`, `nash.py`, or `tools/generate_snapshot.py`.

A normal quick validation is:

```bash
python tools/generate_snapshot.py --sims 5000 --seed 42
```

The committed production snapshot uses 100,000 simulations per matchup, and the
generator's default seed is `42`. Reproducibility depends on preserving explicit
seed control through every stochastic path. Do not regenerate the full snapshot
for every small task when a smaller seeded run is sufficient to validate the
change. The workflow on `main` remains responsible for producing and committing
the full recruiter snapshot for relevant changes.

Because the generator's default output is committed, use a temporary `--output`
path when validation should not update the production artifact. If a task changes
the analytical payload intentionally, regenerate the required committed snapshot
and review it under the generated-file rules above.

### Godot

After Godot scenes, scripts, project configuration, assets, exported data, or
shared battle behavior change, run the repository's static validator:

```bash
python tools/validate_godot_project.py
```

When a Godot editor/runtime is available, also open `game/project.godot`, run the
affected flow, and check for parser and runtime errors. If it is unavailable,
report that limitation rather than claiming an interactive check.

### Streamlit

For Streamlit changes, at minimum verify that the entrypoint imports and starts,
that all tabs render with the current snapshot schema, and that the missing-
snapshot path remains usable. Exercise changed live simulations at their minimum
and maximum supported counts without introducing unbounded work on page load.

## Scope discipline

- Make the smallest coherent change that satisfies the task. Do not bundle lore,
  balance, refactoring, generated-art, dependency, or visual changes without a
  direct requirement.
- Preserve public behavior unless the task explicitly changes it. Add or adjust
  focused regression tests for behavior changes.
- Do not “fix” simulation findings by editing generated JSON or recruiter-facing
  prose. Change and validate the underlying source, then regenerate derived
  artifacts and make the prose match the evidence.
- Inspect diffs for unrelated formatter churn, generated metadata, and accidental
  changes outside the intended layer before committing.

## Definition of done

A change is complete only when all applicable items below are true:

- YAML remains the source of truth and Python/Godot parity is preserved.
- Variable-size encounters, protected lore, and established product identity have
  not been weakened.
- Focused tests and the applicable full regression checks pass, or any environment
  limitation is reported precisely.
- Godot changes pass static validation and, when possible, the affected playable
  flow has been exercised.
- Streamlit changes import and render successfully, including graceful behavior
  without the snapshot.
- Snapshot-backed views remain compatible with the current JSON schema.
- Changes affecting analytical output have been validated with a fixed seed.
- Dependency changes are placed in the correct runtime or development
  requirements file.
- Generated snapshots and exports are current when the task requires them, with no
  manual edits to derived values.
- Recruiter-facing text is consistent with the generated results.
- The final diff contains only files within scope and documents any intentionally
  omitted validation or follow-up work.
