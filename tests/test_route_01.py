"""Route topology and data references; runtime behaviour lives in route_smoke."""

import json
from pathlib import Path

from test_world_locations import DIRS, reachable, walkable

ROOT = Path(__file__).resolve().parents[1]
WORLD = json.loads((ROOT / "game/world/locations.json").read_text())["locations"]
ROUTE = WORLD["route_01"]


def test_route_dimensions_and_bidirectional_safe_spawns():
    assert len(ROUTE["rows"]) == 35 and all(len(row) == 60 for row in ROUTE["rows"])
    for source, dest in [("greymere", "route_01"), ("route_01", "greymere")]:
        exit = next(
            d for d in WORLD[source]["exits"] if d["destination_location"] == dest
        )
        spawn = tuple(WORLD[dest]["spawn_points"][exit["destination_spawn"]]["tile"])
        assert spawn in walkable(WORLD[dest])
        # Arrival is clear of the far side's own exit strip, so walking in
        # never bounces you straight back.
        far_tiles = {tuple(t) for d in WORLD[dest]["exits"] for t in d["tiles"]}
        assert spawn not in far_tiles
        assert min(abs(spawn[0] - t[0]) + abs(spawn[1] - t[1]) for t in far_tiles) >= 2


def test_exits_span_the_full_road_width_and_lead_off_the_map():
    """Every tile of a road mouth is an exit, each walkable, each facing off
    the edge into solid ground (so the exit is the only way through)."""
    for name in ("greymere", "route_01"):
        world = WORLD[name]
        for exit in world["exits"]:
            dx, dy = exit["direction"]
            for x, y in exit["tiles"]:
                assert (x, y) in walkable(world), (name, x, y)
                assert (x + dx, y + dy) not in walkable(world), (name, x, y)
            road = [world["rows"][y][x] for x, y in exit["tiles"]]
            assert len(set(road)) == 1 and road[0] in ":,", (name, road)


def test_every_trainer_and_grass_uses_valid_existing_combat_and_art():
    encounters = json.loads((ROOT / "game/data/encounters.json").read_text())
    classes = json.loads((ROOT / "game/data/classes.json").read_text())
    art = json.loads((ROOT / "game/assets/rework/characters.json").read_text())[
        "characters"
    ]
    known = set(art) | {a for r in art.values() for a in r.get("aliases", [])}
    # Three trainers and the optional boss, Old Greymaw, in its hidden den.
    trainers = [n for n in ROUTE["npcs"] if "encounter" in n]
    assert len(trainers) == 4 and len({n["id"] for n in trainers}) == 4
    assert [n["id"] for n in trainers if n["id"] == "greymaw_den"] == ["greymaw_den"]
    ids = [n["encounter"] for n in trainers] + [
        e for z in ROUTE["encounter_zones"] for e in z["encounters"]
    ]
    for id in ids:
        encounter = encounters[id]
        assert encounter["location"] == "route_01"
        assert 1 <= encounter["player_slots"] <= 3
        assert len(encounter["enemy_party"]) == encounter["enemy_slots"]
        for unit in encounter["enemy_party"]:
            assert unit["class_id"] in classes and unit["sprite_key"] in known


def test_optional_clearing_chest_and_encounter_terrain_are_reachable():
    cells = walkable(ROUTE)
    seen = reachable(tuple(ROUTE["spawn_points"]["greymere"]["tile"]), cells)
    chest = next(i for i in ROUTE["interactions"] if i.get("kind") == "chest")
    assert any(
        (chest["tile"][0] + dx, chest["tile"][1] + dy) in seen for dx, dy in DIRS
    )
    assert (24, 26) in seen  # optional branch west of the final road bend
    assert any(ROUTE["rows"][y][x] == "g" for x, y in seen)
    assert all(
        0 <= z["probability"] <= 1 and z["cooldown_steps"] >= 5
        for z in ROUTE["encounter_zones"]
    )
    items = json.loads((ROOT / "game/data/items.json").read_text())
    assert chest["item"] in items and chest["quantity"] > 0


def test_world_builder_is_reproducible():
    import subprocess

    path = ROOT / "game/world/locations.json"
    before = path.read_bytes()
    subprocess.run(["python", "tools/build_greymere_world.py"], cwd=ROOT, check=True)
    assert path.read_bytes() == before


def test_authored_fences_and_rocks_block_movement():
    cells = walkable(ROUTE)
    assert ROUTE["rows"][22][8] == "|" and (8, 22) not in cells
    assert ROUTE["rows"][15][21] == "r" and (21, 15) not in cells


def test_route_trainers_have_distinct_alpha_art_with_four_facings():
    from PIL import Image

    art = json.loads((ROOT / "game/assets/rework/characters.json").read_text())[
        "characters"
    ]
    crops = set()
    for key in ("route01_rowan", "route01_squire", "route01_challenger"):
        record = art[key]
        assert record["colour_key"] == "alpha"
        crops.add(tuple(record["battle_rect"]))
        image = Image.open(
            ROOT / "game" / record["overworld"]["atlas"].removeprefix("res://")
        )
        assert image.mode == "RGBA" and image.getextrema()[3][0] == 0
        w, h = record["overworld"]["frame_size"]
        assert image.size == (w * 4, h)
        for facing in range(4):
            assert image.crop((facing * w, 0, (facing + 1) * w, h)).getbbox()
    assert len(crops) == 3
