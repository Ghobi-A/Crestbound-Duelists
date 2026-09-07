extends RefCounted
class_name OverworldSprite
## Shared loader and animator for overworld character art.
##
## Production v2 sprites are 40x56 transparent frames with four authored
## facings and four walk frames per facing. The v2 manifest is intentionally
## separate from the battle/portrait registry so presentation aliases can stay
## backwards-compatible while overworld art evolves independently.
##
## Legacy generated/authored sheets remain supported as a fallback for maps
## that have not moved to the v2 registry yet.

const MANIFEST_PATH := "res://assets/battle/sheet_manifest.json"
const V2_MANIFEST_PATH := "res://assets/rework/overworld_v2.json"
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
var _registered_animated := false

static var _cached: Dictionary = {}


static func manifest() -> Dictionary:
	## Parsed once per run: every legacy walker reads the same layout.
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


static func v2_manifest() -> Dictionary:
	if _cached.has("overworld_v2"):
		return _cached["overworld_v2"]
	var result: Dictionary = {}
	if FileAccess.file_exists(V2_MANIFEST_PATH):
		var file := FileAccess.open(V2_MANIFEST_PATH, FileAccess.READ)
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
			result = json.data
		else:
			push_error("OverworldSprite: malformed v2 manifest " + V2_MANIFEST_PATH)
	_cached["overworld_v2"] = result
	return result


static func sheet_path(sprite_key: String) -> String:
	return CHARACTER_PATH % sprite_key


static func _load_sidecar(sheet_path_: String) -> Dictionary:
	var sidecar_path := sheet_path_.get_basename() + ".json"
	if not FileAccess.file_exists(sidecar_path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.open(sidecar_path, FileAccess.READ).get_as_text()) != OK:
		push_warning("OverworldSprite: malformed sidecar %s" % sidecar_path)
		return {}
	return json.data


static func head_clearance() -> float:
	## Interaction markers should clear the production sprite's head after its
	## display-height scaling, rather than inheriting a raw source-atlas size.
	var v2 := v2_manifest()
	if not v2.is_empty():
		return maxf(16.0, float(v2.get("display_height", 24)) - 2.0)
	var data := manifest()
	var point: Array = data.get("anchor", [10, 22])
	return float(point[1]) - 8.0 + 5.0


func attach(parent: Node2D, sprite_key: String) -> bool:
	## Build the sprite under `parent`. Returns false when art is missing,
	## leaving debug builds free to draw their explicit placeholder chip.
	if sprite_key == "":
		return false

	if _attach_v2(parent, sprite_key):
		return true

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
		_registered_animated = false
		_sprite = Sprite2D.new()
		var path: String = str(world.get("atlas", registry.overworld_atlas))
		if not ResourceLoader.exists(path):
			push_error("OverworldSprite: required atlas missing: " + path)
			return false
		_sprite.texture = load(path)
		_sprite.material = CharacterPresentation.key_material(record)
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.region_enabled = true
		_sprite.region_filter_clip_enabled = true
		_sprite.centered = false
		_sprite.offset = -anchor
		_sprite.scale = Vector2.ONE * float(registry.overworld_display_height) / anchor.y
		parent.add_child(_sprite)
		_apply()
		return true

	var path := sheet_path(sprite_key)
	if not ResourceLoader.exists(path):
		return false

	var sidecar := _load_sidecar(path)
	if not sidecar.is_empty():
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
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.region_enabled = true
	_sprite.region_filter_clip_enabled = true
	_sprite.centered = false
	_sprite.offset = -anchor
	_sprite.scale = Vector2.ONE * 24.0 / maxf(1.0, anchor.y)
	parent.add_child(_sprite)
	_apply()
	return true


func _attach_v2(parent: Node2D, sprite_key: String) -> bool:
	var registry := v2_manifest()
	if registry.is_empty():
		return false
	var entries: Dictionary = registry.get("entries", {})
	if not entries.has(sprite_key):
		return false
	var entry: Dictionary = entries[sprite_key]
	var frame_size: Array = entry.get("frame_size", registry.get("frame_size", [40, 56]))
	frame_width = int(frame_size[0])
	frame_height = int(frame_size[1])
	walk_frames = maxi(1, int(entry.get("walk_frames", registry.get("walk_frames", 4))))
	directions = entry.get("directions", registry.get("directions", {"down": 0, "up": 4, "east": 8, "west": 12}))
	mirror_side_for_west = false
	var point: Array = entry.get("anchor", [frame_width / 2.0, frame_height - 4])
	anchor = Vector2(float(point[0]), float(point[1]))
	_registered_row = int(entry.get("row", 0)) * frame_height
	_registered_animated = true

	var atlas_key := str(entry.get("atlas", "cast"))
	var atlases: Dictionary = registry.get("atlases", {})
	var path := str(atlases.get(atlas_key, atlas_key))
	if not ResourceLoader.exists(path):
		push_error("OverworldSprite: v2 atlas missing: " + path)
		return false

	_sprite = Sprite2D.new()
	_sprite.texture = load(path)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.region_enabled = true
	_sprite.region_filter_clip_enabled = true
	_sprite.centered = false
	_sprite.offset = -anchor
	_sprite.scale = Vector2.ONE * float(registry.get("display_height", 24)) / maxf(1.0, anchor.y)
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


func set_walk_phase(progress: float) -> void:
	## `progress` is the owning actor's 0..1 interpolation through one tile.
	## Keeping frame selection tied to movement progress makes animation
	## deterministic at any frame rate and gives each tile step all four poses.
	if walk_frames <= 1:
		return
	var clamped := clampf(progress, 0.0, 0.999999)
	_frame = mini(walk_frames - 1, int(floor(clamped * walk_frames)))
	_apply()


func advance() -> void:
	## Compatibility hook for older callers that advance once per completed step.
	_frame = (_frame + 1) % walk_frames
	_apply()


func rest() -> void:
	_frame = 0
	_apply()


func _apply() -> void:
	if _sprite == null:
		return
	if _registered_row >= 0:
		var start := int(directions.get(_facing, 0))
		var frame_offset := _frame if _registered_animated else 0
		_sprite.region_rect = Rect2((start + frame_offset) * frame_width, _registered_row, frame_width, frame_height)
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
	_sprite.region_rect = Rect2((start + _frame) * frame_width, 0, frame_width, frame_height)
	_sprite.flip_h = flip
	_sprite.offset.x = (anchor.x - frame_width) if flip else -anchor.x
