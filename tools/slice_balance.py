"""Simulate the vertical slice's encounters with the party engine.

Runs each chapter encounter from data/encounters.yaml under the player
policies in party_combat.py (tactical, greedy, setup, random) with fixed
seeds, and reports win rate, rounds and HP left. Kai's build follows the
chapter: Unbonded on Route 01, in Greymere and through the Hollow Court
until the bond, Unsettled against the Sealed Choir, and each of the six
stabilised classes in Civara.

    python tools/slice_balance.py                 # every slice encounter
    python tools/slice_balance.py greymaw_den     # one encounter
    python tools/slice_balance.py --sims 400 --seed 7

The same functions feed the snapshot's vertical_slice section
(tools/generate_snapshot.py).
"""
from __future__ import annotations

import argparse
import statistics
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import loaders  # noqa: E402
import party_combat as pc  # noqa: E402

CLASSES = ["warrior", "guardian", "mage", "sorcerer", "assassin", "neutral"]
DEFAULT_CREST = {
    "warrior": "crimson_crest", "guardian": "azure_crest", "mage": "ember_crest",
    "sorcerer": "eclipse_crest", "assassin": "glass_crest", "neutral": "verdant_crest",
}
SLICE_PREFIXES = ("route01_", "greymaw", "greymere_", "court_", "civara_", "joey_")


def kai_builds(encounter_id: str) -> dict[str, dict]:
    """Kai at this point in the chapter: {label: build}."""
    cast = loaders.load_cast()
    if encounter_id == "court_sealed_choir":
        return {"unsettled": {k: v for k, v in cast["kai_unsettled"].items() if k != "id"}}
    if encounter_id.startswith("civara_"):
        # Kai stabilised the assessor's class, with its default kit.
        classes = loaders.load_classes()
        chosen = [c for c in CLASSES if encounter_id.endswith(c)] or CLASSES
        return {
            c: {"name": "Kai", "class_id": c, "crest_id": DEFAULT_CREST[c], "position": "front",
                "move_ids": classes[c]["move_ids"]}
            for c in chosen
        }
    return {"unbonded": {k: v for k, v in cast["kai_unbonded"].items() if k != "id"}}


def player_party(encounter: dict, kai: dict) -> list[dict]:
    cast = loaders.load_cast()
    builds = []
    for member in encounter.get("player_party") or ["kai"]:
        if isinstance(member, dict):
            builds.append(member)
        elif member == "kai":
            builds.append(dict(kai))
        else:
            builds.append({k: v for k, v in cast[member].items() if k != "id"})
    return builds


def policies(seed: int) -> dict:
    return {
        "tactical": pc.tactical_policy,
        "greedy": pc.greedy_policy,
        "setup": pc.setup_policy,
        "random": pc.random_policy_factory(seed),
    }


def simulate(encounter_id: str, sims: int = 200, seed: int = 42, inventory: dict | None = None) -> dict:
    data = pc.GameData.load()
    encounter = loaders.load_encounters()[encounter_id]
    results: dict = {}
    for label, kai in kai_builds(encounter_id).items():
        for policy_name in ("tactical", "greedy", "setup", "random"):
            wins, rounds, hp_left, actions = 0, [], [], {}
            for i in range(sims):
                policy = policies(seed + i)[policy_name]
                battle = pc.Battle(encounter, player_party(encounter, kai), data, pc.Dice(seed * 100_003 + i), inventory or {})
                result = pc.run_battle(battle, policy, 40)
                won = result["outcome"] == "victory"
                wins += won
                rounds.append(result["rounds"])
                if won:
                    kai_unit = battle.player_units[0]
                    hp_left.append(kai_unit.hp / kai_unit.max_hp)
                for event in result["log"]:
                    if event["type"] == "action_start" and event.get("actor") is battle.player_units[0]:
                        actions[event["label"]] = actions.get(event["label"], 0) + 1
            total = sum(actions.values()) or 1
            results[f"{label}/{policy_name}"] = {
                "win_rate": round(wins / sims, 3),
                "rounds_median": statistics.median(rounds),
                "hp_left_median": round(statistics.median(hp_left), 2) if hp_left else 0.0,
                "top_action_share": round(max(actions.values()) / total, 2) if actions else 0.0,
                "top_action": max(actions, key=actions.get) if actions else "",
            }
    return results


def slice_encounters() -> list[str]:
    return [eid for eid in loaders.load_encounters() if eid.startswith(SLICE_PREFIXES)]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("encounters", nargs="*")
    parser.add_argument("--sims", type=int, default=200)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()
    for encounter_id in args.encounters or slice_encounters():
        print(f"== {encounter_id}")
        for key, row in simulate(encounter_id, args.sims, args.seed).items():
            print(f"  {key:22s} win {row['win_rate']:.0%}  rounds {row['rounds_median']:>4}  "
                  f"hp {row['hp_left_median']:.2f}  top {row['top_action']} {row['top_action_share']:.0%}")


if __name__ == "__main__":
    main()
