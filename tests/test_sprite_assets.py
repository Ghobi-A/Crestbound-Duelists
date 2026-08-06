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
import re
import struct
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
ASSETS = REPO_ROOT / "game" / "assets"
MANIFEST_PATH = ASSETS / "battle" / "sheet_manifest.json"
GREYMERE_GD = REPO_ROOT / "game" / "scripts" / "overworld" / "greymere.gd"
ENTITIES_JSON = REPO_ROOT / "game" / "data" / "entities.json"

# sprite_key values GameState writes into save data (game_state.gd).
PLAYER_CLASSES = ["warrior", "guardian", "mage", "sorcerer", "assassin", "neutral"]
CHARACTER_KEYS = [f"aren/{class_id}" for class_id in PLAYER_CLASSES] + ["elara", "mira"]
ENEMY_KEYS = ["riven_raider", "hexbound_adept", "unbound_mercenary"]

# Bonded Entity ids, read from the data file rather than hand-duplicated
# (same reasoning as TOWNSFOLK_KEYS below): entity_runtime.gd loads
# assets/entities/<entity_id>/idle.png for whatever a party build's
# entity_id names, so an id present in entities.json with no matching
# folder is a bond that silently renders nothing in battle.
ENTITY_IDS = sorted(json.loads(ENTITIES_JSON.read_text(encoding="utf-8")).keys())


def _townsfolk_keys() -> list[str]:
    """Overworld-only sprite_key values, read straight out of greymere.gd's
    TOWNSFOLK array rather than hand-duplicated here — a townsfolk NPC
    added to one and not the other used to go untested silently. These
    are never part of a save's party/roster, so unlike CHARACTER_KEYS they
    have no battle.png and don't gate test_save_referenced_sprite_paths_exist."""
    source = GREYMERE_GD.read_text(encoding="utf-8")
    match = re.search(r"const TOWNSFOLK: Array\[Dictionary\] = \[(.*?)\n\]", source, re.DOTALL)
    assert match, "Could not locate the TOWNSFOLK constant in greymere.gd"
    keys = re.findall(r'"sprite_key":\s*"([^"]+)"', match.group(1))
    assert keys, "TOWNSFOLK parsed but no sprite_key values were found"
    return keys


TOWNSFOLK_KEYS = _townsfolk_keys()


def _townsfolk_symbols() -> list[str]:
    source = GREYMERE_GD.read_text(encoding="utf-8")
    match = re.search(r"const TOWNSFOLK: Array\[Dictionary\] = \[(.*?)\n\]", source, re.DOTALL)
    assert match
    return re.findall(r'"tile_symbol":\s*"([^"]+)"', match.group(1))


def test_townsfolk_tile_symbols_are_unique() -> None:
    """Two NPCs sharing a tile_symbol would both resolve to whichever one
    _find_tile hits first, and the other would silently never spawn."""
    symbols = _townsfolk_symbols()
    duplicates = {s for s in symbols if symbols.count(s) > 1}
    assert not duplicates, f"TOWNSFOLK tile_symbol(s) reused: {sorted(duplicates)}"


def test_townsfolk_tile_symbols_appear_exactly_once_on_the_map() -> None:
    """A TOWNSFOLK entry whose symbol was never placed (or was mistyped)
    fails _find_tile's push_error at runtime instead of at review time; a
    symbol placed twice would silently spawn the same NPC on both tiles."""
    source = GREYMERE_GD.read_text(encoding="utf-8")
    map_match = re.search(r"const MAP: Array\[String\] = \[(.*?)\n\]", source, re.DOTALL)
    assert map_match
    rows = re.findall(r'"([^"]*)"', map_match.group(1))
    for symbol in _townsfolk_symbols():
        count = sum(row.count(symbol) for row in rows)
        assert count == 1, f"MAP contains '{symbol}' {count} time(s), expected exactly 1"


def png_size(path: Path) -> tuple[int, int]:
    """Read a PNG's dimensions from its IHDR chunk, no image library needed."""
    with path.open("rb") as handle:
        header = handle.read(24)
    assert header[:8] == b"\x89PNG\r\n\x1a\n", f"{path} is not a PNG"
    return struct.unpack(">II", header[16:24])


@pytest.fixture(scope="module")
def manifest() -> dict:
    return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))


