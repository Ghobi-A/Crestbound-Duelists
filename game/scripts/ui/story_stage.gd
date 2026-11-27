class_name StoryStage
extends Control
## The staging behind an authored story conversation (DialogueBox with
## "staging": "scene"): the live location softened into a backdrop, and the
## cast drawn large from their battle sheets. Kai stands on the left facing
## right; the other speakers stand on the right facing him, so every line
## has an eyeline. The active speaker steps forward in full light and the
## listeners sink back into shadow. Presentation only: it reads the
## conversation and the character manifest and never changes game state.

const FEET_Y := 182.0          # the panel covers everything below the waist
const BODY_DISPLAY := 140.0    # head-to-foot height on the 320x180 canvas
const PLAYER_X := 70.0
const RIGHT_SLOTS := {1: [250.0], 2: [226.0, 284.0]}
const LISTENER := Color(0.4, 0.43, 0.55)
const NARRATION := Color(0.62, 0.65, 0.74)
const SINK := 5.0              # listeners drop this far
const EASE := 0.18

var _backdrop: ColorRect
var _figures: Dictionary = {}  # record id -> Node2D (holder) with meta
var _order: Array[String] = []


func _ready() -> void:
	position = Vector2.ZERO
	size = PresentationLayout.CANVAS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop = ColorRect.new()
	_backdrop.size = PresentationLayout.CANVAS
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/ui/story_backdrop.gdshader")
	_backdrop.material = material
	add_child(_backdrop)
	visible = false


const PLAYER := "player"  # Kai's lines: his figure as he is now (class or Unbonded)


static func resolve(portrait_key: String) -> String:
	return player_key() if portrait_key == PLAYER else portrait_key


static func figure_record(portrait_key: String) -> Dictionary:
	## The manifest record whose battle sheet can stand in a story scene, or
	## {} when the speaker has no large art (townsfolk keep their portrait).
	var record := CharacterPresentation.record_for(resolve(portrait_key))
	var path := str(record.get("battle_sheet", ""))
	if path == "" or not ResourceLoader.exists(path) or VisualAsset.sidecar_for(path).is_empty():
		return {}
	return record


static func player_key() -> String:
	## Kai in his village clothes until Civara stabilises a class.
	var class_id := str(GameState.player_class_id)
	return "aren/%s" % class_id if class_id != "" else "kai_unbonded"


static func cast_for(entries: Array) -> Array[String]:
	## Canonical ids of the speakers with large art, in order of first line,
	## at most two (the right-hand slots). Kai is added by begin().
	var cast: Array[String] = []
	# Kai always stands on the left; his own lines never add him again.
	var player := str(figure_record(player_key()).get("canonical_id", ""))
	for entry in entries:
		var record := figure_record(str(entry.get("portrait", "")))
		var id := str(record.get("canonical_id", ""))
		if id != "" and id != player and not cast.has(id) and cast.size() < 2:
			cast.append(id)
	return cast


func begin(entries: Array) -> void:
	clear()
	visible = true
	var player := figure_record(player_key())
	if not player.is_empty():
		_add_figure(player, PLAYER_X, false)
	var cast := cast_for(entries)
	var slots: Array = RIGHT_SLOTS.get(cast.size(), [])
	for i in cast.size():
		_add_figure(CharacterPresentation.record_for(cast[i]), float(slots[i]), true)
	var material := _backdrop.material as ShaderMaterial
	material.set_shader_parameter("fade", 0.0)
	create_tween().tween_method(func(v: float) -> void: material.set_shader_parameter("fade", v), 0.0, 1.0, 0.25)


func clear() -> void:
	for id in _figures:
		(_figures[id] as Node2D).queue_free()
	_figures.clear()
	_order.clear()
	visible = false


func has_figure(portrait_key: String) -> bool:
	return _figures.has(str(figure_record(portrait_key).get("canonical_id", "_")))


