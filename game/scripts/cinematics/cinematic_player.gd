extends Node2D
class_name CinematicPlayer
## Plays an authored cinematic timeline (game/data/cinematics/*.json):
## painted shots with camera moves and cross-fades, animated elements laid
## out in each shot's own image pixels, letterboxed narration subtitles,
## screen pulses and one-shot audio cues. Presentation only: no game state
## changes except where the movie leads afterwards.
##
## Audio is optional. Every cue names an AudioRouter slot (music, voice,
## world sfx); a missing file is silent, so recordings drop in by name.

const TIMELINE := "res://data/cinematics/opening_the_last_accord.json"
const ASSETS := "res://assets/cinematics/opening/"
const OVERWORLD_SCENE := "res://scenes/overworld/greymere.tscn"
const VIEW := Vector2(320, 180)
const BAR := 16.0                 # letterbox bar height, top and bottom
const SKIP_HOLD := 0.9            # seconds Confirm must be held to skip
const HINT_TIME := 2.5

## Where the movie leads when it ends or is skipped. The boot screen sets
## it to itself for "Watch Opening"; a new story game goes to Greymere.
static var return_scene := OVERWORLD_SCENE

var timeline: Dictionary = {}
var time := 0.0
var finished := false
var _duration := 0.0
var _shots: Array[Dictionary] = []      # {data, node, texture_size}
var _cues_fired: Dictionary = {}
var _hold := 0.0
var _hint_left := 0.0
var _overlay: Node2D
var _pulse_alpha := 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	timeline = load_timeline(TIMELINE)
	if timeline.is_empty():
		_finish()
		return
	_duration = float(timeline.get("duration", 0.0))
	AudioRouter.stop_music(0.6)
	for shot in timeline.get("shots", []):
		_shots.append(_build_shot(shot))
	_overlay = Node2D.new()
	_overlay.z_index = 200
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_apply(0.0)


static func load_timeline(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.open(path, FileAccess.READ).get_as_text()) != OK or not json.data is Dictionary:
		return {}
	return json.data


func _process(delta: float) -> void:
	if finished:
		return
	_hint_left = maxf(0.0, _hint_left - delta)
	if Input.is_action_pressed("interact"):
		_hold += delta
		if _hold >= SKIP_HOLD:
			skip()
			return
	else:
		_hold = 0.0
	time += delta
	_fire_cues(time)
	_apply(time)
	if time >= _duration:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if finished or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("cancel") and _hint_left > 0.0:
		skip()
		return
	_hint_left = HINT_TIME


func skip() -> void:
	## Cut every sound and jump to the end of the movie.
	AudioRouter.stop_voices()
	AudioRouter.stop_music(0.3)
	_finish()


func _finish() -> void:
	if finished:
		return
	finished = true
	for cue in timeline.get("end_cues", []):
		_play_cue(cue)
	# A skip can land while the fade into the movie is still running, and a
	# transition ignores requests while busy, so wait for it to settle.
	while SceneTransition._busy:
		await get_tree().process_frame
	SceneTransition.change_scene(return_scene)


# ── Shots ────────────────────────────────────────────────────────────────

func _build_shot(data: Dictionary) -> Dictionary:
	var node := Node2D.new()
	node.visible = false
	add_child(node)
	var size := Vector2(VIEW)
	if data.has("image"):
		var path: String = ASSETS + str(data.image) + ".png"
		if ResourceLoader.exists(path):
			var sprite := Sprite2D.new()
			sprite.texture = load(path)
			sprite.centered = false
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			node.add_child(sprite)
			size = sprite.texture.get_size()
	for element in data.get("elements", []):
		var built := _build_element(element)
		if built != null:
			built.set_meta("element", element)
			node.add_child(built)
	return {"data": data, "node": node, "size": size}


