"""Tests for the JSON export pipeline in export_game_data.py."""

from __future__ import annotations

import json

from export_game_data import DATASETS, SCHEMA_VERSION, export_all, sync_to_game


def test_export_produces_all_datasets(tmp_path):
    manifest = export_all(tmp_path)
    expected = {
        "classes", "moves", "combat_config", "crests", "entities",
        "terrain", "battle_objectives", "encounters", "characters", "locations",
    }
    assert set(manifest["datasets"]) == expected
    for name in expected:
        assert (tmp_path / f"{name}.json").exists()
    assert (tmp_path / "manifest.json").exists()


def test_exported_json_is_valid_and_matches_counts(tmp_path):
    manifest = export_all(tmp_path)
    for name in manifest["datasets"]:
        data = json.loads((tmp_path / f"{name}.json").read_text(encoding="utf-8"))
        assert isinstance(data, dict)
        assert len(data) == manifest["record_counts"][name]


def test_manifest_contents(tmp_path):
    export_all(tmp_path)
    manifest = json.loads((tmp_path / "manifest.json").read_text(encoding="utf-8"))
    assert manifest["schema_version"] == SCHEMA_VERSION
    assert "exported_at" in manifest
    assert manifest["record_counts"]["classes"] == 6
    assert manifest["record_counts"]["moves"] == 18
    assert manifest["record_counts"]["crests"] == 6
    assert manifest["record_counts"]["entities"] == 6
    assert manifest["record_counts"]["encounters"] >= 4


def test_export_is_deterministic_apart_from_timestamp(tmp_path):
    dir_a = tmp_path / "a"
    dir_b = tmp_path / "b"
    export_all(dir_a)
    export_all(dir_b)
    for name in DATASETS:
        content_a = (dir_a / f"{name}.json").read_text(encoding="utf-8")
        content_b = (dir_b / f"{name}.json").read_text(encoding="utf-8")
        assert content_a == content_b, f"{name}.json is not deterministic"


def test_exported_classes_preserve_balance_values(tmp_path):
    export_all(tmp_path)
    classes = json.loads((tmp_path / "classes.json").read_text(encoding="utf-8"))
    assert classes["warrior"]["base_stats"] == {
        "hp": 100, "atk": 74, "def": 68, "mag": 30, "res": 44, "spd": 44,
    }
    assert classes["guardian"]["base_stats"]["hp"] == 108
    assert classes["assassin"]["base_stats"]["spd"] == 68

    moves = json.loads((tmp_path / "moves.json").read_text(encoding="utf-8"))
    assert moves["power_slash"]["power"] == 16
    assert moves["reckless_charge"]["power"] == 24
    assert moves["armor_break"]["target_stat_mods"] == [{"stat": "def", "amount": -8}]

    config = json.loads((tmp_path / "combat_config.json").read_text(encoding="utf-8"))
    assert config["brace_multiplier"] == 1.15
    assert config["speed_band"] == 20


def test_sync_to_game_copies_files(tmp_path):
    source = tmp_path / "exports"
    target = tmp_path / "game_data"
    export_all(source)
    sync_to_game(source, target)
    assert (target / "classes.json").exists()
    assert (target / "manifest.json").exists()
    source_names = {p.name for p in source.glob("*.json")}
    target_names = {p.name for p in target.glob("*.json")}
    assert source_names == target_names
