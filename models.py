"""
Crestbound Duelists — Data Models (v2.1)
=========================================
Dataclasses for units, moves, and status effects.
Full 6-class × 3-move table with Brace passive,
cooldowns, and stat-modifier decay.

v2.1 balance changes:
  - Neutral: HP 75→80, Hybrid Strike 22→24p, Focus Shift +4/+4→+6/+6,
    Wild Card 70%→75% accuracy
  - Assassin: RES 50→55, Cripple -4/-4→-5/-5
"""

from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum, auto
from typing import Optional
import copy


# ── Enums ────────────────────────────────────────────────────────────

class MoveType(Enum):
    PHYSICAL = auto()
    MAGICAL = auto()
    ADAPTIVE = auto()


class MoveSlot(Enum):
    BASIC = auto()
    SIGNATURE = auto()
    GAMBIT = auto()


class ClassName(Enum):
    WARRIOR = "Warrior"
    MAGE = "Mage"
    ASSASSIN = "Assassin"
    GUARDIAN = "Guardian"
    NEUTRAL = "Neutral"
    SORCERER = "Sorcerer"


# ── Status Effects ───────────────────────────────────────────────────

@dataclass
class StatModifier:
    """A temporary stat change that decays after `duration` turns."""
    stat: str
    amount: int
    turns_remaining: int = 3

    def tick(self) -> bool:
        """Tick down. Returns True if expired."""
        self.turns_remaining -= 1
        return self.turns_remaining <= 0


@dataclass
class StatusEffect:
    """A named status (e.g. 'hexed') with a turn duration."""
    name: str
    turns_remaining: int = 2

    def tick(self) -> bool:
        self.turns_remaining -= 1
        return self.turns_remaining <= 0


# ── Move ─────────────────────────────────────────────────────────────

@dataclass
class Move:
    name: str
    move_type: MoveType
    slot: MoveSlot
    power: int
    accuracy: float  # 0.0 to 1.0

    # Secondary effects
    target_stat_mods: list[tuple[str, int]] = field(default_factory=list)
    self_stat_mods: list[tuple[str, int]] = field(default_factory=list)
    is_buff_move: bool = False  # blocked by Hex
    applies_status: Optional[str] = None
    status_duration: int = 0

    @property
    def cooldown_turns(self) -> int:
        return 0 if self.slot == MoveSlot.BASIC else 1


# ── Unit ─────────────────────────────────────────────────────────────

@dataclass
class Unit:
    name: str
    class_name: ClassName

    # Base stats (immutable reference)
    base_hp: int
    base_atk: int
    base_def: int
    base_mag: int
    base_res: int
    base_spd: int

    # Current HP
    hp: int = 0

    # Moves
    moves: list[Move] = field(default_factory=list)

    # Active stat modifiers (decay over turns)
    stat_modifiers: list[StatModifier] = field(default_factory=list)

    # Active status effects
    status_effects: list[StatusEffect] = field(default_factory=list)

    # Cooldown tracker: move_name -> turns until available (0 = ready)
    cooldowns: dict[str, int] = field(default_factory=dict)

    def __post_init__(self):
        if self.hp == 0:
            self.hp = self.base_hp

    # ── Effective stats (base + modifiers) ───────────────────────────

    def _effective(self, stat: str) -> int:
        base = getattr(self, f"base_{stat}")
        mod = sum(m.amount for m in self.stat_modifiers if m.stat == stat)
        return max(1, base + mod)

    @property
    def atk(self) -> int:
        return self._effective("atk")

    @property
    def def_(self) -> int:
        return self._effective("def")

    @property
    def mag(self) -> int:
        return self._effective("mag")

    @property
    def res(self) -> int:
        return self._effective("res")

    @property
    def spd(self) -> int:
        return self._effective("spd")

    # ── State management ─────────────────────────────────────────────

    @property
    def is_alive(self) -> bool:
        return self.hp > 0

    def has_status(self, name: str) -> bool:
        return any(s.name == name for s in self.status_effects)

    def available_moves(self) -> list[Move]:
        """Return moves not on cooldown."""
        return [m for m in self.moves if self.cooldowns.get(m.name, 0) <= 0]

    def tick_cooldowns(self):
        """Reduce all cooldowns by 1 at end of turn."""
        for name in list(self.cooldowns):
            self.cooldowns[name] = max(0, self.cooldowns[name] - 1)

    def tick_modifiers(self):
        """Decay stat modifiers and status effects. Call at end of turn."""
        expired = [m for m in self.stat_modifiers if m.tick()]
        self.stat_modifiers = [m for m in self.stat_modifiers if m not in expired]
        expired_s = [s for s in self.status_effects if s.tick()]
        self.status_effects = [s for s in self.status_effects if s not in expired_s]

    def apply_stat_mod(self, stat: str, amount: int, duration: int = 3):
        """Apply a temporary stat modifier with decay."""
        self.stat_modifiers.append(StatModifier(stat=stat, amount=amount, turns_remaining=duration))

    def apply_status(self, name: str, duration: int):
        for s in self.status_effects:
            if s.name == name:
                s.turns_remaining = duration
                return
        self.status_effects.append(StatusEffect(name=name, turns_remaining=duration))

    def reset(self):
        """Reset unit to fresh state for a new battle."""
        self.hp = self.base_hp
        self.stat_modifiers.clear()
        self.status_effects.clear()
        self.cooldowns.clear()


