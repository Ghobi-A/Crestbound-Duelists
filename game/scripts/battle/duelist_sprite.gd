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
var _sprite_pivot: Node2D   # animates around the character's feet; see _setup_sheet()
var _entity_sprite: Sprite2D
var _manifest: Dictionary = {}
var _has_sheet := false

# Per-instance frame geometry. Defaults match the global manifest's
# generated 24x32 sheets; a sidecar (see below) overrides them per
# character, so an authored hero and a generated placeholder can share
# a battle with no code change.
var _frame_w := 24
var _frame_h := 32
var _states: Dictionary = {}
var _anchor := Vector2(12, 22)   # feet, in frame pixels; see docs/AUTHORED_ART_PIPELINE.md

# Where "feet" sit relative to this node's origin, for the contact shadow
# and highlight rings. The legacy placeholder sheets draw centered with a
# hand-tuned -10 offset, so their floor sits a few px below origin; a
# sidecar's anchor is exact, so its floor point IS the origin.
var _feet_y := 6.0
var _state := "idle"
var _frame := 0
var _frame_clock := 0.0
var _holding := false   # a non-looping animation finished; hold last frame
var _entity_clock := 0.0
var _entity_frame := 0
var _entity_frame_w := 32
var _entity_frame_h := 32
var _tween: Tween
var _pivot_tween: Tween   # squash/stretch/rotation on _sprite_pivot; see play()

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
	if path == "":
		return
	var sidecar := _load_sidecar(path)
	if sidecar.is_empty() and _manifest.is_empty():
		return  # no per-character layout and no global fallback to size against
	_sprite = Sprite2D.new()
	_sprite.texture = load(path)
	_sprite.region_enabled = true
	if not sidecar.is_empty():
		_frame_w = int(sidecar.get("frame_width", _frame_w))
		_frame_h = int(sidecar.get("frame_height", _frame_h))
		_states = sidecar.get("states", {})
		var a: Array = sidecar.get("anchor", [_frame_w / 2.0, _frame_h])
		_anchor = Vector2(a[0], a[1])
		# Sidecar art is anchored explicitly, so draw it unscaled from its
		# own top-left rather than the placeholder sheets' centered pivot.
		_sprite.centered = false
		# Each authored hero pose was generated independently with no
		# shared "which way does this face" convention — some lean left,
		# some right. "facing" in the sidecar records which way THIS art
		# faces by default; flip it whenever that doesn't match what the
		# unit's side needs (players face right, toward the enemy
		# formation; enemies face left, toward the party).
		var faces_left := str(sidecar.get("facing", "right")) == "left"
		var needs_flip := (
			(unit.team == "player" and faces_left)
			or (unit.team == "enemy" and not faces_left)
		)
		_sprite.flip_h = needs_flip
		# Flipping a non-centered Sprite2D mirrors around its own local
		# origin, not around the anchor — left uncompensated, the feet
		# jump sideways by frame_width. Same offset-based fix
		# overworld_sprite.gd already uses for its west-facing mirror.
		_sprite.offset = (
			Vector2(_anchor.x - _frame_w, -_anchor.y) if needs_flip else -_anchor
		)
		_feet_y = 0.0
	else:
		_frame_w = int(_manifest.get("frame_width", 24))
		_frame_h = int(_manifest.get("frame_height", 32))
		_states = _manifest.get("states", {})
		_sprite.position = Vector2(0, -10)  # feet roughly on home position
	# A single authored frame has no attack/hit/defeat art of its own, so
	# combat states are sold with motion instead: squash/stretch/rotation
	# tweened on the art alone, never on `self`, so the contact shadow and
	# highlight rings — drawn in this node's own _draw() — stay flat on
	# the ground instead of tilting with the character. Rotating/scaling
	# `_sprite` directly would pivot around its top-left corner (its own
	# node origin under centered=false); wrapping it in a pivot placed at
	# `self`'s origin — which staging already puts at the character's
	# feet — makes those transforms pivot there instead.
	_sprite_pivot = Node2D.new()
	add_child(_sprite_pivot)
	_sprite_pivot.add_child(_sprite)
	_has_sheet = true
	_apply_frame()


func _load_sidecar(sheet_path: String) -> Dictionary:
	## An authored sheet's layout lives beside it as <name>.json
	## (battle.png -> battle.json). Absent entirely for the generated
	## placeholder sheets, which size against the global manifest instead.
	var sidecar_path := sheet_path.get_basename() + ".json"
	if not FileAccess.file_exists(sidecar_path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.open(sidecar_path, FileAccess.READ).get_as_text()) != OK:
		push_warning("DuelistSprite: malformed sidecar %s" % sidecar_path)
		return {}
	return json.data


