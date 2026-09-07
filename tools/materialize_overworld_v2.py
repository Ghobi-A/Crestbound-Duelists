"""Materialize deterministic overworld v2 PNG atlases from repository-safe base64 sources."""

from __future__ import annotations

import base64
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REWORK = ROOT / "game" / "assets" / "rework"
ATLAS_NAMES = ("kai_overworld_v2.png", "overworld_cast_v2.png")
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def materialize() -> None:
    for name in ATLAS_NAMES:
        source = REWORK / f"{name}.b64"
        target = REWORK / name
        payload = base64.b64decode("".join(source.read_text(encoding="ascii").split()), validate=True)
        if not payload.startswith(PNG_SIGNATURE):
            raise RuntimeError(f"decoded asset is not a PNG: {source}")
        target.write_bytes(payload)
        print(f"materialized {target.relative_to(ROOT)} ({len(payload)} bytes)")


if __name__ == "__main__":
    materialize()
