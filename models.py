"""
Crestbound Duelists — Data Models (v2.1)
=========================================
Dataclasses for units, moves, and status effects.

Class stats and move kits are defined in data/classes.yaml and
data/moves.yaml (v2.1 balance baseline) and loaded via loaders.py.
This module keeps the engine types plus the backward-compatible
create_unit / CLASS_STATS / MOVE_FACTORIES / STAT_DECAY API.
"""

from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum, auto
from typing import Optional


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


# ── Data-backed definitions ──────────────────────────────────────────
# Class stats, move kits, and STAT_DECAY live in data/*.yaml and are
# loaded through loaders.py. The names below are kept for backward
# compatibility (analysis.ipynb imports CLASS_STATS directly) and are
# resolved lazily to avoid a models <-> loaders import cycle.


def create_unit(class_name: ClassName, name: Optional[str] = None) -> Unit:
    """Factory: create a fresh unit of the given class."""
    from loaders import create_unit_from_data

    return create_unit_from_data(class_name.value.lower(), name=name)


def __getattr__(attr: str):
    if attr == "CLASS_STATS":
        from loaders import legacy_class_stats

        value = legacy_class_stats()
    elif attr == "MOVE_FACTORIES":
        from loaders import legacy_move_factories

        value = legacy_move_factories()
    elif attr == "STAT_DECAY":
        from loaders import load_combat_config

        value = int(load_combat_config()["stat_decay_duration"])
    else:
        raise AttributeError(f"module 'models' has no attribute {attr!r}")
    globals()[attr] = value  # cache for subsequent access
    return value