@pytest.mark.parametrize("key", CHARACTER_KEYS + TOWNSFOLK_KEYS)
def test_overworld_sheet_matches_manifest(key: str, manifest: dict) -> None:
    """Mirrors test_battle_sheet_matches_manifest: an authored overworld
    sheet (docs/AUTHORED_ART_PIPELINE.md) is sized against its own sidecar
    when one exists, and against the global manifest otherwise."""
    png_path = ASSETS / "characters" / key / "overworld.png"
    width, height = png_size(png_path)
    sidecar_path = png_path.with_suffix(".json")
    if sidecar_path.is_file():
        sidecar = json.loads(sidecar_path.read_text(encoding="utf-8"))
        assert height == sidecar["frame_height"]
        assert width == sidecar["frame_width"] * sidecar.get("walk_frames", 1)
        x, y = sidecar["anchor"]
        assert 0 <= x <= sidecar["frame_width"]
        assert 0 <= y <= sidecar["frame_height"]
        for name, start in sidecar.get("directions", {}).items():
            assert start + sidecar.get("walk_frames", 1) <= (
                width // sidecar["frame_width"]
            ), f"{key}: overworld direction '{name}' runs past the end of the sheet"
    else:
        overworld = manifest["overworld"]
        assert height == overworld["frame_height"]
        assert width == overworld["frame_width"] * overworld["frames"]


@pytest.mark.parametrize("key", CHARACTER_KEYS + ENEMY_KEYS)
def test_battle_sheet_matches_manifest(key: str, manifest: dict) -> None:
    """A battle sheet is sized against its own sidecar (docs/AUTHORED_ART_PIPELINE.md)
    when one exists, and against the global manifest otherwise. Either way the
    PNG and its declared layout must actually agree, or DuelistSprite renders
    a sliver of the wrong frame instead of failing loudly."""
    folder = "characters" if key in CHARACTER_KEYS else "enemies"
    png_path = ASSETS / folder / key / "battle.png"
    width, height = png_size(png_path)
    sidecar_path = png_path.with_suffix(".json")
    if sidecar_path.is_file():
        sidecar = json.loads(sidecar_path.read_text(encoding="utf-8"))
        assert height == sidecar["frame_height"]
        assert width == sidecar["frame_width"] * sidecar["frame_count"]
        x, y = sidecar["anchor"]
        assert 0 <= x <= sidecar["frame_width"]
        assert 0 <= y <= sidecar["frame_height"]
        if "default_facing" in sidecar:
            assert sidecar["default_facing"] in ("left", "right"), (
                f"{key}: default_facing must be 'left' or 'right', got "
                f"{sidecar['default_facing']!r}"
            )
        for extent_key in ("left_extent", "right_extent"):
            if extent_key in sidecar:
                assert 0 <= sidecar[extent_key] <= sidecar["frame_width"], (
                    f"{key}: {extent_key} ({sidecar[extent_key]}) must sit within the "
                    f"frame (0-{sidecar['frame_width']}) — it's a distance from the "
                    f"anchor, not a coordinate."
                )
        for name, state in sidecar["states"].items():
            assert state["start"] + state["count"] <= sidecar["frame_count"], (
                f"{key}: battle state '{name}' references frames past the end of the sheet"
            )
    else:
        assert height == manifest["frame_height"]
        assert width == manifest["frame_width"] * manifest["frame_count"]


@pytest.mark.parametrize("entity_id", ENTITY_IDS)
def test_entity_idle_sheet_exists_and_matches_its_contract(entity_id: str) -> None:
    """Bonded Entities can now be sized via an optional idle.json beside
    idle.png (same _load_sidecar() shape battle.json/overworld.json
    use) — duelist_sprite.gd falls back to the original hardcoded
    32x32-per-frame, 2-frame contract when the sidecar is absent. Either
    way the PNG must actually be 2 frames of whatever size is declared:
    a mismatch renders a sliver, silently, of whichever frame the fixed
    region_rect happens to land on."""
    png_path = ASSETS / "entities" / entity_id / "idle.png"
    assert png_path.is_file(), (
        f"entities.json declares '{entity_id}' but {png_path} does not exist"
    )
    width, height = png_size(png_path)
    sidecar_path = png_path.with_suffix(".json")
    if sidecar_path.is_file():
        sidecar = json.loads(sidecar_path.read_text(encoding="utf-8"))
        frame_w = int(sidecar.get("frame_width", 32))
        frame_h = int(sidecar.get("frame_height", 32))
        assert (width, height) == (frame_w * 2, frame_h), (
            f"{entity_id}/idle.png is {width}x{height}, expected "
            f"{frame_w * 2}x{frame_h} (2 frames of {frame_w}x{frame_h} per idle.json)"
        )
    else:
        assert (width, height) == (64, 32), (
            f"{entity_id}/idle.png is {width}x{height}, expected 64x32 (2 frames of 32x32)"
        )


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
