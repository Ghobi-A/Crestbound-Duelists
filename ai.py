"""
Crestbound Duelists — AI Policies (v2.3)
=========================================
Three analysis policies:
  1. Random    — uniform random from available moves.
  2. Greedy    — highest immediate expected damage, with KO awareness.
  3. Lookahead — finite-horizon marginal state valuation. It prices a
                 Signature/buff/debuff by how much it changes future expected
                 damage dealt and received, rather than assigning arbitrary
                 value to each stat point.

The lookahead policy is deliberately deterministic and inexpensive enough for
large Monte Carlo sweeps. It is a balance-analysis agent, not the Godot enemy
AI implementation.
"""

from __future__ import annotations

import copy
import math
import random

from models import Unit, Move, MoveType, MoveSlot
from combat import BRACE_MULTIPLIER, VARIANCE_LO, VARIANCE_HI


# ── Expected Damage Helper ───────────────────────────────────────────

def expected_damage(move: Move, attacker: Unit, defender: Unit, defender_braced: bool = False) -> float:
    """Expected damage = power × compressed_ratio × avg_variance × accuracy."""
    if move.move_type == MoveType.ADAPTIVE:
        phys_ratio = 2 * attacker.atk / max(1, attacker.atk + defender.def_)
        mag_ratio = 2 * attacker.mag / max(1, attacker.mag + defender.res)
        ratio = max(phys_ratio, mag_ratio)
    elif move.move_type == MoveType.PHYSICAL:
        atk = attacker.atk
        dfn = defender.def_
        if defender_braced:
            dfn = math.floor(dfn * BRACE_MULTIPLIER)
        ratio = 2 * atk / max(1, atk + dfn)
    else:
        atk = attacker.mag
        dfn = defender.res
        if defender_braced:
            dfn = math.floor(dfn * BRACE_MULTIPLIER)
        ratio = 2 * atk / max(1, atk + dfn)

    avg_variance = (VARIANCE_LO + VARIANCE_HI) / 2
    return move.power * ratio * avg_variance * move.accuracy


def can_ko_this_turn(attacker: Unit, defender: Unit, move: Move) -> bool:
    """Can this move KO the defender at max roll?"""
    if move.move_type == MoveType.ADAPTIVE:
        phys_ratio = 2 * attacker.atk / max(1, attacker.atk + defender.def_)
        mag_ratio = 2 * attacker.mag / max(1, attacker.mag + defender.res)
        ratio = max(phys_ratio, mag_ratio)
    elif move.move_type == MoveType.PHYSICAL:
        ratio = 2 * attacker.atk / max(1, attacker.atk + defender.def_)
    else:
        ratio = 2 * attacker.mag / max(1, attacker.mag + defender.res)
    max_dmg = math.floor(move.power * ratio * VARIANCE_HI)
    return max_dmg >= defender.hp


def _basic(unit: Unit) -> Move:
    """Every class contract contains exactly one Basic; return it."""
    return next(move for move in unit.moves if move.slot == MoveSlot.BASIC)


def _exchange_value(attacker: Unit, defender: Unit) -> float:
    """One future round's reliable damage exchange from attacker's view."""
    return (
        expected_damage(_basic(attacker), attacker, defender)
        - expected_damage(_basic(defender), defender, attacker)
    )


def _apply_projected_riders(attacker: Unit, defender: Unit, move: Move) -> tuple[Unit, Unit]:
    """Return cloned units after the move's state riders land.

    Damage itself is not applied here: the caller already accounts for its
    expected immediate value. This projection only asks how buffs, debuffs and
    statuses alter future reliable exchanges.
    """
    projected_attacker = copy.deepcopy(attacker)
    projected_defender = copy.deepcopy(defender)

    # Dedicated buffs cannot resolve while Hexed. Trade-off moves resolve but
    # their positive components are suppressed, matching combat.py.
    if move.is_buff_move and projected_attacker.has_status("hexed"):
        return projected_attacker, projected_defender

    for stat, amount in move.target_stat_mods:
        if amount > 0 and projected_defender.has_status("hexed"):
            continue
        projected_defender.apply_stat_mod(stat, amount, 3)

    for stat, amount in move.self_stat_mods:
        if amount > 0 and projected_attacker.has_status("hexed"):
            continue
        projected_attacker.apply_stat_mod(stat, amount, 3)

    if move.applies_status == "hexed":
        projected_defender.stat_modifiers = [
            mod for mod in projected_defender.stat_modifiers if mod.amount <= 0
        ]
        projected_defender.apply_status("hexed", move.status_duration)

    return projected_attacker, projected_defender


