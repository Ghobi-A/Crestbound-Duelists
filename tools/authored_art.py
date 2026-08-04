"""
Crestbound Duelists — authored pixel art
=========================================
Hand-placed pixel maps for the characters, enemies and portraits the
player actually looks at.

This is deliberately NOT the parametric body builder in
overworld_sprites.py / generate_sprites.py. Every pixel here is written
out by hand in a palette-indexed table, the same way tools/generate_font.py
authors its glyphs. That is what lets Aren and the Riven-touched Raider
have genuinely different anatomy, posture and silhouette instead of one
torso rectangle under different colours.

Frames are authored per pose rather than derived by translating a base
sprite, so an attack has real anticipation and recoil rather than the
whole sprite sliding sideways.

See docs/AUTHORED_ART_PIPELINE.md for how externally produced art
replaces any of this.

Run:

    python tools/authored_art.py

Outputs (committed build artifacts, regenerable):
    game/assets/characters/aren/warrior/battle.png + battle.json
    game/assets/enemies/riven_raider/battle.png    + battle.json
    game/assets/portraits/aren-warrior/neutral.png
    game/assets/portraits/riven_raider/neutral.png
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "game" / "assets"

BATTLE_W, BATTLE_H = 40, 48
# Where the character's feet meet the floor, in frame pixels. Staging,
# shadows, rings and popups all derive from this, so a taller sprite
# needs no offset edits anywhere in GDScript.
BATTLE_ANCHOR = (20, 45)

PORTRAIT_W, PORTRAIT_H = 40, 44

# Palette-indexed art. '.' is transparent; every other character maps
# through a per-character palette, so a sprite's colour scheme lives in
# one place and the pixel map stays readable as a shape.
AREN_PALETTE = {
    "o": "14121c",  # outline
    "s": "e8c8a0",  # skin
    "S": "c79c72",  # skin shadow
    "h": "5a3f2a",  # hair
    "H": "76573a",  # hair light
    "c": "9c2f36",  # crimson coat
    "C": "c04a4a",  # coat highlight
    "d": "6a1f26",  # coat shadow
    "l": "3a4152",  # trousers / leather
    "L": "4d566b",  # leather light
    "b": "2a2028",  # boots
    "m": "8d93a5",  # mail / steel
    "M": "c2c8d8",  # steel highlight
    "g": "caa24a",  # crest gold trim
    "w": "d8dae4",  # blade
    "W": "ffffff",  # blade edge
}

RAIDER_PALETTE = {
    "o": "120e12",  # outline
    "s": "b08a6a",  # weathered skin
    "S": "8a6549",  # skin shadow
    "r": "6a2b2b",  # riven-touched flesh
    "R": "9b3b34",  # riven highlight
    "f": "4a3a2e",  # furs
    "F": "63503f",  # fur light
    "i": "56545e",  # rusted iron
    "I": "7c7a86",  # iron highlight
    "k": "2e2a2c",  # straps
    "v": "9b74d6",  # riven violet glow
    "V": "d9c4ff",  # violet core
    "a": "8a8f98",  # axe head
    "A": "c8ccd4",  # axe edge
}


def _blank(width: int, height: int) -> list[str]:
    return ["." * width for _ in range(height)]


def _paste(base: list[str], art: list[str], at_x: int, at_y: int) -> list[str]:
    """Composite a sub-map onto a frame; '.' in the overlay is see-through."""
    rows = [list(row) for row in base]
    for y, line in enumerate(art):
        for x, cell in enumerate(line):
            if cell == ".":
                continue
            ty, tx = at_y + y, at_x + x
            if 0 <= ty < len(rows) and 0 <= tx < len(rows[0]):
                rows[ty][tx] = cell
    return ["".join(row) for row in rows]


def render(pixel_map: list[str], palette: dict[str, str]) -> Image.Image:
    height = len(pixel_map)
    width = len(pixel_map[0])
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    pixels = image.load()
    for y, line in enumerate(pixel_map):
        if len(line) != width:
            raise ValueError(f"row {y} is {len(line)} wide, expected {width}")
        for x, cell in enumerate(line):
            if cell == ".":
                continue
            if cell not in palette:
                raise ValueError(f"row {y} col {x}: {cell!r} not in palette")
            hexcode = palette[cell]
            pixels[x, y] = (
                int(hexcode[0:2], 16), int(hexcode[2:4], 16), int(hexcode[4:6], 16), 255
            )
    return image


# ── Aren Vale, Warrior ───────────────────────────────────────────────
# Grounded, forward-weighted stance. Crimson coat over steel, hair swept
# back, a longsword held low across the body. Broad shoulders, narrow
# waist, boots planted apart — a fighter's outline, not a rectangle.

AREN_IDLE = [
    "........................................",
    "........................................",
    "..............oooooo....................",
    ".............ohhhhhho...................",
    "............ohhhHHhhho..................",
    "............ohhHHHHhhho.................",
    "...........ohhhHHhhhhhho................",
    "...........ohhossssohhho................",
    "...........ohosssssssoho................",
    "............osssssssso..................",
    "............osoSssoSso..................",
    "............ossssssso...................",
    "............oSsssssSo...................",
    ".............osSSSso....................",
    "..............ooooo.....................",
    "...........ooommmmmooo..................",
    ".........oommMMMMMMMmmoo................",
    "........ommMcccccccccMmmo...............",
    ".......ommMcccCCCCCcccMmmo..............",
    ".......omMcccCCggCCCcccMmo..............",
    "......omMccccCCggCCccccMmo..............",
    "......omccccccCggCcccccco...............",
    "......omcccccccggccccccco...............",
    "......omdccccccggccccccdo...............",
    ".......odddcccggcccdddo.................",
    ".......osoddddggddddoso.................",
    "......osso.oddddddo.osso................",
    ".....osso...oddddo...osso...............",
    ".....oso.....olllo....oso...............",
    ".....oo......ollllo.....oo..............",
    ".............ollllo.....................",
    "............ollLLllo....................",
    "............ollLLllo....................",
    "...........ollLLLLllo...................",
    "...........oll.oo.llo...................",
    "..........oll..oo..llo..................",
    "..........oll..oo..llo..................",
    "..........oll..oo..llo..................",
    "..........obb..oo..bbo..................",
    ".........obbbo.oo.obbbo.................",
    ".........obbbo.oo.obbbo.................",
    "........obbbbo.oo.obbbbo................",
    "........obbbbo.oo.obbbbo................",
    ".......obbbbbo.oo.obbbbbo...............",
    ".......oooooo..oo..oooooo...............",
    "........................................",
    "........................................",
    "........................................",
]
