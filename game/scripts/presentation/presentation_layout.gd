class_name PresentationLayout
extends RefCounted
## Presentation geometry only; no battle rules or character statistics.
##
## Every screen coordinate in the game derives from CANVAS. Nothing here
## is a hand-tuned pixel offset that happens to look right at one
## resolution — that was what made the previous 320x180 canvas so
## expensive to leave. Regions are expressed as fractions of the canvas
## or as offsets from a named region, so changing CANVAS moves the whole
## interface coherently.
##
## Two asset classes render differently and must not be conflated:
##   pixel art   — authored at final size (tiles, icons, the typeface,
##                 the 20x30 townsfolk). Nearest neighbour, pixel-aligned.
##   source art  — painted at high resolution (the 1536x1024 character
##                 atlases, the 1672x941 Hollow Court plate) and sampled
##                 down to fit. Smooth filtering; nearest would alias it
##                 into noise at a non-integer ratio.

const CANVAS := Vector2(1280, 720)

# --- Battle vertical composition -------------------------------------
# The battlefield owns 70% of the canvas so combatants and environment
# art both have room; the HUD is a strip beneath it rather than the
# third of the screen (58 of 180 rows) it occupied at 320x180.
const BATTLEFIELD_FRACTION := 0.70   # 504 / 720
const BATTLE_HEIGHT := 504.0
const HUD_TOP := BATTLE_HEIGHT
const HUD_HEIGHT := CANVAS.y - BATTLE_HEIGHT   # 216
const TOP_BAR_HEIGHT := 56.0
const MESSAGE_STRIP_HEIGHT := 44.0

# --- Battle stage geometry -------------------------------------------
# Team centres sit at just under a third and just over two thirds of the
# width, which is the composition the 320x180 stage already used.
const PLAYER_CENTER_X := CANVAS.x * 0.256    # 328
const ENEMY_CENTER_X := CANVAS.x * 0.744     # 952
# Feet lines, as a fraction of the battlefield rather than the canvas:
# moving the HUD does not drag the combatants with it.
const FRONT_Y := BATTLE_HEIGHT * 0.803       # ~405
const BACK_Y := BATTLE_HEIGHT * 0.656        # ~331
const TEAM_SPAN := 376.0                     # widest a team spreads
const MAX_SPACING := 168.0                   # cap for small encounters

# --- Combatants and effects ------------------------------------------
# The height a registered combatant is drawn at. characters.json carries
# the same number as its display_height (a test keeps the two in step);
# it lives here too because the effect scale derives from it.
const COMBATANT_HEIGHT := 176.0
# What that height was on the 320x180 canvas. Authored VFX sheets and the
# fallback impact marks were drawn to read against a combatant that size,
# so they scale by the same ratio or they become specks beside the
# characters they annotate.
const LEGACY_COMBATANT_HEIGHT := 44.0
const EFFECT_SCALE := COMBATANT_HEIGHT / LEGACY_COMBATANT_HEIGHT

# --- Dialogue ---------------------------------------------------------
# Shorter than it was: typeset serif copy fits far more per line than the
# 8px face did, so the same entries need fewer lines and a 208px panel
# stood mostly empty. Giving the height back to the world is the point of
# a cinematic box rather than a text window.
const DIALOGUE_RECT := Rect2(32, 512, 1216, 168)
# The speaker's portrait breaks the top edge of the dialogue panel rather
# than sitting inside it. The character is the subject of the scene and
# the panel is the surface their words are written on, so the portrait
# reads better crossing the boundary than boxed inside it. Sized above
# its 138x160 atlas crop, which the source resolution comfortably carries.
const PORTRAIT_RECT := Rect2(24, -52, 168, 195)
const TEXT_TOP := 58.0
const TEXT_HEIGHT := 84.0
const RIGHT_MARGIN := 56.0

# --- Overworld --------------------------------------------------------
# Greymere's tiles and townsfolk are authored pixel art at 16px and
# ~20x30. They hold no detail beyond that, so the overworld keeps its
# authored scale and zooms the camera by an integer factor instead of
# resampling: tiles stay exactly crisp, and the high-resolution cast
# atlas still resolves at 4x its logical size because the GPU samples it
# at final screen scale.
#
# 4 is also the smallest whole zoom whose view fits inside Greymere's
# 24x14 tile map. At 3 the camera showed 427x240 world units against a
# 384x224 map and the empty space beyond its edges came with it. Any new
# map must be at least CANVAS / OVERWORLD_ZOOM tiles, which
# test_overworld_camera pins.
const OVERWORLD_ZOOM := 4.0


static func battlefield_rect() -> Rect2:
	return Rect2(0, 0, CANVAS.x, BATTLE_HEIGHT)


static func hud_rect() -> Rect2:
	return Rect2(0, HUD_TOP, CANVAS.x, HUD_HEIGHT)


static func texture_box(node: TextureRect, rect: Rect2) -> void:
	# TextureRect otherwise derives its minimum size from the original PNG.
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.position = rect.position
	node.size = rect.size
	node.clip_contents = true
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE


static func use_source_art_filter(node: CanvasItem) -> void:
	## High-resolution painted art sampled down to fit. Nearest neighbour
	## at a non-integer ratio drops pixels unevenly and stipples the
	## result; smoothing keeps the authored detail readable.
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


static func use_pixel_art_filter(node: CanvasItem) -> void:
	## Art authored at its final pixel size. Must stay hard-edged.
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


static func stage_position(team: String, slot: int, count: int, row: String) -> Vector2:
	var center_x := PLAYER_CENTER_X if team == "player" else ENEMY_CENTER_X
	# Each team keeps a bounded span even for larger asymmetric encounters.
	var spread := minf(MAX_SPACING, TEAM_SPAN / maxf(1.0, float(count - 1)))
	var x := center_x + (slot - (count - 1) / 2.0) * spread
	return Vector2(roundf(x), roundf(FRONT_Y if row == "front" else BACK_Y))


static func needs_flip(native_facing: String, team: String) -> bool:
	var desired := "right" if team == "player" else "left"
	return native_facing != desired


static func mirrored_anchor(point: Vector2, width: float, flipped: bool) -> Vector2:
	return Vector2(width - point.x, point.y) if flipped else point
