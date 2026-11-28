"""
Crestbound Duelists — party battle engine (Combat System 3.0).

The Python reference implementation of the game's battle rules: variable
party sizes (1v1 through 3v3, asymmetric, protect battles), front/back
rows, Brace, Hex, Crest passives, Resonance with a deliberate Awaken
command, all six awakenings, Bonded Entity passives and granted moves,
attack properties and affinities, telegraphed attacks, phased bosses,
battle objectives, items and enemy behaviour profiles.

It mirrors the Godot battle runtime (game/scripts/battle/) rule for rule
and step for step. Every random draw goes through a `Dice` stream, in the
same order in both runtimes, so a recorded stream replays the exact same
battle in Godot (tools/generate_combat_parity.py writes those replays;
game/scripts/tools/combat_parity_smoke.gd checks them).

The classic 1v1 duel model in combat.py stays separate: it powers the
committed recruiter analytics and is not affected by this module.

All values come from data/*.yaml through loaders.py. Nothing here is a
balance constant.
"""

from __future__ import annotations

import copy
import math
import random
from collections.abc import Callable
from dataclasses import dataclass, field
from typing import Any

import loaders

DICE_SCALE = 1 << 24          # dice draws are integers in [0, 2^24)
STAT_NAMES = ("hp", "atk", "def", "mag", "res", "spd")
MOD_STATS = ("atk", "def", "mag", "res", "spd")
PRIORITY_KINDS = ("brace", "item", "awaken")


# ── Data ─────────────────────────────────────────────────────────────

@dataclass
class GameData:
    """Exported game data, shaped exactly like game/data/*.json."""

    classes: dict
    moves: dict
    crests: dict
    entities: dict
    config: dict
    objectives: dict
    items: dict = field(default_factory=dict)
    equipment: dict = field(default_factory=dict)

    @classmethod
    def load(cls) -> GameData:
        return cls(
            classes=loaders.load_classes(),
            moves=loaders.load_moves(),
            crests=loaders.load_crests(),
            entities=loaders.load_entities(),
            config=loaders.load_combat_config(),
            objectives=loaders.load_battle_objectives(),
            items=loaders.load_items(),
            equipment=loaders.load_equipment(),
        )

    def cfg(self, key: str) -> Any:
        return self.config[key]

    def status_kind(self, status: str) -> str:
        return str(self.config.get("statuses", {}).get(status, {}).get("kind", "control"))


# ── Dice ─────────────────────────────────────────────────────────────

class Dice:
    """The battle's only source of randomness.

    Draws are integers in [0, 2^24), turned into floats in [0, 1), so a
    recorded stream survives JSON exactly. Either seeded (live play and
    simulation) or replaying a recorded stream (parity tests).
    """

    def __init__(self, seed: int | None = None, stream: list[int] | None = None):
        self._rng = random.Random(seed)
        self._stream = list(stream) if stream is not None else None
        self._cursor = 0
        self.record: list[int] = []

    def draw(self) -> int:
        if self._stream is not None:
            if self._cursor >= len(self._stream):
                raise IndexError("dice stream exhausted")
            value = self._stream[self._cursor]
            self._cursor += 1
        else:
            value = self._rng.randrange(DICE_SCALE)
        self.record.append(value)
        return value

    def roll(self) -> float:
        return self.draw() / DICE_SCALE

    def pick(self, count: int) -> int:
        return min(count - 1, int(self.roll() * count))


# ── Units ────────────────────────────────────────────────────────────

