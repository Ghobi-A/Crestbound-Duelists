"""Static sanity checks for the Godot project (no Godot binary available)."""
import json
import re
import sys
from pathlib import Path

GAME = Path(__file__).resolve().parent.parent / "game"
errors = []

# 1. Every res:// reference must point at an existing file.
res_ref = re.compile(r'res://[A-Za-z0-9_\-./]+')
for path in list(GAME.rglob("*.gd")) + list(GAME.rglob("*.tscn")) + [GAME / "project.godot"]:
    text = path.read_text(encoding="utf-8")
    for line in text.splitlines():
        for ref in res_ref.findall(line):
            target = ref.replace("res://", "")
            if "%s" in ref or not Path(target).suffix:
                continue
            # Optional authored replacements are deliberately absent until an
            # artist supplies them. Call sites must opt in explicitly and guard
            # them with ResourceLoader.exists rather than weakening all refs.
            if "# optional-authored-asset" in line and "ResourceLoader.exists" not in text:
                errors.append(f"{path.name}: unguarded optional resource {ref}")
                continue
            if "# optional-authored-asset" in line:
                continue
            if not (GAME / target).exists():
                errors.append(f"{path.name}: missing resource {ref}")

# 2. JSON files must parse.
for path in GAME.rglob("*.json"):
    try:
        json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        errors.append(f"{path}: invalid JSON: {exc}")

# 3. Bracket balance per .gd file (strings and comments stripped).
def strip_strings_comments(line: str) -> str:
    out, in_str, quote, i = [], False, "", 0
    while i < len(line):
        ch = line[i]
        if in_str:
            if ch == quote and line[i-1] != "\\":
                in_str = False
        else:
            if ch == "#":
                break
            if ch in "\"'":
                in_str, quote = True, ch
            else:
                out.append(ch)
        i += 1
    return "".join(out)

for path in GAME.rglob("*.gd"):
    counts = {"(": 0, ")": 0, "[": 0, "]": 0, "{": 0, "}": 0}
    for line in path.read_text(encoding="utf-8").splitlines():
        for ch in strip_strings_comments(line):
            if ch in counts:
                counts[ch] += 1
    for open_ch, close_ch in [("(", ")"), ("[", "]"), ("{", "}")]:
        if counts[open_ch] != counts[close_ch]:
            errors.append(f"{path.name}: unbalanced {open_ch}{close_ch} "
                          f"({counts[open_ch]} vs {counts[close_ch]})")

# 4. Mixed indentation check (GDScript requires consistent tabs).
for path in GAME.rglob("*.gd"):
    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if line.startswith(" ") and line.strip():
            errors.append(f"{path.name}:{n}: space indentation (GDScript files use tabs)")
            break

# 5. Dialogue keys used in scripts must exist in the dialogue files.
dialogue = {}
for path in (GAME / "data" / "dialogue").glob("*.json"):
    dialogue.update(json.loads(path.read_text(encoding="utf-8")))
key_use = re.compile(r'(?:dialogue\.play|_play_dialogue|dialogue\.has_key)\("([a-z_]+)"\)')
for path in GAME.rglob("*.gd"):
    for key in key_use.findall(path.read_text(encoding="utf-8")):
        if key not in dialogue:
            errors.append(f"{path.name}: unknown dialogue key '{key}'")

# 6. Dialogue entries have the required shape.
for key, entries in dialogue.items():
    if not isinstance(entries, list) or not entries:
        errors.append(f"dialogue '{key}': must be a non-empty list")
        continue
    for entry in entries:
        if "lines" not in entry or not entry["lines"]:
            errors.append(f"dialogue '{key}': entry missing lines")

# 7. Exported data the client expects must be present in game/data.
for dataset in ["classes", "moves", "combat_config", "crests", "entities",
                "terrain", "battle_objectives"]:
    if not (GAME / "data" / f"{dataset}.json").exists():
        errors.append(f"game/data/{dataset}.json missing — run export_game_data.py")

if errors:
    print("VALIDATION FAILED:")
    for error in errors:
        print(" -", error)
    sys.exit(1)
print("All static Godot project checks passed.")
gd_files = list(GAME.rglob('*.gd'))
print(f"Checked {len(gd_files)} scripts, "
      f"{len(list(GAME.rglob('*.tscn')))} scenes, "
      f"{len(list(GAME.rglob('*.json')))} JSON files.")
