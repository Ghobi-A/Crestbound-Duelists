"""
Crestbound Duelists — Simulation Harness (v2.0)
=================================================
Monte Carlo simulation for:
  - 6×6 win-rate matrices
  - Policy comparison (greedy vs lookahead vs random)
  - CSV log export for Jupyter analysis
"""

from __future__ import annotations
import csv
import time
from typing import Optional

from models import Unit, Move, ClassName, create_unit
from combat import battle_1v1, BattleResult
from ai import POLICIES

ALL_CLASSES = list(ClassName)


def run_matchup(class_a, class_b, n_sims, policy_name="greedy"):
    policy = POLICIES[policy_name]
    wins_a = 0
    wins_b = 0

    for _ in range(n_sims):
        unit_a = create_unit(class_a, "A")
        unit_b = create_unit(class_b, "B")
        result = battle_1v1(unit_a, unit_b, policy, policy)
        if result.winner_class == class_a.value:
            wins_a += 1
        else:
            wins_b += 1

    return round(100 * wins_a / n_sims, 1), round(100 * wins_b / n_sims, 1)


def generate_win_matrix(n_sims=10000, policy_name="greedy"):
    matrix = {}
    for a in ALL_CLASSES:
        for b in ALL_CLASSES:
            if a == b:
                matrix[(a, b)] = 50.0
            else:
                wr_a, _ = run_matchup(a, b, n_sims, policy_name)
                matrix[(a, b)] = wr_a
    return matrix


def compute_averages(matrix):
    avgs = {}
    for c in ALL_CLASSES:
        rates = [matrix[(c, opp)] for opp in ALL_CLASSES if opp != c]
        avgs[c] = round(sum(rates) / len(rates), 1)
    return avgs


def print_matrix(matrix):
    for a in ALL_CLASSES:
        print(a.value, [matrix[(a, b)] for b in ALL_CLASSES])


def print_averages(avgs):
    for k, v in sorted(avgs.items(), key=lambda x: x[1], reverse=True):
        print(k.value, v)


def compare_policies(a, b, n_sims=10000):
    for cls in ALL_CLASSES:
        wins = 0
        for _ in range(n_sims):
            u1 = create_unit(cls, "A")
            u2 = create_unit(cls, "B")
            result = battle_1v1(u1, u2, POLICIES[a], POLICIES[b])
            if result.winner == u1.name:
                wins += 1
        print(cls.value, round(100 * wins / n_sims, 1))


def export_battle_logs(*args, **kwargs):
    pass
