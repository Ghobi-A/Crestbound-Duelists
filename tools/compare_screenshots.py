#!/usr/bin/env python3
"""Tolerance-based comparison for captured screenshots.

Byte-identical PNGs are not a safe contract across rendering environments
(driver, Mesa version and font rasterisation all shift a few pixels), so
visual regression is judged on two measures instead:

  mean absolute error   average per-channel difference, 0-255
  changed pixel ratio   fraction of pixels differing by more than --channel-tol

Usage:
    python tools/compare_screenshots.py baseline.png candidate.png
    python tools/compare_screenshots.py --dir-a docs/visual_refs --dir-b /tmp/run2

Exit code 0 when every comparison is within tolerance, 1 otherwise.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageChops

# Defaults chosen to pass on identical renders and on the same scene
# re-rendered by a different Mesa build, while still catching any real
# art change (which moves far more than a handful of pixels).
DEFAULT_MAE_TOL = 1.0
DEFAULT_CHANGED_TOL = 0.002
DEFAULT_CHANNEL_TOL = 8


def compare(path_a: Path, path_b: Path, channel_tol: int) -> tuple[float, float]:
    """Return (mean absolute error, changed pixel ratio) between two images."""
    image_a = Image.open(path_a).convert("RGB")
    image_b = Image.open(path_b).convert("RGB")
    if image_a.size != image_b.size:
        raise ValueError(
            f"size mismatch: {path_a.name} {image_a.size} vs {path_b.name} {image_b.size}"
        )

    diff = ImageChops.difference(image_a, image_b)
    pixels = image_a.size[0] * image_a.size[1]

    histograms = diff.histogram()
    total = 0
    for channel in range(3):
        band = histograms[channel * 256 : (channel + 1) * 256]
        total += sum(value * count for value, count in enumerate(band))
    mae = total / (pixels * 3)

    # A pixel counts as changed when any channel exceeds the tolerance.
    worst = diff.convert("L").point(lambda v: 255 if v > channel_tol else 0)
    changed = sum(count for value, count in enumerate(worst.histogram()) if value)
    return mae, changed / pixels


def report(path_a: Path, path_b: Path, args: argparse.Namespace) -> bool:
    try:
        mae, changed = compare(path_a, path_b, args.channel_tol)
    except (OSError, ValueError) as exc:
        print(f"FAIL {path_a.name}: {exc}")
        return False

    ok = mae <= args.mae_tol and changed <= args.changed_tol
    print(
        f"{'PASS' if ok else 'FAIL'} {path_a.name}: "
        f"mae={mae:.4f} (tol {args.mae_tol}) "
        f"changed={changed:.5f} (tol {args.changed_tol})"
    )
    return ok


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("images", nargs="*", type=Path, help="two image paths")
    parser.add_argument("--dir-a", type=Path, help="baseline directory")
    parser.add_argument("--dir-b", type=Path, help="candidate directory")
    parser.add_argument("--mae-tol", type=float, default=DEFAULT_MAE_TOL)
    parser.add_argument("--changed-tol", type=float, default=DEFAULT_CHANGED_TOL)
    parser.add_argument("--channel-tol", type=int, default=DEFAULT_CHANNEL_TOL)
    args = parser.parse_args()

    pairs: list[tuple[Path, Path]] = []
    if args.dir_a and args.dir_b:
        for baseline in sorted(args.dir_a.glob("*.png")):
            candidate = args.dir_b / baseline.name
            if candidate.exists():
                pairs.append((baseline, candidate))
        if not pairs:
            print(f"No comparable PNGs between {args.dir_a} and {args.dir_b}")
            return 1
    elif len(args.images) == 2:
        pairs.append((args.images[0], args.images[1]))
    else:
        parser.error("pass two image paths, or --dir-a and --dir-b")

    return 0 if all([report(a, b, args) for a, b in pairs]) else 1


if __name__ == "__main__":
    sys.exit(main())
