extends Node
## SaveManager autoload — minimal JSON save/load for the prototype.
## Stores the GameState snapshot in the user data directory.

const SAVE_PATH := "user://crestbound_save.json"
const SAVE_VERSION := 1


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var payload := {
		"save_version": SAVE_VERSION,
		"state": GameState.to_save_dict(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write save file (error %d)." % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(payload, "  "))
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open save file (error %d)." % FileAccess.get_open_error())
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("Save file is corrupted: %s" % json.get_error_message())
		return false
	var payload: Dictionary = json.data
	if int(payload.get("save_version", 0)) != SAVE_VERSION:
		push_error("Save file version mismatch — starting fresh is recommended.")
		return false
	GameState.from_save_dict(payload.get("state", {}))
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
