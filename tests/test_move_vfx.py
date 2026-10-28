"""Authored battle effects: every move, Crest awakening and Brace has one,
reproducible and well formed."""
import importlib.util
import json
from pathlib import Path

import numpy as np
import yaml
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("build_vfx", ROOT / "tools/build_vfx.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)

KEYS = sorted({move["vfx_key"] for move in yaml.safe_load((ROOT / "data/moves.yaml").read_text())["moves"]})
CRESTS = sorted(builder.crest_ids())
ALL = KEYS + CRESTS + sorted(builder.ACTIONS)


def _load(key):
    out = builder.out_dir(key)
    sidecar = json.loads((out / f"{key}.json").read_text())
    layers = {"front": np.asarray(Image.open(out / f"{key}.png").convert("RGBA"))}
    if "behind" in sidecar:
        layers["behind"] = np.asarray(Image.open(out / sidecar["behind"]).convert("RGBA"))
    return sidecar, layers


def test_every_move_crest_and_brace_has_an_authored_effect_and_source():
    for key in ALL:
        assert (builder.out_dir(key) / f"{key}.png").exists(), key
        assert (builder.SOURCES / key / "manifest.json").exists(), key
    assert {p.name for p in builder.SOURCES.iterdir() if p.is_dir()} == set(ALL)
    # BattleVfx looks these up by category root.
    assert all(builder.out_dir(c).name == "awakening" for c in CRESTS)
    assert builder.out_dir("brace").name == "actions"


def test_effects_rebuild_identically():
    paths = sorted(builder.VFX.glob("*/*.png")) + sorted(builder.VFX.glob("*/*.json"))
    before = {p: p.read_bytes() for p in paths}
    builder.main()
    assert {p: p.read_bytes() for p in paths} == before


def test_layers_share_frames_and_fit_the_runtime_contract():
    for key in ALL:
        sidecar, layers = _load(key)
        w, h, count, fps = sidecar["frame_width"], sidecar["frame_height"], sidecar["frame_count"], sidecar["fps"]
        for layer in layers.values():
            assert layer.shape[:2] == (h, w * count), key
            assert layer.shape[1] <= 4096, key
        # BattleVfx clamps an effect to 1 s; impact must land inside it.
        assert count / fps <= 1.0, key
        assert 0.0 <= sidecar["impact"] <= min(0.4, count / fps), key
        # The anchor is the target's feet, which may lie outside an effect
        # that plays at chest height.
        assert sidecar["anchor_to"] == "feet" and len(sidecar["anchor"]) == 2, key
        assert sum((layer[:, :, 3] >= 128).sum() for layer in layers.values()) > 0, key


def test_runtime_lands_damage_on_the_effect_impact():
    presentation = (ROOT / "game/scripts/presentation/battle_presentation.gd").read_text()
    vfx = (ROOT / "game/scripts/presentation/battle_vfx.gd").read_text()
    assert "BattleVfx.impact_delay(key)" in presentation
    assert 'target.team == "player"' in presentation
    assert "_ground_light" in vfx and "BLEND_MODE_ADD" in vfx
    # Brace and awakenings stand on their unit like move effects.
    assert 'play_effect("brace", guard.effect_origin()' in presentation
    assert "bearer.position, false, bearer.z_index" in presentation
