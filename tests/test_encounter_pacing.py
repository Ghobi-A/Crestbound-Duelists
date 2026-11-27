"""Route 01 random encounters leave breathing room (see encounter_probe.gd)."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROUTE = json.loads((ROOT / "game/world/locations.json").read_text())["locations"]["route_01"]


def test_route_grants_grace_on_arrival_and_after_battle():
    assert ROUTE["arrival_grace_steps"] >= 16
    assert ROUTE["return_grace_steps"] >= 24


def test_random_encounters_need_a_minimum_distance_and_stay_rare():
    for zone in ROUTE["encounter_zones"]:
        assert zone["cooldown_steps"] >= 24
        assert zone["probability"] <= 0.06
        # Expected grass steps between fights: cooldown plus 1/p.
        assert zone["cooldown_steps"] + 1 / zone["probability"] >= 36


def test_arrival_grace_applies_on_every_entry_not_only_the_first():
    world = (ROOT / "game/scripts/overworld/world_location.gd").read_text()
    # WorldCatalog.travel stamps the destination before the scene loads, so the
    # arrival is detected from the recorded departure, not the location id.
    assert 'var arriving := GameState.arrived_from != "" and GameState.arrived_from != location_id' in world
    catalog = (ROOT / "game/scripts/overworld/world_catalog.gd").read_text()
    assert catalog.index("GameState.arrived_from = GameState.location_id") < catalog.index("GameState.location_id = str(door.destination_location)")
    assert 'maxi(int(_encounter_state.get("cooldown", 0)), int(definition.get("arrival_grace_steps", 0)))' in world
