extends Control
class_name RoundPreview
## Pre-commit summary of the round: every planned player action, with
## Confirm / Back. Scales from one action (1v1) to three (3v3).

const PANEL_SIZE := Vector2(180, 110)

var planned: Array = []   # action dictionaries
var cursor := 0           # 0 = Confirm, 1 = Back


func _init() -> void:
	custom_minimum_size = PANEL_SIZE
	size = PANEL_SIZE
	visible = false


func open(actions: Array) -> void:
	planned = actions
	cursor = 0
	visible = true
	queue_redraw()


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
	draw_string(font, Vector2(6, 12), "ROUND PLAN", HORIZONTAL_ALIGNMENT_LEFT, 168, 8, PlaceholderPalette.TEXT_WARN)
	UiStyle.draw_divider(self, Vector2(6, 16), PANEL_SIZE.x - 12, PlaceholderPalette.SPECTRAL_VIOLET)
	var y := 26
	for action in planned:
		var actor: BattleUnit = action.actor
		var line := actor.display_name
		draw_string(font, Vector2(8, y), line, HORIZONTAL_ALIGNMENT_LEFT, 164, 8, PlaceholderPalette.TEXT_MAIN)
		var detail: String
		if action.kind == "brace":
			detail = "Brace"
		else:
			detail = str(action.move.get("name", "?"))
			if action.target != null:
				detail += "  ->  %s" % action.target.display_name
		draw_string(font, Vector2(16, y + 8), detail, HORIZONTAL_ALIGNMENT_LEFT, 156, 8, PlaceholderPalette.TEXT_DIM)
		y += 20
	var confirm_color := PlaceholderPalette.TEXT_WARN if cursor == 0 else PlaceholderPalette.TEXT_DIM
	var back_color := PlaceholderPalette.TEXT_WARN if cursor == 1 else PlaceholderPalette.TEXT_DIM
	draw_string(font, Vector2(24, PANEL_SIZE.y - 8), ("> " if cursor == 0 else "  ") + "CONFIRM ROUND", HORIZONTAL_ALIGNMENT_LEFT, 110, 8, confirm_color)
	draw_string(font, Vector2(118, PANEL_SIZE.y - 8), ("> " if cursor == 1 else "  ") + "BACK", HORIZONTAL_ALIGNMENT_LEFT, 60, 8, back_color)
