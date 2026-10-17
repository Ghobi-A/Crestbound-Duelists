"""Static integration contracts for the Godot presentation-only runtime."""

from __future__ import annotations

import json
import re
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
    assert '_title_label.text = "CRESTBOUND"' in boot
    assert '_subtitle_label.text = "D U E L I S T S"' in boot
    assert "extends WorldLocation" in world
    assert "WorldCatalog" in source("scripts/overworld/world_location.gd")
    assert "assets/ui/results/%s.png" in result and "key.to_upper()" in result
    # The formation panel now shows class/Crest metadata beside the
    # established portrait; there are no nonexistent icon/card paths.
    assert "_identity_label.text" in setup
    assert "assets/crests/%s/icon.png" not in setup
    assert "assets/entities/%s/card.png" not in setup


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


def test_ui_uses_the_licensed_vector_face_at_a_readable_size() -> None:
    """The interface face is IBM Plex Mono (OFL), rendered as MSDF.

    The layout is drawn at 2x-6x of 320x180, so a vector face stays crisp at
    every output size. UiStyle clamps every size to MIN_FONT_SIZE (5 logical
    px = 10 physical px at the smallest supported 640x360 output); direct
    theme overrides must respect the same floor.
    """
    project = (GAME / "project.godot").read_text(encoding="utf-8")
    assert 'theme/custom_font="res://assets/ui/fonts/IBMPlexMono-Regular.ttf"' in project
    assert (GAME / "assets/ui/fonts/OFL.txt").read_text(encoding="utf-8").startswith("Copyright")
    for weight in ("Regular", "Medium", "SemiBold"):
        imported = (GAME / f"assets/ui/fonts/IBMPlexMono-{weight}.ttf.import").read_text(encoding="utf-8")
        assert "multichannel_signed_distance_field=true" in imported
    style = source("scripts/ui/ui_style.gd")
    floor = int(re.search(r"const MIN_FONT_SIZE := (\d+)", style).group(1))
    assert floor >= 5
    assert "maxi(size, MIN_FONT_SIZE)" in style

    offenders: list[str] = []
    for path in sorted(SCRIPTS.rglob("*.gd")):
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            if "add_theme_font_size_override" not in line:
                continue
            for size in re.findall(r"\b(\d+)\b", line.split("font_size", 1)[-1]):
                if int(size) < floor:
                    offenders.append(f"{path.relative_to(GAME)}:{number} uses {size}px")
    assert not offenders, "text below the minimum size: " + "; ".join(offenders)


def test_reachable_encounters_have_authored_battle_art() -> None:
    """Every encounter the client can start must show registered art.

    Data-only encounters may still lack art (presentation_smoke reports them
    as ART_COVERAGE_GAP); once a script can set one as the pending encounter,
    each combatant needs a registered battle record rather than a fallback.
    """
    reachable = set()
    for script in SCRIPTS.rglob("*.gd"):
        reachable.update(re.findall(r'pending_encounter\s*=\s*"([a-z0-9_]+)"', script.read_text(encoding="utf-8")))
    assert reachable, "no reachable encounter found"
    encounters = json.loads((GAME / "data/encounters.json").read_text(encoding="utf-8"))
    manifest = json.loads((GAME / "assets/rework/characters.json").read_text(encoding="utf-8"))
    registry = manifest["characters"]
    native_w, native_h = manifest["native_size"]
    known = set(registry) | {alias for record in registry.values() for alias in record.get("aliases", [])}
    for encounter_id in sorted(reachable):
        encounter = encounters[encounter_id]
        for build in encounter.get("enemy_party", []):
            key = build.get("sprite_key", "")
            assert key in known, f"{encounter_id}: {build.get('name')} has no authored battle art ({key!r})"
            record = next(r for i, r in registry.items() if i == key or key in r.get("aliases", []))
            for field in ("battle_rect", "foot_anchor", "portrait_rect"):
                assert field in record, f"{key} missing {field}"
            x, y, w, h = record["battle_rect"]
            assert 0 <= x and 0 <= y and x + w <= native_w and y + h <= native_h, f"{key} crop outside atlas"
            fx, fy = record["foot_anchor"]
            assert 0 <= fx <= w and 0 <= fy <= h, f"{key} foot anchor outside crop"
