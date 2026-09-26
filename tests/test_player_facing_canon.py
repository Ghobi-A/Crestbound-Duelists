"""Guard: player-facing runtime text must not name retired characters.

The story rework (docs/rework/STORY_SYNOPSIS.md) replaced the original cast.
Legacy lore/location data (e.g. Veyrhold) is migrated separately; this test
covers only text a player can see today: GDScript UI strings and dialogue.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RETIRED = ("Aren", "Elara", "Serin", "Cassian Orre")
PATTERN = re.compile(r"\b(" + "|".join(map(re.escape, RETIRED)) + r")\b")


def _hits(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    return [f"{path.relative_to(ROOT)}: {m.group(0)}" for m in PATTERN.finditer(text)]


def test_scripts_do_not_name_retired_characters():
    hits = [h for p in (ROOT / "game" / "scripts").rglob("*.gd") for h in _hits(p)]
    assert not hits, "Retired character names in GDScript:\n" + "\n".join(hits)


def test_dialogue_does_not_name_retired_characters():
    hits = [h for p in (ROOT / "game" / "data" / "dialogue").glob("*.json") for h in _hits(p)]
    assert not hits, "Retired character names in dialogue:\n" + "\n".join(hits)


def test_boot_objective_names_a_greymere_speaker():
    boot = (ROOT / "game" / "scripts" / "ui" / "boot_screen.gd").read_text(encoding="utf-8")
    objective = re.search(r"Objective: speak to ([^,]+),", boot).group(1)
    dialogue = json.loads((ROOT / "game" / "data" / "dialogue" / "greymere.json").read_text(encoding="utf-8"))
    speakers = set(re.findall(r'"speaker":\s*"([^"]+)"', json.dumps(dialogue)))
    assert objective in speakers, f"Boot objective names {objective!r}, not a Greymere speaker"
