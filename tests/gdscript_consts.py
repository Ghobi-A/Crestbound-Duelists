"""Evaluate the `const` block of a GDScript file from Python.

The layout modules deliberately express geometry as arithmetic on the
canvas (``CANVAS.x * 0.256``) rather than as pre-computed literals, so
that changing the canvas moves the whole interface coherently. Tests that
scraped literals with a regex could not read that, and would silently
stop checking anything the moment a constant became an expression.

This resolves constants in declaration order, so each one may refer to
those above it, and returns them as ordinary Python values.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class Vector2:
    x: float
    y: float

    def __mul__(self, other: float) -> "Vector2":
        return Vector2(self.x * other, self.y * other)

    __rmul__ = __mul__

    def __sub__(self, other: "Vector2") -> "Vector2":
        return Vector2(self.x - other.x, self.y - other.y)

    def __add__(self, other: "Vector2") -> "Vector2":
        return Vector2(self.x + other.x, self.y + other.y)


@dataclass(frozen=True)
class Rect2:
    x: float
    y: float
    width: float
    height: float

    @property
    def position(self) -> Vector2:
        return Vector2(self.x, self.y)

    @property
    def size(self) -> Vector2:
        return Vector2(self.width, self.height)

    @property
    def end(self) -> Vector2:
        return Vector2(self.x + self.width, self.y + self.height)


# `const NAME := expression` — the expression runs to end of line.
_CONST = re.compile(r"^const ([A-Z][A-Z0-9_]*) := (.+?)\s*(?:#.*)?$", re.MULTILINE)


def _to_python(expression: str) -> str:
    """Rewrite the GDScript subset used by the layout modules."""
    expression = expression.strip()
    # Vector2.ONE is the only enum form these modules use.
    expression = expression.replace("Vector2.ONE", "Vector2(1, 1)")
    return expression


def constants(path: Path, extra: dict[str, Any] | None = None) -> dict[str, Any]:
    """Return every top-level constant in `path`, resolved in order.

    `extra` seeds the namespace with constants from other modules (a
    layout file referring to ``Typography.BODY``, say), keyed by the name
    used in the source.
    """
    namespace: dict[str, Any] = {"Vector2": Vector2, "Rect2": Rect2}
    namespace.update(extra or {})
    resolved: dict[str, Any] = {}
    for name, expression in _CONST.findall(path.read_text(encoding="utf-8")):
        try:
            value = eval(_to_python(expression), {"__builtins__": {}}, namespace)  # noqa: S307
        except Exception:  # noqa: BLE001 - a constant this helper cannot model
            continue
        namespace[name] = value
        resolved[name] = value
    return resolved


class Namespace:
    """Attribute access for constants referenced as `Module.NAME`."""

    def __init__(self, values: dict[str, Any]) -> None:
        self.__dict__.update(values)
