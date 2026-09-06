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
from loaders import load_crests, load_entities, load_moves
from models import ClassName, create_unit

ALL_CLASSES = list(ClassName)

# v2.3 chassis targets. These are diagnostic bands, not claims that every
# matchup must be symmetric: deliberate hard counters may reach ~30/70.
CLASS_AVG_LOW = 47.0
CLASS_AVG_HIGH = 53.0
TARGET_TURNS_LOW = 6.0
TARGET_TURNS_HIGH = 8.0
EXTREME_MATCHUP = 75.0
DOMINANT_MOVE_SHARE = 0.60
TARGET_SLOT_SHARE = {
    "basic": (0.35, 0.50),
    "signature": (0.25, 0.35),
    "gambit": (0.15, 0.30),
}


def run_report(n_sims: int, policy_name: str = "greedy") -> None:
    policy = POLICIES[policy_name]
    start = time.time()
    moves = load_moves()
    slot_by_name = {move["name"]: move["slot"] for move in moves.values()}

    win_totals: dict[ClassName, float] = {c: 0.0 for c in ALL_CLASSES}
    move_usage: dict[ClassName, Counter] = {c: Counter() for c in ALL_CLASSES}
    slot_usage: Counter = Counter()
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
                    slot = slot_by_name.get(log.move_name)
                    if slot:
                        slot_usage[slot] += 1

            rate_a = 100 * wins_a / n_sims
            win_totals[class_a] += rate_a
            win_totals[class_b] += 100 - rate_a
            if rate_a >= EXTREME_MATCHUP or rate_a <= 100 - EXTREME_MATCHUP:
                extreme_warnings.append(
                    f"{class_a.value} vs {class_b.value}: {rate_a:.1f}% / {100 - rate_a:.1f}%"
                )

    n_opponents = len(ALL_CLASSES) - 1

    print(f"\n{'=' * 66}")
    print(f"  BALANCE REPORT  ({n_sims} sims/matchup, {policy_name} policy)")
    print(f"{'=' * 66}\n")

    print("  Class average win rates  [target 47–53%]")
    print("  " + "-" * 44)
    averages = {c: win_totals[c] / n_opponents for c in ALL_CLASSES}
    class_warnings: list[str] = []
    for cls, rate in sorted(averages.items(), key=lambda kv: -kv[1]):
        delta = rate - 50
        marker = "" if CLASS_AVG_LOW <= rate <= CLASS_AVG_HIGH else "  !"
        print(f"    {cls.value:<10} {rate:5.1f}%  ({'+' if delta >= 0 else ''}{delta:.1f}){marker}")
        if not CLASS_AVG_LOW <= rate <= CLASS_AVG_HIGH:
            class_warnings.append(f"{cls.value}: {rate:.1f}% average win rate")

    average_turns = total_turns / total_battles
    turns_marker = "" if TARGET_TURNS_LOW <= average_turns <= TARGET_TURNS_HIGH else "  !"
    print(
        f"\n  Average battle duration: {average_turns:.1f} turns "
        f"[target {TARGET_TURNS_LOW:.0f}–{TARGET_TURNS_HIGH:.0f}]{turns_marker}"
    )

    print("\n  Global action-slot usage")
    print("  " + "-" * 44)
    total_slots = sum(slot_usage.values())
    slot_warnings: list[str] = []
    for slot in ("basic", "signature", "gambit"):
        share = slot_usage[slot] / total_slots if total_slots else 0.0
        lo, hi = TARGET_SLOT_SHARE[slot]
        marker = "" if lo <= share <= hi else "  !"
        print(f"    {slot:<10} {share:6.1%}  [target {lo:.0%}–{hi:.0%}]{marker}")
        if not lo <= share <= hi:
            slot_warnings.append(f"{slot}: {share:.1%} action share")

    print("\n  Move usage per class")
    print("  " + "-" * 44)
    dominant_warnings: list[str] = []
    for cls in ALL_CLASSES:
        usage = move_usage[cls]
        total = sum(usage.values())
        shares = ", ".join(
            f"{name} {100 * count / total:.0f}%" for name, count in usage.most_common()
        ) if total else "no actions"
        print(f"    {cls.value:<10} {shares}")
        for name, count in usage.items():
            if total and count / total > DOMINANT_MOVE_SHARE:
                dominant_warnings.append(
                    f"{cls.value}: {name} at {100 * count / total:.0f}% of actions"
                )

    print("\n  Warnings")
    print("  " + "-" * 44)
    warnings = []
    warnings.extend(f"CLASS AVG       {w}" for w in class_warnings)
    if not TARGET_TURNS_LOW <= average_turns <= TARGET_TURNS_HIGH:
        warnings.append(f"FIGHT LENGTH    {average_turns:.1f} turns")
    warnings.extend(f"SLOT MIX        {w}" for w in slot_warnings)
    warnings.extend(f"DOMINANT MOVE   {w}" for w in dominant_warnings)
    warnings.extend(f"EXTREME MATCHUP {w}" for w in extreme_warnings)
    if not warnings:
        print("    none — v2.3 quick targets all inside diagnostic bands")
    else:
        for warning in warnings:
            print(f"    {warning}")

    print("\n  Crest / Entity class compatibility")
    print("  " + "-" * 44)
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
