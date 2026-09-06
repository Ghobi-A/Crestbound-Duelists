"""Regression tests for the combat engine in combat.py."""

from __future__ import annotations

import math
import random

import pytest

import combat
from combat import (
    battle_1v1,
    calculate_damage,
    execute_move,
    resolve_speed,
)
from models import ClassName, Move, MoveSlot, MoveType, create_unit


def _basic(unit):
    return unit.moves[0]


def _signature(unit):
    return unit.moves[1]


def _gambit(unit):
    return unit.moves[2]


# ── Damage ───────────────────────────────────────────────────────────

def test_damage_is_at_least_one():
    mage = create_unit(ClassName.MAGE)
    guardian = create_unit(ClassName.GUARDIAN)
    weak_hit = Move("Feeble", MoveType.PHYSICAL, MoveSlot.BASIC, 1, 1.0)
    for _ in range(50):
        dmg, _, _ = calculate_damage(weak_hit, mage, guardian, defender_braced=True)
        assert dmg >= 1


def test_physical_move_uses_atk_vs_def():
    warrior = create_unit(ClassName.WARRIOR)
    guardian = create_unit(ClassName.GUARDIAN)
    move = _basic(warrior)
    random.seed(7)
    dmg, v, resolved = calculate_damage(move, warrior, guardian)
    assert resolved == "physical"
    ratio = 2 * warrior.atk / (warrior.atk + guardian.def_)
    assert dmg == max(1, math.floor(move.power * ratio * v))


def test_magical_move_uses_mag_vs_res():
    mage = create_unit(ClassName.MAGE)
    warrior = create_unit(ClassName.WARRIOR)
    move = _basic(mage)
    random.seed(7)
    dmg, v, resolved = calculate_damage(move, mage, warrior)
    assert resolved == "magical"
    ratio = 2 * mage.mag / (mage.mag + warrior.res)
    assert dmg == max(1, math.floor(move.power * ratio * v))


def test_adaptive_move_picks_better_path():
    neutral = create_unit(ClassName.NEUTRAL)
    move = _basic(neutral)
    warrior = create_unit(ClassName.WARRIOR)
    _, _, resolved = calculate_damage(move, neutral, warrior)
    assert resolved == "magical"
    mage = create_unit(ClassName.MAGE)
    _, _, resolved = calculate_damage(move, neutral, mage)
    assert resolved == "physical"


def test_damage_variance_within_configured_bounds():
    warrior = create_unit(ClassName.WARRIOR)
    mage = create_unit(ClassName.MAGE)
    move = _basic(warrior)
    for _ in range(200):
        _, v, _ = calculate_damage(move, warrior, mage)
        assert combat.VARIANCE_LO <= v <= combat.VARIANCE_HI


def test_brace_provides_meaningful_mitigation():
    warrior = create_unit(ClassName.WARRIOR)
    guardian = create_unit(ClassName.GUARDIAN)
    move = _basic(warrior)
    random.seed(11)
    unbraced, v1, _ = calculate_damage(move, warrior, guardian, defender_braced=False)
    random.seed(11)
    braced, v2, _ = calculate_damage(move, warrior, guardian, defender_braced=True)
    assert v1 == v2
    assert braced < unbraced
    assert braced <= math.floor(unbraced * 0.95)


def test_defence_break_signatures_ignore_brace():
    warrior = create_unit(ClassName.WARRIOR)
    guardian = create_unit(ClassName.GUARDIAN)
    armor_break = _signature(warrior)
    random.seed(17)
    unbraced, v1, _ = calculate_damage(armor_break, warrior, guardian, False)
    random.seed(17)
    braced, v2, _ = calculate_damage(armor_break, warrior, guardian, True)
    assert v1 == v2
    assert braced == unbraced


# ── Accuracy / execution ─────────────────────────────────────────────

def test_accuracy_can_cause_misses():
    warrior = create_unit(ClassName.WARRIOR)
    mage = create_unit(ClassName.MAGE)
    gambit = _gambit(warrior)
    hits = misses = 0
    for _ in range(300):
        warrior.reset()
        mage.reset()
        log = execute_move(warrior, mage, gambit, 1, False, False)
        if log.hit:
            hits += 1
        else:
            misses += 1
    assert hits > 0
    assert misses > 0


def test_perfect_accuracy_never_misses():
    warrior = create_unit(ClassName.WARRIOR)
    mage = create_unit(ClassName.MAGE)
    basic = _basic(warrior)
    for _ in range(100):
        mage.reset()
        log = execute_move(warrior, mage, basic, 1, False, False)
        assert log.hit


