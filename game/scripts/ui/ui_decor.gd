extends Control
class_name UiDecor
## Node form of UiStyle's ornaments for screens assembled from nodes:
## a centred rule with a star-cross, or a selection frame behind a row.

var kind := "rule"
var role := UiStyle.COMMAND


static func create(kind_: String, rect: Rect2, role_ := UiStyle.COMMAND) -> UiDecor:
	var decor := UiDecor.new()
	decor.kind = kind_
	decor.role = role_
	decor.position = rect.position
	decor.size = rect.size
	decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return decor


func _draw() -> void:
	match kind:
		"selection":
			UiStyle.draw_selection_band(self, Rect2(Vector2.ZERO, size), role)
		"frame", "frame_active":
			UiStyle.draw_portrait_frame(self, Rect2(Vector2.ZERO, size), kind == "frame_active")
		"fade_left", "fade_right":
			# Glass plate that dissolves toward the scene, with a gold rule.
			var steps := 16
			for i in steps:
				var t := (float(i) + 0.5) / steps
				var alpha := lerpf(0.82, 0.0, t)
				var x := i * size.x / steps if kind == "fade_left" else size.x - (i + 1) * size.x / steps
				draw_rect(Rect2(x, 0, size.x / steps + 0.05, size.y), Color(0.02, 0.03, 0.05, alpha))
			var rule_y := size.y - UiStyle.HAIR
			for i in steps:
				var t := (float(i) + 0.5) / steps
				var x := i * size.x / steps if kind == "fade_left" else size.x - (i + 1) * size.x / steps
				draw_rect(Rect2(x, rule_y, size.x / steps + 0.05, UiStyle.HAIR), Color(UiStyle.GOLD, lerpf(0.7, 0.0, t)))
		_:
			UiStyle.draw_divider(self, Vector2(0, size.y / 2.0), size.x, UiStyle.accent_color(role))
