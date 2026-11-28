"""The Hollow Court dungeon (Chapter One); compiled by build_greymere_world.py.

Three underground rooms in the "court" painted-interior style: cold stone,
still black water and the Court's gold light. Kai goes down after Joey
(docs/rework/CHAPTER_ONE_PROVISIONAL_CANON.md):

* court_stair    the Collapsed Stair: Kai drops in, a shrine to rest at,
                 two Riven fights and the first signs of Joey;
* court_gallery  the Drowned Gallery: Almyra pinned under fallen stone, the
                 old bonding rings, and the Husk guarding the way on;
* court_chamber  the Radial Chamber: Joey cornered, the anchor, the bond and
                 the Sealed Choir.

Rooms connect by walking off their side passages (edge exits). Story beats
are triggers that play chapter_one.json conversations; battles start from
those conversations or from Riven that spot Kai, like Route 01 trainers.
"""

from build_greymere_world import npc, prop, rect, spawn

STYLE = {"style": "court"}
BLOCKED = ["#", "_", "~"]


def _room(width, height):
    grid = [["_" for _ in range(width)] for _ in range(height)]
    rect(grid, 1, 1, width - 2, height - 2, "#")
    rect(grid, 2, 3, width - 4, height - 5, "w")
    return grid


def _exit(tiles, direction, location, spawn_id, verb):
    return {
        "building_id": location,
        "tiles": [list(t) for t in tiles],
        "direction": list(direction),
        "destination_location": location,
        "destination_scene": f"res://scenes/overworld/{location}.tscn",
        "destination_spawn": spawn_id,
        "return_spawn": "entrance",
        "transition_type": "fade",
        "verb": verb,
    }


def _riven(name, key, encounter, x, y, facing, sight=3, show_if=()):
    return dict(
        npc(name, key, "", x, y, facing),
        id=encounter,
        encounter=encounter,
        sight=sight,
        intro="The light knots itself into something that turns toward you.",
        after="Only cold air where it was.",
        show_if=[f"!{encounter}_defeated", *show_if],
    )


def _base(id, name, subtitle, grid, **extra):
    location = {
        "id": id,
        "name": name,
        "subtitle": subtitle,
        "scene": f"res://scenes/overworld/{id}.tscn",
        "rows": ["".join(r) for r in grid],
        "interior": True,
        "music_id": "hollow_court",
        "ambience_id": "court",
        "painted_interior": STYLE,
        "blocked_symbols": BLOCKED,
        "doors": [],
        # A lost fight down here rests Kai at the Court's shrine.
        "recovery": {"location": "court_stair", "spawn": "shrine"},
        "return_grace_steps": 6,
        "hud_name": name,
        # Battles down here are fought in front of the Court's painting.
        "battle_backdrop": "res://assets/rework/hollow_court.png",
    }
    location.update(extra)
    return location