# ── Move Definitions ─────────────────────────────────────────────────

STAT_DECAY = 3


def _moves_warrior() -> list[Move]:
    return [
        Move("Power Slash", MoveType.PHYSICAL, MoveSlot.BASIC, 24, 1.0),
        Move("Armor Break", MoveType.PHYSICAL, MoveSlot.SIGNATURE, 18, 1.0,
             target_stat_mods=[("def", -5)]),
        Move("Reckless Charge", MoveType.PHYSICAL, MoveSlot.GAMBIT, 30, 0.75,
             self_stat_mods=[("def", -4)]),
    ]


def _moves_mage() -> list[Move]:
    return [
        Move("Arcane Bolt", MoveType.MAGICAL, MoveSlot.BASIC, 24, 1.0),
        Move("Mind Pierce", MoveType.MAGICAL, MoveSlot.SIGNATURE, 18, 1.0,
             target_stat_mods=[("res", -5)]),
        Move("Overload", MoveType.MAGICAL, MoveSlot.GAMBIT, 30, 0.75,
             self_stat_mods=[("res", -4)]),
    ]


def _moves_assassin() -> list[Move]:
    return [
        Move("Quick Strike", MoveType.PHYSICAL, MoveSlot.BASIC, 24, 1.0),
        # v2.1: Cripple buffed from -4/-4 to -5/-5
        Move("Cripple", MoveType.PHYSICAL, MoveSlot.SIGNATURE, 18, 1.0,
             target_stat_mods=[("def", -5), ("res", -5)]),
        Move("Lethal Edge", MoveType.PHYSICAL, MoveSlot.GAMBIT, 32, 0.70),
    ]


def _moves_guardian() -> list[Move]:
    return [
        Move("Shield Bash", MoveType.ADAPTIVE, MoveSlot.BASIC, 23, 1.0),
        Move("Fortify", MoveType.MAGICAL, MoveSlot.SIGNATURE, 16, 1.0,
             self_stat_mods=[("def", 4), ("res", 4)], is_buff_move=True),
        Move("Avalanche", MoveType.PHYSICAL, MoveSlot.GAMBIT, 28, 0.80),
    ]


def _moves_neutral() -> list[Move]:
    return [
        # v2.1: Hybrid Strike 22→23 power (slight adaptive premium)
        Move("Hybrid Strike", MoveType.ADAPTIVE, MoveSlot.BASIC, 23, 1.0),
        # v2.1: Focus Shift +4/+4→+5/+5 ATK/MAG
        Move("Focus Shift", MoveType.MAGICAL, MoveSlot.SIGNATURE, 18, 1.0,
             self_stat_mods=[("atk", 5), ("mag", 5), ("def", -4), ("res", -4)]),
        # v2.1: Wild Card 70%→75% accuracy
        Move("Wild Card", MoveType.ADAPTIVE, MoveSlot.GAMBIT, 30, 0.75),
    ]


def _moves_sorcerer() -> list[Move]:
    return [
        Move("Flame", MoveType.MAGICAL, MoveSlot.BASIC, 24, 1.0),
        Move("Hex", MoveType.MAGICAL, MoveSlot.SIGNATURE, 18, 1.0,
             applies_status="hexed", status_duration=2),
        Move("Voidfire", MoveType.MAGICAL, MoveSlot.GAMBIT, 30, 0.75,
             self_stat_mods=[("res", -4)]),
    ]


# ── Class Factory ────────────────────────────────────────────────────

CLASS_STATS: dict[ClassName, dict] = {
    ClassName.WARRIOR:  {"hp": 85, "atk": 75, "def": 70, "mag": 30, "res": 35, "spd": 40},
    ClassName.MAGE:     {"hp": 75, "atk": 30, "def": 35, "mag": 80, "res": 75, "spd": 42},
    # v2.1: Assassin RES 50→55, MAG 30→38
    ClassName.ASSASSIN: {"hp": 70, "atk": 70, "def": 35, "mag": 38, "res": 55, "spd": 80},
    ClassName.GUARDIAN: {"hp": 85, "atk": 40, "def": 75, "mag": 40, "res": 75, "spd": 35},
    # v2.1: Neutral HP 75→78
    ClassName.NEUTRAL:  {"hp": 78, "atk": 55, "def": 50, "mag": 55, "res": 50, "spd": 50},
    ClassName.SORCERER: {"hp": 72, "atk": 40, "def": 30, "mag": 80, "res": 48, "spd": 80},
}

MOVE_FACTORIES: dict[ClassName, callable] = {
    ClassName.WARRIOR:  _moves_warrior,
    ClassName.MAGE:     _moves_mage,
    ClassName.ASSASSIN: _moves_assassin,
    ClassName.GUARDIAN: _moves_guardian,
    ClassName.NEUTRAL:  _moves_neutral,
    ClassName.SORCERER: _moves_sorcerer,
}


def create_unit(class_name: ClassName, name: Optional[str] = None) -> Unit:
    """Factory: create a fresh unit of the given class."""
    stats = CLASS_STATS[class_name]
    return Unit(
        name=name or class_name.value,
        class_name=class_name,
        base_hp=stats["hp"],
        base_atk=stats["atk"],
        base_def=stats["def"],
        base_mag=stats["mag"],
        base_res=stats["res"],
        base_spd=stats["spd"],
        hp=stats["hp"],
        moves=MOVE_FACTORIES[class_name](),
    )
