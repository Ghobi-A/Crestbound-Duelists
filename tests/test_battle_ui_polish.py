"""Structural contract for the Phase 4 battle UI / target-highlight pass.

This module doesn't re-implement Godot's rendering — it reads the actual
GDScript source (matching the style of test_battle_staging.py and
test_greymere_layout.py) to pin two things a later change could break
silently:

  - the new highlight/dim API exists on the controller and the palette
    carries the battle-HUD colour grammar it depends on
  - the gameplay files this pass was required to leave untouched
    (target_selector.gd, battle_resolver.gd, battle_unit.gd,
    encounter_runtime.gd) still contain no presentation state — no
    Color/modulate/highlight references sneaking in
"""

from __future__ import annotations

import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
BATTLE_DIR = REPO_ROOT / "game" / "scripts" / "battle"
UI_BATTLE_DIR = REPO_ROOT / "game" / "scripts" / "ui" / "battle"
PALETTE_GD = REPO_ROOT / "game" / "assets" / "placeholders" / "palette.gd"
CONTROLLER_GD = BATTLE_DIR / "battle_controller.gd"
DUELIST_SPRITE_GD = BATTLE_DIR / "duelist_sprite.gd"

UNTOUCHED_FILES = [
    UI_BATTLE_DIR / "target_selector.gd",
    BATTLE_DIR / "battle_resolver.gd",
    BATTLE_DIR / "battle_unit.gd",
    BATTLE_DIR / "encounter_runtime.gd",
]

REQUIRED_PALETTE_CONSTS = [
    "MOON_SLATE", "MOON_SLATE_DIM", "MOON_INDIGO",
    "CREST_GOLD", "CREST_GOLD_BRIGHT",
    "SPECTRAL_VIOLET", "SPECTRAL_VIOLET_DIM",
]

REQUIRED_CONTROLLER_FUNCTIONS = [
    "_clear_all_highlights", "_clear_target_dim", "_clear_target_side",
    "_refresh_target_highlights", "_apply_target_dim",
]

REQUIRED_SPRITE_FUNCTIONS = [
    "set_highlighted", "clear_highlight", "flash_confirm",
]


def test_palette_has_the_battle_hud_colour_grammar() -> None:
    source = PALETTE_GD.read_text(encoding="utf-8")
    for name in REQUIRED_PALETTE_CONSTS:
        match = re.search(rf'const {name} := Color\("([0-9a-fA-F]{{6,8}})"\)', source)
        assert match, f"palette.gd is missing {name}"
        int(match.group(1), 16)  # must be a real hex colour


def test_controller_defines_the_highlight_helpers() -> None:
    source = CONTROLLER_GD.read_text(encoding="utf-8")
    for name in REQUIRED_CONTROLLER_FUNCTIONS:
        assert re.search(rf"func {name}\(", source), f"battle_controller.gd is missing {name}()"


def test_duelist_sprite_defines_the_highlight_api() -> None:
    source = DUELIST_SPRITE_GD.read_text(encoding="utf-8")
    for name in REQUIRED_SPRITE_FUNCTIONS:
        assert re.search(rf"func {name}\(", source), f"duelist_sprite.gd is missing {name}()"


def test_controller_no_longer_hand_draws_a_static_reticle() -> None:
    """The old hardcoded Rect2(-10,-16)/Vector2(20,30) overlay box is the
    thing this phase replaced; it must not come back."""
    source = CONTROLLER_GD.read_text(encoding="utf-8")
    assert "OVERLAY_SELECTED" not in source
    assert "OVERLAY_CURSOR" not in source


def test_gameplay_files_carry_no_presentation_state() -> None:
    """target_selector.gd, battle_resolver.gd, battle_unit.gd and
    encounter_runtime.gd must stay presentation-free: no Color, no
    modulate, no *_highlight* identifiers."""
    forbidden = re.compile(r"\bColor\(|modulate|highlight", re.IGNORECASE)
    for path in UNTOUCHED_FILES:
        source = path.read_text(encoding="utf-8")
        match = forbidden.search(source)
        assert match is None, (
            f"{path.relative_to(REPO_ROOT)} contains presentation state "
            f"({match.group(0)!r}) — this phase was required to leave it untouched."
        )


def test_confirm_flash_state_is_independent_of_the_ring_tween() -> None:
    """flash_confirm must not share _highlight_tween: the controller's
    next call (opening the next unit's menu) clears that tween
    synchronously, which would kill the flash before a frame rendered it
    if the two were the same variable."""
    source = DUELIST_SPRITE_GD.read_text(encoding="utf-8")
    flash_match = re.search(r"func flash_confirm\(\).*?(?=\nfunc )", source, re.DOTALL)
    assert flash_match, "duelist_sprite.gd is missing flash_confirm()"
    assert "_highlight_tween" not in flash_match.group(0)
    assert "_confirm_tween" in flash_match.group(0)
