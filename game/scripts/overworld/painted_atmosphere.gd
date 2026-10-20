extends Node2D
class_name PaintedAtmosphere
## Sun lighting, grading and foreground depth for painted outdoor maps.
## Presentation only. Layers, cheapest first, gated by GraphicsSettings:
##   Low    — none (painted terrain and props only)
##   Medium — canopy shade, sun shafts, colour grade and vignette
##   High   — Medium plus tilt-shift, bloom and drifting foreground foliage

const DIRECTORY := "res://assets/environment/painted/"
const PASSES := [preload("res://scripts/overworld/painted_shade.gdshader"), preload("res://scripts/overworld/painted_sun.gdshader")]
const GRADE := preload("res://scripts/presentation/screen_grade.gdshader")
const FOUNTAIN := preload("res://scripts/overworld/fountain_shimmer.gdshader")
# Where the lit parts of authored props sit relative to the prop's tile
# origin (measured from the source art): the lamp's lantern, the spring's
# basin (centre and half-size) and its spout column.
const LANTERN := Vector2(11.8, -5.7)
const BASIN := Rect2(Vector2(-16.5, -14.0), Vector2(50, 18))
const SPOUT := Rect2(Vector2(6.5, -39.0), Vector2(3, 24))
const TILE := 16
# Screen-space foliage framing the corners: texture, logical position,
# scale, flip. Kept to the frame edges so the player stays unobstructed.
const FOREGROUND := [
	["leaves_blur", Vector2(-22, 118), 0.62, false],
	["leaves_blur", Vector2(268, 128), 0.56, true],
	["leaves_blur", Vector2(-30, -26), 0.42, false],
]

var location_id := ""
var map_tiles := Vector2.ONE
var props: Array = []
var _halos: Array[Sprite2D] = []
var _foreground: Array[Sprite2D] = []
var _clock := 0.0


func _ready() -> void:
	if not GraphicsSettings.lighting():
		return
	var fields: Texture2D = load(DIRECTORY + "fields_%s.png" % location_id)
	for i in PASSES.size():
		var pass_node := Node2D.new()
		pass_node.z_index = 30 + i
		var shader := ShaderMaterial.new()
		shader.shader = PASSES[i]
		shader.set_shader_parameter("fields", fields)
		shader.set_shader_parameter("noise_tex", load(DIRECTORY + "noise.png"))
		shader.set_shader_parameter("map_tiles", map_tiles)
		pass_node.material = shader
		pass_node.draw.connect(func(): pass_node.draw_rect(Rect2(Vector2.ZERO, map_tiles * TILE), Color.WHITE))
		add_child(pass_node)
	_build_prop_lights()
	_build_grade()
	if GraphicsSettings.post_blur():
		_build_foreground()


func _build_prop_lights() -> void:
	## Warm halos on lanterns and moving light on the fountain basin.
	var halo := GradientTexture2D.new()
	halo.fill = GradientTexture2D.FILL_RADIAL
	halo.fill_from = Vector2(0.5, 0.5)
	halo.fill_to = Vector2(1.0, 0.5)
	halo.width = 64
	halo.height = 64
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.78, 0.42, 0.55))
	ramp.set_color(1, Color(1.0, 0.6, 0.25, 0.0))
	ramp.add_point(0.35, Color(1.0, 0.72, 0.36, 0.22))
	halo.gradient = ramp
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for item in props:
		var origin := Vector2(WorldCatalog.tile(item.tile) * TILE)
		if str(item.asset) == "lamp":
			var sprite := Sprite2D.new()
			sprite.texture = halo
			sprite.material = additive
			sprite.position = origin + LANTERN
			sprite.scale = Vector2.ONE * 0.42
			sprite.z_index = 32
			add_child(sprite)
			_halos.append(sprite)
		elif str(item.asset) == "spring":
			var shimmer := Node2D.new()
			var shader := ShaderMaterial.new()
			shader.shader = FOUNTAIN
			shader.set_shader_parameter("noise_tex", load(DIRECTORY + "noise.png"))
			shimmer.material = shader
			shimmer.position = origin
			shimmer.z_index = 32
			shimmer.draw.connect(func():
				shimmer.draw_texture_rect(halo, BASIN, false)
				shimmer.draw_rect(SPOUT, Color(1, 1, 1, 0.12)))
			add_child(shimmer)


func _build_grade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	var rect := ColorRect.new()
	rect.size = PresentationLayout.CANVAS
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := ShaderMaterial.new()
	shader.shader = GRADE
	shader.set_shader_parameter("blur_enabled", GraphicsSettings.post_blur())
	rect.material = shader
	layer.add_child(rect)


func _build_foreground() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	for item in FOREGROUND:
		var path: String = DIRECTORY + str(item[0]) + ".png"
		if not ResourceLoader.exists(path):
			continue
		var sprite := Sprite2D.new()
		sprite.texture = load(path)
		sprite.centered = false
		sprite.position = item[1]
		sprite.scale = Vector2.ONE * float(item[2])
		sprite.flip_h = bool(item[3])
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.set_meta("home", item[1])
		layer.add_child(sprite)
		_foreground.append(sprite)


func _process(delta: float) -> void:
	_clock += delta
	for i in _halos.size():
		# Slow candle-like flicker, desynchronised per lantern.
		_halos[i].modulate.a = 0.82 + 0.12 * sin(_clock * 2.3 + i * 1.9) + 0.06 * sin(_clock * 5.1 + i)
	# Foreground foliage sways a little and drifts against the camera, which
	# reads as depth without a per-frame parallax setup.
	var camera := get_viewport().get_camera_2d()
	var drift := Vector2.ZERO if camera == null else (camera.get_screen_center_position() / (map_tiles * TILE) - Vector2(0.5, 0.5)) * Vector2(-14, -8)
	for i in _foreground.size():
		var home: Vector2 = _foreground[i].get_meta("home")
		_foreground[i].position = home + drift + Vector2(sin(_clock * 0.6 + i) * 1.2, cos(_clock * 0.45 + i * 1.7) * 0.8)
