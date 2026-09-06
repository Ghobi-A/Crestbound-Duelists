"""Static integration contracts for the Godot presentation-only runtime."""

from __future__ import annotations

import json
import re
from pathlib import Path

import yaml

from gdscript_consts import constants

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game"
SCRIPTS = GAME / "scripts"


def source(relative: str) -> str:
    return (GAME / relative).read_text(encoding="utf-8")


def test_every_yaml_move_vfx_key_resolves_through_runtime_key_lookup() -> None:
    moves = yaml.safe_load((ROOT / "data/moves.yaml").read_text())["moves"]
    keys = [move["vfx_key"] for move in moves]
    assert len(keys) == len(set(keys))
    assert all(key and "/" not in key and ".." not in key for key in keys)
    vfx = source("scripts/presentation/battle_vfx.gd")
    assert 'str(move.get("vfx_key", ""))' in source(
        "scripts/presentation/battle_presentation.gd"
    )
    assert 'root + key + ".png"' in vfx


def test_vfx_contract_prefers_authored_art_and_has_missing_fallback() -> None:
    vfx = source("scripts/presentation/battle_vfx.gd")
    assert "VisualAsset.sidecar_for(path)" in vfx
    assert 'if path != ""' in vfx
    assert "_play_fallback" in vfx
    sequencer = source("scripts/presentation/battle_presentation.gd")
    assert 'if action.kind != "move"' in sequencer
    assert 'target = event.get("target", target)' in sequencer


def test_invalid_sidecars_degrade_to_defaults() -> None:
    loader = source("scripts/art/visual_asset.gd")
    assert "malformed sidecar" in loader
    assert "return {}" in loader
    assert "positive_size" in loader and "fallback" in loader


def test_entity_optional_states_fall_back_to_idle() -> None:
    sprite = source("scripts/battle/duelist_sprite.gd")
    assert '_entity_states.get(_entity_state, _entity_states.get("idle", {}))' in sprite
    assert '_entity_state = state if _entity_states.has(state) else "idle"' in sprite


def test_awakening_lookup_is_crest_id_driven() -> None:
    presentation = source("scripts/presentation/battle_presentation.gd")
    assert "vfx.play_effect(unit.crest_id" in presentation
    assert '"res://assets/vfx/awakening/"' in source(
        "scripts/presentation/battle_vfx.gd"
    )


def test_optional_focal_assets_have_runtime_fallbacks() -> None:
    boot = source("scripts/ui/boot_screen.gd")
    setup = source("scripts/ui/battle/party_setup.gd")
    world = source("scripts/overworld/greymere.gd")
    result = source("scripts/presentation/result_presentation.gd")
    assert "assets/ui/title_mark.png" in boot and "CRESTBOUND DUELISTS" in boot
    assert "assets/landmarks/greymere_court_arch.png" in world
    assert "if not ResourceLoader.exists(path):\n\t\treturn" in world
    assert "assets/ui/results/%s.png" in result and "key.to_upper()" in result
    assert "_optional_texture" in setup


def test_audio_missing_files_are_cached_and_silent() -> None:
    audio = source("scripts/presentation/audio_router.gd")
    assert "_missing[path] = true" in audio
    assert "if not has_cue" in audio
    assert "push_warning" not in audio and "push_error" not in audio


def test_presentation_sidecars_cannot_duplicate_combat_mechanics() -> None:
    forbidden = {"damage", "power", "accuracy", "status_chance", "cooldown"}
    for path in (GAME / "assets").rglob("*.json"):
        if not any(part in {"vfx", "backgrounds", "entities", "landmarks"} for part in path.parts):
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        assert forbidden.isdisjoint(data), f"{path} contains combat data"


def test_scene_changes_use_semantic_transition_gateway() -> None:
    for relative in [
        "scripts/ui/boot_screen.gd",
        "scripts/overworld/greymere.gd",
        "scripts/battle/battle_controller.gd",
    ]:
        assert "SceneTransition.change_scene" in source(relative)


