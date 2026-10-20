"""Build the painted-terrain inputs for locations with a "painted" block.

Deterministic (numpy + Pillow, fixed seeds), so the committed outputs can be
regenerated and diffed:

* fields_<location>.png  RGBA material fields, 8 px per tile, blurred so
  the terrain shader can threshold them into organic edges: R path (dirt
  or cobbles), G water, B forest, A tall grass. Collision still reads the
  map rows.
* noise.png              tileable fBm (R broad, G medium, B fine).
* <material>.png         seamless material textures made from the reviewed
  PixelLab sources in tools/painted_sources/.
* <prop>.png             transparent dressing props (shore rocks, shrubs)
  and pre-blurred foreground foliage from the same sources.

    python tools/build_painted_terrain.py
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
LOCATIONS = ROOT / "game/world/locations.json"
SOURCES = ROOT / "tools/painted_sources"
OUT = ROOT / "game/assets/environment/painted"
PX_PER_TILE = 8
# Blur radius per channel in field pixels: wide enough to round path corners
# and shorelines, narrow enough that walkable tiles never read as water.
CHANNELS = (
    ("path", None, 8.0),
    ("water", "~", 4.0),
    ("forest", "#", 5.0),
    ("tall_grass", "g", 4.0),
)
# Material sources: (file, crop box within the PixelLab output, output size).
MATERIALS = {
    "grass": ("grass.png", (24, 40, 232, 248), 256),
    "dirt": ("dirt.png", (0, 0, 190, 190), 256),
    "cobble": ("cobble.png", None, 256),
    "water": ("water.png", (0, 0, 200, 200), 256),
    "tall_grass": ("tall_grass.png", (20, 40, 236, 256), 256),
}


def _gaussian(values: np.ndarray, sigma: float) -> np.ndarray:
    radius = int(np.ceil(sigma * 3))
    offsets = np.arange(-radius, radius + 1)
    kernel = np.exp(-(offsets ** 2) / (2 * sigma * sigma))
    kernel /= kernel.sum()
    # Edge-extend so the map border neither fades nor wraps.
    padded = np.pad(values, radius, mode="edge")
    rows = np.apply_along_axis(lambda r: np.convolve(r, kernel, mode="valid"), 1, padded)
    return np.apply_along_axis(lambda c: np.convolve(c, kernel, mode="valid"), 0, rows)


def build_fields(location: dict) -> Image.Image:
    rows = location["rows"]
    height, width = len(rows), len(rows[0])
    channels = []
    path_symbols = location["painted"]["path_symbols"]
    for _name, symbols, sigma in CHANNELS:
        symbols = symbols or path_symbols
        mask = np.array([[1.0 if c in symbols else 0.0 for c in row] for row in rows])
        mask = np.kron(mask, np.ones((PX_PER_TILE, PX_PER_TILE)))
        channels.append(np.clip(np.round(_gaussian(mask, sigma) * 255), 0, 255).astype(np.uint8))
    assert channels[0].shape == (height * PX_PER_TILE, width * PX_PER_TILE)
    return Image.fromarray(np.dstack(channels), "RGBA")


def _value_noise(size: int, cells: int, rng: np.random.RandomState) -> np.ndarray:
    lattice = rng.rand(cells, cells)
    coords = np.arange(size) * cells / size
    i0 = np.floor(coords).astype(int)
    t = coords - i0
    t = t * t * (3 - 2 * t)
    i1 = (i0 + 1) % cells
    top = lattice[i0][:, i0] * (1 - t)[None, :] + lattice[i0][:, i1] * t[None, :]
    bottom = lattice[i1][:, i0] * (1 - t)[None, :] + lattice[i1][:, i1] * t[None, :]
    return top * (1 - t)[:, None] + bottom * t[:, None]


def build_noise(size: int = 256) -> Image.Image:
    rng = np.random.RandomState(1901)
    out = []
    for base in (4, 12, 40):
        total = np.zeros((size, size))
        amplitude, weight = 1.0, 0.0
        for octave in range(4):
            total += _value_noise(size, base * 2 ** octave, rng) * amplitude
            weight += amplitude
            amplitude *= 0.5
        total /= weight
        total = (total - total.min()) / (total.max() - total.min())
        out.append(np.round(total * 255).astype(np.uint8))
    return Image.fromarray(np.dstack(out), "RGB")


def make_seamless(image: Image.Image, size: int) -> Image.Image:
    """Blend four half-rolled copies so every edge wraps.

    Each copy is weighted to zero along its own seams (the image edges for
    the original, the centre lines for the rolled copies), so no seam from
    any copy survives into the result.
    """
    src = np.asarray(image.convert("RGB").resize((size, size), Image.LANCZOS)).astype(np.float64)
    half = size // 2
    phase = np.pi * (np.arange(size) + 0.5) / size
    edge = np.sin(phase) ** 2      # zero at the image edges
    centre = np.cos(phase) ** 2    # zero along the centre line
    total = np.zeros_like(src)
    for shift_y, wy in ((0, edge), (half, centre)):
        for shift_x, wx in ((0, edge), (half, centre)):
            copy = np.roll(src, (shift_y, shift_x), axis=(0, 1))
            total += copy * np.outer(wy, wx)[:, :, None]
    # edge + centre == 1, so the four weights already sum to one.
    return Image.fromarray(np.clip(np.round(total), 0, 255).astype(np.uint8), "RGB")


# Transparent props: (file, crop box, edge feather px, blur sigma px, rounded).
# "Rounded" props were generated as a full bed of foliage; an irregular
# elliptical silhouette turns them into a single free-standing shrub.
PROPS = {
    "rocks": ("rocks.png", (0, 0, 138, 112), 10, 0.0, False),
    "bush": ("bush.png", None, 6, 0.0, True),
    "leaves_blur": ("leaves.png", None, 0, 3.2, False),
}


def build_prop(image: Image.Image, box, feather: int, sigma: float, rounded: bool = False) -> Image.Image:
    """Crop, fade cut-off edges into the ground, optionally round the
    silhouette and optionally blur (premultiplied, so blurred foliage keeps
    clean dark-free edges)."""
    if box is not None:
        image = image.crop(box)
    rgba = np.asarray(image.convert("RGBA")).astype(np.float64) / 255.0
    if rounded:
        h, w = rgba.shape[:2]
        ys, xs = np.mgrid[0:h, 0:w]
        angle = np.arctan2(ys - h * 0.58, xs - w / 2)
        rng = np.random.RandomState(7)
        wobble = sum(rng.rand() * 0.06 * np.sin(k * angle + rng.rand() * 6.28) for k in (3, 5, 7, 11))
        radius = np.hypot((xs - w / 2) / (w * 0.5), (ys - h * 0.58) / (h * 0.52))
        rgba[:, :, 3] *= np.clip((1.0 + wobble - radius) / 0.08, 0.0, 1.0)
    if feather:
        # Fade every cut-off edge (generated props run to the canvas edge),
        # strongest along the bottom where the prop meets the ground.
        h, w = rgba.shape[:2]
        ys, xs = np.arange(h)[:, None], np.arange(w)[None, :]
        side = np.minimum(xs, w - 1 - xs) / (feather * 1.5)
        rim = np.minimum(np.minimum(ys / (feather * 1.5), (h - 1 - ys) / feather), side)
        rgba[:, :, 3] *= np.clip(rim, 0.0, 1.0)
    if sigma > 0:
        pad = int(np.ceil(sigma * 3))
        rgba = np.pad(rgba, ((pad, pad), (pad, pad), (0, 0)))
        alpha = rgba[:, :, 3:4]
        colour = _blur_stack(rgba[:, :, :3] * alpha, sigma)
        alpha = _blur_stack(alpha, sigma)
        rgba = np.concatenate([np.where(alpha > 1e-4, colour / np.maximum(alpha, 1e-4), 0.0), alpha], axis=2)
    return Image.fromarray(np.clip(np.round(rgba * 255), 0, 255).astype(np.uint8), "RGBA")


def _blur_stack(values: np.ndarray, sigma: float) -> np.ndarray:
    return np.dstack([_gaussian(values[:, :, c], sigma) for c in range(values.shape[2])])


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    locations = json.loads(LOCATIONS.read_text())["locations"]
    for key in sorted(locations):
        if "painted" in locations[key]:
            build_fields(locations[key]).save(OUT / f"fields_{key}.png", optimize=True)
    build_noise().save(OUT / "noise.png", optimize=True)
    for name, (file, box, size) in sorted(MATERIALS.items()):
        source = Image.open(SOURCES / file)
        if box is not None:
            source = source.crop(box)
        make_seamless(source, size).save(OUT / f"{name}.png", optimize=True)
    for name, (file, box, feather, sigma, rounded) in sorted(PROPS.items()):
        build_prop(Image.open(SOURCES / file), box, feather, sigma, rounded).save(OUT / f"{name}.png", optimize=True)


if __name__ == "__main__":
    main()