func _setup_entity() -> void:
	if unit.entity_record.is_empty():
		return
	var path := "res://assets/entities/%s/idle.png" % unit.entity_id
	if not ResourceLoader.exists(path):
		return
	# An optional idle.json beside idle.png (same _load_sidecar() helper
	# battle.json/overworld.json use) lets a Bonded Entity be authored
	# bigger than the original hardcoded 32x32-per-frame contract —
	# needed to actually reach the "large enemy/Entity" visual envelope
	# rather than being stuck at 32x32 forever. Absent sidecar keeps the
	# original 32x32, 2-frame behaviour unchanged.
	var sidecar := _load_sidecar(path)
	var frame_w := int(sidecar.get("frame_width", 32))
	var frame_h := int(sidecar.get("frame_height", 32))
	_entity_frame_w = frame_w
	_entity_frame_h = frame_h
	_entity_sprite = Sprite2D.new()
	_entity_sprite.texture = load(path)
	_entity_sprite.region_enabled = true
	_entity_sprite.region_rect = Rect2(0, 0, frame_w, frame_h)
	# The base offset was tuned for a 32x32 manifestation; scale it with
	# frame size so a bigger sidecar-authored Entity floats the same
	# relative distance from its bearer instead of drifting toward them.
	var offset_scale := frame_w / 32.0
	_entity_sprite.position = (
		Vector2(-24, -12) if unit.team == "player" else Vector2(24, -8)
	) * offset_scale
	_entity_sprite.z_index = -1
	_entity_sprite.modulate = Color(1, 1, 1, 0.85)
	add_child(_entity_sprite)


func _process(delta: float) -> void:
	if _entity_sprite != null:
		_entity_clock += delta
		if _entity_clock >= ENTITY_PULSE_TIME:
			_entity_clock = 0.0
			_entity_frame = 1 - _entity_frame
			_entity_sprite.region_rect = Rect2(
				_entity_frame * _entity_frame_w, 0, _entity_frame_w, _entity_frame_h
			)

	if not _has_sheet or _holding:
		return
	var state: Dictionary = _effective_state(_state)
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
	var state: Dictionary = _effective_state(_state)
	var start := int(state.get("start", 0))
	_sprite.region_rect = Rect2((start + _frame) * _frame_w, 0, _frame_w, _frame_h)


