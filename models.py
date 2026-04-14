"""
Crestbound Duelists — Data Models (v2.1)
========================================
Core dataclasses and unit factory for classes/moves.
"""

from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum
from typing import Optional


class ClassName(str, Enum):
    WARRIOR = "Warrior"
    MAGE = "Mage"
    ASSASSIN = "Assassin"
    GUARDIAN = "Guardian"
    NEUTRAL = "Neutral"
    SORCERER = "Sorcerer"


class MoveType(str, Enum):
    PHYSICAL = "physical"
    MAGICAL = "magical"
    ADAPTIVE = "adaptive"


class MoveSlot(str, Enum):
    BASIC = "basic"
    SIGNATURE = "signature"
    GAMBIT = "gambit"


# Per-turn decay toward 0 for temporary stat modifiers.
STAT_DECAY: int = 1

# Canonical stat names used by effects.
StatModifier = str
StatusEffect = str


@dataclass
class Move:
    name: str
    slot: MoveSlot
    move_type: MoveType
    power: int
    accuracy: float = 1.0
    cooldown_turns: int = 0
    self_stat_mods: list[tuple[StatModifier, int]] = field(default_factory=list)
    target_stat_mods: list[tuple[StatModifier, int]] = field(default_factory=list)
    applies_status: Optional[StatusEffect] = None
    status_duration: int = 0
    is_buff_move: bool = False


@dataclass
class Unit:
    class_name: ClassName
    name: str
    max_hp: int
    base_atk: int
    base_mag: int
    base_def: int
    base_res: int
    spd: int
    moves: list[Move]

    hp: int = field(init=False)
    cooldowns: dict[str, int] = field(default_factory=dict)
    status_effects: dict[StatusEffect, int] = field(default_factory=dict)
    stat_mods: dict[str, int] = field(default_factory=lambda: {
        "atk": 0,
        "mag": 0,
        "def_": 0,
        "res": 0,
        "spd": 0,
    })

    def __post_init__(self):
        self.hp = self.max_hp

    @property
    def is_alive(self) -> bool:
        return self.hp > 0

    @property
    def atk(self) -> int:
        return max(1, self.base_atk + self.stat_mods["atk"])

    @property
    def mag(self) -> int:
        return max(1, self.base_mag + self.stat_mods["mag"])

    @property
    def def_(self) -> int:
        return max(1, self.base_def + self.stat_mods["def_"])

    @property
    def res(self) -> int:
        return max(1, self.base_res + self.stat_mods["res"])

    def reset(self) -> None:
        self.hp = self.max_hp
        self.cooldowns.clear()
        self.status_effects.clear()
        for key in self.stat_mods:
            self.stat_mods[key] = 0

    def has_status(self, status: StatusEffect) -> bool:
        return self.status_effects.get(status, 0) > 0

    def apply_status(self, status: StatusEffect, turns: int) -> None:
        if turns > 0:
            self.status_effects[status] = max(self.status_effects.get(status, 0), turns)

    def apply_stat_mod(self, stat: StatModifier, amount: int, _decay: int) -> None:
        if stat not in self.stat_mods:
            return
        self.stat_mods[stat] += amount

    def tick_modifiers(self) -> None:
        for stat, value in list(self.stat_mods.items()):
            if value > 0:
                self.stat_mods[stat] -= STAT_DECAY
            elif value < 0:
                self.stat_mods[stat] += STAT_DECAY

        for status, turns in list(self.status_effects.items()):
            nxt = turns - 1
            if nxt <= 0:
                self.status_effects.pop(status, None)
            else:
                self.status_effects[status] = nxt

    def tick_cooldowns(self) -> None:
        for move_name, turns in list(self.cooldowns.items()):
            nxt = turns - 1
            if nxt <= 0:
                self.cooldowns.pop(move_name, None)
            else:
                self.cooldowns[move_name] = nxt

    def available_moves(self) -> list[Move]:
        return [m for m in self.moves if self.cooldowns.get(m.name, 0) <= 0]


