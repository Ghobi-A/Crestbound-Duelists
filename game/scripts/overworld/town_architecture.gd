extends Node2D
class_name TownArchitecture
## Authored pixel architecture aligned to the authoritative house footprint.
## Each facade spans four blocking cells; the door stays on its interaction cell.
const TILE := 16
const STONE := Color("475365")
const SHADOW := Color("202c3c")
const ROOF := Color("243549")
const TRIM := Color("82909b")
const WINDOW := Color("e6b968")
var door_column := 2

static func place(parent: Node2D, rows: Array) -> void:
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] != "D":
				continue
			var left: int = x
			while left > 0 and rows[y][left - 1] in ["H", "D"]:
				left -= 1
			var house := TownArchitecture.new()
			house.door_column = x - left
			house.position = Vector2(left * TILE, (y + 1) * TILE)
			parent.add_child(house)

func _draw() -> void:
	draw_rect(Rect2(0, -32, 64, 32), SHADOW)
	draw_rect(Rect2(1, -20, 62, 19), STONE)
	for row in 4:
		var y := -20 + row * 5
		draw_line(Vector2(1, y), Vector2(63, y), SHADOW)
		for column in 7:
			var x := column * 10 + (5 if row % 2 else 0)
			draw_line(Vector2(x, y), Vector2(x, y + 4), SHADOW)
	draw_rect(Rect2(0, -32, 64, 13), ROOF)
	for row in 3:
		draw_line(Vector2(0, -31 + row * 4), Vector2(63, -31 + row * 4), Color("40536a"))
	draw_rect(Rect2(0, -20, 64, 2), TRIM)
	draw_rect(Rect2(1, -2, 62, 2), Color("697381"))
	for column in 4:
		var x := column * TILE + 3
		if column == door_column:
			draw_rect(Rect2(x - 1, -16, 12, 16), TRIM)
			draw_rect(Rect2(x, -15, 10, 15), Color("382e30"))
			draw_rect(Rect2(x + 2, -13, 6, 10), Color("5b4640"))
			draw_rect(Rect2(x + 7, -7, 1, 2), WINDOW)
		else:
			draw_rect(Rect2(x, -14, 10, 10), SHADOW)
			draw_rect(Rect2(x + 1, -13, 8, 7), WINDOW)
			draw_rect(Rect2(x + 4, -13, 1, 8), SHADOW)
			draw_rect(Rect2(x - 1, -5, 12, 2), TRIM)
