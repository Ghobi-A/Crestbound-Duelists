extends Control
class_name EnemyStatusPlate
## A compact battlefield label. The BattleUnit remains the only HP/status source.

var unit: BattleUnit
var selected := false

func bind(value: BattleUnit, width: float, center_x: float) -> void:
	unit = value
	size = Vector2(width, 22)
	position = Vector2(roundf(center_x - width / 2.0), 16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func refresh() -> void:
	queue_redraw()

func _draw() -> void:
	if unit == null:
		return
	var rim := UiStyle.accent_color(UiStyle.TARGET) if selected else UiStyle.GOLD_DIM
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.035, 0.06, 0.88))
	draw_rect(Rect2(0, 0, size.x, 0.5), rim)
	var label := "DOWN" if not unit.is_alive() else unit.display_name.to_upper()
	if UiStyle.text_width(label, 5, UiStyle.MEDIUM) > size.x - 6:
		var words := label.split(" ", false)
		label = words[words.size() - 1]
	while label.length() > 1 and UiStyle.text_width(label, 5, UiStyle.MEDIUM) > size.x - 6:
		label = label.left(label.length() - 2) + "…"
	UiStyle.draw_text(self, Vector2(3, 7), label, 5, UiStyle.TEXT if unit.is_alive() else UiStyle.TEXT_FAINT, size.x - 6, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.MEDIUM)
	var state := ""
	if unit.is_alive():
		if not unit.statuses.is_empty():
			state = str(unit.statuses[0].name).to_upper()
		elif unit.is_braced():
			state = "BRACED"
		elif unit.awakened:
			state = "AWAKENED"
	if state != "":
		UiStyle.draw_text(self, Vector2(2, 14), state, 5, UiStyle.TEXT_DIM, size.x - 4, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.REGULAR)
	var bar := Rect2(3, 18, size.x - 6, 2)
	draw_rect(bar, Color(0.17, 0.2, 0.24))
	if unit.is_alive():
		draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * clampf(unit.hp_ratio(), 0.0, 1.0)), bar.size.y)), UiStyle.GOLD_BRIGHT if selected else Color("ac684e"))
	if selected:
		draw_rect(Rect2(0, 21, size.x, 1), UiStyle.accent_color(UiStyle.TARGET))
