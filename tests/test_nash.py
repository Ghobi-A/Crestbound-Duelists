"""Fast tests for the stateful Nash/maximin analysis in nash.py."""

from __future__ import annotations

import numpy as np
import pytest

from models import ClassName
from nash import (
    analyse_matchup,
    build_payoff_matrix,
    policy_entropy,
    separability_residual,
    solve_maximin,
)


def test_payoff_matrix_shape_and_names():
    payoff, names_a, names_b = build_payoff_matrix(
        ClassName.WARRIOR, ClassName.MAGE, rollouts=24, seed=7
    )
    assert payoff.shape == (3, 3)
    assert names_a == ["Power Slash", "Armor Break", "Reckless Charge"]
    assert names_b == ["Arcane Bolt", "Mind Pierce", "Overload"]


def test_stateful_payoff_is_not_structurally_separable():
    payoff, _, _ = build_payoff_matrix(
        ClassName.WARRIOR, ClassName.GUARDIAN, rollouts=48, seed=11
    )
    assert separability_residual(payoff) > 1e-4


def test_payoff_generation_is_seed_reproducible():
    a, _, _ = build_payoff_matrix(
        ClassName.ASSASSIN, ClassName.NEUTRAL, rollouts=24, seed=99
    )
    b, _, _ = build_payoff_matrix(
        ClassName.ASSASSIN, ClassName.NEUTRAL, rollouts=24, seed=99
    )
    assert np.array_equal(a, b)


def test_maximin_returns_probability_distribution():
    payoff, _, _ = build_payoff_matrix(
        ClassName.ASSASSIN, ClassName.GUARDIAN, rollouts=24, seed=3
    )
    strategy, value = solve_maximin(payoff)
    assert strategy.shape == (3,)
    assert np.all(strategy >= 0)
    assert strategy.sum() == pytest.approx(1.0)
    assert np.isfinite(value)


def test_entropy_bounds():
    assert policy_entropy(np.array([1.0, 0.0, 0.0])) == pytest.approx(0.0)
    assert policy_entropy(np.array([1 / 3] * 3)) == pytest.approx(np.log2(3))


def test_analyse_matchup_returns_stateful_metadata():
    r = analyse_matchup(
        ClassName.NEUTRAL, ClassName.SORCERER, rollouts=24, seed=5
    )
    for key in (
        "payoff", "strategy_a", "entropy_a", "greedy_move", "nash_dominant",
        "analysis_model", "horizon", "rollouts", "separability_residual",
    ):
        assert key in r
    assert r["class_a"] == "Neutral"
    assert r["class_b"] == "Sorcerer"
    assert r["analysis_model"] == "stateful_rollout"
    assert r["horizon"] == 3
    assert r["rollouts"] == 24
