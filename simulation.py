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
import time
from pathlib import Path
from typing import Optional

from models import Unit, Move, ClassName, create_unit
from combat import battle_1v1, BattleResult
from ai import POLICIES


ALL_CLASSES = list(ClassName)
CLASS_ABBREV = {
    ClassName.WARRIOR: "WAR",
    ClassName.MAGE: "MAG",
    ClassName.ASSASSIN: "ASS",
    ClassName.GUARDIAN: "GUA",
    ClassName.NEUTRAL: "NEU",
    ClassName.SORCERER: "SOR",
}


# ── Win-Rate Matrix ──────────────────────────────────────────────────

def run_matchup(
    class_a: ClassName,
    class_b: ClassName,
    n_sims: int,
    policy_name: str = "greedy",
    log_actions: bool = False,
) -> dict:
    """Run n_sims battles between two classes. Returns stats dict."""
    policy = POLICIES[policy_name]
    wins_a = 0
    wins_b = 0
    total_turns = 0
    all_logs = []

    for _ in range(n_sims):
        unit_a = create_unit(class_a, f"{class_a.value}_A")
        unit_b = create_unit(class_b, f"{class_b.value}_B")
        result = battle_1v1(unit_a, unit_b, policy, policy, log_actions=log_actions)

        if result.winner_class == class_a.value:
            wins_a += 1
        else:
            wins_b += 1
        total_turns += result.turns

        if log_actions:
            all_logs.extend(result.logs)

    return {
        "class_a": class_a.value,
        "class_b": class_b.value,
        "n_sims": n_sims,
        "wins_a": wins_a,
        "wins_b": wins_b,
        "win_rate_a": round(100 * wins_a / n_sims, 1),
        "win_rate_b": round(100 * wins_b / n_sims, 1),
        "avg_turns": round(total_turns / n_sims, 1),
        "logs": all_logs,
    }


def generate_win_matrix(
    n_sims: int = 10000,
    policy_name: str = "greedy",
    verbose: bool = True,
) -> dict[tuple[ClassName, ClassName], float]:
    """
    Run all 6×6 matchups and return a win-rate matrix.
    Returns dict[(class_a, class_b)] = win_rate_a_percent.
    """
    matrix: dict[tuple[ClassName, ClassName], float] = {}
    total = len(ALL_CLASSES) * (len(ALL_CLASSES) - 1) // 2
    done = 0
    start = time.time()

    for i, class_a in enumerate(ALL_CLASSES):
        for j, class_b in enumerate(ALL_CLASSES):
            if i == j:
                matrix[(class_a, class_b)] = 50.0
                continue
            if i > j:
                matrix[(class_a, class_b)] = 100.0 - matrix[(class_b, class_a)]
                continue

            result = run_matchup(class_a, class_b, n_sims, policy_name)
            matrix[(class_a, class_b)] = result["win_rate_a"]
            matrix[(class_b, class_a)] = result["win_rate_b"]
            done += 1

            if verbose:
                elapsed = time.time() - start
                eta = (elapsed / done) * (total - done) if done > 0 else 0
                print(f"  [{done}/{total}] {CLASS_ABBREV[class_a]} vs {CLASS_ABBREV[class_b]}: "
                      f"{result['win_rate_a']}% / {result['win_rate_b']}% "
                      f"(avg {result['avg_turns']} turns) "
                      f"[ETA: {eta:.0f}s]")

    return matrix


def print_matrix(matrix: dict[tuple[ClassName, ClassName], float]):
    """Pretty-print the win-rate matrix."""
    header = "        " + "  ".join(f"{CLASS_ABBREV[c]:>5}" for c in ALL_CLASSES)
    print(header)
    print("        " + "  ".join("-----" for _ in ALL_CLASSES))

    for row_class in ALL_CLASSES:
        row_vals = []
        for col_class in ALL_CLASSES:
            if row_class == col_class:
                row_vals.append("  --- ")
            else:
                wr = matrix[(row_class, col_class)]
                row_vals.append(f"{wr:5.1f} ")
        print(f"{CLASS_ABBREV[row_class]:>6}  " + " ".join(row_vals))


