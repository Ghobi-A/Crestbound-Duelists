"""Navigation/transition obligations for every authored location, independent of renderer."""
import json
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCATIONS = json.loads((ROOT / "game/world/locations.json").read_text())["locations"]
ASSETS = json.loads((ROOT / "game/assets/environment/environment.json").read_text())["assets"]
DIRS = [(1,0),(-1,0),(0,1),(0,-1)]

def walkable(location):
    rows = location["rows"]
    cells = {(x,y) for y,row in enumerate(rows) for x,c in enumerate(row) if c not in "#~_"}
    for item in location["props"]:
        x,y = item["tile"]
        dx,dy,w,h = ASSETS[item["asset"]]["collision"]
        cells -= {(i,j) for i in range(x+dx,x+dx+w) for j in range(y+dy,y+dy+h)}
    cells -= {tuple(x["tile"]) for x in location["doors"]+location["npcs"]}
    return cells

def reachable(start,cells):
    seen={start};queue=deque([start])
    while queue:
        x,y=queue.popleft()
        for dx,dy in DIRS:
            next=(x+dx,y+dy)
            if next in cells and next not in seen: seen.add(next);queue.append(next)
    return seen

def test_all_doors_residents_and_inspections_are_reachable():
    for id,location in LOCATIONS.items():
        cells=walkable(location)
        for name,spawn in location["spawn_points"].items():
            start=tuple(spawn["tile"])
            assert start in cells,(id,name,"blocked spawn")
            seen=reachable(start,cells)
            for item in location["doors"]+location["npcs"]+location["interactions"]:
                x,y=item["tile"]
                assert any((x+dx,y+dy) in seen for dx,dy in DIRS),(id,name,item,"unreachable")

def test_door_destinations_and_return_spawns_exist():
    for location in LOCATIONS.values():
        for door in location["doors"]:
            destination=LOCATIONS[door["destination_location"]]
            assert door["destination_spawn"] in destination["spawn_points"]
            assert door["return_spawn"] in location["spawn_points"]
            assert door["destination_scene"]==destination["scene"]
            assert (ROOT/"game"/destination["scene"].removeprefix("res://")).is_file()
    assert sum(x["interior"] for x in LOCATIONS.values())>=3

def test_art_regions_and_footprints_have_valid_shapes():
    import struct
    for key,a in ASSETS.items():
        p=ROOT/"game"/a["sheet"].removeprefix("res://")
        w,h=struct.unpack(">II",p.read_bytes()[16:24])
        x,y,rw,rh=a["region"]
        assert min(x,y)>=0 and x+rw<=w and y+rh<=h,key
        assert 0<=a["anchor"][0]<=rw and 0<=a["anchor"][1]<=rh,key