func figure_x(portrait_key: String) -> float:
	## Screen x of a speaker's figure, or -1 when they are not on stage.
	var id := str(figure_record(portrait_key).get("canonical_id", "_"))
	return float(_figures[id].get_meta("home").x) if _figures.has(id) else -1.0


func focus(portrait_key: String) -> void:
	## Light the speaker and sink everyone else; narration ("" or a speaker
	## without large art) leaves the whole cast half-lit.
	var speaker := str(figure_record(portrait_key).get("canonical_id", ""))
	for id in _order:
		var holder: Node2D = _figures[id]
		var home: Vector2 = holder.get_meta("home")
		var active := id == speaker
		var colour := Color.WHITE if active else (LISTENER if _figures.has(speaker) else NARRATION)
		var tween := holder.create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(holder, "modulate", Color(colour, 1.0), EASE)
		tween.tween_property(holder, "position", home + Vector2(0, 0.0 if active else SINK), EASE)
	# The speaker stands in front. Tree order, not z_index: the figures must
	# stay under the dialogue panel, which shares this canvas layer.
	if _figures.has(speaker):
		move_child(_figures[speaker], -1)


func _add_figure(record: Dictionary, x: float, faces_left: bool) -> void:
	var path := str(record.battle_sheet)
	var sidecar: Dictionary = VisualAsset.sidecar_for(path)
	var sprite := Sprite2D.new()
	sprite.texture = load(path)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.region_enabled = true
	sprite.region_filter_clip_enabled = true
	sprite.centered = false
	var frame := Vector2(float(sidecar.frame_width), float(sidecar.frame_height))
	var flip := PresentationLayout.needs_flip(str(sidecar.get("native_facing", "right")), "enemy" if faces_left else "player")
	sprite.flip_h = flip
	var scale_factor := BODY_DISPLAY / maxf(1.0, float(sidecar.body_height))
	sprite.scale = Vector2.ONE * scale_factor
	var anchor := Vector2(float(sidecar.anchor[0]), float(sidecar.anchor[1]))
	sprite.position = -PresentationLayout.mirrored_anchor(anchor, frame.x, flip) * scale_factor
	var holder := Node2D.new()
	holder.add_child(sprite)
	var home := Vector2(x, FEET_Y)
	holder.set_meta("home", home)
	holder.set_meta("sheet", {"sprite": sprite, "frame": frame, "columns": int(sidecar.get("columns", 0)),
		"idle": sidecar.get("states", {}).get("idle", {"start": 0, "count": 1, "fps": 1}), "time": 0.55 * _order.size()})
	holder.modulate = Color(NARRATION, 0.0)
	holder.position = home + Vector2(24.0 if faces_left else -24.0, SINK)
	add_child(holder)
	_set_frame(holder, 0)
	var id := str(record.canonical_id)
	_figures[id] = holder
	_order.append(id)
	var tween := holder.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(holder, "position", home + Vector2(0, SINK), 0.32)
	tween.tween_property(holder, "modulate:a", 1.0, 0.24)


func _set_frame(holder: Node2D, index: int) -> void:
	var sheet: Dictionary = holder.get_meta("sheet")
	var frame: Vector2 = sheet.frame
	var columns: int = maxi(1, int(sheet.columns))
	var cell := int(sheet.idle.get("start", 0)) + index
	(sheet.sprite as Sprite2D).region_rect = Rect2(Vector2(cell % columns, cell / columns) * frame, frame)


func _process(delta: float) -> void:
	if not visible:
		return
	# The authored idle loop keeps the cast breathing while they talk.
	for id in _order:
		var holder: Node2D = _figures[id]
		var sheet: Dictionary = holder.get_meta("sheet")
		sheet.time += delta
		var count := maxi(1, int(sheet.idle.get("count", 1)))
		_set_frame(holder, int(sheet.time * float(sheet.idle.get("fps", 5))) % count)
