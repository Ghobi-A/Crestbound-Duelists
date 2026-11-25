"""Build the opening movie's game assets from reviewed PixelLab sources.

Sources live in tools/cinematic_sources/opening/:

* <key>.png          a chosen still (688x384, or 384x688 for the descent) or
                     a transparent element sprite;
* <key>/NN.png       the frames of an animated element (animate_image
                     output; frame 00 is the input pose and is skipped).

Writes, deterministically, to game/assets/cinematics/opening/:

* <key>.png          stills and sprites, unchanged except that a pale
                     border frame left by the generator is trimmed;
* <key>.png + .json  animated elements as one row of frames plus a sidecar
                     (frame_width, frame_height, frame_count).

The timeline that places them is authored by hand in
game/data/cinematics/opening_the_last_accord.json.

    python tools/build_cinematic.py
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "tools/cinematic_sources/opening"
OUT = ROOT / "game/assets/cinematics/opening"


def _save(image: Image.Image, path: Path) -> None:
    # Strip ancillary chunks so a rebuild is byte-identical.
    image.save(path, optimize=True)


def _trim_pale_border(image: Image.Image) -> Image.Image:
    """Drop edge rows/columns the generator left near-white (a 1-3 px frame
    some outputs carry), so a camera at the edge never shows a white line."""
    rgba = np.asarray(image)
    pale = (rgba[..., :3].min(axis=2) > 225) & (rgba[..., 3] > 0)
    left, top, right, bottom = 0, 0, rgba.shape[1], rgba.shape[0]
    # Columns go at a lower share: one output left a pale strip down only
    # part of an edge. Rows keep the stricter test, so a bright sky stays.
    while left < right - 1 and pale[:, left].mean() > 0.2:
        left += 1
    while right > left + 1 and pale[:, right - 1].mean() > 0.2:
        right -= 1
    while top < bottom - 1 and pale[top].mean() > 0.5:
        top += 1
    while bottom > top + 1 and pale[bottom - 1].mean() > 0.5:
        bottom -= 1
    return image.crop((left, top, right, bottom))


def build_still(path: Path) -> None:
    _save(_trim_pale_border(Image.open(path).convert("RGBA")), OUT / path.name)


def build_strip(folder: Path) -> dict:
    frames = [Image.open(p).convert("RGBA") for p in sorted(folder.glob("*.png"))][1:]
    w, h = frames[0].size
    strip = Image.new("RGBA", (w * len(frames), h))
    for i, frame in enumerate(frames):
        strip.paste(frame, (i * w, 0))
    _save(strip, OUT / f"{folder.name}.png")
    sidecar = {"frame_width": w, "frame_height": h, "frame_count": len(frames)}
    (OUT / f"{folder.name}.json").write_text(json.dumps(sidecar, indent=2) + "\n")
    return sidecar


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for path in sorted(SOURCES.glob("*.png")):
        build_still(path)
    for folder in sorted(p for p in SOURCES.iterdir() if p.is_dir()):
        build_strip(folder)


if __name__ == "__main__":
    main()
