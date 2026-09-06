extends Control
class_name RoundPreview
## Pre-commit summary of the round: every planned player action, with
## Confirm / Back. Scales from one action (1v1) to three (3v3).

const PANEL_SIZE := Vector2(680, 400)
const MAX_ROWS := 3
const PAD := 20.0
## Portraits keep the cast atlas's 138x160 crop ratio.
const PORTRAIT_SIZE := Vector2(69, 80)
const PORTRAIT_X := PAD
const TEXT_X := PORTRAIT_X + PORTRAIT_SIZE.x + PAD * 0.8   # clears the portrait
## One planned action per row: a name line, a detail line, and a gap.
const ROW_HEIGHT := 104.0
const HEADER_BASELINE := PAD + Typography.HEADING
const ROWS_TOP := HEADER_BASELINE + PAD
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
			slot.position = Vector2(PORTRAIT_X, ROWS_TOP + i * ROW_HEIGHT)
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
	draw_string(font, Vector2(PAD, HEADER_BASELINE), "ROUND PLAN", HORIZONTAL_ALIGNMENT_LEFT,
		PANEL_SIZE.x - PAD * 2, Typography.HEADING, PlaceholderPalette.TEXT_WARN)
	UiStyle.draw_divider(self, Vector2(PAD, HEADER_BASELINE + PAD * 0.4), PANEL_SIZE.x - PAD * 2,
		PlaceholderPalette.SPECTRAL_VIOLET)
	# Text starts at TEXT_X (clearing the portrait column) rather than a
	# fixed inset — a unit with no portrait art just leaves that column
	# blank, so the layout doesn't need two code paths.
	var y := ROWS_TOP
	for action in planned:
		var actor: BattleUnit = action.actor
		draw_string(font, Vector2(TEXT_X, y + Typography.BODY), actor.display_name,
			HORIZONTAL_ALIGNMENT_LEFT, PANEL_SIZE.x - TEXT_X - PAD, Typography.BODY,
			PlaceholderPalette.TEXT_MAIN)
		var detail: String
		if action.kind == "brace":
			detail = "Brace"
		else:
			detail = str(action.move.get("name", "?"))
			if action.target != null:
				detail += "  ->  %s" % action.target.display_name
		draw_string(font, Vector2(TEXT_X + PAD * 0.6, y + Typography.BODY * 2 + PAD * 0.3), detail,
			HORIZONTAL_ALIGNMENT_LEFT, PANEL_SIZE.x - TEXT_X - PAD * 2, Typography.BODY,
			PlaceholderPalette.TEXT_DIM)
		y += ROW_HEIGHT
	var confirm_color := PlaceholderPalette.TEXT_WARN if cursor == 0 else PlaceholderPalette.TEXT_DIM
	var back_color := PlaceholderPalette.TEXT_WARN if cursor == 1 else PlaceholderPalette.TEXT_DIM
	var footer_baseline := PANEL_SIZE.y - PAD
	draw_string(font, Vector2(PAD, footer_baseline), ("> " if cursor == 0 else "  ") + "CONFIRM ROUND",
		HORIZONTAL_ALIGNMENT_LEFT, PANEL_SIZE.x * 0.6, Typography.BODY, confirm_color)
	draw_string(font, Vector2(PANEL_SIZE.x * 0.66, footer_baseline), ("> " if cursor == 1 else "  ") + "BACK",
		HORIZONTAL_ALIGNMENT_LEFT, PANEL_SIZE.x * 0.3, Typography.BODY, back_color)
