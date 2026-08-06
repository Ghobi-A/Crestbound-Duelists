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

import json
import re
import struct
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
CONTROLLER_GD = REPO_ROOT / "game" / "scripts" / "battle" / "battle_controller.gd"
HUD_GD = REPO_ROOT / "game" / "scripts" / "ui" / "battle" / "battle_hud.gd"
BACKGROUND_PNG = REPO_ROOT / "game" / "assets" / "battle" / "backgrounds" / "hollow_court.png"
METRICS_GD = REPO_ROOT / "game" / "scripts" / "core" / "presentation_metrics.gd"
ASSETS = REPO_ROOT / "game" / "assets"


def _int_const(source: str, name: str) -> int:
    """A constant is either a literal or a `PresentationMetrics.SOMETHING`
    reference — resolve either way rather than requiring every constant to
    be a locally-duplicated literal, which is exactly what
    PresentationMetrics exists to avoid."""
    match = re.search(rf"const {name} := (\d+)", source)
    if match:
        return int(match.group(1))
    ref = re.search(rf"const {name} := PresentationMetrics\.(\w+)", source)
    assert ref, f"Could not locate {name}"
    metrics_source = METRICS_GD.read_text(encoding="utf-8")
    metrics_match = re.search(rf"const {ref.group(1)} := (\d+)", metrics_source)
    assert metrics_match, f"Could not locate PresentationMetrics.{ref.group(1)}"
    return int(metrics_match.group(1))


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
        r"bottom\.position = Vector2\(0, (\d+|PresentationMetrics\.\w+)\)", hud_source
    )
    assert match, "Could not locate the bottom panel's Y position in battle_hud.gd"
    raw_y = match.group(1)
    if raw_y.isdigit():
        panel_y = int(raw_y)
    else:
        metrics_source = METRICS_GD.read_text(encoding="utf-8")
        metrics_match = re.search(rf"const {raw_y.split('.')[1]} := (\d+)", metrics_source)
        assert metrics_match, f"Could not locate {raw_y}"
        panel_y = int(metrics_match.group(1))

    assert background_height == panel_y, (
        "The generated background height must equal the HUD bottom panel's Y "
        "position, or a seam shows between the floor and the panel."
    )


def test_generated_background_matches_declared_height() -> None:
    controller_source = CONTROLLER_GD.read_text(encoding="utf-8")
    background_height = _int_const(controller_source, "BACKGROUND_HEIGHT")
    metrics_source = METRICS_GD.read_text(encoding="utf-8")
    canvas_match = re.search(r"const CANVAS_SIZE := Vector2i\((\d+),\s*(\d+)\)", metrics_source)
    assert canvas_match, "Could not locate PresentationMetrics.CANVAS_SIZE"
    canvas_width = int(canvas_match.group(1))
    width, height = png_size(BACKGROUND_PNG)
    assert width == canvas_width
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
    metrics_source = METRICS_GD.read_text(encoding="utf-8")
    canvas_match = re.search(r"const CANVAS_SIZE := Vector2i\((\d+),\s*(\d+)\)", metrics_source)
    assert canvas_match, "Could not locate PresentationMetrics.CANVAS_SIZE"
    arena_width = float(canvas_match.group(1))
    assert player_x < arena_width / 2 < enemy_x, (
        "Player and enemy formation centres must sit on opposite halves "
        "of the arena so the two sides read as opposing at a glance."
    )


def test_front_row_spread_clears_the_widest_authored_sprite_pair() -> None:
    """This is the actual bug that motivated the 640x360 migration: a
    spread narrower than the sprites standing in it. Doubling the old
    320x180-era spread constants verbatim would have reproduced it
    exactly (every authored sidecar is ~88px tall and 74-118px wide
    post-migration; the old spread values, even doubled, are well under
    that). Guard it directly, per team — units only ever stage against
    their own team's roster (stage_position() looks up
    runtime.player_units/enemy_units separately), so the correct bound
    is the worst adjacent pair *within* a team, not across both, which
    would over-count a pairing (e.g. the widest enemy next to the
    widest player) that can never actually appear on screen together."""
    source = CONTROLLER_GD.read_text(encoding="utf-8")
    match = re.search(r"var spread := ([\d.]+) if count < 3 else ([\d.]+)", source)
    assert match, "Could not locate the count-based spread expression in stage_position()"
    front_spread_many = float(match.group(2))

    def widest_pair_bound(glob_pattern: str) -> float:
        widths = sorted(
            (json.loads(p.read_text(encoding="utf-8"))["frame_width"]
             for p in ASSETS.glob(glob_pattern)),
            reverse=True,
        )
        assert len(widths) >= 2, f"Expected at least 2 sidecars matching {glob_pattern}"
        return (widths[0] + widths[1]) / 2.0

    worst_pair = max(
        widest_pair_bound("characters/**/battle.json"),
        widest_pair_bound("enemies/**/battle.json"),
    )

    assert front_spread_many > worst_pair, (
        f"Front-row spread ({front_spread_many}) does not clear the widest "
        f"same-team sidecar pairing ({worst_pair * 2}px combined, needs > "
        f"{worst_pair}px) — two adjacent front-row units could overlap."
    )
