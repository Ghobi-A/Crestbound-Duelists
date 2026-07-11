# Godot Setup

## Engine version

**Godot 4.2 or newer** (standard build; no C#/Mono required).
Download from https://godotengine.org/download.

## Opening and running

1. Ensure exported data exists (committed by default; regenerate with
   `python export_game_data.py` from the repository root).
2. Open Godot → **Import** → select `game/project.godot`.
3. Press **F5** (Run Project). The main scene is
   `scenes/boot/boot.tscn`.

Flow: title → class selection → Greymere (move with WASD/arrows,
interact with Z/Enter/Space, cancel with X/Esc) → the Hollow Court
arch at the north wall → 3v3 tactical battle → post-battle scene →
back to Greymere.

If game data is missing or invalid the boot screen reports the exact
file and the command to fix it instead of crashing.

## Pixel-art configuration (already set in project.godot)

| Setting | Value | Why |
|---------|-------|-----|
| Viewport | **320x180** | Low-res 16:9 canvas; 16x16 tiles → 20x11.25 visible tiles |
| Window override | 1280x720 | 4x integer scale on launch |
| Stretch mode | `canvas_items` | Crisp scaling of the low-res canvas |
| Stretch scale mode | `integer` | No fractional scaling, no shimmer |
| Default texture filter | Nearest | No smoothing/blur on pixels |
| 2D transform/vertex snapping | On | No sub-pixel wobble |
| Renderer | GL Compatibility | Lightweight, runs anywhere |

Conventions: 16x16 tiles, ~16x24 character silhouettes, UI aligned to
whole pixels, one palette (`assets/placeholders/palette.gd`) until
real sprites replace programmer art.

## Project layout

```text
game/
  project.godot
  data/                 # exported JSON (from Python) + dialogue/
  scenes/
    boot/  overworld/  battle/  ui/
  scripts/
    core/  data/  overworld/  battle/  ui/  save/
  assets/
    placeholders/       # programmer-art palette + rules
    sprites/ tiles/ ui/ vfx/ audio/   # reserved for real assets
```

## Validation without an editor

`python tools/validate_godot_project.py` performs static checks
(resource paths, JSON, dialogue keys, indentation, bracket balance).
It is not a substitute for opening the project in the editor, which
performs full GDScript parsing.

## Input map

| Action | Keys |
|--------|------|
| move_up/down/left/right | WASD + arrow keys |
| interact | Z, Enter, Space |
| cancel | X, Esc |
