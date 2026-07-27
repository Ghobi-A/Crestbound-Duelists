"""
Crestbound Duelists — Recruiter Snapshot Generator
===================================================
Precomputes the expensive analytics the Balance Lab shows on load, so the
Streamlit app never has to run a full 100k-per-matchup sweep in a web request.

Writes results/recruiter_snapshot.json:
  - 6x6 win-rate matrix + average fight duration per matchup
  - Ranked average win rate per class
  - Policy comparison (greedy / lookahead / random, mirror matches)
  - Nash maximin analysis for all 15 unique matchups

Usage:
    python tools/generate_snapshot.py                 # 100k per matchup
    python tools/generate_snapshot.py --sims 5000     # quick local run
"""

from __future__ import annotations

import argparse
import json
import random
import subprocess
import sys
import time
from datetime import datetime, timezone
from itertools import combinations
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT))

from models import ClassName  # noqa: E402
from simulation import ALL_CLASSES, run_matchup, compute_averages  # noqa: E402
import nash  # noqa: E402

DEFAULT_MATRIX_SIMS = 100_000
DEFAULT_POLICY_SIMS = 20_000
POLICY_PAIRS = [
    ("greedy", "random"),
    ("lookahead", "random"),
    ("lookahead", "greedy"),
]
OUTPUT_PATH = REPO_ROOT / "results" / "recruiter_snapshot.json"


def _git_commit() -> str | None:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=REPO_ROOT,
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None


def build_matrix(n_sims: int, policy: str, verbose: bool) -> tuple[dict, dict, dict]:
    """Run all 15 unique matchups. Returns (matrix, avg_turns, raw_matrix)."""
    matrix: dict[tuple[ClassName, ClassName], float] = {}
    avg_turns: dict[str, float] = {}
    pairs = list(combinations(ALL_CLASSES, 2))
    start = time.time()

    for cls in ALL_CLASSES:
        matrix[(cls, cls)] = 50.0

    for done, (class_a, class_b) in enumerate(pairs, start=1):
        result = run_matchup(class_a, class_b, n_sims, policy)
        matrix[(class_a, class_b)] = result["win_rate_a"]
        matrix[(class_b, class_a)] = result["win_rate_b"]
        avg_turns[f"{class_a.value}|{class_b.value}"] = result["avg_turns"]

        if verbose:
            elapsed = time.time() - start
            eta = (elapsed / done) * (len(pairs) - done)
            print(
                f"  [{done}/{len(pairs)}] {class_a.value} vs {class_b.value}: "
                f"{result['win_rate_a']}% / {result['win_rate_b']}% "
                f"(avg {result['avg_turns']} turns) [ETA {eta:.0f}s]"
            )

    nested = {
        a.value: {b.value: matrix[(a, b)] for b in ALL_CLASSES}
        for a in ALL_CLASSES
    }
    return nested, avg_turns, matrix


def build_policy_comparison(n_sims: int, verbose: bool) -> dict:
    """Mirror matches per class for each policy pairing."""
    from combat import battle_1v1
    from models import create_unit
    from ai import POLICIES

    out: dict[str, dict[str, dict[str, float]]] = {}

    for name_a, name_b in POLICY_PAIRS:
        policy_a, policy_b = POLICIES[name_a], POLICIES[name_b]
        key = f"{name_a}_vs_{name_b}"
        out[key] = {}

        for cls in ALL_CLASSES:
            wins_a = 0
            for _ in range(n_sims):
                unit_a = create_unit(cls, f"{cls.value}_A")
                unit_b = create_unit(cls, f"{cls.value}_B")
                result = battle_1v1(unit_a, unit_b, policy_a, policy_b)
                if result.winner == unit_a.name:
                    wins_a += 1
            wr = round(100 * wins_a / n_sims, 1)
            out[key][cls.value] = {"win_rate_a": wr, "win_rate_b": round(100 - wr, 1)}

        if verbose:
            print(f"  {key}: done ({n_sims} sims x {len(ALL_CLASSES)} classes)")

    return out


def build_nash() -> list[dict]:
    """Nash maximin analysis for all unique matchups, JSON-serialisable."""
    results = []
    for class_a, class_b in combinations(ALL_CLASSES, 2):
        r = nash.analyse_matchup(class_a, class_b)
        results.append(
            {
                "class_a": r["class_a"],
                "class_b": r["class_b"],
                "moves_a": r["moves_a"],
                "moves_b": r["moves_b"],
                "payoff": r["payoff"].tolist(),
                "strategy_a": [round(float(x), 4) for x in r["strategy_a"]],
                "strategy_b": [round(float(x), 4) for x in r["strategy_b"]],
                "entropy_a": round(float(r["entropy_a"]), 4),
                "entropy_b": round(float(r["entropy_b"]), 4),
                "value_a": round(float(r["value_a"]), 4),
                "is_pure_a": bool(r["is_pure_a"]),
                "greedy_move": r["greedy_move"],
                "nash_dominant": r["nash_dominant"],
                "greedy_matches_nash": bool(r["greedy_matches_nash"]),
            }
        )
    return results


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sims", type=int, default=DEFAULT_MATRIX_SIMS,
                        help="simulations per matchup for the win matrix")
    parser.add_argument("--policy-sims", type=int, default=DEFAULT_POLICY_SIMS,
                        help="simulations per class for each policy pairing")
    parser.add_argument("--policy", default="greedy", help="policy used for the matrix")
    parser.add_argument("--output", type=Path, default=OUTPUT_PATH)
    parser.add_argument(
        "--seed",
        type=int,
        default=42,
        help="Random seed for reproducible Monte Carlo results",
    )
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    verbose = not args.quiet
    start = time.time()

    # The combat engine draws initiative and damage variance from the global
    # `random` module, so seeding here makes the whole snapshot reproducible.
    random.seed(args.seed)

    if verbose:
        print(f"\nWin matrix — {args.sims:,} sims per matchup ({args.policy}):")
    nested, avg_turns, matrix = build_matrix(args.sims, args.policy, verbose)

    averages = {c.value: v for c, v in compute_averages(matrix).items()}

    if verbose:
        print(f"\nPolicy comparison — {args.policy_sims:,} sims per class:")
    policy_comparison = build_policy_comparison(args.policy_sims, verbose)

    if verbose:
        print("\nNash maximin analysis...")
    nash_results = build_nash()

    snapshot = {
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "git_commit": _git_commit(),
        "seed": args.seed,
        "sims_per_matchup": args.sims,
        "policy_sims_per_class": args.policy_sims,
        "matrix_policy": args.policy,
        "classes": [c.value for c in ALL_CLASSES],
        "win_matrix": nested,
        "avg_turns": avg_turns,
        "class_averages": averages,
        "policy_comparison": policy_comparison,
        "nash": nash_results,
        "runtime_seconds": round(time.time() - start, 1),
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(snapshot, indent=2) + "\n", encoding="utf-8")

    if verbose:
        print(f"\nWrote {args.output} in {snapshot['runtime_seconds']}s")


if __name__ == "__main__":
    main()
