extends Node2D
class_name DuelistSprite
## Visual representation of one Duelist in the party battle scene.
## Plays states (idle/attack/hit/defeat/brace/awaken) from the
## generated 24x32 sprite sheets (tools/generate_sprites.py); falls
## back to an original placeholder chip when a build has no sheet.
## Bonded Entities appear as a translucent manifestation behind the
## Duelist, loaded from assets/entities/<id>/idle.png.

signal animation_finished(state: String)

const MANIFEST_PATH := "res://assets/battle/sheet_manifest.json"
const ENTITY_PULSE_TIME := 0.6

var unit: BattleUnit
var home_position := Vector2.ZERO

var _sprite: Sprite2D
var _entity_sprite: Sprite2D
var _manifest: Dictionary = {}
var _has_sheet := false
var _state := "idle"
var _frame := 0
var _frame_clock := 0.0
var _holding := false   # a non-looping animation finished; hold last frame
var _entity_clock := 0.0
var _entity_frame := 0
var _tween: Tween


static func sheet_path_for(key: String) -> String:
	if key == "":
		return ""
	for candidate in [
		"res://assets/characters/%s/battle.png" % key,
		"res://assets/enemies/%s/battle.png" % key,
	]:
		if ResourceLoader.exists(candidate):
			return candidate
	return ""


func configure(unit_: BattleUnit, home: Vector2) -> void:
	unit = unit_
	home_position = home
	position = home
	_load_manifest()
	_setup_sheet()
	_setup_entity()
	refresh()


func _load_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var json := JSON.new()
	if json.parse(FileAccess.open(MANIFEST_PATH, FileAccess.READ).get_as_text()) == OK:
		_manifest = json.data


func _setup_sheet() -> void:
	var path := sheet_path_for(unit.sprite_key())
	if path == "" or _manifest.is_empty():
		return
	_sprite = Sprite2D.new()
	_sprite.texture = load(path)
	_sprite.region_enabled = true
	_sprite.position = Vector2(0, -10)  # feet roughly on home position
	add_child(_sprite)
	_has_sheet = true
	_apply_frame()


func _setup_entity() -> void:
	if unit.entity_record.is_empty():
		return
	var path := "res://assets/entities/%s/idle.png" % unit.entity_id
	if not ResourceLoader.exists(path):
		return
	_entity_sprite = Sprite2D.new()
	_entity_sprite.texture = load(path)
	_entity_sprite.region_enabled = true
	_entity_sprite.region_rect = Rect2(0, 0, 32, 32)
	_entity_sprite.position = Vector2(-24, -12) if unit.team == "player" else Vector2(24, -8)
	_entity_sprite.z_index = -1
	_entity_sprite.modulate = Color(1, 1, 1, 0.85)
	add_child(_entity_sprite)


func _process(delta: float) -> void:
	if _entity_sprite != null:
		_entity_clock += delta
		if _entity_clock >= ENTITY_PULSE_TIME:
			_entity_clock = 0.0
			_entity_frame = 1 - _entity_frame
			_entity_sprite.region_rect = Rect2(_entity_frame * 32, 0, 32, 32)

	if not _has_sheet or _holding:
		return
	var state: Dictionary = _manifest.get("states", {}).get(_state, {})
	if state.is_empty():
		return
	_frame_clock += delta
	if _frame_clock < 1.0 / float(state.get("fps", 4)):
		return
	_frame_clock = 0.0
	_frame += 1
	if _frame >= int(state.get("count", 1)):
		if bool(state.get("loop", false)):
			_frame = 0
		else:
			_frame = int(state.get("count", 1)) - 1
			if _state == "defeat":
				_holding = true  # stay collapsed
				animation_finished.emit("defeat")
			else:
				var finished := _state
				_state = "idle"
				_frame = 0
				animation_finished.emit(finished)
	_apply_frame()


