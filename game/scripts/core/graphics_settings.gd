extends RefCounted
class_name GraphicsSettings
## Graphics presets for the painted outdoor look. High: full lighting,
## grading, tilt-shift, bloom and foreground depth. Medium: the same art
## direction with cheaper grading (no blur or bloom). Low: painted terrain
## and composition only. Web builds default to Medium; the choice persists
## in user://settings.cfg.

const HIGH := "high"
const MEDIUM := "medium"
const LOW := "low"
const PRESETS := [HIGH, MEDIUM, LOW]
const PATH := "user://settings.cfg"

static var _preset := ""


static func preset() -> String:
	if _preset == "":
		var config := ConfigFile.new()
		var fallback := MEDIUM if OS.has_feature("web") else HIGH
		_preset = str(config.get_value("graphics", "preset", fallback)) if config.load(PATH) == OK else fallback
		if not PRESETS.has(_preset):
			_preset = fallback
	return _preset


static func set_preset(value: String) -> void:
	if not PRESETS.has(value):
		return
	_preset = value
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value("graphics", "preset", value)
	config.save(PATH)


static func cycle() -> String:
	set_preset(PRESETS[(PRESETS.find(preset()) + 1) % PRESETS.size()])
	return preset()


static func terrain_detail() -> float:
	return 0.0 if preset() == LOW else 1.0


static func lighting() -> bool:
	return preset() != LOW


static func post_blur() -> bool:
	return preset() == HIGH
