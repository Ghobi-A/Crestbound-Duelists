"""Greymere's authored map and battle return share one location contract."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCATIONS = json.loads((ROOT / "game/world/locations.json").read_text())["locations"]


def test_authored_greymere_layout_is_rectangular_and_spawned():
    town = LOCATIONS["greymere"]
    rows = town["rows"]
    assert len(rows) >= 30 and all(len(row) == len(rows[0]) for row in rows)
    for name in ("approach", "court_return"):
        x, y = town["spawn_points"][name]["tile"]
        assert rows[y][x] not in "#~_", name
    assert town["spawn_points"]["court_return"]["tile"] != town["spawn_points"]["approach"]["tile"]


def test_court_victory_returns_through_the_named_world_spawn():
    story = (ROOT / "game/scripts/overworld/greymere.gd").read_text()
    battle = (ROOT / "game/scripts/battle/battle_controller.gd").read_text()
    assert 'GameState.location_spawn = "court_return"' in story
    assert 'GameState.location_spawn = "court_return"' in battle
    assert "COURT_RETURN_TILE" not in battle
    assert "court_return" in LOCATIONS["greymere"]["spawn_points"]
