"""Compose battle animation sheets from reviewed PixelLab frames.

Sources live in tools/battle_sources/<record>/ as <state>_NN.png, the
animate_image output for each state (frame 00 is the input pose, 01.. are
generated). For every record this writes, deterministically:

* game/assets/battle/cast/<record>.png  an 8-column grid of frames
  (idle, attack, hit, defeat), small enough for WebGL texture limits;
* game/assets/battle/cast/<record>.json  the DuelistSprite sidecar: frame
  size, columns, foot anchor, measured body height and per-state
  start/count/fps/loop;

and points the record's `battle_sheet` in characters.json at the sheet.
Records listed in NEW_RECORDS that the manifest does not have yet are
created from their sheet: the sheet doubles as their atlas, with a head
crop of the idle pose as the dialogue portrait. A story-only figure may
ship idle frames alone; its other states hold the idle pose.

Frames are never re-centred one by one, so a lunge or a fall keeps its
motion. Each state is shifted once so its first frame's feet land on the
idle pose's feet, then the cell is shared by every frame. The attack state
also names its contact frame.

    python tools/build_battle_sheets.py
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "tools/battle_sources"
OUT = ROOT / "game/assets/battle/cast"
CHARACTERS = ROOT / "game/assets/rework/characters.json"
COLUMNS = 8
# State: (first source frame, fps, loop, ping-pong). Idle keeps frame 00 (the
# authored pose) so the loop starts and ends on the approved art. Breathing
# and recoil play forward then back, so they return to their first pose
# instead of popping from the last generated frame.
STATES = {
    "idle": (0, 5, True, True),
    "attack": (1, 14, False, False),
    "hit": (1, 12, False, True),
    "defeat": (1, 9, False, False),
}
# The attack frame where the blow or spell lands, picked by eye from the
# reviewed frames (index within the attack state). The presentation lands
# damage, hit-stop and the lunge on it rather than during the wind-up.
CONTACT = {
    "kai_warrior": 7, "kai_guardian": 6, "kai_mage": 5, "kai_sorcerer": 4,
    "kai_assassin": 4, "kai_neutral": 3, "almyra": 2, "liora": 5,
    "riven_raider": 7, "unbound_mercenary": 6, "hexbound_adept": 3,
    "route01_rowan": 7, "route01_squire": 3, "route01_challenger": 7,
    "kai_unbonded": 4, "danfor": 5, "hale": 2, "assessor": 5,
    "greymaw": 4, "riven_wisp": 3, "riven_husk": 4, "riven_anchor": 3, "sealed_choir": 3,
}
# Vertical slice cast (docs/VERTICAL_SLICE_SPEC.md): display name, side,
# aliases, and a battle size relative to a standing Duelist (beasts and
# Riven constructs are not person-sized).
NEW_RECORDS = {
    "kai_unbonded": {"display_name": "Kai", "battle_side": "player", "aliases": ["kai_unsettled"]},
    "danfor": {"display_name": "Danfor", "battle_side": "enemy"},
    "joey": {"display_name": "Joey", "battle_side": "player"},
    "lena": {"display_name": "Lena", "battle_side": "enemy"},
    "silas": {"display_name": "Elder Silas", "battle_side": "enemy"},
    "gell": {"display_name": "Gell", "battle_side": "enemy"},
    "hale": {"display_name": "Specialist Hale", "battle_side": "player", "class_id": "sorcerer", "overworld": "person"},
    "assessor": {"display_name": "Assessor", "battle_side": "enemy", "overworld": "person"},
    "greymaw": {"display_name": "Old Greymaw", "battle_side": "enemy", "size": 1.25, "overworld": 20},
    "riven_wisp": {"display_name": "Riven Wisp", "battle_side": "enemy", "size": 0.8, "overworld": 18},
    "riven_husk": {"display_name": "Riven Husk", "battle_side": "enemy", "size": 1.15, "overworld": 26},
    "riven_anchor": {"display_name": "Riven Anchor", "battle_side": "enemy", "size": 1.2, "overworld": 28},
    "sealed_choir": {"display_name": "The Sealed Choir", "battle_side": "enemy", "size": 1.6, "overworld": 46},
}
# Map sprites for figures without an authored overworld sheet: the idle
# battle pose. People are drawn at the shared overworld height (like every
# resident); a beast or Riven construct at its own "display_height" px,
# which tools/audit_character_scale.py leaves out of the person check.
OVERWORLD = ROOT / "game/assets/overworld/figures"


def _frames(folder: Path, state: str) -> list[np.ndarray]:
    paths = sorted(folder.glob(f"{state}_*.png"))
    if not paths and state != "idle" and folder.name in NEW_RECORDS:
        # Story-only figures (and Joey, who never attacks) hold their pose.
        paths = sorted(folder.glob("idle_*.png"))[:1] * 2
    if not paths:
        raise FileNotFoundError(f"{folder.name}: no {state} frames")
    return [np.asarray(Image.open(p).convert("RGBA")) for p in paths]


def feet(rgba: np.ndarray) -> tuple[float, int]:
    """Centre x of the lowest body rows and the foot row."""
    opaque = rgba[:, :, 3] >= 128
    rows = np.flatnonzero(opaque.any(axis=1))
    bottom = int(rows[-1])
    band = opaque[max(0, bottom - 6): bottom + 1]
    return float(np.flatnonzero(band.any(axis=0)).mean()), bottom


def body_height(rgba: np.ndarray) -> int:
    opaque = rgba[:, :, 3] >= 128
    counts = opaque.sum(axis=1)
    rows = np.flatnonzero(counts >= max(3, rgba.shape[1] * 0.04))
    return int(np.flatnonzero(counts)[-1] - rows[0] + 1)


def _shift(rgba: np.ndarray, dx: int, dy: int) -> np.ndarray:
    out = np.zeros_like(rgba)
    h, w = rgba.shape[:2]
    ys, xs = slice(max(0, dy), min(h, h + dy)), slice(max(0, dx), min(w, w + dx))
    src_y, src_x = slice(max(0, -dy), min(h, h - dy)), slice(max(0, -dx), min(w, w - dx))
    out[ys, xs] = rgba[src_y, src_x]
    return out


def build(name: str) -> dict:
    folder = SOURCES / name
    idle = _frames(folder, "idle")
    anchor_x, anchor_y = feet(idle[0])
    frames, states = [], {}
    for state, (first, fps, loop, ping_pong) in STATES.items():
        sequence = _frames(folder, state)[first:]
        if ping_pong:
            # A loop wraps back to its first frame itself; a one-shot ends on it.
            sequence += sequence[-2:0:-1] if loop else sequence[-2::-1]
        fx, fy = feet(sequence[0])
        dx, dy = round(anchor_x - fx), anchor_y - fy
        states[state] = {"start": len(frames), "count": len(sequence), "fps": fps, "loop": loop}
        if state == "attack":
            states[state]["contact"] = CONTACT.get(name, len(sequence) // 2)
        frames += [_shift(frame, dx, dy) for frame in sequence]
    h, w = frames[0].shape[:2]
    rows = -(-len(frames) // COLUMNS)
    sheet = np.zeros((rows * h, COLUMNS * w, 4), np.uint8)
    for index, frame in enumerate(frames):
        row, column = divmod(index, COLUMNS)
        sheet[row * h:(row + 1) * h, column * w:(column + 1) * w] = frame
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(sheet, "RGBA").save(OUT / f"{name}.png", optimize=True)
    sidecar = {"frame_width": w, "frame_height": h, "columns": COLUMNS, "frame_count": len(frames),
               "anchor": [round(anchor_x, 1), anchor_y + 1], "body_height": body_height(idle[0]),
               "native_facing": "right", "states": states}
    if "size" in NEW_RECORDS.get(name, {}):
        sidecar["size"] = NEW_RECORDS[name]["size"]
    (OUT / f"{name}.json").write_text(json.dumps(sidecar, indent=2) + "\n")
    return sidecar


def measured_height(rgba: np.ndarray, foot_y: int) -> int:
    """Body height exactly as tools/audit_character_scale.py measures it."""
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from audit_character_scale import body_top, opaque_mask
    return foot_y - body_top(opaque_mask(Image.fromarray(rgba, "RGBA"), "alpha"), foot_y)


def map_height(rgba: np.ndarray, foot: tuple[float, int]) -> int:
    """Map body height exactly as the audit measures a standing map frame."""
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from audit_character_scale import measure, opaque_mask
    return measure(opaque_mask(Image.fromarray(rgba, "RGBA"), "alpha"), foot)["body_height"]


def portrait_rect(rgba: np.ndarray) -> list[int]:
    """A square head-and-shoulders crop at the top of the idle pose."""
    opaque = rgba[:, :, 3] >= 128
    rows = np.flatnonzero(opaque.any(axis=1))
    top, bottom = int(rows[0]), int(rows[-1])
    side = max(24, round((bottom - top) * 0.42))
    band = opaque[top: top + max(4, side // 2)]
    centre = float(np.flatnonzero(band.any(axis=0)).mean())
    x = int(min(max(0, round(centre - side / 2)), rgba.shape[1] - side))
    return [x, max(0, top - 2), side, side]


def overworld_strip(name: str, display) -> dict:
    """Map sprite from the idle pose: down/up/east as drawn, mirrored west."""
    idle = np.asarray(Image.open(SOURCES / name / "idle_00.png").convert("RGBA"))
    pose = Image.fromarray(idle, "RGBA")
    w, h = pose.size
    strip = Image.new("RGBA", (w * 4, h))
    for column, image in enumerate([pose, pose, pose, pose.transpose(Image.FLIP_LEFT_RIGHT)]):
        strip.paste(image, (column * w, 0))
    OVERWORLD.mkdir(parents=True, exist_ok=True)
    strip.save(OVERWORLD / f"{name}.png", optimize=True)
    _, fy = feet(idle)
    # A four-legged body stands centred on its tile, not on its front paws.
    columns = np.flatnonzero((idle[:, :, 3] >= 128).any(axis=0))
    centre = (int(columns[0]) + int(columns[-1])) / 2
    height = map_height(idle, (round(centre), fy + 1))
    world = {"atlas": f"res://assets/overworld/figures/{name}.png", "frame_size": [w, h], "row": 0,
             "foot_anchor": [round(centre), fy + 1], "body_height": height}
    if display != "person":
        world["display_height"] = int(display)
    return world


def main() -> None:
    characters = json.loads(CHARACTERS.read_text())
    for folder in sorted(p for p in SOURCES.iterdir() if p.is_dir()):
        build(folder.name)
        sheet = f"res://assets/battle/cast/{folder.name}.png"
        meta = NEW_RECORDS.get(folder.name)
        if meta is not None:
            idle = np.asarray(Image.open(folder / "idle_00.png").convert("RGBA"))
            fx, fy = feet(idle)
            record = {"display_name": meta["display_name"], "aliases": meta.get("aliases", []),
                      "battle_side": meta["battle_side"], "atlas": sheet, "colour_key": "alpha",
                      # Frame 0 of the sheet is the idle pose: the measured combat body.
                      "battle_rect": [0, 0, idle.shape[1], idle.shape[0]], "foot_anchor": [round(fx, 1), fy + 1],
                      "battle_body_height": measured_height(idle, fy + 1), "portrait_rect": portrait_rect(idle)}
            if "class_id" in meta:
                record["class_id"] = meta["class_id"]
            if meta.get("overworld"):
                record["overworld"] = overworld_strip(folder.name, meta["overworld"])
            characters["characters"][folder.name] = record
        characters["characters"][folder.name]["battle_sheet"] = sheet
    CHARACTERS.write_text(json.dumps(characters, indent=2) + "\n")


if __name__ == "__main__":
    main()
