"""Give side-facing walk cycles a real near/far leg alternation.

The authored side rows are ``idle, contact A, idle, contact B``. In most of
the sheets both contact poses show the *near* leg leading, so the walk reads
as a limp. This tool rebuilds contact B's lower legs so the leading leg is the
*far* leg: it is re-lit in the sheet's own cool shadow tone and layered behind
the trailing (now near) leg. Silhouette, face, clothing, palette, equipment,
facing and foot anchor are kept; the trailing foot lifts into toe-off.
Nothing is flipped and the sprite is never translated.

It also clears torch/magic sparks that bled across a cell's bottom edge
from the row below. The pristine sheets are read from git (``BASELINE``) so
the tool is idempotent; run ``tools/build_overworld_metadata.py`` afterwards. Only facings that fail ``tools/audit_walk_cycles.py`` against the
baseline are rebuilt.

    python tools/rebuild_side_strides.py            # rewrite affected sheets
    python tools/rebuild_side_strides.py --sheet OUT.png   # also write review sheet
"""
from __future__ import annotations

import argparse
import io
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OVERWORLD = ROOT / "game/assets/overworld"
BASELINE = "908b9e1"  # last commit with the unmodified authored sheets
sys.path.insert(0, str(ROOT / "tools"))
import audit_walk_cycles  # noqa: E402

# Lower-leg band (shins and boots), as a fraction of body height above the
# foot line. It stays below skirts, aprons and coat hems.
LEG_BAND = 0.20
# Far-leg relight: darken and cool towards the sheets' outline colour.
FAR_SCALE = np.array([0.42, 0.44, 0.54])
FAR_TINT = np.array([10.0, 10.0, 22.0])
# Stride shortening per foot and trailing toe-off lift, as body-height
# fractions at the sole (they taper to zero at the knee).
STRIDE = 0.06
LIFT = 0.07


def _baseline(name: str) -> Image.Image:
    rel = f"game/assets/overworld/{name}.png"
    blob = subprocess.run(["git", "show", f"{BASELINE}:{rel}"], cwd=ROOT,
                          check=True, capture_output=True).stdout
    return Image.open(io.BytesIO(blob)).convert("RGB")


def _flagged_facings(registry: dict) -> list[tuple[str, str]]:
    out = []
    for line in audit_walk_cycles.audit():
        head = line.split(":", 1)[0]
        if "contact frames" in line:
            name, facing = head.split("/")
            out.append((name, facing))
    return out


def _rebuild(sheet: np.ndarray, frame: dict, facing: str, body_h: int) -> None:
    x, y, w, h = frame["rect"]
    tile = sheet[y:y + h, x:x + w].astype(float)
    body = ~audit_walk_cycles._is_bg(tile)
    background = tile[0, 0].copy()
    foot_y = int(frame["foot"][1])
    knee = max(0, foot_y - int(body_h * LEG_BAND))
    band = np.zeros_like(body)
    band[knee:foot_y + 1] = body[knee:foot_y + 1]
    if not band.any():
        return
    # The hip line is the median occupied column of the leg band; the
    # leading leg lies on the facing side of it.
    hip = int(round(float(np.median(np.nonzero(band)[1]))))
    ahead = -1 if facing == "west" else 1
    grid = np.arange(w)
    lead_cols = (grid - hip) * ahead > 0
    far = np.clip(tile * FAR_SCALE + FAR_TINT, 0, 255)
    out = tile.copy()
    stride = body_h * STRIDE
    lift = body_h * LIFT
    span = max(1, foot_y - knee)
    for r in range(knee, h):
        t = min(1.0, (r - knee) / span)
        # Shading ramps in from the knee so the hem never shows a seam.
        shade = min(1.0, (r - knee) / 10.0)
        s = int(round(stride * t))
        lifted = int(round(lift * t))
        row = np.repeat(background[None, :], w, 0)
        # Far (leading) leg: drawn first, relit, pulled in towards the hip.
        for c in np.where(lead_cols & body[r])[0]:
            nc = c - ahead * s
            if 0 <= nc < w:
                row[nc] = tile[r, c] * (1 - shade) + far[r, c] * shade
        # Near (trailing) leg: drawn on top, swung forward and peeling off
        # the ground in toe-off.
        src = r + lifted
        if src < h:
            for c in np.where(~lead_cols & body[src])[0]:
                nc = c + ahead * s
                if 0 <= nc < w:
                    row[nc] = tile[src, c]
        out[r] = row
    sheet[y:y + h, x:x + w] = np.clip(out, 0, 255).astype(np.uint8)


def _clear_bleed(sheet: np.ndarray, frame: dict) -> bool:
    """Remove sparks that bled in across the cell's bottom edge.

    A torch or spell in the row below can reach a few pixels into this cell.
    Those pixels form an occupied run detached from the body that touches
    the cell edge; they would float under the character in game.
    """
    x, y, w, h = frame["rect"]
    tile = sheet[y:y + h, x:x + w]
    occupied = np.where((~audit_walk_cycles._is_bg(tile.astype(float))).any(1))[0]
    body_end = int(frame["foot"][1]) - 1
    stray = occupied[occupied > body_end + 4]
    if stray.size == 0 or stray.max() < h - 1:
        return False
    tile[stray.min():] = tile[0, 0]
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sheet", help="write a before/after review image")
    args = parser.parse_args()
    registry = json.loads((OVERWORLD / "authored.json").read_text())
    # Restore baselines first so the audit judges the authored art.
    names = sorted(registry["entries"])
    subprocess.run(["git", "checkout", BASELINE, "--"]
                   + [f"game/assets/overworld/{n}.png" for n in names], cwd=ROOT, check=True)
    flagged = _flagged_facings(registry)
    review = []
    for name in names:
        entry = registry["entries"][name]
        sheet = np.array(_baseline(name))
        before = sheet.copy()
        changed = False
        for poses in entry["frames"].values():
            for pose in poses:
                changed |= _clear_bleed(sheet, pose)
        for n, facing in flagged:
            if n == name:
                _rebuild(sheet, entry["frames"][facing][3], facing, entry["native_body_height"])
                review.append((name, facing, before, sheet))
                changed = True
        if changed:
            Image.fromarray(sheet).save(OVERWORLD / f"{name}.png", optimize=True)
    if args.sheet and review:
        cells = []
        for name, facing, before, after in review:
            f = registry["entries"][name]["frames"][facing]
            crop = lambda a, i: Image.fromarray(a).crop(
                (f[i]["rect"][0], f[i]["rect"][1], f[i]["rect"][0] + f[i]["rect"][2],
                 f[i]["rect"][1] + f[i]["rect"][3])).resize((160, 160), Image.LANCZOS)
            cells.append([crop(before, 1), crop(before, 3), crop(after, 3)])
        out = Image.new("RGB", (480, 160 * len(cells)), (40, 40, 48))
        for r, row in enumerate(cells):
            for c, im in enumerate(row):
                out.paste(im, (c * 160, r * 160))
        out.save(args.sheet)
    print(f"Rebuilt {len(flagged)} side facings across {len({n for n, _ in flagged})} sheets.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
