"""
Crestbound Duelists — Combat Engine (v2.1)
============================================
Compressed damage formula, probabilistic speed, Brace passive,
move execution with cooldowns/decay, and the 1v1 battle loop.
"""

from __future__ import annotations
import math
import random
from dataclasses import dataclass, field
from typing import Optional

from models import (
    Unit, Move, MoveType, MoveSlot, StatModifier, StatusEffect,
    STAT_DECAY, ClassName
)


# ── Configuration ────────────────────────────────────────────────────

SPEED_BAND: int = 7
GUARANTEED_RATIO: float = 2.0
VARIANCE_LO: float = 0.85
VARIANCE_HI: float = 1.0
BRACE_MULTIPLIER: float = 1.05
MAX_TURNS: int = 100


# ── Logging ──────────────────────────────────────────────────────────

@dataclass
class ActionLog:
    """Single action record for analysis."""
    turn: int
    actor: str
    actor_class: str
    target: str
    target_class: str
    move_name: str
    move_slot: str
    move_type: str
    raw_damage: int
    variance_roll: float
    hit: bool
    final_damage: int
    target_hp_before: int
    target_hp_after: int
    actor_braced: bool
    target_braced: bool
    stat_mods_applied: list[str] = field(default_factory=list)
    status_applied: Optional[str] = None
    blocked_by_hex: bool = False


@dataclass
class BattleResult:
    """Full result of a 1v1 battle."""
    winner: str
    winner_class: str
    loser: str
    loser_class: str
    turns: int
    logs: list[ActionLog] = field(default_factory=list)


# ── Speed Resolution ─────────────────────────────────────────────────

def resolve_speed(unit_a: Unit, unit_b: Unit) -> tuple[Unit, Unit]:
    """Probabilistic speed system. Returns (first_actor, second_actor)."""
    spd_a, spd_b = unit_a.spd, unit_b.spd

    if spd_a == spd_b:
        return (unit_a, unit_b) if random.random() < 0.5 else (unit_b, unit_a)

    faster, slower = (unit_a, unit_b) if spd_a > spd_b else (unit_b, unit_a)
    diff = abs(spd_a - spd_b)

    if faster.spd >= GUARANTEED_RATIO * slower.spd or diff >= SPEED_BAND:
        return faster, slower

    p_faster_first = 0.5 + 0.5 * (diff / SPEED_BAND)
    return (faster, slower) if random.random() < p_faster_first else (slower, faster)


# ── Damage Calculation ───────────────────────────────────────────────

def _resolve_adaptive_type(move: Move, attacker: Unit, defender: Unit) -> str:
    """For ADAPTIVE moves, pick whichever type deals more damage."""
    phys_ratio = 2 * attacker.atk / max(1, attacker.atk + defender.def_)
    mag_ratio = 2 * attacker.mag / max(1, attacker.mag + defender.res)
    return "physical" if phys_ratio >= mag_ratio else "magical"


def calculate_damage(
    move: Move,
    attacker: Unit,
    defender: Unit,
    defender_braced: bool = False,
) -> tuple[int, float, str]:
    """Compressed damage formula: Power × 2·ATK/(ATK+DEF) × v"""
    if move.move_type == MoveType.ADAPTIVE:
        resolved = _resolve_adaptive_type(move, attacker, defender)
    elif move.move_type == MoveType.PHYSICAL:
        resolved = "physical"
    else:
        resolved = "magical"

    if resolved == "physical":
        atk_stat = attacker.atk
        def_stat = defender.def_
    else:
        atk_stat = attacker.mag
        def_stat = defender.res

    if defender_braced:
        def_stat = math.floor(def_stat * BRACE_MULTIPLIER)

    v = random.uniform(VARIANCE_LO, VARIANCE_HI)
    ratio = 2 * atk_stat / max(1, atk_stat + def_stat)
    raw = math.floor(move.power * ratio * v)
    damage = max(1, raw)

    return damage, v, resolved


# ── Move Execution ───────────────────────────────────────────────────

