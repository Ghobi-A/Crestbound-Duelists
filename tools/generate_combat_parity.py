"""Deterministic Python reference cases for the playable Godot naked chassis."""

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


if __name__ == "__main__":
    path = ROOT / "game/data/combat_parity_cases.json"
    path.write_text(json.dumps(build_cases(), indent=2) + "\n")
    print(f"Wrote {path}")
