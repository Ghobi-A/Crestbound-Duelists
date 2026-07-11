extends Node
## SaveManager autoload — minimal JSON save/load for the prototype.
## Stores the GameState snapshot (name, class, Crest, Entity, party
## with formation positions, pending encounter, location, flags) in
## the user data directory.
##
## Save version 2: party builds carry position/sprite_key and the
## pending encounter id. Version-1 saves (grid-battle prototype) are
## incompatible and are ignored gracefully — the title screen simply
## doesn't offer Continue for them.

const SAVE_PATH := "user://crestbound_save.json"
const SAVE_VERSION := 2


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func has_compatible_save() -> bool:
	return not _read_payload().is_empty()


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
	var payload := _read_payload()
	if payload.is_empty():
		return false
	GameState.from_save_dict(payload.get("state", {}))
	return true


func _read_payload() -> Dictionary:
	## Returns the parsed save payload, or {} if missing/corrupt/old.
	if not has_save():
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("Save file is corrupted (%s) — starting fresh." % json.get_error_message())
		return {}
	var payload: Dictionary = json.data if typeof(json.data) == TYPE_DICTIONARY else {}
	if int(payload.get("save_version", 0)) != SAVE_VERSION:
		push_warning("Save file is from an older prototype version — starting fresh.")
		return {}
	return payload


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
