"""Production contracts for the four-direction overworld v2 sprite pass."""

from __future__ import annotations

import base64
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game"
REWORK = GAME / "assets" / "rework"
REGISTRY = REWORK / "overworld_v2.json"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def _registry() -> dict:
    return json.loads(REGISTRY.read_text(encoding="utf-8"))


def _decode(name: str) -> bytes:
    text = (REWORK / f"{name}.b64").read_text(encoding="ascii")
    return base64.b64decode("".join(text.split()), validate=True)


def _png_dimensions(payload: bytes) -> tuple[int, int]:
    assert payload.startswith(PNG_SIGNATURE)
    assert payload[12:16] == b"IHDR"
    return struct.unpack(">II", payload[16:24])


def test_v2_registry_declares_real_four_frame_four_direction_animation() -> None:
    data = _registry()
    assert data["schema_version"] == 2
    assert data["frame_size"] == [40, 56]
    assert data["walk_frames"] == 4
    assert data["directions"] == {"down": 0, "up": 4, "east": 8, "west": 12}


def test_all_six_kai_classes_have_distinct_animated_rows() -> None:
    entries = _registry()["entries"]
    rows = []
    for class_id in ("warrior", "guardian", "mage", "sorcerer", "assassin", "neutral"):
        record = entries[f"aren/{class_id}"]
        assert record["atlas"] == "kai"
        assert record["anchor"] == [20, 52]
        rows.append(record["row"])
    assert rows == list(range(6))


def test_greymere_and_story_cast_are_covered_by_v2_atlas() -> None:
    entries = _registry()["entries"]
    for key in (
        "elara",
        "mira",
        "townsfolk/farmboy",
        "townsfolk/herbalist_woman",
        "townsfolk/village_elder",
        "townsfolk/farmhand_capped",
        "townsfolk/guard_sword",
        "townsfolk/guard_spear",
        "townsfolk/elder_woman",
        "townsfolk/torch_bearer",
        "townsfolk/hooded_stranger",
        "rin",
        "cassian_clave",
    ):
        assert key in entries
        assert entries[key]["atlas"] == "cast"


def test_encoded_v2_atlases_are_valid_expected_png_sheets() -> None:
    assert _png_dimensions(_decode("kai_overworld_v2.png")) == (640, 336)
    assert _png_dimensions(_decode("overworld_cast_v2.png")) == (640, 896)


def test_runtime_drives_frames_from_step_progress() -> None:
    sprite = (GAME / "scripts" / "overworld" / "overworld_sprite.gd").read_text(encoding="utf-8")
    player = (GAME / "scripts" / "overworld" / "player.gd").read_text(encoding="utf-8")
    assert "V2_MANIFEST_PATH" in sprite
    assert "func set_walk_phase" in sprite
    assert "_registered_animated = true" in sprite
    assert "_sprite.set_walk_phase(_step_progress)" in player
