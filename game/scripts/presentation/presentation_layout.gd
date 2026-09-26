class_name PresentationLayout
extends RefCounted
## Presentation geometry only; no battle rules or character statistics.

const CANVAS := Vector2(320, 180)
# Battle screen: a title bar over a tall battlefield, a 36px command deck
# and an 8px footer (see BattleHud). The background covers the field only.
const BATTLE_HEIGHT := 136
const TOP_BAR_HEIGHT := 11
const DECK_HEIGHT := 36
const FOOTER_TOP := 172
const PLAYER_CENTER_X := 78.0
const ENEMY_CENTER_X := 242.0
const FRONT_Y := 118.0
const BACK_Y := 101.0
const DIALOGUE_RECT := Rect2(10, 130, 300, 44)
const PORTRAIT_RECT := Rect2(4, 4, 30, 36)
const TEXT_TOP := 14.0
const TEXT_HEIGHT := 25.0
const RIGHT_MARGIN := 12.0
const DIALOGUE_FONT_SIZE := 6
const DIALOGUE_LINE_GAP := 1


static func texture_box(node: TextureRect, rect: Rect2) -> void:
	# TextureRect otherwise derives its minimum size from the original PNG.
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.position = rect.position
	node.size = rect.size
	node.clip_contents = true
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE


static func stage_position(team: String, slot: int, count: int, row: String) -> Vector2:
	var center_x := PLAYER_CENTER_X if team == "player" else ENEMY_CENTER_X
	# Each team has a bounded 124px span even for larger asymmetric encounters.
	var spread := minf(42.0, 94.0 / maxf(1.0, float(count - 1)))
	var x := center_x + (slot - (count - 1) / 2.0) * spread
	return Vector2(roundf(x), FRONT_Y if row == "front" else BACK_Y)


static func needs_flip(native_facing: String, team: String) -> bool:
	var desired := "right" if team == "player" else "left"
	return native_facing != desired


static func mirrored_anchor(point: Vector2, width: float, flipped: bool) -> Vector2:
	return Vector2(width - point.x, point.y) if flipped else point
