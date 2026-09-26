"""Geometry/coverage contracts; visual animation approval is a separate gate."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = json.loads((ROOT / "game/assets/overworld/authored.json").read_text())

def test_all_greymere_and_kai_classes_have_authored_sheets():
    locations = json.loads((ROOT / "game/world/locations.json").read_text())
    def walk(value):
        if isinstance(value, dict):
            if "sprite_key" in value:
                assert value["sprite_key"] in MANIFEST["aliases"]
            for item in value.values():
                walk(item)
        elif isinstance(value, list):
            for item in value:
                walk(item)
    walk(locations)
    for name in ("neutral", "warrior", "guardian", "mage", "sorcerer", "assassin"):
        assert "aren/" + name in MANIFEST["aliases"]

def test_frames_have_explicit_facings_bounds_and_feet():
    assert len(MANIFEST["entries"]) == 17
    for entry in MANIFEST["entries"].values():
        assert (ROOT / "game" / entry["atlas"].removeprefix("res://")).is_file()
        assert entry["native_body_height"] > 0
        assert set(entry["frames"]) == {"down", "up", "east", "west"}
        for poses in entry["frames"].values():
            assert len(poses) == 4
            for pose in poses:
                x, y, width, height = pose["rect"]
                assert x >= 0 and y >= 0 and width > 0 and height > 0
                assert 0 <= pose["foot"][0] <= width
                assert 0 <= pose["foot"][1] <= height
