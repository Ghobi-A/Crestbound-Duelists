"""Audit authored overworld walk cycles at display resolution.

Flags (1) side facings whose contact frames 1 and 3 barely differ once
downscaled to the in-game display height (legs don't visibly alternate),
and (2) >1 display-pixel body-height or foot-anchor jitter across a facing.

    python tools/audit_walk_cycles.py        # run from repo root
Exit code 1 if anything is flagged.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

GAME = Path(__file__).resolve().parent.parent / "game"
DIFF_THRESHOLD = 0.03   # min fraction of display pixels that must visibly change
COLOUR_DELTA = 40       # per-channel change counted as visible
JITTER_PX = 1.5   # frame 1 may be a shorter idle stance


def _is_bg(a):
    return (a[..., 0] > 200) & (a[..., 1] < 60) & (a[..., 2] > 200)  # magenta key


def audit():
    reg = json.loads((GAME / "assets/overworld/authored.json").read_text())
    h = reg["display_height"]
    flags = []
    for name, entry in reg["entries"].items():
        img = Image.open(GAME / entry["atlas"].replace("res://", "")).convert("RGB")
        s = h / entry["native_body_height"]
        for facing, frames in entry["frames"].items():
            smalls, heights, feet = [], [], []
            for f in frames:
                x, y, w, hh = f["rect"]
                a = np.array(img.crop((x, y, x + w, y + hh))).astype(float)
                body = ~_is_bg(a)
                rows = np.where(body.any(1))[0]
                heights.append((rows.max() - rows.min() + 1) * s)
                feet.append(f["foot"][1] * s)
                a[~body] = 0
                smalls.append(np.asarray(Image.fromarray(a.astype("uint8")).resize((h, h), Image.BOX), float))
            if facing in ("east", "west") and len(smalls) >= 4:
                # The authored row is idle, left contact, idle, right contact.
                # Comparing indices 0 and 2 measures idle variation instead.
                d = (np.abs(smalls[1] - smalls[3]).max(-1) > COLOUR_DELTA).mean()
                if d < DIFF_THRESHOLD:
                    flags.append(f"{name}/{facing}: contact frames 1 vs 3 differ in {d:.1%} of pixels")
            if max(heights) - min(heights) > JITTER_PX or max(feet) - min(feet) > JITTER_PX:
                flags.append(f"{name}/{facing}: >{JITTER_PX}px height/foot jitter")
    return flags


if __name__ == "__main__":
    found = audit()
    print("\n".join(found) if found else "No walk-cycle flags.")
    sys.exit(1 if found else 0)