def _build_moves(class_name: ClassName) -> list[Move]:
    move_table: dict[ClassName, list[Move]] = {
        ClassName.WARRIOR: [
            Move("Slash", MoveSlot.BASIC, MoveType.PHYSICAL, power=24),
            Move("Iron Break", MoveSlot.SIGNATURE, MoveType.PHYSICAL, power=20, cooldown_turns=1,
                 target_stat_mods=[("def_", -4)]),
            Move("Reckless Charge", MoveSlot.GAMBIT, MoveType.PHYSICAL, power=34, accuracy=0.75,
                 cooldown_turns=2, self_stat_mods=[("def_", -4)]),
        ],
        ClassName.MAGE: [
            Move("Bolt", MoveSlot.BASIC, MoveType.MAGICAL, power=24),
            Move("Hex", MoveSlot.SIGNATURE, MoveType.MAGICAL, power=18, cooldown_turns=2,
                 applies_status="hexed", status_duration=2),
            Move("Arc Surge", MoveSlot.GAMBIT, MoveType.MAGICAL, power=32, accuracy=0.8,
                 cooldown_turns=2, self_stat_mods=[("res", -3)]),
        ],
        ClassName.ASSASSIN: [
            Move("Stab", MoveSlot.BASIC, MoveType.PHYSICAL, power=24),
            Move("Cripple", MoveSlot.SIGNATURE, MoveType.PHYSICAL, power=18, cooldown_turns=1,
                 target_stat_mods=[("def_", -5), ("res", -5)]),
            Move("Execution", MoveSlot.GAMBIT, MoveType.PHYSICAL, power=36, accuracy=0.7,
                 cooldown_turns=2, self_stat_mods=[("def_", -5)]),
        ],
        ClassName.GUARDIAN: [
            Move("Shield Bash", MoveSlot.BASIC, MoveType.PHYSICAL, power=22),
            Move("Fortify", MoveSlot.SIGNATURE, MoveType.PHYSICAL, power=12, cooldown_turns=2,
                 self_stat_mods=[("def_", +5), ("res", +5)], is_buff_move=True),
            Move("Bulwark Slam", MoveSlot.GAMBIT, MoveType.PHYSICAL, power=30, accuracy=0.8,
                 cooldown_turns=2, self_stat_mods=[("spd", -3)]),
        ],
        ClassName.NEUTRAL: [
            Move("Hybrid Strike", MoveSlot.BASIC, MoveType.ADAPTIVE, power=24),
            Move("Focus Shift", MoveSlot.SIGNATURE, MoveType.ADAPTIVE, power=14, cooldown_turns=2,
                 self_stat_mods=[("atk", +6), ("mag", +6), ("def_", -4), ("res", -4)],
                 is_buff_move=True),
            Move("Wild Card", MoveSlot.GAMBIT, MoveType.ADAPTIVE, power=34, accuracy=0.75,
                 cooldown_turns=2),
        ],
        ClassName.SORCERER: [
            Move("Ember", MoveSlot.BASIC, MoveType.MAGICAL, power=24),
            Move("Siphon", MoveSlot.SIGNATURE, MoveType.MAGICAL, power=18, cooldown_turns=1,
                 target_stat_mods=[("mag", -4)]),
            Move("Inferno Pact", MoveSlot.GAMBIT, MoveType.MAGICAL, power=35, accuracy=0.72,
                 cooldown_turns=2, self_stat_mods=[("res", -4)]),
        ],
    }
    return move_table[class_name]


def create_unit(class_name: ClassName, name: str) -> Unit:
    stats = {
        ClassName.WARRIOR: dict(max_hp=84, base_atk=76, base_mag=28, base_def=63, base_res=42, spd=42),
        ClassName.MAGE: dict(max_hp=76, base_atk=25, base_mag=77, base_def=38, base_res=74, spd=46),
        ClassName.ASSASSIN: dict(max_hp=70, base_atk=74, base_mag=30, base_def=35, base_res=55, spd=70),
        ClassName.GUARDIAN: dict(max_hp=92, base_atk=58, base_mag=22, base_def=78, base_res=64, spd=28),
        ClassName.NEUTRAL: dict(max_hp=80, base_atk=58, base_mag=58, base_def=58, base_res=58, spd=50),
        ClassName.SORCERER: dict(max_hp=78, base_atk=30, base_mag=74, base_def=44, base_res=60, spd=52),
    }[class_name]

    return Unit(
        class_name=class_name,
        name=name,
        moves=_build_moves(class_name),
        **stats,
    )
