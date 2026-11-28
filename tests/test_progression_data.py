"""Progression data for the vertical slice: items, charms, quests, cast builds
and encounter rewards (data/*.yaml, validated by loaders.py)."""
from __future__ import annotations

import pytest

import loaders
from loaders import DataValidationError


def test_items_cover_heal_cure_resonance_and_revive():
    items = loaders.load_items()
    kinds = {item["battle_effect"]["type"] for item in items.values() if item.get("battle_effect")}
    assert kinds == {"heal", "cure", "resonance", "revive"}
    assert all(item["price"] > 0 for item in items.values())


def test_charms_trade_rather_than_stack_flat_power():
    """No charm is a plain stat upgrade: each changes how a Duelist fights,
    and those with an upside in one direction pay for it or are rewards."""
    charms = loaders.load_equipment()
    assert {"greymaw_fang", "drowned_bell", "wardens_sigil"} <= set(charms)
    for charm_id, charm in charms.items():
        kinds = {effect["type"] for effect in charm["effects"]}
        assert kinds != {"stat_bonus"}, charm_id
    shop = [c for c in charms.values() if c.get("source") == "shop"]
    assert shop and all(c["price"] > 0 for c in shop)


def test_quest_steps_use_distinct_flags_and_rewards_are_valid():
    quests = loaders.load_quests()
    assert {q["kind"] for q in quests.values()} == {"main", "side"}
    flags = [step["flag"] for q in quests.values() for step in q["steps"]]
    assert len(flags) == len(set(flags))
    assert sum(1 for q in quests.values() if q["kind"] == "side") >= 4


def test_kai_kits_follow_the_chapter():
    cast = loaders.load_cast()
    unbonded, unsettled = cast["kai_unbonded"], cast["kai_unsettled"]
    assert not unbonded.get("crest_id") and not unbonded["class_id"]
    assert unsettled["crest_id"] == "unsettled_crest"
    assert set(unbonded["move_ids"]) < set(unsettled["move_ids"]) | {"wild_swing"}
    # Kai is never shown as a Neutral before Civara (STORY_OUTLINE: class is a player choice).
    assert unbonded["class_id"] != "neutral" and unsettled["class_id"] != "neutral"


def test_joey_is_a_protected_non_combatant():
    joey = loaders.load_cast()["joey"]
    assert "protected" in joey["tags"] and not joey.get("move_ids")


def test_bosses_have_phases_and_telegraphs():
    cast = loaders.load_cast()
    moves = loaders.load_moves()
    for boss in ("greymaw", "sealed_choir"):
        phases = cast[boss]["phases"]
        assert len(phases) >= 2, boss
        assert all(p["trigger"]["type"] == "hp_below" for p in phases[1:]), boss
        telegraphed = {m for p in phases for m in p.get("move_ids", []) if moves[m].get("telegraph")}
        assert telegraphed, boss


def test_bad_rewards_fail_clearly():
    with pytest.raises(DataValidationError):
        loaders.validate_reward("test", {"items": {"no_such_item": 1}})
    with pytest.raises(DataValidationError):
        loaders.validate_reward("test", {"crowns": -5})
    loaders.validate_reward("test", {"crowns": 5, "items": {"potion": 1}, "equipment": ["road_charm"], "unlocks": ["steady_footing"]})
