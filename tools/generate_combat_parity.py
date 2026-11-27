"""Deterministic Python reference cases for the Godot battle runtime.

Two fixtures:

* game/data/combat_parity_cases.json — the classic damage bounds for every
  class pair, move and Brace state (the bare chassis), plus Hex and
  modifier-refresh checks, from the classic duel model in combat.py.
* game/data/combat_replays.json — whole seeded battles from the party
  engine (party_combat.py): each scenario records the encounter, the
  player builds, the player's command each round, every dice draw and
  the canonical event log. combat_parity_smoke.gd replays the commands
  and dice through the real Godot runtime and requires the same log,
  event for event. Together the scenarios cover every class and its
  alternative loadout, every Crest awakening, every Bonded Entity, the
  charms, the items, telegraphs, staggers, phases and summons, and each
  battle objective.

    python tools/generate_combat_parity.py
"""

import json
import sys
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from combat import calculate_damage, execute_move
from loaders import load_combat_config
from models import ClassName, create_unit


def build_cases():
    config = load_combat_config()
    cases = []
    for a in ClassName:
        for b in ClassName:
            for index in range(3):
                for braced in (False, True):
                    actor, target = create_unit(a), create_unit(b)
                    move = actor.moves[index]
                    bounds = []
                    for variance in (config["variance_low"], config["variance_high"]):
                        with patch("combat.random.uniform", return_value=variance):
                            bounds.append(
                                calculate_damage(move, actor, target, braced)[0]
                            )
                    cases.append(
                        {
                            "actor": a.value.lower(),
                            "target": b.value.lower(),
                            "move": index,
                            "braced": braced,
                            "bounds": bounds,
                        }
                    )
    neutral, target = create_unit(ClassName.NEUTRAL), create_unit(ClassName.SORCERER)
    neutral.apply_status("hexed", 2)
    signature = neutral.moves[1]
    with patch("combat.random.random", return_value=0.0):
        execute_move(neutral, target, signature, 1, False, False)
    hex_stats = [neutral.atk, neutral.mag, neutral.def_, neutral.res]
    guardian = create_unit(ClassName.GUARDIAN)
    guardian.apply_stat_mod("def", 8, 4)
    guardian.tick_modifiers()
    guardian.apply_stat_mod("def", 8, 4)
    refresh = {
        "value": guardian.def_,
        "count": len(guardian.stat_modifiers),
        "turns": guardian.stat_modifiers[0].turns_remaining,
    }
    return {"damage": cases, "hex_stats": hex_stats, "refresh": refresh}


# ── Replay scenarios (Combat System 3.0) ────────────────────────────

REPLAY_PATH = ROOT / "game/data/combat_replays.json"
MAX_ROUNDS = 40
DEFAULT_CRESTS = {
    "warrior": "crimson_crest", "guardian": "azure_crest", "mage": "ember_crest",
    "sorcerer": "eclipse_crest", "assassin": "glass_crest", "neutral": "verdant_crest",
}
CLASSES = ["warrior", "guardian", "mage", "sorcerer", "assassin", "neutral"]
CHARMS = ["road_charm", "whetstone_token", "lamplighters_glass", "drowned_bell", "wardens_sigil", "greymaw_fang"]
PROFILES = ["aggressive", "defensive", "disruptive", "opportunistic", "legacy", "aggressive"]


def _duelist(name, class_id, crest=True, entity="", **extra):
    build = {"name": name, "class_id": class_id, "crest_id": DEFAULT_CRESTS[class_id] if crest else "",
             "entity_id": entity, "position": "back" if class_id in ("mage", "sorcerer") else "front"}
    build.update(extra)
    return build


