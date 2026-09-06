"""Regression tests for unit/move creation in models.py."""

from __future__ import annotations

import pytest

from models import ClassName, MoveSlot, MoveType, create_unit, CLASS_STATS

ALL_CLASSES = list(ClassName)

# The v2.3 naked-class chassis. If these change, it must be a deliberate
# balance decision — update data/classes.yaml and this table together.
EXPECTED_STATS = {
    ClassName.WARRIOR:  {"hp": 100, "atk": 74, "def": 68, "mag": 30, "res": 44, "spd": 44},
    ClassName.MAGE:     {"hp": 92, "atk": 30, "def": 34, "mag": 78, "res": 70, "spd": 48},
    ClassName.ASSASSIN: {"hp": 88, "atk": 70, "def": 40, "mag": 34, "res": 48, "spd": 68},
    ClassName.GUARDIAN: {"hp": 108, "atk": 40, "def": 76, "mag": 36, "res": 72, "spd": 36},
    ClassName.NEUTRAL:  {"hp": 96, "atk": 53, "def": 50, "mag": 53, "res": 50, "spd": 54},
    ClassName.SORCERER: {"hp": 90, "atk": 34, "def": 38, "mag": 76, "res": 48, "spd": 64},
}

EXPECTED_MOVES = {
    ClassName.WARRIOR:  ["Power Slash", "Armor Break", "Reckless Charge"],
    ClassName.MAGE:     ["Arcane Bolt", "Mind Pierce", "Overload"],
    ClassName.ASSASSIN: ["Quick Strike", "Cripple", "Lethal Edge"],
    ClassName.GUARDIAN: ["Shield Bash", "Fortify", "Avalanche"],
    ClassName.NEUTRAL:  ["Hybrid Strike", "Focus Shift", "Wild Card"],
    ClassName.SORCERER: ["Flame", "Hex", "Voidfire"],
}


@pytest.mark.parametrize("cls", ALL_CLASSES)
def test_unit_can_be_created(cls):
    unit = create_unit(cls)
    assert unit.class_name is cls
    assert unit.is_alive
    assert unit.hp == unit.base_hp


@pytest.mark.parametrize("cls", ALL_CLASSES)
def test_base_stats_match_v23_chassis(cls):
    unit = create_unit(cls)
    expected = EXPECTED_STATS[cls]
    assert unit.base_hp == expected["hp"]
    assert unit.base_atk == expected["atk"]
    assert unit.base_def == expected["def"]
    assert unit.base_mag == expected["mag"]
    assert unit.base_res == expected["res"]
    assert unit.base_spd == expected["spd"]


@pytest.mark.parametrize("cls", ALL_CLASSES)
def test_class_stats_table_matches_units(cls):
    # analysis.ipynb imports CLASS_STATS directly — keep it consistent.
    unit = create_unit(cls)
    stats = CLASS_STATS[cls]
    assert stats["hp"] == unit.base_hp
    assert stats["atk"] == unit.base_atk
    assert stats["def"] == unit.base_def
    assert stats["mag"] == unit.base_mag
    assert stats["res"] == unit.base_res
    assert stats["spd"] == unit.base_spd


@pytest.mark.parametrize("cls", ALL_CLASSES)
def test_each_class_has_exactly_three_core_moves(cls):
    unit = create_unit(cls)
    assert len(unit.moves) == 3
    assert [m.name for m in unit.moves] == EXPECTED_MOVES[cls]


@pytest.mark.parametrize("cls", ALL_CLASSES)
def test_each_class_has_one_move_per_slot(cls):
    unit = create_unit(cls)
    slots = [m.slot for m in unit.moves]
    assert slots.count(MoveSlot.BASIC) == 1
    assert slots.count(MoveSlot.SIGNATURE) == 1
    assert slots.count(MoveSlot.GAMBIT) == 1


def test_basic_moves_have_no_cooldown():
    for cls in ALL_CLASSES:
        unit = create_unit(cls)
        for move in unit.moves:
            if move.slot == MoveSlot.BASIC:
                assert move.cooldown_turns == 0
            else:
                assert move.cooldown_turns == 1


def test_custom_unit_name():
    unit = create_unit(ClassName.WARRIOR, "Aren Vale")
    assert unit.name == "Aren Vale"


def test_default_unit_name_is_class_name():
    unit = create_unit(ClassName.SORCERER)
    assert unit.name == "Sorcerer"


def test_units_do_not_share_move_objects():
    a = create_unit(ClassName.WARRIOR)
    b = create_unit(ClassName.WARRIOR)
    assert a.moves[0] is not b.moves[0]


def test_move_types_present():
    unit = create_unit(ClassName.GUARDIAN)
    shield_bash = unit.moves[0]
    assert shield_bash.move_type == MoveType.ADAPTIVE
    warrior = create_unit(ClassName.WARRIOR)
    assert warrior.moves[0].move_type == MoveType.PHYSICAL
    mage = create_unit(ClassName.MAGE)
    assert mage.moves[0].move_type == MoveType.MAGICAL


def test_reset_restores_fresh_state():
    unit = create_unit(ClassName.WARRIOR)
    unit.hp = 3
    unit.apply_stat_mod("atk", -5, 3)
    unit.apply_status("hexed", 2)
    unit.cooldowns["Armor Break"] = 1
    unit.reset()
    assert unit.hp == unit.base_hp
    assert unit.stat_modifiers == []
    assert unit.status_effects == []
    assert unit.cooldowns == {}
