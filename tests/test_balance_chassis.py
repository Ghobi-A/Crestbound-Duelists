"""Structural invariants for the v2.3 naked-class balance chassis."""

from __future__ import annotations

from itertools import permutations

from loaders import load_classes, load_combat_config, load_moves


NON_HP_STATS = ("atk", "def", "mag", "res", "spd")


def _basic_hits_to_ko(attacker: dict, defender: dict, move: dict) -> float:
    """Expected Basic hits at mean variance, ignoring tactical state."""
    avg_variance = (0.85 + 1.0) / 2
    if move["move_type"] == "physical":
        ratio = 2 * attacker["atk"] / (attacker["atk"] + defender["def"])
    elif move["move_type"] == "magical":
        ratio = 2 * attacker["mag"] / (attacker["mag"] + defender["res"])
    else:
        phys = 2 * attacker["atk"] / (attacker["atk"] + defender["def"])
        mag = 2 * attacker["mag"] / (attacker["mag"] + defender["res"])
        ratio = max(phys, mag)
    expected_damage = move["power"] * ratio * avg_variance
    return defender["hp"] / expected_damage


def test_all_classes_have_equal_non_hp_budget():
    classes = load_classes()
    totals = {
        class_id: sum(record["base_stats"][stat] for stat in NON_HP_STATS)
        for class_id, record in classes.items()
    }
    assert set(totals.values()) == {260}


def test_v23_speed_tiers_are_soft_except_large_archetypal_gaps():
    classes = load_classes()
    speeds = {class_id: record["base_stats"]["spd"] for class_id, record in classes.items()}
    assert speeds == {
        "warrior": 48,
        "mage": 48,
        "assassin": 68,
        "guardian": 36,
        "neutral": 52,
        "sorcerer": 60,
    }
    assert load_combat_config()["speed_band"] == 20


def test_move_power_bands_match_long_fight_chassis():
    # The classic chassis: every class's default kit (the 1v1 duel model).
    moves = load_moves()
    defaults = {m for c in load_classes().values() for m in c["move_ids"]}
    for move in (moves[m] for m in defaults):
        slot = move["slot"]
        if slot == "basic":
            assert 15 <= move["power"] <= 16
        elif slot == "signature":
            assert 11 <= move["power"] <= 13
        else:
            assert 22 <= move["power"] <= 25
            assert 0.70 <= move["accuracy"] <= 0.80


def test_every_gambit_has_higher_raw_ev_than_its_basic():
    classes = load_classes()
    moves = load_moves()
    for class_id, record in classes.items():
        kit = [moves[move_id] for move_id in record["move_ids"]]
        basic = next(move for move in kit if move["slot"] == "basic")
        gambit = next(move for move in kit if move["slot"] == "gambit")
        assert gambit["power"] * gambit["accuracy"] > basic["power"] * basic["accuracy"], class_id


def test_expected_basic_hit_horizon_is_about_six_hits():
    classes = load_classes()
    moves = load_moves()
    hit_counts = []
    for attacker_id, defender_id in permutations(classes, 2):
        attacker = classes[attacker_id]["base_stats"]
        defender = classes[defender_id]["base_stats"]
        basic_id = next(
            move_id
            for move_id in classes[attacker_id]["move_ids"]
            if moves[move_id]["slot"] == "basic"
        )
        hit_counts.append(_basic_hits_to_ko(attacker, defender, moves[basic_id]))

    average_hits = sum(hit_counts) / len(hit_counts)
    assert 5.5 <= average_hits <= 6.5
    assert min(hit_counts) >= 4.0
    assert max(hit_counts) <= 10.0


def test_signature_riders_match_v23_class_identity():
    moves = load_moves()
    assert moves["armor_break"]["target_stat_mods"] == [{"stat": "def", "amount": -8}]
    assert moves["mind_pierce"]["target_stat_mods"] == [{"stat": "res", "amount": -8}]
    assert moves["cripple"]["target_stat_mods"] == [
        {"stat": "def", "amount": -8},
        {"stat": "spd", "amount": -8},
    ]
    assert moves["fortify"]["self_stat_mods"] == [
        {"stat": "def", "amount": 8},
        {"stat": "res", "amount": 8},
    ]


def test_brace_is_meaningful_without_using_v22_tankier_value():
    assert load_combat_config()["brace_multiplier"] == 1.15


def test_class_alternatives_trade_rather_than_dominate():
    """Each class has one alternative per slot (Combat System 3.0 loadouts),
    and no alternative is simply better than the default on every axis."""
    moves = load_moves()
    for class_id, record in load_classes().items():
        alternatives = [moves[m] for m in record["unlockable_moves"]]
        assert sorted(m["slot"] for m in alternatives) == ["basic", "gambit", "signature"], class_id
        for alt in alternatives:
            default = next(moves[m] for m in record["move_ids"] if moves[m]["slot"] == alt["slot"])
            if alt["slot"] == "basic":
                assert alt["accuracy"] == 1.0 and alt["cooldown_turns"] == 0
            if alt["slot"] == "gambit":
                assert alt["accuracy"] < 1.0, alt["id"]
            dominates = (
                alt["power"] >= default["power"]
                and alt["accuracy"] >= default["accuracy"]
                and alt.get("speed", 0) >= default.get("speed", 0)
                and alt.get("target_rule", "enemy") == default.get("target_rule", "enemy")
                and not any(mod["amount"] < 0 for mod in alt.get("self_stat_mods", []))
                and alt.get("resonance_bonus", 0) >= default.get("resonance_bonus", 0)
                and alt["property"] == default["property"]
                # ...and keeps every rider the default has.
                and (sum(m["amount"] for m in alt.get("self_stat_mods", []) if m["amount"] > 0)
                     >= sum(m["amount"] for m in default.get("self_stat_mods", []) if m["amount"] > 0))
                and (len(alt.get("target_stat_mods", [])) >= len(default.get("target_stat_mods", [])))
                and (len(alt.get("status_effects", [])) >= len(default.get("status_effects", [])))
            )
            assert not dominates, f"{alt['id']} strictly beats {default['id']}"
