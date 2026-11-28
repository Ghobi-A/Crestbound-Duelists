"""Gameplay sound effects: every cue the game asks for has a file, and the
build that makes them behaves (see tools/build_gameplay_audio.py)."""
from __future__ import annotations

import importlib.util
import json
import re
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game"
AUDIO = GAME / "assets/audio"
MANIFEST = json.loads((ROOT / "tools/audio_sources/gameplay_sfx.json").read_text())
spec = importlib.util.spec_from_file_location("build_gameplay_audio", ROOT / "tools/build_gameplay_audio.py")
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)
ROOTS = {"ui": AUDIO / "sfx/ui", "world": AUDIO / "sfx/world", "battle": AUDIO / "sfx/battle",
         "ambience": AUDIO / "ambience"}


def resolves(category: str, cue: str) -> bool:
    """AudioRouter's rule: the cue's own file, or numbered variants from _1."""
    folder = ROOTS[category]
    return (folder / f"{cue}.ogg").is_file() or (folder / f"{cue}_1.ogg").is_file()


def _literal_calls() -> set[tuple[str, str]]:
    calls = set()
    pattern = re.compile(r'AudioRouter\.play_sfx\("(ui|world|battle)", "([a-z_]+)"')
    for path in (GAME / "scripts").rglob("*.gd"):
        if "tools" in path.parts:
            continue
        calls.update(pattern.findall(path.read_text(encoding="utf-8")))
    return calls


def test_every_literal_cue_in_the_game_has_a_sound():
    calls = _literal_calls()
    assert ("ui", "confirm") in calls and ("battle", "block") in calls
    missing = sorted(f"{c}/{q}" for c, q in calls if not resolves(c, q))
    assert not missing, missing


def test_every_computed_cue_has_a_sound():
    # Footsteps by surface (WorldLocation.surface_at), attacks by impact kind,
    # and the result stings (ResultPresentation plays the result key).
    for surface in ("cobble", "dirt", "grass", "wood"):
        assert resolves("world", f"step_{surface}"), surface
        assert (ROOTS["world"] / f"step_{surface}_2.ogg").is_file(), "footsteps need variants"
    for kind in ("physical", "magic"):
        assert resolves("battle", kind) and resolves("battle", f"hit_{kind}"), kind
    assert resolves("battle", "heavy_physical") and resolves("battle", "hit_heavy")
    for result in ("victory", "defeat"):
        assert resolves("battle", result)
    surfaces = (GAME / "scripts/overworld/world_location.gd").read_text()
    assert all(f'"{s}"' in surfaces for s in ("cobble", "dirt", "grass", "wood"))


def test_every_move_sound_exists():
    # Creature moves name their own battle cue (moves.yaml `sfx`), played by
    # BattlePresentation in place of the generic swing.
    import loaders

    named = {move_id: move["sfx"] for move_id, move in loaders.load_moves().items() if move.get("sfx")}
    assert {"greymaw_pounce", "wisp_flicker", "husk_slam", "anchor_pulse", "choir_requiem"} <= set(named)
    missing = sorted(f"{move_id}: battle/{cue}" for move_id, cue in named.items() if not resolves("battle", cue))
    assert not missing, missing
    exported = json.loads((GAME / "data/moves.json").read_text(encoding="utf-8"))
    assert all(exported[move_id].get("sfx") == cue for move_id, cue in named.items()), "re-run export_game_data.py"


def test_every_location_ambience_exists():
    locations = json.loads((GAME / "world/locations.json").read_text())["locations"]
    ids = {str(loc.get("ambience_id", "")) for loc in locations.values()}
    assert ids == {"greymere", "interior", "route", "court", "civara"}
    assert all(resolves("ambience", cue) for cue in ids)


def test_manifest_outputs_exist_and_are_imported():
    for cue in MANIFEST["cues"]:
        source = ROOT / "tools/audio_sources/sfx/gameplay" / (cue["id"].replace("/", "__") + ".mp3")
        assert source.is_file(), cue["id"]
        for out in build.outputs_for(cue):
            assert out.is_file(), out
            assert out.with_suffix(".ogg.import").is_file(), f"{out.name} not imported by Godot"


def test_router_never_stacks_and_varies_repeats():
    router = (GAME / "scripts/presentation/audio_router.gd").read_text()
    for needle in ("MIN_INTERVAL_MS", "MAX_SFX_VOICES", "pitch_scale", "_last_variant", "loop = true"):
        assert needle in router, needle


def test_footfalls_are_found_and_sliced_evenly():
    rate = build.RATE
    take = np.zeros((rate * 3, 1))
    noise = np.random.default_rng(7).standard_normal(int(rate * 0.08))
    for i, start in enumerate((0.2, 0.8, 1.4, 2.0, 2.6)):
        a = int(rate * start)
        take[a:a + len(noise), 0] = noise * np.exp(-np.linspace(0, 6, len(noise))) * (0.5 + 0.05 * i)
    assert [round(s / rate, 1) for s in build.footfalls(take)] == [0.2, 0.8, 1.4, 2.0, 2.6]
    steps = build.build_steps({"id": "world/test", "variants": 4, "level": -27.0}, take)
    assert len(steps) == 4
    for step in steps:
        assert abs(build.window_rms_db(step).max() - -27.0) < 0.5
        assert len(step) <= rate * build.STEP_LENGTH + 1


def test_loops_are_seamless_and_tamed():
    rate = build.RATE
    t = np.arange(rate * 10) / rate
    bed = np.stack([0.05 * np.sin(2 * np.pi * 220 * t)] * 2, axis=1)
    bed[rate * 5: rate * 5 + 200] = 0.9  # a sudden loud pop
    loop = build.build_loop({"level": -32.0}, bed)
    assert len(loop) == len(bed) - int(rate * build.LOOP_CROSSFADE)
    assert np.abs(loop).max() < 10 ** ((-32.0 + build.LOOP_HEADROOM + 1.0) / 20)
    # The wrap point: the loop's end flows into its start without a jump.
    assert abs(loop[-1, 0] - loop[0, 0]) < 0.02
