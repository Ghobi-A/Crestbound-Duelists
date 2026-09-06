"""Contracts for the Greymere rendering architecture and the UI system.

These pin the decisions that produce depth and a coherent interface, and
that a later change could quietly undo:

  - the compositing order that makes the overworld read as layered
  - the two-class filtering policy (pixel art hard, painted art smooth)
  - the absence of resurrected 320x180 constants
  - panels drawing through the one shared surface rather than each
    inventing their own chrome
"""

from __future__ import annotations

import re
from pathlib import Path

from gdscript_consts import constants

REPO_ROOT = Path(__file__).resolve().parents[1]
GAME = REPO_ROOT / "game"
SCRIPTS = GAME / "scripts"
LAYERS_GD = SCRIPTS / "overworld" / "environment_layers.gd"


def source(relative: str) -> str:
    return (SCRIPTS / relative).read_text(encoding="utf-8")


def test_environment_bands_composite_back_to_front() -> None:
    """Depth comes from ordering. Ground must be furthest back and
    atmosphere furthest forward, with actors between shadows and the
    foreground they pass behind.
    """
    bands = constants(LAYERS_GD)
    order = [
        "GROUND",
        "TERRAIN_TREATMENT",
        "DECAL",
        "SHADOW",
        "ACTORS",
        "FOREGROUND",
        "LIGHT",
        "ATMOSPHERE",
    ]
    values = [bands[name] for name in order]
    assert values == sorted(values), f"bands out of order: {dict(zip(order, values))}"
    assert len(set(values)) == len(values), "two bands share a z_index"


def test_props_and_characters_share_the_actor_band() -> None:
    """Godot y-sorts within a z_index. A prop on its own band would stop
    sorting against the player and characters would walk through it.
    """
    renderer = source("overworld/map_renderer.gd")
    assert "stand.z_index = EnvironmentLayers.ACTORS" in renderer
    assert "stand.y_sort_enabled = true" in renderer


def test_overworld_layers_use_named_bands_not_raw_indices() -> None:
    renderer = source("overworld/map_renderer.gd")
    for line in renderer.splitlines():
        if "_make_layer(" not in line or line.lstrip().startswith("func "):
            continue
        assert "EnvironmentLayers." in line, f"raw z_index in {line.strip()}"


def test_high_resolution_source_art_is_not_sampled_with_nearest() -> None:
    """Every consumer of the painted atlases must take the smooth filter.
    Nearest at a non-integer ratio stipples them into noise.
    """
    for relative in [
        "battle/duelist_sprite.gd",
        "presentation/battle_stage.gd",
        "art/character_presentation.gd",
        "overworld/overworld_sprite.gd",
    ]:
        text = source(relative)
        assert "use_source_art_filter" in text, f"{relative} does not smooth source art"


def test_pixel_art_consumers_stay_hard_edged() -> None:
    """Icons and authored effect sheets must not be smoothed."""
    assert "use_pixel_art_filter" in source("presentation/battle_vfx.gd")
    assert "use_pixel_art_filter" in source("ui/battle/battle_hud.gd")


def test_no_script_resurrects_a_320x180_constant() -> None:
    """The old canvas dimensions and its derived HUD rows must not come
    back as literals. `presentation_smoke` carried `position.y < 110` and
    `position.x < 160` through the migration and silently stopped
    checking anything real.
    """
    forbidden = {"320", "180", "122", "160"}
    offenders: list[str] = []
    for path in sorted(SCRIPTS.rglob("*.gd")):
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            code = line.split("#")[0]
            if "Vector2" not in code and "position" not in code and "size" not in code:
                continue
            for literal in re.findall(r"(?<![\w.])(\d{3})(?![\w.])", code):
                if literal in forbidden:
                    offenders.append(f"{path.relative_to(GAME)}:{number} -> {literal}")
    assert not offenders, "legacy canvas literals: " + "; ".join(offenders)


def test_every_screen_draws_through_the_shared_surface() -> None:
    """One interface language. A screen that filled its own background
    would drift away from the rest the moment the surface tokens change.
    """
    style = source("ui/ui_style.gd")
    for token in ("SURFACE_TOP", "SURFACE_BOTTOM", "draw_surface", "draw_scrim"):
        assert token in style, f"UiStyle lost {token}"
    # The panel body is a gradient quad, not a flat fill.
    assert "draw_polygon" in style
    assert "UiStyle.draw_surface" in source("ui/battle/unit_status_panel.gd")
    assert "UiStyle.draw_surface" in source("ui/battle/battle_hud.gd")


def test_interaction_markers_render_above_the_actors_they_label() -> None:
    """A prompt that y-sorted behind its own NPC would be worse than
    none, so markers take the foreground band explicitly.
    """
    assert "indicator.z_index = EnvironmentLayers.FOREGROUND" in source(
        "overworld/greymere.gd"
    )


def test_interaction_focus_comes_from_the_same_tile_the_button_acts_on() -> None:
    """The highlighted marker and the interact target must be derived
    from one expression, or the prompt can highlight something the
    button would not activate.
    """
    world = source("overworld/greymere.gd")
    assert world.count("_player.tile + _player.facing") >= 2
