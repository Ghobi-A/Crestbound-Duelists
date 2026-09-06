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
	# Legacy villagers retain their own portrait, never another character's image.
	var safe_expression := expression if expression in ["neutral", "determined", "injured", "surprised", "intense"] else "neutral"
	var path := "res://assets/portraits/%s/%s.png" % [key, safe_expression]
	if not ResourceLoader.exists(path):
		path = "res://assets/portraits/%s/neutral.png" % key
	if not ResourceLoader.exists(path):
		push_warning("CharacterPresentation: portrait unavailable for " + key)
		return null
	return load(path) as Texture2D


static func apply_portrait(node: TextureRect, key: String, expression := "neutral") -> void:
	node.texture = portrait(key, expression)
	node.material = key_material(record_for(key)) if not record_for(key).is_empty() else null
	# Portrait crops come from the same painted atlas as the battle art.
	PresentationLayout.use_source_art_filter(node)
	node.visible = node.texture != null
