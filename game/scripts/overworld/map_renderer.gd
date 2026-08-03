extends RefCounted
class_name MapRenderer
## Renders an ASCII overworld map as tile layers, props and lighting.
##
## The ASCII map stays the authoritative layout: this class only decides
## how a tile *looks*, never whether it blocks or what it does. It reads
## nothing but the map rows, so walkability, interactions, NPC markers and
## triggers are untouched by anything here.
##
## Terrain autotiling uses a 4-bit neighbour mask (north/east/south/west,
## bit order taken from the manifest) so paths and water grow their own
## transitions against the surrounding land.

const TILE := 16
const ATLAS_DIR := "res://assets/tiles/"
const MANIFEST_PATH := ATLAS_DIR + "tiles_manifest.json"

# Terrain families for autotiling. A tile joins its own family only.
const PATH_CHARS := [":", "S"]
const WATER_CHARS := ["~"]

# Characters that should render as plain ground beneath something else
# (NPC spawn markers and the notice board post).
const GROUND_CHARS := [".", ",", "E", "M", "n"]

var _manifest: Dictionary = {}
var _terrain_source_id := -1
var _prop_source_id := -1
var _tileset: TileSet
var _prop_texture: Texture2D
var _terrain_rows: Array = []   # kept so decals can query the terrain under them


func build(parent: Node2D, rows: Array, decal_rows: Array, decor_rows: Array) -> bool:
	## Construct the visual layers under `parent`. Returns false if the
	## atlas is missing, letting the caller fall back to its old drawing.
	if not _load_manifest():
		return false
	_terrain_rows = rows
	_build_tileset()

	var ground := _make_layer(parent, "GroundLayer", -20)
	var decals := _make_layer(parent, "DecalLayer", -19)
	var overlay := _make_layer(parent, "OverlayLayer", -18)
	_paint_terrain(ground, overlay, rows)
	_paint_decals(decals, decal_rows)
	_place_props(parent, decor_rows)
	return true


func _paint_decals(layer: TileMapLayer, decal_rows: Array) -> void:
	## Flat ground wear. Never affects movement, so unlike props these may
	## sit on walkable tiles.
	for y in decal_rows.size():
		var row: String = decal_rows[y]
		for x in row.length():
			var tile_name := ""
			match row[x]:
				"d":
					tile_name = "dirt_%d" % ((x + y) % 2)
				"g":
					# The verge hugs whichever side the road is on.
					tile_name = "gravel_east" if PATH_CHARS.has(_char_at(_terrain_rows, x + 1, y)) else "gravel_west"
				"F":
					tile_name = "flowerbed"
				"t":
					tile_name = "tallgrass"
			if tile_name != "":
				_put(layer, x, y, tile_name)


func _load_manifest() -> bool:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return false
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("Invalid tiles manifest: %s" % json.get_error_message())
		return false
	_manifest = json.data
	var atlas_path: String = ATLAS_DIR + str(_manifest.get("atlas", ""))
	return ResourceLoader.exists(atlas_path)


func _build_tileset() -> void:
	_tileset = TileSet.new()
	_tileset.tile_size = Vector2i(TILE, TILE)

	var terrain_source := TileSetAtlasSource.new()
	terrain_source.texture = load(ATLAS_DIR + str(_manifest["atlas"]))
	terrain_source.texture_region_size = Vector2i(TILE, TILE)
	for coordinate in _manifest.get("tiles", {}).values():
		terrain_source.create_tile(Vector2i(int(coordinate[0]), int(coordinate[1])))
	_terrain_source_id = _tileset.add_source(terrain_source)

	var props_path: String = ATLAS_DIR + str(_manifest.get("props_atlas", ""))
	if ResourceLoader.exists(props_path):
		_prop_texture = load(props_path)


