class_name OverworldDepth
extends RefCounted
## Contact shadows for anything that stands on Greymere's ground.
##
## A sprite with no shadow reads as pasted onto the map rather than
## standing in it, which was the single clearest reason characters and
## props did not look like they inhabited the town. The shadow is drawn
## as a flat ellipse at the foot anchor — the same point y-sorting
## already uses — so it stays correct for any sprite size and never
## needs per-asset tuning.

## Shadow width as a fraction of the caster's footprint. Under 0.5 the
## shadow reads as a dot; much over 0.8 it reads as a puddle.
const WIDTH_RATIO := 0.62
## Ellipses this flat sell a light source high and slightly off-axis,
## which is what the moonlit direction in the tile art already implies.
const FLATTEN := 0.34
const COLOR := Color(0.03, 0.04, 0.07, 0.42)


static func attach(caster: Node2D, footprint_width: float) -> Node2D:
	## Adds a shadow that follows `caster`. The caster's origin must be
	## its ground contact point, which is the convention the overworld
	## already uses for y-sorting.
	var shadow := _ContactShadow.new()
	shadow.radius = maxf(2.0, footprint_width * WIDTH_RATIO * 0.5)
	# Drawn as a child at the origin so it tracks the caster's movement
	# without a per-frame update, and sits below it in the same band.
	shadow.z_index = -1
	shadow.z_as_relative = true
	caster.add_child(shadow)
	caster.move_child(shadow, 0)
	return shadow


class _ContactShadow:
	extends Node2D
	var radius := 6.0

	func _draw() -> void:
		var points := PackedVector2Array()
		for i in 20:
			var angle := TAU * float(i) / 20.0
			points.append(Vector2(cos(angle) * radius, sin(angle) * radius * FLATTEN))
		draw_colored_polygon(points, COLOR)
