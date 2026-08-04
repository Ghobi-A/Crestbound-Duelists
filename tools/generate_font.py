"""
Crestbound Duelists — pixel font generator
===========================================
Authors the interface typeface as an explicit 5x7 glyph table and emits a
BMFont pair (PNG atlas + .fnt descriptor) that Godot imports as a
FontFile.

Why a bitmap font at all: every screen was rendering in Godot's default
vector font, which anti-aliases against a 320x180 canvas and is the
single loudest "not art-directed yet" tell in the interface. A fixed
5x7 face lands every glyph on whole pixels at the game's native scale.

One face, one size. Hierarchy comes from colour, panel framing and
position rather than from mixing type sizes — mixing them is what forced
the old 6/8/10/12 spread, and a bitmap face only stays crisp at integer
multiples of its native size anyway.

Run:

    python tools/generate_font.py

Outputs (committed build artifacts, regenerable):
    game/assets/ui/crestbound_font.png
    game/assets/ui/crestbound_font.fnt
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
UI_DIR = ROOT / "game" / "assets" / "ui"

# Glyphs are authored as 5x7 but emitted in a 5x8 cell: the eighth row
# sits *below* the baseline so g/j/p/q/y have somewhere to put a tail.
# Without it every descender had to be squeezed above the baseline, which
# made lowercase 'g' render as a digit 9 ("Reckless Char9e").
GLYPH_W, AUTHORED_H, GLYPH_H = 5, 7, 8
# Glyphs are authored in a 5x7 cell but emitted *proportionally*: each
# character advertises the width of its own ink plus one column of
# spacing. A fixed 6px advance made "Warden Elara Thorne" 114px wide and
# it truncated inside the battle HUD's 96px name field; proportional
# spacing brings the same string under 90px and lets 'i', 'l', '.' and
# ':' cost what they actually occupy.
LETTER_SPACING = 1
SPACE_ADVANCE = 3
LINE_HEIGHT = GLYPH_H + 1
# Rows 0-6 sit on and above the baseline; row 7 hangs below it.
BASELINE = AUTHORED_H
COLUMNS = 16

# Declared em size. The codebase sizes text at 8, so declaring 8 here
# makes font_size 8 a 1:1 blit — a bitmap face only stays crisp at its
# native size or integer multiples of it.
DECLARED_SIZE = 8

# Every glyph is seven rows of five cells. '#' is ink, anything else is
# transparent. Caps and digits use the full body; lowercase sits on an
# x-height of five with descenders dropping below the baseline row.
GLYPHS: dict[str, list[str]] = {
    " ": ["     "] * 7,
    "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
    "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
    "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
    "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
    "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
    "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    "M": ["#...#", "##.##", "#.#.#", "#...#", "#...#", "#...#", "#...#"],
    "N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
    "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
    "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
    "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
    "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
    "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
    "a": ["     ", "     ", ".###.", "....#", ".####", "#...#", ".####"],
    "b": ["#....", "#....", "####.", "#...#", "#...#", "#...#", "####."],
    "c": ["     ", "     ", ".###.", "#....", "#....", "#....", ".###."],
    "d": ["....#", "....#", ".####", "#...#", "#...#", "#...#", ".####"],
    "e": ["     ", "     ", ".###.", "#...#", "#####", "#....", ".###."],
    "f": ["..##.", ".#...", "####.", ".#...", ".#...", ".#...", ".#..."],
    "g": ["     ", ".####", "#...#", "#...#", ".####", "....#", ".###."],
    "h": ["#....", "#....", "####.", "#...#", "#...#", "#...#", "#...#"],
    "i": ["..#..", "     ", ".##..", "..#..", "..#..", "..#..", ".###."],
    "j": ["...#.", "     ", "..##.", "...#.", "...#.", "#..#.", ".##.."],
    "k": ["#....", "#....", "#..#.", "#.#..", "##...", "#.#..", "#..#."],
    "l": [".##..", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "m": ["     ", "     ", "##.#.", "#.#.#", "#.#.#", "#...#", "#...#"],
    "n": ["     ", "     ", "####.", "#...#", "#...#", "#...#", "#...#"],
    "o": ["     ", "     ", ".###.", "#...#", "#...#", "#...#", ".###."],
    "p": ["     ", "####.", "#...#", "#...#", "####.", "#....", "#...."],
    "q": ["     ", ".####", "#...#", "#...#", ".####", "....#", "....#"],
    "r": ["     ", "     ", "#.##.", "##...", "#....", "#....", "#...."],
    "s": ["     ", "     ", ".####", "#....", ".###.", "....#", "####."],
    "t": [".#...", ".#...", "####.", ".#...", ".#...", ".#..#", "..##."],
    "u": ["     ", "     ", "#...#", "#...#", "#...#", "#...#", ".####"],
    "v": ["     ", "     ", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
    "w": ["     ", "     ", "#...#", "#...#", "#.#.#", "#.#.#", ".#.#."],
    "x": ["     ", "     ", "#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
    "y": ["     ", "#...#", "#...#", "#...#", ".####", "....#", ".###."],
    "z": ["     ", "     ", "#####", "...#.", "..#..", ".#...", "#####"],
    "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
    "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
    "3": ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
    "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
    "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
    "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
    "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
    "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
    "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
    ".": ["     ", "     ", "     ", "     ", "     ", ".##..", ".##.."],
    ",": ["     ", "     ", "     ", "     ", ".##..", ".##..", ".#..."],
    ":": ["     ", ".##..", ".##..", "     ", ".##..", ".##..", "     "],
    ";": ["     ", ".##..", ".##..", "     ", ".##..", ".#...", "     "],
    "!": ["..#..", "..#..", "..#..", "..#..", "..#..", "     ", "..#.."],
    "?": [".###.", "#...#", "....#", "...#.", "..#..", "     ", "..#.."],
    "'": ["..#..", "..#..", "     ", "     ", "     ", "     ", "     "],
    '"': [".#.#.", ".#.#.", "     ", "     ", "     ", "     ", "     "],
    "(": ["...#.", "..#..", ".#...", ".#...", ".#...", "..#..", "...#."],
    ")": [".#...", "..#..", "...#.", "...#.", "...#.", "..#..", ".#..."],
    "[": ["..##.", "..#..", "..#..", "..#..", "..#..", "..#..", "..##."],
    "]": [".##..", "..#..", "..#..", "..#..", "..#..", "..#..", ".##.."],
    "-": ["     ", "     ", "     ", "#####", "     ", "     ", "     "],
    "+": ["     ", "..#..", "..#..", "#####", "..#..", "..#..", "     "],
    "=": ["     ", "     ", "#####", "     ", "#####", "     ", "     "],
    "/": ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
    "\\": ["#....", "#....", ".#...", "..#..", "...#.", "....#", "....#"],
    "%": ["##..#", "##.#.", "..#..", ".#...", "#..##", "#..##", "     "],
    "<": ["...#.", "..#..", ".#...", "#....", ".#...", "..#..", "...#."],
    ">": [".#...", "..#..", "...#.", "....#", "...#.", "..#..", ".#..."],
    "*": ["     ", "..#..", "#.#.#", ".###.", "#.#.#", "..#..", "     "],
    "_": ["     ", "     ", "     ", "     ", "     ", "     ", "#####"],
    "#": [".#.#.", "#####", ".#.#.", ".#.#.", "#####", ".#.#.", "     "],
    # U+2014 EM DASH — used in screen titles ("ROUND 1 — choose actions").
    "—": ["     ", "     ", "     ", "#####", "     ", "     ", "     "],
    # U+2026 HORIZONTAL ELLIPSIS, used in dialogue.
    "…": ["     ", "     ", "     ", "     ", "     ", "     ", "#.#.#"],
}


# Descenders are authored at full 8-row height; every other glyph is
# padded with a blank eighth row by `normalised()` below.
DESCENDERS: dict[str, list[str]] = {
    "g": ["     ", "     ", ".###.", "#...#", "#...#", ".####", "....#", ".###."],
    "j": ["...#.", "     ", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
    "p": ["     ", "     ", "####.", "#...#", "#...#", "####.", "#....", "#...."],
    "q": ["     ", "     ", ".####", "#...#", "#...#", ".####", "....#", "....#"],
    "y": ["     ", "     ", "#...#", "#...#", "#...#", ".####", "....#", ".###."],
}


def normalised(char: str) -> list[str]:
    """The glyph as 8 rows: descenders as authored, everything else padded."""
    if char in DESCENDERS:
        return DESCENDERS[char]
    return GLYPHS[char] + ["     "]


def ink_span(bitmap: list[str]) -> tuple[int, int]:
    """Leftmost and rightmost columns containing ink; (-1, -1) if blank."""
    columns = [x for x in range(GLYPH_W) for y in range(GLYPH_H) if bitmap[y][x] == "#"]
    if not columns:
        return -1, -1
    return min(columns), max(columns)


def build_atlas() -> tuple[Image.Image, list[dict]]:
    """Pack every glyph into a grid and measure each one's ink width."""
    order = list(GLYPHS.keys())
    rows = (len(order) + COLUMNS - 1) // COLUMNS
    atlas = Image.new("RGBA", (COLUMNS * GLYPH_W, rows * GLYPH_H), (0, 0, 0, 0))
    pixels = atlas.load()

    placements: list[dict] = []
    for index, char in enumerate(order):
        col, row = index % COLUMNS, index // COLUMNS
        ox, oy = col * GLYPH_W, row * GLYPH_H
        bitmap = normalised(char)
        if len(bitmap) != GLYPH_H or any(len(line) != GLYPH_W for line in bitmap):
            raise ValueError(f"glyph {char!r} is not {GLYPH_W}x{GLYPH_H}")
        for y, line in enumerate(bitmap):
            for x, cell in enumerate(line):
                if cell == "#":
                    # White ink: Godot multiplies by the label's font colour,
                    # so one atlas serves every colour in the palette.
                    pixels[ox + x, oy + y] = (255, 255, 255, 255)

        first, last = ink_span(bitmap)
        if first < 0:
            placements.append(
                {"char": char, "x": ox, "y": oy, "w": 0, "advance": SPACE_ADVANCE}
            )
            continue
        width = last - first + 1
        placements.append({
            "char": char,
            "x": ox + first,
            "y": oy,
            "w": width,
            "advance": width + LETTER_SPACING,
        })
    return atlas, placements


