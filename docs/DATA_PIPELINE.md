# Data Pipeline

```text
Edit data/*.yaml
      │
      ▼
python -m pytest              # regression tests validate behaviour
      │
      ▼
python balance_report.py      # fast balance smell check (~1s)
python main.py --quick        # broader simulation pass (~10s)
      │
      ▼
python export_game_data.py    # validate + write exports/ + game/data/
      │
      ▼
Launch Godot                  # client reads game/data/*.json
```

## Source data (`data/`)

| File | Contents | Loader |
|------|----------|--------|
| `classes.yaml` | 6 classes: stats, roles, move kits | `load_classes()` |
| `moves.yaml` | 18 moves: power, accuracy, slots, effects, tactical fields | `load_moves()` |
| `combat_config.yaml` | Speed band, variance, Brace multiplier, decay | `load_combat_config()` |
| `crests.yaml` | 6 Crests: passives, awakening conditions/effects | `load_crests()` |
| `entities.yaml` | 6 Bonded Entities: passives, granted moves, awakened forms | `load_entities()` |
| `terrain.yaml` | Tile types: move cost, passability, DEF/RES bonuses | `load_terrain()` |
| `battle_objectives.yaml` | Win/loss condition definitions | `load_battle_objectives()` |
| `characters.yaml`, `locations.yaml` | Lightweight narrative references | `load_characters()`, `load_locations()` |

## Validation

`loaders.py` validates on first load and raises `DataValidationError`
with the file, record, and field that failed. Checks include: required
fields, stat ranges, move slots (each class needs exactly one
Basic/Signature/Gambit), move references, class references in
`compatible_classes`, and config sanity (variance bounds, positive
turn counts). Cooldowns are derived from slots; data that contradicts
the engine is rejected.

## Export

`python export_game_data.py` writes deterministic, sorted,
human-readable JSON:

```text
exports/
  classes.json  moves.json  combat_config.json  crests.json
  entities.json terrain.json battle_objectives.json
  characters.json locations.json manifest.json
```

and mirrors them into `game/data/` (skip with `--no-sync`).
`manifest.json` records the schema version, export timestamp, dataset
list, and record counts. The Godot client refuses to start a battle
without the required datasets and prints exactly which file is missing.

## Rules of the pipeline

1. Never edit `exports/` or `game/data/*.json` by hand — they are build
   artifacts (committed so the game runs without Python).
2. Never add balance values to GDScript — add a field to YAML, export,
   and read it through `GameData`.
3. A data change is not done until `python -m pytest` and
   `python export_game_data.py` both pass.
4. `python tools/validate_godot_project.py` statically checks the
   client: resource paths, JSON validity, dialogue keys, script syntax
   smells.
