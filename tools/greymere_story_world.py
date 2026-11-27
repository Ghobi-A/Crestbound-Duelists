"""Chapter One staging for Greymere; compiled by build_greymere_world.py.

The town map itself is authored in build_greymere_world.py. This module adds
what the story needs on top of it, without moving a wall:

* who stands where at each story stage (NPC `show_if` variants);
* the conversations they hold (chapter_one.json, by key);
* the triggers that start story beats (arriving, stepping into the square);
* the cordon on the north arch and the closed south road before the lesson.

The class-first prototype ("legacy" stage: Quick Battle and the battle
tools) keeps its original residents, so `stage<morning` marks them. Stages
are GameState.STORY_STAGES; see docs/VERTICAL_SLICE_SPEC.md.
"""

from build_greymere_world import npc, prop, spawn

LEGACY = ["stage<morning"]
STORY = ["stage>=morning"]


def _legacy_only(items, names):
    for item in items:
        if item.get("name") in names or item.get("dialogue") in names or item.get("kind") in names:
            item["show_if"] = list(LEGACY)


def _story_npc(name, key, dialogue, x, y, facing=(0, 1), show_if=()):
    return dict(npc(name, key, dialogue, x, y, facing), show_if=[*STORY, *show_if])


def add_story(locations):
    town = locations["greymere"]
    # The prototype's Almyra and Liora at the arch, its Joey and Danfor, and
    # the old raider battle at the north arch belong to the legacy flow only.
    _legacy_only(town["npcs"], {"Warden Almyra", "Liora Sen", "Joey", "Danfor"})
    _legacy_only(town["interactions"], {"court"})
    town["spawn_points"]["aftermath"] = spawn(17, 12, (0, 1))
    town["spawn_points"]["civara_road"] = spawn(17, 8, (0, 1))
    # The south road stays shut until Danfor's lesson (flag set by start_story).
    for exit in town["exits"]:
        exit["show_if"] = ["!south_road_closed"]
    town["npcs"] += [
        # Morning to the cordon: Joey and his goats, Danfor on his rounds.
        _story_npc("Joey", "townsfolk/farmboy", "joey_talk", 15, 20, (0, 1), ["stage<incident"]),
        _story_npc("Danfor", "townsfolk/guard_sword", "danfor_talk", 20, 26, (-1, 0), ["stage<cordon"]),
        # The inspection party at the arch, and Danfor holding the cordon.
        _story_npc("Warden Almyra", "elara", "almyra_cordon", 18, 9, (0, 1), ["stage>=cordon", "stage<incident"]),
        _story_npc("Specialist Hale", "hale", "hale_cordon", 15, 9, (0, 1), ["stage>=cordon", "stage<incident"]),
        _story_npc("Danfor", "townsfolk/guard_sword", "danfor_cordon", 17, 9, (0, 1), ["stage>=cordon", "stage<incident"]),
        # Aftermath: the square, damaged and standing.
        _story_npc("Danfor", "townsfolk/guard_sword", "danfor_aftermath", 20, 13, (-1, 0), ["stage>=aftermath"]),
        _story_npc("Joey", "townsfolk/farmboy", "joey_aftermath", 14, 14, (1, 0), ["stage>=aftermath"]),
        _story_npc("Warden Almyra", "elara", "almyra_aftermath", 18, 10, (0, 1), ["stage>=aftermath"]),
    ]
    # Old Ferris keeps the lamps and the stories.
    for resident in town["npcs"]:
        if resident["name"] == "Old Ferris":
            resident["dialogue"] = "ferris_talk"
    town["props"] += [
        # The cordon: Avelan survey stakes and crates across the arch.
        dict(prop("crates", 14, 8), show_if=["stage>=cordon", "stage<aftermath"]),
        dict(prop("crates", 21, 8), show_if=["stage>=cordon", "stage<aftermath"]),
        # Aftermath: fallen stone in the square.
        dict(prop("route_rock", 13, 17), show_if=["stage>=aftermath"]),
        dict(prop("route_rock", 22, 15), show_if=["stage>=aftermath"]),
        dict(prop("route_stone", 19, 18), show_if=["stage>=aftermath"]),
    ]
    town["interactions"] += [
        {"tile": [17, 5], "verb": "Look", "show_if": ["stage>=morning", "stage<cordon"],
         "text": "The north arch. Past it, the ridge path climbs to the old ruins. Nobody goes up there, which is mostly why Joey does."},
        {"tile": [17, 5], "verb": "Descend", "show_if": ["stage>=incident", "stage<aftermath"], "dialogue": "court_descend"},
        {"tile": [22, 24], "verb": "Drink", "show_if": ["stage>=abnormal", "stage<aftermath"],
         "text": "The spring water tastes of iron this week. Everyone has noticed. Nobody has said so to Silas."},
    ]
    town["triggers"] = [
        {"id": "after_spar", "dialogue": "after_spar", "show_if": ["greymere_spar_danfor_won"]},
        {"id": "south_road_closed", "dialogue": "south_road_closed", "area": [16, 31, 3, 1], "once": False,
         "show_if": ["south_road_closed"]},
        # Abnormal signs: after Silas's question and a first taste of the road,
        # or once every trainer on Route 01 has been beaten.
        {"id": "abnormal_signs", "dialogue": "abnormal_signs",
         "show_if": ["stage>=village", "stage<abnormal", "talked_silas_ridge", "route01_rowan_defeated"]},
        {"id": "abnormal_signs_road", "dialogue": "abnormal_signs",
         "show_if": ["stage>=village", "stage<abnormal", "route01_rowan_defeated", "route01_squire_defeated",
                     "route01_challenger_defeated"]},
        {"id": "almyra_arrives", "dialogue": "almyra_arrives", "area": [11, 11, 13, 10],
         "show_if": ["stage>=abnormal", "stage<cordon"]},
        {"id": "aftermath", "dialogue": "aftermath", "show_if": ["court_sealed_choir_won"]},
    ]

    # ── Interiors ───────────────────────────────────────────────────
    house = locations["kai_house"]
    house["spawn_points"]["bed"] = spawn(14, 6, (0, 1))
    house["triggers"] = [{"id": "morning_wake", "dialogue": "morning_wake", "show_if": STORY}]
    house["interactions"] = [
        dict(item, dialogue="kai_note") if item["tile"] == [10, 7] else item
        for item in house["interactions"]
    ]
    house["interactions"] += [
        {"tile": [15, 5], "verb": "Rest", "kind": "recovery", "spawn": "bed", "show_if": STORY,
         "text": "You lie down for a moment. It helps more than you expected."},
    ]
    # One bed interaction per tile: the story's rest replaces the inspection.
    house["interactions"] = [
        item for item in house["interactions"]
        if not (item["tile"] == [15, 5] and item.get("kind") != "recovery")
    ] + [{"tile": [15, 5], "verb": "Inspect", "text": "Your bed. Made this morning, mostly.", "show_if": LEGACY}]

    for room_id, dialogue in [("lena_house", "lena_talk"), ("silas_study", "silas_talk"), ("gell_shop", "gell_talk")]:
        for resident in locations[room_id]["npcs"]:
            resident["dialogue"] = dialogue
    inn = locations["inn"]
    _legacy_only(inn["npcs"], {"Joey", "Old Ferris"})
    for resident in inn["npcs"]:
        if resident["name"] == "Goodwife Senna":
            resident["dialogue"] = "senna_talk"
    shop = locations["gell_shop"]
    shop["interactions"] += [
        {"tile": [4, 10], "verb": "Lift", "flag": "crates_picked", "show_if": ["gell_crates_asked", "!crates_picked"],
         "text": "A crate of lamp oil, labelled INN in Gell's careful hand. It is heavier than Gell said."},
    ]

    route = locations["route_01"]
    route["interactions"] += [
        {"tile": [27, 7], "verb": "Gather", "flag": "herbs_gathered", "show_if": ["lena_herbs_asked", "!herbs_gathered"],
         "text": "Marshwort, growing thick in the reeds at the pond's edge. You cut what Lena asked for and a little more."},
    ]
