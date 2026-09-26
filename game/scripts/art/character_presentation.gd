class_name CharacterPresentation
extends RefCounted
## Stable gameplay IDs resolve to canonical presentation records. Never rename saves.

const PATH := "res://assets/rework/characters.json"
static var _manifest: Dictionary = {}
static var _records: Dictionary = {}
static var _textures: Dictionary = {}
static var _materials: Dictionary = {}


static func manifest() -> Dictionary:
	if _manifest.is_empty():
		var file := FileAccess.open(PATH, FileAccess.READ)
		if file == null:
			push_error("CharacterPresentation: missing required manifest " + PATH)
			return {}
		var parsed = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary or not parsed.has("characters"):
			push_error("CharacterPresentation: invalid character manifest")
			return {}
		_manifest = parsed
		for id in _manifest.characters:
			var record: Dictionary = _manifest.characters[id].duplicate(true)
			record["canonical_id"] = id
			_records[id] = record
			for alias in record.get("aliases", []):
				_records[alias] = record
	return _manifest


static func record_for(key: String) -> Dictionary:
	manifest()
	return _records.get(key, {})


static func atlas(record: Dictionary = {}) -> Texture2D:
	var path: String = str(record.get("atlas", manifest().get("atlas", "")))
	if not _textures.has(path):
		if not ResourceLoader.exists(path):
			push_error("CharacterPresentation: missing required atlas " + path)
			return null
		_textures[path] = load(path) as Texture2D
	return _textures[path] as Texture2D


static func rect(values: Array) -> Rect2:
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))


static func key_material(record: Dictionary = {}) -> ShaderMaterial:
	var colour_key := str(record.get("colour_key", "green"))
	if not _materials.has(colour_key):
		var material := ShaderMaterial.new()
		material.shader = load("res://scripts/art/colour_key.gdshader")
		material.set_shader_parameter("magenta_key", colour_key == "magenta")
		_materials[colour_key] = material
	return _materials[colour_key] as ShaderMaterial


static func portrait(key: String, expression := "neutral") -> Texture2D:
	var record := record_for(key)
	if not record.is_empty():
		var crop := AtlasTexture.new()
		crop.atlas = atlas(record)
		crop.region = rect(record.portrait_rect)
		crop.filter_clip = true
		return crop
	if key.is_empty():
		return null
	var authored := authored_portrait(key)
	if authored != null:
		return authored
	# Legacy villagers retain their own portrait, never another character's image.
	var safe_expression := expression if expression in ["neutral", "determined", "injured", "surprised", "intense"] else "neutral"
	var path := "res://assets/portraits/%s/%s.png" % [key, safe_expression]
	if not ResourceLoader.exists(path):
		path = "res://assets/portraits/%s/neutral.png" % key
	if not ResourceLoader.exists(path):
		push_warning("CharacterPresentation: portrait unavailable for " + key)
		return null
	return load(path) as Texture2D


# Head-and-shoulders crop of a character's own HD overworld sheet (down-facing
# idle). Greymere residents share one identity across map and dialogue this
# way instead of falling back to the older low-resolution portrait set.
const AUTHORED_PORTRAIT_HEIGHT := 0.5  # of native body height
const AUTHORED_PORTRAIT_ASPECT := 38.0 / 44.0


static func authored_portrait(key: String) -> AtlasTexture:
	var registry := OverworldSprite.authored_manifest()
	var aliases: Dictionary = registry.get("aliases", {})
	if not aliases.has(key):
		return null
	var entry: Dictionary = registry.entries[aliases[key]]
	var pose: Dictionary = entry.frames.down[0]
	var cell := rect(pose.rect)
	var body := float(entry.native_body_height)
	var height := body * AUTHORED_PORTRAIT_HEIGHT
	var width := height * AUTHORED_PORTRAIT_ASPECT
	var top := cell.position.y + float(pose.foot[1]) - body * 1.04
	var crop := AtlasTexture.new()
	crop.atlas = load(str(entry.atlas)) as Texture2D
	crop.region = Rect2(cell.position.x + float(pose.foot[0]) - width / 2.0, top, width, height)
	crop.filter_clip = true
	return crop


static func apply_portrait(node: TextureRect, key: String, expression := "neutral") -> void:
	node.texture = portrait(key, expression)
	if not record_for(key).is_empty():
		node.material = key_material(record_for(key))
	elif node.texture is AtlasTexture:
		node.material = key_material({"colour_key": "magenta"})
	else:
		node.material = null
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.visible = node.texture != null
