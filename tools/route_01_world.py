"""Authored Route 01 layout; compiled by build_greymere_world.py."""

from build_greymere_world import npc, prop, rect, spawn


def add_route(locations):
    town = locations["greymere"]
    town["spawn_points"]["route_return"] = spawn(17, 29, (0, -1))
    # Edge exits: walking outward off any tile of a road mouth travels, so
    # the whole visible width of the road works and no facing or button is
    # needed. Arrival spawns sit two tiles inside, so nobody bounces back.
    # A signpost at the town's south mouth marks the way out.
    town["props"].append(prop("route_sign", 20, 30))
    town["interactions"].append(
        {"tile": [20, 30], "verb": "Read", "text": "South road: the Greymere Outskirts, and the training grounds beyond."}
    )
    town["exits"] = [
        {
            "building_id": "outskirts",
            "tiles": [[16, 31], [17, 31], [18, 31]],
            "direction": [0, 1],
            "destination_location": "route_01",
            "destination_scene": "res://scenes/overworld/route_01.tscn",
            "destination_spawn": "greymere",
            "return_spawn": "route_return",
            "transition_type": "fade",
            "verb": "Travel",
        }
    ]
    grid = [["#" for _ in range(60)] for _ in range(35)]
    # Connected, authored clearings define the route; forest is solid ground collision.
    for clearing in [
        (3, 14, 18, 9),
        (6, 9, 17, 8),
        (17, 8, 26, 6),
        (23, 12, 15, 9),
        (23, 21, 18, 8),
        (37, 18, 20, 11),
        (42, 17, 12, 8),
        (50, 5, 7, 15),
        (25, 2, 15, 7),
    ]:
        rect(grid, *clearing, ".")
    # Old Greymaw's den: a narrow game trail off the western clearing, easy
    # to walk past, opens into a hollow under the ridge (Chapter One canon).
    rect(grid, 3, 23, 2, 3, ",")
    rect(grid, 3, 26, 12, 5, ".")
    rect(grid, 5, 27, 6, 2, ",")
    rect(grid, 0, 0, 60, 2, "#")
    rect(grid, 0, 33, 60, 2, "#")
    rect(grid, 0, 0, 2, 35, "#")
    rect(grid, 58, 0, 2, 35, "#")
    for r in [
        (3, 17, 18, 3),
        (18, 10, 3, 10),
        (18, 10, 23, 3),
        (38, 10, 3, 17),
        (38, 24, 18, 3),
        (53, 7, 3, 20),
        (24, 24, 17, 3),
        (24, 21, 3, 6),
        (12, 14, 3, 5),
    ]:
        rect(grid, *r, ",")
    rect(grid, 8, 11, 9, 5, "g")
    rect(grid, 25, 13, 10, 6, "g")
    rect(grid, 44, 20, 7, 4, "g")
    rect(grid, 27, 3, 10, 5, "~")
    for x, y in [
        (6, 22),
        (9, 25),
        (21, 6),
        (24, 7),
        (34, 22),
        (45, 11),
        (48, 29),
        (50, 6),
    ]:
        rect(grid, x, y, 2, 2, "f")
    props = [
        prop("route_sign", 6, 16),
        prop("route_sign", 54, 6),
        dict(
            prop("route_chest", 25, 23),
            collected_asset="route_chest_open",
            collected_flag="route01_supplies_collected",
        ),
        prop("crates", 46, 27),
        prop("route_rock", 21, 15),
        prop("route_fence", 8, 22),
        # The den: torn hedges at the trail mouth, a ransacked camp.
        prop("hedge", 6, 25),
        prop("route_rock", 13, 26),
        prop("crates", 12, 29),
        prop("route_chest_open", 5, 30),
    ]
    props += [
        prop("route_oak", x, y)
        for x, y in [
            (4, 7),
            (10, 7),
            (16, 7),
            (23, 7),
            (41, 7),
            (48, 7),
            (57, 6),
            (17, 30),
            (22, 30),
            (30, 31),
            (37, 32),
            (45, 32),
            (53, 32),
            (57, 17),
            (3, 13),
            (32, 23),
            (45, 17),
        ]
    ]
    props += [
        prop("hedge", x, y)
        for x, y in [
            (22, 17),
            (22, 19),
            (36, 16),
            (36, 18),
            (42, 21),
            (48, 15),
            (51, 15),
        ]
    ]
    # Reuse the same authored tree kit to fill impassable forest interiors.
    # Staggered rows with a fixed, hash-derived jitter read as woodland rather
    # than an orchard grid; every footprint stays on solid forest tiles.
    props += _forest_fill(grid)
    trainers = [
        dict(
            npc("Apprentice Rowan", "route01_rowan", "", 11, 16, (0, 1)),
            id="route01_rowan",
            encounter="route01_rowan",
            sight=4,
            intro="Heading into Greymere? Let's see if you've got what it takes!",
            after="That was a good lesson. Keep an eye on the grass off the road.",
        ),
        dict(
            npc("Travelling Squire", "route01_squire", "", 22, 10, (-1, 0)),
            id="route01_squire",
            encounter="route01_squire",
            sight=4,
            intro="A good duelist should always be prepared. Show me your technique!",
            after="Well fought. Supplies from Gell will help on a longer journey.",
        ),
        dict(
            npc("Wandering Challenger", "route01_challenger", "", 41, 24, (-1, 0)),
            id="route01_challenger",
            encounter="route01_challenger",
            sight=4,
            intro="I've been waiting for someone worth challenging!",
            after="A fine match. The road beyond the north gate is closed for now.",
        ),
    ]
    greymaw = dict(
        npc("Old Greymaw", "greymaw", "", 10, 28, (-1, 0)),
        id="greymaw_den",
        encounter="greymaw_den",
        sight=3,
        intro="A low growl rolls out of the hollow. Old Greymaw rises — bigger than the stories, its eyes catching a strange gold light.",
        after="The den is quiet now.",
        # Gone once beaten; out of reach once the cordon closes the chapter's
        # ridge country (docs/VERTICAL_SLICE_SPEC.md, progression gates).
        show_if=["!greymaw_den_defeated", "stage<incident"],
    )
    route = {
        "id": "route_01",
        "name": "Greymere Outskirts — Route 01",
        "subtitle": "The road beyond home",
        "scene": "res://scenes/overworld/route_01.tscn",
        "rows": ["".join(r) for r in grid],
        "music_id": "greymere_route",
        "ambience_id": "route",
        # Organic shader terrain, sun lighting and grading (WorldLocation).
        "painted": {"path_symbols": ",", "path_material": "dirt"},
        "interior": False,
        "props": props,
        "lights": [],
        "spawn_points": {
            "greymere": spawn(5, 18, (1, 0)),
            "entrance": spawn(5, 18, (1, 0)),
            "far_end": spawn(54, 9, (0, 1)),
        },
        "doors": [],
        "exits": [
            {
                "building_id": "greymere_road",
                "tiles": [[3, 17], [3, 18], [3, 19]],
                "direction": [-1, 0],
                "destination_location": "greymere",
                "destination_scene": town["scene"],
                "destination_spawn": "route_return",
                "return_spawn": "greymere",
                "transition_type": "fade",
                "verb": "Travel",
            }
        ],
        "npcs": trainers
        + [greymaw]
        + [
            dict(
                npc("Roadside Traveller", "townsfolk/elder_woman", "", 29, 25, (0, -1)),
                text="The main road is safe to follow. Training parties gather in the tall grass. There are supplies along the western clearing.",
            )
        ],
        "interactions": [
            {
                "tile": [6, 16],
                "verb": "Read",
                "text": "Greymere Outskirts — Travellers beware. Duelists often train along these roads.",
            },
            {
                "tile": [25, 23],
                "verb": "Open",
                "kind": "chest",
                "flag": "route01_supplies_collected",
                "item": "potion",
                "quantity": 2,
            },
            {
                "tile": [54, 6],
                "verb": "Read",
                "text": "North road closed. The next region will open in a future chapter.",
            },
            # Foreshadowing on the main road, then the trail itself.
            {
                "tile": [12, 21],
                "verb": "Look",
                "text": "Paw prints the size of a dinner plate, pressed deep into the mud. They head south, off the road.",
                "flag": "greymaw_tracks_found",
            },
            {
                "tile": [4, 22],
                "verb": "Look",
                "text": "Claw marks score the bank. Something heavy has been using this gap in the hedge.",
                "flag": "greymaw_tracks_found",
            },
            {
                "tile": [5, 30],
                "verb": "Search",
                "kind": "chest",
                "flag": "greymaw_camp_searched",
                "item": "hi_potion",
                "quantity": 1,
                "text": "A traveller's camp, torn apart. The bedroll is shredded and the food sack is gone. A Hi-Potion survived, wedged under the chest.",
            },
            {
                "tile": [10, 28],
                "verb": "Look",
                "text": "Old Greymaw's hollow. Grey fur snagged on every root, and the ground still warm. The ridge hums faintly underfoot.",
                "show_if": ["greymaw_den_defeated"],
            },
        ],
        "encounter_zones": [
            {
                "symbol": "g",
                # Measured with scenes/tools encounter_probe.gd (50 seeded runs
                # through tall grass): the old 12% / 8-step cooldown fought
                # every ~14 grass steps (2 s); this gives a median of 36
                # steps (5 s) and never fewer than 24.
                "probability": 0.06,
                "cooldown_steps": 24,
                "encounters": ["route01_roadside"],
            }
        ],
    }
    # The reserved north gate is an interaction, not a broken destination.
    rect(grid, 53, 6, 3, 1, "#")
    route["rows"] = ["".join(r) for r in grid]
    # Small native-grid fences and stone obstacles extend the shared terrain kit.
    for x, y in [(7, 22), (8, 22), (9, 22)]:
        rect(grid, x, y, 1, 1, "|")
    for x, y in [(21, 15), (35, 18), (48, 28)]:
        rect(grid, x, y, 1, 1, "r")
    # Every blocking stone gets the authored rock art (the terrain no longer
    # paints a procedural block beneath it).
    props += [prop("route_stone", x, y) for x, y in [(35, 18), (48, 28)]]
    route["rows"] = ["".join(row) for row in grid]
    route["blocked_symbols"] = ["#", "~", "_", "|", "r"]
    route["hud_name"] = "GREYMERE OUTSKIRTS"
    # Breathing room on every arrival and after every fight; the road itself
    # never crosses tall grass, so it is always the low-risk way through.
    route["arrival_grace_steps"] = 16
    route["encounter_message"] = (
        "A roadside raider emerges from the tall grass. Prepare your party!"
    )
    route["recovery"] = {"location": "greymere", "spawn": "route_return"}
    route["return_grace_steps"] = 24
    route["battle_background"] = {
        "rows": ["." * 20] * 4 + ["," * 20] * 5,
        "props": [prop("route_oak", x, 2) for x in [1, 5, 10, 15, 19]],
    }
    locations["route_01"] = route


def _forest_fill(grid):
    """Deterministic, staggered oak placement over solid forest."""
    oaks = []
    for row, y in enumerate(range(3, 33, 3)):
        for x in range(3 + (row % 2) * 2, 58, 4):
            jitter = (x * 7 + y * 13) % 3 - 1
            tx = x + jitter
            if all(
                0 <= j < len(grid) and 0 <= i < len(grid[0]) and grid[j][i] == "#"
                for j in range(y - 1, y + 1)
                for i in range(tx - 1, tx + 1)
            ):
                oaks.append(prop("route_oak", tx, y))
    return oaks
