extends RefCounted
class_name OverworldSprite
## Shared loader and animator for 20x28 overworld walk sheets.
##
## Frame geometry comes entirely from `assets/battle/sheet_manifest.json`
## so the player, NPCs and any future walker agree on sheet layout, and
## changing sprite size stays a data edit rather than a hunt for hardcoded
## offsets.
##
## Sheets are one row: four frames per direction for "down", "up" and
## "side", with west drawn as mirrored side frames.

const MANIFEST_PATH := "res://assets/battle/sheet_manifest.json"
const CHARACTER_PATH := "res://assets/characters/%s/overworld.png"

var frame_width := 20
var frame_height := 28
var walk_frames := 4
var anchor := Vector2(10, 22)
var directions: Dictionary = {"down": 0, "up": 4, "side": 8}
var mirror_side_for_west := true

var _sprite: Sprite2D
var _facing := "down"
var _frame := 0
var _registered_row := -1

static var _cached: Dictionary = {}


static func manifest() -> Dictionary:
	## Parsed once per run: every walker reads the same layout.
	if _cached.has("overworld"):
		return _cached["overworld"]
	var result: Dictionary = {}
	if FileAccess.file_exists(MANIFEST_PATH):
		var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
			result = json.data.get("overworld", {})
	_cached["overworld"] = result
	return result


static func sheet_path(sprite_key: String) -> String:
	return CHARACTER_PATH % sprite_key


static func _load_sidecar(sheet_path_: String) -> Dictionary:
	## Mirrors DuelistSprite's battle.json convention: an authored
	## overworld sheet gets a same-named .json beside it (overworld.png
	## -> overworld.json). Absent for the generated 20x28 walk sheets,
	## which keep sizing against the global manifest.
	var sidecar_path := sheet_path_.get_basename() + ".json"
	if not FileAccess.file_exists(sidecar_path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.open(sidecar_path, FileAccess.READ).get_as_text()) != OK:
		push_warning("OverworldSprite: malformed sidecar %s" % sidecar_path)
		return {}
	return json.data


static func head_clearance() -> float:
	## How far a character's art rises above the centre of its tile, so
	## callers can place markers above the head without assuming a size.
	var data := manifest()
	var point: Array = data.get("anchor", [10, 22])
	return float(point[1]) - 8.0 + 5.0


func _ground(parent: Node2D) -> void:
	## A contact shadow at the character's feet. Characters are positioned
	## with their ground contact on the node origin (the same point that
	## drives y-sorting), so the shadow needs no per-character tuning and
	## stays correct whether the art came from the high-resolution cast
	## atlas or a 20x30 townsfolk sheet.
	if _sprite == null:
		return
	var drawn_width := float(frame_width) * _sprite.scale.x
	OverworldDepth.attach(parent, drawn_width)


