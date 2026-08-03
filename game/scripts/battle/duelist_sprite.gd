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

# Target-highlighting (Phase 4). Kept independent of _tween/_state so a
# combat animation (attack/hit/defeat) never fights a highlight, and a
# highlight change never interrupts a combat animation.
var _highlight_kind := ""   # "", "selected" (gold, the acting unit), "target" (violet)
var _highlight_tween: Tween
var _ring_bob := 0.0
var _confirm_flash_t := 0.0
var _confirm_tween: Tween


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


func set_highlighted(kind: String) -> void:
	## "" clears, "selected" marks the acting unit (gold), "target" marks
	## the current target during selection (violet). Drives a small
	## looping bob so a locked-in ring reads as "active", not static.
	if _highlight_kind == kind:
		return
	_highlight_kind = kind
	if is_instance_valid(_highlight_tween):
		_highlight_tween.kill()
	if kind == "":
		_ring_bob = 0.0
	else:
		_highlight_tween = create_tween().set_loops()
		_highlight_tween.tween_method(_set_ring_bob, 0.0, -1.5, 0.5)
		_highlight_tween.tween_method(_set_ring_bob, -1.5, 0.0, 0.5)
	queue_redraw()


func clear_highlight() -> void:
	set_highlighted("")


func _set_ring_bob(value: float) -> void:
	_ring_bob = value
	queue_redraw()


func flash_confirm() -> void:
	## A brief brighter pop on the confirmed target, independent of the
	## ring state above: the controller opens the next unit's menu (or
	## the round preview) on the very next call, which synchronously
	## clears _highlight_kind. If the flash shared that state it would
	## be killed before a single frame rendered it, so it gets its own
	## tweened value that nothing else touches.
	if is_instance_valid(_confirm_tween):
		_confirm_tween.kill()
	_confirm_flash_t = 1.0
	_confirm_tween = create_tween()
	_confirm_tween.tween_method(_set_confirm_flash, 1.0, 0.0, 0.22)


func _set_confirm_flash(value: float) -> void:
	_confirm_flash_t = value
	queue_redraw()


func play(state: String) -> void:
	_state = state
	_frame = 0
	_frame_clock = 0.0
	_holding = false
	if _tween != null and _tween.is_running():
		_tween.kill()
	# A leftover highlight bob must never fight a combat animation's own
	# position/modulate tween.
	if is_instance_valid(_highlight_tween):
		_highlight_tween.kill()
		_ring_bob = 0.0
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


func _draw_contact_shadow() -> void:
	## Grounds every unit on the arena floor. Sized from the manifest's
	## frame width rather than a fixed constant, so a future sprite-size
	## migration (Phase 3B) does not require touching this.
	var frame_w := float(_manifest.get("frame_width", 24))
	var half_w := frame_w * 0.4
	var half_h := frame_w * 0.16
	var feet_y := 6.0  # roughly where the sprite's feet sit below home_position
	var points := PackedVector2Array()
	for i in 16:
		var angle := TAU * float(i) / 16.0
		points.append(Vector2(cos(angle) * half_w, feet_y + sin(angle) * half_h))
	draw_colored_polygon(points, Color(0.04, 0.04, 0.08, 0.4))


func _draw_ring(radius_scale: float, color: Color) -> void:
	var frame_w := float(_manifest.get("frame_width", 24))
	var half_w := frame_w * radius_scale
	var half_h := half_w * 0.4
	var feet_y := 6.0 + _ring_bob
	var points := PackedVector2Array()
	for i in 20:
		var angle := TAU * float(i) / 20.0
		points.append(Vector2(cos(angle) * half_w, feet_y + sin(angle) * half_h))
	draw_polyline(points + PackedVector2Array([points[0]]), color, 1.0)


func _draw_highlight() -> void:
	## Ring markers sit at the unit's base — around the contact shadow,
	## never over the torso or face — so they never obscure the sprite.
	if _highlight_kind == "selected":
		_draw_ring(0.46, PlaceholderPalette.CREST_GOLD)
	elif _highlight_kind == "target":
		_draw_ring(0.46, PlaceholderPalette.SPECTRAL_VIOLET)
	if _confirm_flash_t > 0.0:
		var flash := PlaceholderPalette.CREST_GOLD_BRIGHT
		flash.a = _confirm_flash_t
		_draw_ring(0.5 + 0.25 * _confirm_flash_t, flash)


func _draw() -> void:
	if unit == null:
		return
	_draw_contact_shadow()
	_draw_highlight()
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
