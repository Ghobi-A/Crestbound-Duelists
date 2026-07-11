"""
Crestbound Duelists — Data Loading Layer
==========================================
Loads and validates the YAML source data in data/ and turns it into
engine objects. This module is the single bridge between human-editable
game data and the Python combat engine.

Public API:
    load_classes() / load_moves() / load_combat_config()
    load_crests() / load_entities() / load_terrain()
    load_battle_objectives() / load_characters() / load_locations()
    create_unit_from_data(class_id, name=None)

All loaders cache parsed data. Functions returning raw records hand out
deep copies so callers can't mutate the cache.
"""

from __future__ import annotations

import copy
from functools import lru_cache
from pathlib import Path
from typing import Any, Callable, Optional

import yaml

from models import ClassName, Move, MoveSlot, MoveType, Unit

DATA_DIR = Path(__file__).resolve().parent / "data"

STAT_KEYS = ("hp", "atk", "def", "mag", "res", "spd")
MOD_STAT_KEYS = ("atk", "def", "mag", "res", "spd")

_MOVE_TYPES = {
    "physical": MoveType.PHYSICAL,
    "magical": MoveType.MAGICAL,
    "adaptive": MoveType.ADAPTIVE,
}
_MOVE_SLOTS = {
    "basic": MoveSlot.BASIC,
    "signature": MoveSlot.SIGNATURE,
    "gambit": MoveSlot.GAMBIT,
}
_CLASS_BY_ID = {c.value.lower(): c for c in ClassName}


class DataValidationError(Exception):
    """Raised when a data file is missing, unparseable, or invalid."""


# ── Low-level YAML reading ───────────────────────────────────────────

def _read_yaml(filename: str) -> Any:
    path = DATA_DIR / filename
    if not path.exists():
        raise DataValidationError(
            f"Data file not found: {path}. "
            f"Expected YAML source data in the data/ directory."
        )
    try:
        with path.open(encoding="utf-8") as f:
            return yaml.safe_load(f)
    except yaml.YAMLError as exc:
        raise DataValidationError(f"Could not parse {path}: {exc}") from exc


@lru_cache(maxsize=None)
def _load_records(filename: str, top_key: str, required: tuple[str, ...]) -> dict[str, dict]:
    """Load a YAML file shaped as `{top_key: [{id: ..., ...}, ...]}`.

    Returns an ordered dict keyed by record id. Cached — do not mutate.
    """
    raw = _read_yaml(filename)
    if not isinstance(raw, dict) or top_key not in raw:
        raise DataValidationError(
            f"{filename}: expected a top-level '{top_key}:' list."
        )
    entries = raw[top_key]
    if not isinstance(entries, list):
        raise DataValidationError(f"{filename}: '{top_key}' must be a list.")

    records: dict[str, dict] = {}
    for index, record in enumerate(entries):
        where = f"{filename} entry #{index + 1}"
        if not isinstance(record, dict):
            raise DataValidationError(f"{where}: each entry must be a mapping.")
        record_id = record.get("id")
        if not isinstance(record_id, str) or not record_id:
            raise DataValidationError(f"{where}: missing string 'id' field.")
        if record_id in records:
            raise DataValidationError(f"{filename}: duplicate id '{record_id}'.")
        missing = [key for key in required if key not in record]
        if missing:
            raise DataValidationError(
                f"{filename} record '{record_id}': missing required "
                f"field(s): {', '.join(missing)}."
            )
        records[record_id] = record
    return records


def _validate_stat_mods(where: str, mods: Any) -> None:
    if not isinstance(mods, list):
        raise DataValidationError(f"{where}: stat mods must be a list.")
    for mod in mods:
        if (
            not isinstance(mod, dict)
            or mod.get("stat") not in MOD_STAT_KEYS
            or not isinstance(mod.get("amount"), int)
        ):
            raise DataValidationError(
                f"{where}: each stat mod needs 'stat' (one of "
                f"{MOD_STAT_KEYS}) and an integer 'amount'; got {mod!r}."
            )


