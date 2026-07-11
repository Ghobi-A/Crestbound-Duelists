"""
Crestbound Duelists — Original Pixel Art Generator
====================================================
Authors every prototype sprite as hand-placed pixel clusters via a
small parametric chibi framework: compact late-16-bit-style Duelists
(24x32 battle frames, 16x24 overworld frames), spectral Bonded Entity
manifestations, and the Hollow Court battle background.

All designs are original to Crestbound Duelists. Run:

    python tools/generate_sprites.py

Outputs (committed as build artifacts, regenerable):
    game/assets/characters/<who>[/<class>]/battle.png   11-frame strip
    game/assets/characters/<who>[/<class>]/overworld.png 2-frame strip
    game/assets/enemies/<id>/battle.png
    game/assets/entities/<id>/idle.png                   2-frame strip
    game/assets/battle/backgrounds/hollow_court.png
    game/assets/battle/sheet_manifest.json               frame layout
"""

from __future__ import annotations

import json
import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "game" / "assets"

FRAME_W, FRAME_H = 24, 32
OW_W, OW_H = 16, 24

# Frame strip layout shared by every battle sheet.
BATTLE_STATES = {
    "idle":   {"start": 0, "count": 2, "fps": 3, "loop": True},
    "attack": {"start": 2, "count": 3, "fps": 10, "loop": False},
    "hit":    {"start": 5, "count": 1, "fps": 8, "loop": False},
    "defeat": {"start": 6, "count": 2, "fps": 4, "loop": False},
    "brace":  {"start": 8, "count": 1, "fps": 4, "loop": False},
    "awaken": {"start": 9, "count": 2, "fps": 5, "loop": True},
}
FRAME_COUNT = 11

OUTLINE = (20, 20, 31, 255)
SKIN = (232, 200, 160, 255)
SKIN_SHADOW = (199, 156, 114, 255)


def c(hexcode: str, alpha: int = 255) -> tuple:
    hexcode = hexcode.lstrip("#")
    return (int(hexcode[0:2], 16), int(hexcode[2:4], 16), int(hexcode[4:6], 16), alpha)


class Px:
    """Tiny pixel canvas helper around a PIL RGBA image."""

    def __init__(self, width: int, height: int):
        self.img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        self.w, self.h = width, height

    def dot(self, x: int, y: int, color: tuple):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.img.putpixel((int(x), int(y)), color)

    def rect(self, x: int, y: int, w: int, h: int, color: tuple):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.dot(xx, yy, color)

    def hline(self, x: int, y: int, w: int, color: tuple):
        self.rect(x, y, w, 1, color)

    def vline(self, x: int, y: int, h: int, color: tuple):
        self.rect(x, y, 1, h, color)

    def outline_solid(self):
        """Draw a 1px dark outline around every opaque cluster."""
        src = self.img.load()
        edges = []
        for y in range(self.h):
            for x in range(self.w):
                if src[x, y][3] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < self.w and 0 <= ny < self.h and src[nx, ny][3] > 200:
                            edges.append((x, y))
                            break
        for x, y in edges:
            src[x, y] = OUTLINE


# ── Character specs ──────────────────────────────────────────────────
# Every entry is an original Crestbound design. `build` controls
# silhouette; gear controls weapon/props; palette is per character.

def aren_base(hair: str = "4a3a30") -> dict:
    return {"skin": SKIN, "hair_color": c(hair), "hair": "messy", "eyes": c("30281f")}

