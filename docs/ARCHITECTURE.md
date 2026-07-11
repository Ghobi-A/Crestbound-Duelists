# Architecture

Crestbound Duelists is two connected layers with one source of truth.

```text
┌─────────────────────────┐      ┌──────────────────────────┐
│  Balance Lab (Python)   │      │  Game Client (Godot 4)   │
│                         │      │                          │
│  data/*.yaml  ← edit    │      │  scenes/  scripts/       │
│  loaders.py   ← validate│ JSON │  GameData autoload       │
│  combat.py    ← simulate│─────▶│  overworld + battle      │
│  export_game_data.py    │      │  reads game/data/*.json  │
└─────────────────────────┘      └──────────────────────────┘
```

## Python layer (repository root)

| File | Responsibility |
|------|----------------|
| `data/*.yaml` | Single source of truth: classes, moves, combat constants, Crests, Bonded Entities, terrain, objectives, narrative references |
| `loaders.py` | Loads, validates, and caches YAML; `create_unit_from_data()` |
| `models.py` | Engine dataclasses (`Unit`, `Move`, statuses); backward-compatible `create_unit`, `CLASS_STATS` |
| `combat.py` | Damage formula, speed resolution, Brace, Hex, 1v1 battle loop |
| `ai.py` | Random / greedy / lookahead policies |
| `simulation.py` | Monte Carlo win matrices, policy comparison, CSV logs |
| `nash.py` | Single-turn payoff matrices, maximin LP, entropy analysis |
| `rpg_models.py` | RPG domain models: `Crest`, `BondedEntity`, `DuelistProfile`, grid/encounter primitives |
| `export_game_data.py` | Validates and exports everything to `exports/` and `game/data/` as JSON |
| `balance_report.py` | Fast dev report: win rates, move usage, balance warnings |
| `main.py` | Full simulation suite (`--quick` for development) |
| `tests/` | 133 pytest tests covering engine, loaders, RPG data, export |

## Godot layer (`game/`)

| Path | Responsibility |
|------|----------------|
| `scripts/data/game_data.gd` | Autoload; loads exported JSON with readable errors; the only data access path |
| `scripts/core/game_state.gd` | Autoload; current run: build, party, position, flags |
| `scripts/save/save_manager.gd` | Autoload; JSON save/load in `user://` |
| `scenes/boot/` + `scripts/ui/boot_screen.gd` | Title, continue, class selection |
| `scenes/overworld/` + `scripts/overworld/` | Greymere: grid movement, collision, NPCs, interactions |
| `scripts/ui/dialogue_box.gd` | Reusable JSON-driven dialogue |
| `scenes/battle/` + `scripts/battle/` | Hollow Court 3v3 tactical battle |
| `assets/placeholders/` | Programmer-art palette (no final art yet) |

## Rules

1. **Balance data lives in YAML only.** The Godot client never hardcodes
   stats, powers, accuracies, or combat constants; it reads
   `game/data/*.json`, which is produced only by `export_game_data.py`.
2. **The game does not talk to a running Python process.** The contract
   is the exported JSON plus `manifest.json` (schema version + counts).
3. **The Python engine is protected by regression tests.** Change data
   or engine code, run `python -m pytest` before anything else.
4. **The two layers may implement the same formulas** (Python for
   simulation, GDScript for play) but always from the same data.
