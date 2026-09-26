"""Inspect authored 4x4 sheets and write frame metadata; never modify art pixels."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DIRECTORY = ROOT / "game/assets/overworld"
ALIASES = {
    "kai_neutral": ["aren/neutral", "kai_neutral"],
    "almyra": ["elara", "almyra"],
    "joey": ["townsfolk/farmboy", "farmboy", "joey"],
    "lena": ["townsfolk/herbalist_woman", "herbalist_woman", "lena"],
    "silas": ["townsfolk/village_elder", "village_elder", "silas"],
    "gell": ["townsfolk/farmhand_capped", "farmhand_capped", "gell"],
    "danfor": ["townsfolk/guard_sword", "guard_sword", "danfor"],
    "liora": ["mira", "liora"],
    "orrin": ["townsfolk/guard_spear", "guard_spear", "orrin"],
    "senna": ["townsfolk/elder_woman", "elder_woman", "senna"],
    "stranger": ["townsfolk/hooded_stranger", "hooded_stranger", "stranger"],
    "ferris": ["townsfolk/torch_bearer", "torch_bearer", "ferris"],
}
for class_name in ("warrior", "guardian", "mage", "sorcerer", "assassin"):
    ALIASES["kai_" + class_name] = ["aren/" + class_name, "kai_" + class_name]

def inspect(path):
    image = Image.open(path).convert("RGB")
    width, height = image.size
    pixels = image.load()
    frames = {}
    heights = []
    for row, facing in enumerate(("down", "up", "east", "west")):
        poses = []
        for column in range(4):
            x0, x1 = round(column * width / 4), round((column + 1) * width / 4)
            y0, y1 = round(row * height / 4), round((row + 1) * height / 4)
            occupied = []
            for y in range(y0, y1):
                for x in range(x0, x1):
                    r, g, b = pixels[x, y]
                    if min(r, b) - g < 110:
                        occupied.append((x, y))
            if not occupied:
                raise ValueError(f"Empty pose: {path.name} {facing} {column}")
            # Ignore raised spears, torches and peripheral magic when measuring
            # body scale. They must not make their owner smaller than Kai.
            centre = (x0 + x1) / 2
            half_strip = (x1 - x0) * 0.08
            body_pixels = [(x, y) for x, y in occupied if abs(x - centre) < half_strip]
            top = min(y for _, y in body_pixels)
            bottom = max(y for _, y in occupied) + 1
            heights.append(bottom - top)
            poses.append({"rect": [x0, y0, x1 - x0, y1 - y0],
                          "foot": [(x1 - x0) / 2, bottom - y0]})
        frames[facing] = poses
    return {"atlas": "res://assets/overworld/" + path.name,
            "native_body_height": sorted(heights)[len(heights) // 2],
            "frames": frames, "animation_review": "pending"}

def main():
    entries = {path.stem: inspect(path) for path in sorted(DIRECTORY.glob("*.png"))}
    aliases = {alias: key for key in entries for alias in ALIASES.get(key, [key])}
    manifest = {"schema_version": 1, "display_height": 24, "entries": entries, "aliases": aliases}
    (DIRECTORY / "authored.json").write_text(json.dumps(manifest, indent=2) + "\n")

if __name__ == "__main__":
    main()
