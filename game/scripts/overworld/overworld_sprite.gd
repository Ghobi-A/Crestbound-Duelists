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


static func head_clearance() -> float:
	## How far a character's art rises above the centre of its tile, so
	## callers can place markers above the head without assuming a size.
	var data := manifest()
	var point: Array = data.get("anchor", [10, 22])
	return float(point[1]) - 8.0 + 5.0


func attach(parent: Node2D, sprite_key: String) -> bool:
	## Build the sprite under `parent`. Returns false when art is missing,
	## leaving the caller to fall back to its placeholder drawing.
	if sprite_key == "":
		return false
	var path := sheet_path(sprite_key)
	if not ResourceLoader.exists(path):
		return false

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
	parent.add_child(_sprite)
	_apply()
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
