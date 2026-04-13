"""
Crestbound Duelists — Data Models (v2.0)
==========================================
Class definitions, move data, stat/status systems, and the Unit class.

Six combat classes:
  Warrior  (WAR) — physical powerhouse, high ATK/DEF, low RES
  Mage     (MAG) — magical specialist, high MAG/RES, fragile DEF
  Assassin (ASS) — speed + burst, extreme SPD/ATK, glass DEF
  Guardian (GUA) — tank with buffs, massive DEF/RES/HP, slow
  Neutral  (NEU) — adaptive, balanced stats, no dominant angle
  Sorcerer (SOR) — magical control/debuff, applies Hex status

Damage formula: Power × 2·ATK/(ATK+DEF) × variance
Brace passive:  second actor gains ×1.05 DEF/RES when defending
STAT_DECAY:     modifier duration (turns) before reverting
"""

from __future__ import annotations
import math
import random
from dataclasses import dataclass, field
from enum import Enum
from typing import Optional


# ── Constants ──────────────────────────────────────────────────────────────────

STAT_DECAY: int = 3   # Default duration (turns) for stat modifiers


# ── Enums ──────────────────────────────────────────────────────────────────────

class ClassName(str, Enum):
    WARRIOR  = "Warrior"
    MAGE     = "Mage"
    ASSASSIN = "Assassin"
    GUARDIAN = "Guardian"
    NEUTRAL  = "Neutral"
    SORCERER = "Sorcerer"


class MoveType(str, Enum):
    PHYSICAL = "physical"
    MAGICAL  = "magical"
    ADAPTIVE = "adaptive"   # picks whichever type deals more damage each use


class MoveSlot(str, Enum):
    BASIC     = "basic"
    SIGNATURE = "signature"
    GAMBIT    = "gambit"


class StatusEffect(str, Enum):
    HEXED = "hexed"   # blocks self-buff moves and self-stat-mod application


# ── Stat Modifier ──────────────────────────────────────────────────────────────

@dataclass
class StatModifier:
    stat: str           # "atk", "mag", "def_", "res", "spd"
    amount: int         # positive = buff, negative = debuff
    turns_remaining: int


# ── Move ───────────────────────────────────────────────────────────────────────

@dataclass
class Move:
    name: str
    power: int
    accuracy: float
    move_type: MoveType
    slot: MoveSlot
    cooldown_turns: int = 0

    # Stat modifications applied on hit (list of (stat_name, delta) tuples)
    target_stat_mods: list[tuple[str, int]] = field(default_factory=list)
    self_stat_mods:   list[tuple[str, int]] = field(default_factory=list)

    # Status effect applied to defender on hit
    applies_status: Optional[str] = None
    status_duration: int = 0

    # If True, the entire move is blocked when the attacker is Hexed
    is_buff_move: bool = False


# ── Unit ───────────────────────────────────────────────────────────────────────

