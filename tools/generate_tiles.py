"""
Crestbound Duelists — Greymere tile and prop atlas generator
=============================================================
Authors the moonlit Greymere tileset as hand-placed pixel clusters:
16x16 terrain tiles with 5-step colour ramps, autotiled path and water
transitions, building parts, and 16x24 props.

Art direction: a border town at night. Desaturated blue-shifted foliage
and stone, cool moonlight rim-lighting from the upper left, warm Crest
gold reserved for lit windows, lanterns and the notice seal, spectral
violet reserved for the Hollow Court arch — so the eye is drawn to the
two things that matter: where people are, and where the story goes.

All designs are original to Crestbound Duelists. Run:

    python tools/generate_tiles.py

Outputs (committed as build artifacts, regenerable):
    game/assets/tiles/greymere_atlas.png    16x16 terrain tiles
    game/assets/tiles/greymere_props.png    16x24 props
    game/assets/tiles/tiles_manifest.json   name -> atlas coordinate
    game/assets/tiles/vignette.png          320x180 screen edge falloff
    game/assets/tiles/glow.png              48x48 additive lantern pool
"""

from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image

from generate_sprites import Px, c

ROOT = Path(__file__).resolve().parent.parent
TILES_DIR = ROOT / "game" / "assets" / "tiles"

TILE = 16
PROP_W, PROP_H = 16, 24
ATLAS_COLUMNS = 16

# ── Ramps ────────────────────────────────────────────────────────────
# Each ramp runs darkest -> lightest. Five steps is enough for readable
# 16px tiles without the banding a longer ramp invites at this size.

GRASS = [c("1a2720"), c("24352a"), c("2f4534"), c("3c563f"), c("4b684b")]
# Meadow variation for ',' tiles. Kept very close to GRASS: pushed
# further toward brown it reads as square patches of a different terrain
# rather than as uneven turf.
GRASS_DRY = [c("1c2620"), c("26332a"), c("324133"), c("3f5140"), c("4d6249")]
PATH = [c("2a2620"), c("3a352b"), c("4a4436"), c("5c5443"), c("6e6552")]
WATER = [c("101a2a"), c("16243a"), c("1d3150"), c("2a4570"), c("4a6f9e")]
STONE = [c("1a1c24"), c("262932"), c("343845"), c("454a5a"), c("5a6070")]
ROOF = [c("1c1a26"), c("272433"), c("332f42"), c("423d54"), c("524c66")]
PLASTER = [c("201c1a"), c("2e2823"), c("3d352d"), c("4d4338"), c("5e5244")]
WOOD = [c("1e1611"), c("2c211a"), c("3c2d23"), c("4d3a2c"), c("5f4836")]
GOLD = [c("4a3410"), c("7a5518"), c("b07d24"), c("e0a83a"), c("ffd977")]
VIOLET = [c("241a38"), c("372552"), c("4e3374"), c("6b47a0"), c("9b74d6")]
FOLIAGE = [c("101a15"), c("17251c"), c("1f3325"), c("2a4330"), c("37553c")]
# Damp bank around the pond. Deliberately close to the turf ramp: a pale
# shore would outline the water as a rectangle instead of easing into it.
MUD = [c("161c19"), c("1d2420"), c("262d26"), c("31382d"), c("3d4436")]

SPECTRAL_WHITE = c("d9c4ff")
NIGHT_GLASS = c("1b2436")

# Autotile mask bits: a set bit means "the neighbour on that side is the
# same terrain family", so an unset bit is where a transition is drawn.
N, E, S, W = 1, 2, 4, 8

# Irregular but fixed edge profiles keep transitions organic while
# staying identical every run and seamless between adjacent tiles.
EDGE_BITE = [1, 0, 1, 2, 1, 0, 1, 1, 2, 1, 0, 1, 1, 0, 1, 1]
SHORE_BITE = [2, 1, 1, 2, 2, 1, 1, 2, 2, 1, 2, 2, 1, 1, 2, 1]


