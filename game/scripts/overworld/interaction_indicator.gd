extends Node2D
class_name InteractionIndicator
## Marks a tile or NPC that responds to the interact button.
##
## Two states, because one state cannot do both jobs. At rest the marker
## is a dim Crest spark that says "something is here" without competing
## with the character it floats over — the previous hard gold diamond
## outline read as a debug annotation precisely because it was drawn at
## full contrast whether or not it was relevant. When the player faces
## it, the marker brightens, grows a ring and steadies: that is the
## moment the prompt actually means something.

## Ambient and focused sizes, in world units.
const REST_RADIUS := 2.6
const FOCUS_RADIUS := 4.2
const REST_ALPHA := 0.34
const FOCUS_ALPHA := 1.0
## How fast the marker settles between states. Fast enough to feel
## responsive on a single step, slow enough not to flicker when the
## player turns on the spot.
const BLEND_SPEED := 9.0

var focused := false

var _base_position := Vector2.ZERO
var _time := 0.0
var _blend := 0.0   # 0 at rest, 1 focused


func setup(local_offset: Vector2) -> void:
	_base_position = local_offset
	position = _base_position


func _process(delta: float) -> void:
	_time += delta
	_blend = move_toward(_blend, 1.0 if focused else 0.0, delta * BLEND_SPEED)
	# The bob eases out as the marker takes focus: a settled prompt reads
	# as "press now", a drifting one as "over here".
	var bob := sin(_time * 2.6) * 1.4 * (1.0 - _blend * 0.75)
	position = _base_position + Vector2(0, bob)
	queue_redraw()


func _draw() -> void:
	var radius: float = lerpf(REST_RADIUS, FOCUS_RADIUS, _blend)
	var alpha: float = lerpf(REST_ALPHA, FOCUS_ALPHA, _blend)
	var gold := PlaceholderPalette.CREST_GOLD

	# A soft halo instead of a hard outline. Concentric translucent discs
	# approximate a glow without needing a texture, and they sit behind
	# the mark so the silhouette stays crisp.
	for step in 3:
		var falloff := 1.0 - float(step) / 3.0
		var halo := gold
		halo.a = alpha * 0.16 * falloff
		draw_circle(Vector2.ZERO, radius * (2.4 - float(step) * 0.5), halo)

	# Four-pointed Crest spark: long vertical axis, short horizontal one.
	var spark := PackedVector2Array([
		Vector2(0, -radius * 1.7),
		Vector2(radius * 0.52, 0),
		Vector2(0, radius * 1.7),
		Vector2(-radius * 0.52, 0),
	])
	var body := gold
	body.a = alpha
	draw_colored_polygon(spark, body)

	var core := PlaceholderPalette.CREST_GOLD_BRIGHT
	core.a = alpha
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -radius * 0.72),
		Vector2(radius * 0.22, 0),
		Vector2(0, radius * 0.72),
		Vector2(-radius * 0.22, 0),
	]), core)

	if _blend <= 0.01:
		return
	# Focused only: a ring that closes in as the marker takes focus, so
	# the eye is pulled to the thing the interact button will act on.
	var ring := PlaceholderPalette.CREST_GOLD_BRIGHT
	ring.a = alpha * 0.75 * _blend
	var ring_radius: float = radius * lerpf(3.0, 2.0, _blend)
	var points := PackedVector2Array()
	for i in 18:
		var angle := TAU * float(i) / 18.0
		points.append(Vector2(cos(angle) * ring_radius, sin(angle) * ring_radius * 0.62))
	points.append(points[0])
	draw_polyline(points, ring, 1.0)
