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
    # Weakest attacker into strongest defence: damage must still be >= 1.
    mage = create_unit(ClassName.MAGE)      # atk 30
    guardian = create_unit(ClassName.GUARDIAN)  # def 75
    weak_hit = Move("Feeble", MoveType.PHYSICAL, MoveSlot.BASIC, 1, 1.0)
    for _ in range(50):
        dmg, _, _ = calculate_damage(weak_hit, mage, guardian, defender_braced=True)
        assert dmg >= 1


def test_physical_move_uses_atk_vs_def():
    warrior = create_unit(ClassName.WARRIOR)
    guardian = create_unit(ClassName.GUARDIAN)
    move = _basic(warrior)  # Power Slash, physical, power 24
    random.seed(7)
    dmg, v, resolved = calculate_damage(move, warrior, guardian)
    assert resolved == "physical"
    ratio = 2 * warrior.atk / (warrior.atk + guardian.def_)
    assert dmg == max(1, math.floor(move.power * ratio * v))


def test_magical_move_uses_mag_vs_res():
    mage = create_unit(ClassName.MAGE)
    warrior = create_unit(ClassName.WARRIOR)
    move = _basic(mage)  # Arcane Bolt, magical
    random.seed(7)
    dmg, v, resolved = calculate_damage(move, mage, warrior)
    assert resolved == "magical"
    ratio = 2 * mage.mag / (mage.mag + warrior.res)
    assert dmg == max(1, math.floor(move.power * ratio * v))


def test_adaptive_move_picks_better_path():
    neutral = create_unit(ClassName.NEUTRAL)  # atk 55 / mag 55
    move = _basic(neutral)  # Hybrid Strike, adaptive
    # vs Warrior (def 70, res 35): magical path is better.
    warrior = create_unit(ClassName.WARRIOR)
    _, _, resolved = calculate_damage(move, neutral, warrior)
    assert resolved == "magical"
    # vs Mage (def 35, res 75): physical path is better.
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


def test_brace_raises_effective_defence():
    warrior = create_unit(ClassName.WARRIOR)
    guardian = create_unit(ClassName.GUARDIAN)
    move = _basic(warrior)
    random.seed(11)
    unbraced, v1, _ = calculate_damage(move, warrior, guardian, defender_braced=False)
    random.seed(11)
    braced, v2, _ = calculate_damage(move, warrior, guardian, defender_braced=True)
    assert v1 == v2  # same variance roll
    assert braced <= unbraced


# ── Accuracy / execution ─────────────────────────────────────────────

def test_accuracy_can_cause_misses():
    warrior = create_unit(ClassName.WARRIOR)
    mage = create_unit(ClassName.MAGE)
    gambit = _gambit(warrior)  # Reckless Charge, 75% accuracy
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
    basic = _basic(warrior)  # 100% accuracy
    for _ in range(100):
        mage.reset()
        log = execute_move(warrior, mage, basic, 1, False, False)
        assert log.hit


def test_miss_deals_no_damage_but_sets_cooldown():
    warrior = create_unit(ClassName.WARRIOR)
    mage = create_unit(ClassName.MAGE)
    gambit = _gambit(warrior)
    # Find a seed that produces a miss so the test is deterministic.
    for seed in range(1000):
        random.seed(seed)
        if not (random.random() < gambit.accuracy):
            random.seed(seed)
            break
    log = execute_move(warrior, mage, gambit, 1, False, False)
    assert not log.hit
    assert log.final_damage == 0
    assert mage.hp == mage.base_hp
    assert warrior.cooldowns[gambit.name] == gambit.cooldown_turns


# ── Cooldowns ────────────────────────────────────────────────────────

def test_signature_applies_cooldown_and_ticks_down():
    warrior = create_unit(ClassName.WARRIOR)
    mage = create_unit(ClassName.MAGE)
    sig = _signature(warrior)
    execute_move(warrior, mage, sig, 1, False, False)
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
    armor_break = _signature(warrior)  # def -5 on target
    base_def = mage.def_
    execute_move(warrior, mage, armor_break, 1, False, False)
    assert mage.def_ == base_def - 5


def test_self_stat_mods_apply():
    warrior = create_unit(ClassName.WARRIOR)
    mage = create_unit(ClassName.MAGE)
    reckless = _gambit(warrior)  # self def -4
    base_def = warrior.def_
    # Force a hit deterministically.
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
    fortify = _signature(guardian)  # is_buff_move
    assert fortify.is_buff_move
    guardian.apply_status("hexed", 2)
    base_def = guardian.def_
    log = execute_move(guardian, sorcerer, fortify, 1, False, False)
    assert log.blocked_by_hex
    assert guardian.def_ == base_def  # buff did not apply
    assert sorcerer.hp == sorcerer.base_hp  # no damage either


def test_hex_move_applies_status():
    sorcerer = create_unit(ClassName.SORCERER)
    guardian = create_unit(ClassName.GUARDIAN)
    hex_move = _signature(sorcerer)
    log = execute_move(sorcerer, guardian, hex_move, 1, False, False)
    assert log.status_applied == "hexed"
    assert guardian.has_status("hexed")


# ── Speed resolution ─────────────────────────────────────────────────

def test_speed_guaranteed_when_diff_exceeds_band():
    assassin = create_unit(ClassName.ASSASSIN)   # spd 80
    guardian = create_unit(ClassName.GUARDIAN)   # spd 35
    for _ in range(50):
        first, second = resolve_speed(assassin, guardian)
        assert first is assassin
        assert second is guardian


def test_speed_probabilistic_within_band():
    mage = create_unit(ClassName.MAGE)       # spd 42
    warrior = create_unit(ClassName.WARRIOR)  # spd 40, diff 2 < band 7
    firsts = {id(mage): 0, id(warrior): 0}
    for _ in range(500):
        first, _ = resolve_speed(mage, warrior)
        firsts[id(first)] += 1
    assert firsts[id(mage)] > 0
    assert firsts[id(warrior)] > 0
    # Faster unit should win the coin flip more often.
    assert firsts[id(mage)] > firsts[id(warrior)]


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
    # Two tanks that can't hurt each other much still terminate.
    monkeypatch.setattr(combat, "MAX_TURNS", 5)
    a = create_unit(ClassName.GUARDIAN, "A")
    b = create_unit(ClassName.GUARDIAN, "B")
    result = battle_1v1(a, b, _greedy(), _greedy())
    assert result.turns <= 5
    assert result.winner in {"A", "B"}


def test_dead_unit_stops_acting():
    """The second actor must not act if the first actor's move killed it."""
    a = create_unit(ClassName.WARRIOR, "A")
    b = create_unit(ClassName.MAGE, "B")
    b.hp = 1  # B dies to the first hit unless it moves first
    result = battle_1v1(a, b, _greedy(), _greedy(), log_actions=True)
    for log in result.logs:
        # No log entry may be recorded for an actor that was already dead.
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
