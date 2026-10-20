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
# Outdoor forest depth (1 = touches open ground, capped at 3); see _forest_depths.
var _depth: Dictionary = {}
const ROAD_BASE := [Color("4f3b21"), Color("5b4427"), Color("634b2b")]
const ROAD_FLECKS := [Color("745a35"), Color("3d2d18"), Color("806a48")]
const VERGE := Color("27351c")
const VERGE_RIM := Color("362816")
const BLADES := [Color("34522a"), Color("446a31"), Color("57803d")]
const BLADE_TIP := Color("79a052")
const BLADE_ROOT := Color("1d2a15")
const PETALS := [Color("c8ad69"), Color("a588a4"), Color("cfc6b2")]

func _ready() -> void:
	# The painted terrain kit is ~157px per tile; filter it down to the output scale.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if not interior: _forest_depths()

## Deterministic integer hash: every scatter decision derives from tile
## coordinates, so the same map always renders identically.
static func _h(x: int, y: int, salt: int) -> int:
	var n := (x * 374761393 + y * 668265263 + salt * 1442695041) & 0xffffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
	return (n ^ (n >> 16)) & 0x7fffffff

## Smooth low-frequency value noise in [0,1]; ten units per lattice cell.
static func _tone(x: int, y: int) -> float:
	var fx := float(x) / 10.0
	var fy := float(y) / 10.0
	var ix := int(floor(fx))
	var iy := int(floor(fy))
	var tx := smoothstep(0.0, 1.0, fx - ix)
	var ty := smoothstep(0.0, 1.0, fy - iy)
	var a := lerpf(float(_h(ix,iy,9)%1000), float(_h(ix+1,iy,9)%1000), tx)
	var b := lerpf(float(_h(ix,iy+1,9)%1000), float(_h(ix+1,iy+1,9)%1000), tx)
	return lerpf(a, b, ty) / 1000.0

func _forest_depths() -> void:
	## Breadth-first distance from open ground, so canopy shade deepens
	## gradually instead of ending in a hard-edged black rectangle.
	var frontier: Array[Vector2i] = []
	for y in rows.size():
		for x in rows[y].length():
			if _symbol(x,y) != "#": continue
			for side in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
				var other := _symbol(x+side.x,y+side.y)
				if other != "" and other != "#":
					_depth[Vector2i(x,y)] = 1
					frontier.append(Vector2i(x,y))
					break
	for level in [2,3]:
		var next: Array[Vector2i] = []
		for cell in frontier:
			for side in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
				var c: Vector2i = cell + side
				if _symbol(c.x,c.y) == "#" and not _depth.has(c):
					_depth[c] = level
					next.append(c)
		frontier = next

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
			var cell := Vector2(x%cycle,y%cycle)
			var mirror := Vector2.ONE
			if not interior and material == Vector2(1,0):
				# Mirror whole tileable blocks at random: neighbouring blocks still
				# meet on matching (mirrored) edges, but the 2x2 repeat disappears.
				var flip := _h(x/cycle,y/cycle,1)
				if flip & 1:
					cell.x = cycle-1-cell.x
					mirror.x = -1
				if flip & 2:
					cell.y = cycle-1-cell.y
					mirror.y = -1
			var source := material*quadrant + cell*source_cell
			# Inset a few source px so filtered/mipmapped sampling never pulls in
			# the neighbouring material quadrant as a faint grid line.
			draw_set_transform(p+Vector2(8,8),0.0,mirror)
			draw_texture_rect_region(texture,Rect2(Vector2(-8,-8),Vector2(16,16)),Rect2(source+Vector2.ONE*SOURCE_INSET,source_cell-Vector2.ONE*SOURCE_INSET*2.0))
			draw_set_transform(Vector2.ZERO)
			if not interior and _draw_outdoor(symbol,x,y,p): continue
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
	if not interior:
		_draw_edges()
		_draw_transitions()

# ── Outdoor terrain dressing (presentation only; collision reads `rows`) ──

func _draw_outdoor(symbol: String, x: int, y: int, p: Vector2) -> bool:
	## Returns true when the tile was fully dressed here.
	match symbol:
		".", "f", "g":
			# Broad, faint tonal drift breaks up the uniform field.
			# Sampled per 8px quadrant so the drift has no tile-sized steps.
			for q in 4:
				var t := _tone(x*2+q%2,y*2+q/2)
				var r := Rect2(p+Vector2(q%2,q/2)*8,Vector2(8,8))
				if t < 0.4: draw_rect(r,Color(0.02,0.04,0.02,(0.4-t)*0.16))
				elif t > 0.62: draw_rect(r,Color(0.35,0.30,0.12,(t-0.62)*0.12))
			if symbol == "f": _draw_flowers(x,y,p)
			elif symbol == "g": _draw_tall_grass(x,y,p)
			else: _draw_ground_detail(x,y,p)
			return true
		",":
			_draw_road(x,y,p)
			return true
		"#":
			var depth: int = _depth.get(Vector2i(x,y),3)
			draw_rect(Rect2(p,Vector2(16,16)),Color(0.01,0.025,0.015,[0.0,0.22,0.44,0.62][depth]))
			if depth < 3: _draw_canopy_deepening(x,y,p,depth)
			return true
		"r", "|":
			# Route rocks and fences are authored props on these tiles; the
			# old procedural blocks only doubled them up.
			return true
	return false

