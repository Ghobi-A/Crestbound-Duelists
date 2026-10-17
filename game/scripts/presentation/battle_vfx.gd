class_name BattleVfx
extends Node2D
## Authored VFX player. Mechanics never enter sidecars; move.vfx_key selects art.
##
## Missing authored sheets use the deliberately-designed system pulse below. This
## is a production presentation primitive, not PlaceholderPalette/debug art, so
## an absent optional effect can never leak the old placeholder visual language
## back into the shipped game.

signal effect_finished

const ROOTS := ["res://assets/vfx/moves/", "res://assets/vfx/actions/", "res://assets/vfx/status/", "res://assets/vfx/awakening/"]
const SYSTEM_MAGIC := Color("9d8cff")
const SYSTEM_PHYSICAL := Color("e7c38c")
const SYSTEM_CORE := Color("f5f0df")


static func path_for(key: String) -> String:
	for root: String in ROOTS:
		# Keep this explicitly typed. ROOTS is a Variant-backed Array in
		# GDScript, so `:= root + key` cannot be inferred consistently by the
		# web export parser (and previously stopped the deployed game here).
		var candidate: String = root + key + ".png"
		if ResourceLoader.exists(candidate):
			return candidate
	return ""


func play_effect(key: String, at: Vector2, fallback_kind := "magic", weight := "basic", state := "default") -> void:
	var path := path_for(key)
	if path != "":
		await _play_authored(path, at, state)
	else:
		if OS.is_debug_build():
			push_warning("BattleVfx: authored effect unavailable for '%s'; using system pulse." % key)
		await _play_fallback(at, fallback_kind, weight)
	effect_finished.emit()


func _play_authored(path: String, at: Vector2, state_name: String) -> void:
	var data := VisualAsset.sidecar_for(path)
	var frame_size := VisualAsset.positive_size(data, Vector2i(48, 48))
	var state: Dictionary = data.get("states", {}).get(state_name, {})
	var start := int(state.get("start", 0))
	var count := maxi(1, int(state.get("count", data.get("frame_count", 1))))
	var fps := maxf(1.0, float(state.get("fps", data.get("fps", 12.0))))
	var loops := bool(state.get("loop", data.get("loop", false)))
	var duration := clampf(float(state.get("duration", data.get("duration", count / fps))), 0.04, 1.0)
	var sprite := Sprite2D.new()
	sprite.texture = load(path)
	sprite.region_enabled = true
	sprite.centered = false
	sprite.offset = -VisualAsset.anchor(data, Vector2(frame_size) * 0.5)
	sprite.scale = Vector2.ONE * maxf(0.1, float(data.get("scale", 1.0)))
	sprite.z_index = int(data.get("z_index", 120))
	var offset = data.get("offset", [0, 0])
	if not offset is Array or offset.size() != 2:
		offset = [0, 0]
	sprite.position = at + Vector2(float(offset[0]), float(offset[1]))
	add_child(sprite)
	var shown := 0
	var frames_to_show := maxi(count, ceili(duration * fps)) if loops else count
	var frame_interval := duration / frames_to_show
	for frame in frames_to_show:
		shown = frame % count
		sprite.region_rect = Rect2((start + shown) * frame_size.x, 0, frame_size.x, frame_size.y)
		await get_tree().create_timer(frame_interval).timeout
	var hold := clampf(float(data.get("hold", 0.0)), 0.0, 0.25)
	if hold > 0.0:
		await get_tree().create_timer(hold).timeout
	sprite.queue_free()


func _play_fallback(at: Vector2, kind: String, weight: String) -> void:
	## Coherent production-safe baseline for moves whose authored sheet has not
	## landed yet. Two restrained diamond pulses match the slate/cream UI and
	## avoid the old debug-star/PlaceholderPalette look.
	var radius := 5.0 if weight == "basic" else (7.0 if weight == "signature" else 9.0)
	var accent := SYSTEM_MAGIC if kind == "magic" else SYSTEM_PHYSICAL
	var outer := Polygon2D.new()
	outer.polygon = PackedVector2Array([
		Vector2(0, -radius),
		Vector2(radius, 0),
		Vector2(0, radius),
		Vector2(-radius, 0),
	])
	outer.color = accent
	outer.position = at
	outer.z_index = 120
	add_child(outer)

	var core := Polygon2D.new()
	var core_radius := maxf(2.0, radius * 0.38)
	core.polygon = PackedVector2Array([
		Vector2(0, -core_radius),
		Vector2(core_radius, 0),
		Vector2(0, core_radius),
		Vector2(-core_radius, 0),
	])
	core.color = SYSTEM_CORE
	core.position = at
	core.z_index = 121
	add_child(core)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(outer, "scale", Vector2(1.45, 1.45), 0.16)
	tween.tween_property(outer, "modulate:a", 0.0, 0.16)
	tween.tween_property(core, "scale", Vector2(0.45, 0.45), 0.12)
	tween.tween_property(core, "modulate:a", 0.0, 0.14)
	await tween.finished
	outer.queue_free()
	core.queue_free()