@dataclass
class Unit:
    display_name: str
    team: str
    slot_index: int
    class_id: str
    position: str
    tags: list
    base_stats: dict
    moves: list
    crest: dict
    entity: dict
    equipment: dict
    affinity: dict
    ai_profile: str
    phases: list
    sprite_key: str = ""
    max_hp: int = 1
    hp: int = 1
    cooldowns: dict = field(default_factory=dict)
    stat_mods: list = field(default_factory=list)
    statuses: list = field(default_factory=list)
    braced_rounds: int = 0
    resonance: int = 0
    awakened: bool = False
    awakening_rounds_left: int = 0
    awakening_announced: bool = False
    bloom_index: int = 0
    hits_taken: int = 0
    statuses_applied: int = 0
    debuffs_applied: int = 0
    gambits_landed: int = 0
    used_move_ids: list = field(default_factory=list)
    last_move_id: str = ""
    hit_this_round: bool = False
    staggered: bool = False
    braced_this_round: bool = False
    brace_streak: int = 0
    pending: dict | None = None       # telegraph: {move, target, due_round, delayed}
    phase_index: int = 0
    rotation: list = field(default_factory=list)
    rotation_index: int = 0
    forced_move: str = ""
    surge_expose_ready: bool = False
    brace_pierce_left: int = 0

    # ── reference ───────────────────────────────────────────────
    @property
    def ref(self) -> str:
        return ("p" if self.team == "player" else "e") + str(self.slot_index)

    # ── stats ───────────────────────────────────────────────────
    def base_stat(self, name: str) -> int:
        return int(self.base_stats.get(name, 1))

    def stat(self, name: str) -> int:
        total = self.base_stat(name)
        for mod in self.stat_mods:
            if mod["stat"] == name:
                total += mod["amount"]
        effect = self.awakening_effect()
        if self.awakening_effect_active("counter_stance") and name in ("def", "res"):
            total += int(effect.get("defense_bonus", 0))
        if self.awakening_effect_active("overgrowth"):
            cycle = effect.get("stat_bloom", {}).get("cycle", list(MOD_STATS))
            if cycle and cycle[self.bloom_index % len(cycle)] == name:
                total += int(effect.get("stat_bloom", {}).get("amount", 0))
        for bonus in _equipment_effects(self, "stat_bonus"):
            if bonus.get("stat") == name:
                total += int(bonus.get("amount", 0))
        return max(1, total)

    def is_alive(self) -> bool:
        return self.hp > 0

    def is_braced(self) -> bool:
        return self.braced_rounds > 0

    def hp_ratio(self) -> float:
        return float(self.hp) / self.max_hp

    def has_status(self, name: str) -> bool:
        return any(s["name"] == name for s in self.statuses)

    def has_debuff(self) -> bool:
        return any(m["amount"] < 0 for m in self.stat_mods)

    # ── moves ───────────────────────────────────────────────────
    @staticmethod
    def move_id_of(move: dict) -> str:
        return move.get("id", move.get("name", ""))

    def cooldown_of(self, move: dict) -> int:
        return int(self.cooldowns.get(self.move_id_of(move), 0))

    def is_move_blocked_by_hex(self, move: dict) -> bool:
        return bool(move.get("is_buff_move", False)) and self.has_status("hexed")

    def is_move_available(self, move: dict) -> bool:
        return self.cooldown_of(move) <= 0 and not self.is_move_blocked_by_hex(move)

    def note_move_used(self, move: dict) -> None:
        move_id = self.move_id_of(move)
        self.last_move_id = move_id
        if move_id not in self.used_move_ids:
            self.used_move_ids.append(move_id)
        cooldown = int(move.get("cooldown_turns", 0))
        if cooldown > 0:
            self.cooldowns[move_id] = cooldown + 1

    # ── effects ─────────────────────────────────────────────────
    def apply_stat_mod(self, name: str, amount: int, duration: int) -> None:
        if amount == 0:
            return
        for mod in self.stat_mods:
            same_direction = (mod["amount"] > 0) == (amount > 0)
            if mod["stat"] == name and same_direction:
                if abs(amount) > abs(mod["amount"]):
                    mod["amount"] = amount
                mod["turns"] = max(mod["turns"], duration)
                return
        self.stat_mods.append({"stat": name, "amount": amount, "turns": duration})

    def apply_status(self, name: str, duration: int, value: int = 0) -> None:
        for status in self.statuses:
            if status["name"] == name:
                status["turns"] = max(status["turns"], duration)
                status["value"] = max(status.get("value", 0), value)
                return
        self.statuses.append({"name": name, "turns": duration, "value": value})

    def remove_statuses(self, names: list) -> list:
        removed = [s["name"] for s in self.statuses if s["name"] in names]
        self.statuses = [s for s in self.statuses if s["name"] not in names]
        return removed

    def take_damage(self, amount: int) -> None:
        self.hp = max(0, self.hp - amount)
        self.hits_taken += 1
        self.hit_this_round = True

    def lose_hp(self, amount: int) -> None:
        """Damage over time and recoil: not a hit."""
        self.hp = max(0, self.hp - amount)

    def heal(self, amount: int) -> None:
        self.hp = min(self.max_hp, self.hp + amount)

    def brace(self, extra_rounds: int = 0) -> None:
        self.braced_rounds = 1 + extra_rounds
        self.braced_this_round = True

    def on_round_end(self) -> None:
        for move_id in list(self.cooldowns):
            self.cooldowns[move_id] = max(0, int(self.cooldowns[move_id]) - 1)
        for mod in self.stat_mods:
            mod["turns"] -= 1
        self.stat_mods = [m for m in self.stat_mods if m["turns"] > 0]
        for status in self.statuses:
            status["turns"] -= 1
        self.statuses = [s for s in self.statuses if s["turns"] > 0]
        if self.braced_rounds > 0:
            self.braced_rounds -= 1
        if self.awakening_rounds_left > 0:
            self.awakening_rounds_left -= 1
            if self.awakening_effect().get("type") == "overgrowth":
                self.bloom_index += 1
        self.brace_streak = self.brace_streak + 1 if self.braced_this_round else 0
        self.braced_this_round = False
        self.hit_this_round = False
        self.staggered = False

    # ── crest ───────────────────────────────────────────────────
    def passive(self) -> dict:
        return self.crest.get("passive_modifier", {}) or {}

    def awakening_effect(self) -> dict:
        return self.crest.get("awakening_effect", {}) or {}

    def damage_dealt_multiplier(self, target: Unit | None) -> float:
        multiplier = 1.0
        passive = self.passive()
        kind = passive.get("type", "")
        if kind == "low_hp_damage_bonus":
            if self.hp_ratio() < float(passive.get("threshold", 0.5)):
                multiplier += float(passive.get("amount", 0.0))
        elif kind == "bonus_vs_debuffed":
            if target is not None and target.has_debuff():
                multiplier += float(passive.get("amount", 0.0))
        elif kind == "glass_edge":
            multiplier += float(passive.get("damage_dealt_bonus", 0.0))
        return multiplier

    def damage_taken_multiplier(self) -> float:
        multiplier = 1.0
        if self.passive().get("type", "") == "glass_edge":
            multiplier += float(self.passive().get("damage_taken_penalty", 0.0))
        return multiplier

    def brace_multiplier_bonus(self) -> float:
        if self.passive().get("type", "") == "brace_bonus":
            return float(self.passive().get("brace_multiplier_bonus", 0.0))
        return 0.0

    def status_duration_bonus(self) -> int:
        if self.passive().get("type", "") == "status_duration_bonus":
            return int(self.passive().get("extra_turns", 0))
        return 0

    def entity_passive(self) -> dict:
        return self.entity.get("passive_effect", {}) or {}

    def entity_passive_type(self) -> str:
        return str(self.entity_passive().get("type", ""))

    def initiative_bonus(self) -> int:
        bonus = 0
        if self.awakening_effect_active("overgrowth"):
            bonus += int(self.awakening_effect().get("initiative_bonus", 0))
        for effect in _equipment_effects(self, "initiative_bonus"):
            bonus += int(effect.get("amount", 0))
        return bonus

    def awakening_condition_met(self) -> bool:
        condition = self.crest.get("awakening_condition", {}) or {}
        kind = condition.get("type", "")
        count = int(condition.get("count", 999))
        if kind == "hp_below":
            return self.hp_ratio() < float(condition.get("threshold", 0.0))
        if kind == "hits_taken":
            return self.hits_taken >= count
        if kind == "statuses_applied":
            return self.statuses_applied >= count
        if kind == "debuffs_applied":
            return self.debuffs_applied >= count
        if kind == "gambits_landed":
            return self.gambits_landed >= count
        if kind == "unique_moves_used":
            return len(self.used_move_ids) >= count
        return kind == "none"

    def awakening_ready(self) -> bool:
        if self.awakened or not self.crest or not self.is_alive():
            return False
        condition = self.crest.get("awakening_condition", {}) or {}
        if self.resonance < int(condition.get("min_resonance", 0)):
            return False
        return self.awakening_condition_met()

    def awaken(self) -> None:
        self.awakened = True
        self.awakening_rounds_left = int(self.awakening_effect().get("duration", 0))
        self.bloom_index = 0
        if self.awakening_effect().get("type") == "resonance_surge":
            self.surge_expose_ready = True

    def awakening_effect_active(self, effect_type: str) -> bool:
        if not self.awakened or self.awakening_rounds_left <= 0:
            return False
        return self.awakening_effect().get("type", "") == effect_type

    def add_resonance_amount(self, amount: int) -> int:
        if not self.crest or self.awakened or amount <= 0:
            return 0
        before = self.resonance
        self.resonance = max(0, min(100, self.resonance + amount))
        return self.resonance - before


def _equipment_effects(unit: Unit, effect_type: str) -> list:
    return [e for e in unit.equipment.get("effects", []) if e.get("type") == effect_type]


