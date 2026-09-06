"""
Crestbound Duelists — interface surface grain
=============================================
Authors the fine tiling grain that gives interface panels a material.

A flat translucent fill reads as generic glass: the same panel would sit
just as happily in a phone weather app. Crestbound's panels should read
as something *found* — dark slate, old vellum under lamplight — and the
cheapest honest way to say that is a very low-contrast grain that breaks
up the fill without ever becoming a visible texture.

Deliberately subtle: peak deviation is a few values out of 255. If the
grain is legible as a pattern it is too strong, and it will fight the
artwork the panels sit over.

Tiles seamlessly at 64x64 so a panel of any size can repeat it.

Run:

    python tools/generate_ui_surface.py

Outputs:
    game/assets/ui/surface_grain.png    64x64 seamless, white with alpha
"""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "assets" / "ui" / "surface_grain.png"

SIZE = 64
# Alpha ceiling. The first attempt used 26 with a coarse octave and the
# result was plainly legible as a repeating blotch across a 700px panel —
# a tiling pattern is worse than no texture at all. The grain must read
# as surface, never as wallpaper.
PEAK_ALPHA = 9


def _seamless_value_noise(size: int, period: int, seed: int) -> list[list[float]]:
    """Value noise on a lattice that wraps, so the tile has no seam."""
    rng = random.Random(seed)
    lattice = [[rng.random() for _ in range(period)] for _ in range(period)]

    def sample(x: float, y: float) -> float:
        x0, y0 = int(math.floor(x)), int(math.floor(y))
        fx, fy = x - x0, y - y0
        # Smoothstep keeps the interpolation free of lattice creases.
        ux, uy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        a = lattice[y0 % period][x0 % period]
        b = lattice[y0 % period][(x0 + 1) % period]
        c = lattice[(y0 + 1) % period][x0 % period]
        d = lattice[(y0 + 1) % period][(x0 + 1) % period]
        return (a * (1 - ux) + b * ux) * (1 - uy) + (c * (1 - ux) + d * ux) * uy

    scale = period / size
    return [[sample(x * scale, y * scale) for x in range(size)] for y in range(size)]


def grain() -> Image.Image:
    # Both octaves are fine. A low-frequency octave tiles visibly at any
    # panel size, because its features are a large fraction of the tile.
    coarse = _seamless_value_noise(SIZE, 16, 0xC7E5)
    fine = _seamless_value_noise(SIZE, 32, 0x10FE)

    image = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    pixels = image.load()
    for y in range(SIZE):
        for x in range(SIZE):
            value = coarse[y][x] * 0.45 + fine[y][x] * 0.55
            # Centred on zero, so the grain lightens and darkens the
            # surface equally instead of only brightening it.
            signed = (value - 0.5) * 2.0
            alpha = int(abs(signed) * PEAK_ALPHA)
            tone = 255 if signed > 0 else 0
            pixels[x, y] = (tone, tone, tone, alpha)
    return image


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    grain().save(OUT)
    print(f"Surface grain: {OUT}")


if __name__ == "__main__":
    main()
