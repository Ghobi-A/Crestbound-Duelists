extends Node2D
class_name PaintedInterior
## Painted interior room (locations with a "painted_interior" block): the
## room shader, back-wall decor (windows, banners, candle sconces), a rug,
## potted plants and candle/window lighting. Presentation only; collision
## still reads the map rows and the authored furniture props.

const DIRECTORY := "res://assets/environment/painted/"
const ROOM := preload("res://scripts/overworld/painted_interior.gdshader")
const PASSES := [preload("res://scripts/overworld/painted_interior_shade.gdshader"), preload("res://scripts/overworld/painted_interior_glow.gdshader")]
const TILE := 16
const WALL_ROWS := 2
# Display widths (logical px) of decor, scaled from their source art.
const WIDTHS := {"window": 20.0, "banner": 11.0, "sconce": 9.0, "plant": 15.0}

var rows: Array = []
var props: Array = []
var lights: Array = []
var floor_rect := Rect2i()
var door_rect := Rect2i()
var windows: Array[float] = []
var sconces: Array[Vector2] = []


func setup(location: Dictionary) -> void:
	rows = location.rows
	props = location.props
	lights = location.lights
	floor_rect = _bounds(["w", ":"])
	door_rect = _bounds([":"])


func _ready() -> void:
	var room := ShaderMaterial.new()
	room.shader = ROOM
	room.set_shader_parameter("floor_tex", load(DIRECTORY + "wood_floor.png"))
	room.set_shader_parameter("wall_tex", load(DIRECTORY + "stone_wall.png"))
	room.set_shader_parameter("stone_tex", load(DIRECTORY + "cobble.png"))
	room.set_shader_parameter("noise_tex", load(DIRECTORY + "noise.png"))
	room.set_shader_parameter("floor_rect", _vec4(floor_rect))
	room.set_shader_parameter("door_rect", _vec4(door_rect))
	room.set_shader_parameter("wall_rows", float(WALL_ROWS))
	material = room
	_dress_back_wall()
	_dress_floor()
	if GraphicsSettings.lighting():
		_build_light()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(str(rows[0]).length(), rows.size()) * TILE), Color.WHITE)


func _bounds(symbols: Array) -> Rect2i:
	var found := Rect2i()
	var first := true
	for y in rows.size():
		for x in str(rows[y]).length():
			if symbols.has(str(rows[y])[x]):
				var cell := Rect2i(x, y, 1, 1)
				found = cell if first else found.merge(cell)
				first = false
	return found


static func _vec4(r: Rect2i) -> Vector4:
	return Vector4(r.position.x, r.position.y, r.end.x, r.end.y)


func _wall_columns_in_use() -> Dictionary:
	## Columns hidden behind furniture standing against the back wall.
	var used := {}
	for item in props:
		var footprint := WorldCatalog.footprint(item)
		if footprint.position.y > floor_rect.position.y + 2:
			continue
		var width := float(WorldCatalog.asset(str(item.asset)).width) / TILE
		var centre := float(WorldCatalog.tile(item.tile).x) + 0.5
		for x in range(floor(centre - width / 2.0 - 0.2), ceil(centre + width / 2.0 + 0.2)):
			used[x] = true
	return used


func _dress_back_wall() -> void:
	## Windows, banners and candle sconces fill the free stretches of the
	## back wall, alternating so no two of a kind sit side by side.
	var used := _wall_columns_in_use()
	var wall_foot := float(floor_rect.position.y * TILE)
	var x := floor_rect.position.x
	var kinds := ["window", "sconce", "banner", "sconce"]
	var turn := 0
	while x < floor_rect.end.x:
		var free_run := 0
		while x + free_run < floor_rect.end.x and not used.has(x + free_run):
			free_run += 1
		if free_run < 2:
			x += maxi(1, free_run)
			continue
		var kind: String = kinds[turn % kinds.size()]
		if kind == "window" and free_run < 2:
			kind = "banner"
		var centre := (x + (1.0 if kind == "window" else 0.5)) * TILE
		match kind:
			"window":
				_decor("window", Vector2(centre, wall_foot - 3), -14)
				windows.append(centre / TILE)
			"banner":
				_decor("banner", Vector2(centre, wall_foot - 6), -14)
			"sconce":
				_decor("sconce", Vector2(centre, wall_foot - 12), -14)
				sconces.append(Vector2(centre, wall_foot - 19))
		turn += 1
		x += 3 if kind == "window" else 2


