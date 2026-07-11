"""Smoke tests for the three AI policies in ai.py."""

from __future__ import annotations

import pytest

from ai import POLICIES, expected_damage, policy_greedy, policy_lookahead, policy_random
from models import ClassName, create_unit

ALL_CLASSES = list(ClassName)


@pytest.mark.parametrize("policy_name", ["random", "greedy", "lookahead"])
@pytest.mark.parametrize("cls", ALL_CLASSES)
def test_policy_returns_available_move(policy_name, cls):
    policy = POLICIES[policy_name]
    attacker = create_unit(cls)
    defender = create_unit(ClassName.NEUTRAL)
    move = policy(attacker, defender, turn=1)
    assert move in attacker.available_moves()


@pytest.mark.parametrize("policy_name", ["random", "greedy", "lookahead"])
def test_policy_respects_cooldowns(policy_name):
    policy = POLICIES[policy_name]
    attacker = create_unit(ClassName.WARRIOR)
    defender = create_unit(ClassName.MAGE)
    # Put everything except the Basic on cooldown.
    attacker.cooldowns[attacker.moves[1].name] = 1
    attacker.cooldowns[attacker.moves[2].name] = 1
    for _ in range(20):
        move = policy(attacker, defender, turn=1)
        assert move is attacker.moves[0]


def test_greedy_prefers_higher_expected_damage():
    attacker = create_unit(ClassName.ASSASSIN)
    defender = create_unit(ClassName.MAGE)
    chosen = policy_greedy(attacker, defender, turn=1)
    best_ev = max(expected_damage(m, attacker, defender) for m in attacker.available_moves())
    # Greedy may take a guaranteed-KO line instead, but never below-best EV
    # against a full-HP opponent it cannot KO.
    assert expected_damage(chosen, attacker, defender) == pytest.approx(best_ev)


def test_greedy_takes_kill_when_available():
    attacker = create_unit(ClassName.WARRIOR)
    defender = create_unit(ClassName.MAGE)
    defender.hp = 1
    chosen = policy_greedy(attacker, defender, turn=1)
    # With the target at 1 HP every move KOs; greedy prefers accuracy.
    assert chosen.accuracy == max(m.accuracy for m in attacker.available_moves())


def test_expected_damage_positive():
    attacker = create_unit(ClassName.MAGE)
    defender = create_unit(ClassName.GUARDIAN)
    for move in attacker.moves:
        assert expected_damage(move, attacker, defender) > 0


def test_lookahead_returns_move_even_when_opponent_locked():
    attacker = create_unit(ClassName.NEUTRAL)
    defender = create_unit(ClassName.SORCERER)
    for m in defender.moves:
        defender.cooldowns[m.name] = 1
    move = policy_lookahead(attacker, defender, turn=3)
    assert move in attacker.available_moves()