def create_unit(build: dict, team: str, slot_index: int, data: GameData) -> Unit:
    """A battle unit from a build: {name, class_id, crest_id, entity_id,
    position, move_ids?, stats?, stat_scale?, affinity?, ai_profile?,
    phases?, tags?, equipment?, current_hp?, sprite_key?}."""
    class_id = str(build.get("class_id", "") or "")
    class_record = data.classes.get(class_id, {})
    base = dict(build.get("stats") or class_record.get("base_stats", {}))
    for stat_name, scale in (build.get("stat_scale") or {}).items():
        base[stat_name] = max(1, math.floor(base[stat_name] * scale))
    crest = data.crests.get(str(build.get("crest_id", "") or ""), {})
    entity = data.entities.get(str(build.get("entity_id", "") or ""), {})
    equipment = data.equipment.get(str(build.get("equipment", "") or ""), {})
    move_ids = list(build.get("move_ids") or class_record.get("move_ids", []))
    if not build.get("move_ids") and entity.get("granted_move") in data.moves:
        move_ids.append(entity["granted_move"])
    affinity = copy.deepcopy(build.get("affinity") or crest.get("affinity_profile") or {"weak": [], "resist": []})
    for effect in [e for e in equipment.get("effects", []) if e.get("type") == "affinity"]:
        for key in ("weak", "resist"):
            for prop in effect.get("add_" + key, []):
                if prop not in affinity.setdefault(key, []):
                    affinity[key].append(prop)
            affinity[key] = [p for p in affinity.get(key, []) if p not in effect.get("remove_" + key, [])]
    unit = Unit(
        display_name=str(build.get("name", "Duelist")),
        team=team,
        slot_index=slot_index,
        class_id=class_id,
        position=str(build.get("position", "front")),
        tags=list(build.get("tags", [])),
        base_stats=base,
        moves=[copy.deepcopy(data.moves[m]) for m in move_ids],
        crest=crest,
        entity=entity,
        equipment=equipment,
        affinity=affinity,
        ai_profile=str(build.get("ai_profile", "legacy")),
        phases=copy.deepcopy(build.get("phases", [])),
        sprite_key=str(build.get("sprite_key", "")),
    )
    unit.max_hp = int(base.get("hp", 1))
    current = build.get("current_hp")
    unit.hp = max(1, min(unit.max_hp, int(current))) if (team == "player" and current is not None) else unit.max_hp
    for effect in _equipment_effects(unit, "brace_pierce"):
        unit.brace_pierce_left += int(effect.get("charges", 1))
    if unit.phases:
        _enter_phase(unit, 0, data, [])
    return unit


def _enter_phase(unit: Unit, index: int, data: GameData, events: list) -> None:
    phase = unit.phases[index]
    unit.phase_index = index
    if phase.get("move_ids"):
        unit.moves = [copy.deepcopy(data.moves[m]) for m in phase["move_ids"]]
    if phase.get("ai_profile"):
        unit.ai_profile = phase["ai_profile"]
    if phase.get("affinity") is not None:
        unit.affinity = copy.deepcopy(phase["affinity"])
    unit.rotation = copy.deepcopy(phase.get("rotation", []))
    unit.rotation_index = 0
    unit.forced_move = str(phase.get("entry_move", ""))
    for status in phase.get("entry_statuses", []):
        unit.apply_status(status["status"], int(status.get("duration", 1)) + 1)
    if index > 0:
        events.append({"type": "phase", "unit": unit, "name": phase.get("name", ""), "banner": phase.get("banner", "")})


# ── Battle ───────────────────────────────────────────────────────────

