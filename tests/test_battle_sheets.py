"""Authored battle animation sheets: reproducible, complete and stable."""
import importlib.util
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("build_battle_sheets", ROOT / "tools/build_battle_sheets.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)

CHARACTERS = json.loads((ROOT / "game/assets/rework/characters.json").read_text())["characters"]
ANIMATED = sorted(p.name for p in builder.SOURCES.iterdir() if p.is_dir())
WAVE_A = {"kai_warrior", "kai_guardian", "kai_mage", "kai_sorcerer", "kai_assassin", "kai_neutral", "almyra", "liora"}


def _sheet(name):
    sidecar = json.loads((builder.OUT / f"{name}.json").read_text())
    image = np.asarray(Image.open(builder.OUT / f"{name}.png").convert("RGBA"))
    return sidecar, image


def _frame(sidecar, image, index):
    w, h, columns = sidecar["frame_width"], sidecar["frame_height"], sidecar["columns"]
    row, column = divmod(index, columns)
    return image[row * h:(row + 1) * h, column * w:(column + 1) * w]


def test_wave_a_cast_is_animated_and_referenced():
    assert WAVE_A <= set(ANIMATED)
    for name in ANIMATED:
        assert CHARACTERS[name]["battle_sheet"] == f"res://assets/battle/cast/{name}.png"


def test_sheets_rebuild_identically():
    paths = [builder.OUT / f"{n}.{ext}" for n in ANIMATED for ext in ("png", "json")]
    before = {p: p.read_bytes() for p in paths}
    for name in ANIMATED:
        builder.build(name)
    assert {p: p.read_bytes() for p in paths} == before


def test_every_state_fits_its_sheet_and_frames_are_not_empty():
    for name in ANIMATED:
        sidecar, image = _sheet(name)
        assert set(sidecar["states"]) == set(builder.STATES)
        capacity = (image.shape[0] // sidecar["frame_height"]) * sidecar["columns"]
        for state, info in sidecar["states"].items():
            assert info["count"] >= 4 and info["start"] + info["count"] <= min(capacity, sidecar["frame_count"]), (name, state)
            for index in range(info["start"], info["start"] + info["count"]):
                assert (_frame(sidecar, image, index)[:, :, 3] >= 128).sum() > 500, (name, state, index)
        # WebGL-safe texture size.
        assert image.shape[0] <= 4096 and image.shape[1] <= 4096, name


def test_idle_loop_does_not_bob_or_slide():
    # Breathing only: the body stays within ~1 display px and the feet stay put.
    for name in ANIMATED:
        sidecar, image = _sheet(name)
        scale = 39 / sidecar["body_height"]
        idle = sidecar["states"]["idle"]
        frames = [_frame(sidecar, image, i) for i in range(idle["start"], idle["start"] + idle["count"])]
        heights = [builder.body_height(f) * scale for f in frames]
        feet = [builder.feet(f)[1] * scale for f in frames]
        assert max(heights) - min(heights) <= 1.5, (name, heights)
        assert max(feet) - min(feet) <= 1.0, (name, feet)


def test_runtime_prefers_animated_sheets_and_keeps_tweens_secondary():
    source = (ROOT / "game/scripts/battle/duelist_sprite.gd").read_text()
    assert "if _setup_animated_sprite(record):" in source
    assert 'not has_frames("attack")' in source and 'not has_frames("defeat")' in source


def test_attacks_name_a_contact_frame_and_reactions_return_to_their_pose():
    for name in ANIMATED:
        sidecar, image = _sheet(name)
        attack = sidecar["states"]["attack"]
        assert 0 <= attack["contact"] < attack["count"], name
        # Ping-pong states end (or wrap) on their first frame, so they never pop.
        hit = sidecar["states"]["hit"]
        first = _frame(sidecar, image, hit["start"])
        last = _frame(sidecar, image, hit["start"] + hit["count"] - 1)
        assert np.array_equal(first, last), name


def test_presentation_lands_damage_on_the_contact_frame():
    source = (ROOT / "game/scripts/presentation/battle_presentation.gd").read_text()
    assert "sprites[actor].contact_time()" in source
