"""Reference coverage is a prerequisite, not a substitute for visual approval."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIT = json.loads((ROOT / "docs/rework/greymere_character_references.json").read_text())


def test_every_resident_and_kai_class_has_a_reference_decision():
    world = json.loads((ROOT / "game/world/locations.json").read_text())
    aliases = {alias for record in AUDIT["characters"] for alias in record["aliases"]}
    locations = world["locations"]
    if isinstance(locations, dict):
        locations = locations.values()
    for location in locations:
        for npc in location.get("npcs", []):
            assert npc["sprite_key"] in aliases, npc
    for name in ("warrior", "guardian", "mage", "sorcerer", "assassin", "neutral"):
        assert f"aren/{name}" in aliases


def test_reference_sources_exist_and_are_not_procedural_replacements():
    assert AUDIT["audit_complete"] is True
    assert (ROOT / AUDIT["decision_document"]).is_file()
    ids = [record["id"] for record in AUDIT["characters"]]
    assert len(ids) == len(set(ids))
    for record in AUDIT["characters"]:
        assert record["classification"] in ("A", "B", "C")
        assert record["references"], record["id"]
        for source in record["references"]:
            assert (ROOT / source).is_file(), source
            assert not source.endswith("_v2.png"), source
        assert record["replacement_status"] in ("not_started", "in_review", "verified")
