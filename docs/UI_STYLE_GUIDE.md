# Crestbound Duelists — interface style guide

The rules every player-facing screen follows, so boot, party setup,
overworld dialogue and battle read as one designed system rather than
four independently-styled screens.

Everything here is enforced in code by two files:

- `game/scripts/ui/ui_style.gd` (`UiStyle`) — static draw helpers for
  screens that render their own chrome in `_draw()`
- `game/scripts/ui/ui_panel.gd` (`UiPanel`) — a panel *node* for screens
  assembled from child nodes

Both render through the same helpers, so the two paths cannot drift.
`UiDecor` (`game/scripts/ui/ui_decor.gd`) is the node form of the
ornaments (rules, selection frames, portrait wells, fading plates).

## Visual language (2026 rework)

The interface follows the "moonlit ledger" direction of the Hollow Court
art-direction reference: deep navy glass panels, gold hairline frames
with small corner brackets and star-cross ornaments, and letter-spaced
capitals for titles.

- **Type.** IBM Plex Mono (SIL OFL, `game/assets/ui/fonts/OFL.txt`) in
  Regular, Medium and SemiBold, imported as MSDF so it stays sharp at
  every integer output scale. Body copy is 5 logical px (10 physical px
  at 640x360, 20-30 at 720p-1080p); `UiStyle.MIN_FONT_SIZE` is the floor
  and every helper clamps to it. Spaced capitals use fractional
  `tracking` in `UiStyle.draw_text`, not whole-pixel font spacing.
- **Lines.** Hairlines are `UiStyle.HAIR` (0.5 logical px, ~2-3
  physical px). Project-wide vertex snapping is off so fractional glyph
  and hairline geometry is not rounded to the logical grid; transform
  snapping stays on for sprites.
- **Battle screen.** Title bar (objective, encounter title between
  ornaments, round), a 136px battlefield, a 36px command deck with one
  portrait card per active Duelist (HP and RS values with gauges, one
  status tag under the portrait), a framed command list with vector
  glyphs and a pointer, a description panel, and a footer carrying the
  sub-phase, controls and battlefield effect.
- **Other screens.** Title, party setup, exploration HUD, pause menu,
  dialogue, onboarding, round plan and results use the same panels,
  selection frame, portrait wells and type scale.

## Accent grammar

Accent colour carries meaning. It is not decoration, and it is not
chosen per screen — it is chosen per *role*.

| Role | Colour | Means | Used by |
| --- | --- | --- | --- |
| `UiStyle.COMMAND` | `CREST_GOLD` | The player's own agency | Action menu, acting unit's ring, dialogue, onboarding, boot title, party roster |
| `UiStyle.TARGET` | `SPECTRAL_VIOLET` | What an action affects | Target info panel, round preview, target ring, encounter detail |
| `UiStyle.NEUTRAL` | `MOON_SLATE_LIGHT` | Passive framing that should recede | Boot menu body |

A screen that is asking the player to *choose* is gold. A screen or
panel that is showing them *what their choice will hit* is violet.

## Palette

Defined in `game/assets/placeholders/palette.gd`. The slate and accent
values are the same hex codes `tools/generate_sprites.py` uses to draw
the Hollow Court background and dais, so interface and battlefield are
literally one palette.

| Token | Hex | Use |
| --- | --- | --- |
| `MOON_SLATE` | `2a2836` | Panel fill |
| `MOON_SLATE_DIM` | `1e1c28` | Recessed insets |
| `MOON_INDIGO` | `342f40` | Selection bands, alternate rows, panel bevel |
| `MOON_SLATE_LIGHT` | `6a6480` | Neutral borders (light enough to survive the border darkening) |
| `CREST_GOLD` | `caa24a` | Command accent |
| `CREST_GOLD_BRIGHT` | `f2cf7a` | Confirmation flash, awakening banner |
| `SPECTRAL_VIOLET` | `9b74d6` | Target accent |
| `SPECTRAL_VIOLET_DIM` | `6a4a9a` | Secondary violet |
| `STEEL_GUARD` | `6a8fb8` | Defensive states (Brace, intercept) |

`PANEL_BORDER` (`4a9eff`) is **retired** from all scripts — it read as
debug-tool blue against this palette. It remains defined only so older
saves and any external reference to the constant keep resolving.

## Panels

`UiStyle.draw_panel(canvas, rect, role, ornate)` draws, in order:

1. `MOON_SLATE` fill
2. a one-pixel `MOON_INDIGO` top bevel, inset by 1px
3. a border in the role accent, darkened 40%
4. corner marks in the full-strength accent (when `ornate`)

Corner marks are `UiStyle.CORNER_LENGTH` = **3px**. This is a hard
ceiling, not a preference: at 320x180 a longer mark stops reading as a
flourish and starts reading as a broken border.

For node-based screens use `UiPanel.create(pos, size, role)`, and
`.with_divider(y)` when the panel has a title that needs separating from
its body.