class Unit:
    """
    A combatant with mutable live stats, cooldowns, modifiers, and statuses.
    Base stats are stored separately and restored on reset() between battles.
    """

    def __init__(
        self,
        class_name: ClassName,
        name: str,
        hp: int, atk: int, mag: int,
        def_: int, res: int, spd: int,
        moves: list[Move],
    ):
        self.class_name = class_name
        self.name = name

        # Immutable base stats — restored by reset()
        self._base_hp  = hp
        self._base_atk = atk
        self._base_mag = mag
        self._base_def = def_
        self._base_res = res
        self._base_spd = spd

        # Live stats — mutated during combat
        self.hp   = hp
        self.atk  = atk
        self.mag  = mag
        self.def_ = def_
        self.res  = res
        self.spd  = spd

        self.moves: list[Move] = moves
        self.cooldowns: dict[str, int] = {}          # move_name → turns remaining
        self._modifiers: list[StatModifier] = []
        self._statuses: list[tuple[str, int]] = []   # (status_name, turns_remaining)

    # ── Properties ────────────────────────────────────────────────────────────

    @property
    def is_alive(self) -> bool:
        return self.hp > 0

    # ── Reset ──────────────────────────────────────────────────────────────────

    def reset(self) -> None:
        """Restore all base stats and clear transient state. Call before each battle."""
        self.hp   = self._base_hp
        self.atk  = self._base_atk
        self.mag  = self._base_mag
        self.def_ = self._base_def
        self.res  = self._base_res
        self.spd  = self._base_spd
        self.cooldowns.clear()
        self._modifiers.clear()
        self._statuses.clear()

    # ── Stat Modifiers ────────────────────────────────────────────────────────

    def apply_stat_mod(self, stat: str, amount: int, duration: int) -> None:
        """Apply a stat delta immediately and track it for later reversal."""
        self._modifiers.append(StatModifier(stat=stat, amount=amount, turns_remaining=duration))
        self._shift_stat(stat, amount)

    def _shift_stat(self, stat: str, delta: int) -> None:
        """Apply a delta to a live stat, clamped to minimum 1."""
        if stat == "atk":
            self.atk  = max(1, self.atk  + delta)
        elif stat == "mag":
            self.mag  = max(1, self.mag  + delta)
        elif stat == "def_":
            self.def_ = max(1, self.def_ + delta)
        elif stat == "res":
            self.res  = max(1, self.res  + delta)
        elif stat == "spd":
            self.spd  = max(1, self.spd  + delta)

    def tick_modifiers(self) -> None:
        """
        Called at end of each turn. Decrements modifier durations,
        reverts expired ones, and ticks status effect durations.
        """
        surviving = []
        for mod in self._modifiers:
            mod.turns_remaining -= 1
            if mod.turns_remaining <= 0:
                self._shift_stat(mod.stat, -mod.amount)   # revert
            else:
                surviving.append(mod)
        self._modifiers = surviving

        self._statuses = [
            (name, turns - 1)
            for name, turns in self._statuses
            if turns - 1 > 0
        ]

    # ── Cooldowns ─────────────────────────────────────────────────────────────

    def tick_cooldowns(self) -> None:
        """Decrement all active cooldowns by 1, removing zeroed entries."""
        self.cooldowns = {
            name: turns - 1
            for name, turns in self.cooldowns.items()
            if turns - 1 > 0
        }

    def available_moves(self) -> list[Move]:
        """Return moves not currently on cooldown."""
        return [m for m in self.moves if self.cooldowns.get(m.name, 0) == 0]

    # ── Status Effects ────────────────────────────────────────────────────────

    def apply_status(self, status: str, duration: int) -> None:
        """Apply a status, replacing any existing instance of the same status."""
        self._statuses = [(n, t) for n, t in self._statuses if n != status]
        self._statuses.append((status, duration))

    def has_status(self, status: str) -> bool:
        return any(n == status for n, _ in self._statuses)

    def __repr__(self) -> str:
        return f"Unit({self.class_name.value}, {self.name}, hp={self.hp})"


# ── Move Rosters ───────────────────────────────────────────────────────────────
#
# Each class gets exactly three moves: Basic / Signature / Gambit.
# Moves are created fresh each time so Unit instances don't share mutable data.

def _warrior_moves() -> list[Move]:
    return [
        Move(
            name="Iron Strike", power=24, accuracy=1.0,
            move_type=MoveType.PHYSICAL, slot=MoveSlot.BASIC,
        ),
        Move(
            name="Rend", power=28, accuracy=0.90,
            move_type=MoveType.PHYSICAL, slot=MoveSlot.SIGNATURE,
            cooldown_turns=2,
            target_stat_mods=[("def_", -5)],
        ),
        Move(
            name="Berserker Rush", power=38, accuracy=0.75,
            move_type=MoveType.PHYSICAL, slot=MoveSlot.GAMBIT,
            cooldown_turns=3,
            self_stat_mods=[("atk", +8), ("def_", -6)],
        ),
    ]


def _mage_moves() -> list[Move]:
    return [
        Move(
            name="Arcane Bolt", power=24, accuracy=1.0,
            move_type=MoveType.MAGICAL, slot=MoveSlot.BASIC,
        ),
        Move(
            name="Arcane Lance", power=30, accuracy=0.90,
            move_type=MoveType.MAGICAL, slot=MoveSlot.SIGNATURE,
            cooldown_turns=2,
            target_stat_mods=[("res", -5)],
        ),
        Move(
            name="Overchannel", power=42, accuracy=0.70,
            move_type=MoveType.MAGICAL, slot=MoveSlot.GAMBIT,
            cooldown_turns=3,
            self_stat_mods=[("mag", +10), ("res", -8)],
        ),
    ]


