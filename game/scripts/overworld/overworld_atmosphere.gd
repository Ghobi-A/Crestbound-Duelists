class_name OverworldAtmosphere
extends Node2D
## Ground mist and drifting motes over Greymere.
##
## Restraint is the point: this is a thin, slow, low-contrast wash that
## gives the air some depth between the camera and the far side of the
## town. It must never read as fog covering the art, and it must never
## sit over anything the player needs to read, so it is drawn in its own
## band beneath the interface and above the world.

## Mist itself is a shader (atmosphere.gdshader) because a drawn band has
## edges and edges are exactly what must not show. This node owns the
## motes, which do want to be discrete points.
const SHADER_PATH := "res://scripts/overworld/atmosphere.gdshader"
const MOTE_COUNT := 26
const MOTE_COLOR := Color(0.80, 0.86, 1.0, 0.5)

var world_size := Vector2(384, 224)

var _time := 0.0
var _motes: Array[Dictionary] = []


func _ready() -> void:
	z_index = EnvironmentLayers.ATMOSPHERE
	if ResourceLoader.exists(SHADER_PATH):
		var mist := ColorRect.new()
		mist.name = "Mist"
		mist.size = world_size
		mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material := ShaderMaterial.new()
		material.shader = load(SHADER_PATH)
		material.set_shader_parameter("world_size", world_size)
		mist.material = material
		add_child(mist)
	# Deterministic: the screenshot harness must produce identical frames
	# on every run, so this cannot use a global or time-seeded RNG.
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x4752454d   # "GREM"
	for i in MOTE_COUNT:
		_motes.append({
			"origin": Vector2(rng.randf() * world_size.x, rng.randf() * world_size.y),
			"drift": Vector2(rng.randf_range(1.5, 4.0), rng.randf_range(-1.2, -0.3)),
			"phase": rng.randf() * TAU,
			"size": rng.randf_range(0.5, 1.1),
		})


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	for mote in _motes:
		var origin: Vector2 = mote["origin"]
		var drift: Vector2 = mote["drift"]
		var phase: float = mote["phase"]
		var position := Vector2(
			fposmod(origin.x + drift.x * _time, world_size.x),
			fposmod(origin.y + drift.y * _time, world_size.y)
		)
		# A slow sine on alpha so motes fade in and out rather than
		# popping when they wrap around the map edge.
		var pulse := 0.35 + 0.65 * (0.5 + 0.5 * sin(_time * 0.9 + phase))
		var color := MOTE_COLOR
		color.a *= pulse
		draw_circle(position + Vector2(0, sin(_time * 0.6 + phase) * 2.0),
			float(mote["size"]), color)