func _apply_frame() -> void:
	if not _has_sheet:
		return
	var state: Dictionary = _manifest.get("states", {}).get(_state, {})
	var start := int(state.get("start", 0))
	var frame_w := int(_manifest.get("frame_width", 24))
	var frame_h := int(_manifest.get("frame_height", 32))
	_sprite.region_rect = Rect2((start + _frame) * frame_w, 0, frame_w, frame_h)


func refresh() -> void:
	visible = unit == null or unit.is_alive() or _state == "defeat"
	queue_redraw()


func play(state: String) -> void:
	_state = state
	_frame = 0
	_frame_clock = 0.0
	_holding = false
	if _tween != null and _tween.is_running():
		_tween.kill()
	if _has_sheet:
		_apply_frame()
		# Small physical accents on top of the frame animation.
		match state:
			"attack":
				var toward := Vector2(0, -3) if unit.team == "player" else Vector2(0, 3)
				_tween = create_tween()
				_tween.tween_property(self, "position", home_position + toward, 0.1)
				_tween.tween_property(self, "position", home_position, 0.15)
			"hit":
				_tween = create_tween()
				_tween.tween_property(self, "modulate", Color(1, 0.55, 0.55), 0.07)
				_tween.tween_property(self, "modulate", Color.WHITE, 0.15)
			"defeat":
				_tween = create_tween()
				_tween.tween_property(self, "modulate", Color(0.6, 0.55, 0.6), 0.4)
		return
	# Placeholder path (no sheet available for this build).
	match state:
		"attack":
			var toward := Vector2(0, -6) if unit.team == "player" else Vector2(0, 6)
			_tween = create_tween()
			_tween.tween_property(self, "position", home_position + toward, 0.08)
			_tween.tween_property(self, "position", home_position, 0.12)
			_tween.tween_callback(_emit_done.bind("attack"))
		"hit":
			_tween = create_tween()
			_tween.tween_property(self, "modulate", Color(1, 0.4, 0.4), 0.06)
			_tween.tween_property(self, "modulate", Color.WHITE, 0.12)
			_tween.tween_callback(_emit_done.bind("hit"))
		"defeat":
			_tween = create_tween()
			_tween.tween_property(self, "modulate", Color(0.4, 0.4, 0.5, 0.0), 0.35)
			_tween.tween_callback(_emit_done.bind("defeat"))
		_:
			refresh()
			_emit_done.call_deferred(state)
	queue_redraw()


func _emit_done(state: String) -> void:
	if state != "defeat":
		_state = "idle"
		refresh()
	animation_finished.emit(state)


func _draw() -> void:
	if unit == null:
		return
	if not _has_sheet:
		# Original placeholder chip for builds without generated art.
		var body := PlaceholderPalette.class_color(unit.class_id)
		var outline := PlaceholderPalette.PLAYER_OUTLINE if unit.team == "player" else PlaceholderPalette.ENEMY_TINT
		if not unit.entity_record.is_empty() and _entity_sprite == null:
			var entity_color := EntityRuntime.manifestation_color(unit.entity_record)
			var offset := Vector2(10, -14) if unit.team == "player" else Vector2(-10, 10)
			draw_circle(offset, 6.0, entity_color)
			draw_circle(offset + Vector2(0, -4), 3.5, entity_color)
		draw_rect(Rect2(-7, -4, 14, 13), outline)
		draw_rect(Rect2(-6, -3, 12, 11), body)
		draw_rect(Rect2(-4, -11, 8, 8), Color("e8c8a0"))
	# State overlays shown in both render modes.
	if unit.awakened and unit.awakening_rounds_left > 0:
		draw_rect(Rect2(-13, -27, 26, 34), Color(1.0, 0.85, 0.3, 0.85), false, 1.0)
	if unit.is_braced():
		draw_rect(Rect2(-12, -14, 3, 8), PlaceholderPalette.PANEL_BORDER)
	if unit.has_status("hexed"):
		draw_rect(Rect2(9, -26, 4, 4), PlaceholderPalette.TILE_CREST_NODE.lightened(0.3))