func _make_layer(parent: Node2D, layer_name: String, z: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = _tileset
	layer.z_index = z
	parent.add_child(layer)
	return layer


func _tile_coord(tile_name: String) -> Vector2i:
	var coordinate: Array = _manifest["tiles"].get(tile_name, [0, 0])
	return Vector2i(int(coordinate[0]), int(coordinate[1]))


func _put(layer: TileMapLayer, x: int, y: int, tile_name: String) -> void:
	if not _manifest["tiles"].has(tile_name):
		push_error("Tile '%s' missing from the atlas manifest." % tile_name)
		return
	layer.set_cell(Vector2i(x, y), _terrain_source_id, _tile_coord(tile_name))


# ── Terrain ──────────────────────────────────────────────────────────

func _char_at(rows: Array, x: int, y: int) -> String:
	if y < 0 or y >= rows.size():
		return "#"
	var row: String = rows[y]
	if x < 0 or x >= row.length():
		return "#"
	return row[x]


func _mask_for(rows: Array, x: int, y: int, family: Array) -> int:
	## Bit set where the neighbour belongs to the same terrain family.
	var bits: Dictionary = _manifest.get("mask_bits", {})
	var mask := 0
	if family.has(_char_at(rows, x, y - 1)):
		mask |= int(bits.get("north", 1))
	if family.has(_char_at(rows, x + 1, y)):
		mask |= int(bits.get("east", 2))
	if family.has(_char_at(rows, x, y + 1)):
		mask |= int(bits.get("south", 4))
	if family.has(_char_at(rows, x - 1, y)):
		mask |= int(bits.get("west", 8))
	return mask


func _grass_variant(x: int, y: int, alt: bool) -> String:
	## Deterministic scatter so the ground has texture without noise for
	## its own sake: most tiles stay plain, a minority carry detail.
	if alt:
		return "grass_4" if (x * 5 + y * 3) % 2 == 0 else "grass_5"
	var pick := (x * 7 + y * 13) % 11
	if pick == 0:
		return "grass_1"
	if pick == 3:
		return "grass_2"
	if pick == 7:
		return "grass_3"
	return "grass_0"


func _paint_terrain(ground: TileMapLayer, overlay: TileMapLayer, rows: Array) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var symbol := row[x]
			# Everything sits on ground, so buildings and props never
			# punch a transparent hole in the map.
			_put(ground, x, y, _grass_variant(x, y, symbol == ","))

			if PATH_CHARS.has(symbol):
				_put(overlay, x, y, "path_%d" % _mask_for(rows, x, y, PATH_CHARS))
			elif WATER_CHARS.has(symbol):
				_put(overlay, x, y, "water_%d" % _mask_for(rows, x, y, WATER_CHARS))
			elif symbol == "#":
				_put(overlay, x, y, "wall_%d" % ((x * 3 + y * 5) % 3))
			elif symbol == "R":
				_put(overlay, x, y, "roof_%s" % _building_kind(rows, x, y, "R"))
			elif symbol == "H":
				_put(overlay, x, y, "house_%s" % _house_kind(rows, x, y))
			elif symbol == "D":
				_put(overlay, x, y, "door")
			elif symbol == "C":
				_put(overlay, x, y, "court_arch")
			elif symbol == "n":
				_put(overlay, x, y, "notice")
			elif not GROUND_CHARS.has(symbol):
				push_warning("Unhandled map symbol '%s' at (%d, %d)." % [symbol, x, y])


func _building_kind(rows: Array, x: int, y: int, symbol: String) -> String:
	var left := _char_at(rows, x - 1, y) == symbol
	var right := _char_at(rows, x + 1, y) == symbol
	if left and right:
		return "mid"
	return "right" if left else "left"


func _house_kind(rows: Array, x: int, y: int) -> String:
	## House walls flank a door; the outer ends get corner framing and
	## the inner spans alternate lit and shuttered windows.
	var left_is_wall := _char_at(rows, x - 1, y) in ["H", "D"]
	var right_is_wall := _char_at(rows, x + 1, y) in ["H", "D"]
	if not left_is_wall:
		return "left"
	if not right_is_wall:
		return "right"
	return "window" if x % 2 == 0 else "shuttered"


# ── Props and lighting ───────────────────────────────────────────────

func _place_props(parent: Node2D, decor_rows: Array) -> void:
	if _prop_texture == null:
		return
	var prop_size: Array = _manifest.get("prop_size", [16, 24])
	var width := int(prop_size[0])
	var height := int(prop_size[1])
	var props: Dictionary = _manifest.get("props", {})

	for y in decor_rows.size():
		var row: String = decor_rows[y]
		for x in row.length():
			var prop_name := _prop_for(row[x], x, y)
			if prop_name == "" or not props.has(prop_name):
				continue
			var coordinate: Array = props[prop_name]
			var sprite := Sprite2D.new()
			sprite.texture = _prop_texture
			sprite.region_enabled = true
			sprite.region_rect = Rect2(
				int(coordinate[0]) * width, int(coordinate[1]) * height, width, height
			)
			sprite.centered = false
			# Props stand on their tile. The node sits at the foot of the
			# cell and the art is offset upward from there, so y-sorting
			# compares where a prop touches the ground — not where its
			# canopy starts — and characters pass behind it correctly.
			sprite.offset = Vector2(0, -height)
			sprite.position = Vector2(x * TILE, (y + 1) * TILE)
			parent.add_child(sprite)

			if prop_name == "lamp":
				_add_glow(parent, Vector2(x * TILE + TILE / 2.0, y * TILE + 4), 1.0)


func _prop_for(symbol: String, x: int, y: int) -> String:
	match symbol:
		"T":
			return "tree_%d" % ((x * 3 + y * 7) % 2)
		"L":
			return "lamp"
		"b":
			return "barrel"
		"c":
			return "crate"
		"w":
			return "well"
		"f":
			return "fence"
	return ""


func _add_glow(parent: Node2D, at: Vector2, scale_factor: float) -> void:
	var glow_path := ATLAS_DIR + "glow.png"
	if not ResourceLoader.exists(glow_path):
		return
	var glow := Sprite2D.new()
	glow.texture = load(glow_path)
	glow.position = at
	glow.scale = Vector2(scale_factor, scale_factor)
	# Additive so lantern pools brighten the ground without washing out
	# the tile detail underneath.
	glow.material = CanvasItemMaterial.new()
	glow.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.z_index = -18
	parent.add_child(glow)