def test_miss_deals_no_damage_but_sets_full_cooldown_window():
    warrior = create_unit(ClassName.WARRIOR)
    mage = create_unit(ClassName.MAGE)
    gambit = _gambit(warrior)
    for seed in range(1000):
        random.seed(seed)
        if not (random.random() < gambit.accuracy):
            random.seed(seed)
            break
    log = execute_move(warrior, mage, gambit, 1, False, False)
    assert not log.hit
    assert log.final_damage == 0
    assert mage.hp == mage.base_hp
    assert warrior.cooldowns[gambit.name] == gambit.cooldown_turns + 1


# ── Cooldowns ────────────────────────────────────────────────────────

def test_signature_cooldown_skips_the_next_round():
    warrior = create_unit(ClassName.WARRIOR)
    mage = create_unit(ClassName.MAGE)
    sig = _signature(warrior)
    execute_move(warrior, mage, sig, 1, False, False)
    assert warrior.cooldowns[sig.name] == 2
    assert sig not in warrior.available_moves()

    warrior.tick_cooldowns()
    assert warrior.cooldowns[sig.name] == 1
    assert sig not in warrior.available_moves()

    warrior.tick_cooldowns()
    assert warrior.cooldowns[sig.name] == 0
    assert sig in warrior.available_moves()


def test_basic_move_has_no_cooldown_after_use():
    warrior = create_unit(ClassName.WARRIOR)
    mage = create_unit(ClassName.MAGE)
    basic = _basic(warrior)
    execute_move(warrior, mage, basic, 1, False, False)
    assert warrior.cooldowns.get(basic.name, 0) == 0
    assert basic in warrior.available_moves()


def test_unavailable_moves_are_excluded():
    warrior = create_unit(ClassName.WARRIOR)
    warrior.cooldowns[_signature(warrior).name] = 1
    warrior.cooldowns[_gambit(warrior).name] = 1
    available = warrior.available_moves()
    assert available == [_basic(warrior)]


# ── Stat modifiers ───────────────────────────────────────────────────

def test_target_stat_mods_apply():
    warrior = create_unit(ClassName.WARRIOR)
    mage = create_unit(ClassName.MAGE)
    armor_break = _signature(warrior)
    base_def = mage.def_
    execute_move(warrior, mage, armor_break, 1, False, False)
    assert mage.def_ == base_def - 8


def test_self_stat_mods_apply():
    warrior = create_unit(ClassName.WARRIOR)
    mage = create_unit(ClassName.MAGE)
    reckless = _gambit(warrior)
    base_def = warrior.def_
    for seed in range(1000):
        random.seed(seed)
        if random.random() < reckless.accuracy:
            random.seed(seed)
            break
    execute_move(warrior, mage, reckless, 1, False, False)
    assert warrior.def_ == base_def - 4


def test_stat_modifiers_expire_after_decay():
    from models import STAT_DECAY

    unit = create_unit(ClassName.MAGE)
    unit.apply_stat_mod("def", -5, STAT_DECAY)
    base = unit.base_def
    assert unit.def_ == base - 5
    for _ in range(STAT_DECAY):
        unit.tick_modifiers()
    assert unit.def_ == base


def test_effective_stat_never_below_one():
    unit = create_unit(ClassName.MAGE)
    unit.apply_stat_mod("atk", -999, 3)
    assert unit.atk == 1


def test_all_gambits_have_positive_raw_ev_vs_basic():
    for class_name in ClassName:
        unit = create_unit(class_name)
        basic = _basic(unit)
        gambit = _gambit(unit)
        assert gambit.power * gambit.accuracy > basic.power * basic.accuracy


def test_cripple_controls_initiative():
    assassin = create_unit(ClassName.ASSASSIN)
    neutral = create_unit(ClassName.NEUTRAL)
    cripple = _signature(assassin)
    base_spd = neutral.spd
    execute_move(assassin, neutral, cripple, 1, False, False)
    assert neutral.spd == base_spd - 8


# ── Statuses / Hex ───────────────────────────────────────────────────

def test_status_ticks_and_expires():
    unit = create_unit(ClassName.GUARDIAN)
    unit.apply_status("hexed", 2)
    assert unit.has_status("hexed")
    unit.tick_modifiers()
    assert unit.has_status("hexed")
    unit.tick_modifiers()
    assert not unit.has_status("hexed")


def test_hex_reapplication_refreshes_duration():
    unit = create_unit(ClassName.GUARDIAN)
    unit.apply_status("hexed", 1)
    unit.apply_status("hexed", 3)
    assert len(unit.status_effects) == 1
    assert unit.status_effects[0].turns_remaining == 3


