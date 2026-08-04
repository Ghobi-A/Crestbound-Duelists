"""
Crestbound Duelists — interface icon generator
===============================================
Authors the UI icon set as explicit 7x7 pixel bitmaps and packs them into
a single atlas with a name -> cell manifest.

7x7 is chosen to match the action menu's 9px row pitch: an icon can sit
beside a row of the pixel font without changing the list's rhythm.

Icons carry the same accent grammar as the panels — they are drawn in
whatever colour the call site passes, so a gold-tinted icon reads as the
player's command and a violet one as something targeting them.

Run:

    python tools/generate_icons.py

Outputs (committed build artifacts, regenerable):
    game/assets/ui/icons.png
    game/assets/ui/icons_manifest.json
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
UI_DIR = ROOT / "game" / "assets" / "ui"

ICON = 7
COLUMNS = 8

# '#' is ink, anything else transparent. Shapes are kept blocky and
# closed — at 7px a thin outline dissolves into noise at 1x.
ICONS: dict[str, list[str]] = {
    # Move slots, in the order the action menu lists them.
    "slot_basic": [       # a plain blade
        "....##.",
        "...##..",
        "..##...",
        ".##....",
        "###....",
        "##.....",
        "#......",
    ],
    "slot_signature": [   # a struck rune / burst
        "...#...",
        ".#.#.#.",
        "..###..",
        "###.###",
        "..###..",
        ".#.#.#.",
        "...#...",
    ],
    "slot_gambit": [      # a wagered die
        ".#####.",
        "#.....#",
        "#.#.#.#",
        "#.....#",
        "#.#.#.#",
        "#.....#",
        ".#####.",
    ],
    "slot_brace": [       # a guarding shield
        "#######",
        "#.....#",
        "#.###.#",
        "#.###.#",
        ".#...#.",
        "..#.#..",
        "...#...",
    ],
    # Battle states.
    "status_hexed": [     # a warding hex
        "..###..",
        ".#...#.",
        "#..#..#",
        "#.###.#",
        "#..#..#",
        ".#...#.",
        "..###..",
    ],
    "status_awakened": [  # the Crest diamond
        "...#...",
        "..###..",
        ".##.##.",
        "##...##",
        ".##.##.",
        "..###..",
        "...#...",
    ],
    "status_down": [      # a fallen marker
        ".......",
        "#.....#",
        ".#...#.",
        "..###..",
        ".#...#.",
        "#.....#",
        ".......",
    ],
    # The encounter objective, shown in the battle header.
    "objective": [        # crossed blades
        "#.....#",
        ".#...#.",
        "..#.#..",
        "...#...",
        "..#.#..",
        ".##.##.",
        "##...##",
    ],
}


def build() -> tuple[Image.Image, dict]:
    names = list(ICONS.keys())
    rows = (len(names) + COLUMNS - 1) // COLUMNS
    atlas = Image.new("RGBA", (COLUMNS * ICON, rows * ICON), (0, 0, 0, 0))
    pixels = atlas.load()

    coordinates: dict[str, list[int]] = {}
    for index, name in enumerate(names):
        col, row = index % COLUMNS, index // COLUMNS
        bitmap = ICONS[name]
        if len(bitmap) != ICON or any(len(line) != ICON for line in bitmap):
            raise ValueError(f"icon {name!r} is not {ICON}x{ICON}")
        for y, line in enumerate(bitmap):
            for x, cell in enumerate(line):
                if cell == "#":
                    # White ink so the call site can tint it to any accent.
                    pixels[col * ICON + x, row * ICON + y] = (255, 255, 255, 255)
        coordinates[name] = [col, row]

    manifest = {
        "icon_size": ICON,
        "columns": COLUMNS,
        "atlas": "icons.png",
        "icons": coordinates,
    }
    return atlas, manifest


def main() -> None:
    UI_DIR.mkdir(parents=True, exist_ok=True)
    atlas, manifest = build()
    atlas.save(UI_DIR / "icons.png")
    (UI_DIR / "icons_manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    print("Icons: %d at %dx%d -> %s" % (len(manifest["icons"]), ICON, ICON, UI_DIR / "icons.png"))


if __name__ == "__main__":
    main()