func attach(parent: Node2D, sprite_key: String) -> bool:
	## Build the sprite under `parent`. Returns false when art is missing,
	## leaving the caller to fall back to its placeholder drawing.
	if sprite_key == "":
		return false
	var record := CharacterPresentation.record_for(sprite_key)
	var registry := CharacterPresentation.manifest()
	if not record.is_empty() and (record.has("overworld") or registry.overworld_rows.has(record.canonical_id)):
		var world: Dictionary = record.get("overworld", {})
		_registered_row = int(world.get("row", registry.overworld_rows.get(record.canonical_id, 0)))
		var frame_size: Array = world.get("frame_size", registry.overworld_frame_size)
		frame_width = int(frame_size[0])
		frame_height = int(frame_size[1])
		var point: Array = world.get("foot_anchor", registry.overworld_anchors.get(record.canonical_id, [192, 322]))
		anchor = Vector2(point[0], point[1])
		directions = registry.overworld_directions
		walk_frames = 1
		_sprite = Sprite2D.new()
		var path: String = str(world.get("atlas", registry.overworld_atlas))
		if not ResourceLoader.exists(path):
			push_error("OverworldSprite: required atlas missing: " + path)
			return false
		_sprite.texture = load(path)
		_sprite.material = CharacterPresentation.key_material(record)
		# Registered cast only: 384x336 atlas frames sampled down to the
		# overworld display height. The authored 20x30 townsfolk sheets
		# below take the project-wide nearest filter instead.
		PresentationLayout.use_source_art_filter(_sprite)
		_sprite.region_enabled = true
		_sprite.region_filter_clip_enabled = true
		_sprite.centered = false
		_sprite.offset = -anchor
		_sprite.scale = Vector2.ONE * float(registry.overworld_display_height) / anchor.y
		parent.add_child(_sprite)
		_apply()
		_ground(parent)
		return true
	var path := sheet_path(sprite_key)
	if not ResourceLoader.exists(path):
		return false

	var sidecar := _load_sidecar(path)
	if not sidecar.is_empty():
		# An authored overworld sheet, per docs/AUTHORED_ART_PIPELINE.md.
		# The pipeline so far only supplies a front-facing pose (no side
		# or back view was drawn), which is exactly what a *static* NPC
		# needs: OverworldNPC never calls advance() or re-faces itself,
		# so one frame in "down" is the whole sheet. A sidecar that does
		# author more rows can still declare its own "directions".
		frame_width = int(sidecar.get("frame_width", frame_width))
		frame_height = int(sidecar.get("frame_height", frame_height))
		walk_frames = maxi(1, int(sidecar.get("walk_frames", 1)))
		mirror_side_for_west = bool(sidecar.get("mirror_side_for_west", false))
		directions = sidecar.get("directions", {"down": 0})
		var a: Array = sidecar.get("anchor", [frame_width / 2.0, frame_height])
		anchor = Vector2(a[0], a[1])
	else:
		var data := manifest()
		frame_width = int(data.get("frame_width", frame_width))
		frame_height = int(data.get("frame_height", frame_height))
		walk_frames = maxi(1, int(data.get("walk_frames", walk_frames)))
		mirror_side_for_west = bool(data.get("mirror_side_for_west", mirror_side_for_west))
		if data.has("directions"):
			directions = data["directions"]
		if data.has("anchor"):
			var point: Array = data["anchor"]
			anchor = Vector2(float(point[0]), float(point[1]))

	_sprite = Sprite2D.new()
	_sprite.texture = load(path)
	_sprite.region_enabled = true
	_sprite.centered = false
	# The anchor pixel lands on the node origin, so a character stands on
	# its own feet wherever the owner places it.
	_sprite.offset = -anchor
	# Static villagers share the same ground scale as the travelling cast.
	_sprite.scale = Vector2.ONE * 24.0 / maxf(1.0, anchor.y)
	parent.add_child(_sprite)
	_apply()
	_ground(parent)
	return true


func set_facing(direction: Vector2i) -> void:
	if direction.y > 0:
		_facing = "down"
	elif direction.y < 0:
		_facing = "up"
	elif direction.x != 0:
		_facing = "west" if direction.x < 0 else "east"
	_apply()


func advance() -> void:
	## Step the walk cycle one frame; called once per completed step.
	_frame = (_frame + 1) % walk_frames
	_apply()


func rest() -> void:
	## Frames 0 and 2 are the neutral stance; settle on 0 when stopping.
	_frame = 0
	_apply()


func _apply() -> void:
	if _sprite == null:
		return
	if _registered_row >= 0:
		_sprite.region_rect = Rect2(int(directions.get(_facing, 0)) * frame_width, _registered_row, frame_width, frame_height)
		return
	var row_name := _facing
	var flip := false
	if row_name in ["east", "west"]:
		if mirror_side_for_west:
			flip = row_name == "west"
			row_name = "side"
		elif not directions.has(row_name):
			row_name = "side"
	var start := int(directions.get(row_name, 0))
	_sprite.region_rect = Rect2(
		(start + _frame) * frame_width, 0, frame_width, frame_height
	)
	_sprite.flip_h = flip
	# Mirroring pivots on the node origin, so shift back by the anchor to
	# keep the character's feet in the same place when facing west.
	_sprite.offset.x = (anchor.x - frame_width) if flip else -anchor.x