# ── Combat config ────────────────────────────────────────────────────

_CONFIG_KEYS = (
    "speed_band",
    "guaranteed_speed_ratio",
    "variance_low",
    "variance_high",
    "brace_multiplier",
    "max_turns",
    "stat_decay_duration",
)


@lru_cache(maxsize=1)
def _combat_config() -> dict[str, float]:
    raw = _read_yaml("combat_config.yaml")
    if not isinstance(raw, dict):
        raise DataValidationError("combat_config.yaml: expected a mapping of settings.")
    missing = [key for key in _CONFIG_KEYS if key not in raw]
    if missing:
        raise DataValidationError(
            f"combat_config.yaml: missing key(s): {', '.join(missing)}."
        )
    for key in _CONFIG_KEYS:
        if not isinstance(raw[key], (int, float)) or isinstance(raw[key], bool):
            raise DataValidationError(
                f"combat_config.yaml: '{key}' must be a number, got {raw[key]!r}."
            )
    if not 0 < raw["variance_low"] <= raw["variance_high"]:
        raise DataValidationError(
            "combat_config.yaml: require 0 < variance_low <= variance_high."
        )
    if raw["max_turns"] < 1 or raw["stat_decay_duration"] < 1:
        raise DataValidationError(
            "combat_config.yaml: max_turns and stat_decay_duration must be >= 1."
        )
    return {key: raw[key] for key in _CONFIG_KEYS}


def load_combat_config() -> dict[str, float]:
    """Return the validated global combat constants."""
    return dict(_combat_config())


# ── Moves ────────────────────────────────────────────────────────────

_MOVE_REQUIRED = ("name", "class_id", "move_type", "slot", "power", "accuracy")


@lru_cache(maxsize=1)
def _moves() -> dict[str, dict]:
    records = _load_records("moves.yaml", "moves", _MOVE_REQUIRED)
    for move_id, record in records.items():
        where = f"moves.yaml move '{move_id}'"
        if record["move_type"] not in _MOVE_TYPES:
            raise DataValidationError(
                f"{where}: move_type must be one of {sorted(_MOVE_TYPES)}."
            )
        if record["slot"] not in _MOVE_SLOTS:
            raise DataValidationError(
                f"{where}: slot must be one of {sorted(_MOVE_SLOTS)}."
            )
        if not isinstance(record["power"], int) or record["power"] < 0:
            raise DataValidationError(f"{where}: power must be a non-negative integer.")
        if not isinstance(record["accuracy"], (int, float)) or not 0 < record["accuracy"] <= 1:
            raise DataValidationError(f"{where}: accuracy must be in (0, 1].")

        _validate_stat_mods(where, record.get("target_stat_mods", []))
        _validate_stat_mods(where, record.get("self_stat_mods", []))

        for effect in record.get("status_effects", []):
            if (
                not isinstance(effect, dict)
                or not isinstance(effect.get("status"), str)
                or not isinstance(effect.get("duration"), int)
            ):
                raise DataValidationError(
                    f"{where}: status effects need string 'status' and "
                    f"integer 'duration'; got {effect!r}."
                )

        # The engine derives cooldowns from the slot (Basic = 0, others = 1).
        # Keep the data honest: an explicit cooldown must match.
        expected_cd = 0 if record["slot"] == "basic" else 1
        if record.get("cooldown_turns", expected_cd) != expected_cd:
            raise DataValidationError(
                f"{where}: cooldown_turns must be {expected_cd} for slot "
                f"'{record['slot']}' (engine derives cooldown from slot)."
            )
    return records


def load_moves() -> dict[str, dict]:
    """Return all move records keyed by id (deep copy, safe to mutate)."""
    return copy.deepcopy(_moves())