class Battle:
    """One encounter. Mirrors EncounterRuntime + BattleResolver in Godot."""

    def __init__(
        self,
        encounter: dict,
        player_builds: list,
        data: GameData,
        dice: Dice,
        inventory: dict | None = None,
    ):
        self.encounter = encounter
        self.data = data
        self.dice = dice
        self.inventory = dict(inventory or {})
        self.round_number = 1
        self.player_units = [create_unit(b, "player", i, data) for i, b in enumerate(player_builds)]
        self.enemy_units = [create_unit(b, "enemy", i, data) for i, b in enumerate(encounter.get("enemy_party", []))]
        objective = data.objectives.get(encounter.get("objective", "defeat_all"), {})
        self.objective_type = str(objective.get("objective_type", "eliminate"))
        self.objective_params = dict(objective.get("params", {}))
        self.objective_params.update(encounter.get("objective_params", {}) or {})

    # ── queries ─────────────────────────────────────────────────
    def all_units(self) -> list:
        return self.player_units + self.enemy_units

    def living(self, team: str) -> list:
        units = self.player_units if team == "player" else self.enemy_units
        return [u for u in units if u.is_alive()]

    @staticmethod
    def opposing(team: str) -> str:
        return "enemy" if team == "player" else "player"

    def battlefield_effect(self) -> dict:
        effect = self.encounter.get("battlefield_effect", {})
        return effect if isinstance(effect, dict) else {}

    def resonance_multiplier(self) -> float:
        effect = self.battlefield_effect()
        if effect.get("type", "") == "resonance_surge" and self.round_number > int(effect.get("after_round", 999)):
            return float(effect.get("multiplier", 1.0))
        return 1.0

    def stat_mod_duration(self, base_duration: int) -> int:
        effect = self.battlefield_effect()
        if effect.get("type", "") == "modifier_decay":
            return max(1, base_duration - int(effect.get("decay_penalty", 0)))
        return base_duration

    def has_battlefield_tag(self, tag: str) -> bool:
        return tag in self.battlefield_effect().get("tags", [])

    def rounds_completed(self) -> int:
        return self.round_number - 1

    def outcome(self) -> str:
        """'' while the battle continues, else 'victory' or 'defeat'."""
        tag = str(self.objective_params.get("unit_tag", "protected"))
        protected = [u for u in self.player_units if "protected" in u.tags or (self.objective_type == "protect" and tag in u.tags)]
        if any(not u.is_alive() for u in protected):
            return "defeat"
        fighters = [u for u in self.living("player") if "protected" not in u.tags]
        enemies = self.living("enemy")
        if not enemies:
            return "victory"
        if self.objective_type == "defeat_target":
            targets = [u for u in self.enemy_units if str(self.objective_params.get("unit_tag", "target")) in u.tags]
            if targets and all(not u.is_alive() for u in targets):
                return "victory"
        if self.objective_type == "survive" and self.rounds_completed() >= int(self.objective_params.get("turns_required", 1)):
            return "victory"
        if not fighters:
            return "defeat"
        return ""

    def objective_progress(self) -> str:
        if self.objective_type == "survive":
            needed = int(self.objective_params.get("turns_required", 1))
            return f"{min(self.rounds_completed(), needed)}/{needed}"
        return ""

    # ── damage ──────────────────────────────────────────────────
    def resolve_move_type(self, move: dict, attacker: Unit, defender: Unit) -> str:
        move_type = move.get("move_type", "physical")
        if move_type != "adaptive":
            return move_type
        phys = 2.0 * attacker.stat("atk") / max(1.0, attacker.stat("atk") + self.defence_value(defender, "def"))
        mag = 2.0 * attacker.stat("mag") / max(1.0, attacker.stat("mag") + self.defence_value(defender, "res"))
        return "physical" if phys >= mag else "magical"

    def defence_value(self, defender: Unit, stat_name: str, ignore_brace: bool = False) -> float:
        value = float(defender.stat(stat_name))
        if defender.is_braced() and not ignore_brace:
            multiplier = float(self.data.cfg("brace_multiplier")) + defender.brace_multiplier_bonus()
            value = math.floor(value * multiplier)
        return value

    @staticmethod
    def move_breaks_brace(move: dict) -> bool:
        tags = move.get("tags", [])
        return "guard_break" in tags or "resistance_break" in tags

    def pierces_brace(self, attacker: Unit, defender: Unit, move: dict) -> bool:
        """Greymaw Fang-style charms: an Edge hit ignores Brace a limited
        number of times per battle."""
        return (
            attacker.brace_pierce_left > 0 and defender.is_braced()
            and move.get("property", "") == "edge"
        )

    def affinity_of(self, defender: Unit, move: dict) -> str:
        """'weak', 'resist' or '' for this move against this defender."""
        prop = move.get("property", "")
        if not prop:
            return ""
        if defender.has_status("exposed") or prop in defender.affinity.get("weak", []):
            return "weak"
        if prop in defender.affinity.get("resist", []):
            return "resist"
        return ""

    def damage_multipliers(self, attacker: Unit, defender: Unit, move: dict, previous_move_id: str) -> float:
        multiplier = attacker.damage_dealt_multiplier(defender) * defender.damage_taken_multiplier()
        passive = attacker.passive()
        if passive.get("type", "") == "variety_bonus":
            move_id = Unit.move_id_of(move)
            if previous_move_id != "" and previous_move_id != move_id:
                multiplier += float(passive.get("amount", 0.0))
        effect = attacker.awakening_effect()
        if move.get("slot", "") == "gambit" and attacker.awakening_effect_active("empowered_gambit"):
            multiplier += float(effect.get("power_bonus", 0.0))
        if attacker.awakening_effect_active("perfect_edge"):
            multiplier += float(effect.get("power_bonus", 0.0))
        if attacker.awakening_effect_active("resonance_surge"):
            multiplier += float(effect.get("power_bonus", 0.0))
        if int(move.get("range", 1)) <= int(self.data.cfg("melee_range")):
            if attacker.position == "back":
                multiplier *= float(self.data.cfg("back_row_melee_multiplier"))
            if defender.position == "back":
                multiplier *= float(self.data.cfg("back_row_melee_multiplier"))
        if attacker.entity_passive_type() == "terrain_damage_bonus":
            for tag in attacker.entity_passive().get("terrain_tags", []):
                if self.has_battlefield_tag(tag):
                    multiplier += float(attacker.entity_passive().get("amount", 0.0))
                    break
        if attacker.entity_passive_type() == "flanking_bonus" and defender.hit_this_round:
            multiplier += float(attacker.entity_passive().get("amount", 0.0))
        for bonus in _equipment_effects(attacker, "property_bonus"):
            if move.get("property", "") == bonus.get("property"):
                multiplier += float(bonus.get("amount", 0.0))
        affinity = self.affinity_of(defender, move)
        if affinity == "weak":
            multiplier *= float(self.data.cfg("weakness_multiplier"))
        elif affinity == "resist":
            multiplier *= float(self.data.cfg("resist_multiplier"))
        if attacker.has_status("hexed"):
            for unit in self.living(defender.team):
                if unit.entity_passive_type() == "hex_amplifier":
                    multiplier *= 1.0 - float(unit.entity_passive().get("amount", 0.0))
                    break
        return multiplier

    def damage_base(self, attacker: Unit, defender: Unit, move: dict, previous_move_id: str = "", release: bool = False) -> float:
        resolved = self.resolve_move_type(move, attacker, defender)
        atk = float(attacker.stat("atk" if resolved == "physical" else "mag"))
        ignore = self.move_breaks_brace(move) or self.pierces_brace(attacker, defender, move)
        def_value = self.defence_value(defender, "def" if resolved == "physical" else "res", ignore)
        ratio = 2.0 * atk / max(1.0, atk + def_value)
        base = float(move.get("power", 0)) * ratio * self.damage_multipliers(attacker, defender, move, previous_move_id)
        if release and defender.is_braced():
            base *= float(self.data.cfg("telegraph_brace_multiplier"))
        return base

    def damage_range(self, attacker: Unit, defender: Unit, move: dict, previous_move_id: str = "") -> tuple:
        base = self.damage_base(attacker, defender, move, previous_move_id)
        low = max(1, math.floor(base * float(self.data.cfg("variance_low"))))
        high = max(1, math.floor(base * float(self.data.cfg("variance_high"))))
        return (low, high)

    def roll_damage(self, base: float) -> int:
        low = float(self.data.cfg("variance_low"))
        high = float(self.data.cfg("variance_high"))
        return max(1, math.floor(base * (low + (high - low) * self.dice.roll())))

    def accuracy_of(self, attacker: Unit, move: dict) -> float:
        accuracy = float(move.get("accuracy", 1.0))
        if attacker.awakening_effect_active("perfect_edge"):
            accuracy = max(accuracy, float(attacker.awakening_effect().get("accuracy_override", 1.0)))
        return accuracy

    # ── initiative ──────────────────────────────────────────────
    def initiative_mod(self, action: dict) -> float:
        actor: Unit = action["actor"]
        bonus = float(actor.initiative_bonus())
        if action["kind"] == "move":
            bonus += float(action["move"].get("speed", 0))
        return bonus

    def order_actions(self, actions: list) -> list:
        band = float(self.data.cfg("speed_band"))
        priority = float(self.data.cfg("priority_bonus"))
        scored = []
        for index, action in enumerate(actions):
            actor: Unit = action["actor"]
            score = float(actor.stat("spd")) + self.initiative_mod(action) + self.dice.roll() * band
            if action["kind"] in PRIORITY_KINDS:
                score += priority
            scored.append((score, index, action))
        scored.sort(key=lambda entry: (-entry[0], entry[1]))
        return [entry[2] for entry in scored]

    def projected_order(self) -> list:
        living = [u for u in self.all_units() if u.is_alive()]
        indexed = list(enumerate(living))
        indexed.sort(key=lambda pair: (-float(pair[1].stat("spd") + pair[1].initiative_bonus()), pair[0]))
        return [u for _, u in indexed]

    # ── enemy decisions ─────────────────────────────────────────
    def plan_enemy_actions(self) -> list:
        return [choose_action(unit, self) for unit in self.living("enemy")]

    # ── execution ───────────────────────────────────────────────
    def execute(self, action: dict) -> list:
        actor: Unit = action["actor"]
        if not actor.is_alive():
            return []
        kind = action["kind"]
        if kind == "brace":
            events = self._execute_brace(actor)
        elif kind == "item":
            events = self._execute_item(actor, action)
        elif kind == "awaken":
            events = self._execute_awaken(actor)
        elif kind == "hold":
            events = [{"type": "action_start", "actor": actor, "label": "…"}, {"type": "hold", "actor": actor}]
        elif kind == "windup":
            events = self._execute_windup(actor, action)
        else:
            events = self._execute_move(actor, action)
        self._process_crest_events(events)
        self._check_phases(events)
        return events

    def _execute_brace(self, actor: Unit) -> list:
        extra = 0
        if actor.entity_passive_type() == "brace_extension":
            extra = int(actor.entity_passive().get("extra_turns", 1))
        actor.brace(extra)
        return [
            {"type": "action_start", "actor": actor, "label": "Brace"},
            {"type": "brace", "actor": actor},
            {"type": "crest", "unit": actor, "event": "braced"},
        ]

    def _execute_awaken(self, actor: Unit) -> list:
        if not actor.awakening_ready():
            return [{"type": "action_start", "actor": actor, "label": "Awaken"}, {"type": "fizzle", "actor": actor}]
        actor.awaken()
        return [
            {"type": "action_start", "actor": actor, "label": "Awaken"},
            {"type": "awaken", "actor": actor, "effect": actor.awakening_effect().get("type", "")},
        ]

    def _execute_item(self, actor: Unit, action: dict) -> list:
        item_id = action.get("item_id", "")
        item = self.data.items.get(item_id, {})
        target: Unit = action.get("target") or actor
        events = [{"type": "action_start", "actor": actor, "target": target, "label": item.get("name", "Item")}]
        if int(self.inventory.get(item_id, 0)) <= 0 or not item:
            events.append({"type": "fizzle", "actor": actor})
            return events
        effect = item.get("battle_effect", {})
        kind = effect.get("type", "")
        if kind == "revive":
            if target.is_alive():
                events.append({"type": "fizzle", "actor": actor})
                return events
            target.hp = max(1, math.floor(target.max_hp * float(effect.get("ratio", 0.3))))
            events.append({"type": "revive", "target": target, "amount": target.hp})
        elif not target.is_alive():
            events.append({"type": "fizzle", "actor": actor})
            return events
        elif kind == "heal":
            before = target.hp
            target.heal(int(effect.get("amount", 0)))
            events.append({"type": "heal", "target": target, "amount": target.hp - before})
        elif kind == "cure":
            removed = target.remove_statuses(list(effect.get("statuses", [])))
            events.append({"type": "cure", "target": target, "statuses": removed})
        elif kind == "resonance":
            gained = target.add_resonance_amount(int(effect.get("amount", 0)))
            events.append({"type": "resonance", "unit": target, "amount": gained, "source": "item"})
        self.inventory[item_id] = int(self.inventory[item_id]) - 1
        events.append({"type": "item_used", "actor": actor, "item_id": item_id})
        return events

    def _execute_windup(self, actor: Unit, action: dict) -> list:
        move = action["move"]
        target: Unit = action.get("target")
        actor.pending = {"move": move, "target": target, "due_round": self.round_number + 1, "delayed": False}
        return [
            {"type": "action_start", "actor": actor, "target": target, "label": move.get("name", "?")},
            {"type": "windup", "actor": actor, "target": target, "move_name": move.get("name", "?")},
        ]

    def _targets_for(self, actor: Unit, action: dict, events: list) -> list:
        move = action["move"]
        rule = move.get("target_rule", "enemy")
        if rule == "self":
            return [actor]
        if rule == "all_enemies":
            return self.living(self.opposing(actor.team))
        target: Unit | None = action.get("target")
        if target is None or not target.is_alive():
            pool = self.living(self.opposing(actor.team))
            if not pool:
                return []
            target = pool[self.dice.pick(len(pool))]
            events.append({"type": "retarget", "actor": actor, "target": target})
        return [target]

    def _execute_move(self, actor: Unit, action: dict) -> list:
        move = action["move"]
        events: list = []
        previous_move_id = actor.last_move_id
        release = bool(action.get("release", False))
        if release:
            if actor.pending is not None and actor.pending["due_round"] > self.round_number:
                # Staggered while winding up: the attack falters this round.
                return [{"type": "action_start", "actor": actor, "label": move.get("name", "?")},
                        {"type": "falter", "actor": actor}]
            actor.pending = None

        if actor.is_move_blocked_by_hex(move):
            actor.note_move_used(move)
            events.append({"type": "blocked", "actor": actor, "move_name": move.get("name", "?"), "reason": "Hex"})
            return events

        targets = self._targets_for(actor, action, events)
        if not targets:
            return events

        actor.note_move_used(move)
        events.append({"type": "action_start", "actor": actor, "target": targets[0], "label": move.get("name", "?")})
        if actor.hp_ratio() < float(self.data.cfg("low_hp_threshold")):
            events.append({"type": "crest", "unit": actor, "event": "low_hp_action"})
        if previous_move_id != "" and previous_move_id != Unit.move_id_of(move):
            events.append({"type": "crest", "unit": actor, "event": "varied_move"})
        if move.get("slot", "") == "gambit":
            events.append({"type": "crest", "unit": actor, "event": "gambit_used"})
        if int(move.get("resonance_bonus", 0)) > 0:
            events.append({"type": "resonance", "unit": actor, "amount": actor.add_resonance_amount(int(move["resonance_bonus"])), "source": "move"})

        if self.dice.roll() >= self.accuracy_of(actor, move):
            events.append({"type": "miss", "actor": actor, "target": targets[0], "move_name": move.get("name", "?")})
            self._aftermath(actor, move, events)
            return events

        single = move.get("target_rule", "enemy") not in ("self", "all_enemies")
        decay = self.stat_mod_duration(int(self.data.cfg("stat_decay_duration"))) + 1
        for target in targets:
            if not target.is_alive():
                continue
            if single:
                target = self._apply_interception(actor, target, events)
            if int(move.get("power", 0)) > 0 and target.team != actor.team:
                self._land_hit(actor, target, move, previous_move_id, release, events)
            for mod in move.get("target_stat_mods", []):
                if target is actor:
                    break
                if int(mod["amount"]) > 0 and target.has_status("hexed"):
                    continue
                target.apply_stat_mod(mod["stat"], int(mod["amount"]), decay)
                if int(mod["amount"]) < 0:
                    actor.debuffs_applied += 1
                events.append({"type": "stat_mod", "target": target, "stat": mod["stat"], "amount": int(mod["amount"])})
            if move.get("dispel_buffs", False) and target.team != actor.team:
                removed = [m for m in target.stat_mods if m["amount"] > 0]
                target.stat_mods = [m for m in target.stat_mods if m["amount"] <= 0]
                if removed:
                    events.append({"type": "dispel", "target": target, "count": len(removed)})
            for effect in move.get("status_effects", []):
                if effect.get("target", "enemy") != "enemy" or target.team == actor.team:
                    continue
                self._apply_status(actor, target, effect, events)

        for mod in move.get("self_stat_mods", []):
            if int(mod["amount"]) > 0 and actor.has_status("hexed"):
                continue
            actor.apply_stat_mod(mod["stat"], int(mod["amount"]), decay)
            events.append({"type": "stat_mod", "target": actor, "stat": mod["stat"], "amount": int(mod["amount"])})
            if int(mod["amount"]) > 0:
                self._mirror_buff(actor, mod["stat"], int(mod["amount"]), decay, events)
        for effect in move.get("status_effects", []):
            if effect.get("target", "enemy") == "self":
                self._apply_status(actor, actor, effect, events)
        self._aftermath(actor, move, events)
        return events

    def _land_hit(self, actor: Unit, target: Unit, move: dict, previous_move_id: str, release: bool, events: list) -> None:
        was_debuffed = target.has_debuff()
        affinity = self.affinity_of(target, move)
        pierced = self.pierces_brace(actor, target, move) and not self.move_breaks_brace(move)
        was_braced = target.is_braced()
        base = self.damage_base(actor, target, move, previous_move_id, release)
        damage = self.roll_damage(base)
        target.take_damage(damage)
        if pierced:
            actor.brace_pierce_left -= 1
        events.append({
            "type": "damage", "actor": actor, "target": target, "amount": damage,
            "move_name": move.get("name", "?"), "ko": not target.is_alive(),
            "affinity": affinity, "pierced": pierced,
        })
        events.append({"type": "crest", "unit": actor, "event": "hit_landed"})
        events.append({"type": "crest", "unit": target, "event": "damage_taken"})
        if move.get("slot", "") == "gambit":
            actor.gambits_landed += 1
            events.append({"type": "crest", "unit": actor, "event": "gambit_hit"})
        if self.resolve_move_type(move, actor, target) == "magical":
            events.append({"type": "crest", "unit": actor, "event": "magical_hit"})
        if was_debuffed:
            events.append({"type": "crest", "unit": actor, "event": "hit_debuffed_target"})
        if target.has_status("hexed"):
            events.append({"type": "crest", "unit": actor, "event": "hit_hexed_target"})
        if release and was_braced:
            events.append({"type": "crest", "unit": target, "event": "telegraph_braced"})
        for bonus in _equipment_effects(actor, "resonance_vs_status"):
            if any(target.has_status(s) for s in bonus.get("statuses", [])) or (target.staggered and "staggered" in bonus.get("statuses", [])):
                events.append({"type": "resonance", "unit": actor, "amount": actor.add_resonance_amount(int(bonus.get("amount", 0))), "source": "equipment"})
        if affinity == "weak" and target.is_alive():
            events.append({"type": "crest", "unit": actor, "event": "weakness_hit"})
            target.staggered = True
            target.braced_rounds = 0
            delayed = False
            if target.pending is not None and not target.pending["delayed"]:
                target.pending["due_round"] += 1
                target.pending["delayed"] = True
                delayed = True
            events.append({"type": "stagger", "target": target, "delayed": delayed})

        effect = actor.awakening_effect()
        if move.get("slot", "") == "gambit" and actor.awakening_effect_active("empowered_gambit"):
            steal = int(damage * float(effect.get("lifesteal", 0.0)))
            if steal > 0:
                actor.heal(steal)
                events.append({"type": "lifesteal", "actor": actor, "amount": steal})
        if target.is_alive() and target.awakening_effect_active("counter_stance"):
            reflected = max(1, math.floor(damage * float(target.awakening_effect().get("counter_damage", 0.0))))
            actor.take_damage(reflected)
            events.append({"type": "counter", "actor": target, "target": actor, "amount": reflected, "ko": not actor.is_alive()})
        if target.is_alive() and actor.awakening_effect_active("scorched_ground"):
            target.apply_status("scorched", int(effect.get("dot_duration", 3)), int(effect.get("dot_damage", 0)))
            events.append({"type": "status", "target": target, "status": "scorched"})
        if target.is_alive() and actor.surge_expose_ready:
            actor.surge_expose_ready = False
            target.apply_status("exposed", int(effect.get("expose_duration", 1)) + 1)
            events.append({"type": "status", "target": target, "status": "exposed"})

    def _apply_status(self, actor: Unit, target: Unit, effect: dict, events: list) -> None:
        status_name = effect.get("status", "")
        kind = self.data.status_kind(status_name)
        duration = int(effect.get("duration", 1)) + actor.status_duration_bonus()
        if kind != "dot":
            duration += 1
        if status_name == "hexed":
            target.stat_mods = [m for m in target.stat_mods if m["amount"] <= 0]
        target.apply_status(status_name, duration, int(effect.get("value", 0)))
        if target.team != actor.team:
            actor.statuses_applied += 1
            events.append({"type": "status", "target": target, "status": status_name})
            events.append({"type": "crest", "unit": actor, "event": "status_applied"})
        else:
            events.append({"type": "status", "target": target, "status": status_name})
        if status_name == "hexed" and actor.awakening_effect_active("hex_saturation"):
            for move_id in list(target.cooldowns):
                target.cooldowns[move_id] = int(target.cooldowns[move_id]) + int(actor.awakening_effect().get("cooldown_penalty", 1))

    def _aftermath(self, actor: Unit, move: dict, events: list) -> None:
        """Effects on the user whether the move hit or missed (a pounce
        leaves the attacker exposed either way)."""
        for effect in move.get("aftermath_self_statuses", []):
            actor.apply_status(effect["status"], int(effect.get("duration", 1)) + 1)
            events.append({"type": "status", "target": actor, "status": effect["status"]})

    def _mirror_buff(self, actor: Unit, stat_name: str, amount: int, duration: int, events: list) -> None:
        for unit in self.living(self.opposing(actor.team)):
            if unit.entity_passive_type() == "copy_last_buff" and not unit.has_status("hexed"):
                unit.apply_stat_mod(stat_name, amount, duration)
                events.append({"type": "mirror", "unit": unit, "stat": stat_name, "amount": amount})

    def _apply_interception(self, actor: Unit, target: Unit, events: list) -> Unit:
        for ally in self.living(target.team):
            if ally is target or not ally.is_alive():
                continue
            if ally.entity_passive_type() != "intercept_adjacent":
                continue
            chance = float(ally.entity_passive().get("chance", 0.0))
            if self.dice.roll() < chance:
                events.append({"type": "intercept", "protector": ally, "original_target": target})
                events.append({"type": "crest", "unit": ally, "event": "ally_protected"})
                return ally
        return target

    # ── resonance and phases ────────────────────────────────────
    def _gain_for(self, unit: Unit, event: str) -> int:
        gains = unit.crest.get("resonance_gain", {})
        amount = gains.get(event)
        if amount is None:
            amount = self.data.cfg("generic_resonance").get(event)
        if amount is None:
            return 0
        bonus = 0
        for effect in _equipment_effects(unit, "resonance_on_event"):
            if effect.get("event") == event:
                bonus += int(effect.get("amount", 0))
        # floor(x + 0.5): the same half-up rounding in both runtimes.
        return unit.add_resonance_amount(math.floor(float(amount + bonus) * self.resonance_multiplier() + 0.5))

    def _process_crest_events(self, events: list) -> None:
        for event in list(events):
            if event["type"] != "crest":
                continue
            unit: Unit = event["unit"]
            event["gained"] = self._gain_for(unit, event["event"])
        for unit in self.all_units():
            if not unit.awakening_announced and unit.awakening_ready():
                unit.awakening_announced = True
                events.append({"type": "awakening_ready", "unit": unit})

    def _check_phases(self, events: list) -> None:
        for unit in list(self.enemy_units):
            if not unit.is_alive() or not unit.phases:
                continue
            while unit.phase_index + 1 < len(unit.phases):
                trigger = unit.phases[unit.phase_index + 1].get("trigger", {})
                kind = trigger.get("type", "")
                met = (kind == "hp_below" and unit.hp_ratio() < float(trigger.get("threshold", 0.0))) or (
                    kind == "round" and self.round_number >= int(trigger.get("round", 999)))
                if not met:
                    break
                _enter_phase(unit, unit.phase_index + 1, self.data, events)
                summon = unit.phases[unit.phase_index].get("summon")
                if summon:
                    self._summon(summon, events)

    def _summon(self, build: dict, events: list) -> None:
        unit = create_unit(build, "enemy", len(self.enemy_units), self.data)
        self.enemy_units.append(unit)
        events.append({"type": "summon", "unit": unit})

    # ── round end ───────────────────────────────────────────────
    def end_round(self) -> list:
        events: list = []
        for unit in self.all_units():
            if not unit.is_alive():
                continue
            for status in list(unit.statuses):
                if self.data.status_kind(status["name"]) == "dot" and int(status.get("value", 0)) > 0:
                    unit.lose_hp(int(status["value"]))
                    events.append({"type": "dot", "target": unit, "status": status["name"], "amount": int(status["value"]), "ko": not unit.is_alive()})
            if unit.is_alive() and unit.awakening_effect_active("resonance_surge"):
                # The surge strains its bearer but never knocks them out.
                recoil = min(max(1, math.floor(unit.max_hp * float(unit.awakening_effect().get("recoil", 0.0)))), unit.hp - 1)
                if recoil > 0:
                    unit.lose_hp(recoil)
                    events.append({"type": "recoil", "target": unit, "amount": recoil})
        for unit in self.all_units():
            if unit.is_alive():
                unit.on_round_end()
        self.round_number += 1
        self._check_phases(events)
        self._process_crest_events(events)
        return events


