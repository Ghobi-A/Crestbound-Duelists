"""Tests for the YAML data loading layer in loaders.py."""

from __future__ import annotations

import pytest

import loaders
from loaders import (
    DataValidationError,
    build_move,
    create_unit_from_data,
    load_classes,
    load_combat_config,
    load_moves,
)
from models import ClassName, MoveSlot, create_unit


def test_load_combat_config_values_match_v23():
    config = load_combat_config()
    assert config["speed_band"] == 20
    # Retained for v2.1 schema/API compatibility; initiative uses
    # SPD + U(0, speed_band) rather than this ratio threshold.
    assert config["guaranteed_speed_ratio"] == 2.0
    assert config["variance_low"] == 0.85
    assert config["variance_high"] == 1.0
    assert config["brace_multiplier"] == 1.15
    assert config["max_turns"] == 100
    assert config["stat_decay_duration"] == 3


def test_load_classes_returns_all_six():
    classes = load_classes()
    assert set(classes) == {"warrior", "mage", "assassin", "guardian", "neutral", "sorcerer"}
    for record in classes.values():
        assert set(record["base_stats"]) == set(loaders.STAT_KEYS)
        assert len(record["move_ids"]) == 3


def test_load_moves_returns_all_eighteen():
    moves = load_moves()
    assert len(moves) == 18
    slots = [m["slot"] for m in moves.values()]
    assert slots.count("basic") == 6
    assert slots.count("signature") == 6
    assert slots.count("gambit") == 6


def test_loaded_data_is_isolated_from_cache():
    load_classes()["warrior"]["base_stats"]["hp"] = 1
    assert load_classes()["warrior"]["base_stats"]["hp"] == 100


def test_build_move_matches_engine_expectations():
    hex_move = build_move("hex")
    assert hex_move.name == "Hex"
    assert hex_move.slot == MoveSlot.SIGNATURE
    assert hex_move.applies_status == "hexed"
    assert hex_move.status_duration == 2
    assert hex_move.power == 12

    fortify = build_move("fortify")
    assert fortify.is_buff_move
    assert ("def", 8) in fortify.self_stat_mods
    assert ("res", 8) in fortify.self_stat_mods

    cripple = build_move("cripple")
    assert cripple.target_stat_mods == [
        ("def", -6),
        ("spd", -8),
    ]


def test_build_move_unknown_id():
    with pytest.raises(DataValidationError, match="Unknown move id"):
        build_move("does_not_exist")


def test_create_unit_from_data_matches_legacy_factory():
    for cls in ClassName:
        legacy = create_unit(cls)
        from_data = create_unit_from_data(cls.value.lower())
        assert from_data.base_hp == legacy.base_hp
        assert from_data.base_atk == legacy.base_atk
        assert from_data.base_def == legacy.base_def
        assert from_data.base_mag == legacy.base_mag
        assert from_data.base_res == legacy.base_res
        assert from_data.base_spd == legacy.base_spd
        assert [m.name for m in from_data.moves] == [m.name for m in legacy.moves]


def test_create_unit_from_data_unknown_class():
    with pytest.raises(DataValidationError, match="Unknown class id"):
        create_unit_from_data("paladin")


def test_create_unit_from_data_custom_name():
    unit = create_unit_from_data("guardian", name="Warden Elara Thorne")
    assert unit.name == "Warden Elara Thorne"


def test_legacy_class_stats_shape():
    import models

    stats = models.CLASS_STATS
    assert set(stats) == set(ClassName)
    assert stats[ClassName.WARRIOR]["atk"] == 74
    assert stats[ClassName.WARRIOR]["hp"] == 100


def test_legacy_move_factories_shape():
    import models

    factories = models.MOVE_FACTORIES
    moves = factories[ClassName.SORCERER]()
    assert [m.name for m in moves] == ["Flame", "Hex", "Voidfire"]


def test_missing_data_file_error_is_readable(monkeypatch, tmp_path):
    monkeypatch.setattr(loaders, "DATA_DIR", tmp_path)
    loaders.clear_caches()
    try:
        with pytest.raises(DataValidationError, match="Data file not found"):
            load_combat_config()
    finally:
        loaders.clear_caches()


def test_invalid_yaml_error_is_readable(monkeypatch, tmp_path):
    (tmp_path / "combat_config.yaml").write_text("speed_band: [unclosed")
    monkeypatch.setattr(loaders, "DATA_DIR", tmp_path)
    loaders.clear_caches()
    try:
        with pytest.raises(DataValidationError, match="Could not parse"):
            load_combat_config()
    finally:
        loaders.clear_caches()


def test_missing_config_key_error(monkeypatch, tmp_path):
    (tmp_path / "combat_config.yaml").write_text("speed_band: 20\n")
    monkeypatch.setattr(loaders, "DATA_DIR", tmp_path)
    loaders.clear_caches()
    try:
        with pytest.raises(DataValidationError, match="missing key"):
            load_combat_config()
    finally:
        loaders.clear_caches()
