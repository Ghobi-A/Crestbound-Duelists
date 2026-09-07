extends Node2D
class_name WorldTerrain
## Low-frequency support terrain, one native pixel per drawn detail.
## Focal architecture and furniture are separate authored sprites.
var rows: Array = []
var interior := false
const TILE := 16

func _draw() -> void:
	for y in rows.size():
		for x in rows[y].length():
			var p := Vector2(x * TILE, y * TILE)
			var symbol: String = rows[y][x]
			var variant: int = (x * 17 + y * 31) % 7
			match symbol:
				"_": draw_rect(Rect2(p, Vector2(16,16)), Color("090f19"))
				"w":
					draw_rect(Rect2(p,Vector2(16,16)),Color("47372f"))
					for board in 4:
						draw_rect(Rect2(p+Vector2(0,board*4),Vector2(15,3)), Color("574437") if (x+board)%3 else Color("604c3b"))
						draw_line(p+Vector2(2,board*4+1),p+Vector2(8+variant,board*4+1),Color("4d3b30"))
				":", "^", "#":
					draw_rect(Rect2(p,Vector2(16,16)),Color("252e37"))
					for row in 3:
						for col in 2:
							var q := p + Vector2(col*8+(row%2)*2, row*5)
							var color := Color("52606a") if symbol == "^" else Color("434c53")
							draw_rect(Rect2(q, Vector2(7,4)),color.lightened(variant*0.008))
							draw_line(q,q+Vector2(6,0),color.lightened(0.10))
					if symbol == "^": draw_line(p,p+Vector2(15,0),Color("8a9193"))
				"~":
					draw_rect(Rect2(p,Vector2(16,16)),Color("14283c"))
					draw_rect(Rect2(p+Vector2(variant,4),Vector2(7,1)),Color("42718d"))
					draw_rect(Rect2(p+Vector2(2,11),Vector2(5,1)),Color("294b66"))
				"=":
					draw_rect(Rect2(p,Vector2(16,16)),Color("302f30"))
					for board in 4: draw_rect(Rect2(p+Vector2(0,board*4),Vector2(16,3)),Color("6a5340"))
				_:
					draw_rect(Rect2(p,Vector2(16,16)),Color("202f2d"))
					for i in 4:
						var q := p+Vector2((x*7+i*5)%15,(y*3+i*7)%15)
						draw_line(q,q+Vector2(1,-2),Color("38483d"))
					if variant == 2: draw_rect(Rect2(p+Vector2(5,8),Vector2(2,1)),Color("797d7e"))