## Selection state

A selected row is **never** indicated by a cursor glyph alone. Use
`UiStyle.draw_selection_band(canvas, rect, role)`, which fills the row
with `MOON_INDIGO` and puts a 1px accent tick on its leading edge.
Unselected rows drop to `TEXT_DIM`.

This applies to the battle action menu and the boot menu alike.

### Layering caveat

A `Control` paints itself **beneath** its children. On screens with a
full-rect background node (boot, party setup), a band drawn in `_draw()`
is invisible — it lands under the background. On those screens the band
must be a *node* inserted after the background and before the labels.
`boot_screen.gd` does exactly this and comments why.

## Dividers

`UiStyle.draw_divider(canvas, from, width, colour)` draws a hairline
rule with a small diamond pinch at its centre. Use it between a panel's
header and its body, or between a list and a detail block — not as
general decoration.

## Typeface

The interface uses one pixel face, **Crestbound** — a proportional 5x7
bitmap in a 5x8 cell, generated by `tools/generate_font.py` and emitted
as a BMFont pair (`crestbound_font.png` + `.fnt`) that Godot imports as a
`FontFile`.

It is wired up as the **project-wide default font**
(`gui/theme/custom_font` in `project.godot`), not per-Label. That means
every `Control` and every `draw_string(get_theme_default_font(), …)`
picks it up, so no screen can silently fall back to Godot's
anti-aliased default.

Two rules follow from it being a bitmap face:

1. **Always draw at size 8.** The face declares an em size of 8, so 8 is
   a 1:1 blit. Any other size resamples and goes soft — the old size-6
   detail text was visibly mushy until it was moved to 8. Integer
   multiples (16, 24) are safe if a display size is ever needed.
2. **Hierarchy comes from colour and framing, not size.** With one size
   available, rank is expressed through `TEXT_WARN` / `TEXT_MAIN` /
   `TEXT_DIM`, panel accent, and position.

| Level | Colour |
| --- | --- |
| Screen or panel title | `TEXT_WARN` |
| Body / selected row | `TEXT_MAIN` |
| Secondary / unselected / detail | `TEXT_DIM` |
| Alert | `TEXT_DANGER` |

Glyphs are white in the atlas and tinted by the label's font colour, so
one atlas serves the whole palette. Descenders (`g j p q y`) occupy the
eighth row, below the baseline — authored explicitly in the generator's
`DESCENDERS` table, because folding them above the baseline made
lowercase `g` render as a digit `9`.

## Icons

`tools/generate_icons.py` emits a 7x7 icon atlas plus a name→cell
manifest; `UiIcons` (`game/scripts/ui/ui_icons.gd`) draws them tinted, or
hands back an `AtlasTexture` for node-based screens.

7x7 matches the action menu's 9px row pitch, so an icon sits beside a
row of text without disturbing the list's rhythm. Icons are authored
white and tinted at the call site, following the same accent grammar as
panels: a gold icon is the player's command, a violet one is something
acting on them.

Current set: `slot_basic`, `slot_signature`, `slot_gambit`,
`slot_brace`, `status_hexed`, `status_awakened`, `status_down`,
`objective`.

In the action menu the slot icon **replaces** the old `> ` cursor
prefix — the selection band already says which row is focused, which
frees the glyph to say what kind of action the row is. `UiIcons` no-ops
when the atlas is missing, so a checkout without generated assets still
renders readable text-only menus.

## Layout constraints

Layout uses a **320x180** logical canvas drawn at 2x-6x. Two rules
follow from that and have both already caused real bugs:

1. **Clamp label width to the panel interior.** A label left at default
   width bleeds across panel borders into the neighbouring column. This
   happened to the party-setup roster ("Warden Elara Thorne" ran into the
   detail column).
2. **Check the longest real string, not a typical one.** Two pixels of
   label width decided whether "Riven-touched Raider" fit on one line;
   when it wrapped, it pushed the panel's last row out of view entirely.

Verify layout changes with `tools/capture_screenshots.sh`, which renders
screens at 640x360, 1280x720 or 1920x1080 through the real game.

## Current implementation and remaining art review

- Party rows, battle status cards and dialogue use bounded character portraits.
  Party setup shows class and Crest names beside the portrait rather than
  reserving empty slots for nonexistent icon/card paths.
- The shared `SURFACE_OUTER`, `SURFACE_INNER`, `SURFACE_RAISED` and
  `SURFACE_LINE` tokens give menus, status cards and dialogue consistent depth.
- Dialogue captures now cover portrait and text-only conversations in the
  Greymere world QA workflow.
- Walk-cycle contact frames require art polish. The side-facing audit in
  `tools/audit_walk_cycles.py` measures their visible alternation at native
  display height; the incomplete poses remain marked for review.
- Move descriptions keep `PWR`/`ACC` abbreviations; the description panel is
  57 logical px wide beside the command list.
