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
const FALLBACK_DURATION := 0.16


static func path_for(key: String) -> String:
	for root: String in ROOTS:
		# Keep this explicitly typed. ROOTS is a Variant-backed Array in
		# GDScript, so `:= root + key` cannot be inferred consistently by the
		# web export parser (and previously stopped the deployed game here).
		var candidate: String = root + key + ".png"
		if ResourceLoader.exists(candidate):
			return candidate
	return ""


static func impact_delay(key: String) -> float:
	## Seconds from the start of an effect to the moment it lands, when the
	## damage, hit-stop and reaction should play. The system pulse lands as
	## it ends.
	var path := path_for(key)
	if path == "":
		return FALLBACK_DURATION
	return clampf(float(VisualAsset.sidecar_for(path).get("impact", 0.0)), 0.0, 0.4)


func play_effect(key: String, at: Vector2, fallback_kind := "magic", weight := "basic", state := "default",
		feet := Vector2.INF, mirror := false, depth := 120) -> void:
	## `feet`, `mirror` and `depth` place a move effect on its target: authored
	## effects anchored to the feet stand on them, face the attacker (art is
	## drawn struck from the left) and layer around the target sprite.
	var path := path_for(key)
	if path != "":
		await _play_authored(path, at, state, feet, mirror, depth, fallback_kind == "magic")
	else:
		if OS.is_debug_build():
			push_warning("BattleVfx: authored effect unavailable for '%s'; using system pulse." % key)
		await _play_fallback(at, fallback_kind, weight)
	effect_finished.emit()


func _play_authored(path: String, at: Vector2, state_name: String, feet := Vector2.INF, mirror := false,
		depth := 120, ground_light := false) -> void:
	var data := VisualAsset.sidecar_for(path)
	var frame_size := VisualAsset.positive_size(data, Vector2i(48, 48))
	var state: Dictionary = data.get("states", {}).get(state_name, {})
	var start := int(state.get("start", 0))
	var count := maxi(1, int(state.get("count", data.get("frame_count", 1))))
	var fps := maxf(1.0, float(state.get("fps", data.get("fps", 12.0))))
	var loops := bool(state.get("loop", data.get("loop", false)))
	var duration := clampf(float(state.get("duration", data.get("duration", count / fps))), 0.04, 1.0)
	var on_feet := str(data.get("anchor_to", "")) == "feet" and feet != Vector2.INF
	var origin := feet if on_feet else at
	var offset = data.get("offset", [0, 0])
	if not offset is Array or offset.size() != 2:
		offset = [0, 0]
	origin += Vector2(float(offset[0]), float(offset[1]))
	var layers: Array[Sprite2D] = []
	# The front layer draws over the target; an optional behind layer (the
	# far half of a ring, a fire mass) draws under it, on the same frames.
	layers.append(_effect_layer(load(path), data, frame_size, origin, mirror and on_feet,
		depth + 1 if on_feet else int(data.get("z_index", 120))))
	var behind := str(data.get("behind", ""))
	if on_feet and behind != "" and ResourceLoader.exists(path.get_base_dir().path_join(behind)):
		layers.append(_effect_layer(load(path.get_base_dir().path_join(behind)), data, frame_size, origin, mirror, depth - 1))
	if on_feet and ground_light:
		_ground_light(feet, Color(str(data.get("glow", "#9d8cff"))), duration, depth - 2)
	var shown := 0
	var frames_to_show := maxi(count, ceili(duration * fps)) if loops else count
	var frame_interval := duration / frames_to_show
	for frame in frames_to_show:
		shown = frame % count
		for layer in layers:
			layer.region_rect = Rect2((start + shown) * frame_size.x, 0, frame_size.x, frame_size.y)
		await get_tree().create_timer(frame_interval).timeout
	var hold := clampf(float(data.get("hold", 0.0)), 0.0, 0.25)
	if hold > 0.0:
		await get_tree().create_timer(hold).timeout
	for layer in layers:
		layer.queue_free()


func _effect_layer(texture: Texture2D, data: Dictionary, frame_size: Vector2i, origin: Vector2, mirror: bool, z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.centered = false
	var anchor := VisualAsset.anchor(data, Vector2(frame_size) * 0.5)
	if mirror:
		# Struck from the right instead: flip the art about its own anchor.
		sprite.flip_h = true
		anchor.x = frame_size.x - anchor.x
	sprite.offset = -anchor
	sprite.scale = Vector2.ONE * maxf(0.1, float(data.get("scale", 1.0)))
	sprite.z_index = z
	sprite.position = origin
	add_child(sprite)
	return sprite


func _ground_light(feet: Vector2, colour: Color, duration: float, z: int) -> void:
	## Magic lights the floor it lands on: a soft additive pool in the
	## effect's own colour under the target, swelling with the impact and
	## fading out with the effect.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(colour, 0.55))
	gradient.set_color(1, Color(colour, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	var pool := Sprite2D.new()
	pool.texture = texture
	pool.material = CanvasItemMaterial.new()
	(pool.material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	pool.position = feet
	pool.scale = Vector2(0.5, 0.16)
	pool.modulate.a = 0.0
	pool.z_index = z
	add_child(pool)
	var tween := create_tween()
	tween.tween_property(pool, "modulate:a", 1.0, minf(0.12, duration * 0.3))
	tween.parallel().tween_property(pool, "scale", Vector2(0.75, 0.22), minf(0.12, duration * 0.3))
	tween.tween_property(pool, "modulate:a", 0.0, maxf(0.1, duration * 0.7))
	tween.tween_callback(pool.queue_free)


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
	tween.tween_property(outer, "scale", Vector2(1.45, 1.45), FALLBACK_DURATION)
	tween.tween_property(outer, "modulate:a", 0.0, FALLBACK_DURATION)
	tween.tween_property(core, "scale", Vector2(0.45, 0.45), 0.12)
	tween.tween_property(core, "modulate:a", 0.0, 0.14)
	await tween.finished
	outer.queue_free()
	core.queue_free()