func _effective_state(name: String) -> Dictionary:
	## A sheet that only authors some states (an idle-only single-frame
	## sheet, say) falls back to "idle" for the rest, per
	## docs/AUTHORED_ART_PIPELINE.md, rather than freezing on whatever
	## frame happened to be on screen or erroring out.
	if _states.has(name):
		return _states[name]
	return _states.get("idle", {})


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
	if _pivot_tween != null and _pivot_tween.is_running():
		_pivot_tween.kill()
	# A leftover highlight bob must never fight a combat animation's own
	# position/modulate tween.
	if is_instance_valid(_highlight_tween):
		_highlight_tween.kill()
		_ring_bob = 0.0
	if _has_sheet:
		_apply_frame()
		# Every state starts from a clean pivot transform, whatever the
		# previous state left it at (brace's held crouch, in particular,
		# would otherwise leak into the next unrelated animation).
		if _sprite_pivot != null:
			_sprite_pivot.scale = Vector2.ONE
			_sprite_pivot.rotation = 0.0
		# Single-frame art has no attack/hit/defeat pose of its own, so
		# these states are sold with motion instead: a position/modulate
		# tween on `self` (unchanged from before) plus squash, stretch and
		# rotation on `_sprite_pivot`, which pivots at the character's
		# feet rather than the sprite's own top-left corner (see
		# _setup_sheet()) — so a "lean" or "topple" reads as the body
		# moving, not the art sliding around inside its own frame.
		var lean := 1.0 if unit.team == "player" else -1.0   # attacks lean toward the enemy side
		match state:
			"attack":
				var toward := Vector2(0, -3) if unit.team == "player" else Vector2(0, 3)
				_tween = create_tween()
				_tween.tween_property(self, "position", home_position + toward, 0.1)
				_tween.tween_property(self, "position", home_position, 0.15)
				if _sprite_pivot != null:
					_pivot_tween = create_tween()
					# Anticipation crouch, then a forward stretch on the
					# strike, then settle — a squash/stretch beat standing
					# in for real windup/release frames.
					_pivot_tween.tween_property(_sprite_pivot, "scale", Vector2(0.88, 1.12), 0.06)
					_pivot_tween.parallel().tween_property(_sprite_pivot, "rotation", deg_to_rad(-6.0 * lean), 0.06)
					_pivot_tween.tween_property(_sprite_pivot, "scale", Vector2(1.18, 0.85), 0.07)
					_pivot_tween.parallel().tween_property(_sprite_pivot, "rotation", deg_to_rad(10.0 * lean), 0.07)
					_pivot_tween.tween_property(_sprite_pivot, "scale", Vector2.ONE, 0.12)
					_pivot_tween.parallel().tween_property(_sprite_pivot, "rotation", 0.0, 0.12)
			"hit":
				# A small flinch: rocked back and squashed on the impact
				# frame, then eased back to neutral — the shadow/rings
				# stay put since only the pivot (and briefly `self`, for
				# the knockback) moves, not the whole draw. `.parallel()`
				# ties to whichever tweener was added immediately before
				# it, so each position step is interleaved right after
				# its matching modulate step rather than appended at the
				# end, where it would sync to the wrong half of the flash.
				var knockback := Vector2(-3, 0) if unit.team == "player" else Vector2(3, 0)
				_tween = create_tween()
				_tween.tween_property(self, "modulate", Color(1, 0.55, 0.55), 0.07)
				_tween.parallel().tween_property(self, "position", home_position + knockback, 0.06)
				_tween.tween_property(self, "modulate", Color.WHITE, 0.15)
				_tween.parallel().tween_property(self, "position", home_position, 0.16)
				if _sprite_pivot != null:
					_pivot_tween = create_tween()
					_pivot_tween.tween_property(_sprite_pivot, "scale", Vector2(1.12, 0.85), 0.05)
					_pivot_tween.parallel().tween_property(_sprite_pivot, "rotation", deg_to_rad(-10.0 * lean), 0.05)
					_pivot_tween.tween_property(_sprite_pivot, "scale", Vector2.ONE, 0.17)
					_pivot_tween.parallel().tween_property(_sprite_pivot, "rotation", 0.0, 0.17)
			"defeat":
				_tween = create_tween()
				_tween.tween_property(self, "modulate", Color(0.6, 0.55, 0.6), 0.4)
				# A collapse, not just a colour fade: the unit topples and
				# sinks, and — unlike the other states — this pose is left
				# in place (defeat never springs back to idle).
				_tween.parallel().tween_property(self, "position", home_position + Vector2(0, 4), 0.4)
				if _sprite_pivot != null:
					_pivot_tween = create_tween()
					_pivot_tween.tween_property(_sprite_pivot, "rotation", deg_to_rad(78.0 * lean), 0.4)
					_pivot_tween.parallel().tween_property(_sprite_pivot, "scale", Vector2(0.88, 0.82), 0.4)
			"brace":
				if _sprite_pivot != null:
					_pivot_tween = create_tween()
					# A held crouch, not a spring-back bounce: brace is a
					# stance that persists until the unit's next action,
					# and _effective_state() keeps this frame looping
					# (falling back to "idle") for as long as it does.
					_pivot_tween.tween_property(_sprite_pivot, "scale", Vector2(0.92, 0.94), 0.12)
			"awaken":
				var lift := Vector2(0, -3)
				_tween = create_tween()
				_tween.tween_property(self, "position", home_position + lift, 0.12)
				_tween.tween_property(self, "position", home_position, 0.18)
				if _sprite_pivot != null:
					_pivot_tween = create_tween()
					_pivot_tween.tween_property(_sprite_pivot, "scale", Vector2(1.18, 1.18), 0.14)
					_pivot_tween.tween_property(_sprite_pivot, "scale", Vector2.ONE, 0.22)
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
	var frame_w := float(_frame_w)
	var half_w := frame_w * 0.4
	var half_h := frame_w * 0.16
	var feet_y := _feet_y  # roughly where the sprite's feet sit below home_position
	var points := PackedVector2Array()
	for i in 16:
		var angle := TAU * float(i) / 16.0
		points.append(Vector2(cos(angle) * half_w, feet_y + sin(angle) * half_h))
	draw_colored_polygon(points, Color(0.04, 0.04, 0.08, 0.4))


func _draw_ring(radius_scale: float, color: Color) -> void:
	var frame_w := float(_frame_w)
	var half_w := frame_w * radius_scale
	var half_h := half_w * 0.4
	var feet_y := _feet_y + _ring_bob
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
	# State overlays shown in both render modes, sized against this
	# instance's own frame geometry so they still wrap the sprite once a
	# sidecar swaps in art much bigger than the 24x32 placeholder box.
	var body_top_left := (
		Vector2(-_anchor.x, -_anchor.y) if _has_sheet and _feet_y == 0.0
		else Vector2(-_frame_w / 2.0, -10 - _frame_h / 2.0)
	)
	var body_size := Vector2(_frame_w, _frame_h)
	if unit.awakened and unit.awakening_rounds_left > 0:
		draw_rect(Rect2(body_top_left - Vector2(1, 1), body_size + Vector2(2, 2)),
			Color(1.0, 0.85, 0.3, 0.85), false, 1.0)
	if unit.is_braced():
		draw_rect(Rect2(body_top_left.x, body_top_left.y + body_size.y * 0.35, 3, body_size.y * 0.25),
			PlaceholderPalette.STEEL_GUARD)
	if unit.has_status("hexed"):
		draw_rect(Rect2(body_top_left.x + body_size.x - 5, body_top_left.y + 2, 4, 4),
			PlaceholderPalette.TILE_CREST_NODE.lightened(0.3))