def build_move(move_id: str) -> Move:
    """Construct a fresh engine Move object from its data record."""
    records = _moves()
    if move_id not in records:
        raise DataValidationError(
            f"Unknown move id '{move_id}'. Known moves: {', '.join(records)}."
        )
    record = records[move_id]
    statuses = record.get("status_effects") or []
    first_status = statuses[0] if statuses else None
    return Move(
        name=record["name"],
        move_type=_MOVE_TYPES[record["move_type"]],
        slot=_MOVE_SLOTS[record["slot"]],
        power=record["power"],
        accuracy=float(record["accuracy"]),
        target_stat_mods=[(m["stat"], m["amount"]) for m in record.get("target_stat_mods", [])],
        self_stat_mods=[(m["stat"], m["amount"]) for m in record.get("self_stat_mods", [])],
        is_buff_move=bool(record.get("is_buff_move", False)),
        applies_status=first_status["status"] if first_status else None,
        status_duration=first_status["duration"] if first_status else 0,
    )


# ── Classes ──────────────────────────────────────────────────────────

_CLASS_REQUIRED = ("name", "description", "role", "base_stats", "move_ids")


@lru_cache(maxsize=1)
def _classes() -> dict[str, dict]:
    records = _load_records("classes.yaml", "classes", _CLASS_REQUIRED)
    moves = _moves()
    for class_id, record in records.items():
        where = f"classes.yaml class '{class_id}'"
        if class_id not in _CLASS_BY_ID:
            raise DataValidationError(
                f"{where}: id must match an engine class: {sorted(_CLASS_BY_ID)}."
            )
        stats = record["base_stats"]
        if not isinstance(stats, dict):
            raise DataValidationError(f"{where}: base_stats must be a mapping.")
        for key in STAT_KEYS:
            if not isinstance(stats.get(key), int) or stats[key] < 1:
                raise DataValidationError(
                    f"{where}: base_stats.{key} must be a positive integer."
                )
        move_ids = record["move_ids"]
        if not isinstance(move_ids, list) or len(move_ids) != 3:
            raise DataValidationError(f"{where}: move_ids must list exactly 3 moves.")
        unknown = [m for m in move_ids if m not in moves]
        if unknown:
            raise DataValidationError(
                f"{where}: unknown move id(s): {', '.join(unknown)}."
            )
        slots = sorted(moves[m]["slot"] for m in move_ids)
        if slots != ["basic", "gambit", "signature"]:
            raise DataValidationError(
                f"{where}: moves must cover exactly one basic, one signature "
                f"and one gambit slot; got {slots}."
            )
    if set(records) != set(_CLASS_BY_ID):
        missing = set(_CLASS_BY_ID) - set(records)
        raise DataValidationError(
            f"classes.yaml: missing definition(s) for: {', '.join(sorted(missing))}."
        )
    return records


def load_classes() -> dict[str, dict]:
    """Return all class records keyed by id (deep copy, safe to mutate)."""
    return copy.deepcopy(_classes())


# ── Unit factory ─────────────────────────────────────────────────────

def create_unit_from_data(class_id: str, name: Optional[str] = None) -> Unit:
    """Create a fresh Unit for `class_id` ('warrior', 'mage', ...)."""
    records = _classes()
    key = class_id.lower()
    if key not in records:
        raise DataValidationError(
            f"Unknown class id '{class_id}'. Known classes: {', '.join(records)}."
        )
    record = records[key]
    stats = record["base_stats"]
    return Unit(
        name=name or record["name"],
        class_name=_CLASS_BY_ID[key],
        base_hp=stats["hp"],
        base_atk=stats["atk"],
        base_def=stats["def"],
        base_mag=stats["mag"],
        base_res=stats["res"],
        base_spd=stats["spd"],
        hp=stats["hp"],
        moves=[build_move(move_id) for move_id in record["move_ids"]],
    )


# ── Legacy compatibility helpers (used by models.__getattr__) ────────

def legacy_class_stats() -> dict[ClassName, dict]:
    """models.CLASS_STATS shape: dict[ClassName] -> {hp, atk, def, ...}."""
    return {
        _CLASS_BY_ID[class_id]: dict(record["base_stats"])
        for class_id, record in _classes().items()
    }


