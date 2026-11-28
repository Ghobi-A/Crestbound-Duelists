"""Derive the Unsettled Crest's awakening effect from the six recognised ones.

Kai's Crest answers all six resonance patterns and settles into none
(docs/rework/CHAPTER_ONE_PROVISIONAL_CANON.md). Its awakening reuses the
Verdant Crest's PixelLab VFX source and rotates its hue frame by frame
through the six recognised Crests' colours, so the burst visibly flickers
between patterns.

Writes tools/vfx_sources/unsettled_crest/ (the same layout as a PixelLab VFX
Creator export); tools/build_vfx.py then builds it like every other effect.
Deterministic: the same source always gives the same files.

    python tools/compose_unsettled_vfx.py && python tools/build_vfx.py
"""
from __future__ import annotations

import colorsys
import json
import shutil
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tools/vfx_sources/verdant_crest"
OUT = ROOT / "tools/vfx_sources/unsettled_crest"
# Crimson, azure, ember, eclipse violet, glass cyan, verdant green.
HUES = [0.0, 0.59, 0.06, 0.74, 0.53, 0.36]


def _recolour(frame: np.ndarray, hue: float) -> np.ndarray:
    rgb = frame[:, :, :3].astype(np.float64) / 255.0
    out = frame.copy()
    flat = rgb.reshape(-1, 3)
    shifted = np.array([colorsys.hsv_to_rgb(hue, s, v) for (_, s, v) in (colorsys.rgb_to_hsv(*p) for p in flat)])
    out[:, :, :3] = np.round(shifted.reshape(rgb.shape) * 255.0).astype(np.uint8)
    return out


def _recolour_sheet(path: Path, clip: dict) -> Image.Image:
    sheet = np.asarray(Image.open(path).convert("RGBA")).copy()
    w, h = clip["frame"]["w"], clip["frame"]["h"]
    columns = clip["sheets"][0]["columns"]
    for i in range(clip["sheets"][0]["frames"]):
        y, x = (i // columns) * h, (i % columns) * w
        frame_index = clip["start_frame"] + i
        sheet[y:y + h, x:x + w] = _recolour(sheet[y:y + h, x:x + w], HUES[frame_index % len(HUES)])
    return Image.fromarray(sheet, "RGBA")


def main() -> None:
    manifest = json.loads((SOURCE / "manifest.json").read_text())
    OUT.mkdir(parents=True, exist_ok=True)
    for clip in manifest["clips"]:
        name = clip["sheets"][0]["file"]
        if (SOURCE / name).exists():
            _recolour_sheet(SOURCE / name, clip).save(OUT / name, optimize=True)
    manifest["name"] = "Crestbound unsettled_crest (derived from verdant_crest)"
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    if (SOURCE / "pixellab.json").exists():
        shutil.copyfile(SOURCE / "pixellab.json", OUT / "pixellab.json")


if __name__ == "__main__":
    main()
