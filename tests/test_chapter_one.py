"""Chapter One's story graph: every reference in the story data resolves.

The chapter is data: conversations (game/data/dialogue/chapter_one.json)
carry StoryDirector effects and choices, and the world (game/world/
locations.json) carries the triggers and residents that start them. A typo
here would strand the player mid-chapter without any error, so every link
is checked: conversations, battles, travel targets, cinematics, triggers,
quest flags and story stages.
"""
from __future__ import annotations

import json
from pathlib import Path

import loaders

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game"
CHAPTER = json.loads((GAME / "data/dialogue/chapter_one.json").read_text(encoding="utf-8"))
DIALOGUE = {**json.loads((GAME / "data/dialogue/greymere.json").read_text(encoding="utf-8")), **CHAPTER}
LOCATIONS = json.loads((GAME / "world/locations.json").read_text())["locations"]
ENCOUNTERS = loaders.load_encounters()
STAGES = ["morning", "village", "abnormal", "cordon", "incident", "aftermath", "civara", "complete"]
EFFECT_KEYS = {"flags", "clear_flags", "stage", "profile", "class", "join", "leave", "rewards", "recover",
               "checkpoint", "battle", "travel", "cinematic", "scene"}


def _effects():
    """(conversation, effects) for every entry and choice in the chapter."""
    for key, entries in CHAPTER.items():
        for entry in entries:
            if "effects" in entry:
                yield key, entry["effects"]
            for choice in entry.get("choices", []):
                if "effects" in choice:
                    yield key, choice["effects"]


def _set_flags() -> set[str]:
    """Every flag the chapter can set: effects, encounter wins and rewards,
    trainer wins, stages, clues and searches, quest steps' sources."""
    flags = set()
    for _, effects in _effects():
        flags |= set(effects.get("flags", []))
        if "stage" in effects:
            flags.add("stage_" + effects["stage"])
        if "class" in effects:
            flags |= {"class_stabilised", "class_" + effects["class"]}
    for encounter_id, encounter in ENCOUNTERS.items():
        flags.add(encounter_id + "_won")
        flags |= set((encounter.get("rewards") or {}).get("flags", []))
        flags |= set((encounter.get("return") or {}).get("flags", []))
    for location in LOCATIONS.values():
        for resident in location.get("npcs", []):
            if "encounter" in resident:
                flags.add(resident["id"] + "_defeated")
        for item in location.get("interactions", []):
            if item.get("flag"):
                flags.add(item["flag"])
        for trigger in location.get("triggers", []):
            flags.add("seen_" + trigger["id"])
    return flags | {"south_road_closed"}  # set by GameState.start_story


def test_effects_use_only_known_keys_and_valid_values():
    for key, effects in _effects():
        assert set(effects) <= EFFECT_KEYS, (key, set(effects) - EFFECT_KEYS)
        if "stage" in effects:
            assert effects["stage"] in STAGES, key
        if "battle" in effects:
            assert effects["battle"] in ENCOUNTERS, (key, effects["battle"])
        if "travel" in effects:
            target = effects["travel"]
            assert target["location"] in LOCATIONS, (key, target)
            assert target["spawn"] in LOCATIONS[target["location"]]["spawn_points"], (key, target)
        if "cinematic" in effects:
            assert (GAME / f"data/cinematics/{effects['cinematic']}.json").is_file(), key
        if "scene" in effects:
            assert (GAME / effects["scene"].removeprefix("res://")).is_file(), key
        if "class" in effects:
            assert effects["class"] in loaders.load_classes(), key
        if "profile" in effects:
            assert effects["profile"] in loaders.load_cast(), key
        for cast_id in effects.get("join", []):
            assert cast_id in loaders.load_cast(), key


def test_every_choice_and_conversation_link_resolves():
    for key, entries in CHAPTER.items():
        assert entries, key
        for entry in entries:
            assert entry.get("lines"), key
            for choice in entry.get("choices", []):
                assert choice.get("label"), key
                if "next" in choice:
                    assert choice["next"] in DIALOGUE, (key, choice["next"])


def test_every_trigger_and_resident_has_its_conversation():
    for location in LOCATIONS.values():
        for trigger in location.get("triggers", []):
            assert trigger["dialogue"] in DIALOGUE, (location["id"], trigger["id"])
            area = trigger.get("area")
            if area:
                assert len(area) == 4 and area[2] > 0 and area[3] > 0, trigger["id"]
        for resident in location.get("npcs", []):
            if resident.get("dialogue") and "encounter" not in resident and "text" not in resident:
                assert resident["dialogue"] in DIALOGUE, (location["id"], resident["name"], resident["dialogue"])
            if "encounter" in resident:
                assert resident["encounter"] in ENCOUNTERS, resident
        for item in location.get("interactions", []):
            if "dialogue" in item:
                assert item["dialogue"] in DIALOGUE, (location["id"], item["tile"])


def test_every_condition_names_a_flag_the_chapter_can_set():
    known = _set_flags()
    def check(where, conditions):
        for condition in [conditions] if isinstance(conditions, str) else conditions:
            if condition.startswith("stage"):
                stage = condition.split("=")[-1].split("<")[-1]
                assert stage in STAGES, (where, condition)
            else:
                assert condition.lstrip("!") in known, (where, condition)
    for key, entries in CHAPTER.items():
        for entry in entries:
            check(key, entry.get("show_if", []))
            for choice in entry.get("choices", []):
                check(key, choice.get("show_if", []))
    for location in LOCATIONS.values():
        for group in ("npcs", "props", "interactions", "triggers", "doors", "exits"):
            for item in location.get(group, []):
                check((location["id"], group), item.get("show_if", []))


def test_every_quest_flag_can_be_set():
    known = _set_flags()
    for quest in loaders.load_quests().values():
        if quest.get("start_flag"):
            assert quest["start_flag"] in known, quest["id"]
        for step in quest["steps"]:
            assert step["flag"] in known, (quest["id"], step["id"])


def test_the_chapter_reaches_every_stage_in_order():
    advanced = [effects["stage"] for _, effects in _effects() if "stage" in effects]
    assert set(advanced) == set(STAGES) - {"morning"}
    # Each stage is entered by exactly one beat.
    assert len(advanced) == len(set(advanced))


def test_story_battles_send_kai_back_into_the_story():
    # The climax returns to Greymere's aftermath; every other story battle
    # returns to where it was fought (a world battle) and its win flag
    # unlocks the next beat.
    choir = ENCOUNTERS["court_sealed_choir"]
    assert choir["return"]["location"] == "greymere"
    assert choir["return"]["spawn"] in LOCATIONS["greymere"]["spawn_points"]
    for encounter_id in ("greymere_spar_danfor", "court_gallery_husk", "court_protect_joey", "court_anchor"):
        assert ENCOUNTERS[encounter_id].get("retry") is True, encounter_id


def test_assessments_cover_every_class_with_another_build():
    classes = loaders.load_classes()
    for class_id, record in classes.items():
        encounter = ENCOUNTERS[f"civara_assessment_{class_id}"]
        assessor = encounter["enemy_party"][0]
        assert assessor["class_id"] == class_id
        # Same class, different habits: an Entity and a non-default kit.
        assert assessor["entity_id"] and assessor["move_ids"] != record["move_ids"]
        assert "civara_assessment_won" in encounter["rewards"]["flags"]
