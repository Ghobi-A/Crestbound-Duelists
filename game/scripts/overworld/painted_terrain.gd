extends Node2D
class_name PaintedTerrain
## Outdoor ground for locations with a "painted" block: one shader-drawn
## rect over the whole map (see painted_terrain.gdshader). Presentation only;
## WorldLocation keeps reading the map rows for collision and encounters.

const DIRECTORY := "res://assets/environment/painted/"
const SHADER := preload("res://scripts/overworld/painted_terrain.gdshader")
const TILE := 16

var location_id := ""
var rows: Array = []
var path_material := "dirt"


func _ready() -> void:
	var fields_path := DIRECTORY + "fields_%s.png" % location_id
	if not ResourceLoader.exists(fields_path):
		push_error("PaintedTerrain: missing material fields " + fields_path)
		return
	var shader := ShaderMaterial.new()
	shader.shader = SHADER
	shader.set_shader_parameter("fields", load(fields_path))
	shader.set_shader_parameter("noise_tex", load(DIRECTORY + "noise.png"))
	for uniform_name in ["grass", "water"]:
		shader.set_shader_parameter(uniform_name + "_tex", load(DIRECTORY + uniform_name + ".png"))
	shader.set_shader_parameter("path_tex", load(DIRECTORY + path_material + ".png"))
	shader.set_shader_parameter("tall_tex", load(DIRECTORY + "tall_grass.png"))
	shader.set_shader_parameter("map_tiles", map_tiles())
	shader.set_shader_parameter("detail", GraphicsSettings.terrain_detail())
	material = shader


func map_tiles() -> Vector2:
	return Vector2(str(rows[0]).length(), rows.size())


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, map_tiles() * TILE), Color.WHITE)
