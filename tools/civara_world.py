"""Civara, minimally (Chapter One); compiled by build_greymere_world.py.

Only what the chapter needs (docs/VERTICAL_SLICE_SPEC.md, beats 20-22):
the forecourt where the north road arrives, and the Classification Hall,
where Kai's Crest answers all six patterns, the player stabilises one, and
an Avelan assessor of the same class tests it. Greymere is behind Kai now;
there is no road back in this chapter.
"""

from build_greymere_world import entrance, npc, prop, rect, spawn

CLASSES = ["warrior", "guardian", "mage", "sorcerer", "assassin", "neutral"]


def add_civara(locations):
    width, height = 30, 22
    grid = [["." for _ in range(width)] for _ in range(height)]
    rect(grid, 0, 0, width, 2, "#")
    rect(grid, 0, height - 2, width, 2, "#")
    rect(grid, 0, 0, 2, height, "#")
    rect(grid, width - 2, 0, 2, height, "#")
    # One paved civic square under the Hall's arch, planted edges either side.
    rect(grid, 4, 7, 22, 13, ":")
    rect(grid, 13, 2, 5, 6, ":")
    forecourt = {
        "id": "civara_forecourt",
        "name": "CIVARA",
        "subtitle": "The Classification Hall forecourt",
        "scene": "res://scenes/overworld/civara_forecourt.tscn",
        "rows": ["".join(r) for r in grid],
        "music_id": "civara",
        "ambience_id": "civara",
        "interior": False,
        "painted": {"path_symbols": ":", "path_material": "cobble"},
        "props": [prop("gate", 15, 6), prop("wall", 10, 6), prop("wall", 20, 6),
                  prop("notice", 8, 9), prop("crates", 23, 12), prop("crates", 24, 14)]
        + [prop("lamp", x, y) for x, y in [(6, 8), (12, 8), (18, 8), (24, 8), (6, 17), (24, 17)]]
        + [prop("hedge", x, y) for x, y in [(5, 12), (5, 15), (25, 10)]]
        + [prop("tree", x, y) for x, y in [(3, 4), (27, 4), (3, 19), (27, 19)]],
        "npcs": [
            npc("Avelan Clerk", "townsfolk/elder_woman", "civara_clerk", 13, 8, (0, 1)),
            dict(npc("Warden Almyra", "elara", "almyra_civara", 18, 9, (-1, 0)), show_if=["!civara_assessment_won"]),
            npc("Stall Keeper", "townsfolk/farmhand_capped", "civara_stall", 22, 13, (-1, 0)),
        ],
        "spawn_points": {"entrance": spawn(15, 18, (0, -1)), "hall_return": spawn(15, 8, (0, 1))},
        "doors": [entrance("hall", 15, 6, "civara_hall", "hall_return")],
        "exits": [],
        "interactions": [
            {"tile": [8, 9], "verb": "Read",
             "text": "CLASSIFICATION HALL. Registrants report to the clerk. Resonance testing in order of arrival. No Crest demonstrations in the forecourt."},
            {"tile": [23, 12], "verb": "Browse", "kind": "shop"},
        ],
        "lights": [{"tile": [x, y], "color": "warm"} for x, y in [(6, 8), (12, 8), (18, 8), (24, 8)]],
        "recovery": {"location": "civara_hall", "spawn": "entrance"},
        "hud_name": "CIVARA",
        "triggers": [{"id": "civara_arrive", "dialogue": "civara_arrive"}],
        "battle_background": locations["route_01"]["battle_background"],
    }
    locations["civara_forecourt"] = forecourt

    grid = [["_" for _ in range(22)] for _ in range(14)]
    rect(grid, 1, 1, 20, 12, "#")
    rect(grid, 2, 3, 18, 9, "w")
    rect(grid, 10, 11, 2, 1, ":")
    hall = {
        "id": "civara_hall",
        "name": "CLASSIFICATION HALL",
        "subtitle": "Civara",
        "scene": "res://scenes/overworld/civara_hall.tscn",
        "rows": ["".join(r) for r in grid],
        "interior": True,
        "music_id": "civara",
        "ambience_id": "interior",
        "painted_interior": {"style": "candlelit"},
        "props": [prop("counter", 10, 5), prop("books", 4, 5), prop("books", 17, 5), prop("table", 15, 9), prop("desk", 5, 9)],
        "npcs": [
            npc("Liora Sen", "mira", "liora_hall", 15, 7, (-1, 0)),
            dict(npc("Assessor", "assessor", "assessor_hall", 6, 6, (1, 0)), show_if=["!civara_assessment_won"]),
        ],
        "spawn_points": {"entrance": spawn(10, 10, (0, -1))},
        "doors": [{"building_id": "civara_hall", "tile": [10, 12], "destination_location": "civara_forecourt",
                   "destination_scene": "res://scenes/overworld/civara_forecourt.tscn", "destination_spawn": "hall_return",
                   "return_spawn": "entrance", "locked": False, "locked_dialogue_id": "locked_door",
                   "transition_type": "fade", "verb": "Leave"}],
        "interactions": [
            {"tile": [5, 9], "verb": "Rest", "kind": "recovery", "spawn": "entrance",
             "text": "A bench for registrants. You sit. Nobody tells you to stand."},
            {"tile": [17, 5], "verb": "Read",
             "text": "Six resonance patterns, six columns in a ledger. In every row but one, a single column is ticked."},
        ],
        "lights": [{"tile": [5, 4], "color": "warm"}, {"tile": [15, 8], "color": "warm"}],
        "recovery": {"location": "civara_hall", "spawn": "entrance"},
        # The assessment is fought in the Hall itself (the opening's hall plate).
        "battle_backdrop": "res://assets/cinematics/opening/s2_hall.png",
        "battle_backdrop_tint": "#7d8296",
        "triggers": [
            {"id": "civara_classification", "dialogue": "civara_classification", "once": False,
             "show_if": ["!class_stabilised"]},
            {"id": "civara_assess_retry", "dialogue": "civara_assess_retry", "once": False,
             "show_if": ["class_stabilised", "!civara_assessment_won"]},
            {"id": "civara_after", "dialogue": "civara_after", "show_if": ["civara_assessment_won"]},
        ],
    }
    locations["civara_hall"] = hall