CHARACTERS = {
    # Aren Vale — same person, class-specific gear (silhouette shifts).
    "aren/warrior": {**aren_base(), "build": "std", "top": c("8d93a5"), "top2": c("b04848"),
                     "legs": c("5a4a3a"), "weapon": "sword", "pauldrons": True},
    "aren/guardian": {**aren_base(), "build": "std", "top": c("9aa5b5"), "top2": c("4a9eff"),
                      "legs": c("4a4a5a"), "weapon": "mace", "shield": True, "pauldrons": True},
    "aren/mage": {**aren_base(), "build": "robe", "top": c("b86438"), "top2": c("e8d8b8"),
                  "legs": c("6a4a30"), "weapon": "staff"},
    "aren/sorcerer": {**aren_base(), "build": "robe", "top": c("5a4a7a"), "top2": c("9a7ad8"),
                      "legs": c("3a3448"), "weapon": "orb"},
    "aren/assassin": {**aren_base(), "build": "slim", "top": c("5a6470"), "top2": c("8a94a6"),
                      "legs": c("3a4048"), "weapon": "dagger", "scarf": c("8a94a6")},
    "aren/neutral": {**aren_base(), "build": "std", "top": c("7a8a6a"), "top2": c("a89858"),
                     "legs": c("5a5a4a"), "weapon": "sword"},

    # Warden Elara Thorne — disciplined Guardian, azure tabard, kite shield.
    "elara": {"skin": SKIN, "hair_color": c("d8d8e0"), "hair": "bun", "eyes": c("2a3a5a"),
              "build": "std", "top": c("a8b4c8"), "top2": c("3a7ad8"), "legs": c("4a4a5a"),
              "weapon": "sword", "shield": True, "pauldrons": True},

    # Mira Solen — archive assistant Mage, ember robe, ponytail, satchel.
    "mira": {"skin": SKIN, "hair_color": c("6a3a2a"), "hair": "ponytail", "eyes": c("3a2a20"),
             "build": "robe", "top": c("c06a3a"), "top2": c("e8d0a8"), "legs": c("7a4a30"),
             "weapon": "tome", "satchel": True},
}

ENEMIES = {
    # Riven-touched Raider — hulking Warrior, rusted iron, ragged red.
    "riven_raider": {"skin": c("caa27e"), "hair_color": c("2a2a30"), "hair": "horns",
                     "eyes": c("c04040"), "build": "bulky", "top": c("6a5548"),
                     "top2": c("8a3030"), "legs": c("4a3a30"), "weapon": "axe", "pauldrons": True},
    # Hexbound Adept — hooded Sorcerer, near-black robe, sigil staff.
    "hexbound_adept": {"skin": c("221e33"), "hair_color": c("3a3448"), "hair": "hood",
                       "eyes": c("c9a3ff"), "build": "robe", "top": c("3a3448"),
                       "top2": c("8a5ad8"), "legs": c("2a2438"), "weapon": "staff"},
    # Unbound Mercenary — drifting Neutral blade-for-hire, olive cloak.
    "unbound_mercenary": {"skin": c("d0a880"), "hair_color": c("504438"), "hair": "bandana",
                          "eyes": c("30281f"), "build": "std", "top": c("6a6a58"),
                          "top2": c("a05840"), "legs": c("4a4438"), "weapon": "sword",
                          "scarf": c("a05840")},
}

POSES = [
    {"name": "idle0", "bob": 0, "arm": "rest"},
    {"name": "idle1", "bob": 1, "arm": "rest"},
    {"name": "atk0", "bob": 0, "lean": -1, "arm": "raised"},
    {"name": "atk1", "bob": 1, "lean": 2, "arm": "thrust"},
    {"name": "atk2", "bob": 0, "lean": 1, "arm": "rest"},
    {"name": "hit0", "bob": 1, "lean": -2, "arm": "rest", "wince": True},
    {"name": "def0", "bob": 3, "lean": -1, "arm": "rest", "kneel": True},
    {"name": "def1", "collapsed": True},
    {"name": "brace0", "bob": 2, "arm": "guard"},
    {"name": "awk0", "bob": 0, "arm": "wide", "aura": 0},
    {"name": "awk1", "bob": 1, "arm": "wide", "aura": 1},
]


def shade(color: tuple, factor: float) -> tuple:
    return (max(0, min(255, int(color[0] * factor))),
            max(0, min(255, int(color[1] * factor))),
            max(0, min(255, int(color[2] * factor))), color[3])


