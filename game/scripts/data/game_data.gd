extends Node
## GameData autoload — loads the JSON exported by the Python Balance Lab.
##
## The single source of truth for classes, moves, combat constants,
## Crests, and Bonded Entities is the YAML in the repository's data/
## directory. Edit there, run `python export_game_data.py`, relaunch.
## Battle scripts must read from this API and never hardcode balance.

const DATA_DIR := "res://data"
const REQUIRED_DATASETS: Array[String] = [
	"classes", "moves", "combat_config", "crests", "entities",
	"terrain", "battle_objectives", "encounters",
]
const OPTIONAL_DATASETS: Array[String] = ["characters", "locations", "manifest"]

var datasets: Dictionary = {}
var load_ok := false
var load_errors: PackedStringArray = []


func _ready() -> void:
	reload()


func reload() -> void:
	datasets.clear()
	load_errors.clear()
	for dataset_name in REQUIRED_DATASETS:
		var result: Variant = _load_json_file("%s/%s.json" % [DATA_DIR, dataset_name])
		if result == null:
			continue  # _load_json_file already recorded the error
		datasets[dataset_name] = result
	for dataset_name in OPTIONAL_DATASETS:
		var path := "%s/%s.json" % [DATA_DIR, dataset_name]
		if FileAccess.file_exists(path):
			var result: Variant = _load_json_file(path)
			if result != null:
				datasets[dataset_name] = result
	load_ok = load_errors.is_empty()
	if not load_ok:
		push_error("GameData failed to load:\n" + "\n".join(load_errors))


func _load_json_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		load_errors.append(
			"Missing data file: %s — run `python export_game_data.py` in the repository root." % path
		)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		load_errors.append("Could not open %s (error %d)." % [path, FileAccess.get_open_error()])
		return null
	var text := file.get_as_text()
	var json := JSON.new()
	if json.parse(text) != OK:
		load_errors.append(
			"Invalid JSON in %s at line %d: %s" % [path, json.get_error_line(), json.get_error_message()]
		)
		return null
	if typeof(json.data) != TYPE_DICTIONARY:
		load_errors.append("Unexpected JSON shape in %s: expected an object." % path)
		return null
	return json.data


func _get_record(dataset_name: String, id: String) -> Dictionary:
	var dataset: Dictionary = datasets.get(dataset_name, {})
	if not dataset.has(id):
		push_error("Unknown %s id '%s'. Known: %s" % [dataset_name, id, ", ".join(dataset.keys())])
		return {}
	return dataset[id]


func get_class_record(class_id: String) -> Dictionary:
	return _get_record("classes", class_id)


func get_move(move_id: String) -> Dictionary:
	return _get_record("moves", move_id)


func get_crest(crest_id: String) -> Dictionary:
	return _get_record("crests", crest_id)


func get_entity(entity_id: String) -> Dictionary:
	return _get_record("entities", entity_id)


func get_terrain(terrain_id: String) -> Dictionary:
	return _get_record("terrain", terrain_id)


func get_objective(objective_id: String) -> Dictionary:
	return _get_record("battle_objectives", objective_id)


func get_encounter(encounter_id: String) -> Dictionary:
	return _get_record("encounters", encounter_id)


func class_ids() -> Array:
	var ids: Array = datasets.get("classes", {}).keys()
	ids.sort()
	return ids


func config_value(key: String) -> float:
	var config: Dictionary = datasets.get("combat_config", {})
	if not config.has(key):
		push_error("combat_config.json is missing '%s' — re-run the export pipeline." % key)
		return 0.0
	return float(config[key])


func moves_for_class(class_id: String) -> Array:
	var record := get_class_record(class_id)
	var result: Array = []
	for move_id in record.get("move_ids", []):
		var move := get_move(move_id)
		if not move.is_empty():
			result.append(move)
	return result
