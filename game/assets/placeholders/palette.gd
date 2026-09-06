class_name PlaceholderPalette
## Programmer-art palette for placeholder rendering.
##
## Everything visual in the prototype draws from this palette so the
## game can be reskinned later by replacing placeholder drawing with
## real 16x16 sprites/tiles. GBC-inspired: dark, slightly desaturated,
## small set of hues. All original.

const BG_DARK := Color("0b101b")
const BG_PANEL := Color("16213e")
const PANEL_BORDER := Color("4a9eff")
const TEXT_MAIN := Color("e8e8f0")
const TEXT_DIM := Color("9aa0b8")
const TEXT_WARN := Color("e2b04a")
const TEXT_DANGER := Color("e05555")

# Overworld tiles.
const TILE_GRASS := Color("3a6b41")
const TILE_GRASS_ALT := Color("356038")
const TILE_PATH := Color("9c8a5a")
const TILE_WATER := Color("2b4a78")
const TILE_WALL := Color("4a4a5a")
const TILE_ROOF := Color("7a4a4a")
const TILE_DOOR := Color("c8a050")
const TILE_COURT := Color("5a4a7a")

# Battle terrain.
const TILE_PLAINS := Color("4a5a3a")
const TILE_RUIN := Color("5a5a6a")
const TILE_FOREST := Color("2e4a30")
const TILE_CREST_NODE := Color("6a4a9a")
const TILE_SCORCHED := Color("7a3a2a")

# Grid overlays.
const OVERLAY_MOVE := Color(0.35, 0.62, 1.0, 0.35)
const OVERLAY_ATTACK := Color(1.0, 0.35, 0.35, 0.35)
const OVERLAY_CURSOR := Color(1.0, 1.0, 1.0, 0.85)
const OVERLAY_SELECTED := Color(1.0, 0.85, 0.3, 0.9)

# Class colours (units are drawn as class-coloured duelist silhouettes).
const CLASS_COLORS := {
	"warrior": Color("c94f4f"),
	"mage": Color("7c5fd3"),
	"assassin": Color("8a94a6"),
	"guardian": Color("3f9e6a"),
	"neutral": Color("b8b8b8"),
	"sorcerer": Color("d3743f"),
}

const ENEMY_TINT := Color(0.55, 0.2, 0.25)
const PLAYER_OUTLINE := Color("e8e8f0")
const NPC_COLOR := Color("d8b46a")
const NPC_COLOR_ALT := Color("6ab4d8")

# Battle HUD colour grammar (Phase 4): gold marks the acting unit and its
# command menu, violet marks the target and anything reviewing/affecting
# it. Values match tools/generate_sprites.py's Hollow Court background
# and dais exactly, so the HUD and the battlefield read as one palette
# rather than a coincidentally similar one.
const MOON_SLATE := Color("111722")
const MOON_SLATE_DIM := Color("0b1019")
const MOON_INDIGO := Color("1d2533")
const MOON_SLATE_LIGHT := Color("697587")
const CREST_GOLD := Color("caa24a")
const CREST_GOLD_BRIGHT := Color("f2cf7a")
const SPECTRAL_VIOLET := Color("9b74d6")
const SPECTRAL_VIOLET_DIM := Color("6a4a9a")
# Defensive states (Brace, intercepted hits). Moonlit steel rather than
# the old PANEL_BORDER blue, which read as debug UI against this palette.
const STEEL_GUARD := Color("6a8fb8")


static func class_color(class_id: String) -> Color:
	return CLASS_COLORS.get(class_id, Color.WHITE)
