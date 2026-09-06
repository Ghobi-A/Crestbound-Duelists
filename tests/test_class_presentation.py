"""Validate production atlas geometry and stable class-to-outfit identity."""
import json
from pathlib import Path

import pytest
from PIL import Image

GAME = Path(__file__).resolve().parents[1] / "game"
MANIFEST = json.loads((GAME / "assets/rework/characters.json").read_text())
CLASSES = ("warrior", "guardian", "mage", "sorcerer", "assassin", "neutral")


def texture_size(path):
    with Image.open(GAME / path.removeprefix("res://")) as image:
        return image.size


def within(rect, size):
    x, y, width, height = rect
    return x >= 0 and y >= 0 and width > 0 and height > 0 and x + width <= size[0] and y + height <= size[1]


@pytest.mark.parametrize("class_id", CLASSES)
def test_class_art_bounds_and_identity(class_id):
    record = MANIFEST["characters"][f"kai_{class_id}"]
    assert record["display_name"] == "Kai"
    assert record["class_id"] == class_id
    assert f"aren/{class_id}" in record["aliases"]
    size = texture_size(record["atlas"])
    assert within(record["battle_rect"], size)
    assert within(record["portrait_rect"], size)
    width, height = record["battle_rect"][2:]
    x, y = record["foot_anchor"]
    assert 0 < x < width and 0 < y <= height
    world = record["overworld"]
    size = texture_size(world["atlas"])
    width, height = world["frame_size"]
    for column in range(4):
        assert within([column * width, world["row"], width, height], size)
    assert record["colour_key"] == "magenta"  # Verdant green must survive extraction.


def test_all_six_outfits_are_distinct_and_aliases_unambiguous():
    records = MANIFEST["characters"]
    crops = [tuple(records[f"kai_{key}"]["battle_rect"]) for key in CLASSES]
    assert len(set(crops)) == 6
    aliases = [alias for record in records.values() for alias in record["aliases"]]
    assert len(set(aliases)) == len(aliases)
