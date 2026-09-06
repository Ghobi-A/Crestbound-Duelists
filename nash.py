"""
Crestbound Duelists — Stateful Nash / Maximin Analysis (v2.2)
==============================================================
Builds a zero-sum normal-form approximation from multi-round combat state:
  - each matrix cell forces a joint opening action (move_i, move_j)
  - seeded Monte Carlo rollouts continue for three rounds
  - HP, cooldowns, buffs/debuffs, Hex, initiative and Brace all persist
  - maximin mixed strategies are solved by linear programming

The v2.1 matrix used A[i,j] = E[dmg_A(i)] - E[dmg_B(j)], which is
separable as f(i)-g(j). Pure strategies were therefore largely a property
of the payoff construction rather than evidence about strategic mixing.
v2.2 estimates Q(s, a_i, a_j) from the actual state transition system.
"""

from __future__ import annotations

import copy
import random
import numpy as np
from scipy.optimize import linprog

from models import ClassName, create_unit, Unit, Move, MoveType
from combat import (
    VARIANCE_LO,
    VARIANCE_HI,
    execute_move,
    resolve_speed,
)
from ai import policy_greedy, policy_lookahead


ALL_CLASSES = list(ClassName)
DEFAULT_ROLLOUTS = 128
DEFAULT_HORIZON = 3
DEFAULT_SEED = 42


# ── Expected Damage (for the Greedy comparison only) ────────────────

def _expected_damage(move: Move, attacker: Unit, defender: Unit) -> float:
    """Immediate expected damage, retained only as the Greedy baseline."""
    if move.move_type == MoveType.ADAPTIVE:
        phys = 2 * attacker.atk / max(1, attacker.atk + defender.def_)
        mag = 2 * attacker.mag / max(1, attacker.mag + defender.res)
        ratio = max(phys, mag)
    elif move.move_type == MoveType.PHYSICAL:
        ratio = 2 * attacker.atk / max(1, attacker.atk + defender.def_)
    else:
        ratio = 2 * attacker.mag / max(1, attacker.mag + defender.res)

    avg_v = (VARIANCE_LO + VARIANCE_HI) / 2
    return move.power * ratio * avg_v * move.accuracy


# ── Stateful rollout model ───────────────────────────────────────────

def _state_utility(unit_a: Unit, unit_b: Unit) -> float:
    """Zero-sum value from A's perspective, with terminal outcomes dominant."""
    hp_term = (unit_a.hp / unit_a.base_hp) - (unit_b.hp / unit_b.base_hp)
    if unit_a.is_alive and not unit_b.is_alive:
        return 1.0 + hp_term
    if unit_b.is_alive and not unit_a.is_alive:
        return -1.0 + hp_term
    return hp_term


def _resolve_joint_round(
    unit_a: Unit,
    unit_b: Unit,
    move_a: Move,
    move_b: Move,
    turn: int,
) -> None:
    """Resolve one committed 1v1 round without resetting state."""
    first, second = resolve_speed(unit_a, unit_b)

    if first is unit_a:
        execute_move(unit_a, unit_b, move_a, turn, False, True)
        if unit_b.is_alive:
            execute_move(unit_b, unit_a, move_b, turn, True, False)
    else:
        execute_move(unit_b, unit_a, move_b, turn, False, True)
        if unit_a.is_alive:
            execute_move(unit_a, unit_b, move_a, turn, True, False)

    if unit_a.is_alive and unit_b.is_alive:
        for unit in (unit_a, unit_b):
            unit.tick_cooldowns()
            unit.tick_modifiers()


def _rollout_value(
    initial_a: Unit,
    initial_b: Unit,
    move_index_a: int,
    move_index_b: int,
    horizon: int,
) -> float:
    """Force one joint action pair, then continue with lookahead policies."""
    unit_a = copy.deepcopy(initial_a)
    unit_b = copy.deepcopy(initial_b)

    available_a = unit_a.available_moves()
    available_b = unit_b.available_moves()
    move_a = available_a[move_index_a]
    move_b = available_b[move_index_b]
    _resolve_joint_round(unit_a, unit_b, move_a, move_b, 1)

    for turn in range(2, horizon + 1):
        if not unit_a.is_alive or not unit_b.is_alive:
            break
        next_a = policy_lookahead(unit_a, unit_b, turn)
        next_b = policy_lookahead(unit_b, unit_a, turn)
        _resolve_joint_round(unit_a, unit_b, next_a, next_b, turn)

    return _state_utility(unit_a, unit_b)


