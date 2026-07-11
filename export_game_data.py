"""
Crestbound Duelists — Game Data Export Pipeline
=================================================
Validates the YAML source data and exports it as JSON for the Godot
client. This is the only supported path for game data to reach the
game — the Godot project must never hardcode balance values.

Usage:
    python export_game_data.py            # exports/ + game/data/
    python export_game_data.py --no-sync  # exports/ only

Output is deterministic (sorted keys, stable ordering) apart from the
export timestamp recorded in manifest.json.
"""

from __future__ import annotations

import argparse
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable

from loaders import (
    DataValidationError,
    load_battle_objectives,
    load_characters,
    load_classes,
    load_combat_config,
    load_crests,
    load_entities,
    load_encounters,
    load_locations,
    load_moves,
    load_terrain,
)

ROOT = Path(__file__).resolve().parent
EXPORTS_DIR = ROOT / "exports"
GAME_DATA_DIR = ROOT / "game" / "data"

SCHEMA_VERSION = "1.1.0"

# Dataset name -> loader. Record datasets return dict[id, record];
# combat_config returns a flat settings mapping.
DATASETS: dict[str, Callable[[], dict[str, Any]]] = {
    "classes": load_classes,
    "moves": load_moves,
    "combat_config": load_combat_config,
    "crests": load_crests,
    "entities": load_entities,
    "terrain": load_terrain,
    "battle_objectives": load_battle_objectives,
    "encounters": load_encounters,
    "characters": load_characters,
    "locations": load_locations,
}


def _write_json(path: Path, data: Any) -> None:
    path.write_text(
        json.dumps(data, indent=2, sort_keys=True, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def export_all(output_dir: Path = EXPORTS_DIR) -> dict[str, Any]:
    """Export every dataset to `output_dir`. Returns the manifest."""
    output_dir.mkdir(parents=True, exist_ok=True)

    counts: dict[str, int] = {}
    for name, loader in DATASETS.items():
        data = loader()
        _write_json(output_dir / f"{name}.json", data)
        counts[name] = len(data)

    manifest = {
        "schema_version": SCHEMA_VERSION,
        "exported_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "datasets": sorted(DATASETS),
        "record_counts": counts,
    }
    _write_json(output_dir / "manifest.json", manifest)
    return manifest


def sync_to_game(source_dir: Path = EXPORTS_DIR, game_dir: Path = GAME_DATA_DIR) -> None:
    """Copy exported JSON into the Godot project's data directory."""
    game_dir.mkdir(parents=True, exist_ok=True)
    for json_file in sorted(source_dir.glob("*.json")):
        shutil.copy2(json_file, game_dir / json_file.name)


def main() -> int:
    parser = argparse.ArgumentParser(description="Export game data to JSON for the Godot client.")
    parser.add_argument(
        "--no-sync", action="store_true",
        help="write exports/ only; skip copying into game/data/",
    )
    args = parser.parse_args()

    try:
        manifest = export_all()
    except DataValidationError as exc:
        print(f"EXPORT FAILED — data validation error:\n  {exc}")
        return 1

    print(f"Exported {len(manifest['datasets'])} datasets to {EXPORTS_DIR}/")
    for name in manifest["datasets"]:
        print(f"  {name}.json  ({manifest['record_counts'][name]} records)")

    if not args.no_sync:
        sync_to_game()
        print(f"Synced exports to {GAME_DATA_DIR}/")

    print(f"Schema version {manifest['schema_version']}, exported {manifest['exported_at']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
