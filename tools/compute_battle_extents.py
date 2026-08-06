"""Derive left_extent/right_extent for every authored battle sidecar.

battle_controller.gd's formation math (_sprite_envelope() in
battle_controller.gd) needs to know how far each character's actual art
reaches from its anchor on each side — not just half the frame width,
which overstates the room a narrow silhouette needs and understates it
for a lopsided one (a raised weapon, a trailing cloak). Rather than
hand-guess those numbers, this reads each battle.png's real
non-transparent bounds and writes them into its sidecar.

Run after regenerating or re-anchoring any battle.png:

    python3 tools/compute_battle_extents.py

Idempotent: re-running after nothing changed rewrites the same values.
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image

REPO_ROOT = Path(__file__).resolve().parents[1]
ASSETS = REPO_ROOT / "game" / "assets"


def compute(sidecar_path: Path) -> None:
    sidecar = json.loads(sidecar_path.read_text(encoding="utf-8"))
    png_path = sidecar_path.with_suffix(".png")
    im = np.asarray(Image.open(png_path).convert("RGBA"))
    frame_w = sidecar["frame_width"]
    frame_count = sidecar.get("frame_count", 1)
    anchor_x = sidecar["anchor"][0]

    # Union of alpha bounds across every frame: most authored sheets are
    # a single idle frame reused for every state, but this stays correct
    # if a sheet ever adds more without anyone having to remember why.
    min_x, max_x = frame_w, 0
    for i in range(frame_count):
        frame = im[:, i * frame_w : (i + 1) * frame_w, :]
        solid = frame[..., 3] > 10
        if not solid.any():
            continue
        xs = np.where(solid.any(axis=0))[0]
        min_x = min(min_x, int(xs.min()))
        max_x = max(max_x, int(xs.max()) + 1)

    sidecar["left_extent"] = anchor_x - min_x
    sidecar["right_extent"] = max_x - anchor_x

    ordered = {}
    for key in (
        "frame_width", "frame_height", "frame_count", "anchor",
        "default_facing", "left_extent", "right_extent", "states",
    ):
        if key in sidecar:
            ordered[key] = sidecar.pop(key)
    ordered.update(sidecar)
    sidecar_path.write_text(json.dumps(ordered, indent=2) + "\n", encoding="utf-8")
    print(f"{sidecar_path.relative_to(REPO_ROOT)}: left={ordered['left_extent']} "
          f"right={ordered['right_extent']}")


def main() -> None:
    paths = sorted(ASSETS.glob("characters/**/battle.json")) + \
        sorted(ASSETS.glob("enemies/**/battle.json"))
    for path in paths:
        compute(path)


if __name__ == "__main__":
    main()
