"""Layout and walkability parity for the Greymere overworld.

The Greymere visual passes replace how tiles are *drawn* without changing
what they *mean*. The ASCII map in `game/scripts/overworld/greymere.gd`
stays the authoritative layout, so this module pins the gameplay contract
derived from it — walkability, interaction tiles, NPC markers, triggers and
spawn points — against a golden fixture captured before the tile-atlas
migration.

A deliberate layout change is legitimate; it just has to be an explicit
edit to `tests/data/greymere_layout_golden.json`, reviewed alongside the
map change, rather than something a rendering refactor can do silently.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
GREYMERE_GD = REPO_ROOT / "game" / "scripts" / "overworld" / "greymere.gd"
GOLDEN_PATH = Path(__file__).parent / "data" / "greymere_layout_golden.json"

# Tiles the player may interact with by facing them, and the NPC spawn
# markers. Both are read out of the script so a renamed symbol fails loudly.
INTERACTION_SYMBOLS = ("n", "D", "C")
NPC_SYMBOLS = ("E", "M")


def _read_source() -> str:
    return GREYMERE_GD.read_text(encoding="utf-8")


def _parse_map(source: str) -> list[str]:
    """Extract the MAP constant's rows in order."""
    match = re.search(r"const MAP: Array\[String\] = \[(.*?)\n\]", source, re.DOTALL)
    assert match, "Could not locate the MAP constant in greymere.gd"
    return re.findall(r'"([^"]*)"', match.group(1))


def _parse_blocking(source: str) -> list[str]:
    match = re.search(r"const BLOCKING_TILES := \[(.*?)\]", source, re.DOTALL)
    assert match, "Could not locate BLOCKING_TILES in greymere.gd"
    return re.findall(r'"([^"]*)"', match.group(1))


def _parse_vector2i(source: str, name: str) -> list[int]:
    match = re.search(rf"const {name} := Vector2i\((\d+),\s*(\d+)\)", source)
    assert match, f"Could not locate {name} in greymere.gd"
    return [int(match.group(1)), int(match.group(2))]


def _walkability_rows(rows: list[str], blocking: list[str]) -> list[str]:
    """One '.'/'#' string per map row: '.' walkable, '#' blocked.

    Mirrors `Greymere.is_walkable`, minus the NPC occupancy check, which is
    runtime state rather than layout. NPC tiles are asserted separately.
    """
    return [
        "".join("#" if char in blocking else "." for char in row) for row in rows
    ]


def _symbol_tiles(rows: list[str], symbols: tuple[str, ...]) -> dict[str, list[list[int]]]:
    found: dict[str, list[list[int]]] = {symbol: [] for symbol in symbols}
    for y, row in enumerate(rows):
        for x, char in enumerate(row):
            if char in found:
                found[char].append([x, y])
    return found


def current_layout() -> dict:
    """The layout contract as it exists in the source right now."""
    source = _read_source()
    rows = _parse_map(source)
    blocking = _parse_blocking(source)
    return {
        "width": len(rows[0]),
        "height": len(rows),
        "blocking_tiles": sorted(blocking),
        "walkability": _walkability_rows(rows, blocking),
        "interaction_tiles": _symbol_tiles(rows, INTERACTION_SYMBOLS),
        "npc_tiles": _symbol_tiles(rows, NPC_SYMBOLS),
        "spawn_default": _parse_vector2i(source, "SPAWN_DEFAULT"),
        "spawn_from_court": _parse_vector2i(source, "SPAWN_FROM_COURT"),
    }


@pytest.fixture(scope="module")
def golden() -> dict:
    return json.loads(GOLDEN_PATH.read_text(encoding="utf-8"))


@pytest.fixture(scope="module")
def layout() -> dict:
    return current_layout()


def test_map_dimensions_unchanged(layout: dict, golden: dict) -> None:
    assert (layout["width"], layout["height"]) == (golden["width"], golden["height"])


def test_map_rows_are_rectangular(layout: dict) -> None:
    assert all(len(row) == layout["width"] for row in layout["walkability"])


def test_blocking_tile_set_unchanged(layout: dict, golden: dict) -> None:
    assert layout["blocking_tiles"] == golden["blocking_tiles"]


def test_walkability_grid_unchanged(layout: dict, golden: dict) -> None:
    """The whole point: no rendering change may alter where the player can walk."""
    differences = [
        f"row {y}: {before!r} -> {after!r}"
        for y, (before, after) in enumerate(zip(golden["walkability"], layout["walkability"]))
        if before != after
    ]
    assert not differences, "Walkability changed:\n" + "\n".join(differences)


def test_interaction_tiles_unchanged(layout: dict, golden: dict) -> None:
    assert layout["interaction_tiles"] == golden["interaction_tiles"]


def test_npc_markers_unchanged(layout: dict, golden: dict) -> None:
    assert layout["npc_tiles"] == golden["npc_tiles"]


def test_each_npc_marker_is_unique(layout: dict) -> None:
    for symbol, tiles in layout["npc_tiles"].items():
        assert len(tiles) == 1, f"Expected exactly one '{symbol}' marker, found {len(tiles)}"


def test_spawn_points_unchanged(layout: dict, golden: dict) -> None:
    assert layout["spawn_default"] == golden["spawn_default"]
    assert layout["spawn_from_court"] == golden["spawn_from_court"]


def test_spawn_points_are_walkable(layout: dict) -> None:
    for name in ("spawn_default", "spawn_from_court"):
        x, y = layout[name]
        assert layout["walkability"][y][x] == ".", f"{name} spawns inside a blocked tile"


def test_court_return_tile_matches_battle_controller() -> None:
    """`SPAWN_FROM_COURT` and the battle controller's return tile are declared
    independently and must stay in sync, or the player returns to the wrong tile."""
    battle_source = (
        REPO_ROOT / "game" / "scripts" / "battle" / "battle_controller.gd"
    ).read_text(encoding="utf-8")
    match = re.search(r"const COURT_RETURN_TILE := Vector2i\((\d+),\s*(\d+)\)", battle_source)
    assert match, "Could not locate COURT_RETURN_TILE in battle_controller.gd"
    assert [int(match.group(1)), int(match.group(2))] == current_layout()["spawn_from_court"]


def test_camera_zoom_keeps_the_view_inside_the_map(layout: dict) -> None:
    """An integer zoom preserves the tile art exactly, but too low a zoom
    shows past the map edge into empty space. At 3 the camera framed
    427x240 world units against a 384x224 map and rendered the void
    around it; any zoom must keep the visible region within bounds.
    """
    from gdscript_consts import constants

    layout_gd = (
        REPO_ROOT / "game" / "scripts" / "presentation" / "presentation_layout.gd"
    )
    constants_ = constants(layout_gd)
    zoom = constants_["OVERWORLD_ZOOM"]
    canvas = constants_["CANVAS"]

    source = _read_source()
    tile = int(re.search(r"const TILE := (\d+)", source).group(1))
    map_width = layout["width"] * tile
    map_height = layout["height"] * tile

    assert zoom == int(zoom), "A fractional zoom breaks pixel alignment on tile art"
    assert canvas.x / zoom <= map_width, (
        f"view is {canvas.x / zoom:.0f} world units wide, map is only {map_width}"
    )
    assert canvas.y / zoom <= map_height, (
        f"view is {canvas.y / zoom:.0f} world units tall, map is only {map_height}"
    )