def legacy_move_factories() -> dict[ClassName, Callable[[], list[Move]]]:
    """models.MOVE_FACTORIES shape: dict[ClassName] -> () -> list[Move]."""

    def factory_for(move_ids: list[str]) -> Callable[[], list[Move]]:
        return lambda: [build_move(move_id) for move_id in move_ids]

    return {
        _CLASS_BY_ID[class_id]: factory_for(record["move_ids"])
        for class_id, record in _classes().items()
    }


# ── RPG datasets (Crests, Entities, terrain, objectives, narrative) ──

_CREST_REQUIRED = (
    "name", "affinity", "rarity", "description", "compatible_classes",
    "passive_modifier", "awakening_condition", "awakening_effect", "visual_theme",
)
_ENTITY_REQUIRED = (
    "name", "category", "affinity", "rarity", "description",
    "compatible_classes", "passive_effect", "granted_move",
    "awakening_form", "awakening_effect", "visual_theme",
)
_TERRAIN_REQUIRED = ("name", "description", "move_cost", "passable")
_OBJECTIVE_REQUIRED = ("name", "description", "objective_type")
_CHARACTER_REQUIRED = ("name", "role", "description")
_LOCATION_REQUIRED = ("name", "region", "description")


def _validate_compatible_classes(filename: str, records: dict[str, dict]) -> None:
    for record_id, record in records.items():
        compatible = record.get("compatible_classes", [])
        if not isinstance(compatible, list) or not compatible:
            raise DataValidationError(
                f"{filename} record '{record_id}': compatible_classes must be "
                f"a non-empty list of class ids."
            )
        unknown = [c for c in compatible if c not in _CLASS_BY_ID]
        if unknown:
            raise DataValidationError(
                f"{filename} record '{record_id}': unknown class id(s): "
                f"{', '.join(unknown)}."
            )


# Canonical battle events a crest may gain Resonance from.
RESONANCE_EVENTS = (
    "hit_landed", "gambit_used", "gambit_hit", "magical_hit",
    "damage_taken", "braced", "ally_protected", "status_applied",
    "hit_debuffed_target", "hit_hexed_target", "low_hp_action", "varied_move",
)


@lru_cache(maxsize=1)
def _crests() -> dict[str, dict]:
    records = _load_records("crests.yaml", "crests", _CREST_REQUIRED)
    _validate_compatible_classes("crests.yaml", records)
    for crest_id, record in records.items():
        where = f"crests.yaml crest '{crest_id}'"
        gains = record.get("resonance_gain", {})
        if not isinstance(gains, dict) or not gains:
            raise DataValidationError(
                f"{where}: resonance_gain must map at least one battle event "
                f"to a gain amount."
            )
        for event, amount in gains.items():
            if event not in RESONANCE_EVENTS:
                raise DataValidationError(
                    f"{where}: unknown resonance event '{event}'. "
                    f"Known events: {', '.join(RESONANCE_EVENTS)}."
                )
            if not isinstance(amount, int) or not 0 < amount <= 100:
                raise DataValidationError(
                    f"{where}: resonance gain for '{event}' must be an "
                    f"integer in (0, 100]."
                )
        min_resonance = record.get("awakening_condition", {}).get("min_resonance", 0)
        if not isinstance(min_resonance, int) or not 0 <= min_resonance <= 100:
            raise DataValidationError(
                f"{where}: awakening_condition.min_resonance must be an "
                f"integer in [0, 100]."
            )
    return records


def load_crests() -> dict[str, dict]:
    """Return all Crest records keyed by id (deep copy, safe to mutate)."""
    return copy.deepcopy(_crests())


@lru_cache(maxsize=1)
def _entities() -> dict[str, dict]:
    records = _load_records("entities.yaml", "entities", _ENTITY_REQUIRED)
    _validate_compatible_classes("entities.yaml", records)
    return records


def load_entities() -> dict[str, dict]:
    """Return all Bonded Entity records keyed by id (deep copy)."""
    return copy.deepcopy(_entities())


