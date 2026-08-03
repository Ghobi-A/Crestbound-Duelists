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

## Text hierarchy

| Level | Size | Colour |
| --- | --- | --- |
| Screen title | 10–12 | `TEXT_WARN` |
| Body / row label | 8 | `TEXT_MAIN` |
| Secondary / unselected | 8 | `TEXT_DIM` |
| Dense detail | 6 | `TEXT_DIM` |
| Alert | 8 | `TEXT_DANGER` |

Sizes below 6 are not legible at this resolution and must not be used.

## Layout constraints

The internal canvas is **320x180**. Two rules follow from that and have
both already caused real bugs:

1. **Clamp label width to the panel interior.** A label left at default
   width bleeds across panel borders into the neighbouring column. This
   happened to the party-setup roster ("Warden Elara Thorne" ran into the
   detail column).
2. **Check the longest real string, not a typical one.** Two pixels of
   label width decided whether "Riven-touched Raider" fit on one line;
   when it wrapped, it pushed the panel's last row out of view entirely.

Verify layout changes with `tools/capture_screenshots.sh`, which renders
every screen at the true internal resolution.

## Known gap

There is no custom bitmap font — every screen uses Godot's default font.
It is the largest remaining "not yet art-directed" tell in the
interface, and is the natural next pass.
