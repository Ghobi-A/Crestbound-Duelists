"""Compose overworld sheets for characters re-rendered on Kai's proportions.

Sources (tools/overworld_sources/<name>/) are reviewed PixelLab outputs: a
standing rotation per facing (rot_<facing>.png) and four-frame side walks
(walk_<east|west>_<n>.png). Deterministic; never edits art pixels beyond
alignment and keying.

* Authored NPCs -> game/assets/overworld/<name>.png, the 4x4 magenta-keyed
  layout build_overworld_metadata.py reads: rows down, up, east, west;
  columns idle, left contact, idle, right contact (front and back rows
  repeat the idle pose: NPCs only ever stand).
* Route trainers -> game/assets/route01/<name>_overworld.png, a 1x4 alpha
  strip (down, up, east, west), with characters.json frame size and foot
  anchor updated to match.

Then run build_overworld_metadata.py and audit_character_scale.py --write.

    python tools/rerender_overworld_sheets.py
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "tools/overworld_sources"
AUTHORED = ROOT / "game/assets/overworld"
CHARACTERS = ROOT / "game/assets/rework/characters.json"
TRAINERS = {"rowan": "route01_rowan", "squire": "route01_squire", "challenger": "route01_challenger"}
FOOT_MARGIN = 12
MAGENTA = (255, 0, 255)


def _load(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGBA"))


def _anchor(rgba: np.ndarray) -> tuple[float, int]:
    """Torso centre x (head and body, ignoring striding legs) and foot y."""
    ys, xs = np.nonzero(rgba[:, :, 3] >= 128)
    top, bottom = ys.min(), ys.max()
    upper = ys < top + (bottom - top) * 0.6
    return float(xs[upper].mean()), int(bottom)


def _place(cell: int, rgba: np.ndarray) -> np.ndarray:
    out = np.zeros((cell, cell, 4), np.uint8)
    cx, foot = _anchor(rgba)
    dx, dy = round(cell / 2 - cx), cell - FOOT_MARGIN - foot
    h, w = rgba.shape[:2]
    ys, xs = np.mgrid[0:h, 0:w]
    tx, ty = xs + dx, ys + dy
    ok = (tx >= 0) & (tx < cell) & (ty >= 0) & (ty < cell) & (rgba[:, :, 3] > 0)
    out[ty[ok], tx[ok]] = rgba[ok]
    return out


def _frames(name: str) -> dict:
    folder = SOURCES / name
    rot = {facing: _load(folder / f"rot_{facing}.png") for facing in ("south", "north", "east", "west")}
    walks = {side: [_load(folder / f"walk_{side}_{i}.png") for i in range(4)] for side in ("east", "west")}
    picked = {side: _contacts(rot[side], walks[side]) for side in ("east", "west")}
    return {"down": [rot["south"]] * 4, "up": [rot["north"]] * 4,
            "east": [rot["east"], picked["east"][0], rot["east"], picked["east"][1]],
            "west": [rot["west"], picked["west"][0], rot["west"], picked["west"][1]]}


def _small(rgba: np.ndarray, size: int = 24) -> np.ndarray:
    # The walk audit compares frames at display size; so does this choice.
    placed = _place(max(rgba.shape[:2]), rgba).astype(float)
    placed[placed[:, :, 3] < 128] = 0
    return np.asarray(Image.fromarray(placed[:, :, :3].astype(np.uint8)).resize((size, size), Image.BOX), float)


def _height(rgba: np.ndarray) -> int:
    ys = np.nonzero(rgba[:, :, 3] >= 128)[0]
    return int(ys.max() - ys.min() + 1)


def _contacts(idle: np.ndarray, frames: list) -> tuple:
    """The two walk frames whose legs differ most (left and right contact),
    among pairs that keep the idle pose's height within a display pixel."""
    limit = _height(idle) / 24.0 * 1.2
    best, best_score = (frames[0], frames[2]), -1.0
    for i in range(len(frames)):
        for j in range(i + 1, len(frames)):
            if max(abs(_height(f) - _height(idle)) for f in (frames[i], frames[j])) > limit:
                continue
            score = float((np.abs(_small(frames[i]) - _small(frames[j])).max(-1) > 40).mean())
            if score > best_score:
                best, best_score = (frames[i], frames[j]), score
    return best


def _cell(frames) -> int:
    extent = 0
    for image in frames:
        ys, xs = np.nonzero(image[:, :, 3] >= 128)
        extent = max(extent, xs.max() - xs.min() + 24, ys.max() - ys.min() + FOOT_MARGIN + 24)
    return int(max(256, np.ceil(extent / 8) * 8))


def build_authored(name: str) -> None:
    frames = _frames(name)
    cell = _cell([f for row in frames.values() for f in row])
    sheet = np.zeros((cell * 4, cell * 4, 4), np.uint8)
    for row, facing in enumerate(("down", "up", "east", "west")):
        for column, image in enumerate(frames[facing]):
            sheet[row * cell:(row + 1) * cell, column * cell:(column + 1) * cell] = _place(cell, image)
    # Hard alpha onto the magenta key the authored sheets and shader use.
    rgb = np.where(sheet[:, :, 3:4] >= 128, sheet[:, :, :3], np.array(MAGENTA, np.uint8))
    Image.fromarray(rgb.astype(np.uint8), "RGB").save(AUTHORED / f"{name}.png", optimize=True)


def build_trainer(name: str, record: dict) -> None:
    folder = SOURCES / name
    frames = [_load(folder / f"rot_{facing}.png") for facing in ("south", "north", "east", "west")]
    cell = _cell(frames)
    strip = np.concatenate([_place(cell, image) for image in frames], axis=1)
    Image.fromarray(strip, "RGBA").save(ROOT / "game" / record["atlas"].removeprefix("res://"), optimize=True)
    record["frame_size"] = [cell, cell]
    record["foot_anchor"] = [cell // 2, cell - FOOT_MARGIN]


def main() -> None:
    characters = json.loads(CHARACTERS.read_text())
    for folder in sorted(p for p in SOURCES.iterdir() if p.is_dir()):
        if folder.name in TRAINERS:
            build_trainer(folder.name, characters["characters"][TRAINERS[folder.name]]["overworld"])
        else:
            build_authored(folder.name)
    CHARACTERS.write_text(json.dumps(characters, indent=2) + "\n")


if __name__ == "__main__":
    main()