def execute_move(
    attacker: Unit,
    defender: Unit,
    move: Move,
    turn: int,
    attacker_braced: bool,
    defender_braced: bool,
) -> ActionLog:
    """Execute a move: accuracy check, damage, effects. Returns log."""
    log = ActionLog(
        turn=turn, actor=attacker.name, actor_class=attacker.class_name.value,
        target=defender.name, target_class=defender.class_name.value,
        move_name=move.name, move_slot=move.slot.name, move_type="",
        raw_damage=0, variance_roll=0.0, hit=False, final_damage=0,
        target_hp_before=defender.hp, target_hp_after=defender.hp,
        actor_braced=attacker_braced, target_braced=defender_braced,
    )

    hit = random.random() < move.accuracy
    log.hit = hit

    if not hit:
        log.target_hp_after = defender.hp
        if move.cooldown_turns > 0:
            attacker.cooldowns[move.name] = move.cooldown_turns
        return log

    if move.is_buff_move and attacker.has_status("hexed"):
        log.blocked_by_hex = True
        log.target_hp_after = defender.hp
        if move.cooldown_turns > 0:
            attacker.cooldowns[move.name] = move.cooldown_turns
        return log

    damage, v, resolved = calculate_damage(move, attacker, defender, defender_braced)
    log.move_type = resolved
    log.raw_damage = damage
    log.variance_roll = v
    log.final_damage = damage

    defender.hp = max(0, defender.hp - damage)
    log.target_hp_after = defender.hp

    for stat, amount in move.target_stat_mods:
        defender.apply_stat_mod(stat, amount, STAT_DECAY)
        log.stat_mods_applied.append(f"{defender.name}.{stat}{amount:+d}")

    if not (move.self_stat_mods and attacker.has_status("hexed")):
        for stat, amount in move.self_stat_mods:
            attacker.apply_stat_mod(stat, amount, STAT_DECAY)
            log.stat_mods_applied.append(f"{attacker.name}.{stat}{amount:+d}")

    if move.applies_status:
        defender.apply_status(move.applies_status, move.status_duration)
        log.status_applied = move.applies_status

    if move.cooldown_turns > 0:
        attacker.cooldowns[move.name] = move.cooldown_turns

    return log


# ── 1v1 Battle Loop ─────────────────────────────────────────────────

def battle_1v1(
    unit_a: Unit,
    unit_b: Unit,
    ai_policy_a: callable,
    ai_policy_b: callable,
    log_actions: bool = False,
) -> BattleResult:
    """Run a full 1v1 battle between two units."""
    unit_a.reset()
    unit_b.reset()
    logs: list[ActionLog] = []

    for turn in range(1, MAX_TURNS + 1):
        if not unit_a.is_alive or not unit_b.is_alive:
            break

        first, second = resolve_speed(unit_a, unit_b)
        first_opp = second
        second_opp = first

        first_braced = False
        second_braced = True

        policy_first = ai_policy_a if first is unit_a else ai_policy_b
        policy_second = ai_policy_b if second is unit_b else ai_policy_a

        move = policy_first(first, first_opp, turn)
        action_log = execute_move(first, first_opp, move, turn, first_braced, second_braced)
        if log_actions:
            logs.append(action_log)

        if not first_opp.is_alive:
            break

        move = policy_second(second, second_opp, turn)
        action_log = execute_move(second, second_opp, move, turn, second_braced, first_braced)
        if log_actions:
            logs.append(action_log)

        if not second_opp.is_alive:
            break

        for u in (unit_a, unit_b):
            u.tick_cooldowns()
            u.tick_modifiers()

    if unit_a.is_alive and not unit_b.is_alive:
        winner, loser = unit_a, unit_b
    elif unit_b.is_alive and not unit_a.is_alive:
        winner, loser = unit_b, unit_a
    else:
        if unit_a.hp >= unit_b.hp:
            winner, loser = unit_a, unit_b
        else:
            winner, loser = unit_b, unit_a

    return BattleResult(
        winner=winner.name, winner_class=winner.class_name.value,
        loser=loser.name, loser_class=loser.class_name.value,
        turns=turn, logs=logs,
    )