def projected_move_value(attacker: Unit, defender: Unit, move: Move) -> float:
    """Immediate EV plus marginal value of the resulting multi-turn state.

    A three-round stat modifier is worth exactly the change it causes to three
    subsequent reliable damage exchanges. Accuracy naturally discounts both
    immediate Gambit damage and any riders that only apply on hit. This keeps
    the heuristic in combat units (expected HP swing) instead of arbitrary
    'points per stat' coefficients.
    """
    immediate = expected_damage(move, attacker, defender)

    if not (move.target_stat_mods or move.self_stat_mods or move.applies_status):
        return immediate

    before = _exchange_value(attacker, defender)
    projected_attacker, projected_defender = _apply_projected_riders(
        attacker, defender, move
    )
    after = _exchange_value(projected_attacker, projected_defender)

    if move.target_stat_mods or move.self_stat_mods:
        horizon = 3
    elif move.applies_status:
        horizon = max(1, move.status_duration)
    else:
        horizon = 0

    marginal_future = (after - before) * horizon * move.accuracy

    # Hex's future denial is opponent-dependent. If the target owns an
    # available dedicated buff Signature, estimate the reliable exchange gain
    # that buff would otherwise create and credit Hex for denying that option
    # while the curse is active. No generic flat Hex bonus is used.
    if move.applies_status == "hexed":
        for opponent_move in defender.available_moves():
            if not opponent_move.is_buff_move:
                continue
            opp_before = _exchange_value(defender, attacker)
            buffed_defender, buffed_attacker = _apply_projected_riders(
                defender, attacker, opponent_move
            )
            opp_after = _exchange_value(buffed_defender, buffed_attacker)
            denial_per_round = max(0.0, opp_after - opp_before)
            marginal_future += denial_per_round * move.status_duration

    return immediate + marginal_future


# ── Policies ─────────────────────────────────────────────────────────

def policy_random(attacker: Unit, defender: Unit, turn: int) -> Move:
    available = attacker.available_moves()
    return random.choice(available) if available else attacker.moves[0]


def _reliable_ko_choice(attacker: Unit, defender: Unit, available: list[Move]) -> Move | None:
    ko_moves = [move for move in available if can_ko_this_turn(attacker, defender, move)]
    if not ko_moves:
        return None
    # Prefer certainty at a KO breakpoint, then expected damage.
    return max(
        ko_moves,
        key=lambda move: (move.accuracy, expected_damage(move, attacker, defender)),
    )


def policy_greedy(attacker: Unit, defender: Unit, turn: int) -> Move:
    available = attacker.available_moves()
    if not available:
        return attacker.moves[0]

    ko = _reliable_ko_choice(attacker, defender, available)
    if ko is not None:
        return ko

    return max(available, key=lambda move: expected_damage(move, attacker, defender))


def policy_lookahead(attacker: Unit, defender: Unit, turn: int) -> Move:
    """Choose the action with the best finite-horizon expected HP swing."""
    available = attacker.available_moves()
    if not available:
        return attacker.moves[0]

    ko = _reliable_ko_choice(attacker, defender, available)
    if ko is not None:
        return ko

    return max(
        available,
        key=lambda move: projected_move_value(attacker, defender, move),
    )


POLICIES = {
    "random": policy_random,
    "greedy": policy_greedy,
    "lookahead": policy_lookahead,
}
