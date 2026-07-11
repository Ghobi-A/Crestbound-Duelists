"""Tests for the RPG data files and domain models."""

from __future__ import annotations

import pytest

from loaders import (
    load_battle_objectives,
    load_characters,
    load_crests,
    load_entities,
    load_locations,
    load_terrain,
)
from rpg_models import (
    DEFAULT_CREST_BY_CLASS,
    BattleObjective,
    Crest,
    DuelistProfile,
    GridPosition,
    Team,
    TerrainTile,
    get_crest,
    get_entity,
)

EXPECTED_CRESTS = {
    "crimson_crest", "azure_crest", "eclipse_crest",
    "ember_crest", "glass_crest", "verdant_crest",
}
EXPECTED_ENTITIES = {
    "storm_lion", "glass_mantis", "ash_seraph",
    "iron_tortoise", "mirror_fox", "grave_stag",
}


def test_all_sample_crests_present():
    assert set(load_crests()) == EXPECTED_CRESTS


def test_all_sample_entities_present():
    assert set(load_entities()) == EXPECTED_ENTITIES


def test_crests_are_not_plain_stat_boosts():
    # Every Crest passive must be a typed behavioural modifier.
    types = {c["passive_modifier"]["type"] for c in load_crests().values()}
    assert len(types) == len(EXPECTED_CRESTS)  # all distinct behaviours


def test_crest_model_round_trip():
    crest = get_crest("crimson_crest")
    assert isinstance(crest, Crest)
    assert crest.affinity == "force"
    assert crest.passive_modifier["type"] == "low_hp_damage_bonus"
    assert crest.is_compatible_with("warrior")
    assert not crest.is_compatible_with("mage")


def test_entity_model_round_trip():
    entity = get_entity("storm_lion")
    assert entity.category == "beast"
    assert entity.granted_move == "lionfall_verdict"
    assert entity.is_compatible_with("guardian")


def test_unknown_crest_raises_readable_error():
    with pytest.raises(KeyError, match="Unknown crest id"):
        get_crest("obsidian_crest")


def test_default_crest_pairings_are_compatible():
    # The prototype default pairing for every class must be a legal combination.
    for class_id, crest_id in DEFAULT_CREST_BY_CLASS.items():
        crest = get_crest(crest_id)
        assert crest.is_compatible_with(class_id), (
            f"{crest_id} is not compatible with its default class {class_id}"
        )


def test_duelist_profile_build():
    aren = DuelistProfile("Aren Vale", "guardian", "azure_crest", "storm_lion")
    assert aren.crest.name == "Azure Crest"
    assert aren.entity.name == "Storm Lion"
    assert aren.level == 1


def test_duelist_profile_rejects_unknown_class():
    with pytest.raises(ValueError, match="Unknown class id"):
        DuelistProfile("Nobody", "paladin")


def test_same_class_different_crest_is_different_build():
    a = DuelistProfile("A", "warrior", "crimson_crest")
    b = DuelistProfile("B", "warrior", "glass_crest")
    assert a.crest.passive_modifier != b.crest.passive_modifier


def test_team_holds_members():
    team = Team("Player", [
        DuelistProfile("Aren Vale", "guardian", "azure_crest"),
        DuelistProfile("Warden Elara Thorne", "guardian", "azure_crest"),
        DuelistProfile("Mira Solen", "mage", "ember_crest"),
    ])
    assert len(team) == 3


def test_grid_position_distance():
    assert GridPosition(0, 0).manhattan_distance(GridPosition(3, 2)) == 5


def test_terrain_data_loads_and_models():
    terrain = load_terrain()
    assert "plains" in terrain and "wall" in terrain and "crest_node" in terrain
    wall = TerrainTile.from_record(terrain["wall"])
    assert not wall.passable
    forest = TerrainTile.from_record(terrain["forest"])
    assert forest.move_cost == 2
    assert forest.defense_bonus > 0


def test_battle_objectives_load_and_model():
    objectives = load_battle_objectives()
    assert "defeat_all" in objectives
    hold = BattleObjective.from_record(objectives["hold_crest_node"])
    assert hold.objective_type == "hold_tile"
    assert hold.params["turns_required"] == 3


def test_narrative_characters_load():
    characters = load_characters()
    for expected in ("aren_vale", "serin_dain", "cassian_orre",
                     "elara_thorne", "mira_solen", "mara_vale"):
        assert expected in characters
    assert characters["serin_dain"]["role"] == "rival"
    assert characters["elara_thorne"]["class"] == "guardian"


def test_narrative_locations_load():
    locations = load_locations()
    for expected in ("greymere", "hollow_court", "veyrhold", "bellgrave",
                     "caer_lumen", "solharbor", "evershade", "first_vault"):
        assert expected in locations
    assert locations["greymere"]["region"] == "Kingdom of Avelaine"
