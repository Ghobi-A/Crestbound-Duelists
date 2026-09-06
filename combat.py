"""
Crestbound Duelists — Combat Engine (v2.2)
============================================
Compressed damage formula, probabilistic speed, Brace passive,
move execution with real cooldown windows, stronger Hex interaction,
and the 1v1 battle loop.
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
# Values come from data/combat_config.yaml; edit there, not here.

from loaders import load_combat_config as _load_combat_config

_config = _load_combat_config()

SPEED_BAND: int = int(_config["speed_band"])
# Retained as a public constant for v2.1/API compatibility. Initiative in
# v2.2 is resolved with the same SPD + U(0, band) score used by Godot.
GUARANTEED_RATIO: float = float(_config["guaranteed_speed_ratio"])
VARIANCE_LO: float = float(_config["variance_low"])
VARIANCE_HI: float = float(_config["variance_high"])
BRACE_MULTIPLIER: float = float(_config["brace_multiplier"])
MAX_TURNS: int = int(_config["max_turns"])


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
    """Resolve initiative with SPD + U(0, SPEED_BAND).

    This is the same score model used by the Godot party resolver. A raw
    speed gap at or beyond SPEED_BAND guarantees order; otherwise both
    combatants retain a non-zero chance to act first.
    """
    spd_a, spd_b = unit_a.spd, unit_b.spd

    if spd_a == spd_b:
        return (unit_a, unit_b) if random.random() < 0.5 else (unit_b, unit_a)

    faster, slower = (unit_a, unit_b) if spd_a > spd_b else (unit_b, unit_a)
    if abs(spd_a - spd_b) >= SPEED_BAND:
        return faster, slower

    score_a = spd_a + random.uniform(0.0, SPEED_BAND)
    score_b = spd_b + random.uniform(0.0, SPEED_BAND)
    if score_a == score_b:
        return (unit_a, unit_b) if random.random() < 0.5 else (unit_b, unit_a)
    return (unit_a, unit_b) if score_a > score_b else (unit_b, unit_a)


# ── Damage Calculation ───────────────────────────────────────────────

def _resolve_adaptive_type(move: Move, attacker: Unit, defender: Unit) -> str:
    """For ADAPTIVE moves, pick whichever type deals more damage."""
    phys_ratio = 2 * attacker.atk / max(1, attacker.atk + defender.def_)
    mag_ratio = 2 * attacker.mag / max(1, attacker.mag + defender.res)
    return "physical" if phys_ratio >= mag_ratio else "magical"


def _signature_breaks_brace(move: Move, resolved_type: str) -> bool:
    """High-impact defence-break signatures punch through Brace.

    The rule is derived from the move's own rider rather than a class/name
    check: a Signature that applies at least -10 to the defence channel it
    attacks ignores Brace for that hit. In the v2.2 kit this covers Armor
    Break and Mind Pierce while leaving Cripple as an initiative/setup tool.
    """
    if move.slot != MoveSlot.SIGNATURE:
        return False
    relevant_stat = "def" if resolved_type == "physical" else "res"
    return any(stat == relevant_stat and amount <= -10
               for stat, amount in move.target_stat_mods)


def calculate_damage(
    move: Move,
    attacker: Unit,
    defender: Unit,
    defender_braced: bool = False,
) -> tuple[int, float, str]:
    """Compressed damage formula: Power × 2·ATK/(ATK+DEF) × v."""
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

    if defender_braced and not _signature_breaks_brace(move, resolved):
        def_stat = math.floor(def_stat * BRACE_MULTIPLIER)

    v = random.uniform(VARIANCE_LO, VARIANCE_HI)
    ratio = 2 * atk_stat / max(1, atk_stat + def_stat)
    raw = math.floor(move.power * ratio * v)
    damage = max(1, raw)

    return damage, v, resolved


# ── Move Execution ───────────────────────────────────────────────────

def _start_cooldown(attacker: Unit, move: Move) -> None:
    """Start a cooldown without consuming its first round immediately.

    Cooldowns tick at round end. Storing configured cooldown + 1 means a
    one-round Signature/Gambit cooldown is still at 1 on the next decision,
    then reaches 0 after that round. This matches the Godot runtime.
    """
    if move.cooldown_turns > 0:
        attacker.cooldowns[move.name] = move.cooldown_turns + 1


def _purge_positive_modifiers(unit: Unit) -> None:
    """Hex suppresses already-active positive stat modifications."""
    unit.stat_modifiers = [m for m in unit.stat_modifiers if m.amount <= 0]


def _apply_mod_with_hex_rule(unit: Unit, stat: str, amount: int) -> bool:
    """Apply a stat mod unless Hex suppresses a positive change."""
    if amount > 0 and unit.has_status("hexed"):
        return False
    unit.apply_stat_mod(stat, amount, STAT_DECAY)
    return True


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
        _start_cooldown(attacker, move)
        return log

    # Dedicated buff actions are denied outright by Hex. Hybrid/trade-off
    # actions still resolve, but their positive riders are suppressed below.
    if move.is_buff_move and attacker.has_status("hexed"):
        log.blocked_by_hex = True
        log.target_hp_after = defender.hp
        _start_cooldown(attacker, move)
        return log

    damage, v, resolved = calculate_damage(move, attacker, defender, defender_braced)
    log.move_type = resolved
    log.raw_damage = damage
    log.variance_roll = v
    log.final_damage = damage

    defender.hp = max(0, defender.hp - damage)
    log.target_hp_after = defender.hp

    for stat, amount in move.target_stat_mods:
        if _apply_mod_with_hex_rule(defender, stat, amount):
            log.stat_mods_applied.append(f"{defender.name}.{stat}{amount:+d}")
        else:
            log.blocked_by_hex = True

    for stat, amount in move.self_stat_mods:
        if _apply_mod_with_hex_rule(attacker, stat, amount):
            log.stat_mods_applied.append(f"{attacker.name}.{stat}{amount:+d}")
        else:
            log.blocked_by_hex = True

    if move.applies_status:
        if move.applies_status == "hexed":
            _purge_positive_modifiers(defender)
        defender.apply_status(move.applies_status, move.status_duration)
        log.status_applied = move.applies_status

    _start_cooldown(attacker, move)

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
