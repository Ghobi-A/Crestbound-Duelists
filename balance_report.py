"""
Crestbound Duelists — Fast Balance Report
===========================================
A quick development report for iterating on data/*.yaml. Runs a small
Monte Carlo pass and flags balance smells. Not a replacement for the
full main.py suite — this is the "did I just break something?" check.

Usage:
    python balance_report.py            # ~500 sims per matchup
    python balance_report.py --sims 200
"""

from __future__ import annotations

import argparse
import time
from collections import Counter

from ai import POLICIES
from combat import battle_1v1
from loaders import load_crests, load_entities
from models import ClassName, create_unit

ALL_CLASSES = list(ClassName)

# Thresholds for warnings.
EXTREME_MATCHUP = 70.0      # win rate above this (or below 100-this) is flagged
DOMINANT_MOVE_SHARE = 0.60  # one move above this share of a class's actions


def run_report(n_sims: int, policy_name: str = "greedy") -> None:
    policy = POLICIES[policy_name]
    start = time.time()

    win_totals: dict[ClassName, float] = {c: 0.0 for c in ALL_CLASSES}
    move_usage: dict[ClassName, Counter] = {c: Counter() for c in ALL_CLASSES}
    extreme_warnings: list[str] = []
    total_turns = 0
    total_battles = 0

    for i, class_a in enumerate(ALL_CLASSES):
        for class_b in ALL_CLASSES[i + 1:]:
            wins_a = 0
            for _ in range(n_sims):
                unit_a = create_unit(class_a, "A")
                unit_b = create_unit(class_b, "B")
                result = battle_1v1(unit_a, unit_b, policy, policy, log_actions=True)
                if result.winner == "A":
                    wins_a += 1
                total_turns += result.turns
                total_battles += 1
                for log in result.logs:
                    cls = class_a if log.actor == "A" else class_b
                    move_usage[cls][log.move_name] += 1

            rate_a = 100 * wins_a / n_sims
            win_totals[class_a] += rate_a
            win_totals[class_b] += 100 - rate_a
            if rate_a >= EXTREME_MATCHUP or rate_a <= 100 - EXTREME_MATCHUP:
                extreme_warnings.append(
                    f"{class_a.value} vs {class_b.value}: {rate_a:.1f}% / {100 - rate_a:.1f}%"
                )

    n_opponents = len(ALL_CLASSES) - 1

    print(f"\n{'=' * 58}")
    print(f"  BALANCE REPORT  ({n_sims} sims/matchup, {policy_name} policy)")
    print(f"{'=' * 58}\n")

    print("  Class average win rates")
    print("  " + "-" * 38)
    averages = {c: win_totals[c] / n_opponents for c in ALL_CLASSES}
    for cls, rate in sorted(averages.items(), key=lambda kv: -kv[1]):
        delta = rate - 50
        print(f"    {cls.value:<10} {rate:5.1f}%  ({'+' if delta >= 0 else ''}{delta:.1f})")

    print(f"\n  Average battle duration: {total_turns / total_battles:.1f} turns")

    print("\n  Move usage per class")
    print("  " + "-" * 38)
    dominant_warnings: list[str] = []
    for cls in ALL_CLASSES:
        usage = move_usage[cls]
        total = sum(usage.values())
        shares = ", ".join(
            f"{name} {100 * count / total:.0f}%" for name, count in usage.most_common()
        )
        print(f"    {cls.value:<10} {shares}")
        for name, count in usage.items():
            if count / total > DOMINANT_MOVE_SHARE:
                dominant_warnings.append(
                    f"{cls.value}: {name} at {100 * count / total:.0f}% of actions"
                )

    print("\n  Warnings")
    print("  " + "-" * 38)
    if not dominant_warnings and not extreme_warnings:
        print("    none — no dominant moves, no extreme matchups")
    for warning in dominant_warnings:
        print(f"    DOMINANT MOVE   {warning}")
    for warning in extreme_warnings:
        print(f"    EXTREME MATCHUP {warning}")

    print("\n  Crest / Entity class compatibility")
    print("  " + "-" * 38)
    crest_counts: Counter = Counter()
    for crest in load_crests().values():
        for class_id in crest["compatible_classes"]:
            crest_counts[class_id] += 1
    entity_counts: Counter = Counter()
    for entity in load_entities().values():
        for class_id in entity["compatible_classes"]:
            entity_counts[class_id] += 1
    for cls in ALL_CLASSES:
        class_id = cls.value.lower()
        print(f"    {cls.value:<10} {crest_counts[class_id]} crests, "
              f"{entity_counts[class_id]} entities")

    print(f"\n  Completed in {time.time() - start:.1f}s\n")


def main() -> None:
    parser = argparse.ArgumentParser(description="Fast balance report for data iteration.")
    parser.add_argument("--sims", type=int, default=500, help="simulations per matchup")
    parser.add_argument("--policy", default="greedy", choices=sorted(POLICIES))
    args = parser.parse_args()
    run_report(args.sims, args.policy)


if __name__ == "__main__":
    main()
