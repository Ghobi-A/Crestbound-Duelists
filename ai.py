"""
Crestbound Duelists — AI Policies (v2.1)
==========================================
Three AI tiers:
  1. Random  — uniform random from available moves
  2. Greedy  — picks highest expected damage this turn
  3. Lookahead — 1-step minimax (my value − 0.5 × opp best response)
"""

from __future__ import annotations
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


def policy_random(attacker: Unit, defender: Unit, turn: int) -> Move:
    available = attacker.available_moves()
    return random.choice(available) if available else attacker.moves[0]


def policy_greedy(attacker: Unit, defender: Unit, turn: int) -> Move:
    available = attacker.available_moves()
    if not available:
        return attacker.moves[0]

    ko_moves = [(m, expected_damage(m, attacker, defender)) for m in available
                if can_ko_this_turn(attacker, defender, m)]
    if ko_moves:
        ko_moves.sort(key=lambda x: (-x[0].accuracy, -x[1]))
        return ko_moves[0][0]

    return max(available, key=lambda m: expected_damage(m, attacker, defender))


def _simulate_move_value(attacker: Unit, defender: Unit, move: Move) -> float:
    base_ev = expected_damage(move, attacker, defender)

    debuff_value = 0.0
    for stat, amount in move.target_stat_mods:
        debuff_value += abs(amount) * 2.0 if amount < 0 else 0

    self_cost = 0.0
    for stat, amount in move.self_stat_mods:
        if amount < 0:
            self_cost += abs(amount) * 1.5

    buff_value = 0.0
    for stat, amount in move.self_stat_mods:
        if amount > 0:
            buff_value += amount * 1.5

    hex_value = 0.0
    if move.applies_status == "hexed":
        hex_value = 5.0

    return base_ev + debuff_value + buff_value - self_cost + hex_value


def policy_lookahead(attacker: Unit, defender: Unit, turn: int) -> Move:
    available = attacker.available_moves()
    if not available:
        return attacker.moves[0]

    ko_moves = [(m, expected_damage(m, attacker, defender)) for m in available
                if can_ko_this_turn(attacker, defender, m)]
    if ko_moves:
        ko_moves.sort(key=lambda x: (-x[0].accuracy, -x[1]))
        return ko_moves[0][0]

    best_move = available[0]
    best_score = -float("inf")

    for move in available:
        my_value = _simulate_move_value(attacker, defender, move)

        opp_available = defender.available_moves()
        if opp_available:
            opp_best = max(opp_available, key=lambda m: expected_damage(m, defender, attacker))
            opp_threat = expected_damage(opp_best, defender, attacker)
        else:
            opp_threat = 0

        net = my_value - 0.5 * opp_threat

        if net > best_score:
            best_score = net
            best_move = move

    return best_move


POLICIES = {
    "random": policy_random,
    "greedy": policy_greedy,
    "lookahead": policy_lookahead,
}
