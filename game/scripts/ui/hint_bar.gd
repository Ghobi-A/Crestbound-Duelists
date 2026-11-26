class_name HintBar
extends Control
## The one input-hint row every screen shares: key caps and serif action
## names, e.g. [Z] Confirm  [X] Back  [▲▼] Choose. Caps follow the device
## the player is using (Z/X on keys, A/B on a controller). Items are
## [action, label] pairs; action is "interact", "cancel", "move_v" (up and
## down), "move_h" (left and right) or "move" (all four).

const GAP := 7.0
const CAP := 6.4

var items: Array = []
var align := HORIZONTAL_ALIGNMENT_CENTER
var colour := UiStyle.TEXT_DIM


static func create(parent: Node, rect: Rect2, hint_items: Array, alignment := HORIZONTAL_ALIGNMENT_CENTER) -> HintBar:
	var bar := HintBar.new()
	bar.position = rect.position
	bar.size = rect.size
	bar.align = alignment
	bar.items = hint_items
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	return bar


func _ready() -> void:
	InputDevice.changed.connect(queue_redraw)


func set_items(hint_items: Array) -> void:
	if hint_items != items:
		items = hint_items
		queue_redraw()


static func item_width(action: String, label: String) -> float:
	var caps := 2.0 if action in ["move_v", "move_h"] else 1.0
	return CAP * caps + (caps - 1.0) + 2.5 + UiStyle.text_width(label, 6, UiStyle.SERIF) + GAP


func content_width() -> float:
	var total := 0.0
	for item in items:
		total += item_width(str(item[0]), str(item[1]))
	return maxf(0.0, total - GAP)


func _draw() -> void:
	var y := size.y / 2.0
	var x := 0.0
	match align:
		HORIZONTAL_ALIGNMENT_CENTER:
			x = roundf((size.x - content_width()) / 2.0)
		HORIZONTAL_ALIGNMENT_RIGHT:
			x = size.x - content_width()
	for item in items:
		var action := str(item[0])
		var label := str(item[1])
		if action in ["interact", "cancel"]:
			x += UiStyle.draw_key_cap(self, Vector2(x, y), InputDevice.cap(action), label, colour)
			continue
		var directions: Array = {"move_v": [Vector2.UP, Vector2.DOWN], "move_h": [Vector2.LEFT, Vector2.RIGHT]}.get(action, [Vector2.ZERO])
		for direction in directions:
			_draw_direction_cap(Vector2(x, y), direction)
			x += CAP + 1.0
		x -= 1.0
		UiStyle.draw_text(self, Vector2(x + 2.5, y + 2.0), label, 6, colour, -1, HORIZONTAL_ALIGNMENT_LEFT, UiStyle.SERIF)
		x += 2.5 + UiStyle.text_width(label, 6, UiStyle.SERIF) + GAP


func _draw_direction_cap(at: Vector2, direction: Vector2) -> void:
	## A key cap with an arrow, or a small cross for "any direction".
	var centre := at + Vector2(CAP / 2.0, 0)
	draw_circle(centre, CAP / 2.0, Color(0.92, 0.9, 0.84, 0.92))
	var ink := Color(0.05, 0.06, 0.09)
	if direction == Vector2.ZERO:
		draw_rect(Rect2(centre - Vector2(2.2, 0.55), Vector2(4.4, 1.1)), ink)
		draw_rect(Rect2(centre - Vector2(0.55, 2.2), Vector2(1.1, 4.4)), ink)
		return
	var side := Vector2(-direction.y, direction.x)
	draw_colored_polygon(PackedVector2Array([centre + direction * 1.8, centre - direction * 1.1 + side * 1.6, centre - direction * 1.1 - side * 1.6]), ink)
