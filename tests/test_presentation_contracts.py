"""Static integration contracts for the Godot presentation-only runtime."""

from __future__ import annotations

import json
from pathlib import Path

import yaml

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
