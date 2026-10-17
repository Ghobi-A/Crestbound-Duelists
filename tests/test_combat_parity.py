"""The committed cross-runtime fixture must follow current Python/YAML rules."""

import json

from tools.generate_combat_parity import ROOT, build_cases


def test_godot_parity_fixture_is_current():
    assert (
        json.loads((ROOT / "game/data/combat_parity_cases.json").read_text())
        == build_cases()
    )


def test_cripple_does_not_gain_brace_bypass_from_debuff_magnitude():
    from combat import move_breaks_brace
    from models import ClassName, create_unit

    assert not move_breaks_brace(create_unit(ClassName.ASSASSIN).moves[1])
    assert move_breaks_brace(create_unit(ClassName.WARRIOR).moves[1])
    assert move_breaks_brace(create_unit(ClassName.MAGE).moves[1])


def test_ai_brace_estimates_follow_the_same_tactical_tags():
    from ai import expected_damage
    from models import ClassName, create_unit

    guardian = create_unit(ClassName.GUARDIAN)
    for class_id in (ClassName.WARRIOR, ClassName.MAGE):
        actor = create_unit(class_id)
        signature = actor.moves[1]
        assert expected_damage(signature, actor, guardian, True) == expected_damage(
            signature, actor, guardian, False
        )
    assassin = create_unit(ClassName.ASSASSIN)
    assert expected_damage(
        assassin.moves[1], assassin, guardian, True
    ) < expected_damage(assassin.moves[1], assassin, guardian, False)