# ── Enemy decisions ──────────────────────────────────────────────────

def _profile(battle: Battle, name: str) -> dict:
    profiles = battle.data.cfg("ai_profiles")
    return profiles.get(name) or profiles["legacy"]


def _score(unit: Unit, move: dict, target: Unit, battle: Battle, profile: dict) -> float:
    low, high = battle.damage_range(unit, target, move, unit.last_move_id)
    if int(move.get("power", 0)) <= 0:
        low = high = 0
    accuracy = battle.accuracy_of(unit, move)
    mid = (low + high) / 2.0
    score = mid * accuracy * float(profile.get("damage", 1.0))
    if high >= target.hp and int(move.get("power", 0)) > 0:
        score += float(profile.get("ko", 0.0)) * accuracy
    for effect in move.get("status_effects", []):
        if effect.get("target", "enemy") == "enemy" and not target.has_status(effect.get("status", "")):
            score += float(profile.get("status", 0.0))
    for mod in move.get("target_stat_mods", []):
        if int(mod["amount"]) < 0 and not target.has_debuff():
            score += float(profile.get("debuff", 0.0))
    if unit.hp_ratio() < float(profile.get("self_risk_hp", 0.0)):
        for mod in move.get("self_stat_mods", []):
            if int(mod["amount"]) < 0:
                score -= float(profile.get("self_risk", 0.0))
    score += float(profile.get("finisher", 0.0)) * (1.0 - target.hp_ratio())
    if target.has_status("exposed") or target.staggered:
        score += float(profile.get("exposed", 0.0))
    score += float(profile.get("target_resonance", 0.0)) * target.resonance
    if "guard_break" in move.get("tags", []) and target.brace_streak >= 2:
        score += float(profile.get("punish_brace", 0.0))
    if "protected" in target.tags:
        score += float(profile.get("target_protected", 0.0))
    if move.get("dispel_buffs", False) and any(m["amount"] > 0 for m in target.stat_mods):
        score += float(profile.get("dispel", 0.0))
    return score


