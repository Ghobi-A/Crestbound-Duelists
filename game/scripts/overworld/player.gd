extends Node2D
class_name OverworldPlayer
## Grid-aligned four-direction player movement with placeholder drawing.
## The owning map provides collision through `is_walkable(tile)`.

signal stepped_onto(tile: Vector2i)

const TILE := 16
const STEP_TIME := 0.14

var tile := Vector2i.ZERO
var facing := Vector2i(0, 1)
var movement_locked := false

var _map: Node  # must expose is_walkable(Vector2i) -> bool
var _step_from := Vector2.ZERO
var _step_to := Vector2.ZERO
var _step_progress := 1.0


func setup(map: Node, start_tile: Vector2i) -> void:
	_map = map
	tile = start_tile
	position = Vector2(tile * TILE) + Vector2(TILE / 2.0, TILE / 2.0)
	_step_progress = 1.0


func is_moving() -> bool:
	return _step_progress < 1.0


func _process(delta: float) -> void:
	if is_moving():
		_step_progress = minf(_step_progress + delta / STEP_TIME, 1.0)
		position = _step_from.lerp(_step_to, _step_progress)
		if not is_moving():
			position = _step_to
			stepped_onto.emit(tile)
		return

	if movement_locked:
		return

	var direction := Vector2i.ZERO
	if Input.is_action_pressed("move_up"):
		direction = Vector2i(0, -1)
	elif Input.is_action_pressed("move_down"):
		direction = Vector2i(0, 1)
	elif Input.is_action_pressed("move_left"):
		direction = Vector2i(-1, 0)
	elif Input.is_action_pressed("move_right"):
		direction = Vector2i(1, 0)

	if direction == Vector2i.ZERO:
		return

	if facing != direction:
		facing = direction
		queue_redraw()

	var next := tile + direction
	if not _map.is_walkable(next):
		return

	tile = next
	_step_from = position
	_step_to = Vector2(tile * TILE) + Vector2(TILE / 2.0, TILE / 2.0)
	_step_progress = 0.0


func _draw() -> void:
	# Placeholder duelist: class-coloured body, lighter head, facing dot.
	var body_color := PlaceholderPalette.class_color(GameState.player_class_id)
	draw_rect(Rect2(-4, -2, 8, 8), PlaceholderPalette.PLAYER_OUTLINE)  # outline
	draw_rect(Rect2(-3, -1, 6, 6), body_color)                          # body
	draw_rect(Rect2(-3, -7, 6, 6), Color("e8c8a0"))                     # head
	draw_rect(Rect2(Vector2(facing) * 3 - Vector2(1, 3), Vector2(2, 2)), Color.BLACK)