def _assassin_moves() -> list[Move]:
    return [
        Move(
            name="Quick Strike", power=22, accuracy=1.0,
            move_type=MoveType.PHYSICAL, slot=MoveSlot.BASIC,
        ),
        Move(
            name="Cripple", power=26, accuracy=0.85,
            move_type=MoveType.PHYSICAL, slot=MoveSlot.SIGNATURE,
            cooldown_turns=2,
            target_stat_mods=[("def_", -4), ("res", -4)],
        ),
        Move(
            name="Death Mark", power=36, accuracy=0.75,
            move_type=MoveType.PHYSICAL, slot=MoveSlot.GAMBIT,
            cooldown_turns=3,
            target_stat_mods=[("atk", -6), ("mag", -6)],
        ),
    ]


def _guardian_moves() -> list[Move]:
    return [
        Move(
            name="Shield Bash", power=20, accuracy=1.0,
            move_type=MoveType.PHYSICAL, slot=MoveSlot.BASIC,
        ),
        Move(
            name="Fortify", power=5, accuracy=1.0,
            move_type=MoveType.PHYSICAL, slot=MoveSlot.SIGNATURE,
            cooldown_turns=2,
            self_stat_mods=[("def_", +8), ("res", +6)],
            is_buff_move=True,
        ),
        Move(
            name="Bulwark Strike", power=30, accuracy=0.85,
            move_type=MoveType.PHYSICAL, slot=MoveSlot.GAMBIT,
            cooldown_turns=3,
            self_stat_mods=[("def_", +6)],
        ),
    ]


def _neutral_moves() -> list[Move]:
    return [
        Move(
            name="Hybrid Strike", power=22, accuracy=1.0,
            move_type=MoveType.ADAPTIVE, slot=MoveSlot.BASIC,
        ),
        Move(
            name="Focus Shift", power=10, accuracy=1.0,
            move_type=MoveType.ADAPTIVE, slot=MoveSlot.SIGNATURE,
            cooldown_turns=2,
            self_stat_mods=[("atk", +4), ("mag", +4), ("def_", -4), ("res", -4)],
            is_buff_move=True,
        ),
        Move(
            name="Wild Card", power=32, accuracy=0.70,
            move_type=MoveType.ADAPTIVE, slot=MoveSlot.GAMBIT,
            cooldown_turns=3,
        ),
    ]


def _sorcerer_moves() -> list[Move]:
    return [
        Move(
            name="Shadow Bolt", power=22, accuracy=1.0,
            move_type=MoveType.MAGICAL, slot=MoveSlot.BASIC,
        ),
        Move(
            name="Hex", power=18, accuracy=0.90,
            move_type=MoveType.MAGICAL, slot=MoveSlot.SIGNATURE,
            cooldown_turns=3,
            applies_status="hexed",
            status_duration=3,
        ),
        Move(
            name="Soul Drain", power=38, accuracy=0.75,
            move_type=MoveType.MAGICAL, slot=MoveSlot.GAMBIT,
            cooldown_turns=3,
            target_stat_mods=[("res", -7)],
        ),
    ]


# ── Class Stats ────────────────────────────────────────────────────────────────
#                       hp   atk  mag  def_  res  spd
_STATS: dict[ClassName, tuple[int, int, int, int, int, int]] = {
    ClassName.WARRIOR:  (85,  75,  20,  60,  25,  55),
    ClassName.MAGE:     (65,  20,  80,  30,  65,  70),
    ClassName.ASSASSIN: (70,  80,  30,  35,  50,  90),
    ClassName.GUARDIAN: (95,  50,  30,  80,  70,  40),
    ClassName.NEUTRAL:  (75,  55,  55,  55,  55,  60),
    ClassName.SORCERER: (70,  30,  75,  25,  60,  75),
}

_MOVE_FACTORIES = {
    ClassName.WARRIOR:  _warrior_moves,
    ClassName.MAGE:     _mage_moves,
    ClassName.ASSASSIN: _assassin_moves,
    ClassName.GUARDIAN: _guardian_moves,
    ClassName.NEUTRAL:  _neutral_moves,
    ClassName.SORCERER: _sorcerer_moves,
}


# ── Factory ────────────────────────────────────────────────────────────────────

def create_unit(class_name: ClassName, name: str) -> Unit:
    """Instantiate a fresh Unit for the given class."""
    hp, atk, mag, def_, res, spd = _STATS[class_name]
    return Unit(
        class_name=class_name,
        name=name,
        hp=hp, atk=atk, mag=mag,
        def_=def_, res=res, spd=spd,
        moves=_MOVE_FACTORIES[class_name](),
    )
