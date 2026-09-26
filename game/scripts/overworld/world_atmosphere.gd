extends Node2D
class_name WorldAtmosphere
var lights: Array = []
var clock := 0.0

func _process(delta: float) -> void:
	clock += delta
	if int(clock * 6) != int((clock-delta)*6): queue_redraw()

func _draw() -> void:
	for light in lights:
		var p := Vector2(WorldCatalog.tile(light.tile)*16)+Vector2(8,0)
		var color := Color("b38add") if light.color == "violet" else Color("efb966")
		# Stepped diamonds, not a blurred bloom texture.
		for radius in [24,16,8]:
			var points := PackedVector2Array([p+Vector2(0,-radius),p+Vector2(radius,0),p+Vector2(0,radius/2),p+Vector2(-radius,0)])
			draw_colored_polygon(points,Color(color,0.035))
		var phase := int(clock*6) % 4
		draw_rect(Rect2(p+Vector2(phase-2,-10-phase*2),Vector2.ONE),Color(color,0.6))
