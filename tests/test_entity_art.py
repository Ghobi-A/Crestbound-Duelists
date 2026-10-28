"""Every Bonded Entity has painted HD idle art the battle stage can scale."""
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ENTITIES = json.loads((ROOT / "game/data/entities.json").read_text())
ENTITIES = ENTITIES.get("entities", ENTITIES)


def test_every_entity_has_hd_idle_art():
    for key in ENTITIES:
        folder = ROOT / "game/assets/entities" / key
        sidecar = json.loads((folder / "idle.json").read_text())
        width, height = Image.open(folder / "idle.png").size
        assert width == sidecar["frame_width"] * sidecar["frame_count"] and height == sidecar["frame_height"], key
        # Painted sources, not the old 32px placeholder blocks.
        assert sidecar["frame_height"] >= 96 and sidecar["display_height"] > 0, key
        assert (ROOT / "tools/entity_sources" / f"{key}.png").exists(), key