def build_descriptor(atlas: Image.Image, placements: list[dict]) -> str:
    lines = [
        'info face="Crestbound" size=%d bold=0 italic=0 charset="" unicode=1 '
        'stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1'
        % DECLARED_SIZE,
        "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0"
        % (LINE_HEIGHT, BASELINE, atlas.width, atlas.height),
        'page id=0 file="crestbound_font.png"',
        "chars count=%d" % len(placements),
    ]
    for glyph in placements:
        lines.append(
            "char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=0 "
            "xadvance=%d page=0 chnl=15"
            % (
                ord(glyph["char"]), glyph["x"], glyph["y"],
                glyph["w"], GLYPH_H, glyph["advance"],
            )
        )
    return "\n".join(lines) + "\n"


def main() -> None:
    UI_DIR.mkdir(parents=True, exist_ok=True)
    atlas, placements = build_atlas()
    atlas.save(UI_DIR / "crestbound_font.png")
    (UI_DIR / "crestbound_font.fnt").write_text(
        build_descriptor(atlas, placements), encoding="utf-8"
    )
    widths = [g["advance"] for g in placements]
    print(
        "Font: %d glyphs, %dx%d atlas, advance %d-%d px -> %s"
        % (
            len(placements), atlas.width, atlas.height,
            min(widths), max(widths), UI_DIR / "crestbound_font.png",
        )
    )


if __name__ == "__main__":
    main()
