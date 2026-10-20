extends RefCounted
class_name PaintedDressing
## Decorative props for painted outdoor maps: flowering shrubs soften the
## forest edge and rocks sit along the shoreline. Placement is a fixed
## coordinate hash, so a map always dresses identically, and only ever on
## tiles that are already blocked, so walkable ground and encounter grass
## stay readable and collision is untouched.

const DIRECTORY := "res://assets/environment/painted/"
const TILE := 16
const SHRUB_WIDTH := 30.0
const ROCK_WIDTH := 21.0


static func _h(x: int, y: int, salt: int) -> int:
	return WorldTerrain._h(x, y, salt)


static func build(parent: Node, rows: Array, occupied: Dictionary) -> int:
	var shrub: Texture2D = load(DIRECTORY + "bush.png")
	var rock: Texture2D = load(DIRECTORY + "rocks.png")
	var placed := 0
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var cell := Vector2i(x, y)
			if occupied.has(cell):
				continue
			var symbol := row[x]
			if symbol == "#" and _touches(rows, cell, func(s): return s != "#" and s != "~") and _h(x, y, 301) % 2 == 0:
				parent.add_child(_sprite(shrub, cell, SHRUB_WIDTH, _h(x, y, 302)))
				placed += 1
			elif symbol == "~" and _touches(rows, cell, func(s): return s != "~") and _h(x, y, 303) % 2 == 0:
				parent.add_child(_sprite(rock, cell, ROCK_WIDTH, _h(x, y, 304)))
				placed += 1
	return placed


static func _touches(rows: Array, cell: Vector2i, test: Callable) -> bool:
	for side in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var c: Vector2i = cell + side
		if c.y < 0 or c.y >= rows.size() or c.x < 0 or c.x >= str(rows[c.y]).length():
			continue
		if test.call(str(rows[c.y])[c.x]):
			return true
	return false


static func _sprite(texture: Texture2D, cell: Vector2i, width: float, roll: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.centered = false
	var scale := width / texture.get_width() * (0.85 + float(roll % 30) / 100.0)
	sprite.scale = Vector2.ONE * scale
	sprite.flip_h = roll & 64 != 0
	# Bottom-centre anchored on the tile's lower edge, jittered a little so
	# rows of dressing never line up on the grid.
	sprite.offset = Vector2(-texture.get_width() / 2.0, -texture.get_height())
	sprite.position = Vector2(cell.x * TILE + 8 + (roll % 13) - 6, cell.y * TILE + 15 + (roll / 13) % 4)
	# Dressing sits in canopy shade; lift it so it reads as foliage, not a hole.
	sprite.modulate = Color(1.12, 1.12, 1.05)
	return sprite
