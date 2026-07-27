extends Node2D
class_name InteractionIndicator
## Small bobbing marker drawn above interactable tiles/NPCs so a
## first-time player (or recruiter) can immediately see what responds
## to the interact button, without reading the README.

var _base_position := Vector2.ZERO
var _time := 0.0


func setup(local_offset: Vector2) -> void:
	_base_position = local_offset
	position = _base_position


func _process(delta: float) -> void:
	_time += delta
	position = _base_position + Vector2(0, sin(_time * 3.2) * 1.5)
	queue_redraw()


func _draw() -> void:
	draw_colored_polygon(
		PackedVector2Array([Vector2(0, -4), Vector2(3, 0), Vector2(0, 4), Vector2(-3, 0)]),
		PlaceholderPalette.TEXT_WARN,
	)
	draw_colored_polygon(
		PackedVector2Array([Vector2(0, -2), Vector2(1.5, 0), Vector2(0, 2), Vector2(-1.5, 0)]),
		PlaceholderPalette.BG_DARK,
	)
