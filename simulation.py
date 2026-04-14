"""
Crestbound Duelists — Simulation Harness (v2.1)
=================================================
Monte Carlo simulation for:
  - 6×6 win-rate matrices
  - Policy comparison (greedy vs lookahead vs random)
  - CSV log export for Jupyter analysis
"""

from __future__ import annotations
import csv
from pathlib import Path

from models import ClassName, create_unit
from combat import battle_1v1
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


def export_battle_logs(class_a, class_b, n_sims=1000, policy_name="greedy", output_path="results/battle_logs.csv"):
    policy = POLICIES[policy_name]
    output_file = Path(output_path)
    output_file.parent.mkdir(parents=True, exist_ok=True)

    with output_file.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow([
            "sim", "turn", "actor", "actor_class", "target", "target_class",
            "move_name", "move_slot", "move_type", "raw_damage", "variance_roll",
            "hit", "final_damage", "target_hp_before", "target_hp_after",
            "actor_braced", "target_braced", "stat_mods_applied", "status_applied",
            "blocked_by_hex", "winner", "winner_class", "turns"
        ])

        for sim_idx in range(1, n_sims + 1):
            unit_a = create_unit(class_a, "A")
            unit_b = create_unit(class_b, "B")
            result = battle_1v1(unit_a, unit_b, policy, policy, log_actions=True)

            for log in result.logs:
                writer.writerow([
                    sim_idx,
                    log.turn,
                    log.actor,
                    log.actor_class,
                    log.target,
                    log.target_class,
                    log.move_name,
                    log.move_slot,
                    log.move_type,
                    log.raw_damage,
                    round(log.variance_roll, 4),
                    log.hit,
                    log.final_damage,
                    log.target_hp_before,
                    log.target_hp_after,
                    log.actor_braced,
                    log.target_braced,
                    "|".join(log.stat_mods_applied),
                    log.status_applied or "",
                    log.blocked_by_hex,
                    result.winner,
                    result.winner_class,
                    result.turns,
                ])
