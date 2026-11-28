extends Node2D
class_name OverworldPlayer
## Grid-aligned four-direction player movement. The protagonist resolves through
## the shared overworld presentation registry, including class-specific v2
## walk cycles, and falls back to a debug chip only when art is unavailable.

signal stepped_onto(tile: Vector2i)

const TILE := 16
const STEP_TIME := 0.14
const TURN_DELAY := 0.08          # a shorter tap from standing only turns
const IDLE_BREATH_AFTER := 1.5    # seconds still before the idle breath starts
const DIRECTIONS := {
	"move_up": Vector2i(0, -1), "move_down": Vector2i(0, 1),
	"move_left": Vector2i(-1, 0), "move_right": Vector2i(1, 0),
}

var tile := Vector2i.ZERO
var facing := Vector2i(0, 1)
var movement_locked := false

var _map: Node  # must expose is_walkable(Vector2i) -> bool
var _step_from := Vector2.ZERO
var _step_to := Vector2.ZERO
var _step_progress := 1.0
var _footfall_due := false  # this step's footstep has not sounded yet
var footfalls := 0           # steps that have sounded (QA counter)
var _reach_tween: Tween
var _sprite: OverworldSprite
var _has_sheet := false


static func sprite_key() -> String:
	## Kai in his village clothes until Civara stabilises a class.
	var class_id := str(GameState.player_class_id)
	return "aren/%s" % class_id if class_id != "" else "kai_unbonded"
var _stride := 0  # alternates per tile so the feet take turns
var _held: Array[String] = []     # held move actions, most recent first
var _hold_time := 0.0
var _turn_hold := TURN_DELAY      # time since a standing turn; moves once >= TURN_DELAY
var _idle_time := 0.0
var _walked_last_frame := false


func setup(map: Node, start_tile: Vector2i) -> void:
	_map = map
	tile = start_tile
	position = Vector2(tile * TILE) + Vector2(TILE / 2.0, TILE / 2.0)
	_step_progress = 1.0
	_footfall_due = false
	_setup_sprite()


func _setup_sprite() -> void:
	_sprite = OverworldSprite.new()
	_has_sheet = _sprite.attach(self, sprite_key())
	if _has_sheet:
		_sprite.set_facing(facing)


func is_moving() -> bool:
	return _step_progress < 1.0


func _process(delta: float) -> void:
	_track_held_directions()
	var budget := delta
	if is_moving():
		_step_progress += budget / STEP_TIME
		_land_footfall()
		if _step_progress < 1.0:
			_place_on_step()
			return
		# Carry the leftover time straight into the next step, so a held
		# direction never stalls for a frame at each tile.
		budget = (_step_progress - 1.0) * STEP_TIME
		_step_progress = 1.0
		position = _step_to
		_stride = 1 - _stride
		_walked_last_frame = true
		stepped_onto.emit(tile)
		# What that step triggered (an encounter, an exit, a dialogue) locks
		# movement before the next step can start in this same frame.
		if _map.has_method("movement_blocked") and _map.movement_blocked():
			movement_locked = true
	else:
		_walked_last_frame = false

	if movement_locked:
		_hold_time = 0.0
		_settle(delta)
		return
	var direction := _wanted_direction()
	if direction == Vector2i.ZERO:
		_hold_time = 0.0
		_settle(delta)
		return
	_idle_time = 0.0
	if _has_sheet:
		_sprite.breathe(0.0)
	if facing != direction:
		facing = direction
		if _has_sheet:
			_sprite.set_facing(facing)
		queue_redraw()
		# From standing, a short tap only turns to face that way; already
		# walking, a new direction is taken at once.
		_turn_hold = 0.0 if not _walked_last_frame else TURN_DELAY
	_turn_hold += delta
	_hold_time += delta
	if _turn_hold < TURN_DELAY:
		if _has_sheet:
			_sprite.rest()
		return
	var next := tile + direction
	if _map.has_method("try_exit") and _map.try_exit(tile, direction):
		return
	if not _map.is_walkable(next):
		if _has_sheet:
			_sprite.rest()
		return
	tile = next
	_step_from = position
	_step_to = Vector2(tile * TILE) + Vector2(TILE / 2.0, TILE / 2.0)
	_step_progress = budget / STEP_TIME
	_footfall_due = true
	_land_footfall()
	_place_on_step()


func _land_footfall() -> void:
	## The foot lands mid-step, on the walk's contact frame. Checked against
	## a per-step flag, not a frame crossing, so every step sounds once even
	## when a slow frame starts a step already past its midpoint.
	if _footfall_due and _step_progress >= 0.5:
		_footfall_due = false
		footfalls += 1
		AudioRouter.play_sfx("world", footstep_cue())


func _place_on_step() -> void:
	# Whole pixels, so the camera (locked to the player) and the sprite move
	# together and the character never shimmers against the ground.
	position = _step_from.lerp(_step_to, _step_progress).round()
	if _has_sheet:
		_sprite.set_walk_phase(_step_progress, _stride)


func reach() -> void:
	## Anticipation: lean a pixel and a half toward what you are talking to,
	## reading or opening, and settle back, so the press has weight before
	## the world answers. Visual only; the tile and camera do not move.
	if not _has_sheet:
		return
	if _reach_tween != null and _reach_tween.is_valid():
		_reach_tween.kill()
	var toward := Vector2(facing) * 1.5
	_reach_tween = create_tween()
	_reach_tween.tween_method(_sprite.lean, Vector2.ZERO, toward, 0.06).set_ease(Tween.EASE_OUT)
	_reach_tween.tween_method(_sprite.lean, toward, Vector2.ZERO, 0.14).set_trans(Tween.TRANS_SINE)


func _settle(delta: float) -> void:
	## Standing still: the idle pose, then a slow breath after a moment.
	if not _has_sheet:
		return
	_sprite.rest()
	_idle_time += delta
	var breath := clampf((_idle_time - IDLE_BREATH_AFTER) / 1.0, 0.0, 1.0)
	_sprite.breathe(0.012 * breath * (0.5 - 0.5 * cos(TAU * _idle_time / 3.2)))


func _track_held_directions() -> void:
	## Most recent press wins, so rolling between two keys feels direct.
	for action in DIRECTIONS:
		if Input.is_action_just_pressed(action):
			_held.erase(action)
			_held.push_front(action)
		elif not Input.is_action_pressed(action):
			_held.erase(action)


func _wanted_direction() -> Vector2i:
	for action in _held:
		if Input.is_action_pressed(action):
			return DIRECTIONS[action]
	for action in DIRECTIONS:   # pressed before this scene started
		if Input.is_action_pressed(action):
			return DIRECTIONS[action]
	return Vector2i.ZERO


func footstep_cue() -> String:
	## Surface under the player: cobbles in town, dirt and grass outside,
	## boards indoors.
	if _map == null or not _map.has_method("surface_at"):
		return "step"
	return "step_" + str(_map.surface_at(tile))


func _draw() -> void:
	if _has_sheet:
		return
	if not OS.is_debug_build():
		return
	# Explicit debug-only fallback when class art is missing.
	var body_color := PlaceholderPalette.class_color(GameState.player_class_id)
	draw_rect(Rect2(-4, -2, 8, 8), PlaceholderPalette.PLAYER_OUTLINE)
	draw_rect(Rect2(-3, -1, 6, 6), body_color)
	draw_rect(Rect2(-3, -7, 6, 6), Color("e8c8a0"))
	draw_rect(Rect2(Vector2(facing) * 3 - Vector2(1, 3), Vector2(2, 2)), Color.BLACK)
