extends Node2D
class_name WorldAtmosphere
var lights: Array = []
var clock := 0.0
## Interiors get stronger lamplight and a vignette over the room bounds so
## the rooms read as lit spaces rather than flat floor plans.
var interior := false
var bounds := Rect2()

func _process(delta: float) -> void:
	clock += delta
	if int(clock * 6) != int((clock-delta)*6): queue_redraw()

func _draw() -> void:
	if interior and bounds.has_area():
		var shade := Color(0.02, 0.015, 0.03)
		for step in 10:
			var inset := step * 3.0
			var alpha := 0.07 * (1.0 - step / 10.0)
			var r := bounds.grow(-inset)
			draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color(shade, alpha))
			draw_rect(Rect2(r.position + Vector2(0, r.size.y - 3), Vector2(r.size.x, 3)), Color(shade, alpha))
			draw_rect(Rect2(r.position + Vector2(0, 3), Vector2(3, r.size.y - 6)), Color(shade, alpha))
			draw_rect(Rect2(r.position + Vector2(r.size.x - 3, 3), Vector2(3, r.size.y - 6)), Color(shade, alpha))
	for light in lights:
		var p := Vector2(WorldCatalog.tile(light.tile)*16)+Vector2(8,0)
		var color := Color("b38add") if light.color == "violet" else Color("efb966")
		# Soft light pool: flattened concentric ellipses at HD output read as
		# lamplight on the ground rather than stepped low-res diamonds.
		for step in 8:
			var radius := 26.0 - step * 3.0
			var points := PackedVector2Array()
			for i in 24:
				var angle := TAU * i / 24.0
				points.append(p + Vector2(cos(angle) * radius, sin(angle) * radius * 0.55 + 4.0))
			draw_colored_polygon(points,Color(color,0.034 if interior else 0.022))
		var phase := int(clock*6) % 4
		draw_rect(Rect2(p+Vector2(phase-2,-10-phase*2),Vector2.ONE),Color(color,0.6))
