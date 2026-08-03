"""Presentation contract for the Hollow Court battle staging.

Phase 3A changed how units are placed on screen without touching combat
rules: `position` ("front"/"back") still means exactly what
battle_resolver.gd says it means, only the pixel coordinates changed. This
module pins the two things a future rendering change could silently break:

  - the background must reach exactly the row the HUD's opaque bottom
    panel starts at, or a seam reappears between the floor and the panel
  - front is always closer to the camera than back, for both teams alike
    (the earlier version reversed this between player and enemy)

Both are read directly out of the GDScript source, not re-implemented,
so they can only drift if someone edits the actual constants.
"""

from __future__ import annotations

import re
import struct
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
CONTROLLER_GD = REPO_ROOT / "game" / "scripts" / "battle" / "battle_controller.gd"
HUD_GD = REPO_ROOT / "game" / "scripts" / "ui" / "battle" / "battle_hud.gd"
BACKGROUND_PNG = REPO_ROOT / "game" / "assets" / "battle" / "backgrounds" / "hollow_court.png"


def _int_const(source: str, name: str) -> int:
    match = re.search(rf"const {name} := (\d+)", source)
    assert match, f"Could not locate {name}"
    return int(match.group(1))


def _float_const(source: str, name: str) -> float:
    match = re.search(rf"const {name} := ([\d.]+)", source)
    assert match, f"Could not locate {name}"
    return float(match.group(1))


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        header = handle.read(24)
    assert header[:8] == b"\x89PNG\r\n\x1a\n", f"{path} is not a PNG"
    return struct.unpack(">II", header[16:24])


def test_background_height_matches_hud_bottom_panel() -> None:
    controller_source = CONTROLLER_GD.read_text(encoding="utf-8")
    hud_source = HUD_GD.read_text(encoding="utf-8")

    background_height = _int_const(controller_source, "BACKGROUND_HEIGHT")

    match = re.search(
        r'bottom\.position = Vector2\(0, (\d+)\)', hud_source
    )
    assert match, "Could not locate the bottom panel's Y position in battle_hud.gd"
    panel_y = int(match.group(1))

    assert background_height == panel_y, (
        "The generated background height must equal the HUD bottom panel's Y "
        "position, or a seam shows between the floor and the panel."
    )


def test_generated_background_matches_declared_height() -> None:
    controller_source = CONTROLLER_GD.read_text(encoding="utf-8")
    background_height = _int_const(controller_source, "BACKGROUND_HEIGHT")
    width, height = png_size(BACKGROUND_PNG)
    assert width == 320
    assert height == background_height


def test_front_row_is_closer_to_camera_than_back_row_for_both_teams() -> None:
    """The depth convention must not differ between player and enemy —
    that mismatch was the original "inverted" bug."""
    source = CONTROLLER_GD.read_text(encoding="utf-8")
    front_y = _float_const(source, "FRONT_Y")
    back_y = _float_const(source, "BACK_Y")
    # Larger Y is lower on screen, i.e. closer to the camera/HUD.
    assert front_y > back_y, "Front row must render closer to the camera than back row."


def test_team_formations_are_on_opposite_halves_of_the_arena() -> None:
    source = CONTROLLER_GD.read_text(encoding="utf-8")
    player_x = _float_const(source, "PLAYER_CENTER_X")
    enemy_x = _float_const(source, "ENEMY_CENTER_X")
    arena_width = 320.0
    assert player_x < arena_width / 2 < enemy_x, (
        "Player and enemy formation centres must sit on opposite halves "
        "of the arena so the two sides read as opposing at a glance."
    )