func _dress_floor() -> void:
	# The rug sits under the room's centre, below the furniture.
	var rug_tex: Texture2D = load(DIRECTORY + "rug.png")
	var rug := Sprite2D.new()
	rug.texture = rug_tex
	rug.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var width := minf(floor_rect.size.x * 0.42, 7.0) * TILE
	rug.scale = Vector2.ONE * width / rug_tex.get_width()
	rug.position = (Vector2(floor_rect.position) + Vector2(floor_rect.size) * Vector2(0.5, 0.55)) * TILE
	rug.z_as_relative = false
	rug.z_index = -18
	add_child(rug)
	# Potted plants stand on the side walls' blocked tiles, leaning into the
	# room, beside any floor tile that furniture does not already use.
	var occupied := {}
	for item in props:
		var footprint := WorldCatalog.footprint(item)
		for y in range(footprint.position.y, footprint.end.y):
			for xx in range(footprint.position.x, footprint.end.x):
				occupied[Vector2i(xx, y)] = true
	for cell in [Vector2i(floor_rect.position.x, floor_rect.position.y + 1), Vector2i(floor_rect.end.x - 1, floor_rect.position.y + 1),
			Vector2i(floor_rect.position.x, floor_rect.end.y - 2), Vector2i(floor_rect.end.x - 1, floor_rect.end.y - 2)]:
		if occupied.has(cell) or occupied.has(cell + Vector2i.UP):
			continue
		var wall_x: int = cell.x - 1 if cell.x == floor_rect.position.x else cell.x + 1
		var lean := 6.0 if wall_x < cell.x else -6.0
		get_parent().add_child.call_deferred(_decor_sprite("plant", Vector2(wall_x * TILE + 8 + lean, cell.y * TILE + 14), 0))


func _decor(kind: String, foot: Vector2, z: int) -> void:
	add_child(_decor_sprite(kind, foot, z))


func _decor_sprite(kind: String, foot: Vector2, z: int) -> Sprite2D:
	var texture: Texture2D = load(DIRECTORY + kind + ".png")
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.centered = false
	sprite.offset = Vector2(-texture.get_width() / 2.0, -texture.get_height())
	sprite.scale = Vector2.ONE * float(WIDTHS[kind]) / texture.get_width()
	sprite.position = foot
	if z != 0:
		# Wall decor sits behind everything; z is absolute, not relative to
		# this node's own -20.
		sprite.z_as_relative = false
		sprite.z_index = z
	return sprite


func _build_light() -> void:
	var points := PackedVector2Array()
	for light in lights:
		points.append(Vector2(WorldCatalog.tile(light.tile)) + Vector2(0.5, 0.6))
	for sconce in sconces:
		points.append(sconce / TILE + Vector2(0, 1.2))
	var shafts := PackedFloat32Array(windows)
	for i in PASSES.size():
		var pass_node := Node2D.new()
		pass_node.z_as_relative = false
		pass_node.z_index = 30 + i
		var shader := ShaderMaterial.new()
		shader.shader = PASSES[i]
		shader.set_shader_parameter("noise_tex", load(DIRECTORY + "noise.png"))
		shader.set_shader_parameter("lights", points)
		shader.set_shader_parameter("light_count", mini(points.size(), 8))
		shader.set_shader_parameter("windows", shafts)
		shader.set_shader_parameter("window_count", mini(shafts.size(), 4))
		shader.set_shader_parameter("floor_rect", _vec4(floor_rect))
		pass_node.material = shader
		pass_node.draw.connect(func(): pass_node.draw_rect(Rect2(Vector2.ZERO, Vector2(str(rows[0]).length(), rows.size()) * TILE), Color.WHITE))
		add_child(pass_node)