def test_hex_blocks_buff_moves():
    guardian = create_unit(ClassName.GUARDIAN)
    sorcerer = create_unit(ClassName.SORCERER)
    fortify = _signature(guardian)
    assert fortify.is_buff_move
    guardian.apply_status("hexed", 2)
    base_def = guardian.def_
    log = execute_move(guardian, sorcerer, fortify, 1, False, False)
    assert log.blocked_by_hex
    assert guardian.def_ == base_def
    assert sorcerer.hp == sorcerer.base_hp


def test_hex_move_applies_status_and_strips_positive_modifiers():
    sorcerer = create_unit(ClassName.SORCERER)
    guardian = create_unit(ClassName.GUARDIAN)
    guardian.apply_stat_mod("def", 8, 3)
    assert guardian.def_ == guardian.base_def + 8

    hex_move = _signature(sorcerer)
    log = execute_move(sorcerer, guardian, hex_move, 1, False, False)
    assert log.status_applied == "hexed"
    assert guardian.has_status("hexed")
    assert guardian.def_ == guardian.base_def


def test_hex_suppresses_positive_but_not_negative_tradeoff_mods():
    neutral = create_unit(ClassName.NEUTRAL)
    sorcerer = create_unit(ClassName.SORCERER)
    neutral.apply_status("hexed", 2)
    focus_shift = _signature(neutral)
    execute_move(neutral, sorcerer, focus_shift, 1, False, False)
    assert neutral.atk == neutral.base_atk
    assert neutral.mag == neutral.base_mag
    assert neutral.def_ == neutral.base_def - 5
    assert neutral.res == neutral.base_res - 5


# ── Speed resolution ─────────────────────────────────────────────────

def test_speed_guaranteed_when_diff_exceeds_band():
    assassin = create_unit(ClassName.ASSASSIN)
    guardian = create_unit(ClassName.GUARDIAN)
    for _ in range(50):
        first, second = resolve_speed(assassin, guardian)
        assert first is assassin
        assert second is guardian


def test_speed_probabilistic_inside_wider_band():
    neutral = create_unit(ClassName.NEUTRAL)    # spd 54
    guardian = create_unit(ClassName.GUARDIAN)  # spd 36; diff 18 < band 20
    firsts = {id(neutral): 0, id(guardian): 0}
    random.seed(12345)
    for _ in range(1000):
        first, _ = resolve_speed(neutral, guardian)
        firsts[id(first)] += 1
    assert firsts[id(neutral)] > 0
    assert firsts[id(guardian)] > 0
    assert firsts[id(neutral)] > firsts[id(guardian)]


# ── Battle loop ──────────────────────────────────────────────────────

def _greedy():
    from ai import policy_greedy
    return policy_greedy


def test_battle_produces_winner_and_loser():
    a = create_unit(ClassName.WARRIOR, "A")
    b = create_unit(ClassName.MAGE, "B")
    result = battle_1v1(a, b, _greedy(), _greedy())
    assert {result.winner, result.loser} == {"A", "B"}
    assert result.turns >= 1


def test_battle_ends_when_a_unit_dies():
    a = create_unit(ClassName.WARRIOR, "A")
    b = create_unit(ClassName.MAGE, "B")
    result = battle_1v1(a, b, _greedy(), _greedy())
    assert (not a.is_alive) or (not b.is_alive)
    loser = a if result.loser == "A" else b
    assert loser.hp == 0


def test_battle_respects_max_turns(monkeypatch):
    monkeypatch.setattr(combat, "MAX_TURNS", 5)
    a = create_unit(ClassName.GUARDIAN, "A")
    b = create_unit(ClassName.GUARDIAN, "B")
    result = battle_1v1(a, b, _greedy(), _greedy())
    assert result.turns <= 5
    assert result.winner in {"A", "B"}


def test_dead_unit_stops_acting():
    a = create_unit(ClassName.WARRIOR, "A")
    b = create_unit(ClassName.MAGE, "B")
    b.hp = 1
    result = battle_1v1(a, b, _greedy(), _greedy(), log_actions=True)
    for log in result.logs:
        actor = a if log.actor == "A" else b
        assert log.target_hp_before > 0 or actor.is_alive


def test_battle_logs_generated_when_requested():
    a = create_unit(ClassName.WARRIOR, "A")
    b = create_unit(ClassName.MAGE, "B")
    result = battle_1v1(a, b, _greedy(), _greedy(), log_actions=True)
    assert len(result.logs) >= 1
    log = result.logs[0]
    assert log.actor in {"A", "B"}
    assert log.move_name


def test_battle_logs_empty_by_default():
    a = create_unit(ClassName.WARRIOR, "A")
    b = create_unit(ClassName.MAGE, "B")
    result = battle_1v1(a, b, _greedy(), _greedy())
    assert result.logs == []