def build_state_payoff_matrix(
    unit_a: Unit,
    unit_b: Unit,
    *,
    rollouts: int = DEFAULT_ROLLOUTS,
    horizon: int = DEFAULT_HORIZON,
    seed: int = DEFAULT_SEED,
) -> tuple[np.ndarray, list[str], list[str]]:
    """Estimate Q(s, a_i, a_j) for the units' current combat state.

    Available moves define the rows/columns. Each cell uses common seeded
    random numbers across action pairs to reduce Monte Carlo comparison noise.
    The caller's global random state is restored before returning.
    """
    if rollouts < 1:
        raise ValueError("rollouts must be >= 1")
    if horizon < 1:
        raise ValueError("horizon must be >= 1")

    moves_a = unit_a.available_moves()
    moves_b = unit_b.available_moves()
    if not moves_a or not moves_b:
        raise ValueError("both units must have at least one available move")

    payoff = np.zeros((len(moves_a), len(moves_b)), dtype=float)
    saved_random_state = random.getstate()
    try:
        for sample in range(rollouts):
            # Common random numbers make pairwise matrix differences less noisy.
            sample_seed = seed + sample * 104729
            for i in range(len(moves_a)):
                for j in range(len(moves_b)):
                    random.seed(sample_seed)
                    payoff[i, j] += _rollout_value(
                        unit_a, unit_b, i, j, horizon
                    )
    finally:
        random.setstate(saved_random_state)

    payoff /= rollouts
    return payoff, [m.name for m in moves_a], [m.name for m in moves_b]


def build_payoff_matrix(
    class_a: ClassName,
    class_b: ClassName,
    *,
    rollouts: int = DEFAULT_ROLLOUTS,
    horizon: int = DEFAULT_HORIZON,
    seed: int = DEFAULT_SEED,
) -> tuple[np.ndarray, list[str], list[str]]:
    """Build the initial-state stateful payoff matrix for a class matchup."""
    return build_state_payoff_matrix(
        create_unit(class_a),
        create_unit(class_b),
        rollouts=rollouts,
        horizon=horizon,
        seed=seed,
    )


# ── Nash Equilibrium Solver (Maximin via LP) ─────────────────────────

def solve_maximin(payoff: np.ndarray) -> tuple[np.ndarray, float]:
    """Solve Player A's zero-sum maximin mixed strategy by linear programming."""
    m, n = payoff.shape

    c = np.zeros(m + 1)
    c[-1] = -1

    A_ub = np.zeros((n, m + 1))
    for j in range(n):
        A_ub[j, :m] = -payoff[:, j]
        A_ub[j, -1] = 1
    b_ub = np.zeros(n)

    A_eq = np.zeros((1, m + 1))
    A_eq[0, :m] = 1
    b_eq = np.array([1.0])

    bounds = [(0, None)] * m + [(None, None)]

    result = linprog(
        c,
        A_ub=A_ub,
        b_ub=b_ub,
        A_eq=A_eq,
        b_eq=b_eq,
        bounds=bounds,
        method="highs",
    )

    if result.success:
        strategy = np.maximum(result.x[:m], 0)
        strategy /= strategy.sum()
        return strategy, result.x[-1]

    return np.ones(m) / m, 0.0


# ── Entropy / diagnostics ────────────────────────────────────────────

def policy_entropy(strategy: np.ndarray) -> float:
    """Shannon entropy. 0 = pure; log2(n) = uniform over n actions."""
    s = strategy[strategy > 1e-10]
    return -np.sum(s * np.log2(s))


def greedy_choice(payoff: np.ndarray) -> int:
    """Compatibility helper: best row against a uniform column mixture."""
    return int(np.argmax(payoff.mean(axis=1)))


def separability_residual(payoff: np.ndarray) -> float:
    """Maximum |Aij-Ai0-A0j+A00|; zero iff a matrix is f(i)-g(j)."""
    residual = payoff - payoff[:, [0]] - payoff[[0], :] + payoff[0, 0]
    return float(np.max(np.abs(residual)))


