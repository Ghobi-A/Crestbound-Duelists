extends Node2D
class_name WorldTerrain
## The original texture kit spans four tiles per material to avoid a stamped grid.
var rows: Array = []
var interior := false
const TILE := 16
const MATERIAL_TILES := 4
var texture: Texture2D = preload("res://assets/environment/terrain.png")
var clock := 0.0

func _process(delta: float) -> void:
	clock += delta
	if int(clock*4) != int((clock-delta)*4): queue_redraw()

func _draw() -> void:
	var quadrant := texture.get_size()/2.0
	var source_cell := quadrant/float(MATERIAL_TILES)
	for y in rows.size():
		for x in rows[y].length():
			var p := Vector2(x*TILE,y*TILE)
			var symbol: String = rows[y][x]
			var material := Vector2(1,0)
			if symbol in [":","^"]: material = Vector2.ZERO
			elif symbol == "w": material = Vector2(0,1)
			elif symbol == "#": material = Vector2(1,1)
			var source := material*quadrant + Vector2(x%MATERIAL_TILES,y%MATERIAL_TILES)*source_cell
			draw_texture_rect_region(texture,Rect2(p,Vector2(16,16)),Rect2(source,source_cell))
			if symbol == "_": draw_rect(Rect2(p,Vector2(16,16)),Color("090f19"))
			elif symbol == "^":
				draw_line(p,p+Vector2(15,0),Color("65727a"))
				draw_line(p+Vector2(0,14),p+Vector2(15,14),Color("202c37"))
			elif symbol == "#":
				draw_rect(Rect2(p,Vector2(16,16)),Color(0.02,0.04,0.08,0.2))
				if interior: draw_line(p+Vector2(0,15),p+Vector2(15,15),Color("59646a"))
			elif symbol == "~":
				draw_rect(Rect2(p,Vector2(16,16)),Color("14283c"))
				var phase := int(clock*4+x+y)%7
				draw_line(p+Vector2(phase,4),p+Vector2(phase+5,4),Color("578197"))
				draw_line(p+Vector2(2,11),p+Vector2(7,11),Color("294b66"))
			elif symbol == "=":
				draw_rect(Rect2(p,Vector2(16,16)),Color("302f30"))
				for board in 4: draw_rect(Rect2(p+Vector2(0,board*4),Vector2(16,3)),Color("6a5340"))
