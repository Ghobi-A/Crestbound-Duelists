"""Characters re-rendered on Kai's proportions: reproducible, framed like Kai."""
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "tools/overworld_sources"
spec = importlib.util.spec_from_file_location("rerender", ROOT / "tools/rerender_overworld_sheets.py")
rerender = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rerender)

AUTHORED = json.loads((ROOT / "game/assets/overworld/authored.json").read_text())["entries"]
CHARACTERS = json.loads((ROOT / "game/assets/rework/characters.json").read_text())["characters"]
NAMES = sorted(p.name for p in SOURCES.iterdir() if p.is_dir())


def _outputs():
    paths = [ROOT / "game/assets/overworld" / f"{name}.png" for name in NAMES if name not in rerender.TRAINERS]
    paths += [ROOT / "game" / CHARACTERS[key]["overworld"]["atlas"].removeprefix("res://") for key in rerender.TRAINERS.values()]
    return paths + [rerender.CHARACTERS]


def test_townsfolk_and_trainers_are_rerendered():
    assert set(NAMES) == {"joey", "lena", "senna", "silas", "gell", "danfor", "orrin", "ferris", "stranger",
                          "rowan", "squire", "challenger"}


def test_sheets_rebuild_identically_from_sources():
    before = {path: path.read_bytes() for path in _outputs()}
    rerender.main()
    assert {path: path.read_bytes() for path in _outputs()} == before


def test_rerendered_bodies_fill_the_frame_like_kai():
    # Kai's authored sheet sets the framing: body height / frame height.
    kai = AUTHORED["kai_warrior"]
    kai_fill = kai["body_height"] / kai["frames"]["down"][0]["rect"][3]
    for name in NAMES:
        if name in rerender.TRAINERS:
            record = CHARACTERS[rerender.TRAINERS[name]]["overworld"]
            fill = record["body_height"] / record["frame_size"][1]
        else:
            entry = AUTHORED[name]
            fill = entry["body_height"] / entry["frames"]["down"][0]["rect"][3]
        assert abs(fill - kai_fill) < 0.1, (name, round(fill, 2), round(kai_fill, 2))


def test_rerendered_npcs_keep_no_superseded_walk_sources():
    walks = {path.stem.rsplit("-", 1)[0] for path in (ROOT / "tools/walk_sources").glob("*.png")}
    assert not walks & set(NAMES)
