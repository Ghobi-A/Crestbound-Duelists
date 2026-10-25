"""Overworld characters are scaled so their visible body matches Kai's."""
import importlib.util
import json
import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("audit_character_scale", ROOT / "tools/audit_character_scale.py")
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


@pytest.fixture(scope="module")
def rows():
    return [row for row in audit.audit() if "manifest" in row]


def _stored(row):
    if row["manifest"] == "v2":
        return json.loads(audit.V2_PATH.read_text())["entries"][row["key"]].get("body_height")
    if row["manifest"] == "authored":
        return json.loads(audit.AUTHORED_PATH.read_text())["entries"][row["key"]].get("body_height")
    data = json.loads(audit.CHARACTERS_PATH.read_text())
    kind, key = row["key"]
    if kind == "row":
        return data.get("overworld_body_heights", {}).get(key)
    return data["characters"][key]["overworld"].get("body_height")


def test_every_entry_has_measured_body_height(rows):
    assert len(rows) > 40
    for row in rows:
        assert _stored(row) == row["body_height"], row["name"]


def test_scaled_heights_match_kai(rows):
    kai = next(r for r in rows if (r["manifest"], r["key"]) == audit.REFERENCE)
    kai_height = kai["display_height"] * kai["body_height"] / _stored(kai)
    for row in rows:
        visible = row["display_height"] * row["body_height"] / _stored(row)
        assert abs(visible - kai_height) <= 1.0, row["name"]


def test_measurements_are_deterministic(rows):
    again = [row for row in audit.audit() if "manifest" in row]
    strip = lambda rs: [{k: v for k, v in r.items()} for r in rs]
    assert strip(again) == strip(rows)


def test_runtime_scale_is_uniform_and_body_based():
    # One factor for both axes, derived from the measured body height.
    source = (ROOT / "game/scripts/overworld/overworld_sprite.gd").read_text()
    helper = source[source.index("static func body_scale"):source.index("func attach")]
    assert "Vector2.ONE * float(display_height) / maxf(1.0, source)" in helper
    assert source.count("body_scale(") == 4  # the helper and its three call sites


def test_turning_and_walking_do_not_change_visible_height(rows):
    # Every drawn sheet stays within MOTION_TOLERANCE display px across its
    # facings and walk frames (no growing, shrinking or popping when moving).
    for row in rows:
        if row["motion"] and not row["shadowed"]:
            assert max(row["motion"].values()) <= audit.MOTION_TOLERANCE, (row["name"], row["motion"])


def test_character_proportions_match_the_approved_baseline(rows):
    # Scale normalisation must never change who a character is: any edit that
    # stretches, crops or re-renders a sprite moves these ratios and fails
    # here until the new art is reviewed and re-baselined (--baseline).
    baseline = json.loads(audit.BASELINE_PATH.read_text())
    current = audit.proportions(rows + [{"reference": None}])
    assert set(current) == set(baseline)
    for name, ratios in baseline.items():
        for ratio, value in ratios.items():
            assert abs(current[name][ratio] - value) <= 0.02, (name, ratio, current[name][ratio], value)


@pytest.mark.parametrize("mutate, message", [
    (lambda v2, c, a: v2.update(display_height=0), "display_height must be positive"),
    (lambda v2, c, a: a["entries"]["joey"].update(body_height=-3), "body_height must be positive"),
    (lambda v2, c, a: a["entries"]["joey"]["frames"].pop("west"), "needs down, up, east and west"),
    (lambda v2, c, a: a["entries"]["joey"]["frames"]["down"][0].update(foot=[10, 99999]), "foot outside its rect"),
    (lambda v2, c, a: c["characters"]["route01_rowan"]["overworld"].update(body_height=99999), "body_height outside the frame"),
    (lambda v2, c, a: a["aliases"].update(ghost="nobody"), "unknown entry 'nobody'"),
])
def test_invalid_manifest_data_fails_clearly(mutate, message):
    v2 = json.loads(audit.V2_PATH.read_text())
    characters = json.loads(audit.CHARACTERS_PATH.read_text())
    authored = json.loads(audit.AUTHORED_PATH.read_text())
    audit.validate(v2, characters, authored)
    mutate(v2, characters, authored)
    with pytest.raises(audit.ManifestError, match=re.escape(message)):
        audit.validate(v2, characters, authored)


def test_battle_bodies_are_measured_and_drawn_at_one_height():
    characters = json.loads(audit.CHARACTERS_PATH.read_text())
    measured = audit.battle_heights(characters)
    assert characters["battle_body_display"] == audit.BATTLE_BODY_DISPLAY
    for key, record in characters["characters"].items():
        assert record["battle_body_height"] == measured[key], key
    # DuelistSprite.battle_scale divides the display height by the body, so
    # every combatant's visible body is the same size whatever its headroom.
    source = (ROOT / "game/scripts/battle/duelist_sprite.gd").read_text()
    assert "float(manifest.battle_body_display) / maxf(1.0, float(record.battle_body_height))" in source
