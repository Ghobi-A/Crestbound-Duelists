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
}


def _frames(folder: Path, state: str) -> list[np.ndarray]:
    paths = sorted(folder.glob(f"{state}_*.png"))
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
    (OUT / f"{name}.json").write_text(json.dumps(sidecar, indent=2) + "\n")
    return sidecar


def main() -> None:
    characters = json.loads(CHARACTERS.read_text())
    for folder in sorted(p for p in SOURCES.iterdir() if p.is_dir()):
        build(folder.name)
        characters["characters"][folder.name]["battle_sheet"] = f"res://assets/battle/cast/{folder.name}.png"
    CHARACTERS.write_text(json.dumps(characters, indent=2) + "\n")


if __name__ == "__main__":
    main()
