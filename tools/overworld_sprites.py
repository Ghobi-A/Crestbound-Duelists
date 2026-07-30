"""
Crestbound Duelists — overworld character sprites
==================================================
Authors the 24x32 walking sprites for the named cast.

Each of Aren's six classes is a distinct build, not one body under a
different palette: shoulder width, hip treatment, headgear, mantle and
carried gear all change, so a class is recognisable from outline alone
before any colour is read. Elara and Mira are built the same way.

Sheets are one row of twelve frames — a four-step walk cycle for down,
up and side — with west drawn by mirroring the side frames at runtime.
Frames 0 and 2 are the neutral stance, so a standing character holds
frame 0.

Imported by generate_sprites.py; not run directly.
"""

from __future__ import annotations

from PIL import Image

from px_canvas import Px, c, shade

OW_W, OW_H = 24, 32
GROUND_Y = 28                      # the row boots rest on
OW_DIRECTIONS = ("down", "up", "side")
OW_WALK_FRAMES = 4
OW_ANCHOR = (OW_W // 2, GROUND_Y - 2)

SKIN = c("e8c8a0")
SKIN_SHADOW = c("c79c72")
BOOT = c("2e2620")
STEEL = c("8a94a6")
STEEL_DARK = c("5a6470")
GOLD = c("caa24a")
GOLD_LIGHT = c("f0d98a")

# ── Build definitions ────────────────────────────────────────────────
# shoulders : half-width of the torso in pixels (drives the silhouette)
# hip       : how the lower body reads — tassets, bell, tails, plain, skirt
# head      : headgear shape
# mantle    : shoulder treatment; "asym" breaks the outline deliberately
# gear      : carried item that extends past the body
# lean      : forward weight, in pixels

OW_BUILDS = {
    "aren/warrior": {
        "shoulders": 6, "hip": "tassets", "head": "hair_messy", "mantle": "pauldrons",
        "gear": "sword_hip", "lean": 1,
        "main": c("a8383c"), "trim": c("d8b45a"), "legs": c("4a3a30"), "hair": c("6a4a32"),
    },
    "aren/guardian": {
        "shoulders": 7, "hip": "skirt", "head": "helm", "mantle": "pauldrons_heavy",
        "gear": "kite_shield", "lean": 0,
        "main": c("2f5f9e"), "trim": c("d8b45a"), "legs": c("46506a"), "hair": c("6a4a32"),
    },
    "aren/mage": {
        "shoulders": 4, "hip": "bell", "head": "hood_soft", "mantle": "none",
        "gear": "tome", "lean": 0,
        "main": c("b0632c"), "trim": c("e8c88a"), "legs": c("6a4028"), "hair": c("6a4a32"),
    },
    "aren/sorcerer": {
        "shoulders": 5, "hip": "bell", "head": "hood_deep", "mantle": "asym",
        "gear": "orb_staff", "lean": 0,
        "main": c("3a2a56"), "trim": c("9a6ad8"), "legs": c("241a38"), "hair": c("6a4a32"),
    },
    "aren/assassin": {
        "shoulders": 4, "hip": "tails", "head": "hood_peak", "mantle": "scarf",
        "gear": "daggers", "lean": 1,
        "main": c("34383f"), "trim": c("8a94a6"), "legs": c("2a2e34"), "hair": c("6a4a32"),
    },
    "aren/neutral": {
        "shoulders": 5, "hip": "plain", "head": "hair_messy", "mantle": "half_cloak",
        "gear": "sword_hip", "lean": 0,
        "main": c("5f6a44"), "trim": c("b09a52"), "legs": c("4a4638"), "hair": c("6a4a32"),
    },
    "elara": {
        "shoulders": 6, "hip": "skirt", "head": "bun", "mantle": "cloak",
        "gear": "kite_shield", "lean": 0,
        "main": c("3f6fae"), "trim": c("d8d8e0"), "legs": c("46506a"), "hair": c("d8d8e0"),
    },
    "mira": {
        "shoulders": 4, "hip": "bell", "head": "ponytail", "mantle": "none",
        "gear": "satchel_tome", "lean": 0,
        "main": c("c06a3a"), "trim": c("e8d0a8"), "legs": c("7a4a30"), "hair": c("6a3a2a"),
    },
}


def draw_overworld(key: str, direction: str, frame: int) -> Image.Image:
    """One 24x32 frame for `key` facing `direction`."""
    build = OW_BUILDS[key]
    p = Px(OW_W, OW_H)

    stride = (0, 1, 0, -1)[frame % 4]
    bob = 1 if frame % 2 else 0
    lean = build["lean"] if direction == "side" else 0

    ground = GROUND_Y
    torso_top = ground - 17 + bob
    head_top = ground - 26 + bob

    # Anything that sits behind the body is drawn first.
    _behind(p, build, direction, torso_top, ground, stride, lean)
    _lower(p, build, direction, ground, stride, bob, lean)
    _torso(p, build, direction, torso_top, lean)
    _arms(p, build, direction, torso_top, stride, lean)
    _head(p, build, direction, head_top, lean)
    _front_gear(p, build, direction, torso_top, stride, lean)

    p.outline_solid()
    _shadow(p, ground)
    return p.img


# ── Body ─────────────────────────────────────────────────────────────

def _lower(p, build, direction, ground, stride, bob, lean):
    cx = OW_W // 2 + lean
    hip = build["hip"]
    main, trim, legs_c = build["main"], build["trim"], build["legs"]

    if hip in ("bell", "skirt"):
        # A hem: wide triangular base, the scholarly/knightly read.
        height = 12 if hip == "bell" else 9
        top = ground - height
        for i in range(height + 1):
            width = (5 if hip == "bell" else 6) + int(i * (0.75 if hip == "bell" else 0.45))
            x = cx - width // 2 + (stride if i > height - 4 else 0)
            tone = main if i % 3 else shade(main, 0.82)
            p.rect(x, top + i, width, 1, tone)
        # Hem trim catches the light.
        width = (5 if hip == "bell" else 6) + int(height * (0.75 if hip == "bell" else 0.45))
        p.rect(cx - width // 2 + stride, ground, width, 1, trim)
        if hip == "skirt":
            _legs(p, build, direction, ground, stride, cx, short=True)
        return

    _legs(p, build, direction, ground, stride, cx)

    if hip == "tassets":
        # Armoured skirt plates flaring past the hips.
        p.rect(cx - 7, ground - 12, 5, 5, main)
        p.rect(cx + 2, ground - 12, 5, 5, main)
        p.hline(cx - 7, ground - 12, 5, trim)
        p.hline(cx + 2, ground - 12, 5, trim)
    elif hip == "tails":
        # Split coat tails trailing behind the stride.
        back = cx - 6 if direction != "side" else cx - 7 - stride
        p.rect(back, ground - 13, 3, 11, shade(main, 0.85))
        p.rect(back + 1, ground - 3, 2, 3, shade(main, 0.7))
        if direction != "side":
            p.rect(cx + 4, ground - 13, 3, 11, shade(main, 0.85))
            p.rect(cx + 4, ground - 3, 2, 3, shade(main, 0.7))


def _legs(p, build, direction, ground, stride, cx, short=False):
    legs_c = build["legs"]
    top = ground - (6 if short else 10)
    if direction == "side":
        front, back = cx + 1 + stride, cx - 3 - stride
        p.rect(back, top, 3, ground - top - 1, shade(legs_c, 0.75))
        p.rect(front, top, 3, ground - top - 1, legs_c)
        p.rect(back - 1, ground - 1, 4, 2, shade(BOOT, 0.8))
        p.rect(front, ground - 1, 4, 2, BOOT)
    else:
        left, right = cx - 4, cx + 1
        p.rect(left, top, 3, ground - top - 1 + stride, legs_c)
        p.rect(right, top, 3, ground - top - 1 - stride, legs_c)
        p.rect(left, ground - 1 + stride, 3, 2, BOOT)
        p.rect(right, ground - 1 - stride, 3, 2, BOOT)


def _torso(p, build, direction, torso_top, lean):
    cx = OW_W // 2 + lean
    half = build["shoulders"]
    main, trim = build["main"], build["trim"]
    width = half * 2
    x = cx - half

    p.rect(x, torso_top, width, 10, main)
    p.vline(x, torso_top, 10, shade(main, 0.78))
    p.vline(x + width - 1, torso_top, 10, shade(main, 0.78))
    p.hline(x, torso_top, width, shade(main, 1.12))

    if direction == "down":
        p.rect(cx - 1, torso_top + 2, 2, 8, trim)
        p.dot(cx, torso_top + 3, GOLD_LIGHT)
    elif direction == "up":
        p.rect(x + 2, torso_top + 2, width - 4, 2, shade(main, 0.88))
    else:
        p.rect(x + 1, torso_top + 2, 2, 7, trim)

    mantle = build["mantle"]
    if mantle in ("pauldrons", "pauldrons_heavy"):
        size = 4 if mantle == "pauldrons_heavy" else 3
        p.rect(x - 2, torso_top - 1, size, size, STEEL)
        p.rect(x + width - 1, torso_top - 1, size, size, STEEL)
        p.hline(x - 2, torso_top - 1, size, shade(STEEL, 1.15))
        p.hline(x + width - 1, torso_top - 1, size, shade(STEEL, 1.15))
    elif mantle == "asym":
        # One high collar and a long sleeve: a deliberately lopsided
        # outline that reads as Eclipse before any colour registers.
        p.rect(x - 3, torso_top - 2, 4, 7, shade(main, 1.2))
        p.rect(x - 3, torso_top + 5, 3, 8, shade(main, 0.9))
        p.rect(x + width - 1, torso_top, 2, 3, shade(main, 1.05))
        p.dot(x - 3, torso_top - 2, build["trim"])
    elif mantle == "scarf":
        p.rect(x, torso_top - 1, width, 2, trim)
        tail = x - 4 if direction != "side" else x - 5
        p.rect(tail, torso_top, 4, 2, trim)
        p.rect(tail - 1, torso_top + 2, 3, 2, shade(trim, 0.85))
    elif mantle in ("cloak", "half_cloak"):
        span = width + 4 if mantle == "cloak" else half + 3
        cloak_x = x - 2 if mantle == "cloak" else x - 2
        p.rect(cloak_x, torso_top - 1, span, 13, shade(main, 0.7))
        p.hline(cloak_x, torso_top - 1, span, shade(main, 0.9))
        if mantle == "cloak":
            p.rect(cloak_x, torso_top + 12, span, 2, shade(main, 0.55))


def _arms(p, build, direction, torso_top, stride, lean):
    cx = OW_W // 2 + lean
    half = build["shoulders"]
    x, width = cx - half, half * 2
    sleeve = shade(build["main"], 0.92)
    if build["mantle"] == "asym":
        return  # the long sleeve already covers this side
    if direction == "side":
        p.rect(x + width - 3, torso_top + 3 - stride, 3, 6, sleeve)
        p.dot(x + width - 2, torso_top + 9 - stride, SKIN)
    else:
        p.rect(x - 1, torso_top + 3 + stride, 2, 6, sleeve)
        p.rect(x + width - 1, torso_top + 3 - stride, 2, 6, sleeve)
        p.dot(x - 1, torso_top + 9 + stride, SKIN)
        p.dot(x + width, torso_top + 9 - stride, SKIN)


def _head(p, build, direction, head_top, lean):
    cx = OW_W // 2 + lean
    hair = build["hair"]
    style = build["head"]

    if direction == "side":
        p.rect(cx - 3, head_top, 8, 9, SKIN)
        p.vline(cx - 3, head_top, 9, SKIN_SHADOW)
        p.rect(cx - 3, head_top + 1, 4, 7, hair)
        p.dot(cx + 2, head_top + 5, c("30281f"))
        p.dot(cx + 5, head_top + 5, SKIN)          # nose
        p.dot(cx + 5, head_top + 6, SKIN_SHADOW)
        p.dot(cx + 4, head_top + 8, SKIN_SHADOW)   # chin
    else:
        p.rect(cx - 4, head_top, 9, 8, SKIN)
        p.vline(cx - 4, head_top, 8, SKIN_SHADOW)
        p.hline(cx - 3, head_top + 7, 7, SKIN_SHADOW)   # jaw
        if direction == "up":
            p.rect(cx - 4, head_top, 9, 8, hair)
        else:
            p.dot(cx - 2, head_top + 4, c("30281f"))
            p.dot(cx + 2, head_top + 4, c("30281f"))

    _headgear(p, build, style, direction, head_top, cx, hair)


def _headgear(p, build, style, direction, head_top, cx, hair):
    trim = build["trim"]
    if style == "helm":
        # Full helm: the head becomes a hard steel mass with a visor slot.
        p.rect(cx - 5, head_top - 2, 11, 8, STEEL)
        p.hline(cx - 5, head_top - 2, 11, shade(STEEL, 1.2))
        p.rect(cx - 5, head_top + 6, 11, 2, STEEL_DARK)
        if direction == "down":
            p.rect(cx - 3, head_top + 3, 7, 2, c("1a1c24"))
        elif direction == "side":
            p.rect(cx, head_top + 3, 6, 2, c("1a1c24"))
        p.rect(cx - 1, head_top - 4, 2, 3, trim)   # crest fin
        return
    if style in ("hood_soft", "hood_deep", "hood_peak"):
        depth = {"hood_soft": 0, "hood_deep": 1, "hood_peak": 2}[style]
        main = build["main"]
        cloth = shade(main, 1.05)

        if direction == "up":
            # From behind a hood is a solid shell.
            p.rect(cx - 6, head_top - 3, 13, 12 + depth, cloth)
            p.hline(cx - 6, head_top - 3, 13, shade(main, 1.2))
            if style == "hood_peak":
                p.rect(cx - 2, head_top - 6, 4, 3, cloth)
            return

        # A hood frames the face rather than hiding it: crown above,
        # cheek panels either side, brow shadow across the top of the
        # face. The opening is what makes a hood read as a hood.
        p.rect(cx - 6, head_top - 3, 13, 4, cloth)
        p.hline(cx - 6, head_top - 3, 13, shade(main, 1.2))
        left, right = (cx - 6, cx + 5) if direction != "side" else (cx - 5, cx + 5)
        p.rect(left, head_top + 1, 2, 8 + depth, cloth)
        p.rect(right, head_top + 1, 2, 8 + depth, shade(main, 0.85))
        # Brow shadow just inside the opening.
        brow_x = cx - 4 if direction != "side" else cx - 1
        p.rect(brow_x, head_top + 1, 8, 1, c("2a2028"))
        if style == "hood_peak":
            p.rect(cx - 2, head_top - 6, 4, 3, cloth)
            p.dot(cx - 1, head_top - 7, shade(main, 0.9))
        if depth:
            # Deeper hoods drop cloth further down the jaw.
            p.rect(left, head_top + 8, 2, 3, shade(main, 0.8))
            p.rect(right, head_top + 8, 2, 3, shade(main, 0.7))
        return

    # The cap overlaps the top of the face so there is a fringe rather
    # than a bare forehead filling half the head.
    p.rect(cx - 4, head_top - 2, 9, 4, hair)
    if direction == "down":
        p.rect(cx - 4, head_top + 2, 2, 2, hair)
        p.rect(cx + 3, head_top + 2, 2, 2, hair)
    if style == "bun":
        p.rect(cx - 2, head_top - 5, 5, 3, hair)
        p.dot(cx - 3, head_top - 4, shade(hair, 1.15))
        if direction == "up":
            p.rect(cx - 2, head_top + 2, 5, 4, shade(hair, 0.85))
    elif style == "ponytail":
        if direction == "up":
            p.rect(cx - 1, head_top + 3, 3, 9, hair)
        else:
            tail = cx + 5
            p.rect(tail, head_top + 1, 2, 9, hair)
            p.dot(tail + 1, head_top + 10, shade(hair, 0.85))
    else:  # messy
        p.dot(cx - 5, head_top - 2, hair)
        p.dot(cx + 5, head_top - 1, hair)
        p.dot(cx + 2, head_top - 3, hair)
        p.dot(cx - 2, head_top - 3, hair)


# ── Carried gear ─────────────────────────────────────────────────────

def _behind(p, build, direction, torso_top, ground, stride, lean):
    """Gear that sits behind the body — drawn before it."""
    cx = OW_W // 2 + lean
    gear = build["gear"]
    if gear == "kite_shield" and direction == "up":
        _kite_shield(p, cx - 5, torso_top - 1, build)
    elif gear == "orb_staff" and direction == "up":
        p.vline(cx + 6, torso_top - 8, 24, c("4a3a52"))


def _front_gear(p, build, direction, torso_top, stride, lean):
    cx = OW_W // 2 + lean
    gear = build["gear"]
    trim = build["trim"]

    if gear == "kite_shield" and direction != "up":
        # Carried on the off arm, past the body's edge — it has to widen
        # the silhouette, not replace the torso.
        x = cx - 12 if direction != "side" else cx - 11
        _kite_shield(p, x, torso_top - 1, build)
    elif gear == "sword_hip":
        hip_x = cx + 5 if direction != "side" else cx - 6
        p.vline(hip_x, torso_top + 7, 11, STEEL_DARK)
        p.vline(hip_x + 1, torso_top + 8, 9, STEEL)
        p.rect(hip_x - 1, torso_top + 5, 3, 2, GOLD)
    elif gear == "daggers":
        for side in (-1, 1) if direction != "side" else (-1,):
            hip_x = cx + side * 6
            p.vline(hip_x, torso_top + 8, 6, STEEL)
            p.dot(hip_x, torso_top + 7, GOLD)
    elif gear == "orb_staff" and direction != "up":
        rod = cx - 8 if direction != "side" else cx + 6
        p.vline(rod, torso_top - 7, 24, c("4a3a52"))
        p.vline(rod + 1, torso_top - 7, 24, c("2e2438"))
        # Orb: the one bright spectral note on the sprite.
        p.rect(rod - 1, torso_top - 10, 4, 4, c("9b74d6"))
        p.rect(rod, torso_top - 9, 2, 2, c("d9c4ff"))
        p.dot(rod - 1, torso_top - 10, c("6b47a0"))
    elif gear == "tome" and direction != "up":
        book_x = cx + 4 if direction != "side" else cx + 3
        p.rect(book_x, torso_top + 6, 5, 6, c("8a4a2a"))
        p.rect(book_x + 1, torso_top + 7, 3, 4, c("e8d0a8"))
        p.dot(book_x + 2, torso_top + 6, GOLD)
    elif gear == "satchel_tome":
        bag_x = cx + 5 if direction != "side" else cx + 4
        p.rect(bag_x, torso_top + 7, 4, 5, c("6a4a30"))
        p.hline(bag_x, torso_top + 7, 4, c("8a6a48"))
        p.dot(bag_x + 1, torso_top + 9, GOLD)


def _kite_shield(p, x, y, build):
    """A kite shield tall enough to dominate the outline."""
    trim = build["trim"]
    # Darker than the tabard and rimmed in steel, or the shield and the
    # surcoat merge into one flat blue mass at this size.
    face = shade(build["main"], 0.78)
    for i in range(15):
        if i < 9:
            width, offset = 8, 0
        else:
            width, offset = 8 - (i - 8), (i - 8) // 2
        p.rect(x + offset, y + i, max(1, width), 1, face)
    p.vline(x, y, 9, STEEL)
    p.vline(x + 7, y, 9, STEEL_DARK)
    p.hline(x, y, 8, STEEL)
    for i in range(9, 15):
        offset = (i - 8) // 2
        p.dot(x + offset, y + i, STEEL_DARK)
        p.dot(x + max(0, 7 - (i - 8)), y + i, STEEL_DARK)
    # Charge: a simple cross-and-boss, original to Avelaine's wardens.
    p.vline(x + 3, y + 2, 9, trim)
    p.hline(x + 1, y + 5, 6, trim)
    p.dot(x + 3, y + 5, GOLD_LIGHT)


def _shadow(p, ground):
    """Contact shadow at a fixed height, so it does not bob with the walk."""
    for y, inset, alpha in ((ground + 1, 7, 65), (ground + 2, 5, 45)):
        for x in range(inset, OW_W - inset):
            if 0 <= y < OW_H and p.img.getpixel((x, y))[3] == 0:
                p.dot(x, y, (10, 10, 20, alpha))


def save_sheet(key: str, out_path) -> None:
    columns = len(OW_DIRECTIONS) * OW_WALK_FRAMES
    sheet = Image.new("RGBA", (OW_W * columns, OW_H), (0, 0, 0, 0))
    for d, direction in enumerate(OW_DIRECTIONS):
        for frame in range(OW_WALK_FRAMES):
            index = d * OW_WALK_FRAMES + frame
            sheet.paste(draw_overworld(key, direction, frame), (index * OW_W, 0))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_path)


def manifest_section() -> dict:
    return {
        "frame_width": OW_W,
        "frame_height": OW_H,
        "walk_frames": OW_WALK_FRAMES,
        "directions": {
            name: index * OW_WALK_FRAMES for index, name in enumerate(OW_DIRECTIONS)
        },
        "mirror_side_for_west": True,
        "anchor": list(OW_ANCHOR),
        "frames": len(OW_DIRECTIONS) * OW_WALK_FRAMES,
    }