func _apply(t: float) -> void:
	for shot in _shots:
		var data: Dictionary = shot.data
		var start := float(data.start)
		var length := float(data.duration)
		var node: Node2D = shot.node
		var hold := float(data.get("hold", 0.0))   # stays under the next shot's cross-fade
		if t < start or t > start + length + hold:
			node.visible = false
			continue
		node.visible = true
		var local := t - start
		var alpha := 1.0
		var fade_in := float(data.get("fade_in", 0.0))
		var fade_out := float(data.get("fade_out", 0.0))
		if fade_in > 0.0:
			alpha = minf(alpha, smoothstep(0.0, fade_in, local))
		if fade_out > 0.0:
			alpha = minf(alpha, 1.0 - smoothstep(length - fade_out, length, local))
		node.modulate.a = alpha
		node.z_index = int(data.get("layer", 0))
		_place_camera(node, shot.size, data.get("camera", {}), clampf(local / maxf(0.01, length), 0.0, 1.0))
		for child in node.get_children():
			if child.has_meta("element"):
				_update_element(child, child.get_meta("element"), local)
	_pulse_alpha = 0.0
	for beat in timeline.get("pulses", []):
		var dt := t - float(beat)
		if dt >= 0.0 and dt < 0.5:
			_pulse_alpha = maxf(_pulse_alpha, (1.0 - dt / 0.5) * 0.35)
	_overlay.queue_redraw()


func _place_camera(node: Node2D, size: Vector2, camera: Dictionary, u: float) -> void:
	## camera.from / camera.to = [centre_x, centre_y, zoom] in image pixels;
	## zoom 1 covers the view. Eased so moves start and settle gently.
	var cover := maxf(VIEW.x / size.x, VIEW.y / size.y)
	var a: Array = camera.get("from", [size.x / 2.0, size.y / 2.0, 1.0])
	var b: Array = camera.get("to", a)
	var e := u if str(camera.get("ease", "in_out")) == "linear" else u * u * (3.0 - 2.0 * u)
	var centre := Vector2(lerpf(a[0], b[0], e), lerpf(a[1], b[1], e))
	var scale_value := cover * maxf(1.0, lerpf(float(a[2]), float(b[2]), e))
	# Never show past the painting: keep the whole view inside the image.
	var half := VIEW / 2.0 / scale_value
	centre = Vector2(clampf(centre.x, half.x, maxf(half.x, size.x - half.x)), clampf(centre.y, half.y, maxf(half.y, size.y - half.y)))
	node.scale = Vector2.ONE * scale_value
	node.position = VIEW / 2.0 - centre * scale_value


# ── Elements (image-pixel coordinates inside their shot) ────────────────