def draw_duelist(spec: dict, pose: dict) -> Image.Image:
    """One 24x32 battle frame. Front-facing chibi, ~2.5 heads tall."""
    p = Px(FRAME_W, FRAME_H)
    if pose.get("collapsed"):
        return _draw_collapsed(p, spec)

    bob = pose.get("bob", 0)
    lean = pose.get("lean", 0)
    kneel = pose.get("kneel", False)
    top, top2 = spec["top"], spec["top2"]
    legs_c = spec["legs"]
    skin = spec["skin"]
    bulky = spec["build"] == "bulky"
    robe = spec["build"] == "robe"
    slim = spec["build"] == "slim"

    ground = 30
    # Legs / lower body.
    leg_h = 3 if kneel else 6
    hip_y = ground - leg_h - 2
    if robe:
        # Skirted robe instead of separate legs.
        for i, yy in enumerate(range(hip_y, ground)):
            wdt = 8 + (2 if i >= leg_h - 1 else i // 2)
            p.rect(12 - wdt // 2, yy, wdt, 1, shade(top, 0.8) if i % 2 else top)
        p.hline(8, ground - 1, 3, spec.get("boots", c("3a3028")))
        p.hline(13, ground - 1, 3, spec.get("boots", c("3a3028")))
    else:
        lw = 3 if not bulky else 4
        p.rect(12 - lw - 1, hip_y, lw, leg_h, legs_c)
        p.rect(13, hip_y, lw, leg_h, legs_c)
        p.rect(12 - lw - 1, ground - 2, lw, 2, c("3a3028"))
        p.rect(13, ground - 2, lw, 2, c("3a3028"))

    # Torso.
    tw = 12 if bulky else (8 if slim else 10)
    torso_h = 7
    ty = hip_y - torso_h + 1
    tx = 12 - tw // 2 + lean
    p.rect(tx, ty + bob, tw, torso_h, top)
    p.rect(tx, ty + bob + torso_h - 2, tw, 1, shade(top, 0.72))
    # Chest accent (tabard / trim / rags).
    p.rect(12 - 2 + lean, ty + bob + 1, 4, torso_h - 2, top2)
    if spec.get("pauldrons"):
        p.rect(tx - 1, ty + bob, 3, 2, shade(top, 1.15))
        p.rect(tx + tw - 2, ty + bob, 3, 2, shade(top, 1.15))
    if spec.get("satchel"):
        p.rect(tx + tw - 2, ty + bob + 3, 3, 3, c("6a5030"))
    if spec.get("scarf"):
        p.hline(12 - 3 + lean, ty + bob, 6, spec["scarf"])

    # Arms.
    arm = pose.get("arm", "rest")
    arm_y = ty + bob + 1
    if arm == "guard":
        p.rect(tx - 1, arm_y + 1, 2, 3, skin)
        p.rect(tx + tw - 1, arm_y + 1, 2, 3, skin)
    elif arm == "wide":
        p.rect(tx - 2, arm_y, 2, 2, skin)
        p.rect(tx + tw, arm_y, 2, 2, skin)
    else:
        p.rect(tx - 1, arm_y, 2, 5, shade(top, 0.85))
        p.rect(tx + tw - 1, arm_y, 2, 5, shade(top, 0.85))
        p.dot(tx, arm_y + 5, skin)
        p.dot(tx + tw, arm_y + 5, skin)

    # Head (big chibi skull).
    head_w = 10
    hx = 12 - head_w // 2 + lean
    hy = ty + bob - 9
    p.rect(hx, hy, head_w, 9, skin)
    p.rect(hx, hy + 7, head_w, 2, SKIN_SHADOW if spec["skin"] == SKIN else shade(skin, 0.82))
    # Eyes.
    if not pose.get("wince"):
        p.dot(hx + 2, hy + 5, spec["eyes"])
        p.dot(hx + 7, hy + 5, spec["eyes"])
    else:
        p.hline(hx + 2, hy + 5, 2, spec["eyes"])
        p.hline(hx + 6, hy + 5, 2, spec["eyes"])
    _draw_hair(p, spec, hx, hy, head_w)

    # Weapon (right side of the sprite).
    _draw_weapon(p, spec, pose, tx, tw, arm_y)
    if spec.get("shield"):
        sy = arm_y + (0 if arm != "guard" else -1)
        p.rect(tx - 6, sy, 4, 6, c("c8ccd8"))           # steel kite shield
        p.rect(tx - 5, sy + 1, 2, 4, top2)              # painted crest
        p.dot(tx - 5, sy + 6, c("c8ccd8"))              # tapered point
        p.dot(tx - 4, sy + 6, c("c8ccd8"))

    p.outline_solid()

    # Awakening aura (drawn after outline so it stays unoutlined).
    if pose.get("aura") is not None:
        accent = spec["top2"]
        phase = pose["aura"]
        points = [(3, 8), (20, 6), (2, 18), (21, 17), (5, 3), (18, 2), (11, 1)]
        for i, (ax, ay) in enumerate(points):
            if (i + phase) % 2 == 0:
                p.dot(ax, ay + bob, (accent[0], accent[1], accent[2], 220))
    return p.img


def _draw_hair(p: Px, spec: dict, hx: int, hy: int, head_w: int):
    hair = spec["hair"]
    color = spec["hair_color"]
    if hair == "hood":
        p.rect(hx - 1, hy - 2, head_w + 2, 4, color)
        p.rect(hx - 1, hy - 2, 2, 9, color)
        p.rect(hx + head_w - 1, hy - 2, 2, 9, color)
        p.rect(hx + 1, hy + 1, head_w - 2, 2, shade(color, 0.6))
        return
    if hair == "horns":
        p.rect(hx, hy - 1, head_w, 3, color)
        p.rect(hx - 2, hy - 3, 2, 4, c("d8d0c0"))
        p.rect(hx + head_w, hy - 3, 2, 4, c("d8d0c0"))
        return
    if hair == "bandana":
        p.rect(hx, hy - 1, head_w, 3, spec.get("scarf", color))
        p.rect(hx + head_w - 1, hy + 1, 2, 3, spec.get("scarf", color))
        return
    if hair == "bun":
        p.rect(hx, hy - 2, head_w, 4, color)
        p.rect(hx + head_w - 2, hy - 4, 3, 3, color)
        p.hline(hx, hy + 2, 2, color)
        p.hline(hx + head_w - 2, hy + 2, 2, color)
        return
    if hair == "ponytail":
        p.rect(hx, hy - 2, head_w, 4, color)
        p.rect(hx + head_w - 1, hy - 1, 2, 8, color)
        p.hline(hx, hy + 2, 2, color)
        return
    # messy (default)
    p.rect(hx, hy - 2, head_w, 4, color)
    p.dot(hx - 1, hy, color)
    p.dot(hx + head_w, hy - 1, color)
    p.hline(hx, hy + 2, 2, color)
    p.hline(hx + head_w - 2, hy + 2, 2, color)


def _draw_weapon(p: Px, spec: dict, pose: dict, tx: int, tw: int, arm_y: int):
    weapon = spec.get("weapon", "")
    arm = pose.get("arm", "rest")
    wx = tx + tw + 1
    steel = c("c8ccd8")
    wood = c("7a5a3a")
    if weapon == "sword":
        if arm == "thrust":
            p.hline(wx - 1, arm_y + 3, 7, steel)
            p.dot(wx + 6, arm_y + 3, c("ffffff"))
            p.dot(wx - 2, arm_y + 3, wood)
        elif arm == "raised":
            for i in range(6):
                p.dot(wx + i - 1, arm_y + 1 - i, steel)
            p.dot(wx + 5, arm_y - 5, c("ffffff"))
        else:
            p.vline(wx, arm_y, 8, steel)
            p.dot(wx, arm_y, c("ffffff"))
            p.hline(wx - 1, arm_y + 6, 3, wood)
    elif weapon == "axe":
        p.vline(wx, arm_y - 2 if arm == "raised" else arm_y, 9, wood)
        head_y = (arm_y - 4 if arm == "raised" else arm_y - 2)
        p.rect(wx + 1, head_y, 3, 5, steel)
        p.dot(wx + 3, head_y + 1, shade(steel, 0.8))
        p.dot(wx + 3, head_y + 3, shade(steel, 0.8))
        p.dot(wx + 1, head_y, c("ffffff"))
    elif weapon == "mace":
        p.vline(wx, arm_y + 1, 6, wood)
        p.rect(wx - 1, arm_y + (0 if arm != "raised" else -2), 3, 3, steel)
    elif weapon == "staff":
        top_y = arm_y - 4
        p.vline(wx, top_y, 12, wood)
        p.rect(wx - 1, top_y - 2, 3, 3, spec["top2"])
        if arm == "thrust":
            p.dot(wx + 2, top_y - 1, spec["top2"])
            p.dot(wx + 3, top_y - 2, spec["top2"])
    elif weapon == "orb":
        oy = arm_y + (0 if arm != "thrust" else -2)
        p.rect(wx, oy, 3, 3, spec["top2"])
        p.dot(wx + 1, oy + 1, c("ffffff"))
    elif weapon == "dagger":
        if arm == "thrust":
            p.hline(wx - 1, arm_y + 2, 4, steel)
            p.hline(tx - 4, arm_y + 4, 4, steel)
        else:
            p.vline(wx, arm_y + 2, 4, steel)
            p.vline(tx - 2, arm_y + 3, 4, steel)
    elif weapon == "tome":
        p.rect(wx - 1, arm_y + 2, 4, 5, c("8a4a34"))
        p.rect(wx, arm_y + 3, 2, 3, c("f0e8d0"))


def _draw_collapsed(p: Px, spec: dict) -> Image.Image:
    """Defeated: a low heap near the ground line."""
    top = spec["top"]
    ground = 30
    p.rect(5, ground - 4, 14, 4, top)
    p.rect(6, ground - 5, 8, 2, shade(top, 0.8))
    p.rect(16, ground - 6, 6, 5, spec["skin"])  # head resting sideways
    p.rect(16, ground - 7, 6, 2, spec["hair_color"])
    p.outline_solid()
    return p.img


# ── Overworld sprites (16x24, 2-frame bob) ───────────────────────────

def draw_overworld(spec: dict, bob: int) -> Image.Image:
    p = Px(OW_W, OW_H)
    top, skin = spec["top"], spec["skin"]
    ground = 22
    robe = spec["build"] == "robe"
    if robe:
        for i, yy in enumerate(range(ground - 6, ground)):
            wdt = 6 + i // 2
            p.rect(8 - wdt // 2, yy, wdt, 1, top if i % 2 == 0 else shade(top, 0.8))
    else:
        p.rect(5, ground - 5, 2, 4, spec["legs"])
        p.rect(9, ground - 5, 2, 4, spec["legs"])
        p.hline(5, ground - 1, 2, c("3a3028"))
        p.hline(9, ground - 1, 2, c("3a3028"))
    p.rect(4, ground - 11 + bob, 8, 6, top)
    p.rect(7, ground - 10 + bob, 2, 4, spec["top2"])
    p.rect(4, ground - 18 + bob, 8, 7, skin)
    p.dot(6, ground - 14 + bob, spec["eyes"])
    p.dot(9, ground - 14 + bob, spec["eyes"])
    _draw_hair(p, spec, 4, ground - 18 + bob, 8)
    p.outline_solid()
    return p.img


# ── Bonded Entity manifestations (32x32, 2 frames, translucent) ──────

def draw_entity(entity_id: str, frame: int) -> Image.Image:
    p = Px(32, 32)
    a = 175  # spectral translucency
    pulse = frame % 2

    if entity_id == "storm_lion":
        body = c("4a7ab8", a)
        mane = c("7ec8ff", a)
        p.rect(8, 16, 16, 8, body)          # body
        p.rect(6, 22, 3, 5, body)           # legs
        p.rect(20, 22, 3, 5, body)
        p.rect(20, 10, 9, 9, body)          # head
        for dx, dy in ((18, 8), (26, 7), (17, 14), (29, 12), (21, 6), (28, 17)):
            p.dot(dx + pulse, dy, mane)
        p.rect(19, 9, 2, 10, mane)          # mane edge
        p.dot(24, 13, c("ffffff", 230))     # eye
        p.rect(5, 14, 4, 2, c("7ec8ff", 120))  # tail spark
    elif entity_id == "ash_seraph":
        robe = c("8a8a92", a)
        ember = c("d3743f", a)
        p.rect(13, 8, 6, 14, robe)          # figure
        p.rect(12, 22, 8, 3, shade(robe, 0.7))
        p.rect(14, 4, 4, 4, c("b8b8c0", a))  # featureless head
        for i in range(6):                   # wings
            p.hline(6 + i, 10 + i + pulse, 6 - i, robe)

        for i in range(6):
            p.hline(20 + i, 10 + (5 - i) + pulse, 6 - (5 - i), robe)
        for dx, dy in ((10, 24), (22, 25), (15, 27), (18, 23)):
            p.dot(dx, dy + pulse, ember)     # drifting embers
        p.dot(15, 6, ember)                  # eye glow
        p.dot(17, 6, ember)
    elif entity_id == "iron_tortoise":
        shell = c("5a7a5a", a)
        plate = c("8a9a8a", a)
        p.rect(6, 14, 20, 8, shell)          # dome
        p.rect(8, 11, 16, 4, shell)
        p.rect(10, 12, 4, 3, plate)          # plating
        p.rect(17, 12, 4, 3, plate)
        p.rect(12, 17, 8, 3, plate)
        p.rect(4, 20, 4, 4, plate)           # head/feet
        p.rect(8, 22, 4, 3, shade(shell, 0.7))
        p.rect(20, 22, 4, 3, shade(shell, 0.7))
        p.dot(5, 21, c("ffd870", 220))       # relic light
        if pulse:
            p.hline(12, 9, 8, c("ffd870", 100))
    elif entity_id == "mirror_fox":
        coat = c("c0c8d8", a)
        p.rect(10, 18, 12, 5, coat)          # body
        p.rect(20, 12, 6, 7, coat)           # head
        p.rect(20, 9, 2, 4, coat)            # ears
        p.rect(24, 9, 2, 4, coat)
        for i in range(6):                   # long tail
            p.dot(9 - i, 17 - i + pulse, coat)
        p.dot(23, 14, c("7ec8ff", 230))      # eye
        p.dot(12 + pulse * 2, 15, c("ffffff", 140))
    else:  # grave_stag and any future entity: antlered shade
        shade_c = c("6a5a8a", a)
        p.rect(10, 14, 14, 8, shade_c)
        p.rect(20, 8, 6, 8, shade_c)
        p.vline(21, 3, 5, shade_c)           # antlers
        p.vline(25, 3, 5, shade_c)
        p.dot(20, 4, shade_c)
        p.dot(26, 4, shade_c)
        p.rect(11, 22, 2, 5, shade_c)
        p.rect(21, 22, 2, 5, shade_c)
        p.dot(23, 11, c("d8b46a", 220))
    return p.img


# ── Hollow Court battle background (320x112) ─────────────────────────

def draw_background() -> Image.Image:
    rng = random.Random(41)
    W, H = 320, 112
    p = Px(W, H)
    sky = c("14121e")
    wall = c("2a2836")
    wall_dark = c("221f2c")
    floor = c("3a3644")
    floor_dark = c("322e3c")
    accent = c("6a4a9a")

    p.rect(0, 0, W, 30, sky)                       # upper dark
    for i in range(50):                            # dust motes
        p.dot(rng.randrange(W), rng.randrange(28), c("3a3450"))

    p.rect(0, 30, W, 22, wall)                     # far wall
    for arch_x in range(20, W, 60):                # broken arches
        p.rect(arch_x, 33, 18, 19, wall_dark)
        p.rect(arch_x + 2, 36, 14, 16, sky)
        if rng.random() < 0.5:
            p.rect(arch_x + 2, 33, 14, rng.randrange(2, 7), wall_dark)
    p.hline(0, 30, W, shade(wall, 1.2))

    # Broken pillars standing at the floor line.
    for px_x, ph in ((36, 16), (120, 11), (204, 17), (282, 13)):
        p.rect(px_x, 52 - ph, 10, ph, wall_dark)
        p.rect(px_x + 1, 52 - ph, 3, ph, shade(wall_dark, 1.25))
        p.hline(px_x - 1, 52 - ph, 12, shade(wall_dark, 1.35))

    # Floor (large — both parties stand here).
    p.rect(0, 52, W, H - 52, floor)
    for yy in range(52, H, 4):                     # stone courses
        for xx in range((yy // 4) % 2 * 8, W, 16):
            p.dot(xx, yy, floor_dark)
    for i in range(46):                            # rubble
        x, y = rng.randrange(W), rng.randrange(54, H)
        p.rect(x, y, rng.randrange(1, 3), 1, floor_dark)

    # Central dueling ring + dormant crest node.
    cx, cy = 160, 78
    for t in range(360):
        import math
        x = int(cx + 52 * math.cos(math.radians(t)))
        y = int(cy + 16 * math.sin(math.radians(t)))
        if t % 3 == 0:
            p.dot(x, y, c("4a4458"))
    p.rect(cx - 4, cy - 3, 8, 5, wall_dark)        # node base
    p.rect(cx - 2, cy - 6, 4, 4, accent)           # dormant crest node
    p.dot(cx - 1, cy - 5, c("9a7ad8"))
    for dx, dy in ((-8, -2), (7, -4), (-3, 4), (9, 2)):
        p.dot(cx + dx, cy + dy, c("5a4a7a"))

    return p.img


# ── Sheet assembly / output ──────────────────────────────────────────

def save_battle_sheet(spec: dict, out_path: Path):
    sheet = Image.new("RGBA", (FRAME_W * FRAME_COUNT, FRAME_H), (0, 0, 0, 0))
    for i, pose in enumerate(POSES):
        sheet.paste(draw_duelist(spec, pose), (i * FRAME_W, 0))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_path)


def save_overworld_sheet(spec: dict, out_path: Path):
    sheet = Image.new("RGBA", (OW_W * 2, OW_H), (0, 0, 0, 0))
    for i in range(2):
        sheet.paste(draw_overworld(spec, i), (i * OW_W, 0))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_path)


def main():
    for key, spec in CHARACTERS.items():
        save_battle_sheet(spec, ASSETS / "characters" / key / "battle.png")
        save_overworld_sheet(spec, ASSETS / "characters" / key / "overworld.png")
    for key, spec in ENEMIES.items():
        save_battle_sheet(spec, ASSETS / "enemies" / key / "battle.png")

    for entity_id in ("storm_lion", "ash_seraph", "iron_tortoise", "mirror_fox", "grave_stag"):
        sheet = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
        for i in range(2):
            sheet.paste(draw_entity(entity_id, i), (i * 32, 0))
        out = ASSETS / "entities" / entity_id / "idle.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        sheet.save(out)

    backgrounds_dir = ASSETS / "battle" / "backgrounds"
    backgrounds_dir.mkdir(parents=True, exist_ok=True)
    draw_background().save(backgrounds_dir / "hollow_court.png")

    manifest = {
        "frame_width": FRAME_W,
        "frame_height": FRAME_H,
        "frame_count": FRAME_COUNT,
        "states": BATTLE_STATES,
        "overworld": {"frame_width": OW_W, "frame_height": OW_H, "frames": 2},
    }
    (ASSETS / "battle" / "sheet_manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    print("Generated: %d character sheets, %d enemy sheets, 5 entities, 1 background."
          % (len(CHARACTERS), len(ENEMIES)))


if __name__ == "__main__":
    main()