def scenario_specs():
    import loaders
    cast = loaders.load_cast()
    classes = loaders.load_classes()

    def c(cast_id, **extra):
        build = {k: v for k, v in cast[cast_id].items() if k != "id"}
        build.update(extra)
        return build

    specs = []
    for i, class_id in enumerate(CLASSES):
        rival = CLASSES[(i + 3) % len(CLASSES)]
        specs.append({"id": f"duel_{class_id}", "seed": 1000 + i,
                      "players": [_duelist("Kai", class_id)],
                      "enemies": [_duelist("Rival", rival, ai_profile="legacy")]})
        alts = classes[class_id]["unlockable_moves"]
        loadout = alts + [classes[class_id]["move_ids"][1]]
        specs.append({"id": f"loadout_{class_id}", "seed": 1100 + i,
                      "players": [_duelist("Kai", class_id, move_ids=loadout, equipment=CHARMS[i])],
                      "enemies": [_duelist("Rival", CLASSES[(i + 1) % 6], ai_profile=PROFILES[i]),
                                  _duelist("Second", CLASSES[(i + 2) % 6], crest=False, ai_profile=PROFILES[(i + 1) % 6])]})
    # Every Crest's awakening, against a sturdy sparring dummy that gives
    # the bearer time to meet the Crest's condition.
    for i, class_id in enumerate(CLASSES):
        dummy = _duelist("Sparring Dummy", "guardian", crest=False, ai_profile="legacy",
                         stat_scale={"hp": 3.0, "atk": 0.45, "mag": 0.45})
        extra = {"move_ids": ["mind_pierce", "binding_glyph"]} if class_id == "mage" else {}
        specs.append({"id": f"awaken_{DEFAULT_CRESTS[class_id]}", "seed": 1050 + i,
                      "players": [_duelist("Kai", class_id, **extra)], "enemies": [dummy]})
    entity_classes = {"storm_lion": "guardian", "glass_mantis": "assassin", "ash_seraph": "mage",
                      "iron_tortoise": "guardian", "mirror_fox": "neutral", "grave_stag": "sorcerer"}
    for i, (entity, class_id) in enumerate(entity_classes.items()):
        players = [_duelist("Bearer", class_id, entity=entity), _duelist("Ally", "warrior")]
        enemies = [_duelist("Foe", "assassin", ai_profile="aggressive"), _duelist("Caster", "sorcerer", ai_profile="disruptive")]
        if entity == "mirror_fox":
            players = [_duelist("Ally", "warrior", move_ids=["power_slash", "rallying_roar", "reckless_charge"]), _duelist("Ally Two", "neutral", move_ids=["hybrid_strike", "mirror_stance", "wild_card"])]
            enemies = [_duelist("Fox Bearer", "neutral", entity="mirror_fox", ai_profile="aggressive"), _duelist("Caster", "sorcerer", ai_profile="disruptive")]
        specs.append({"id": f"entity_{entity}", "seed": 1200 + i, "players": players, "enemies": enemies,
                      "policy": "setup" if entity == "mirror_fox" else "tactical",
                      "battlefield_effect": {"name": "Old Ruin", "type": "resonance_surge", "after_round": 2, "multiplier": 1.5, "tags": ["ruin"]}})
    for seed in range(3):
        extra = {"equipment": "greymaw_fang"} if seed == 2 else {}
        if seed == 1:
            extra = {"move_ids": ["kai_strike", "shoulder_check", "wild_swing", "steady_footing"]}
        specs.append({"id": f"greymaw_{seed}", "seed": 1300 + seed, "players": [c("kai_unbonded", **extra)],
                      "enemies": [c("greymaw")], "inventory": {"potion": 2, "hi_potion": 1, "clearwater": 1},
                      "policy": "setup" if seed == 1 else "tactical"})
    specs.append({"id": "fang_vs_brace", "seed": 1310,
                  "players": [c("kai_unbonded", equipment="greymaw_fang", move_ids=["kai_strike", "wild_swing"])],
                  "enemies": [c("danfor")]})
    specs.append({"id": "dispel_buffs", "seed": 1311,
                  "players": [_duelist("Kai", "sorcerer", move_ids=["null_burst", "shadow_lash"])],
                  "enemies": [_duelist("Showboat", "warrior", crest=False, move_ids=["rallying_roar"], ai_profile="legacy")]})
    for seed in range(2):
        specs.append({"id": f"sealed_choir_{seed}", "seed": 1400 + seed,
                      "players": [c("kai_unsettled"), c("almyra"), c("hale")], "enemies": [c("sealed_choir")],
                      "inventory": {"potion": 2, "resonance_tonic": 1, "smelling_salts": 1}})
    specs.append({"id": "protect_joey", "seed": 1500, "players": [c("kai_unsettled"), c("joey")],
                  "enemies": [c("riven_wisp"), c("riven_wisp", name="Riven Wisp II")],
                  "objective": "survive_assault", "objective_params": {"turns_required": 4}, "inventory": {"potion": 1}})
    specs.append({"id": "riven_anchor", "seed": 1501, "players": [c("kai_unsettled")],
                  "enemies": [c("riven_anchor"), c("riven_wisp")], "objective": "defeat_target"})
    specs.append({"id": "gallery_pair", "seed": 1502, "players": [c("kai_unsettled"), c("almyra")],
                  "enemies": [c("riven_husk"), c("riven_wisp")]})
    specs.append({"id": "danfor_spar", "seed": 1503, "players": [c("kai_unbonded")], "enemies": [c("danfor")]})
    specs.append({"id": "roadside_ambush", "seed": 1504, "players": [c("kai_unbonded")],
                  "enemies": [c("roadside_tough"), c("roadside_tough", name="Roadside Tough II")], "inventory": {"potion": 1}})
    import loaders as _l
    court = _l.load_encounters()["hollow_court_battle"]
    for seed in range(2):
        specs.append({"id": f"hollow_court_3v3_{seed}", "seed": 1600 + seed,
                      "players": [_duelist("Kai", "warrior"), c("almyra"), _duelist("Liora Sen", "mage", entity="ash_seraph")],
                      "enemies": court["enemy_party"], "battlefield_effect": court["battlefield_effect"]})
    return specs


def record_scenario(spec):
    import party_combat as pc
    data = pc.GameData.load()
    encounter = {"name": spec["id"], "objective": spec.get("objective", "defeat_all"),
                 "objective_params": spec.get("objective_params", {}),
                 "battlefield_effect": spec.get("battlefield_effect", {}), "enemy_party": spec["enemies"]}
    dice = pc.Dice(spec["seed"])
    battle = pc.Battle(encounter, spec["players"], data, dice, spec.get("inventory", {}))
    commands, log = [], []
    while not battle.outcome() and battle.round_number <= MAX_ROUNDS:
        policy = pc.POLICIES[spec.get("policy", "tactical")]
        actions = [policy(unit, battle) for unit in battle.living("player")]
        commands.append([pc.command_of(action) for action in actions])
        log.extend(pc.canonical(event) for event in pc.run_round(battle, actions))
    return {
        "id": spec["id"], "encounter": encounter, "players": spec["players"],
        "inventory": spec.get("inventory", {}), "commands": commands, "dice": dice.record,
        "log": log, "outcome": battle.outcome() or "timeout", "rounds": battle.rounds_completed(),
    }


def build_replays():
    return {"scenarios": [record_scenario(spec) for spec in scenario_specs()]}


if __name__ == "__main__":
    path = ROOT / "game/data/combat_parity_cases.json"
    path.write_text(json.dumps(build_cases(), indent=2) + "\n")
    print(f"Wrote {path}")
    REPLAY_PATH.write_text(json.dumps(build_replays(), indent=1, sort_keys=True) + "\n")
    print(f"Wrote {REPLAY_PATH}")