func _draw_ground_detail(x: int, y: int, p: Vector2) -> void:
	var roll := _h(x,y,2) % 100
	var q := p + Vector2(2+_h(x,y,3)%11, 4+_h(x,y,4)%10)
	if roll < 6:
		draw_rect(Rect2(q+Vector2(0,1),Vector2(3,1)),Color(0.05,0.05,0.03,0.6))
		draw_rect(Rect2(q,Vector2(2,1)),Color("6f6a5b"))
	elif roll < 15:
		for blade in 3:
			var b := q + Vector2(blade*2-2,0)
			draw_line(b,b+Vector2(blade-1,-2-blade%2),BLADES[(blade+x)%2],1)
	elif roll < 19:
		draw_rect(Rect2(q,Vector2(3,2)),Color(0.20,0.15,0.07,0.45))
		draw_rect(Rect2(q+Vector2(1,-1),Vector2(2,1)),Color(0.20,0.15,0.07,0.3))

func _draw_flowers(x: int, y: int, p: Vector2) -> void:
	_draw_ground_detail(x,y,p)
	for flower in 1 + _h(x,y,5)%2:
		var q := p + Vector2(2+_h(x,y,6+flower)%11, 5+_h(x,y,8+flower)%9)
		var petal: Color = PETALS[_h(x,y,10+flower)%PETALS.size()]
		draw_rect(Rect2(q+Vector2(1,2),Vector2(1,2)),BLADES[0])
		draw_rect(Rect2(q+Vector2(0,1),Vector2(3,1)),petal.darkened(0.25))
		draw_rect(Rect2(q+Vector2(1,0),Vector2(1,3)),petal.darkened(0.1))
		draw_rect(Rect2(q+Vector2(1,1),Vector2(1,1)),petal.lightened(0.25))

func _draw_tall_grass(x: int, y: int, p: Vector2) -> void:
	# Patch edges thin out, so tall grass feathers into the meadow.
	var inner := 0
	for side in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
		if _symbol(x+side.x,y+side.y) == "g": inner += 1
	draw_rect(Rect2(p,Vector2(16,16)),Color(0.04,0.07,0.03,0.16 if inner == 4 else 0.08))
	var tufts := 2 + _h(x,y,11)%2 + (1 if inner == 4 else 0)
	for tuft in tufts:
		var k := 20 + tuft*7
		var q := p + Vector2(1+_h(x,y,k)%13, 7+_h(x,y,k+1)%9)
		var tall := 4 + _h(x,y,k+2)%3 - (1 if inner < 3 else 0)
		draw_rect(Rect2(q+Vector2(-2,0),Vector2(6,1)),BLADE_ROOT)
		for blade in 3:
			var lean := blade-1
			var height := tall - absi(lean) + _h(x,y,k+3+blade)%2
			var tip := q + Vector2(lean*2, -height)
			draw_line(q+Vector2(lean,0),tip,BLADES[(blade + _h(x,y,k+6))%3],1)
			if blade == 1: draw_rect(Rect2(tip,Vector2(1,1)),BLADE_TIP)

func _road_bite(along: int, line: int, salt: int) -> int:
	## Verge depth (0-5px) varies smoothly along each road edge.
	var a := _h(along/4, line, salt) % 6
	var b := _h(along/4+1, line, salt) % 6
	return int(round(lerpf(a, b, float(along%4)/4.0)))

func _draw_road(x: int, y: int, p: Vector2) -> void:
	var base: Color = ROAD_BASE[1]
	draw_rect(Rect2(p,Vector2(16,16)),base)
	# Packed and dusty stretches drift gently, sampled per 8px quadrant.
	for q in 4:
		var t := _tone(x*2+q%2+31,y*2+q/2+17)
		var shade: Color = ROAD_BASE[0] if t < 0.5 else ROAD_BASE[2]
		draw_rect(Rect2(p+Vector2(q%2,q/2)*8,Vector2(8,8)),Color(shade,absf(t-0.5)*1.2))
	# Darker worn mottling at 4px resolution keeps the dirt from reading flat.
	for patch in 3:
		var m := Vector2(_h(x,y,40+patch)%4, _h(x,y,43+patch)%4)*4
		draw_rect(Rect2(p+m,Vector2(4,4)),Color(base.darkened(0.1),0.3))
	for fleck in 3 + _h(x,y,46)%3:
		var q := p + Vector2(_h(x,y,50+fleck)%15, _h(x,y,60+fleck)%15)
		var c: Color = ROAD_FLECKS[_h(x,y,70+fleck)%3]
		draw_rect(Rect2(q,Vector2(1+_h(x,y,80+fleck)%2,1)),c)
	if _h(x,y,90)%9 == 0:
		var q := p + Vector2(3+_h(x,y,91)%9, 3+_h(x,y,92)%9)
		draw_rect(Rect2(q+Vector2(0,1),Vector2(3,1)),Color("2c2114"))
		draw_rect(Rect2(q,Vector2(2,1)),Color("8b8270"))

