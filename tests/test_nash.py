"""Fast tests for the Nash/maximin analysis in nash.py."""

from __future__ import annotations

import numpy as np
import pytest

from models import ClassName
from nash import analyse_matchup, build_payoff_matrix, policy_entropy, solve_maximin


def test_payoff_matrix_shape_and_names():
    payoff, names_a, names_b = build_payoff_matrix(ClassName.WARRIOR, ClassName.MAGE)
    assert payoff.shape == (3, 3)
    assert names_a == ["Power Slash", "Armor Break", "Reckless Charge"]
    assert names_b == ["Arcane Bolt", "Mind Pierce", "Overload"]


def test_maximin_returns_probability_distribution():
    payoff, _, _ = build_payoff_matrix(ClassName.ASSASSIN, ClassName.GUARDIAN)
    strategy, value = solve_maximin(payoff)
    assert strategy.shape == (3,)
    assert np.all(strategy >= 0)
    assert strategy.sum() == pytest.approx(1.0)


def test_entropy_bounds():
    assert policy_entropy(np.array([1.0, 0.0, 0.0])) == pytest.approx(0.0)
    assert policy_entropy(np.array([1 / 3] * 3)) == pytest.approx(np.log2(3))


def test_analyse_matchup_returns_expected_keys():
    r = analyse_matchup(ClassName.NEUTRAL, ClassName.SORCERER)
    for key in ("payoff", "strategy_a", "entropy_a", "greedy_move", "nash_dominant"):
        assert key in r
    assert r["class_a"] == "Neutral"
    assert r["class_b"] == "Sorcerer"