func _build_element(element: Dictionary) -> Node2D:
	match str(element.type):
		"sprite", "dissolve":
			var path: String = ASSETS + str(element.key) + ".png"
			if not ResourceLoader.exists(path):
				return null
			var sprite := Sprite2D.new()
			sprite.texture = load(path)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			var frames := int(element.get("frames", 1))
			if frames > 1:
				sprite.region_enabled = true
				sprite.region_rect = Rect2(0, 0, sprite.texture.get_width() / frames, sprite.texture.get_height())
			sprite.scale = Vector2.ONE * float(element.get("scale", 1.0))
			sprite.flip_h = bool(element.get("flip", false))
			if element.has("tint"):
				# Atmospheric perspective: distant forms take on the haze colour.
				sprite.self_modulate = Color(str(element.tint))
			if element.type == "dissolve":
				var material := ShaderMaterial.new()
				material.shader = preload("res://scripts/cinematics/dissolve.gdshader")
				material.set_shader_parameter("glow", Color(str(element.get("color", "#cfe8ff"))))
				sprite.material = material
				sprite.add_child(_particles(element, Vector2(sprite.texture.get_size()) * Vector2(1.0 / frames, 1.0)))
			return sprite
		"motes":
			var holder := Node2D.new()
			holder.add_child(_particles(element, Vector2(element.size[0], element.size[1])))
			return holder
		"glow":
			var glow := Sprite2D.new()
			glow.texture = _radial(Color(str(element.get("color", "#ffd890"))))
			glow.material = CanvasItemMaterial.new()
			(glow.material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			glow.scale = Vector2.ONE * float(element.get("radius", 24.0)) / 32.0
			return glow
		"strokes", "crack":
			var holder := Node2D.new()
			for stroke in element.get("paths", []):
				var line := Line2D.new()
				line.width = float(element.get("width", 1.5))
				line.default_color = Color(str(element.get("color", "#2a1a10")))
				line.joint_mode = Line2D.LINE_JOINT_ROUND
				line.begin_cap_mode = Line2D.LINE_CAP_ROUND
				line.end_cap_mode = Line2D.LINE_CAP_ROUND
				line.antialiased = true
				if element.type == "crack":
					line.material = CanvasItemMaterial.new()
					(line.material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
				line.set_meta("points", stroke)
				holder.add_child(line)
			return holder
		"text":
			var label := Node2D.new()
			label.draw.connect(func() -> void:
				var size := int(element.get("size", 14))
				var tracking := float(element.get("tracking", 2.0))
				var face := str(element.get("face", UiStyle.DISPLAY))
				var width := UiStyle.text_width(str(element.text), size, face, tracking)
				UiStyle.draw_text(label, Vector2(-width / 2.0, size * 0.35), str(element.text), size,
					Color(str(element.get("color", "#3a2414"))), -1.0, HORIZONTAL_ALIGNMENT_LEFT, face, tracking))
			return label
		"shadow":
			var shade := Sprite2D.new()
			shade.texture = _radial(Color(str(element.get("color", "#000000"))))
			shade.scale = Vector2(float(element.get("radius", 30.0)) / 32.0 * 1.6, float(element.get("radius", 30.0)) / 32.0)
			return shade
	return null


func _update_element(node: Node2D, element: Dictionary, local: float) -> void:
	var t0 := float(element.get("start", 0.0))
	var t1 := float(element.get("end", 9999.0))
	var u := clampf((local - t0) / maxf(0.01, t1 - t0), 0.0, 1.0)
	var active := local >= t0 and local <= t1 + float(element.get("linger", 0.0))
	node.visible = active or bool(element.get("persist", false)) and local > t0
	var from: Array = element.get("at", element.get("from", [0, 0]))
	var to: Array = element.get("to", from)
	node.position = Vector2(lerpf(from[0], to[0], u), lerpf(from[1], to[1], u))
	var fade := float(element.get("fade", 0.4))
	var alpha := smoothstep(t0, t0 + fade, local) * (1.0 - smoothstep(t1 - fade, t1, local)) if fade > 0.0 else 1.0
	if bool(element.get("persist", false)) and local > t1:
		alpha = 1.0
	alpha *= float(element.get("alpha", 1.0))
	match str(element.type):
		"sprite":
			var frames := int(element.get("frames", 1))
			if frames > 1:
				var sprite := node as Sprite2D
				var frame := int(local * float(element.get("fps", 8.0))) % frames
				var w := sprite.texture.get_width() / frames
				sprite.region_rect = Rect2(frame * w, 0, w, sprite.texture.get_height())
		"dissolve":
			# Hold whole until `dissolve_at`, then break apart into light.
			var at := float(element.get("dissolve_at", t0))
			var progress := clampf((local - at) / maxf(0.01, t1 - at), 0.0, 1.0)
			((node as Sprite2D).material as ShaderMaterial).set_shader_parameter("progress", progress)
			for child in node.get_children():
				if child is CPUParticles2D:
					child.emitting = active and local >= at
		"motes":
			for child in node.get_children():
				if child is CPUParticles2D:
					child.emitting = active
		"glow":
			var pulse := float(element.get("pulse", 0.0))
			var flicker := 1.0 + pulse * sin(local * TAU * float(element.get("rate", 0.5)))
			node.scale = Vector2.ONE * float(element.get("radius", 24.0)) / 32.0 * lerpf(float(element.get("grow_from", 1.0)), 1.0, u) * flicker
		"strokes", "crack":
			# Paths draw in one after another, each over its own share of the window.
			var paths := node.get_children()
			var per := 1.0 / maxf(1.0, paths.size())
			for i in paths.size():
				var line := paths[i] as Line2D
				var points: Array = line.get_meta("points")
				var part := clampf((u - i * per) / per, 0.0, 1.0) if not bool(element.get("together", false)) else u
				line.clear_points()
				var reach := part * (points.size() - 1)
				for p in points.size():
					if p > reach + 1.0:
						break
					var point := Vector2(points[p][0], points[p][1])
					if p > reach and p > 0:
						var prev := Vector2(points[p - 1][0], points[p - 1][1])
						point = prev.lerp(point, reach - floorf(reach))
					line.add_point(point - node.position)
		"text":
			node.queue_redraw()
	node.modulate.a = alpha


func _particles(element: Dictionary, area: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = int(element.get("amount", 40))
	p.lifetime = float(element.get("lifetime", 4.0))
	p.preprocess = p.lifetime if element.type == "motes" else 0.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = area * 0.5 * float(element.get("spread", 1.0))
	if element.type == "motes":
		p.position = area * 0.5
	p.direction = Vector2(float(element.get("drift", 0.15)), -1.0)
	p.spread = 25.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = float(element.get("speed", 6.0)) * 0.5
	p.initial_velocity_max = float(element.get("speed", 6.0))
	p.scale_amount_min = float(element.get("mote", 1.5)) * 0.6
	p.scale_amount_max = float(element.get("mote", 1.5))
	var colour := Color(str(element.get("color", "#ffe6a8")))
	var ramp := Gradient.new()
	ramp.set_color(0, Color(colour, 0.0))
	ramp.add_point(0.2, colour)
	ramp.set_color(ramp.get_point_count() - 1, Color(colour, 0.0))
	p.color_ramp = ramp
	p.material = CanvasItemMaterial.new()
	(p.material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.emitting = false
	return p


func _radial(colour: Color) -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(colour, colour.a))
	gradient.set_color(1, Color(colour, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture


# ── Overlay: letterbox, narration, title, pulses, skip hint ─────────────

func _draw_overlay() -> void:
	var canvas := _overlay
	var t := time
	if _pulse_alpha > 0.0:
		canvas.draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.55, 0.62, 0.8, _pulse_alpha * 0.25))
	for block in timeline.get("fades", []):
		var a := _window_alpha(t, block)
		if a > 0.0:
			canvas.draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0, 0, 0, a))
	canvas.draw_rect(Rect2(0, 0, VIEW.x, BAR), Color.BLACK)
	canvas.draw_rect(Rect2(0, VIEW.y - BAR, VIEW.x, BAR), Color.BLACK)
	for line in timeline.get("narration", []):
		var a := _window_alpha(t, line)
		if a <= 0.0:
			continue
		var rows: Array = str(line.text).split("\n")
		var y := VIEW.y - BAR - 3.0 - (rows.size() - 1) * 8.0
		for row in rows:
			UiStyle.draw_text(canvas, Vector2(1, y + 0.6), row, 7, Color(0, 0, 0, 0.8 * a), VIEW.x, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.SERIF)
			UiStyle.draw_text(canvas, Vector2(0, y), row, 7, Color(0.93, 0.9, 0.82, a), VIEW.x, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.SERIF)
			y += 8.0
	for title in timeline.get("titles", []):
		var a := _window_alpha(t, title)
		if a <= 0.0:
			continue
		var size := int(title.get("size", 14))
		var tracking := float(title.get("tracking", 4.0))
		UiStyle.draw_text(canvas, Vector2(0, float(title.y)), str(title.text), size,
			Color(str(title.get("color", "#e9dcb8")), a), VIEW.x, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.DISPLAY, tracking)
	if _hint_left > 0.0:
		var a := minf(1.0, _hint_left / 0.5)
		var hint := "Hold Z to skip  ·  X skip now"
		UiStyle.draw_text(canvas, Vector2(0, VIEW.y - 5.0), hint, 5, Color(0.75, 0.72, 0.66, a * 0.85), VIEW.x - 6.0, HORIZONTAL_ALIGNMENT_RIGHT)
		if _hold > 0.0:
			canvas.draw_rect(Rect2(VIEW.x - 66.0, VIEW.y - 3.0, 60.0 * clampf(_hold / SKIP_HOLD, 0.0, 1.0), 0.8), Color(0.9, 0.82, 0.6, a))


static func _window_alpha(t: float, block: Dictionary) -> float:
	var start := float(block.start)
	var end := float(block.end)
	var fade := float(block.get("fade", 0.5))
	if t < start or t > end:
		return 0.0
	return minf(smoothstep(start, start + fade, t), 1.0 - smoothstep(end - fade, end, t)) * float(block.get("alpha", 1.0))


# ── Audio cues ───────────────────────────────────────────────────────────

func _fire_cues(t: float) -> void:
	var cues: Array = timeline.get("cues", [])
	for i in cues.size():
		if not _cues_fired.has(i) and t >= float(cues[i].at):
			_cues_fired[i] = true
			_play_cue(cues[i])


func _play_cue(cue: Dictionary) -> void:
	match str(cue.kind):
		"music":
			AudioRouter.play_music(str(cue.id), float(cue.get("fade", 1.5)))
		"music_stop":
			AudioRouter.stop_music(float(cue.get("fade", 1.0)))
		"voice":
			AudioRouter.play_voice(str(cue.id))
		_:
			AudioRouter.play_sfx(str(cue.kind), str(cue.id), float(cue.get("volume_db", 0.0)))
