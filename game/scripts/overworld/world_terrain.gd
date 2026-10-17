extends Node2D
class_name WorldTerrain
## Each material is a tileable quadrant of the painted kit, drawn across 2x2 tiles.
var rows: Array = []
var interior := false
const TILE := 16
# Each tileable material quadrant spans 2x2 tiles (it used to span 4x4), so
# a 16px tile samples ~313 source px: cobbles, planks and grass sit at a
# believable scale beside 24px characters. The quadrant still repeats
# seamlessly because each material is authored as a tileable block.
const MATERIAL_TILES := 2
const SOURCE_INSET := 2.0
var texture: Texture2D = preload("res://assets/environment/terrain.png")
var clock := 0.0

func _ready() -> void:
	# The painted terrain kit is ~157px per tile; filter it down to the output scale.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _process(delta: float) -> void:
	clock += delta
	if int(clock*4) != int((clock-delta)*4): queue_redraw()

func _material(symbol: String) -> Vector2:
	if symbol in [":","^"]: return Vector2.ZERO
	if symbol == "w": return Vector2(0,1)
	if symbol == "#": return Vector2(1,1)
	return Vector2(1,0)

func _symbol(x: int, y: int) -> String:
	if y < 0 or y >= rows.size() or x < 0 or x >= rows[y].length(): return ""
	return rows[y][x]

func _draw_edges() -> void:
	## Grass meets paving through a soft soil fringe rather than a hard
	## tile seam. Presentation only; collision reads `rows`.
	var soil := Color(0.12, 0.09, 0.05)
	for y in rows.size():
		for x in rows[y].length():
			if _symbol(x,y) != ":": continue
			var p := Vector2(x*TILE,y*TILE)
			for side in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
				var other := _symbol(x+side.x,y+side.y)
				if other == "" or _material(other) != Vector2(1,0) or other in ["~","=","_"]: continue
				for step in 4:
					var alpha: float = [0.26,0.16,0.09,0.04][step]
					var inset := float(step)*1.5
					var strip: Rect2
					match side:
						Vector2i.UP: strip = Rect2(p+Vector2(0,inset),Vector2(16,1.5))
						Vector2i.DOWN: strip = Rect2(p+Vector2(0,14.5-inset),Vector2(16,1.5))
						Vector2i.LEFT: strip = Rect2(p+Vector2(inset,0),Vector2(1.5,16))
						_: strip = Rect2(p+Vector2(14.5-inset,0),Vector2(1.5,16))
					draw_rect(strip,Color(soil,alpha))

func _draw() -> void:
	var quadrant := texture.get_size()/2.0
	var source_cell := quadrant/float(MATERIAL_TILES)
	var cycle := MATERIAL_TILES
	for y in rows.size():
		for x in rows[y].length():
			var p := Vector2(x*TILE,y*TILE)
			var symbol: String = rows[y][x]
			var material := _material(symbol)
			# Outdoors the map edge is undergrowth, not masonry.
			if symbol == "#" and not interior: material = Vector2(1,0)
			var source := material*quadrant + Vector2(x%cycle,y%cycle)*source_cell
			# Inset a few source px so filtered/mipmapped sampling never pulls in
			# the neighbouring material quadrant as a faint grid line.
			draw_texture_rect_region(texture,Rect2(p,Vector2(16,16)),Rect2(source+Vector2.ONE*SOURCE_INSET,source_cell-Vector2.ONE*SOURCE_INSET*2.0))
			if symbol == "|":
				draw_rect(Rect2(p+Vector2(1,7),Vector2(14,2)),Color("82623f"))
				draw_rect(Rect2(p+Vector2(1,12),Vector2(14,2)),Color("61482f"))
				for post in [2,12]:
					draw_rect(Rect2(p+Vector2(post,4),Vector2(2,12)),Color("4b3928"))
					draw_rect(Rect2(p+Vector2(post,3),Vector2(2,2)),Color("a38758"))
			elif symbol == "r":
				draw_rect(Rect2(p+Vector2(2,7),Vector2(12,7)),Color("30373b"))
				draw_rect(Rect2(p+Vector2(3,5),Vector2(9,7)),Color("6b7070"))
				draw_rect(Rect2(p+Vector2(5,4),Vector2(6,2)),Color("93988b"))
				draw_rect(Rect2(p+Vector2(10,8),Vector2(2,4)),Color("4d5556"))
			elif symbol == ",":
				draw_rect(Rect2(p,Vector2(16,16)),Color(0.40,0.29,0.13,0.85))
				for mark in 3: draw_rect(Rect2(p+Vector2((x*3+mark*5)%15,(y*5+mark*3)%15),Vector2(2,1)),Color("80683c"))
			elif symbol == "g":
				for blade in 6:
					var q := p + Vector2((blade*5+x)%15, 4+(blade*3+y)%11)
					draw_line(q,q+Vector2(-2,-4),Color("436c35"),1)
					draw_line(q,q+Vector2(2,-5),Color("648944"),1)
			elif symbol == "f":
				for flower in 3:
					var q := p+Vector2(3+flower*5,4+(x+y+flower*3)%10)
					draw_rect(Rect2(q,Vector2(2,2)),Color("d6b875") if flower%2 == 0 else Color("b18db1"))
			elif symbol == "_": draw_rect(Rect2(p,Vector2(16,16)),Color("090f19"))
			elif symbol == "^":
				# Edge marks are 1 logical px rects so they keep their weight at 2x-6x.
				draw_rect(Rect2(p,Vector2(16,1)),Color("65727a"))
				draw_rect(Rect2(p+Vector2(0,14),Vector2(16,1)),Color("202c37"))
			elif symbol == "#" and not interior:
				draw_rect(Rect2(p,Vector2(16,16)),Color(0.01,0.03,0.02,0.62))
			elif symbol == "#":
				draw_rect(Rect2(p,Vector2(16,16)),Color(0.02,0.04,0.08,0.2))
				if interior: draw_rect(Rect2(p+Vector2(0,15),Vector2(16,1)),Color("59646a"))
			elif symbol == "~":
				draw_rect(Rect2(p,Vector2(16,16)),Color("14283c"))
				var phase := int(clock*4+x+y)%7
				draw_rect(Rect2(p+Vector2(phase,4),Vector2(6,1)),Color("578197"))
				draw_rect(Rect2(p+Vector2(2,11),Vector2(6,1)),Color("294b66"))
			elif symbol == "=":
				draw_rect(Rect2(p,Vector2(16,16)),Color("302f30"))
				for board in 4: draw_rect(Rect2(p+Vector2(0,board*4),Vector2(16,3)),Color("6a5340"))
	if not interior: _draw_edges()
