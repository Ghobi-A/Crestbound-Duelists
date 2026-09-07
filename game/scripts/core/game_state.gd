extends Node
## GameState autoload — the current run: protagonist build, party,
## formation, overworld position, and progression flags. Persisted by
## SaveManager.

# Development placeholder name; the player will be able to rename the
# protagonist (canon: player-named, "Kai" used for development).
const DEFAULT_PLAYER_NAME := "Kai"

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

# Classes that default to the back row in pre-battle positioning.
const BACK_ROW_CLASSES := ["mage", "sorcerer"]

var player_name := DEFAULT_PLAYER_NAME
var player_class_id := ""
var player_crest_id := ""

# Party members as build dictionaries:
# {name, class_id, crest_id, entity_id, position}.
# Order matters: the first `player_slots` members become the active
# party unless the pre-battle setup changes the selection.
var party: Array = []

# The encounter id the next battle scene should load.
var pending_encounter := "hollow_court_battle"

var current_scene := "res://scenes/overworld/greymere.tscn"
var player_tile := Vector2i(11, 9)
var flags: Dictionary = {}  # e.g. {"hollow_court_cleared": true}
var location_id := "greymere"
var location_spawn := "approach"
var location_revision := 1
var player_facing := Vector2i(0,-1)


func start_new_game(class_id: String) -> void:
	player_class_id = class_id
	player_crest_id = DEFAULT_CREST_BY_CLASS.get(class_id, "")
	player_tile = Vector2i(11, 9)
	flags = {}
	current_scene = "res://scenes/overworld/greymere.tscn"
	location_id = "greymere"
	location_spawn = "approach"
	location_revision = 1
	player_facing = Vector2i(0,-1)
	pending_encounter = "hollow_court_battle"
	_build_default_party()


func _build_default_party() -> void:
	# Opening party: Kai + Warden Almyra + Liora Sen.
	party = [
		{
			"name": player_name,
			"class_id": player_class_id,
			"crest_id": player_crest_id,
			"entity_id": "",
			"position": default_position_for(player_class_id),
			"sprite_key": "aren/%s" % player_class_id,
		},
		{
			"name": "Warden Almyra",
			"class_id": "guardian",
			"crest_id": "azure_crest",
			"entity_id": "storm_lion",
			"position": "front",
			"sprite_key": "elara",
		},
		{
			"name": "Liora Sen",
			"class_id": "mage",
			"crest_id": "ember_crest",
			"entity_id": "ash_seraph",
			"position": "back",
			"sprite_key": "mira",
		},
	]


static func default_position_for(class_id: String) -> String:
	return "back" if BACK_ROW_CLASSES.has(class_id) else "front"


func active_party(slots: int) -> Array:
	## The builds that enter the next battle: the first `slots` members.
	## Pre-battle setup reorders `party` to change selection/formation.
	return party.slice(0, mini(slots, party.size()))


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
		"pending_encounter": pending_encounter,
		"current_scene": current_scene,
		"player_tile": {"x": player_tile.x, "y": player_tile.y},
		"flags": flags,
		"location_id": location_id,
		"location_spawn": location_spawn,
		"location_revision": location_revision,
		"player_facing": [player_facing.x, player_facing.y],
	}


func from_save_dict(data: Dictionary) -> void:
	player_name = data.get("player_name", DEFAULT_PLAYER_NAME)
	player_class_id = data.get("player_class_id", "")
	player_crest_id = data.get("player_crest_id", "")
	party = data.get("party", [])
	for build in party:
		if not build.has("position"):
			build["position"] = default_position_for(build.get("class_id", ""))
	pending_encounter = data.get("pending_encounter", "hollow_court_battle")
	current_scene = data.get("current_scene", "res://scenes/overworld/greymere.tscn")
	var tile: Dictionary = data.get("player_tile", {"x": 11, "y": 9})
	player_tile = Vector2i(int(tile.get("x", 11)), int(tile.get("y", 9)))
	flags = data.get("flags", {})
	location_id = str(data.get("location_id","greymere"))
	location_spawn = str(data.get("location_spawn","approach"))
	location_revision = int(data.get("location_revision",0))
	var facing: Array = data.get("player_facing",[0,1])
	player_facing = Vector2i(int(facing[0]),int(facing[1]))
