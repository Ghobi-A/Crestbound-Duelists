"""Measure and annotate cast lineups rendered by scenes/tools/cast_lineup.tscn.

The Godot scene draws every overworld character through the real
OverworldSprite path, feet on one baseline per row, on a flat ground colour.
This script finds each character's opaque bounds in that render, converts
them to logical (320x180) pixels and reports, per character:

* visible standing height in each facing, against Kai's;
* height and foot drift across facings and across walk phases (a sprite
  that grows, shrinks, hops or slides while turning or walking).

It also writes a labelled contact sheet. Deterministic for a given render.

    python tools/cast_lineup.py measure <render.png> [<render.png> ...]
    python tools/cast_lineup.py sheet <before.png> <after.png> <out.png>
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

# Must match game/scripts/tools/cast_lineup.gd.
KEYS = ["aren/warrior", "aren/guardian", "elara", "mira", "townsfolk/farmboy", "townsfolk/herbalist_woman",
        "townsfolk/elder_woman", "townsfolk/village_elder", "townsfolk/farmhand_capped", "townsfolk/guard_sword",
        "townsfolk/guard_spear", "townsfolk/torch_bearer", "townsfolk/hooded_stranger", "route01_rowan",
        "route01_squire", "route01_challenger"]
LABELS = ["Kai", "Kai (Grd)", "Almyra", "Liora", "Joey", "Lena", "Senna", "Silas", "Gell", "Danfor", "Orrin",
          "Ferris", "Stranger", "Rowan", "Squire", "Challngr"]
GROUND = np.array([0x3C, 0x4A, 0x3C])
COLUMN, FIRST_FOOT, ROW, LEFT = 19.0, 38.0, 44.0, 12.0
LOGICAL_WIDTH = 320
# Half-width (logical px) of the central strip used to find the head, so a
# neighbour's raised spear or torch never counts as the top of this head.
STRIP = 3.5


def _cells(image: np.ndarray):
    scale = image.shape[1] / LOGICAL_WIDTH
    diff = np.abs(image[:, :, :3].astype(int) - GROUND).max(axis=2) > 18
    for row in range(4):
        foot = FIRST_FOOT + row * ROW
        for i, key in enumerate(KEYS):
            cx = LEFT + i * COLUMN
            x0, x1 = int((cx - STRIP) * scale), int((cx + STRIP) * scale)
            y0, y1 = max(0, int((foot - 37) * scale)), int((foot + 4) * scale)
            # Body rows: at least ~1.5 logical px of opaque sprite in the strip,
            # so a spear shaft or torch handle is not read as the head.
            ys = np.nonzero(diff[y0:y1, x0:x1].sum(axis=1) >= 1.5 * scale)[0]
            if ys.size == 0:
                yield row, key, None
                continue
            # Feet can stride outside the strip: find the lowest row across
            # the whole column instead.
            wx0, wx1 = int((cx - COLUMN / 2) * scale), int((cx + COLUMN / 2) * scale)
            feet = np.nonzero(diff[y0:y1, wx0:wx1].sum(axis=1) >= scale)[0]
            top, bottom = (y0 + ys.min()) / scale, (y0 + feet.max() + 1) / scale
            yield row, key, {"height": round(foot - top, 2), "foot_offset": round(bottom - foot, 2)}


def measure(path: Path) -> dict:
    image = np.asarray(Image.open(path).convert("RGB"))
    result: dict = {}
    for row, key, cell in _cells(image):
        result.setdefault(key, [None] * 4)[row] = cell
    return result


def summarise(facings: dict, walks: list[dict]) -> list[dict]:
    """Per character: standing height, vs Kai, and drift over facings/walks."""
    kai = facings["aren/warrior"][0]["height"]
    rows = []
    for key, label in zip(KEYS, LABELS):
        stand = [cell["height"] for cell in facings[key] if cell]
        feet = [cell["foot_offset"] for cell in facings[key] if cell]
        walk_heights = [cell["height"] for walk in walks for cell in walk[key] if cell]
        walk_feet = [cell["foot_offset"] for walk in walks for cell in walk[key] if cell]
        rows.append({"key": key, "label": label, "down": stand[0], "vs_kai": round(stand[0] - kai, 2),
                     "facing_spread": round(max(stand) - min(stand), 2),
                     "walk_spread": round(max(walk_heights) - min(walk_heights), 2) if walk_heights else 0.0,
                     "foot_drift": round(max(feet + walk_feet) - min(feet + walk_feet), 2)})
    return rows


def sheet(before: Path, after: Path, out: Path) -> None:
    images = [Image.open(before).convert("RGB"), Image.open(after).convert("RGB")]
    width, height = images[0].size
    canvas = Image.new("RGB", (width, height * 2 + 120), (18, 20, 26))
    draw = ImageDraw.Draw(canvas)
    scale = width / LOGICAL_WIDTH
    for index, (image, title) in enumerate(zip(images, ("BEFORE", "AFTER"))):
        top = 60 + index * (height + 60)
        canvas.paste(image, (0, top))
        draw.text((16, top - 44), title, fill=(240, 214, 140))
        for row in range(4):
            foot = top + (FIRST_FOOT + row * ROW) * scale
            kai_top = foot - 24 * scale
            draw.line([(0, foot), (width, foot)], fill=(230, 90, 80), width=2)
            draw.line([(0, kai_top), (width, kai_top)], fill=(120, 170, 240), width=1)
        for i, label in enumerate(LABELS):
            draw.text((int((LEFT + i * COLUMN - 8) * scale), top - 18), label, fill=(220, 220, 220))
    canvas.save(out)


def main(argv: list[str]) -> None:
    if argv[0] == "measure":
        print(json.dumps({Path(p).name: measure(Path(p)) for p in argv[1:]}, indent=1))
    elif argv[0] == "sheet":
        sheet(Path(argv[1]), Path(argv[2]), Path(argv[3]))
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
