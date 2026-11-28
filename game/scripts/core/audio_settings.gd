extends RefCounted
class_name AudioSettings
## Volume per audio bus (default_bus_layout.tres: Master, Music, Ambience,
## SFX, Voice), as a level from 0 (silent) to 10 (full), saved with the
## graphics preset in user://settings.cfg. AudioRouter routes every player
## to its bus; the title screen and the pause menu change the levels.

const PATH := GraphicsSettings.PATH
const BUSES := ["Master", "Music", "Ambience", "SFX", "Voice"]
const MAX_LEVEL := 10
const DEFAULT_LEVEL := 8

static var _levels: Dictionary = {}


static func level(bus: String) -> int:
	_load()
	return int(_levels.get(bus, DEFAULT_LEVEL))


static func set_level(bus: String, value: int) -> void:
	if not BUSES.has(bus):
		return
	_load()
	_levels[bus] = clampi(value, 0, MAX_LEVEL)
	apply(bus)
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value("audio", bus, _levels[bus])
	config.save(PATH)


static func step(bus: String, delta: int) -> int:
	set_level(bus, level(bus) + delta)
	return level(bus)


static func apply(bus := "") -> void:
	## Pushes the saved levels to AudioServer (one bus, or all of them).
	_load()
	for name in ([bus] if bus != "" else BUSES):
		var index := AudioServer.get_bus_index(name)
		if index < 0:
			continue
		var linear := float(level(name)) / float(MAX_LEVEL)
		AudioServer.set_bus_mute(index, linear <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))


static func _load() -> void:
	if not _levels.is_empty():
		return
	var config := ConfigFile.new()
	var loaded := config.load(PATH) == OK
	for bus in BUSES:
		_levels[bus] = int(config.get_value("audio", bus, DEFAULT_LEVEL)) if loaded else DEFAULT_LEVEL
