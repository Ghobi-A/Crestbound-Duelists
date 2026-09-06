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


def test_all_ui_text_uses_whole_multiples_of_the_bitmap_font() -> None:
    """`crestbound_font.fnt` is an 8px bitmap face.

    Godot rescales bitmap glyphs to any requested size, and only whole
    multiples of the native size survive intact. Below 8px whole pixel
    rows are dropped: party setup once rendered "ACTIVE" as "NCTIVE" and
    "Liora" as "L:ora". At a non-integer multiple the stems land on
    uneven pixel counts and one letter's strokes differ in weight from
    the next. Typography exists so sizes are chosen from a fixed scale.

    This checks all three ways a size reaches the renderer: a direct
    theme override, a size handed to a label helper that forwards it,
    and a `draw_string` call in a custom-drawn panel.
    """
    fnt = (GAME / "assets/ui/crestbound_font.fnt").read_text(encoding="utf-8")
    native = int(re.search(r"\bsize=(\d+)", fnt).group(1))
    assert native == 8

    scale = constants(SCRIPTS / "ui" / "typography.gd")
    assert scale["NATIVE"] == native
    named = {k: v for k, v in scale.items() if k != "NATIVE"}
    assert named, "Typography defines no sizes"
    for name, size in named.items():
        assert size % native == 0 and size >= native, (
            f"Typography.{name} is {size}px, not a whole multiple of {native}"
        )

    offenders: list[str] = []
    for path in sorted(SCRIPTS.rglob("*.gd")):
        text = path.read_text(encoding="utf-8")
        lines = text.splitlines()
        label = f"{path.relative_to(GAME)}"

        for number, line in enumerate(lines, start=1):
            for size in re.findall(
                r'add_theme_font_size_override\(\s*"font_size"\s*,\s*(\d+)', line
            ):
                if int(size) % native:
                    offenders.append(f"{label}:{number} overrides font_size to {size}px")

        # draw_string(font, pos, text, alignment, width, SIZE, colour).
        # Scanned over the whole file, not per line: these calls routinely
        # wrap, and a per-line splitter simply saw an unclosed paren and
        # skipped them — which is how a 6px caption slipped through.
        for call in re.finditer(r"draw_string\(", text):
            args = _split_call_args(text[call.end() - 1 :])
            if args is None or len(args) < 6:
                continue
            size_argument = args[5].strip()
            if size_argument.isdigit() and int(size_argument) % native:
                number = text.count("\n", 0, call.start()) + 1
                offenders.append(f"{label}:{number} draws text at {size_argument}px")

        for helper, index in _font_size_forwarding_helpers(text).items():
            for call in re.finditer(rf"\b{helper}\(", text):
                args = _split_call_args(text[call.end() - 1 :])
                if args is None or index >= len(args):
                    continue
                argument = args[index].strip()
                if argument.isdigit() and int(argument) % native:
                    number = text.count("\n", 0, call.start()) + 1
                    offenders.append(
                        f"{label}:{number} passes {argument}px to {helper}()"
                    )
    assert not offenders, "text off the type scale: " + "; ".join(offenders)


def _font_size_forwarding_helpers(text: str) -> dict[str, int]:
    """Map helper name -> index of its font-size parameter.

    Only functions that actually forward the parameter into the theme
    override count, so an unrelated `font_size` local cannot flag callers.
    """
    helpers: dict[str, int] = {}
    for match in re.finditer(r"^func (\w+)\(([^)]*)\)", text, re.MULTILINE):
        name, signature = match.group(1), match.group(2)
        parameters = [p.split(":")[0].strip() for p in signature.split(",") if p.strip()]
        if "font_size" not in parameters:
            continue
        body = text[match.end() :]
        next_func = body.find("\nfunc ")
        if next_func != -1:
            body = body[:next_func]
        if 'add_theme_font_size_override("font_size", font_size)' in body:
            helpers[name] = parameters.index("font_size")
    return helpers


def _split_call_args(text: str) -> list[str] | None:
    """Split the argument list of a call, ignoring commas nested in parens.

    `text` starts at the opening paren. Returns None if the call is not
    closed on this line.
    """
    depth = 0
    args: list[str] = []
    current = ""
    for character in text:
        if character in "([":
            depth += 1
            if depth == 1:
                continue
        elif character in ")]":
            depth -= 1
            if depth == 0:
                args.append(current)
                return args
        if depth == 1 and character == ",":
            args.append(current)
            current = ""
        else:
            current += character
    return None
