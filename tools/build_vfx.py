"""Compose move effects from PixelLab VFX Creator game packs.

Sources live in tools/vfx_sources/<vfx_key>/: the pack's manifest.json and
its front.png / behind.png clip sheets (frames left to right, top to
bottom), plus pixellab.json naming the editable effect on pixellab.ai. For
every key this writes, deterministically:

* game/assets/vfx/moves/<key>.png  the front layer, one row of frames;
* game/assets/vfx/moves/<key>_behind.png  the layer under the target,
  when the effect has one, on the same frames;
* game/assets/vfx/moves/<key>.json  the BattleVfx sidecar: frame size,
  fps, the target's feet in the frame, display scale, the impact time
  (when the effect lands) and the effect's dominant colour for the
  ground light under magic.

Effects are drawn for a target on the right facing left (struck from the
left); BattleVfx mirrors them when the target is on the player side.

    python tools/build_vfx.py
"""
from __future__ import annotations

import colorsys
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "tools/vfx_sources"
OUT = ROOT / "game/assets/vfx/moves"
# Effects are authored at twice the logical density: a 39 px battle body was
# 78 px in the VFX Creator, so one effect pixel is half a logical pixel.
SCALE = 0.5
LAYERS = ("front", "behind")


def _clip_frames(folder: Path, clip: dict) -> list[np.ndarray]:
    sheet = np.asarray(Image.open(folder / clip["sheets"][0]["file"]).convert("RGBA"))
    w, h = clip["frame"]["w"], clip["frame"]["h"]
    columns = clip["sheets"][0]["columns"]
    return [sheet[(i // columns) * h:(i // columns + 1) * h, (i % columns) * w:(i % columns + 1) * w]
            for i in range(clip["frames"])]


def _coverage(frame: np.ndarray) -> int:
    return int((frame[:, :, 3] >= 128).sum())


def _glow(frame: np.ndarray) -> str:
    """The effect's own colour: saturated, bright pixels, at full value."""
    rgb = frame[:, :, :3][frame[:, :, 3] >= 128].astype(float) / 255
    hsv = np.array([colorsys.rgb_to_hsv(*p) for p in rgb]) if len(rgb) else np.zeros((0, 3))
    keep = rgb[(hsv[:, 1] >= 0.35) & (hsv[:, 2] >= 0.45)] if len(rgb) else rgb
    mean = (keep if len(keep) else rgb).mean(axis=0) if len(rgb) else np.ones(3)
    hue, sat, _ = colorsys.rgb_to_hsv(*mean)
    r, g, b = colorsys.hsv_to_rgb(hue, min(1.0, sat * 1.1), 1.0)
    return f"#{round(r * 255):02x}{round(g * 255):02x}{round(b * 255):02x}"


def build(key: str) -> dict:
    folder = SOURCES / key
    manifest = json.loads((folder / "manifest.json").read_text())
    clips = {c["name"]: c for c in manifest["clips"] if c["name"] in LAYERS and (folder / c["sheets"][0]["file"]).exists()}
    # One shared frame: the union of every layer's rect around the feet.
    left = min(c["offset"]["x"] for c in clips.values())
    top = min(c["offset"]["y"] for c in clips.values())
    right = max(c["offset"]["x"] + c["frame"]["w"] for c in clips.values())
    bottom = max(c["offset"]["y"] + c["frame"]["h"] for c in clips.values())
    w, h = right - left, bottom - top
    count = max(c["start_frame"] + c["frames"] for c in clips.values())
    strips = {}
    for name, clip in clips.items():
        strip = np.zeros((h, w * count, 4), np.uint8)
        x0, y0 = clip["offset"]["x"] - left, clip["offset"]["y"] - top
        for i, frame in enumerate(_clip_frames(folder, clip)):
            x = (clip["start_frame"] + i) * w + x0
            strip[y0:y0 + frame.shape[0], x:x + frame.shape[1]] = frame
        strips[name] = strip
    frames = [sum(_coverage(s[:, i * w:(i + 1) * w]) for s in strips.values()) for i in range(count)]
    # The hit lands on the first frame at half the peak: a slash mid-sweep,
    # a bolt's burst rather than its flight.
    impact = next(i for i, c in enumerate(frames) if c >= max(frames) * 0.5)
    fps = manifest["fps"]
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(strips["front"], "RGBA").save(OUT / f"{key}.png", optimize=True)
    sidecar = {
        "frame_width": w, "frame_height": h, "frame_count": count, "fps": fps, "loop": False,
        "anchor": [-left, -top], "anchor_to": "feet", "scale": SCALE,
        "impact": round(impact / fps, 3),
        "glow": _glow(np.concatenate([s[:, impact * w:(impact + 1) * w] for s in strips.values()], axis=1)),
    }
    if "behind" in strips:
        Image.fromarray(strips["behind"], "RGBA").save(OUT / f"{key}_behind.png", optimize=True)
        sidecar["behind"] = f"{key}_behind.png"
    (OUT / f"{key}.json").write_text(json.dumps(sidecar, indent=2) + "\n")
    return sidecar


def main() -> None:
    for folder in sorted(p for p in SOURCES.iterdir() if p.is_dir()):
        build(folder.name)


if __name__ == "__main__":
    main()
