"""Tests for encounter definitions and the Resonance data schema."""

from __future__ import annotations

import pytest

from loaders import RESONANCE_EVENTS, load_crests, load_encounters


def test_prototype_encounters_present():
    encounters = load_encounters()
    for expected in ("hollow_court_battle", "serin_first_duel",
                     "veyrhold_pair_trial", "archive_ambush"):
        assert expected in encounters


def test_encounter_sizes_cover_all_supported_shapes():
    encounters = load_encounters()
    shapes = {(e["player_slots"], e["enemy_slots"]) for e in encounters.values()}
    assert (1, 1) in shapes   # 1v1 duel
    assert (2, 2) in shapes   # 2v2 partnership
    assert (3, 3) in shapes   # 3v3 full party
    assert any(p != e for p, e in shapes)  # at least one asymmetric encounter


def test_enemy_party_matches_slots():
    for encounter_id, record in load_encounters().items():
        assert len(record["enemy_party"]) == record["enemy_slots"], encounter_id


def test_hollow_court_battle_definition():
    encounter = load_encounters()["hollow_court_battle"]
    assert encounter["player_slots"] == 3
    assert encounter["pre_battle_positioning"] is True
    assert encounter["objective"] == "defeat_all"
    assert encounter["battlefield_effect"]["type"] == "resonance_surge"
    classes = [build["class_id"] for build in encounter["enemy_party"]]
    assert classes == ["warrior", "sorcerer", "neutral"]


def test_enemy_positions_valid():
    for record in load_encounters().values():
        for build in record["enemy_party"]:
            assert build.get("position", "front") in ("front", "back")


def test_every_crest_has_resonance_rules():
    for crest_id, crest in load_crests().items():
        gains = crest["resonance_gain"]
        assert gains, f"{crest_id} has no resonance gains"
        for event, amount in gains.items():
            assert event in RESONANCE_EVENTS
            assert 0 < amount <= 100
        min_resonance = crest["awakening_condition"]["min_resonance"]
        assert 0 <= min_resonance <= 100


def test_resonance_rules_differ_between_crests():
    # Crests must not all gain Resonance identically.
    signatures = {
        tuple(sorted(crest["resonance_gain"].items()))
        for crest in load_crests().values()
    }
    assert len(signatures) == 6
