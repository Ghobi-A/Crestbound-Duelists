"""Overworld characters are scaled so their visible body matches Kai's."""
import importlib.util
import json
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
