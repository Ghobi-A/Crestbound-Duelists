"""Route topology and data references; runtime behaviour lives in route_smoke."""
import json
from pathlib import Path
from test_world_locations import walkable, reachable, DIRS
ROOT = Path(__file__).resolve().parents[1]
WORLD = json.loads((ROOT/'game/world/locations.json').read_text())['locations']
ROUTE = WORLD['route_01']


def test_route_dimensions_and_bidirectional_safe_spawns():
    assert len(ROUTE['rows']) == 35 and all(len(row) == 60 for row in ROUTE['rows'])
    for source, dest in [('greymere','route_01'),('route_01','greymere')]:
        door = next(d for d in WORLD[source]['doors'] if d['destination_location'] == dest)
        spawn = tuple(WORLD[dest]['spawn_points'][door['destination_spawn']]['tile'])
        assert spawn in walkable(WORLD[dest])
        assert spawn not in {tuple(d['tile']) for d in WORLD[dest]['doors']}


def test_every_trainer_and_grass_uses_valid_existing_combat_and_art():
    encounters = json.loads((ROOT/'game/data/encounters.json').read_text())
    classes = json.loads((ROOT/'game/data/classes.json').read_text())
    art = json.loads((ROOT/'game/assets/rework/characters.json').read_text())['characters']
    known = set(art) | {a for r in art.values() for a in r.get('aliases',[])}
    trainers = [n for n in ROUTE['npcs'] if 'encounter' in n]
    assert len(trainers) == 3 and len({n['id'] for n in trainers}) == 3
    ids = [n['encounter'] for n in trainers] + [e for z in ROUTE['encounter_zones'] for e in z['encounters']]
    for id in ids:
        encounter = encounters[id]
        assert encounter['location'] == 'route_01'
        assert 1 <= encounter['player_slots'] <= 3
        assert len(encounter['enemy_party']) == encounter['enemy_slots']
        for unit in encounter['enemy_party']:
            assert unit['class_id'] in classes and unit['sprite_key'] in known


def test_optional_clearing_chest_and_encounter_terrain_are_reachable():
    cells = walkable(ROUTE)
    seen = reachable(tuple(ROUTE['spawn_points']['greymere']['tile']),cells)
    chest = next(i for i in ROUTE['interactions'] if i.get('kind') == 'chest')
    assert any((chest['tile'][0]+dx,chest['tile'][1]+dy) in seen for dx,dy in DIRS)
    assert (24,26) in seen  # optional branch west of the final road bend
    assert any(ROUTE['rows'][y][x] == 'g' for x,y in seen)
    assert all(0 <= z['probability'] <= 1 and z['cooldown_steps'] >= 5 for z in ROUTE['encounter_zones'])
    items = json.loads((ROOT/'game/data/items.json').read_text())['items']
    assert chest['item'] in {i['id'] for i in items} and chest['quantity'] > 0


def test_world_builder_is_reproducible():
    import subprocess
    path = ROOT/'game/world/locations.json'
    before = path.read_bytes()
    subprocess.run(['python','tools/build_greymere_world.py'],cwd=ROOT,check=True)
    assert path.read_bytes() == before