def choose_action(unit: Unit, battle: Battle) -> dict:
    """One enemy's action for this round. Mirrors EnemyAI.choose_action."""
    if unit.pending is not None:
        if unit.pending["due_round"] <= battle.round_number:
            return {"actor": unit, "kind": "move", "move": unit.pending["move"], "target": unit.pending["target"], "release": True}
        return {"actor": unit, "kind": "hold", "move": {}, "target": None}
    profile = _profile(battle, unit.ai_profile)
    if unit.awakening_ready() and int(profile.get("awaken", 1)) > 0:
        return {"actor": unit, "kind": "awaken", "move": {}, "target": None}

    candidates = [m for m in unit.moves if unit.is_move_available(m)]
    if unit.forced_move:
        forced = [m for m in candidates if Unit.move_id_of(m) == unit.forced_move]
        unit.forced_move = ""
        if forced:
            candidates = forced
    elif unit.rotation:
        step = unit.rotation[unit.rotation_index % len(unit.rotation)]
        unit.rotation_index += 1
        wanted = [step["move"]] if "move" in step else list(step.get("pick", []))
        narrowed = [m for m in candidates if Unit.move_id_of(m) in wanted]
        if narrowed:
            candidates = narrowed

    targets = battle.living(Battle.opposing(unit.team))
    best_score = -1.0
    best = {"actor": unit, "kind": "brace", "move": {}, "target": None}
    brace_below = float(profile.get("brace_below_hp", 0.0))
    if brace_below > 0.0 and unit.hp_ratio() < brace_below:
        best_score = float(profile.get("brace_value", 0.0))
    noise = float(profile.get("noise", 0.0))
    for move in candidates:
        if move.get("target_rule", "enemy") == "all_enemies":
            score = sum(_score(unit, move, t, battle, profile) for t in targets)
            if noise > 0.0:
                score += battle.dice.roll() * noise
            if score > best_score:
                best_score = score
                best = {"actor": unit, "kind": "move", "move": move, "target": targets[0] if targets else None}
            continue
        if move.get("target_rule", "enemy") == "self":
            score = float(profile.get("self_move", 6.0))
            if noise > 0.0:
                score += battle.dice.roll() * noise
            if score > best_score:
                best_score = score
                best = {"actor": unit, "kind": "move", "move": move, "target": unit}
            continue
        for target in targets:
            score = _score(unit, move, target, battle, profile)
            if noise > 0.0:
                score += battle.dice.roll() * noise
            if score > best_score:
                best_score = score
                best = {"actor": unit, "kind": "move", "move": move, "target": target}
    if best["kind"] == "move" and best["move"].get("telegraph", False):
        best["kind"] = "windup"
    return best


