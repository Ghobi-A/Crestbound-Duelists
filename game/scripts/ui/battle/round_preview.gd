extends Control
class_name RoundPreview
## Pre-commit summary of the round: every planned player action, with
## Confirm / Back. Scales from one action (1v1) to three (3v3).

const PANEL_SIZE := Vector2(184, 86)
const MAX_ROWS := 3
const PORTRAIT_SIZE := Vector2(12, 14)
const PORTRAIT_X := 9.0
const TEXT_X := PORTRAIT_X + PORTRAIT_SIZE.x + 5.0
const FIRST_ROW := 17.0
const ROW_PITCH := 17.0
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
			slot.position = Vector2(PORTRAIT_X, FIRST_ROW + i * ROW_PITCH)
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
	UiStyle.draw_text(self, Vector2(0, 9.5), "ROUND PLAN", 6, UiStyle.GOLD_BRIGHT, PANEL_SIZE.x, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.MEDIUM, 1.2)
	UiStyle.draw_divider(self, Vector2(10, 13), PANEL_SIZE.x - 20, PlaceholderPalette.SPECTRAL_VIOLET)
	var text_width := PANEL_SIZE.x - TEXT_X - 9
	for i in planned.size():
		var action: Dictionary = planned[i]
		var actor: BattleUnit = action.actor
		var top := FIRST_ROW + i * ROW_PITCH
		UiStyle.draw_portrait_frame(self, Rect2(Vector2(PORTRAIT_X, top), PORTRAIT_SIZE).grow(0.75))
		# Actor and move share the first line; the target gets its own line
		# so long enemy names are never clipped mid-word.
		UiStyle.draw_text(self, Vector2(TEXT_X, top + 5.2), actor.display_name.to_upper(), 5, UiStyle.TEXT, text_width, HORIZONTAL_ALIGNMENT_LEFT, UiStyle.MEDIUM)
		var move_name := "Brace" if action.kind == "brace" else str(action.move.get("name", "?"))
		UiStyle.draw_text(self, Vector2(TEXT_X, top + 5.2), move_name, 5, UiStyle.GOLD_BRIGHT, text_width, HORIZONTAL_ALIGNMENT_RIGHT)
		if action.kind != "brace" and action.target != null:
			UiStyle.draw_pointer(self, Vector2(TEXT_X + 3.5, top + 9.8), PlaceholderPalette.SPECTRAL_VIOLET, 1.8)
			UiStyle.draw_text(self, Vector2(TEXT_X + 6, top + 11.6), action.target.display_name, 5, UiStyle.TEXT_DIM, text_width - 6)
	# Two framed buttons; the focused one takes the selection style.
	var buttons := [Rect2(18, PANEL_SIZE.y - 13, 84, 8), Rect2(116, PANEL_SIZE.y - 13, 50, 8)]
	var labels := ["CONFIRM ROUND", "BACK"]
	for b in 2:
		var rect: Rect2 = buttons[b]
		if cursor == b:
			UiStyle.draw_selection_band(self, rect, UiStyle.COMMAND)
		else:
			UiStyle.draw_frame(self, rect, Color("3b4459"))
		UiStyle.draw_text(self, Vector2(rect.position.x, rect.position.y + 5.8), labels[b], 5,
			UiStyle.GOLD_BRIGHT if cursor == b else UiStyle.TEXT_DIM, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.MEDIUM, 0.6)
