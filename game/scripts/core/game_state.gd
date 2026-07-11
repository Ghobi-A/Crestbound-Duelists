extends Node
## GameState autoload — the current run: protagonist build, party,
## overworld position, and progression flags. Persisted by SaveManager.

# Development placeholder name; the player will be able to rename the
# protagonist (canon: player-named, "Aren Vale" used for development).
const DEFAULT_PLAYER_NAME := "Aren Vale"

# Prototype default Crest for each starting class. Mirrors
# rpg_models.DEFAULT_CREST_BY_CLASS; the architecture allows any
# compatible pairing later — this is only the prototype default.
const DEFAULT_CREST_BY_CLASS := {
	"warrior": "crimson_crest",
	"guardian": "azure_crest",
	"mage": "ember_crest",
	"sorcerer": "eclipse_crest",
	"assassin": "glass_crest",
	"neutral": "verdant_crest",
}

var player_name := DEFAULT_PLAYER_NAME
var player_class_id := ""
var player_crest_id := ""

# Party members as build dictionaries {name, class_id, crest_id, entity_id}.
var party: Array = []

var current_scene := "res://scenes/overworld/greymere.tscn"
var player_tile := Vector2i(7, 8)
var flags: Dictionary = {}  # e.g. {"hollow_court_cleared": true}


func start_new_game(class_id: String) -> void:
	player_class_id = class_id
	player_crest_id = DEFAULT_CREST_BY_CLASS.get(class_id, "")
	player_tile = Vector2i(7, 8)
	flags = {}
	_build_default_party()


func _build_default_party() -> void:
	# First battle scenario: Aren + Warden Elara Thorne + Mira Solen.
	party = [
		{
			"name": player_name,
			"class_id": player_class_id,
			"crest_id": player_crest_id,
			"entity_id": "",
		},
		{
			"name": "Warden Elara Thorne",
			"class_id": "guardian",
			"crest_id": "azure_crest",
			"entity_id": "storm_lion",
		},
		{
			"name": "Mira Solen",
			"class_id": "mage",
			"crest_id": "ember_crest",
			"entity_id": "",
		},
	]


func set_flag(flag_name: String, value: bool = true) -> void:
	flags[flag_name] = value


func has_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)


func to_save_dict() -> Dictionary:
	return {
		"player_name": player_name,
		"player_class_id": player_class_id,
		"player_crest_id": player_crest_id,
		"party": party,
		"current_scene": current_scene,
		"player_tile": {"x": player_tile.x, "y": player_tile.y},
		"flags": flags,
	}


func from_save_dict(data: Dictionary) -> void:
	player_name = data.get("player_name", DEFAULT_PLAYER_NAME)
	player_class_id = data.get("player_class_id", "")
	player_crest_id = data.get("player_crest_id", "")
	party = data.get("party", [])
	current_scene = data.get("current_scene", "res://scenes/overworld/greymere.tscn")
	var tile: Dictionary = data.get("player_tile", {"x": 7, "y": 8})
	player_tile = Vector2i(int(tile.get("x", 7)), int(tile.get("y", 8)))
	flags = data.get("flags", {})
