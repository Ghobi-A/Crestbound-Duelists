"""Regression contracts for the Cowork/PR15 visual rebuild.

These checks protect the authored presentation layer from drifting back toward
legacy names, placeholder visual language, or disconnected Kai class assets.
They deliberately test production-facing contracts rather than combat rules.
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game"
REWORK = GAME / "assets" / "rework"


def _presentation_manifest() -> dict:
    return json.loads((REWORK / "characters.json").read_text(encoding="utf-8"))


def test_cowork_focal_rework_assets_exist() -> None:
    for filename in (
        "characters.json",
        "combat_cast.png",
        "kai_classes.png",
        "kai_overworld.png",
        "overworld_cast.png",
        "hollow_court.png",
    ):
        path = REWORK / filename
        assert path.exists() and path.stat().st_size > 0, f"missing focal rework asset: {path}"


def test_kai_has_six_distinct_class_records_with_one_identity() -> None:
    manifest = _presentation_manifest()
    classes = ("warrior", "guardian", "mage", "sorcerer", "assassin", "neutral")
    records = manifest["characters"]

    battle_rects: set[tuple[int, ...]] = set()
    overworld_rows: set[int] = set()
    for class_id in classes:
        record = records[f"kai_{class_id}"]
        assert record["display_name"] == "Kai"
        assert record["class_id"] == class_id
        assert record["atlas"] == "res://assets/rework/kai_classes.png"
        assert record["overworld"]["atlas"] == "res://assets/rework/kai_overworld.png"
        battle_rects.add(tuple(record["battle_rect"]))
        overworld_rows.add(int(record["overworld"]["row"]))

    assert len(battle_rects) == 6
    assert len(overworld_rows) == 6


def test_kai_class_visual_spec_preserves_magic_and_neutral_identities() -> None:
    spec = (ROOT / "docs" / "rework" / "KAI_CLASS_VISUALS.md").read_text(encoding="utf-8").lower()
    assert "mage" in spec and ("tunic" in spec or "robe" in spec or "long coat" in spec)
    assert "sorcerer" in spec and ("tunic" in spec or "robe" in spec or "coat" in spec)
    assert "neutral" in spec and "sword" in spec and "magic" in spec
    assert "kai's face" in spec or "kai’s face" in spec or "same face" in spec


def test_visible_greymere_text_uses_current_canon() -> None:
    text = (GAME / "data" / "dialogue" / "greymere.json").read_text(encoding="utf-8")
    for stale in ("Warden Thorne", "Avelaine", "Veyrhold"):
        assert stale not in text
    for current in ("Warden Almyra", "Duchy of Avelan", "Civara", "Elder Silas"):
        assert current in text


def test_missing_move_vfx_never_use_placeholder_palette() -> None:
    vfx = (GAME / "scripts" / "presentation" / "battle_vfx.gd").read_text(encoding="utf-8")
    assert "PlaceholderPalette" not in vfx
    assert "SYSTEM_MAGIC" in vfx
    assert "SYSTEM_PHYSICAL" in vfx
    assert "_play_fallback" in vfx
