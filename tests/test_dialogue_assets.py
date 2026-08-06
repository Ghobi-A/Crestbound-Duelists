"""Dialogue-referenced assets must actually exist.

`DialogueBox` reads an optional "portrait" field per entry and, if the
path resolves, shows a portrait beside the text — but it fails silent:
a missing or renamed asset just means no portrait, never an error. A
typo here plays through fine in-engine and is easy to miss, so it's
checked here instead.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
DIALOGUE_DIR = REPO_ROOT / "game" / "data" / "dialogue"
PORTRAITS_DIR = REPO_ROOT / "game" / "assets" / "portraits"

DIALOGUE_FILES = sorted(DIALOGUE_DIR.glob("*.json"))


def _portrait_references() -> list[tuple[str, str, str]]:
    """(file name, dialogue key, portrait value) for every entry that sets one."""
    refs: list[tuple[str, str, str]] = []
    for path in DIALOGUE_FILES:
        data = json.loads(path.read_text(encoding="utf-8"))
        for key, entries in data.items():
            for entry in entries:
                portrait = entry.get("portrait")
                if portrait:
                    refs.append((path.name, key, portrait))
    return refs


@pytest.mark.parametrize("file_name,key,portrait", _portrait_references())
def test_dialogue_portrait_asset_exists(file_name: str, key: str, portrait: str) -> None:
    assert (PORTRAITS_DIR / portrait / "neutral.png").is_file(), (
        f"{file_name}:{key} references portrait '{portrait}', "
        f"but {PORTRAITS_DIR / portrait / 'neutral.png'} does not exist"
    )


@pytest.mark.parametrize("path", DIALOGUE_FILES, ids=lambda p: p.name)
def test_dialogue_file_is_valid_json(path: Path) -> None:
    json.loads(path.read_text(encoding="utf-8"))


@pytest.mark.parametrize("path", DIALOGUE_FILES, ids=lambda p: p.name)
def test_dialogue_entries_have_speaker_and_lines(path: Path) -> None:
    data = json.loads(path.read_text(encoding="utf-8"))
    for key, entries in data.items():
        assert isinstance(entries, list) and entries, f"{path.name}:{key} has no entries"
        for entry in entries:
            assert "speaker" in entry, f"{path.name}:{key} entry missing 'speaker'"
            lines = entry.get("lines")
            assert isinstance(lines, list) and lines, f"{path.name}:{key} entry has no lines"
