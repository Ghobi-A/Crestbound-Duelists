"""The opening movie, "The Last Accord": a well-formed, reproducible timeline."""
import importlib.util
import json
from itertools import pairwise
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game"
TIMELINE = json.loads((GAME / "data/cinematics/opening_the_last_accord.json").read_text())
ASSETS = GAME / "assets/cinematics/opening"
spec = importlib.util.spec_from_file_location("build_cinematic", ROOT / "tools/build_cinematic.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


def test_timeline_runs_90_to_125_seconds_in_order():
    assert 90.0 <= TIMELINE["duration"] <= 125.0
    starts = [shot["start"] for shot in TIMELINE["shots"]]
    assert starts == sorted(starts)
    for shot in TIMELINE["shots"]:
        assert shot["start"] + shot["duration"] <= TIMELINE["duration"], shot["id"]
    for block in TIMELINE["narration"] + TIMELINE["titles"]:
        assert 0.0 <= block["start"] < block["end"] <= TIMELINE["duration"]


def test_every_referenced_asset_exists():
    for shot in TIMELINE["shots"]:
        assert (ASSETS / f"{shot['image']}.png").exists(), shot["id"]
        for element in shot.get("elements", []):
            if "key" in element:
                assert (ASSETS / f"{element['key']}.png").exists(), element["key"]


def test_narration_lines_never_overlap_and_each_has_a_voice_slot():
    lines = TIMELINE["narration"]
    for before, after in pairwise(lines):
        assert before["end"] <= after["start"], after["id"]
    voices = {cue["id"] for cue in TIMELINE["cues"] if cue["kind"] == "voice"}
    assert voices == {f"opening/{line['id']}" for line in lines}


def test_audio_cues_follow_the_router_naming_contract():
    allowed = {"music", "music_stop", "voice", "world", "ui", "battle"}
    for cue in TIMELINE["cues"] + TIMELINE["end_cues"]:
        assert cue["kind"] in allowed, cue
        assert cue["id"].replace("/", "").replace("_", "").isalnum(), cue
    music = {cue["id"] for cue in TIMELINE["cues"] if cue["kind"] == "music"}
    assert "opening_theme" in music


def test_cues_are_documented_for_the_audio_team():
    doc = (ROOT / "docs/rework/OPENING_THE_LAST_ACCORD.md").read_text()
    for cue in TIMELINE["cues"]:
        name = cue["id"].split("/")[-1]
        assert name in doc, cue["id"]


def test_assets_rebuild_identically():
    paths = sorted(ASSETS.glob("*.png")) + sorted(ASSETS.glob("*.json"))
    before = {p: p.read_bytes() for p in paths}
    builder.main()
    assert {p: p.read_bytes() for p in paths} == before


def test_movie_is_presentation_only_and_wired_into_the_boot_flow():
    forbidden = {"damage", "power", "accuracy", "cooldown", "status_chance"}

    def keys(value):
        if isinstance(value, dict):
            for key, item in value.items():
                yield key
                yield from keys(item)
        elif isinstance(value, list):
            for item in value:
                yield from keys(item)

    assert forbidden.isdisjoint(keys(TIMELINE))
    boot = (GAME / "scripts/ui/boot_screen.gd").read_text()
    assert "Watch Opening" in boot and "OPENING_SCENE" in boot
    player = (GAME / "scripts/cinematics/cinematic_player.gd").read_text()
    assert "AudioRouter.play_voice" in player and "skip()" in player