# ── Running battles (simulation and replay) ──────────────────────────

PlayerPolicy = Callable[[Unit, Battle], dict]


def run_round(battle: Battle, player_actions: list) -> list:
    """Resolve one round: the given player actions plus enemy AI.

    Returns the round's events in order. Mirrors the controller's
    _resolve_round + resolver.end_round sequence.
    """
    events: list = []
    actions = list(player_actions) + battle.plan_enemy_actions()
    for action in battle.order_actions(actions):
        if battle.outcome():
            break
        if not action["actor"].is_alive():
            continue
        events.extend(battle.execute(action))
    events.extend(battle.end_round())
    return events


def run_battle(battle: Battle, policy: PlayerPolicy, max_rounds: int | None = None) -> dict:
    """Play a battle to its end with `policy` choosing every player action."""
    limit = max_rounds or int(battle.data.cfg("max_turns"))
    log: list = []
    while not battle.outcome() and battle.round_number <= limit:
        actions = [policy(unit, battle) for unit in battle.living("player")]
        log.extend(run_round(battle, actions))
    return {
        "outcome": battle.outcome() or "timeout",
        "rounds": battle.rounds_completed(),
        "log": log,
    }


def canonical(event: dict) -> str:
    """One event as a stable string, for parity logs."""
    def ref(value: Any) -> str:
        return value.ref if isinstance(value, Unit) else ("" if value is None else str(value))
    keys = ("type", "actor", "unit", "target", "protector", "original_target", "label", "event",
            "amount", "gained", "ko", "affinity", "pierced", "stat", "status", "statuses",
            "delayed", "effect", "item_id", "name", "count", "source", "move_name", "reason")
    parts = []
    for key in keys:
        if key in event:
            value = event[key]
            if isinstance(value, bool):
                value = int(value)
            if isinstance(value, list):
                value = ",".join(str(v) for v in value)
            parts.append(f"{key}={ref(value)}")
    return "|".join(parts)