@lru_cache(maxsize=1)
def _terrain() -> dict[str, dict]:
    records = _load_records("terrain.yaml", "terrain", _TERRAIN_REQUIRED)
    for terrain_id, record in records.items():
        if not isinstance(record["move_cost"], int) or record["move_cost"] < 1:
            raise DataValidationError(
                f"terrain.yaml '{terrain_id}': move_cost must be an integer >= 1."
            )
        if not isinstance(record["passable"], bool):
            raise DataValidationError(
                f"terrain.yaml '{terrain_id}': passable must be a boolean."
            )
    return records


def load_terrain() -> dict[str, dict]:
    """Return all terrain records keyed by id (deep copy)."""
    return copy.deepcopy(_terrain())


@lru_cache(maxsize=1)
def _battle_objectives() -> dict[str, dict]:
    return _load_records("battle_objectives.yaml", "battle_objectives", _OBJECTIVE_REQUIRED)


def load_battle_objectives() -> dict[str, dict]:
    """Return all battle objective records keyed by id (deep copy)."""
    return copy.deepcopy(_battle_objectives())


@lru_cache(maxsize=1)
def _characters() -> dict[str, dict]:
    return _load_records("characters.yaml", "characters", _CHARACTER_REQUIRED)


def load_characters() -> dict[str, dict]:
    """Return all narrative character records keyed by id (deep copy)."""
    return copy.deepcopy(_characters())


@lru_cache(maxsize=1)
def _locations() -> dict[str, dict]:
    return _load_records("locations.yaml", "locations", _LOCATION_REQUIRED)


def load_locations() -> dict[str, dict]:
    """Return all narrative location records keyed by id (deep copy)."""
    return copy.deepcopy(_locations())


_ENCOUNTER_REQUIRED = (
    "name", "location", "player_slots", "enemy_slots",
    "pre_battle_positioning", "objective", "enemy_party",
)
_POSITIONS = ("front", "back")


@lru_cache(maxsize=1)
def _encounters() -> dict[str, dict]:
    records = _load_records("encounters.yaml", "encounters", _ENCOUNTER_REQUIRED)
    classes = _classes()
    crests = _crests()
    entities = _entities()
    objectives = _battle_objectives()
    for encounter_id, record in records.items():
        where = f"encounters.yaml encounter '{encounter_id}'"
        for key in ("player_slots", "enemy_slots"):
            if not isinstance(record[key], int) or not 1 <= record[key] <= 3:
                raise DataValidationError(f"{where}: {key} must be an integer 1-3.")
        if record["objective"] not in objectives:
            raise DataValidationError(
                f"{where}: unknown objective '{record['objective']}'. "
                f"Known: {', '.join(objectives)}."
            )
        party = record["enemy_party"]
        if not isinstance(party, list) or len(party) != record["enemy_slots"]:
            raise DataValidationError(
                f"{where}: enemy_party must list exactly enemy_slots "
                f"({record['enemy_slots']}) builds."
            )
        for build in party:
            if build.get("class_id") not in classes:
                raise DataValidationError(
                    f"{where}: enemy build has unknown class "
                    f"'{build.get('class_id')}'."
                )
            crest_id = build.get("crest_id", "")
            if crest_id and crest_id not in crests:
                raise DataValidationError(
                    f"{where}: enemy build has unknown crest '{crest_id}'."
                )
            entity_id = build.get("entity_id", "")
            if entity_id and entity_id not in entities:
                raise DataValidationError(
                    f"{where}: enemy build has unknown entity '{entity_id}'."
                )
            if build.get("position", "front") not in _POSITIONS:
                raise DataValidationError(
                    f"{where}: enemy build position must be one of {_POSITIONS}."
                )
    return records


def load_encounters() -> dict[str, dict]:
    """Return all encounter records keyed by id (deep copy)."""
    return copy.deepcopy(_encounters())


def clear_caches() -> None:
    """Drop all cached data (useful in tests that write temp data)."""
    for cached in (
        _load_records, _combat_config, _moves, _classes,
        _crests, _entities, _terrain, _battle_objectives,
        _characters, _locations,
    ):
        cached.cache_clear()
