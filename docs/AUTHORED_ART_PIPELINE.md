# Authored art pipeline

How hand-made pixel art replaces generated art in Crestbound, and where
the line between the two sits.

## The rule

Procedural generation (`tools/generate_*.py`) is **support**, not the
production standard. It stays responsible for:

- tile variants and terrain autotiling
- background filler and props
- deterministic test fixtures and visual-regression baselines
- placeholders for assets nobody has authored yet

Every asset a player looks *at* rather than *past* is authored:

- playable characters (overworld and battle)
- major enemies and bosses
- character portraits
- signature environmental landmarks
- Crest awakening effects

## How an authored sheet overrides a generated one

Drop the PNG at the path the game already loads, and put a JSON sidecar
next to it describing its frame layout:

```
game/assets/characters/aren/warrior/battle.png     ← the sheet
game/assets/characters/aren/warrior/battle.json    ← its layout
```

```json
{
  "frame_width": 40,
  "frame_height": 48,
  "frame_count": 6,
  "anchor": [20, 44],
  "states": {
    "idle":   {"start": 0, "count": 1, "fps": 2,  "loop": true},
    "attack": {"start": 1, "count": 2, "fps": 10, "loop": false},
    "hit":    {"start": 3, "count": 1, "fps": 8,  "loop": false},
    "brace":  {"start": 4, "count": 1, "fps": 4,  "loop": false},
    "defeat": {"start": 5, "count": 1, "fps": 4,  "loop": false}
  }
}
```

`DuelistSprite` looks for the sidecar first and falls back to the global
`assets/battle/sheet_manifest.json` when there isn't one. That means:

- **Sprite size is per-character.** An authored 40x48 hero and a
  generated 24x32 placeholder coexist in the same battle with no code
  change.
- **`anchor` is where the character's feet meet the floor**, in frame
  pixels. Staging, contact shadows, target rings and damage popups are
  all positioned from it, so a taller sprite lands correctly without
  anyone editing offsets.
- **Frame counts and state names are the artist's choice.** A sheet with
  no `brace` state simply falls back to `idle` for that state.

Nothing about `sprite_key`, file paths or save data changes, so an
authored sheet is save-compatible by construction.

## Replacing this repository's authored art

The art committed here is authored as explicit pixel maps in
`tools/authored_art.py` — every pixel is placed by hand in a palette-indexed
table, not built from a parametric body template. That is a deliberate
step up from the old generator, but it is **not** a claim of
Aseprite-grade craft.

To replace any of it with externally produced art:

1. Export the sheet as a horizontal strip of equal-sized frames.
2. Write the sidecar JSON above (or copy the existing one and edit the
   numbers).
3. Overwrite the PNG. Delete nothing else.

No GDScript changes, no manifest edits, no gameplay changes. If the
sidecar and the PNG disagree about frame size, `tests/test_sprite_assets.py`
fails rather than the game rendering a sliver of the wrong frame.

## Portraits

Portraits live beside the sheets:

```
game/assets/portraits/<sprite_key>/<expression>.png
```

Expressions: `neutral`, `determined`, `injured`, `surprised`, `intense`.
`neutral` is required; the rest are optional and fall back to it, so a
character with one portrait still works everywhere a portrait is shown.

All portraits share one crop, eye line and light direction — see
`docs/UI_STYLE_GUIDE.md` for the framing rules.
