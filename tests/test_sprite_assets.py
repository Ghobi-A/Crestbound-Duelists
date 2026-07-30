"""Sprite sheets must match the manifest the game reads them through.

`duelist_sprite.gd` and `overworld_sprite.gd` slice every character sheet
using the frame geometry in `game/assets/battle/sheet_manifest.json`. If a
sheet and the manifest disagree the game does not fail loudly — it renders
a sliver of the wrong frame — so the agreement is checked here instead.

These tests also pin the asset paths that `sprite_key` resolves to. Those
strings are written into save files, so renaming a directory silently
breaks existing saves.
"""

from __future__ import annotations

import json
import struct
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
ASSETS = REPO_ROOT / "game" / "assets"
MANIFEST_PATH = ASSETS / "battle" / "sheet_manifest.json"

# sprite_key values GameState writes into save data (game_state.gd).
PLAYER_CLASSES = ["warrior", "guardian", "mage", "sorcerer", "assassin", "neutral"]
CHARACTER_KEYS = [f"aren/{class_id}" for class_id in PLAYER_CLASSES] + ["elara", "mira"]
ENEMY_KEYS = ["riven_raider", "hexbound_adept", "unbound_mercenary"]


def png_size(path: Path) -> tuple[int, int]:
    """Read a PNG's dimensions from its IHDR chunk, no image library needed."""
    with path.open("rb") as handle:
        header = handle.read(24)
    assert header[:8] == b"\x89PNG\r\n\x1a\n", f"{path} is not a PNG"
    return struct.unpack(">II", header[16:24])


@pytest.fixture(scope="module")
def manifest() -> dict:
    return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))


@pytest.mark.parametrize("key", CHARACTER_KEYS)
def test_overworld_sheet_matches_manifest(key: str, manifest: dict) -> None:
    overworld = manifest["overworld"]
    width, height = png_size(ASSETS / "characters" / key / "overworld.png")
    assert height == overworld["frame_height"]
    assert width == overworld["frame_width"] * overworld["frames"]


@pytest.mark.parametrize("key", CHARACTER_KEYS + ENEMY_KEYS)
def test_battle_sheet_matches_manifest(key: str, manifest: dict) -> None:
    folder = "characters" if key in CHARACTER_KEYS else "enemies"
    width, height = png_size(ASSETS / folder / key / "battle.png")
    assert height == manifest["frame_height"]
    assert width == manifest["frame_width"] * manifest["frame_count"]


def test_overworld_directions_fit_within_the_sheet(manifest: dict) -> None:
    overworld = manifest["overworld"]
    walk_frames = overworld["walk_frames"]
    for name, start in overworld["directions"].items():
        assert start + walk_frames <= overworld["frames"], (
            f"direction '{name}' runs past the end of the sheet"
        )


def test_overworld_anchor_sits_inside_the_frame(manifest: dict) -> None:
    """The anchor is subtracted as a sprite offset; outside the frame it
    would place characters off their own tile."""
    overworld = manifest["overworld"]
    x, y = overworld["anchor"]
    assert 0 <= x <= overworld["frame_width"]
    assert 0 <= y <= overworld["frame_height"]


def test_battle_states_stay_within_the_frame_count(manifest: dict) -> None:
    for name, state in manifest["states"].items():
        assert state["start"] + state["count"] <= manifest["frame_count"], (
            f"battle state '{name}' references frames past the end of the sheet"
        )


@pytest.mark.parametrize("key", CHARACTER_KEYS)
def test_save_referenced_sprite_paths_exist(key: str) -> None:
    """`sprite_key` is persisted in saves; these paths must keep resolving."""
    assert (ASSETS / "characters" / key / "overworld.png").is_file()
    assert (ASSETS / "characters" / key / "battle.png").is_file()