def test_pixel_accent_font_is_only_used_at_whole_multiples() -> None:
    """The 8px bitmap face is now an accent, not the interface font.

    It survives only integral rescaling — below native, whole pixel rows
    vanish (party setup once rendered "ACTIVE" as "NCTIVE"); at a
    fractional multiple one letter's stems differ in weight from the
    next. The scalable serif has no such constraint, so the rule applies
    to the pixel roles alone.
    """
    fnt = (GAME / "assets/ui/crestbound_font.fnt").read_text(encoding="utf-8")
    native = int(re.search(r"\bsize=(\d+)", fnt).group(1))

    typography = (SCRIPTS / "ui" / "typography.gd").read_text(encoding="utf-8")
    assert f"const PIXEL_NATIVE := {native}" in typography

    sizes = dict(
        re.findall(r"Role\.([A-Z_]+):\s*(\d+)", typography)
    )
    pixel_roles = re.findall(r"const _PIXEL_ROLES := \[([^\]]*)\]", typography)
    assert pixel_roles, "Typography does not declare which roles are pixel"
    names = re.findall(r"Role\.([A-Z_]+)", pixel_roles[0])
    assert names, "no pixel roles declared"
    for name in names:
        size = int(sizes[name])
        assert size % native == 0 and size >= native, (
            f"pixel role {name} is {size}px, not a whole multiple of {native}"
        )


def test_typography_is_the_only_place_that_chooses_a_size_or_a_face() -> None:
    """One hierarchy across every screen.

    Screens ask for a role. A screen that set its own `font_size` or
    loaded its own face would drift away from the rest the first time the
    scale changed — which is exactly how the old interface ended up with
    six ad-hoc sizes between 6 and 14.
    """
    offenders: list[str] = []
    for path in sorted(SCRIPTS.rglob("*.gd")):
        if path.name == "typography.gd":
            continue
        text = path.read_text(encoding="utf-8")
        for number, line in enumerate(text.splitlines(), 1):
            code = line.split("#")[0]
            if "add_theme_font_size_override" in code:
                offenders.append(f"{path.relative_to(GAME)}:{number} sets font_size directly")
            if "add_theme_font_override" in code:
                offenders.append(f"{path.relative_to(GAME)}:{number} sets a face directly")
            if ".ttf" in code or ".fnt" in code:
                offenders.append(f"{path.relative_to(GAME)}:{number} names a font file")
    assert not offenders, "text styling outside Typography: " + "; ".join(offenders)


def test_every_screen_renders_text_through_a_role() -> None:
    """`draw_string` bypasses the role vocabulary, so custom-drawn panels
    must go through `Typography.draw` instead."""
    offenders: list[str] = []
    for path in sorted(SCRIPTS.rglob("*.gd")):
        if path.name in {"typography.gd", "dialogue_box.gd", "presentation_smoke.gd"}:
            # dialogue_box measures inside `paginate`, which is handed a
            # font and size by its caller; the smoke scene re-measures the
            # same way to verify pagination.
            continue
        text = path.read_text(encoding="utf-8")
        for number, line in enumerate(text.splitlines(), 1):
            if "draw_string(" in line.split("#")[0]:
                offenders.append(f"{path.relative_to(GAME)}:{number}")
    assert not offenders, "raw draw_string outside Typography: " + "; ".join(offenders)


def test_the_serif_face_ships_with_its_licence() -> None:
    """The interface face is vendored, so its licence must travel with
    it — the Bitstream Vera terms require the notice be included."""
    fonts = GAME / "assets/ui/fonts"
    assert (fonts / "DejaVuSerif.ttf").exists()
    assert (fonts / "DejaVuSerif-Bold.ttf").exists()
    licence = (fonts / "LICENSE-DejaVu.txt").read_text(encoding="utf-8")
    assert "Bitstream" in licence and "Permission is hereby granted" in licence
