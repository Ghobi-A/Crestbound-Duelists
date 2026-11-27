"""Authored story conversations are staged; incidental talk stays compact.

DialogueBox stages a conversation whose first entry sets "staging": "scene"
(StoryStage: the location as a backdrop and the cast drawn large from their
battle sheets). Chapter One conversations hold one variant per point in the
story ("show_if"); DialogueBox keeps the variants whose conditions hold, so
staging may also open a variant. The Godot presentation smoke test drives
the reveal and progression; this checks the data contract that decides what
is staged.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game"
DIALOGUE = {}
for path in sorted((GAME / "data/dialogue").glob("*.json")):
    DIALOGUE.update(json.loads(path.read_text(encoding="utf-8")))
CHARACTERS = json.loads((GAME / "assets/rework/characters.json").read_text())["characters"]
CHAPTER = json.loads((GAME / "data/dialogue/chapter_one.json").read_text(encoding="utf-8"))
LEGACY_KEYS = {"elara_intro", "mira_intro", "court_entrance", "post_battle", "battle_intro"}
STORY_KEYS = LEGACY_KEYS | {key for key, entries in CHAPTER.items() if any(e.get("staging") for e in entries)}


def _staged(key: str) -> bool:
    return any(entry.get("staging") == "scene" for entry in DIALOGUE[key])


def _battle_sheet(portrait: str) -> str | None:
    for record_id, record in CHARACTERS.items():
        if portrait == record_id or portrait in record.get("aliases", []):
            return record.get("battle_sheet")
    return None


def test_story_scenes_are_staged_and_incidental_talk_is_not():
    staged = {key for key in DIALOGUE if _staged(key)}
    assert staged == STORY_KEYS
    assert all(not _staged(key) for key in DIALOGUE if key.endswith("_flavor"))
    # The chapter's main beats are all staged scenes.
    for key in ("morning_wake", "almyra_arrives", "danfor_cordon", "chamber_bond", "aftermath", "civara_classification"):
        assert key in STORY_KEYS, key


def test_staging_is_only_set_where_a_variant_starts():
    for key, entries in DIALOGUE.items():
        for index, entry in enumerate(entries[1:], start=1):
            if "staging" in entry:
                assert entry.get("show_if") != entries[index - 1].get("show_if"), (key, index)


def test_every_staged_speaker_has_large_art_with_a_sidecar():
    for key in STORY_KEYS:
        for entry in DIALOGUE[key]:
            portrait = entry.get("portrait")
            if not portrait:
                continue  # narration
            sheet = _battle_sheet(portrait)
            assert sheet, f"{key}: {portrait} has no battle sheet to stage"
            png = GAME / sheet.removeprefix("res://")
            assert png.is_file() and png.with_suffix(".json").is_file(), sheet


def test_kai_can_stand_in_every_story_scene_as_any_class():
    for record in CHARACTERS.values():
        if record.get("class_id"):
            png = GAME / str(record.get("battle_sheet", "")).removeprefix("res://")
            assert png.is_file() and png.with_suffix(".json").is_file(), record["class_id"]


def test_reveal_completes_before_advancing():
    box = (GAME / "scripts/ui/dialogue_box.gd").read_text()
    confirm = box[box.index("func confirm()"):box.index("func _process(")]
    assert confirm.index("if revealing:") < confirm.index("complete_reveal()") < confirm.index("_advance()")
    assert 'is_action_pressed("interact") or event.is_action_pressed("cancel")' in box
    project = (GAME / "project.godot").read_text()
    for action in ("interact", "cancel", "move_up", "move_down", "move_left", "move_right"):
        block = project[project.index(f"\n{action}={{"):]
        block = block[: block.index("\n}\n")]
        assert "InputEventJoypadButton" in block, f"{action} has no controller binding"
