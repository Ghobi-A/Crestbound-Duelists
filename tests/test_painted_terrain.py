"""Painted outdoor terrain: reproducible inputs that never contradict collision."""
import importlib.util
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game"
PAINTED = GAME / "assets/environment/painted"
LOCATIONS = json.loads((GAME / "world/locations.json").read_text())["locations"]
spec = importlib.util.spec_from_file_location("build_painted_terrain", ROOT / "tools/build_painted_terrain.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


def painted_locations():
    return {key: value for key, value in LOCATIONS.items() if "painted" in value}


def test_greymere_town_and_outskirts_are_painted():
    assert set(painted_locations()) == {"greymere", "route_01"}
    for location in painted_locations().values():
        assert (PAINTED / f"{location['painted']['path_material']}.png").exists()
        assert not location["interior"]


def test_painted_inputs_are_reproducible():
    before = {path.name: path.read_bytes() for path in PAINTED.glob("*.png")}
    builder.main()
    after = {path.name: path.read_bytes() for path in PAINTED.glob("*.png")}
    assert before == after


def test_fields_match_map_size():
    for key, location in painted_locations().items():
        width, height = Image.open(PAINTED / f"fields_{key}.png").size
        assert (width, height) == (len(location["rows"][0]) * builder.PX_PER_TILE, len(location["rows"]) * builder.PX_PER_TILE)


def test_walkable_tiles_never_render_as_water():
    # The shader draws water above 0.62 in the G field (before at most
    # ~0.1 of edge warp); every walkable tile centre must stay well below.
    half = builder.PX_PER_TILE // 2
    for key, location in painted_locations().items():
        water = np.asarray(Image.open(PAINTED / f"fields_{key}.png"))[:, :, 1] / 255.0
        blocked = set(location.get("blocked_symbols", [])) | {"#", "~"}
        for y, row in enumerate(location["rows"]):
            for x, symbol in enumerate(row):
                if symbol in blocked or symbol == "=":
                    continue
                assert water[y * builder.PX_PER_TILE + half, x * builder.PX_PER_TILE + half] < 0.5, (key, x, y)


def test_materials_tile_seamlessly():
    for name in builder.MATERIALS:
        pixels = np.asarray(Image.open(PAINTED / f"{name}.png")).astype(float)
        wrapped = np.concatenate([pixels, pixels], axis=1)
        steps = np.abs(np.diff(wrapped, axis=1)).mean(axis=(0, 2))
        # The wrap column must look like any other column, not a seam.
        assert steps[pixels.shape[1] - 1] < steps.mean() * 2.5, name


def test_dressing_and_lighting_stay_presentation_only():
    dressing = (GAME / "scripts/overworld/painted_dressing.gd").read_text()
    # Shrubs only on forest edges, rocks only on water: never walkable ground.
    assert 'symbol == "#"' in dressing and 'symbol == "~"' in dressing
    for script in ("painted_terrain.gd", "painted_dressing.gd", "painted_atmosphere.gd"):
        source = (GAME / "scripts/overworld" / script).read_text()
        assert "_blocked[" not in source and "rows[" not in source.replace("rows[y]", "").replace("rows[c.y]", "").replace("rows[0]", "")


def test_graphics_presets_default_to_medium_on_web():
    settings = (GAME / "scripts/core/graphics_settings.gd").read_text()
    assert 'MEDIUM if OS.has_feature("web") else HIGH' in settings
    assert "user://settings.cfg" in settings


def test_every_interior_is_painted_with_its_assets():
    interiors = {key: value for key, value in LOCATIONS.items() if value["interior"]}
    assert interiors and all("painted_interior" in room for room in interiors.values())
    for asset in ("wood_floor", "stone_wall", "cobble", "rug", "plant", "sconce", "banner", "window", "bokeh_warm"):
        assert (PAINTED / f"{asset}.png").exists(), asset
    for room in interiors.values():
        # The room shader derives everything from one floor rectangle.
        floor = [(x, y) for y, row in enumerate(room["rows"]) for x, c in enumerate(row) if c in "w:"]
        xs, ys = {x for x, _ in floor}, {y for _, y in floor}
        assert len(floor) == len(xs) * len(ys), room["id"]
