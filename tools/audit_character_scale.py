"""Audit overworld character scale against Kai and record body heights.

For every overworld entry in the three runtime manifests this takes the
down-facing standing frame, applies the entry's colour key (or alpha),
measures the opaque body from the top of the head to the foot anchor, and
reports the on-screen height at the manifest's display height next to Kai's.
It also reports width-to-height and head-to-body ratios, since re-scaling
cannot fix a sprite drawn with different proportions.

    python tools/audit_character_scale.py          # report only
    python tools/audit_character_scale.py --write  # store body_height fields
    python tools/audit_character_scale.py --markdown report.md

Beyond the front-facing measurement it also checks motion: for every sheet
with more than one facing, the body height in each facing and walk frame
(in display px), so a sprite that grows or shrinks while turning or walking
is reported. Malformed manifest data raises ManifestError naming the entry.

The output is deterministic: the v2 sheets are rebuilt in memory from
overworld_v2_art, and entries are visited in sorted order.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game"
V2_PATH = GAME / "assets/rework/overworld_v2.json"
CHARACTERS_PATH = GAME / "assets/rework/characters.json"
AUTHORED_PATH = GAME / "assets/overworld/authored.json"
BASELINE_PATH = ROOT / "tools/character_proportions_baseline.json"
REFERENCE = ("authored", "kai_warrior")  # what the player's "aren/warrior" resolves to
STRIP = 0.12      # half-width of the central column, as a fraction of frame width
MAX_ROW_GAP = 2   # detached sparks/props above the head are not the head
RATIO_TOLERANCE = 0.25  # relative deviation from Kai that counts as an outlier

# Display px a body may vary across facings / walk frames before it reads
# as growing or shrinking. Kai's own approved art varies by ~0.8 px.
MOTION_TOLERANCE = 1.5
FACINGS = ("down", "up", "east", "west")

sys.path.insert(0, str(Path(__file__).resolve().parent))


class ManifestError(ValueError):
    """Overworld sprite metadata the audit (and the runtime) cannot use."""


def _require(condition: bool, where: str, message: str) -> None:
    if not condition:
        raise ManifestError(f"{where}: {message}")


def validate(v2: dict, characters: dict, authored: dict) -> None:
    """Fail clearly on data the runtime scale helper would mis-render."""
    _require(v2.get("display_height", 0) > 0, "overworld_v2.json", "display_height must be positive")
    for key, entry in v2.get("entries", {}).items():
        where = f"overworld_v2.json entries.{key}"
        _require(entry.get("atlas") in v2.get("atlases", {}), where, f"unknown atlas {entry.get('atlas')!r}")
        _require(len(entry.get("anchor", [])) == 2, where, "anchor must be [x, y]")
        if "body_height" in entry:
            _require(0 < entry["body_height"] <= v2["frame_size"][1], where, "body_height outside the frame")
    _require(characters.get("overworld_display_height", 0) > 0, "characters.json", "overworld_display_height must be positive")
    for key, record in characters.get("characters", {}).items():
        world = record.get("overworld")
        if world is None:
            continue
        where = f"characters.json characters.{key}.overworld"
        for field in ("atlas", "frame_size", "foot_anchor"):
            _require(field in world, where, f"missing {field}")
        _require(len(world["frame_size"]) == 2 and min(world["frame_size"]) > 0, where, "frame_size must be two positive ints")
        if "body_height" in world:
            _require(0 < world["body_height"] <= world["frame_size"][1], where, "body_height outside the frame")
    _require(authored.get("display_height", 0) > 0, "authored.json", "display_height must be positive")
    for key, entry in authored.get("entries", {}).items():
        where = f"authored.json entries.{key}"
        _require(set(FACINGS) <= set(entry.get("frames", {})), where, "needs down, up, east and west frames")
        for facing in FACINGS:
            for index, pose in enumerate(entry["frames"][facing]):
                rect, foot = pose.get("rect", []), pose.get("foot", [])
                _require(len(rect) == 4 and rect[2] > 0 and rect[3] > 0, f"{where}.{facing}[{index}]", "rect must be [x, y, w, h]")
                _require(len(foot) == 2 and 0 < foot[1] <= rect[3], f"{where}.{facing}[{index}]", "foot outside its rect")
        if "body_height" in entry:
            _require(entry["body_height"] > 0, where, "body_height must be positive")
    for alias, target in authored.get("aliases", {}).items():
        _require(target in authored.get("entries", {}), f"authored.json aliases.{alias}", f"unknown entry {target!r}")


def body_top(mask: np.ndarray, foot_y: float) -> int:
    """Top body row: the first row with a real body's width of opaque
    pixels, so a raised spear, torch or spark is not counted as the head."""
    counts = mask[: max(1, round(foot_y))].sum(axis=1)
    rows = np.flatnonzero(counts >= max(3, mask.shape[1] * 0.04))
    if rows.size == 0:
        raise ValueError("empty frame")
    return int(rows[0])


def authored_motion(entry: dict, display: float) -> dict:
    """Display-px body heights for every facing (standing) and walk frame."""
    atlas = Image.open(_res(entry["atlas"]))
    scale = display / entry["body_height"]
    standing, walking = [], []
    for facing in FACINGS:
        for index, pose in enumerate(entry["frames"][facing]):
            x, y, w, h = pose["rect"]
            mask = opaque_mask(atlas.crop((x, y, x + w, y + h)), "magenta")
            height = (pose["foot"][1] - body_top(mask, pose["foot"][1])) * scale
            (standing if index == 0 else walking).append(height)
    return {"turn": max(standing) - min(standing), "walk": max(standing + walking) - min(standing + walking)}


def strip_motion(world: dict, colour_key: str, display: float) -> dict:
    """Trainer strips: one standing frame per facing."""
    sheet = Image.open(_res(world["atlas"]))
    fw, fh = world["frame_size"]
    scale = display / world["body_height"]
    heights = []
    for index in range(min(len(FACINGS), sheet.width // fw)):
        mask = opaque_mask(sheet.crop((index * fw, world["row"], (index + 1) * fw, world["row"] + fh)), colour_key)
        heights.append((world["foot_anchor"][1] - body_top(mask, world["foot_anchor"][1])) * scale)
    return {"turn": max(heights) - min(heights), "walk": max(heights) - min(heights)}


def _res(path: str) -> Path:
    return GAME / path.removeprefix("res://")


def opaque_mask(image: Image.Image, colour_key: str) -> np.ndarray:
    """Mirror colour_key.gdshader: a texel is opaque when its key is below 0.5."""
    rgba = np.asarray(image.convert("RGBA")).astype(np.int16)
    r, g, b, a = rgba[..., 0], rgba[..., 1], rgba[..., 2], rgba[..., 3]
    if colour_key == "magenta":
        keyed = (np.minimum(r, b) - g) >= 0.625 * 255
    elif colour_key == "green":
        keyed = (g - np.maximum(r, b)) >= 0.315 * 255
    else:
        keyed = np.zeros_like(a, dtype=bool)
    return (a >= 128) & ~keyed


def measure(mask: np.ndarray, foot: tuple[float, float]) -> dict:
    """Body from the head (top of the central column) to the foot anchor."""
    height, width = mask.shape
    foot_x, foot_y = foot
    half = max(2.0, width * STRIP)
    x0, x1 = max(0, int(foot_x - half)), min(width, int(np.ceil(foot_x + half)))
    rows = [y for y in range(min(height, round(foot_y))) if mask[y, x0:x1].any()]
    if not rows:
        raise ValueError("empty standing frame")
    # Walk up from the feet through the contiguous body; raised spears or
    # sparks separated by a gap do not count as the top of the head.
    top = rows[-1]
    for y in reversed(rows):
        if top - y > MAX_ROW_GAP:
            break
        top = y
    body_height = round(foot_y) - top
    widths = np.array([int(mask[y].sum()) for y in range(top, top + body_height)])
    columns = np.flatnonzero(mask[top : top + body_height].any(axis=0))
    body_width = int(columns[-1] - columns[0] + 1)
    # The neck is the narrowest row between the widest head row (top 30%)
    # and 45% of the body; hats and hair above the head's widest row are ignored.
    head = int(np.argmax(widths[: max(1, int(body_height * 0.30))]))
    hi = max(int(body_height * 0.45), head + 1)
    neck = head + int(np.argmin(widths[head:hi]))
    return {"body_height": body_height, "width": body_width,
            "width_ratio": body_width / body_height, "head_ratio": neck / body_height}


def _v2_sheets(registry: dict, workdir: Path) -> dict[str, Image.Image]:
    from overworld_v2_art import CAST, KAI, build_sheet

    sheets = {}
    for key, specs in (("kai", KAI), ("cast", CAST)):
        target = workdir / f"{key}.png"
        build_sheet(specs, target)
        sheets[key] = Image.open(target).copy()
    return sheets


def v2_frames(registry: dict, workdir: Path):
    sheets = _v2_sheets(registry, workdir)
    width, height = registry["frame_size"]
    down = int(registry["directions"]["down"])
    for key in sorted(registry["entries"]):
        entry = registry["entries"][key]
        row = int(entry["row"]) * height
        frame = sheets[entry["atlas"]].crop((down * width, row, (down + 1) * width, row + height))
        yield key, entry, frame, "alpha", tuple(entry["anchor"]), registry["display_height"]


def character_frames(registry: dict):
    width, height = registry["overworld_frame_size"]
    down = int(registry["overworld_directions"]["down"])
    atlas = Image.open(_res(registry["overworld_atlas"]))
    for key in sorted(registry["overworld_rows"]):
        row = int(registry["overworld_rows"][key])
        frame = atlas.crop((down * width, row, (down + 1) * width, row + height))
        anchor = tuple(registry["overworld_anchors"][key])
        yield ("row", key), None, frame, registry["colour_key"], anchor, registry["overworld_display_height"]
    for key in sorted(registry["characters"]):
        record = registry["characters"][key]
        world = record.get("overworld")
        if world is None:
            continue
        fw, fh = world["frame_size"]
        sheet = Image.open(_res(world["atlas"]))
        frame = sheet.crop((down * fw, world["row"], (down + 1) * fw, world["row"] + fh))
        colour_key = record.get("colour_key", registry["colour_key"])
        yield ("record", key), world, frame, colour_key, tuple(world["foot_anchor"]), registry["overworld_display_height"]


def authored_frames(registry: dict):
    for key in sorted(registry["entries"]):
        entry = registry["entries"][key]
        pose = entry["frames"]["down"][0]
        x, y, w, h = pose["rect"]
        frame = Image.open(_res(entry["atlas"])).crop((x, y, x + w, y + h))
        yield key, entry, frame, "magenta", tuple(pose["foot"]), registry["display_height"]


def audit() -> list[dict]:
    rows = []
    v2 = json.loads(V2_PATH.read_text())
    characters = json.loads(CHARACTERS_PATH.read_text())
    authored = json.loads(AUTHORED_PATH.read_text())
    validate(v2, characters, authored)
    with tempfile.TemporaryDirectory() as tmp:
        sources = (("v2", v2_frames(v2, Path(tmp))), ("characters", character_frames(characters)),
                   ("authored", authored_frames(authored)))
        for manifest, frames in sources:
            for key, entry, frame, colour_key, anchor, display in frames:
                name = key if isinstance(key, str) else f"{key[0]}:{key[1]}"
                row = measure(opaque_mask(frame, colour_key), anchor)
                # The pre-normalisation runtime divided by the anchor height
                # (or the authored median body height) instead of the body.
                legacy = entry["native_body_height"] if manifest == "authored" else anchor[1]
                motion = None
                if manifest == "authored" and "body_height" in entry:
                    motion = authored_motion(entry, display)
                elif manifest == "characters" and entry is not None and "body_height" in entry and \
                        Image.open(_res(entry["atlas"])).width >= 4 * entry["frame_size"][0]:
                    motion = strip_motion(entry, colour_key, display)
                rows.append({"manifest": manifest, "key": key, "name": name,
                             "display_height": display, "frame": frame.size,
                             "legacy_height": row["body_height"] * display / legacy, "motion": motion,
                             "padding": 1.0 - row["body_height"] / frame.size[1], **row})
    # Which entries the runtime actually draws: authored aliases win, then v2,
    # then the character records (OverworldSprite.attach). Shadowed entries
    # are kept for reference but are never rendered.
    aliases = set(authored.get("aliases", {}))
    for row in rows:
        keys = {row["key"]} if isinstance(row["key"], str) else {row["key"][1]}
        if row["manifest"] == "characters" and row["key"][0] == "record":
            keys |= set(characters["characters"][row["key"][1]].get("aliases", []))
        if row["manifest"] == "characters" and row["key"][0] == "row":
            keys |= {row["key"][1]}
        shadowed_by_v2 = row["manifest"] == "characters" and bool(keys & set(v2.get("entries", {})))
        row["shadowed"] = row["manifest"] != "authored" and (bool(keys & aliases) or shadowed_by_v2)
    reference = next(r for r in rows if (r["manifest"], r["key"]) == REFERENCE)
    for row in rows:
        row["scaled_height"] = row["body_height"] * row["display_height"] / row["body_height"]
        for ratio in ("width_ratio", "head_ratio"):
            row[ratio + "_outlier"] = abs(row[ratio] / reference[ratio] - 1.0) > RATIO_TOLERANCE
        row["motion_outlier"] = bool(row["motion"]) and max(row["motion"].values()) > MOTION_TOLERANCE and not row["shadowed"]
    rows.append({"reference": reference})
    return rows


def battle_heights(characters: dict) -> dict:
    """Combat sprites: body height (head to foot anchor) in each record's
    battle rect. The battle stage scales by this, like the overworld, so
    sheets with extra headroom (the route trainers) are not drawn small."""
    heights = {}
    for key in sorted(characters["characters"]):
        record = characters["characters"][key]
        x, y, w, h = record["battle_rect"]
        atlas = Image.open(_res(record.get("atlas", characters["atlas"])))
        mask = opaque_mask(atlas.crop((x, y, x + w, y + h)), record.get("colour_key", characters["colour_key"]))
        foot_y = record["foot_anchor"][1]
        heights[key] = foot_y - body_top(mask, foot_y)
    return heights


# Combat target height (logical px) for the visible body: what Kai, the
# reference, already rendered at (40 px foot anchor, ~38.7 px body).
BATTLE_BODY_DISPLAY = 39


def write(rows: list[dict]) -> None:
    measured = [r for r in rows if "manifest" in r]
    # v2 keeps its compact one-line entries, so patch those lines in place.
    text = V2_PATH.read_text()
    for row in (r for r in measured if r["manifest"] == "v2"):
        key = re.escape(row["key"])
        pattern = re.compile(rf'^(    "{key}": \{{.*?)(, "body_height": \d+)?\}}', re.MULTILINE)
        text, count = pattern.subn(lambda m, h=row["body_height"]: f'{m.group(1)}, "body_height": {h}}}', text)
        if count != 1:
            raise RuntimeError(f"v2 entry not found: {row['key']}")
    V2_PATH.write_text(text)

    characters = json.loads(CHARACTERS_PATH.read_text())
    heights = {}
    for row in (r for r in measured if r["manifest"] == "characters"):
        kind, key = row["key"]
        if kind == "row":
            heights[key] = row["body_height"]
        else:
            characters["characters"][key]["overworld"]["body_height"] = row["body_height"]
    characters["overworld_body_heights"] = dict(sorted(heights.items()))
    characters["battle_body_display"] = BATTLE_BODY_DISPLAY
    for key, height in battle_heights(characters).items():
        characters["characters"][key]["battle_body_height"] = height
    CHARACTERS_PATH.write_text(json.dumps(characters, indent=2) + "\n")

    authored = json.loads(AUTHORED_PATH.read_text())
    for row in (r for r in measured if r["manifest"] == "authored"):
        authored["entries"][row["key"]]["body_height"] = row["body_height"]
    AUTHORED_PATH.write_text(json.dumps(authored, indent=2) + "\n")


def _flags(row: dict) -> list[str]:
    flags = [n for n in ("width_ratio", "head_ratio", "motion") if row[n + "_outlier"]]
    return flags + (["shadowed"] if row["shadowed"] else [])


def proportions(rows: list[dict]) -> dict:
    """Identity guard: proportions of every runtime-drawn sprite."""
    return {row["name"]: {"width_ratio": round(row["width_ratio"], 3), "head_ratio": round(row["head_ratio"], 3)}
            for row in rows[:-1] if not row["shadowed"]}


def report(rows: list[dict]) -> None:
    reference = rows[-1]["reference"]
    print(f"Reference {reference['manifest']}:{reference['name']}: body {reference['body_height']} px "
          f"-> {reference['display_height']} px on screen, w/h {reference['width_ratio']:.2f}, "
          f"head/body {reference['head_ratio']:.2f}")
    print(f"{'manifest':<11}{'entry':<28}{'frame':>10}{'body':>6}{'before':>8}{'after':>7}{'w/h':>7}{'head':>7}"
          f"{'turn':>6}{'walk':>6}  flags")
    for row in rows[:-1]:
        frame = "x".join(map(str, row["frame"]))
        motion = row["motion"] or {}
        turn = f"{motion['turn']:6.1f}" if motion else "     -"
        walk = f"{motion['walk']:6.1f}" if motion else "     -"
        print(f"{row['manifest']:<11}{row['name']:<28}{frame:>10}{row['body_height']:>6}"
              f"{row['legacy_height']:>8.1f}{row['scaled_height']:>7.1f}{row['width_ratio']:>7.2f}{row['head_ratio']:>7.2f}"
              f"{turn}{walk}  {' '.join(_flags(row))}")


def markdown(rows: list[dict]) -> str:
    """The same measurements as a Markdown table (the audit's evidence)."""
    lines = ["| Manifest | Entry | Source body px | Before (display px) | After | w/h | Head/body | Turn drift | Walk drift | Flags |",
             "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |"]
    for row in rows[:-1]:
        motion = row["motion"] or {}
        lines.append(f"| {row['manifest']} | `{row['name']}` | {row['body_height']} | {row['legacy_height']:.1f} | "
                     f"{row['scaled_height']:.1f} | {row['width_ratio']:.2f} | {row['head_ratio']:.2f} | "
                     f"{motion.get('turn', float('nan')):.1f} | {motion.get('walk', float('nan')):.1f} | {', '.join(_flags(row))} |")
    return "\n".join(lines).replace("| nan |", "| - |") + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--write", action="store_true", help="store body_height in each manifest")
    parser.add_argument("--markdown", type=Path, help="also write the table as Markdown")
    parser.add_argument("--baseline", action="store_true", help="record the current proportions as approved")
    args = parser.parse_args()
    rows = audit()
    report(rows)
    if args.markdown:
        args.markdown.write_text(markdown(rows))
    if args.baseline:
        BASELINE_PATH.write_text(json.dumps(proportions(rows), indent=2, sort_keys=True) + "\n")
    if args.write:
        write(rows)


if __name__ == "__main__":
    main()
