"""Materialize reviewed PixelLab side walks into the existing runtime atlases.

Keep standing pose zero and other facings intact. Source strips are RGBA;
production atlases retain their existing magenta-key contract.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "tools/walk_sources"
FACINGS = ("down", "up", "east", "west")


def apply_walks():
    for source in sorted(SOURCES.glob("*.png")):
        name, facing = source.stem.rsplit("-", 1)
        target = ROOT / "game/assets/overworld" / (name + ".png")
        atlas = Image.open(target).convert("RGB")
        strip = Image.open(source).convert("RGBA")
        assert strip.size == (768, 192), source
        row = FACINGS.index(facing)
        y0, y1 = round(row * atlas.height / 4), round((row + 1) * atlas.height / 4)
        # Leave the original standing pose in column zero. The four generated
        # frames provide contact / passing / contact poses for columns 1..3.
        for column, frame in ((1, 0), (2, 1), (3, 3)):
            x0, x1 = round(column * atlas.width / 4), round((column + 1) * atlas.width / 4)
            pose = strip.crop((frame * 192, 0, (frame + 1) * 192, 192))
            pose = pose.resize((x1 - x0, y1 - y0), Image.Resampling.LANCZOS)
            cell = Image.new("RGB", pose.size, (255, 0, 255))
            cell.paste(pose, (0, 0), pose)
            atlas.paste(cell, (x0, y0))
        temporary = target.with_suffix(".pending")
        atlas.save(temporary, format="PNG")
        with Image.open(temporary) as checked:
            checked.load()
        temporary.replace(target)
        print("applied", source.stem)


if __name__ == "__main__":
    apply_walks()