# ── Full Analysis ────────────────────────────────────────────────────

def analyse_matchup(
    class_a: ClassName,
    class_b: ClassName,
    *,
    rollouts: int = DEFAULT_ROLLOUTS,
    horizon: int = DEFAULT_HORIZON,
    seed: int = DEFAULT_SEED,
) -> dict:
    """Stateful Nash analysis for a single initial class matchup."""
    payoff, names_a, names_b = build_payoff_matrix(
        class_a, class_b, rollouts=rollouts, horizon=horizon, seed=seed
    )
    strategy_a, value_a = solve_maximin(payoff)
    strategy_b, value_b = solve_maximin(-payoff.T)

    entropy_a = policy_entropy(strategy_a)
    entropy_b = policy_entropy(strategy_b)

    baseline_a = create_unit(class_a)
    baseline_b = create_unit(class_b)
    greedy_move = policy_greedy(baseline_a, baseline_b, 1)
    greedy_idx = names_a.index(greedy_move.name)
    nash_dominant = int(np.argmax(strategy_a))

    return {
        "class_a": class_a.value,
        "class_b": class_b.value,
        "analysis_model": "stateful_rollout",
        "rollouts": rollouts,
        "horizon": horizon,
        "payoff": payoff,
        "moves_a": names_a,
        "moves_b": names_b,
        "strategy_a": strategy_a,
        "strategy_b": strategy_b,
        "entropy_a": entropy_a,
        "entropy_b": entropy_b,
        "value_a": value_a,
        "value_b": value_b,
        "is_pure_a": entropy_a < 0.01,
        "greedy_idx": greedy_idx,
        "greedy_move": names_a[greedy_idx],
        "nash_dominant": names_a[nash_dominant],
        "greedy_matches_nash": greedy_idx == nash_dominant,
        "separability_residual": separability_residual(payoff),
    }


def run_full_analysis(verbose: bool = True) -> list[dict]:
    """Run stateful Nash analysis for all 15 unique matchups."""
    results = []

    if verbose:
        print(f"\n{'='*78}")
        print("  NASH / MAXIMIN ANALYSIS — 3-ROUND STATEFUL ROLLOUT GAME")
        print(f"{'='*78}\n")

    for i, class_a in enumerate(ALL_CLASSES):
        for j, class_b in enumerate(ALL_CLASSES):
            if i >= j:
                continue

            r = analyse_matchup(class_a, class_b)
            results.append(r)

            if verbose:
                eq_type = "PURE" if r["is_pure_a"] else "MIXED"
                match = "✓" if r["greedy_matches_nash"] else "✗"
                print(
                    f"  {r['class_a']:>10} vs {r['class_b']:<10}  "
                    f"Equilibrium: {eq_type:<5}  "
                    f"Entropy: {r['entropy_a']:.3f}  "
                    f"Greedy={r['greedy_move']:<16} "
                    f"Nash={r['nash_dominant']:<16} "
                    f"Match: {match}  "
                    f"Nonsep={r['separability_residual']:.3f}"
                )

    if verbose and results:
        n_pure = sum(1 for r in results if r["is_pure_a"])
        n_mixed = len(results) - n_pure
        n_greedy_match = sum(1 for r in results if r["greedy_matches_nash"])
        avg_entropy = np.mean([r["entropy_a"] for r in results])
        avg_nonsep = np.mean([r["separability_residual"] for r in results])

        print(f"\n{'='*78}")
        print("  SUMMARY")
        print(f"{'='*78}")
        print(f"  Total matchups:        {len(results)}")
        print(f"  Pure equilibria:       {n_pure}")
        print(f"  Mixed equilibria:      {n_mixed}")
        print(f"  Greedy = Nash:         {n_greedy_match}/{len(results)}")
        print(f"  Avg policy entropy:    {avg_entropy:.3f}")
        print(f"  Avg non-separability:  {avg_nonsep:.3f}")
        print("\n  Interpretation: strategy mixing is now an empirical result of")
        print("  stateful interaction, not a consequence of a separable payoff matrix.")

    return results


if __name__ == "__main__":
    run_full_analysis()
