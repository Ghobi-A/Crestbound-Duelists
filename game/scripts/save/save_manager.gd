extends Node
## SaveManager autoload — minimal JSON save/load for the prototype.
## Stores the GameState snapshot (name, class, Crest, Entity, party
## with formation positions, pending encounter, location, flags) in
## the user data directory.
##
## Save version 3 (the vertical slice): the roster carries member ids,
## loadouts, unlocked moves and charms; the run carries the story stage,
## owned charms, rewarded quests and the last checkpoint. Version-2 saves
## come from the class-first prototype story, which the slice replaced:
## they are migrated to a fresh chapter start that keeps crowns and items.
## Version-1 saves (grid-battle prototype) are ignored.
##
## Quick Battle (GameState.mode == "quick") never writes the save.

const SAVE_PATH := "user://crestbound_save.json"
const SAVE_VERSION := 3


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func has_compatible_save() -> bool:
	return not _read_payload().is_empty()


func save_game() -> bool:
	if GameState.mode != "story":
		return false
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
	var version := int(payload.get("save_version", 0))
	if version == 2:
		return {"save_version": SAVE_VERSION, "state": migrate_v2(payload.get("state", {}))}
	if version != SAVE_VERSION:
		push_warning("Save file is from an older prototype version — starting fresh.")
		return {}
	return payload


static func migrate_v2(state: Dictionary) -> Dictionary:
	## The class-first prototype story is gone; restart the chapter but
	## keep what the player earned in coin and supplies.
	var crowns := int(state.get("crowns", GameState.STARTING_CROWNS))
	var inventory: Dictionary = state.get("inventory", {}) if state.get("inventory", {}) is Dictionary else {}
	var previous_mode := GameState.mode
	GameState.start_story()
	GameState.crowns = maxi(crowns, GameState.STARTING_CROWNS)
	GameState.inventory = inventory.duplicate()
	GameState.set_flag("legacy_save_migrated")
	var migrated := GameState.to_save_dict()
	GameState.mode = previous_mode
	return migrated


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