def dither(px: Px, x: int, y: int, w: int, h: int, colour: tuple, parity: int = 0) -> None:
    """Checkerboard-dither `colour` over a region to blend two ramp steps."""
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            if (xx + yy) % 2 == parity:
                px.dot(xx, yy, colour)


def speckle(px: Px, colour: tuple, step: int, offset: int = 0) -> None:
    """Deterministic scattered texture — a cheap way to break up flat fill."""
    for i in range(TILE * TILE):
        if (i * 7 + offset) % step == 0:
            px.dot(i % TILE, i // TILE, colour)


# ── Terrain ──────────────────────────────────────────────────────────

def grass_tile(variant: int) -> Px:
    """Moonlit turf.

    Variant 0 covers most of the map, so it is deliberately almost flat:
    any feature drawn here repeats across every tile and reads as a
    lattice rather than as texture. Detail lives in the sparse variants
    instead, and the renderer scatters those thinly.
    """
    px = Px(TILE, TILE)
    ramp = GRASS_DRY if variant >= 4 else GRASS
    px.rect(0, 0, TILE, TILE, ramp[2])

    if variant == 0:
        # Two pixels only — enough to stop banding, too little to pattern.
        px.dot(11, 4, ramp[1])
        px.dot(3, 12, ramp[3])
    elif variant == 1:
        for bx, by in ((4, 9), (5, 8), (6, 9), (10, 6), (11, 5), (12, 6)):
            px.dot(bx, by, ramp[3])
            px.dot(bx, by + 1, ramp[1])
    elif variant == 2:
        for sx, sy in ((3, 4), (9, 11), (12, 3)):
            px.rect(sx, sy, 2, 2, STONE[1])
            px.dot(sx, sy, STONE[2])
    elif variant == 3:
        # Pale night blooms. Gold is the Crest's colour and is kept for
        # lamps and windows, so these stay cool and very sparse.
        for fx, fy in ((5, 6), (10, 10)):
            px.dot(fx, fy, c("8f9fb4"))
            px.dot(fx + 1, fy + 1, ramp[3])
    elif variant == 5:
        for bx in (3, 7, 12):
            px.dot(bx, 10, ramp[3])
            px.dot(bx, 9, ramp[1])
    return px


def _apply_edges(px: Px, mask: int, bite: list[int], colour: tuple, shade: tuple) -> None:
    """Bite an irregular fringe into every side whose neighbour differs."""
    if not mask & N:
        for x in range(TILE):
            depth = bite[x]
            if depth:
                px.rect(x, 0, 1, depth, colour)
                px.dot(x, depth, shade)
    if not mask & S:
        for x in range(TILE):
            depth = bite[(x + 5) % TILE]
            if depth:
                px.rect(x, TILE - depth, 1, depth, colour)
                px.dot(x, TILE - depth - 1, shade)
    if not mask & W:
        for y in range(TILE):
            depth = bite[(y + 3) % TILE]
            if depth:
                px.rect(0, y, depth, 1, colour)
                px.dot(depth, y, shade)
    if not mask & E:
        for y in range(TILE):
            depth = bite[(y + 9) % TILE]
            if depth:
                px.rect(TILE - depth, y, depth, 1, colour)
                px.dot(TILE - depth - 1, y, shade)


def path_tile(mask: int) -> Px:
    """Packed earth road; grass encroaches on every non-road edge."""
    px = Px(TILE, TILE)
    px.rect(0, 0, TILE, TILE, PATH[2])
    speckle(px, PATH[1], 9, mask)
    speckle(px, PATH[3], 12, mask + 6)
    # Cart ruts only on straight north-south runs, and broken up so they
    # read as worn tracks rather than ruled lines.
    if mask & N and mask & S:
        for y in range(TILE):
            if (y * 3 + mask) % 7 > 1:
                px.dot(5, y, PATH[1])
                px.dot(10, y, PATH[1])
    for sx, sy in ((3, 6), (12, 11)):
        px.dot(sx, sy, PATH[4])
    _apply_edges(px, mask, EDGE_BITE, GRASS[2], GRASS[1])
    return px


def water_tile(mask: int) -> Px:
    """Still moonlit water with a pale shore where it meets land."""
    px = Px(TILE, TILE)
    px.rect(0, 0, TILE, TILE, WATER[2])
    # Depth gradient: darker away from the lit shore, blended with one
    # dither band rather than a hard step.
    px.rect(0, 0, TILE, 5, WATER[1])
    dither(px, 0, 5, TILE, 2, WATER[1], parity=1)
    for wy in (3, 8, 12):
        offset = (wy + mask) % 4
        px.rect(2 + offset, wy, 6, 1, WATER[3])
        px.rect(9 + offset // 2, wy + 1, 3, 1, WATER[3])
        px.rect(4 + offset, wy + 1, 3, 1, WATER[0])
    # A single bright glint sells "moonlight" better than many dim ones.
    if mask == (N | E | S | W):
        px.rect(9, 5, 3, 1, WATER[4])
        px.dot(11, 6, WATER[4])
    # A damp bank, wide enough to read as a transition rather than an
    # outline: mud at the waterline, drying out toward the turf.
    _apply_edges(px, mask, [d + 2 for d in SHORE_BITE], MUD[3], MUD[4])
    _apply_edges(px, mask, SHORE_BITE, MUD[1], MUD[2])
    # Moonlight catches the near lip of the north bank only, giving the
    # pond a light direction instead of a uniform frame.
    if not mask & N:
        for x in range(TILE):
            px.dot(x, SHORE_BITE[x], WATER[4] if x % 4 == 0 else MUD[2])
    # Reeds break the waterline where the bank meets turf.
    if not mask & W:
        for ry in (3, 7, 12):
            px.dot(1, ry, FOLIAGE[3])
            px.dot(1, ry - 1, FOLIAGE[4])
    if not mask & E:
        for ry in (5, 10):
            px.dot(TILE - 2, ry, FOLIAGE[3])
            px.dot(TILE - 2, ry - 1, FOLIAGE[4])
    return px


def wall_tile(variant: int) -> Px:
    """Ruined boundary stonework: three courses, mossed and moonlit."""
    px = Px(TILE, TILE)
    px.rect(0, 0, TILE, TILE, STONE[1])
    courses = ((0, 5), (6, 5), (12, 4))
    for index, (top, height) in enumerate(courses):
        offset = (index + variant) % 2 * 4
        px.rect(0, top, TILE, height, STONE[2])
        px.hline(0, top, TILE, STONE[3])          # moonlit upper edge
        px.hline(0, top + height - 1, TILE, STONE[0])  # mortar shadow
        for seam in range(offset, TILE + offset, 8):
            if seam < TILE:
                px.vline(seam, top, height - 1, STONE[1])
    if variant == 1:
        for mx, my in ((2, 7), (3, 7), (3, 8), (11, 1), (12, 1)):
            px.dot(mx, my, FOLIAGE[2])
    elif variant == 2:
        px.rect(9, 6, 3, 2, STONE[0])  # a stone knocked out of the course
        px.dot(9, 6, STONE[1])
    return px


def roof_tile(kind: str) -> Px:
    """Slate shingles, ridge cap lit from above, dark eave at the bottom."""
    px = Px(TILE, TILE)
    px.rect(0, 0, TILE, TILE, ROOF[2])
    # Ridge cap along the top.
    px.hline(0, 0, TILE, ROOF[4])
    px.hline(0, 1, TILE, ROOF[3])
    # Overlapping shingle courses: each course is lit along its exposed
    # upper lip and shadowed where the course below tucks under it.
    for index, row in enumerate((3, 8)):
        offset = 0 if index % 2 == 0 else 4
        px.hline(0, row, TILE, ROOF[3])
        px.rect(0, row + 1, TILE, 3, ROOF[2])
        px.hline(0, row + 4, TILE, ROOF[0])
        for seam in range(offset, TILE + offset, 8):
            if seam < TILE:
                px.vline(seam, row + 1, 3, ROOF[1])
                px.dot(seam + 1, row + 1, ROOF[3])
        dither(px, 0, row + 3, TILE, 1, ROOF[1], parity=index)
    # Eave: the roof edge overhangs into shadow.
    px.hline(0, TILE - 3, TILE, ROOF[1])
    px.hline(0, TILE - 2, TILE, ROOF[0])
    px.hline(0, TILE - 1, TILE, c("0d0c14"))
    if kind == "left":
        px.vline(0, 0, TILE, ROOF[3])
        px.vline(1, 2, TILE - 4, ROOF[2])
    elif kind == "right":
        px.vline(TILE - 1, 0, TILE, ROOF[0])
        px.vline(TILE - 2, 2, TILE - 4, ROOF[1])
    return px


def house_tile(kind: str) -> Px:
    """Plaster between timber framing; a lit window is the warm accent."""
    px = Px(TILE, TILE)
    px.rect(0, 0, TILE, TILE, PLASTER[2])
    speckle(px, PLASTER[1], 13, 2)
    px.hline(0, 0, TILE, PLASTER[0])       # under the eave
    px.hline(0, 1, TILE, PLASTER[3])
    px.rect(0, TILE - 3, TILE, 3, STONE[1])  # footing course
    px.hline(0, TILE - 3, TILE, STONE[2])

    if kind == "window":
        px.rect(4, 4, 8, 7, WOOD[1])
        px.rect(5, 5, 6, 5, GOLD[2])
        px.rect(6, 6, 4, 3, GOLD[3])
        px.dot(6, 6, GOLD[4])
        px.dot(7, 6, GOLD[4])
        px.vline(8, 5, 5, WOOD[2])         # window bar
        px.hline(4, 11, 8, WOOD[2])        # sill
    elif kind == "left":
        px.vline(0, 1, TILE - 4, WOOD[2])
        px.vline(1, 1, TILE - 4, WOOD[1])
    elif kind == "right":
        px.vline(TILE - 1, 1, TILE - 4, WOOD[1])
        px.vline(TILE - 2, 1, TILE - 4, WOOD[2])
    elif kind == "shuttered":
        px.rect(4, 4, 8, 7, WOOD[2])
        px.rect(5, 5, 6, 5, WOOD[1])
        px.vline(8, 5, 5, WOOD[3])
        px.hline(4, 11, 8, WOOD[3])
    return px


def door_tile() -> Px:
    """Planked door with a gold handle and light spilling onto the step."""
    px = Px(TILE, TILE)
    px.rect(0, 0, TILE, TILE, PLASTER[2])
    px.hline(0, 0, TILE, PLASTER[0])
    px.hline(0, 1, TILE, PLASTER[3])
    px.rect(3, 2, 10, TILE - 4, WOOD[1])
    px.rect(4, 3, 8, TILE - 6, WOOD[2])
    for plank in (6, 9):
        px.vline(plank, 3, TILE - 7, WOOD[1])
    px.hline(4, 4, 8, WOOD[3])             # lintel highlight
    px.dot(10, 9, GOLD[3])                 # handle
    px.dot(10, 10, GOLD[1])
    px.rect(2, TILE - 2, 12, 2, STONE[2])  # threshold step
    px.hline(3, TILE - 2, 10, STONE[3])
    dither(px, 4, TILE - 3, 8, 1, GOLD[0], parity=0)  # warm spill
    return px


def court_arch_tile() -> Px:
    """The Hollow Court entrance: cold violet stone around a lit void.

    The only spectral violet in Greymere, so it reads as the one place in
    town that is not ordinary.
    """
    px = Px(TILE, TILE)
    px.rect(0, 0, TILE, TILE, VIOLET[1])
    px.rect(1, 1, TILE - 2, TILE - 1, VIOLET[2])
    px.hline(0, 0, TILE, VIOLET[3])
    for jamb in (0, 1, TILE - 2, TILE - 1):
        px.vline(jamb, 1, TILE - 1, VIOLET[1] if jamb < 2 else VIOLET[0])
    px.vline(1, 1, TILE - 1, VIOLET[3])
    # Void opening.
    px.rect(4, 4, 8, TILE - 4, c("07060d"))
    px.rect(5, 3, 6, 2, c("07060d"))
    px.dot(4, 4, VIOLET[0])
    px.dot(11, 4, VIOLET[0])
    # Crest fragment glow suspended in the dark.
    px.rect(7, 8, 2, 3, VIOLET[4])
    px.dot(7, 7, VIOLET[3])
    px.dot(8, 11, VIOLET[3])
    px.dot(7, 9, SPECTRAL_WHITE)
    px.dot(8, 9, SPECTRAL_WHITE)
    for gx, gy in ((6, 9), (9, 9), (7, 6), (8, 12)):
        px.dot(gx, gy, VIOLET[3])
    # Keystone carved with the Warden's mark.
    px.dot(7, 1, GOLD[2])
    px.dot(8, 1, GOLD[2])
    px.dot(7, 2, GOLD[1])
    px.dot(8, 2, GOLD[1])
    return px


def notice_tile() -> Px:
    """Posted Crest restriction: parchment, gold seal, weathered posts."""
    px = Px(TILE, TILE)
    px.rect(3, 2, 1, 12, WOOD[1])
    px.rect(12, 2, 1, 12, WOOD[1])
    px.rect(2, 2, 12, 10, WOOD[2])
    px.hline(2, 2, 12, WOOD[3])
    px.rect(3, 3, 10, 8, c("b8ae8c"))
    px.rect(3, 3, 10, 1, c("d0c6a2"))
    for line_y in (5, 7, 9):
        px.hline(4, line_y, 8 if line_y != 9 else 6, c("6a6350"))
    px.dot(11, 9, GOLD[2])                 # wax seal
    px.dot(11, 10, GOLD[1])
    px.rect(2, 12, 12, 1, WOOD[0])
    return px


# ── Ground decals ────────────────────────────────────────────────────
# Flat, walkable detail painted over the turf. These carry the interior
# density: props need a blocking tile to stand on, but ground wear can
# sit anywhere without implying collision.

# Irregular alpha edge so a decal fades into turf instead of showing a
# 16px square. Indexed by distance from the tile centre.
DECAL_EDGE = [7, 6, 7, 8, 7, 6, 6, 7, 8, 7, 6, 7, 7, 6, 7, 6]


def _decal_mask(px: Px, radius_profile: list[int], fill: tuple) -> None:
    """Fill a soft blob centred in the tile using a per-angle radius."""
    centre = (TILE - 1) / 2.0
    for y in range(TILE):
        for x in range(TILE):
            dx, dy = x - centre, y - centre
            distance = math.hypot(dx, dy)
            angle = int((math.atan2(dy, dx) + math.pi) / (2 * math.pi) * TILE) % TILE
            if distance <= radius_profile[angle] - 0.5:
                px.dot(x, y, fill)


def dirt_decal(variant: int) -> Px:
    """Ground worn bare by footfall — placed where people actually walk."""
    px = Px(TILE, TILE)
    profile = [max(4, d - variant) for d in DECAL_EDGE]
    _decal_mask(px, profile, PATH[1])
    inner = [max(2, d - 3) for d in profile]
    _decal_mask(px, inner, PATH[2])
    for sx, sy in ((6, 7), (9, 9), (7, 11)):
        px.dot(sx, sy, PATH[3])
    return px


def gravel_decal(side: str) -> Px:
    """Loose stone verge hugging one edge of the road.

    Drawn as a directional strip rather than a blob: a verge is a border
    condition, and circular patches in a column read as machine output.
    """
    px = Px(TILE, TILE)
    for y in range(TILE):
        width = 4 + (y * 5 % 3)
        for step in range(width):
            x = TILE - 1 - step if side == "east" else step
            shade = PATH[1] if step < width - 1 else PATH[0]
            px.dot(x, y, shade)
    for sx, sy in ((2, 3), (3, 9), (1, 13), (4, 6)):
        x = TILE - 1 - sx if side == "east" else sx
        px.dot(x, sy, STONE[2])
    return px


def flowerbed_decal() -> Px:
    """A tended bed — evidence somebody lives here and cares."""
    px = Px(TILE, TILE)
    _decal_mask(px, [d - 2 for d in DECAL_EDGE], PATH[0])
    _decal_mask(px, [d - 3 for d in DECAL_EDGE], GRASS[1])
    for fx, fy in ((5, 6), (9, 5), (7, 10), (11, 8)):
        px.dot(fx, fy, GRASS[4])
        px.dot(fx, fy - 1, GOLD[2])
        px.dot(fx + 1, fy + 1, GRASS[3])
    return px


def tallgrass_decal() -> Px:
    """Unmown turf: blades break the silhouette without blocking passage."""
    px = Px(TILE, TILE)
    for bx, by in ((2, 11), (5, 9), (8, 12), (11, 10), (13, 13), (6, 13)):
        px.dot(bx, by + 1, GRASS[1])
        px.dot(bx, by, GRASS[3])
        px.dot(bx, by - 1, GRASS[4])
        px.dot(bx + 1, by, GRASS[1])
    return px


# ── Props (16x24, anchored to the bottom of a tile) ───────────────────

def tree_prop(variant: int) -> Px:
    """Canopy tree for the treeline. Moonlight rims the upper-left mass."""
    px = Px(PROP_W, PROP_H)
    px.rect(7, 14, 2, 9, WOOD[1])
    px.vline(7, 14, 9, WOOD[2])
    px.dot(6, 20, WOOD[1])
    px.dot(9, 18, WOOD[1])

    lobes = (
        [(8, 7, 6), (4, 10, 4), (12, 10, 4), (8, 13, 5)]
        if variant == 0
        else [(7, 8, 6), (12, 9, 4), (4, 11, 4), (9, 13, 5)]
    )
    for cx, cy, radius in lobes:
        for y in range(cy - radius, cy + radius + 1):
            for x in range(cx - radius, cx + radius + 1):
                if (x - cx) ** 2 + (y - cy) ** 2 <= radius * radius:
                    px.dot(x, y, FOLIAGE[2])
    # Shade the underside, then rim-light the moonward side.
    for y in range(PROP_H):
        for x in range(PROP_W):
            if px.img.getpixel((x, y))[3] == 0:
                continue
            if px.img.getpixel((x, min(y + 3, PROP_H - 1)))[3] == 0:
                px.dot(x, y, FOLIAGE[1])
    for cx, cy, radius in lobes:
        for angle in range(140, 260, 12):
            rx = int(cx + math.cos(math.radians(angle)) * (radius - 0.5))
            ry = int(cy + math.sin(math.radians(angle)) * (radius - 0.5))
            if px.img.getpixel((rx, ry))[3] > 0:
                px.dot(rx, ry, FOLIAGE[4])
                px.dot(rx, ry + 1, FOLIAGE[3])
    speckle_positions = ((6, 9), (10, 12), (5, 13), (11, 8))
    for sx, sy in speckle_positions:
        if px.img.getpixel((sx, sy))[3] > 0:
            px.dot(sx, sy, FOLIAGE[0])
    return px


def lamp_prop() -> Px:
    """Iron lamp post — the warm anchor points along the road."""
    px = Px(PROP_W, PROP_H)
    px.rect(7, 8, 2, 15, STONE[1])
    px.vline(7, 8, 15, STONE[2])
    px.rect(5, 21, 6, 2, STONE[1])
    px.hline(5, 21, 6, STONE[2])
    # Lantern housing.
    px.rect(5, 2, 6, 7, STONE[0])
    px.rect(6, 3, 4, 5, GOLD[2])
    px.rect(6, 4, 4, 3, GOLD[3])
    px.rect(7, 4, 2, 2, GOLD[4])
    px.hline(5, 1, 6, STONE[2])
    px.dot(7, 0, STONE[1])
    px.dot(8, 0, STONE[1])
    # Light falling on the post below the lantern.
    px.dot(7, 9, GOLD[1])
    px.dot(8, 9, GOLD[1])
    return px


def barrel_prop() -> Px:
    px = Px(PROP_W, PROP_H)
    px.rect(4, 12, 8, 11, WOOD[1])
    px.rect(5, 12, 6, 11, WOOD[2])
    px.vline(5, 13, 9, WOOD[3])
    px.hline(4, 15, 8, WOOD[0])
    px.hline(4, 20, 8, WOOD[0])
    px.rect(5, 11, 6, 2, WOOD[3])
    px.hline(6, 11, 4, WOOD[4])
    return px


def crate_prop() -> Px:
    px = Px(PROP_W, PROP_H)
    px.rect(3, 13, 10, 10, WOOD[1])
    px.rect(4, 14, 8, 8, WOOD[2])
    px.hline(4, 14, 8, WOOD[3])
    px.vline(4, 14, 8, WOOD[3])
    for dx in range(8):
        px.dot(4 + dx, 14 + dx, WOOD[3])
        px.dot(11 - dx, 14 + dx, WOOD[0])
    return px


def well_prop() -> Px:
    """Village well — a plausible reason for the open square to exist."""
    px = Px(PROP_W, PROP_H)
    px.rect(3, 14, 10, 9, STONE[1])
    px.rect(4, 15, 8, 7, STONE[2])
    px.hline(4, 15, 8, STONE[3])
    for sx in range(4, 12, 3):
        px.vline(sx, 16, 6, STONE[1])
    px.rect(5, 12, 6, 3, c("07060d"))      # the shaft
    px.hline(5, 12, 6, STONE[3])
    px.rect(2, 4, 1, 9, WOOD[2])           # posts and roof
    px.rect(13, 4, 1, 9, WOOD[2])
    px.rect(1, 2, 14, 2, WOOD[1])
    px.hline(1, 2, 14, WOOD[3])
    px.dot(8, 5, WOOD[3])                  # bucket rope
    px.dot(8, 6, WOOD[3])
    return px


def fence_prop() -> Px:
    px = Px(PROP_W, PROP_H)
    px.rect(2, 14, 2, 9, WOOD[1])
    px.rect(11, 14, 2, 9, WOOD[1])
    px.vline(2, 14, 9, WOOD[2])
    px.vline(11, 14, 9, WOOD[2])
    for rail_y in (16, 20):
        px.rect(0, rail_y, TILE, 2, WOOD[1])
        px.hline(0, rail_y, TILE, WOOD[3])
    return px


# ── Screen-space helpers ─────────────────────────────────────────────

def vignette_image(width: int = 320, height: int = 180) -> Image.Image:
    """Soft darkening toward the screen edges — night, without fog."""
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    pixels = img.load()
    cx, cy = width / 2.0, height / 2.0
    max_distance = math.hypot(cx, cy)
    for y in range(height):
        for x in range(width):
            distance = math.hypot(x - cx, y - cy) / max_distance
            falloff = max(0.0, (distance - 0.62) / 0.38)
            alpha = int(min(1.0, falloff ** 1.7) * 78)
            if alpha:
                pixels[x, y] = (8, 8, 20, alpha)
    return img


def glow_image(size: int = 48) -> Image.Image:
    """Radial warm pool, drawn additively under lanterns and lit doors."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pixels = img.load()
    centre = (size - 1) / 2.0
    for y in range(size):
        for x in range(size):
            distance = math.hypot(x - centre, y - centre) / centre
            if distance >= 1.0:
                continue
            intensity = (1.0 - distance) ** 2.2
            pixels[x, y] = (
                int(GOLD[3][0] * intensity),
                int(GOLD[2][1] * intensity),
                int(GOLD[1][2] * intensity),
                int(190 * intensity),
            )
    return img


# ── Atlas assembly ───────────────────────────────────────────────────

def build_terrain() -> tuple[dict, list[Px]]:
    tiles: dict[str, Px] = {}
    for variant in range(6):
        tiles[f"grass_{variant}"] = grass_tile(variant)
    for mask in range(16):
        tiles[f"path_{mask}"] = path_tile(mask)
    for mask in range(16):
        tiles[f"water_{mask}"] = water_tile(mask)
    for variant in range(3):
        tiles[f"wall_{variant}"] = wall_tile(variant)
    for kind in ("left", "mid", "right"):
        tiles[f"roof_{kind}"] = roof_tile(kind)
    for kind in ("left", "mid", "right", "window", "shuttered"):
        tiles[f"house_{kind}"] = house_tile(kind)
    tiles["door"] = door_tile()
    tiles["court_arch"] = court_arch_tile()
    tiles["notice"] = notice_tile()
    for variant in range(2):
        tiles[f"dirt_{variant}"] = dirt_decal(variant)
    for side in ("west", "east"):
        tiles[f"gravel_{side}"] = gravel_decal(side)
    tiles["flowerbed"] = flowerbed_decal()
    tiles["tallgrass"] = tallgrass_decal()
    return tiles, list(tiles.values())


def build_props() -> dict[str, Px]:
    return {
        "tree_0": tree_prop(0),
        "tree_1": tree_prop(1),
        "lamp": lamp_prop(),
        "barrel": barrel_prop(),
        "crate": crate_prop(),
        "well": well_prop(),
        "fence": fence_prop(),
    }


def pack(tiles: dict[str, Px], cell_w: int, cell_h: int) -> tuple[Image.Image, dict]:
    columns = min(ATLAS_COLUMNS, max(1, len(tiles)))
    rows = math.ceil(len(tiles) / columns)
    atlas = Image.new("RGBA", (columns * cell_w, rows * cell_h), (0, 0, 0, 0))
    coordinates: dict[str, list[int]] = {}
    for index, (name, px) in enumerate(tiles.items()):
        col, row = index % columns, index // columns
        atlas.paste(px.img, (col * cell_w, row * cell_h))
        coordinates[name] = [col, row]
    return atlas, coordinates


def main() -> None:
    TILES_DIR.mkdir(parents=True, exist_ok=True)

    terrain, _ = build_terrain()
    terrain_atlas, terrain_coords = pack(terrain, TILE, TILE)
    terrain_atlas.save(TILES_DIR / "greymere_atlas.png")

    props = build_props()
    prop_atlas, prop_coords = pack(props, PROP_W, PROP_H)
    prop_atlas.save(TILES_DIR / "greymere_props.png")

    vignette_image().save(TILES_DIR / "vignette.png")
    glow_image().save(TILES_DIR / "glow.png")

    manifest = {
        "tile_size": TILE,
        "prop_size": [PROP_W, PROP_H],
        "atlas": "greymere_atlas.png",
        "props_atlas": "greymere_props.png",
        "terrain_columns": min(ATLAS_COLUMNS, len(terrain)),
        "prop_columns": min(ATLAS_COLUMNS, len(props)),
        "tiles": terrain_coords,
        "props": prop_coords,
        # Autotile bit order, so the renderer and generator cannot drift.
        "mask_bits": {"north": N, "east": E, "south": S, "west": W},
    }
    (TILES_DIR / "tiles_manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )

    print(f"Terrain atlas: {len(terrain)} tiles -> {terrain_atlas.size}")
    print(f"Prop atlas:    {len(props)} props -> {prop_atlas.size}")
    print(f"Manifest:      {TILES_DIR / 'tiles_manifest.json'}")


if __name__ == "__main__":
    main()
