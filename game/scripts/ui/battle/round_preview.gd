extends Control
class_name RoundPreview
## Pre-commit summary of the round: every planned player action, with
## Confirm / Back. Scales from one action (1v1) to three (3v3).

const PANEL_SIZE := Vector2(200, 110)
const MAX_ROWS := 3
const PORTRAIT_SIZE := Vector2(16, 18)
const PORTRAIT_X := 8.0
const TEXT_X := PORTRAIT_X + PORTRAIT_SIZE.x + 6.0   # 30 — clears the portrait
const PORTRAIT_PATH := "res://assets/portraits/%s/neutral.png"

var planned: Array = []   # action dictionaries
var cursor := 0           # 0 = Confirm, 1 = Back

var _portraits: Array[TextureRect] = []


func _init() -> void:
	custom_minimum_size = PANEL_SIZE
	size = PANEL_SIZE
	visible = false
	# This floating modal is centred with real margin either side of it
	# (unlike the docked HUD panels, which are pixel-tuned to the exact
	# width they're given), so it's the one place in the battle screen a
	# portrait fits without shrinking something else. Nodes rather than
	# _draw(), same as DialogueBox's portrait, since a plain Sprite2D/
	# TextureRect gets filtering control _draw()'s draw_texture doesn't.
	for i in MAX_ROWS:
		var portrait := TextureRect.new()
		PresentationLayout.texture_box(portrait, Rect2(Vector2.ZERO, PORTRAIT_SIZE))
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		portrait.visible = false
		add_child(portrait)
		_portraits.append(portrait)


func open(actions: Array) -> void:
	planned = actions
	cursor = 0
	visible = true
	_update_portraits()
	queue_redraw()


func _update_portraits() -> void:
	for i in MAX_ROWS:
		var slot := _portraits[i]
		if i >= planned.size():
			slot.visible = false
			continue
		var actor: BattleUnit = planned[i].actor
		CharacterPresentation.apply_portrait(slot, actor.sprite_key())
		if slot.texture != null:
			slot.position = Vector2(PORTRAIT_X, 26.0 + i * 22.0 - 9.0)
			slot.visible = true
		else:
			slot.visible = false


func close() -> void:
	visible = false


func toggle_cursor() -> void:
	cursor = 1 - cursor
	queue_redraw()


func confirmed() -> bool:
	return cursor == 0


func _draw() -> void:
	# Violet framing: this screen reviews who each action affects, the
	# same "review/target" role violet plays on the battlefield ring.
	UiStyle.draw_panel(self, Rect2(Vector2.ZERO, PANEL_SIZE), UiStyle.TARGET)
	var font := get_theme_default_font()
	draw_string(font, Vector2(6, 12), "ROUND PLAN", HORIZONTAL_ALIGNMENT_LEFT, PANEL_SIZE.x - 12, 8, PlaceholderPalette.TEXT_WARN)
	UiStyle.draw_divider(self, Vector2(6, 16), PANEL_SIZE.x - 12, PlaceholderPalette.SPECTRAL_VIOLET)
	var y := 26
	# Text starts at TEXT_X (clearing the portrait column added in
	# _init()/_update_portraits()) rather than the original fixed 8/16 —
	# a unit with no portrait art just leaves that column blank, so the
	# layout doesn't need two code paths.
	for action in planned:
		var actor: BattleUnit = action.actor
		var text_width := PANEL_SIZE.x - TEXT_X - 8
		# Actor and move share the first line; the target gets its own line so
		# long enemy names are never clipped mid-word.
		draw_string(font, Vector2(TEXT_X, y), actor.display_name, HORIZONTAL_ALIGNMENT_LEFT, text_width, 8, PlaceholderPalette.TEXT_MAIN)
		var move_name := "Brace" if action.kind == "brace" else str(action.move.get("name", "?"))
		draw_string(font, Vector2(TEXT_X, y), move_name, HORIZONTAL_ALIGNMENT_RIGHT, text_width, 8, PlaceholderPalette.TEXT_WARN)
		if action.kind != "brace" and action.target != null:
			draw_string(font, Vector2(TEXT_X + 8, y + 9), "-> " + action.target.display_name, HORIZONTAL_ALIGNMENT_LEFT, text_width - 8, 8, PlaceholderPalette.TEXT_DIM)
		y += 22
	var confirm_color := PlaceholderPalette.TEXT_WARN if cursor == 0 else PlaceholderPalette.TEXT_DIM
	var back_color := PlaceholderPalette.TEXT_WARN if cursor == 1 else PlaceholderPalette.TEXT_DIM
	draw_string(font, Vector2(24, PANEL_SIZE.y - 8), ("> " if cursor == 0 else "  ") + "CONFIRM ROUND", HORIZONTAL_ALIGNMENT_LEFT, 110, 8, confirm_color)
	draw_string(font, Vector2(118, PANEL_SIZE.y - 8), ("> " if cursor == 1 else "  ") + "BACK", HORIZONTAL_ALIGNMENT_LEFT, 60, 8, back_color)