def compute_averages(matrix: dict[tuple[ClassName, ClassName], float]) -> dict[ClassName, float]:
    """Compute average win rate per class (excluding mirror matches)."""
    avgs = {}
    for c in ALL_CLASSES:
        rates = [matrix[(c, opp)] for opp in ALL_CLASSES if opp != c]
        avgs[c] = round(sum(rates) / len(rates), 1)
    return avgs


def print_averages(avgs: dict[ClassName, float]):
    """Print ranked average win rates."""
    ranked = sorted(avgs.items(), key=lambda x: x[1], reverse=True)
    print("\n  Class       Avg Win %")
    print("  " + "-" * 24)
    for cls, rate in ranked:
        bar = "█" * int(rate / 2)
        delta = rate - 50.0
        sign = "+" if delta >= 0 else ""
        print(f"  {cls.value:<10}  {rate:5.1f}%  ({sign}{delta:.1f})  {bar}")


# ── Policy Comparison ────────────────────────────────────────────────

def compare_policies(
    policy_a_name: str,
    policy_b_name: str,
    n_sims: int = 10000,
    verbose: bool = True,
) -> dict[ClassName, dict]:
    """
    For each class, pit policy_a vs policy_b in mirror matches
    to see if the smarter policy wins more.
    """
    policy_a = POLICIES[policy_a_name]
    policy_b = POLICIES[policy_b_name]
    results = {}

    for cls in ALL_CLASSES:
        wins_a = 0
        for _ in range(n_sims):
            unit_a = create_unit(cls, f"{cls.value}_PolicyA")
            unit_b = create_unit(cls, f"{cls.value}_PolicyB")
            result = battle_1v1(unit_a, unit_b, policy_a, policy_b)
            if result.winner == unit_a.name:
                wins_a += 1

        wr = round(100 * wins_a / n_sims, 1)
        results[cls] = {"win_rate_a": wr, "win_rate_b": round(100 - wr, 1)}
        if verbose:
            print(f"  {cls.value:<10}  {policy_a_name}: {wr}%  vs  {policy_b_name}: {100-wr:.1f}%")

    return results


# ── CSV Export ───────────────────────────────────────────────────────

LOG_FIELDNAMES = [
    "sim", "turn", "actor", "actor_class", "target", "target_class",
    "move_name", "move_slot", "move_type", "raw_damage", "variance_roll",
    "hit", "final_damage", "target_hp_before", "target_hp_after",
    "actor_braced", "target_braced", "stat_mods_applied",
    "status_applied", "blocked_by_hex",
    "winner", "winner_class", "total_turns",
]


def export_battle_logs(
    class_a: ClassName,
    class_b: ClassName,
    n_sims: int,
    policy_name: str,
    filepath: str,
):
    """Run battles and export action logs to CSV for Jupyter analysis."""
    policy = POLICIES[policy_name]
    output = Path(filepath)
    output.parent.mkdir(parents=True, exist_ok=True)

    with output.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=LOG_FIELDNAMES)
        writer.writeheader()

        for sim_idx in range(1, n_sims + 1):
            unit_a = create_unit(class_a, f"{class_a.value}_A")
            unit_b = create_unit(class_b, f"{class_b.value}_B")
            result = battle_1v1(unit_a, unit_b, policy, policy, log_actions=True)

            for log in result.logs:
                writer.writerow({
                    "sim": sim_idx,
                    "turn": log.turn,
                    "actor": log.actor,
                    "actor_class": log.actor_class,
                    "target": log.target,
                    "target_class": log.target_class,
                    "move_name": log.move_name,
                    "move_slot": log.move_slot,
                    "move_type": log.move_type,
                    "raw_damage": log.raw_damage,
                    "variance_roll": round(log.variance_roll, 4),
                    "hit": log.hit,
                    "final_damage": log.final_damage,
                    "target_hp_before": log.target_hp_before,
                    "target_hp_after": log.target_hp_after,
                    "actor_braced": log.actor_braced,
                    "target_braced": log.target_braced,
                    "stat_mods_applied": "|".join(log.stat_mods_applied),
                    "status_applied": log.status_applied or "",
                    "blocked_by_hex": log.blocked_by_hex,
                    "winner": result.winner,
                    "winner_class": result.winner_class,
                    "total_turns": result.turns,
                })

    print(f"  Exported {n_sims} battles to {filepath}")