def add_court(locations):
    town = locations["greymere"]
    town["spawn_points"]["court_climb"] = spawn(17, 8, (0, 1))

    # ── The Collapsed Stair ─────────────────────────────────────────
    grid = _room(30, 17)
    stair = _base(
        "court_stair", "THE COLLAPSED STAIR", "Under the ridge", grid,
        props=[prop("route_rock", 4, 6), prop("route_rock", 7, 4), prop("route_stone", 3, 8),
               prop("route_stone", 11, 6), prop("route_rock", 12, 11), prop("route_stone", 18, 4),
               prop("route_rock", 20, 8), prop("route_stone", 25, 6), prop("route_rock", 8, 13),
               prop("spring", 16, 7)],
        lights=[{"tile": [4, 3], "color": "gold"}, {"tile": [16, 6], "color": "gold"},
                {"tile": [26, 12], "color": "violet"}],
        npcs=[
            _riven("Riven Wisp", "riven_wisp", "court_stair_wisp", 10, 9, (0, 1)),
            _riven("Riven Wisps", "riven_wisp", "court_stair_pair", 23, 11, (-1, 0)),
        ],
        spawn_points={
            "entrance": spawn(4, 4, (0, 1)),
            "shrine": spawn(16, 9, (0, -1)),
            "gallery_return": spawn(26, 12, (-1, 0)),
        },
        exits=[
            _exit([(2, 4), (2, 5)], (-1, 0), "greymere", "court_climb", "Climb"),
            _exit([(27, 12), (27, 13)], (1, 0), "court_gallery", "entrance", "Descend"),
        ],
        interactions=[
            {"tile": [16, 7], "verb": "Rest", "kind": "recovery", "spawn": "shrine",
             "text": "An old basin of still water. The air around it is calm, and so, for a moment, are you."},
            {"tile": [6, 9], "verb": "Look", "flag": "found_joey_lantern",
             "text": "A tin lantern on its side, still warm. There's a J scratched into the lid. Joey's."},
            {"tile": [18, 4], "verb": "Look",
             "text": "Bronze fittings, prised out of the wall years ago. Somebody has been coming down here a long time."},
            {"tile": [25, 6], "verb": "Search", "kind": "chest", "flag": "court_stair_supplies",
             "item": "potion", "quantity": 1,
             "text": "A survey pack, dropped in a hurry. Avelan stamps on the straps."},
        ],
        triggers=[
            {"id": "court_stair_arrive", "dialogue": "court_stair_arrive"},
        ],
    )

    # ── The Drowned Gallery ─────────────────────────────────────────
    grid = _room(32, 17)
    rect(grid, 5, 7, 22, 3, "~")
    rect(grid, 15, 7, 2, 3, "w")  # a causeway over the still water
    gallery = _base(
        "court_gallery", "THE DROWNED GALLERY", "Still water, older than the town", grid,
        props=[prop("route_stone", 6, 4), prop("route_stone", 9, 5), prop("route_rock", 23, 4),
               prop("route_stone", 27, 5), prop("route_rock", 6, 12), prop("route_stone", 12, 13),
               prop("route_rock", 21, 12)],
        lights=[{"tile": [15, 6], "color": "gold"}, {"tile": [25, 4], "color": "violet"},
                {"tile": [28, 12], "color": "gold"}],
        npcs=[
            dict(npc("Warden Almyra", "elara", "", 25, 5, (-1, 0)), show_if=["!court_gallery_husk_won"]),
            _riven("Riven Husk", "riven_husk", "court_gallery_pair", 27, 12, (-1, 0),
                   show_if=["court_gallery_husk_won"]),
        ],
        spawn_points={
            "entrance": spawn(3, 4, (1, 0)),
            "chamber_return": spawn(28, 13, (-1, 0)),
            "almyra": spawn(22, 5, (1, 0)),
        },
        exits=[
            _exit([(2, 4), (2, 5)], (-1, 0), "court_stair", "gallery_return", "Climb"),
            dict(_exit([(29, 12), (29, 13)], (1, 0), "court_chamber", "entrance", "Descend"),
                 show_if=["court_gallery_pair_won"]),
        ],
        interactions=[
            {"tile": [9, 5], "verb": "Look",
             "text": "Rings scorched into the floor, one inside another. People knelt here and tried to answer something. A long time ago."},
            {"tile": [12, 13], "verb": "Look",
             "text": "Names cut into the stone, centuries old. Most have been struck through."},
            {"tile": [21, 12], "verb": "Look", "flag": "found_survey_peg",
             "text": "A brass survey peg with Avelan markings, snapped in half. Hale's team got this far."},
        ],
        triggers=[
            {"id": "gallery_almyra", "dialogue": "gallery_almyra", "area": [19, 3, 8, 4], "once": False,
             "show_if": ["!court_gallery_husk_won"]},
            {"id": "gallery_almyra_freed", "dialogue": "gallery_almyra_freed",
             "show_if": ["court_gallery_husk_won"]},
        ],
    )

    # ── The Radial Chamber ──────────────────────────────────────────
    grid = _room(26, 17)
    chamber = _base(
        "court_chamber", "THE RADIAL CHAMBER", "Where the Court still sings", grid,
        props=[prop("route_stone", x, y) for x, y in [(9, 6), (15, 6), (8, 9), (16, 9), (9, 12), (15, 12)]]
        + [prop("route_rock", 4, 5), prop("route_rock", 20, 13)],
        lights=[{"tile": [12, 8], "color": "gold"}, {"tile": [12, 4], "color": "violet"},
                {"tile": [4, 12], "color": "gold"}, {"tile": [20, 5], "color": "violet"}],
        npcs=[
            dict(npc("Joey", "townsfolk/farmboy", "", 19, 7, (-1, 0)), show_if=["!kai_bonded"]),
            dict(npc("Riven Anchor", "riven_anchor", "", 12, 4, (0, 1)), show_if=["!court_anchor_won"]),
            dict(npc("The Sealed Choir", "sealed_choir", "", 12, 4, (0, 1)),
                 show_if=["court_anchor_won", "kai_bonded", "!court_sealed_choir_won"]),
            dict(npc("Specialist Hale", "hale", "", 6, 9, (1, 0)), show_if=["kai_bonded"]),
            dict(npc("Warden Almyra", "elara", "", 7, 11, (1, 0)), show_if=["kai_bonded"]),
        ],
        spawn_points={
            "entrance": spawn(3, 12, (1, 0)),
            "centre": spawn(12, 10, (0, -1)),
        },
        exits=[
            _exit([(2, 12), (2, 13)], (-1, 0), "court_gallery", "chamber_return", "Climb"),
        ],
        interactions=[
            {"tile": [12, 8], "verb": "Look", "show_if": ["!kai_bonded"],
             "text": "A disc of gold set into the floor, lines running out from it to every wall. It is warm. It is humming."},
        ],
        triggers=[
            # Each battle beat stays repeatable until it is won.
            {"id": "chamber_joey", "dialogue": "chamber_joey", "once": False,
             "show_if": ["!court_protect_joey_won"]},
            {"id": "chamber_anchor", "dialogue": "chamber_anchor", "once": False,
             "show_if": ["court_protect_joey_won", "!court_anchor_won"]},
            {"id": "chamber_bond", "dialogue": "chamber_bond", "show_if": ["court_anchor_won"]},
            {"id": "chamber_choir", "dialogue": "chamber_choir", "once": False,
             "show_if": ["kai_bonded", "!court_sealed_choir_won"]},
        ],
    )
    for room in (stair, gallery, chamber):
        locations[room["id"]] = room
