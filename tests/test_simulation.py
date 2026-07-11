"""Fast tests for the Monte Carlo simulation harness in simulation.py."""

from __future__ import annotations

import csv

from models import ClassName
from simulation import LOG_FIELDNAMES, compute_averages, export_battle_logs, run_matchup


def test_run_matchup_small():
    result = run_matchup(ClassName.WARRIOR, ClassName.MAGE, n_sims=20, policy_name="greedy")
    assert result["n_sims"] == 20
    assert result["wins_a"] + result["wins_b"] == 20
    assert result["win_rate_a"] + result["win_rate_b"] == 100.0
    assert result["avg_turns"] >= 1


def test_run_matchup_collects_logs_when_requested():
    result = run_matchup(
        ClassName.ASSASSIN, ClassName.GUARDIAN, n_sims=5,
        policy_name="random", log_actions=True,
    )
    assert len(result["logs"]) >= 5


def test_compute_averages_small_matrix():
    classes = list(ClassName)
    # Build a fake symmetric matrix: everything 50%.
    matrix = {(a, b): 50.0 for a in classes for b in classes}
    avgs = compute_averages(matrix)
    assert set(avgs) == set(classes)
    assert all(v == 50.0 for v in avgs.values())


def test_export_battle_logs_creates_valid_csv(tmp_path):
    out = tmp_path / "logs.csv"
    export_battle_logs(ClassName.SORCERER, ClassName.GUARDIAN, 3, "greedy", str(out))
    assert out.exists()
    with out.open(newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    assert len(rows) >= 3  # at least one action per battle
    assert set(rows[0]) == set(LOG_FIELDNAMES)
    sims = {row["sim"] for row in rows}
    assert sims == {"1", "2", "3"}
    for row in rows:
        assert row["winner"]
        assert int(row["total_turns"]) >= 1
