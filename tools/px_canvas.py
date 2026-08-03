"""
Shared pixel canvas primitives for the Crestbound Duelists art generators.

Extracted so the sprite, overworld and tile generators draw through one
implementation instead of three copies that can quietly drift apart.
"""

from __future__ import annotations

from PIL import Image

# Every opaque cluster gets this outline, which is what holds the art
# together as a single style across sprites, props and tiles.
OUTLINE = (20, 20, 31, 255)


def c(hexcode: str, alpha: int = 255) -> tuple:
    hexcode = hexcode.lstrip("#")
    return (int(hexcode[0:2], 16), int(hexcode[2:4], 16), int(hexcode[4:6], 16), alpha)


def shade(color: tuple, factor: float) -> tuple:
    return (
        max(0, min(255, int(color[0] * factor))),
        max(0, min(255, int(color[1] * factor))),
        max(0, min(255, int(color[2] * factor))),
        color[3],
    )


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
