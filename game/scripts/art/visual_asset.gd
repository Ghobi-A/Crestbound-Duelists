class_name VisualAsset
extends RefCounted
## Presentation-only loader for authored focal art and its JSON sidecar.
## Gameplay code asks for an asset by stable path; artists control frame geometry,
## anchors and display fitting beside the PNG. Missing or malformed metadata falls
## back to the supplied defaults, never to duplicated balance or encounter data.

static var _sidecars: Dictionary = {}


static func sidecar_for(texture_path: String) -> Dictionary:
	var path := texture_path.get_basename() + ".json"
	if _sidecars.has(path):
		return _sidecars[path]
	if not FileAccess.file_exists(path):
		_sidecars[path] = {}
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.open(path, FileAccess.READ).get_as_text()) != OK or not json.data is Dictionary:
		push_warning("VisualAsset: malformed sidecar %s" % path)
		_sidecars[path] = {}
		return {}
	_sidecars[path] = json.data
	return _sidecars[path]


static func positive_size(data: Dictionary, fallback: Vector2i) -> Vector2i:
	var width := maxi(1, int(data.get("frame_width", fallback.x)))
	var height := maxi(1, int(data.get("frame_height", fallback.y)))
	return Vector2i(width, height)


static func anchor(data: Dictionary, fallback: Vector2) -> Vector2:
	var raw = data.get("anchor", [fallback.x, fallback.y])
	if not raw is Array or raw.size() != 2:
		return fallback
	return Vector2(float(raw[0]), float(raw[1]))


static func fit_sprite(sprite: Sprite2D, data: Dictionary, target: Rect2) -> void:
	## Background/landmark art declares `fit: cover|contain|native`. Fitting is
	## presentation-only and keeps source dimensions out of scene controllers.
	var texture_size := sprite.texture.get_size()
	var fit := str(data.get("fit", "cover"))
	if fit == "native":
		sprite.position = target.position
		return
	var sx := target.size.x / maxf(1.0, texture_size.x)
	var sy := target.size.y / maxf(1.0, texture_size.y)
	var scale_factor := minf(sx, sy) if fit == "contain" else maxf(sx, sy)
	sprite.scale = Vector2.ONE * scale_factor
	var focal = data.get("focal_point", [0.5, 0.5])
	var focal_point := Vector2(0.5, 0.5)
	if focal is Array and focal.size() == 2:
		focal_point = Vector2(float(focal[0]), float(focal[1]))
	var overflow := texture_size * scale_factor - target.size
	sprite.position = target.position - overflow * focal_point
