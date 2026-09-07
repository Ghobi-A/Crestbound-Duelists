"""Materialize the authored overworld v2 PNG atlases used by Godot and Web export."""

from __future__ import annotations

from pathlib import Path

from overworld_v2_art import CAST, KAI, build_sheet

ROOT = Path(__file__).resolve().parents[1]
REWORK = ROOT / "game" / "assets" / "rework"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def materialize() -> None:
    targets = (
        (KAI, REWORK / "kai_overworld_v2.png", (640, 336)),
        (CAST, REWORK / "overworld_cast_v2.png", (640, 896)),
    )
    for specs, target, expected in targets:
        build_sheet(specs, target)
        payload = target.read_bytes()
        if not payload.startswith(PNG_SIGNATURE):
            raise RuntimeError(f"generated asset is not a PNG: {target}")
        print(f"materialized {target.relative_to(ROOT)} {expected[0]}x{expected[1]} ({len(payload)} bytes)")


if __name__ == "__main__":
    materialize()