func _is_open_ground(symbol: String) -> bool:
	return symbol != "" and symbol != ","

func _draw_transitions() -> void:
	## Second pass: organic road verges and canopy shade spill, drawn after
	## every base tile so neighbouring tiles cannot paint over them.
	for y in rows.size():
		for x in rows[y].length():
			var symbol := _symbol(x,y)
			var p := Vector2(x*TILE,y*TILE)
			if symbol == ",": _draw_road_verge(x,y,p)
			elif symbol != "#": _draw_canopy_spill(x,y,p)

func _draw_road_verge(x: int, y: int, p: Vector2) -> void:
	var up := _is_open_ground(_symbol(x,y-1))
	var down := _is_open_ground(_symbol(x,y+1))
	var left := _is_open_ground(_symbol(x-1,y))
	var right := _is_open_ground(_symbol(x+1,y))
	for i in 16:
		if up:
			var d := _road_bite(x*16+i, y, 101)
			if d > 0: draw_rect(Rect2(p+Vector2(i,0),Vector2(1,d)),VERGE)
			draw_rect(Rect2(p+Vector2(i,d),Vector2(1,1)),Color(VERGE_RIM,0.7))
		if down:
			var d := _road_bite(x*16+i, y+1, 101)
			if d > 0: draw_rect(Rect2(p+Vector2(i,16-d),Vector2(1,d)),VERGE)
		if left:
			var d := _road_bite(y*16+i, x, 103)
			if d > 0: draw_rect(Rect2(p+Vector2(0,i),Vector2(d,1)),VERGE)
			draw_rect(Rect2(p+Vector2(d,i),Vector2(1,1)),Color(VERGE_RIM,0.5))
		if right:
			var d := _road_bite(y*16+i, x+1, 103)
			if d > 0: draw_rect(Rect2(p+Vector2(16-d,i),Vector2(d,1)),VERGE)
			draw_rect(Rect2(p+Vector2(15-d,i),Vector2(1,1)),Color(VERGE_RIM,0.5))
	# Round outer corners with a stepped wedge instead of a square notch.
	for corner in [[up,left,Vector2(0,0),Vector2(1,1)],[up,right,Vector2(16,0),Vector2(-1,1)],[down,left,Vector2(0,16),Vector2(1,-1)],[down,right,Vector2(16,16),Vector2(-1,-1)]]:
		if not (corner[0] and corner[1]): continue
		for step in 5:
			var w := 5 - step
			var o: Vector2 = corner[2]
			var dir: Vector2 = corner[3]
			var r := Rect2(p+o+Vector2(0,step)*dir.y, Vector2(w*dir.x,dir.y))
			draw_rect(r.abs(),VERGE)
	# A few grass blades lean over the verge.
	if up or down or left or right:
		for blade in _h(x,y,110)%3:
			var q := p + Vector2(1+_h(x,y,111+blade)%14, 1+_h(x,y,114+blade)%14)
			if up: q.y = p.y + 2
			elif down: q.y = p.y + 15
			elif left: q.x = p.x + 2
			else: q.x = p.x + 14
			draw_line(q,q+Vector2(1-blade,-3),BLADES[blade%3],1)

func _draw_canopy_spill(x: int, y: int, p: Vector2) -> void:
	## Open tiles beside the forest sit in soft, uneven canopy shade.
	for side in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
		if _symbol(x+side.x,y+side.y) != "#": continue
		for step in 4:
			var reach := 3 + step*2 + _h(x*4+side.x,y*4+side.y,120+step)%3
			var alpha: float = [0.08,0.05,0.04,0.03][step]
			var strip: Rect2
			match side:
				Vector2i.UP: strip = Rect2(p,Vector2(16,reach))
				Vector2i.DOWN: strip = Rect2(p+Vector2(0,16-reach),Vector2(16,reach))
				Vector2i.LEFT: strip = Rect2(p,Vector2(reach,16))
				_: strip = Rect2(p+Vector2(16-reach,0),Vector2(reach,16))
			draw_rect(strip,Color(0.01,0.025,0.015,alpha))

func _draw_canopy_deepening(x: int, y: int, p: Vector2, depth: int) -> void:
	## Shade ramps toward deeper neighbours, so no forest tile ends on a step.
	for side in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
		var other: Vector2i = Vector2i(x,y)+side
		if _symbol(other.x,other.y) != "#" or int(_depth.get(other,3)) <= depth: continue
		for step in 4:
			var reach := 4 + step*3
			var strip: Rect2
			match side:
				Vector2i.UP: strip = Rect2(p,Vector2(16,reach))
				Vector2i.DOWN: strip = Rect2(p+Vector2(0,16-reach),Vector2(16,reach))
				Vector2i.LEFT: strip = Rect2(p,Vector2(reach,16))
				_: strip = Rect2(p+Vector2(16-reach,0),Vector2(reach,16))
			draw_rect(strip,Color(0.01,0.025,0.015,0.04))
