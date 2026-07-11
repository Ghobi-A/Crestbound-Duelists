"""
Crestbound Duelists — RPG Domain Models
=========================================
Typed models for the RPG layer built on top of the combat engine:
Crests, Bonded Entities, Duelist builds, teams, and tactical-battle
primitives. These establish domain boundaries for the Godot client
and future battle-layer work; they deliberately stay lightweight.

A Duelist = Character + Class + Crest + Bonded Entity + Trait + Move Kit.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Optional

from loaders import load_crests, load_entities
from models import ClassName


@dataclass(frozen=True)
class Crest:
    """A fragment of Eidros with an innate behavioural nature."""
    id: str
    name: str
    affinity: str
    rarity: str
    description: str
    compatible_classes: tuple[str, ...]
    passive_modifier: dict[str, Any]
    awakening_condition: dict[str, Any]
    awakening_effect: dict[str, Any]
    visual_theme: dict[str, Any]
    tags: tuple[str, ...] = ()

    @classmethod
    def from_record(cls, record: dict[str, Any]) -> "Crest":
        return cls(
            id=record["id"],
            name=record["name"],
            affinity=record["affinity"],
            rarity=record["rarity"],
            description=record["description"],
            compatible_classes=tuple(record["compatible_classes"]),
            passive_modifier=dict(record["passive_modifier"]),
            awakening_condition=dict(record["awakening_condition"]),
            awakening_effect=dict(record["awakening_effect"]),
            visual_theme=dict(record["visual_theme"]),
            tags=tuple(record.get("tags", [])),
        )

    def is_compatible_with(self, class_id: str) -> bool:
        return class_id.lower() in self.compatible_classes


@dataclass(frozen=True)
class BondedEntity:
    """A manifestation produced by the Duelist-Crest relationship."""
    id: str
    name: str
    category: str
    affinity: str
    rarity: str
    description: str
    compatible_classes: tuple[str, ...]
    passive_effect: dict[str, Any]
    granted_move: str
    awakening_form: str
    awakening_effect: dict[str, Any]
    visual_theme: dict[str, Any]
    tags: tuple[str, ...] = ()

    @classmethod
    def from_record(cls, record: dict[str, Any]) -> "BondedEntity":
        return cls(
            id=record["id"],
            name=record["name"],
            category=record["category"],
            affinity=record["affinity"],
            rarity=record["rarity"],
            description=record["description"],
            compatible_classes=tuple(record["compatible_classes"]),
            passive_effect=dict(record["passive_effect"]),
            granted_move=record["granted_move"],
            awakening_form=record["awakening_form"],
            awakening_effect=dict(record["awakening_effect"]),
            visual_theme=dict(record["visual_theme"]),
            tags=tuple(record.get("tags", [])),
        )

    def is_compatible_with(self, class_id: str) -> bool:
        return class_id.lower() in self.compatible_classes


def get_crest(crest_id: str) -> Crest:
    """Load a single Crest by id from data/crests.yaml."""
    records = load_crests()
    if crest_id not in records:
        raise KeyError(f"Unknown crest id '{crest_id}'. Known: {', '.join(records)}.")
    return Crest.from_record(records[crest_id])


def get_entity(entity_id: str) -> BondedEntity:
    """Load a single Bonded Entity by id from data/entities.yaml."""
    records = load_entities()
    if entity_id not in records:
        raise KeyError(f"Unknown entity id '{entity_id}'. Known: {', '.join(records)}.")
    return BondedEntity.from_record(records[entity_id])


# Prototype default Crest for each starting class (architecture allows
# any compatible combination; these are just the development defaults).
DEFAULT_CREST_BY_CLASS: dict[str, str] = {
    "warrior": "crimson_crest",
    "guardian": "azure_crest",
    "mage": "ember_crest",
    "sorcerer": "eclipse_crest",
    "assassin": "glass_crest",
    "neutral": "verdant_crest",
}


@dataclass
class DuelistProfile:
    """A complete build: character + class + Crest + Bonded Entity."""
    character_name: str
    class_id: str
    crest_id: Optional[str] = None
    entity_id: Optional[str] = None
    trait: Optional[str] = None
    level: int = 1

    def __post_init__(self) -> None:
        valid_classes = {c.value.lower() for c in ClassName}
        if self.class_id not in valid_classes:
            raise ValueError(
                f"Unknown class id '{self.class_id}'. Known: {sorted(valid_classes)}."
            )

    @property
    def crest(self) -> Optional[Crest]:
        return get_crest(self.crest_id) if self.crest_id else None

    @property
    def entity(self) -> Optional[BondedEntity]:
        return get_entity(self.entity_id) if self.entity_id else None


@dataclass
class Team:
    """An ordered party of Duelist builds."""
    name: str
    members: list[DuelistProfile] = field(default_factory=list)

    def __len__(self) -> int:
        return len(self.members)


@dataclass(frozen=True)
class GridPosition:
    """A tile coordinate on the tactical battle grid."""
    x: int
    y: int

    def manhattan_distance(self, other: "GridPosition") -> int:
        return abs(self.x - other.x) + abs(self.y - other.y)


@dataclass(frozen=True)
class TerrainTile:
    """A terrain type placed at grid positions in an encounter."""
    id: str
    name: str
    move_cost: int
    passable: bool
    defense_bonus: int = 0
    resistance_bonus: int = 0
    tags: tuple[str, ...] = ()

    @classmethod
    def from_record(cls, record: dict[str, Any]) -> "TerrainTile":
        return cls(
            id=record["id"],
            name=record["name"],
            move_cost=record["move_cost"],
            passable=record["passable"],
            defense_bonus=record.get("defense_bonus", 0),
            resistance_bonus=record.get("resistance_bonus", 0),
            tags=tuple(record.get("tags", [])),
        )


@dataclass(frozen=True)
class BattleObjective:
    """A win/loss condition for a tactical encounter."""
    id: str
    name: str
    objective_type: str
    params: dict[str, Any] = field(default_factory=dict)

    @classmethod
    def from_record(cls, record: dict[str, Any]) -> "BattleObjective":
        return cls(
            id=record["id"],
            name=record["name"],
            objective_type=record["objective_type"],
            params=dict(record.get("params", {})),
        )


@dataclass
class Encounter:
    """A tactical battle setup: teams, grid, terrain, and objectives."""
    id: str
    name: str
    player_team: Team
    enemy_team: Team
    grid_width: int = 8
    grid_height: int = 6
    terrain_overrides: dict[GridPosition, str] = field(default_factory=dict)
    objectives: list[BattleObjective] = field(default_factory=list)
    intro_dialogue_id: Optional[str] = None
    outro_dialogue_id: Optional[str] = None


@dataclass(frozen=True)
class ProgressionReward:
    """A reward granted by an encounter or story beat."""
    reward_type: str            # e.g. 'crest', 'entity', 'crest_fragment', 'flag'
    reward_id: str
    amount: int = 1
    description: str = ""