# ── Player policies (simulation and parity scenarios) ────────────────
#
# Policies decide for player units. They never draw from the battle's
# Dice (a replay reproduces their decisions from the recorded commands),
# so stochastic policies carry their own random.Random.

def _action(unit: Unit, kind: str, move: dict | None = None, target: Unit | None = None, **extra) -> dict:
    action = {"actor": unit, "kind": kind, "move": move or {}, "target": target}
    action.update(extra)
    return action


def threatened_by_telegraph(unit: Unit, battle: Battle) -> bool:
    """A telegraphed attack aimed at this unit (or all of its side) lands this round."""
    for enemy in battle.living(Battle.opposing(unit.team)):
        pending = enemy.pending
        if pending is None or pending["due_round"] > battle.round_number:
            continue
        if pending["target"] is unit or pending["move"].get("target_rule") == "all_enemies":
            return True
    return False


def _expected(unit: Unit, move: dict, target: Unit, battle: Battle) -> float:
    if int(move.get("power", 0)) <= 0:
        return 0.0
    low, high = battle.damage_range(unit, target, move, unit.last_move_id)
    return (low + high) / 2.0 * battle.accuracy_of(unit, move)


def greedy_policy(unit: Unit, battle: Battle) -> dict:
    """Highest expected damage against any living enemy; Brace if nothing."""
    best, best_score = _action(unit, "brace"), 0.0
    for move in unit.moves:
        if not unit.is_move_available(move) or move.get("target_rule") == "self":
            continue
        for target in battle.living(Battle.opposing(unit.team)):
            score = _expected(unit, move, target, battle)
            if move.get("target_rule") == "all_enemies":
                score = sum(_expected(unit, move, t, battle) for t in battle.living(Battle.opposing(unit.team)))
            if score > best_score:
                best, best_score = _action(unit, "move", move, target), score
    if best["kind"] == "move" and best["move"].get("target_rule") == "all_enemies":
        best["target"] = battle.living(Battle.opposing(unit.team))[0]
    return best


def tactical_policy(unit: Unit, battle: Battle) -> dict:
    """A competent player: awaken when ready, Brace into telegraphs, heal
    when low, play weaknesses, finish wounded foes, set up when safe."""
    enemies = battle.living(Battle.opposing(unit.team))
    allies = battle.living(unit.team)
    if unit.awakening_ready():
        return _action(unit, "awaken")
    if threatened_by_telegraph(unit, battle):
        return _action(unit, "brace")
    fallen = [a for a in battle.player_units if not a.is_alive() and "protected" not in a.tags] if unit.team == "player" else []
    if fallen and battle.inventory.get("smelling_salts", 0) > 0:
        return _action(unit, "item", target=fallen[0], item_id="smelling_salts")
    wounded = [a for a in allies if a.hp_ratio() < 0.35]
    if wounded:
        for item_id in ("hi_potion", "potion"):
            if battle.inventory.get(item_id, 0) > 0:
                return _action(unit, "item", target=min(wounded, key=lambda a: (a.hp_ratio(), a.slot_index)), item_id=item_id)
    if unit.has_status("hexed") and battle.inventory.get("clearwater", 0) > 0:
        return _action(unit, "item", target=unit, item_id="clearwater")
    if not unit.moves or "protected" in unit.tags:
        return _action(unit, "brace")
    if unit.crest and not unit.awakened and battle.inventory.get("resonance_tonic", 0) > 0 and unit.resonance >= 40:
        return _action(unit, "item", target=unit, item_id="resonance_tonic")
    best, best_score = _action(unit, "brace"), 1.0
    for move in unit.moves:
        if not unit.is_move_available(move):
            continue
        rule = move.get("target_rule", "enemy")
        if rule == "self":
            buffed = any(m["amount"] > 0 for m in unit.stat_mods)
            score = 0.0 if buffed else 9.0
            if score > best_score:
                best, best_score = _action(unit, "move", move, unit), score
            continue
        candidates = enemies if rule != "all_enemies" else enemies[:1]
        for target in candidates:
            if rule == "all_enemies":
                score = sum(_expected(unit, move, t, battle) for t in enemies)
            else:
                score = _expected(unit, move, target, battle)
                if battle.affinity_of(target, move) == "weak":
                    score *= 1.2
                low, _high = battle.damage_range(unit, target, move, unit.last_move_id)
                if int(move.get("power", 0)) > 0 and low >= target.hp:
                    score += 50.0
                if "target" in target.tags:
                    score *= 1.25
                for mod in move.get("target_stat_mods", []):
                    if mod["amount"] < 0 and not target.has_debuff():
                        score += 3.0
                for effect in move.get("status_effects", []):
                    if effect.get("target", "enemy") == "enemy" and not target.has_status(effect["status"]):
                        score += 4.0
            if score > best_score:
                best, best_score = _action(unit, "move", move, target), score
    return best


def random_policy_factory(seed: int) -> PlayerPolicy:
    rng = random.Random(seed)

    def policy(unit: Unit, battle: Battle) -> dict:
        options = [_action(unit, "brace")]
        for move in unit.moves:
            if not unit.is_move_available(move):
                continue
            if move.get("target_rule") == "self":
                options.append(_action(unit, "move", move, unit))
            else:
                for target in battle.living(Battle.opposing(unit.team)):
                    options.append(_action(unit, "move", move, target))
        if unit.awakening_ready():
            options.append(_action(unit, "awaken"))
        return options[rng.randrange(len(options))]

    return policy


def command_of(action: dict) -> dict:
    """An action as a replayable command (unit references, move ids)."""
    command = {"kind": action["kind"]}
    if action.get("move"):
        command["move"] = Unit.move_id_of(action["move"])
    if action.get("target") is not None:
        command["target"] = action["target"].ref
    if action.get("item_id"):
        command["item_id"] = action["item_id"]
    return command


def action_of(command: dict, unit: Unit, battle: Battle) -> dict:
    """The inverse of command_of, resolving references in `battle`."""
    def find(ref: str) -> Unit | None:
        for candidate in battle.all_units():
            if candidate.ref == ref:
                return candidate
        return None
    move = next((m for m in unit.moves if Unit.move_id_of(m) == command.get("move")), {}) if command.get("move") else {}
    return _action(unit, command["kind"], move, find(command["target"]) if command.get("target") else None,
                   **({"item_id": command["item_id"]} if command.get("item_id") else {}))


def setup_policy(unit: Unit, battle: Battle) -> dict:
    """A setup-minded player: takes any available self-buff while unbuffed,
    otherwise plays like tactical_policy."""
    if not any(m["amount"] > 0 for m in unit.stat_mods) and not unit.has_status("hexed"):
        for move in unit.moves:
            if move.get("target_rule") == "self" and unit.is_move_available(move):
                return _action(unit, "move", move, unit)
    return tactical_policy(unit, battle)


POLICIES: dict = {"tactical": tactical_policy, "greedy": greedy_policy, "setup": setup_policy}
