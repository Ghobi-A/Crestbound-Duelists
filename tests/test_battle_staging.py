"""Presentation contract for the Hollow Court battle staging.

`position` ("front"/"back") still means exactly what battle_resolver.gd
says it means; only the screen coordinates changed when the canvas moved
from 320x180 to 1280x720. This module pins the things a future rendering
change could silently break:

  - the battlefield must reach exactly the row the HUD begins at, or a
    seam reappears between the floor and the panel
  - front is always closer to the camera than back, for both teams alike
    (an earlier version reversed this between player and enemy)
  - the battlefield keeps the share of the canvas the composition was
    designed around

All of these read the actual GDScript constants — including the ones
expressed as arithmetic on the canvas — so they can only drift if
someone edits the real geometry.
"""

from __future__ import annotations

import json

from pathlib import Path

from gdscript_consts import constants

REPO_ROOT = Path(__file__).resolve().parents[1]
LAYOUT_GD = REPO_ROOT / "game" / "scripts" / "presentation" / "presentation_layout.gd"
HUD_GD = REPO_ROOT / "game" / "scripts" / "ui" / "battle" / "battle_hud.gd"

LAYOUT = constants(LAYOUT_GD)


def test_canvas_is_the_migrated_resolution() -> None:
    canvas = LAYOUT["CANVAS"]
    assert (canvas.x, canvas.y) == (1280, 720)


def test_battlefield_meets_the_hud_with_no_seam() -> None:
    """The HUD's opaque panel starts exactly where the battlefield ends.

    Both are derived from the same constant now, so this checks the
    derivation rather than two numbers that happen to match.
    """
    assert LAYOUT["HUD_TOP"] == LAYOUT["BATTLE_HEIGHT"]
    assert LAYOUT["HUD_HEIGHT"] == LAYOUT["CANVAS"].y - LAYOUT["BATTLE_HEIGHT"]
    hud_source = HUD_GD.read_text(encoding="utf-8")
    # The panel positions itself from the shared rect rather than from a
    # literal, which is what keeps the two in step.
    assert "bottom.position = hud.position" in hud_source
    assert "bottom.size = hud.size" in hud_source


def test_battlefield_owns_roughly_three_quarters_of_the_canvas() -> None:
    """The composition brief: 70-75% of vertical space to the battlefield."""
    fraction = LAYOUT["BATTLE_HEIGHT"] / LAYOUT["CANVAS"].y
    assert 0.70 <= fraction <= 0.75, f"battlefield is {fraction:.1%} of the canvas"


def test_hud_is_a_smaller_share_of_the_screen_than_at_320x180() -> None:
    """Party cards and target info should occupy relatively less room.

    The old canvas gave the bottom panel 58 rows of 180 (32.2%).
    """
    share = LAYOUT["HUD_HEIGHT"] / LAYOUT["CANVAS"].y
    assert share < 58 / 180, f"HUD still takes {share:.1%} of the canvas"


def test_front_row_is_closer_to_camera_than_back_row_for_both_teams() -> None:
    """The depth convention must not differ between player and enemy —
    that mismatch was the original "inverted" bug."""
    # Larger Y is lower on screen, i.e. closer to the camera/HUD.
    assert LAYOUT["FRONT_Y"] > LAYOUT["BACK_Y"], (
        "Front row must render closer to the camera than back row."
    )


def test_rows_sit_inside_the_battlefield() -> None:
    """Both feet lines must stay above the HUD, or units stand on it."""
    for row in ("FRONT_Y", "BACK_Y"):
        assert 0 < LAYOUT[row] < LAYOUT["BATTLE_HEIGHT"], f"{row} escapes the battlefield"


def test_team_formations_are_on_opposite_halves_of_the_arena() -> None:
    player_x = LAYOUT["PLAYER_CENTER_X"]
    enemy_x = LAYOUT["ENEMY_CENTER_X"]
    midpoint = LAYOUT["CANVAS"].x / 2
    assert player_x < midpoint < enemy_x, (
        "Player and enemy formation centres must sit on opposite halves "
        "of the arena so the two sides read as opposing at a glance."
    )


def test_a_full_team_spread_stays_on_its_own_half() -> None:
    """The widest encounter must not push a unit across the midline."""
    half_span = LAYOUT["TEAM_SPAN"] / 2
    midpoint = LAYOUT["CANVAS"].x / 2
    assert LAYOUT["PLAYER_CENTER_X"] + half_span < midpoint
    assert LAYOUT["ENEMY_CENTER_X"] - half_span > midpoint


def test_combatant_height_matches_the_character_manifest() -> None:
    """The manifest drives what is drawn; the layout drives what scales
    with it (VFX, impact marks). If the two drift, effects stop matching
    the combatants they annotate.
    """
    manifest = json.loads(
        (REPO_ROOT / "game" / "assets" / "rework" / "characters.json").read_text()
    )
    assert manifest["display_height"] == LAYOUT["COMBATANT_HEIGHT"]


def test_effects_scale_with_the_combatants_they_annotate() -> None:
    ratio = LAYOUT["COMBATANT_HEIGHT"] / LAYOUT["LEGACY_COMBATANT_HEIGHT"]
    assert LAYOUT["EFFECT_SCALE"] == ratio
    assert ratio > 1, "combatants must be drawn larger than on the old canvas"
