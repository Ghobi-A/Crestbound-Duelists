extends Node
## GameState autoload — the current run: the roster (Kai and whoever is
## with him), loadouts, charms, inventory, crowns, quests, story stage,
## overworld position and flags. Persisted by SaveManager.
##
## Battle builds come from data/cast.yaml (exported "cast") merged with
## each member's own state: loadout, unlocked moves, charm and HP. Kai's
## build follows the story: Unbonded, then Unsettled after the Hollow
## Court, then his stabilised class after Civara.

signal flag_changed(flag_name: String)
signal quest_updated(quest_id: String, text: String)

# Development placeholder name; the player will be able to rename the
# protagonist (canon: player-named, "Kai" used for development).
const DEFAULT_PLAYER_NAME := "Kai"
const STORY_START_SCENE := "res://scenes/overworld/kai_house.tscn"

# Prototype default Crest for each class. Mirrors
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
const STARTING_CROWNS := 60

var player_name := DEFAULT_PLAYER_NAME
var player_class_id := ""
var player_crest_id := ""

## "story" writes saves; "quick" (Quick Battle) never touches the story save.
var mode := "story"
var story_stage := "morning"
## Chapter One in order (docs/VERTICAL_SLICE_SPEC.md). Map objects gate on
## these with show_if "stage>=..." / "stage<..." (WorldCatalog.present).
const STORY_STAGES := ["morning", "village", "abnormal", "cordon", "incident", "aftermath", "civara", "complete"]

# The roster: member dictionaries with a stable "id" ("kai", "almyra",
# ...): {id, name, cast?, class_id, crest_id, entity_id, position,
# sprite_key, loadout, unlocked_moves, equipment, current_hp?}.
# Order matters for encounters without an explicit player_party: the
# first `player_slots` members become the active party.
var party: Array = []

# The encounter id the next battle scene should load.
var pending_encounter := "hollow_court_battle"

var current_scene := "res://scenes/overworld/greymere.tscn"
var player_tile := Vector2i(11, 9)
var flags: Dictionary = {}  # e.g. {"hollow_court_cleared": true}
var location_id := "greymere"
var location_spawn := "approach"
# Transient: the location a door or road exit just left, so the next
# location can tell a real arrival from a reload or a battle return.
var arrived_from := ""
var location_revision := 1
var player_facing := Vector2i(0,-1)
var world_encounters: Dictionary = {} # saved cooldowns and RNG states by location
var world_battle: Dictionary = {} # transient return context, never serialized
var crowns := STARTING_CROWNS
var inventory: Dictionary = {} # item id -> quantity
var equipment_owned: Array = [] # charm ids, each wearable by one member
var quests_rewarded: Array = [] # quest ids whose reward was granted
var checkpoint: Dictionary = {} # last recovery point {location, spawn}
var last_rewards: Array = [] # transient: reward lines for the results screen
var retry_snapshot: Dictionary = {} # transient: HP and items before a battle


# ── New games ────────────────────────────────────────────────────────

func _reset() -> void:
	player_name = DEFAULT_PLAYER_NAME
	player_tile = Vector2i(11, 9)
	flags = {}
	world_encounters = {}
	world_battle = {}
	location_revision = 1
	player_facing = Vector2i(0,-1)
	crowns = STARTING_CROWNS
	inventory = {}
	equipment_owned = []
	quests_rewarded = []
	checkpoint = {}
	last_rewards = []
	retry_snapshot = {}
	arrived_from = ""


func start_story() -> void:
	## A new story: Kai, Unbonded, at home in Greymere. His class is chosen
	## in Civara (docs/STORY_OUTLINE.md).
	_reset()
	mode = "story"
	story_stage = "morning"
	player_class_id = ""
	player_crest_id = ""
	current_scene = STORY_START_SCENE
	location_id = "kai_house"
	location_spawn = "bed"
	pending_encounter = ""
	party = [new_member("kai", "kai_unbonded")]
	party[0]["unlocked_moves"] = cast_build("kai_unbonded").get("move_ids", []).duplicate()
	# Danfor keeps the south road shut until the morning's lesson.
	set_flag("south_road_closed")


func start_new_game(class_id: String) -> void:
	## The class-first prototype party (Kai, Almyra, Liora). Used by Quick
	## Battle and the battle tools; the story starts with start_story().
	_reset()
	player_class_id = class_id
	player_crest_id = DEFAULT_CREST_BY_CLASS.get(class_id, "")
	current_scene = "res://scenes/overworld/greymere.tscn"
	location_id = "greymere"
	location_spawn = "approach"
	pending_encounter = "hollow_court_battle"
	story_stage = "legacy"
	_build_default_party()


func start_quick_battle(class_id: String) -> void:
	## Quick Battle: any class, straight to a challenge. Never saves.
	start_new_game(class_id)
	mode = "quick"


func _build_default_party() -> void:
	# Prototype party: Kai + Warden Almyra + Liora Sen.
	party = [
		{
			"id": "kai",
			"name": player_name,
			"class_id": player_class_id,
			"crest_id": player_crest_id,
			"entity_id": "",
			"position": default_position_for(player_class_id),
			"sprite_key": "aren/%s" % player_class_id,
			"loadout": [],
			"unlocked_moves": class_moves(player_class_id),
			"equipment": "",
		},
		{
			"id": "almyra",
			"name": "Warden Almyra",
			"class_id": "guardian",
			"crest_id": "azure_crest",
			"entity_id": "storm_lion",
			"position": "front",
			"sprite_key": "elara",
			"loadout": [],
			"unlocked_moves": [],
			"equipment": "",
		},
		{
			"id": "liora",
			"name": "Liora Sen",
			"class_id": "mage",
			"crest_id": "ember_crest",
			"entity_id": "ash_seraph",
			"position": "back",
			"sprite_key": "mira",
			"loadout": [],
			"unlocked_moves": [],
			"equipment": "",
		},
	]


static func default_position_for(class_id: String) -> String:
	return "back" if BACK_ROW_CLASSES.has(class_id) else "front"


# ── Roster and builds ────────────────────────────────────────────────

func cast_build(cast_id: String) -> Dictionary:
	var record: Dictionary = GameData.datasets.get("cast", {}).get(cast_id, {})
	return record.duplicate(true)


func class_moves(class_id: String) -> Array:
	## Every move a Duelist of the class can know: default kit + alternatives.
	var record := GameData.get_class_record(class_id) if class_id != "" else {}
	return record.get("move_ids", []).duplicate() + record.get("unlockable_moves", []).duplicate()


func new_member(member_id: String, cast_id: String) -> Dictionary:
	var base := cast_build(cast_id)
	return {
		"id": member_id,
		"cast": cast_id,
		"name": str(base.get("name", member_id.capitalize())),
		"position": str(base.get("position", "front")),
		"sprite_key": str(base.get("sprite_key", "")),
		"loadout": [],
		"unlocked_moves": [],
		"equipment": "",
	}


func member(member_id: String) -> Dictionary:
	for candidate in party:
		if str(candidate.get("id", "")) == member_id:
			return candidate
	return {}


func add_member(member_id: String, cast_id: String) -> Dictionary:
	if not member(member_id).is_empty():
		return member(member_id)
	var entry := new_member(member_id, cast_id)
	party.append(entry)
	return entry


func remove_member(member_id: String) -> void:
	party = party.filter(func(m): return str(m.get("id", "")) != member_id)


func member_build(entry: Dictionary) -> Dictionary:
	## A battle build for a roster member: its cast record (if any) with the
	## member's own class, position, loadout, charm and HP on top.
	var build := cast_build(str(entry.get("cast", ""))) if str(entry.get("cast", "")) != "" else {}
	for key in ["name", "class_id", "crest_id", "entity_id", "position", "sprite_key", "current_hp"]:
		if entry.has(key) and (key == "current_hp" or str(entry[key]) != "" or not build.has(key)):
			build[key] = entry[key]
	build["id"] = str(entry.get("id", ""))
	var loadout: Array = entry.get("loadout", [])
	if not loadout.is_empty():
		build["move_ids"] = loadout.duplicate()
	if str(entry.get("equipment", "")) != "":
		build["equipment"] = str(entry.equipment)
	return build


func member_stats(entry: Dictionary) -> Dictionary:
	## Base stats from the member's build: explicit stats or the class base,
	## with any stat_scale applied (floored, as BattleUnit.create does).
	var build := member_build(entry)
	var stats: Dictionary = build.get("stats", {}) if build.get("stats", {}) is Dictionary else {}
	if stats.is_empty():
		stats = GameData.get_class_record(str(build.get("class_id", ""))).get("base_stats", {}) if str(build.get("class_id", "")) != "" else {}
	var scale: Dictionary = build.get("stat_scale", {}) if build.get("stat_scale", {}) is Dictionary else {}
	var result := {}
	for stat in ["hp", "atk", "def", "mag", "res", "spd"]:
		var value := float(stats.get(stat, 1 if stat == "hp" else 0))
		if scale.has(stat):
			value = floorf(value * float(scale[stat]))
		result[stat] = int(value)
	return result


func member_max_hp(entry: Dictionary) -> int:
	## Max HP from the member's build: explicit stats or class base, scaled.
	return maxi(1, int(member_stats(entry).hp))


func member_hp(entry: Dictionary) -> int:
	return int(entry.get("current_hp", member_max_hp(entry)))


func equipped_moves(entry: Dictionary) -> Array:
	## The loadout, else the build's kit, else the class's default kit (what
	## BattleUnit.create equips for a class build with no move list).
	var loadout: Array = entry.get("loadout", [])
	if not loadout.is_empty():
		return loadout
	var build := member_build(entry)
	var kit: Array = build.get("move_ids", [])
	if not kit.is_empty() or str(build.get("class_id", "")) == "":
		return kit
	return GameData.get_class_record(str(build.class_id)).get("move_ids", []).duplicate()


func active_party(slots: int) -> Array:
	## The builds that enter the next battle: the first `slots` members.
	## Pre-battle setup reorders `party` to change selection/formation.
	var builds: Array = []
	for entry in party.slice(0, mini(slots, party.size())):
		builds.append(member_build(entry))
	return builds


func encounter_party(encounter: Dictionary) -> Array:
	## The player side of an encounter: its authored player_party (roster
	## ids or cast ids) or, without one, the first player_slots members.
	var authored: Array = encounter.get("player_party", [])
	if authored.is_empty():
		return active_party(int(encounter.get("player_slots", 3)))
	var builds: Array = []
	for entry in authored:
		if entry is Dictionary:
			builds.append(entry.duplicate(true))
		elif not member(str(entry)).is_empty():
			builds.append(member_build(member(str(entry))))
		else:
			var build := cast_build(str(entry))
			build["id"] = str(entry)
			builds.append(build)
	return builds


func set_kai_profile(cast_id: String) -> void:
	## Kai's story kits: kai_unbonded, kai_unsettled.
	var kai := member("kai")
	kai["cast"] = cast_id
	kai["loadout"] = []
	var build := cast_build(cast_id)
	for move_id in build.get("move_ids", []):
		if not kai.unlocked_moves.has(move_id):
			kai.unlocked_moves.append(move_id)


func stabilise_class(class_id: String) -> void:
	## Civara: Kai deliberately stabilises one resonance pattern. His class
	## becomes his build identity; its default kit is equipped.
	player_class_id = class_id
	player_crest_id = DEFAULT_CREST_BY_CLASS.get(class_id, "")
	var kai := member("kai")
	kai["cast"] = ""
	kai["class_id"] = class_id
	kai["crest_id"] = player_crest_id
	kai["sprite_key"] = "aren/%s" % class_id
	kai["position"] = default_position_for(class_id)
	kai["loadout"] = GameData.get_class_record(class_id).get("move_ids", []).duplicate()
	kai["unlocked_moves"] = GameData.get_class_record(class_id).get("move_ids", []).duplicate()
	kai.erase("current_hp")
	set_flag("class_" + class_id)
	set_flag("class_stabilised")


func unlock_move(member_id: String, move_id: String) -> bool:
	var entry := member(member_id)
	if entry.is_empty() or entry.get("unlocked_moves", []).has(move_id):
		return false
	entry.unlocked_moves.append(move_id)
	return true


func set_loadout(member_id: String, move_ids: Array) -> bool:
	## Equip up to four unlocked moves (Basic, Signature, Gambit, Flex).
	var entry := member(member_id)
	if entry.is_empty() or move_ids.is_empty() or move_ids.size() > 4:
		return false
	for move_id in move_ids:
		if not entry.get("unlocked_moves", []).has(move_id) and not equipped_moves(entry).has(move_id):
			return false
	entry["loadout"] = move_ids.duplicate()
	return true


func equip(member_id: String, charm_id: String) -> bool:
	## Wear a charm (or "" to remove). Each charm is worn by one member.
	var entry := member(member_id)
	if entry.is_empty() or (charm_id != "" and not equipment_owned.has(charm_id)):
		return false
	for other in party:
		if str(other.get("equipment", "")) == charm_id and charm_id != "":
			other["equipment"] = ""
	entry["equipment"] = charm_id
	return true


# ── Flags, quests and rewards ────────────────────────────────────────

func set_flag(flag_name: String, value: bool = true) -> void:
	var changed := bool(flags.get(flag_name, false)) != value
	flags[flag_name] = value
	if changed and value:
		flag_changed.emit(flag_name)
		_update_quests(flag_name)


func stage_index(stage: String) -> int:
	return STORY_STAGES.find(stage)


func advance_stage(stage: String) -> void:
	## Stages only move forward; replaying a beat never rewinds the chapter.
	if stage_index(stage) > stage_index(story_stage):
		story_stage = stage
		# Quests and dialogue can key off a stage like any other flag.
		set_flag("stage_" + stage)


func has_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)


func quest_state(quest: Dictionary) -> String:
	## "hidden", "active" or "complete", derived only from flags.
	if not has_flag(str(quest.get("start_flag", ""))) and str(quest.get("start_flag", "")) != "":
		return "hidden"
	for step in quest.get("steps", []):
		if not has_flag(str(step.flag)):
			return "active"
	return "complete"


func quest_steps_done(quest: Dictionary) -> int:
	var done := 0
	for step in quest.get("steps", []):
		if has_flag(str(step.flag)):
			done += 1
	return done


func _update_quests(flag_name: String) -> void:
	for quest in GameData.datasets.get("quests", {}).values():
		var started := str(quest.get("start_flag", "")) == flag_name
		var stepped := false
		for step in quest.get("steps", []):
			if str(step.flag) == flag_name:
				stepped = true
		if not started and not stepped:
			continue
		var state := quest_state(quest)
		if state == "complete" and not quests_rewarded.has(str(quest.id)):
			quests_rewarded.append(str(quest.id))
			var lines := apply_rewards(quest.get("reward", {}))
			quest_updated.emit(str(quest.id), "%s complete" % str(quest.name) + ("" if lines.is_empty() else ": " + ", ".join(lines)))
		elif started:
			quest_updated.emit(str(quest.id), "New: %s" % str(quest.name))
		elif state == "active":
			quest_updated.emit(str(quest.id), "%s updated" % str(quest.name))


func apply_rewards(reward: Dictionary) -> Array:
	## Grants crowns, items, charms, move unlocks and flags. Returns the
	## lines shown to the player.
	var lines: Array = []
	if int(reward.get("crowns", 0)) > 0:
		crowns += int(reward.crowns)
		lines.append("%d crowns" % int(reward.crowns))
	for item_id in reward.get("items", {}):
		var count := int(reward.items[item_id])
		inventory[item_id] = int(inventory.get(item_id, 0)) + count
		lines.append("%s × %d" % [str(ItemCatalog.get_item(str(item_id)).get("name", item_id)), count])
	for charm_id in reward.get("equipment", []):
		if not equipment_owned.has(charm_id):
			equipment_owned.append(charm_id)
			lines.append("Charm: %s" % str(GameData.get_equipment(str(charm_id)).get("name", charm_id)))
	for move_id in reward.get("unlocks", []):
		if unlock_move("kai", str(move_id)):
			lines.append("New move: %s" % str(GameData.get_move(str(move_id)).get("name", move_id)))
	for flag_name in reward.get("flags", []):
		set_flag(str(flag_name))
	return lines


func grant_encounter_rewards(encounter: Dictionary) -> Array:
	## Victory rewards, granted once per encounter (repeat fights such as
	## grass encounters pay their crowns every time unless `once` is set).
	var reward: Dictionary = encounter.get("rewards", {})
	var once := bool(reward.get("once", true))
	var flag_name := "%s_rewarded" % str(encounter.get("id", ""))
	if reward.is_empty() or (once and has_flag(flag_name)):
		last_rewards = []
		return last_rewards
	last_rewards = apply_rewards(reward)
	if once:
		set_flag(flag_name)
	return last_rewards


# ── Battle bookkeeping ───────────────────────────────────────────────

func snapshot_for_retry() -> void:
	## Remember HP and items before a battle, so a retry starts the same.
	var hp: Dictionary = {}
	for entry in party:
		if entry.has("current_hp"):
			hp[str(entry.id)] = int(entry.current_hp)
	retry_snapshot = {"hp": hp, "inventory": inventory.duplicate()}


func restore_retry_snapshot() -> void:
	if retry_snapshot.is_empty():
		return
	for entry in party:
		if retry_snapshot.hp.has(str(entry.id)):
			entry["current_hp"] = int(retry_snapshot.hp[str(entry.id)])
		else:
			entry.erase("current_hp")
	inventory = retry_snapshot.inventory.duplicate()


func store_battle_results(units: Array, battle_inventory: Dictionary) -> void:
	## Carry HP (at least 1) and spent items out of a won or fled battle.
	for unit in units:
		var entry := member(str(unit.member_id))
		if not entry.is_empty():
			entry["current_hp"] = maxi(1, int(unit.hp))
	inventory = battle_inventory.duplicate()
	for item_id in inventory.keys():
		if int(inventory[item_id]) <= 0:
			inventory.erase(item_id)


func recover_party() -> void:
	## A recovery point: everyone back to full.
	for entry in party:
		entry.erase("current_hp")


func set_checkpoint(location: String, spawn: String) -> void:
	checkpoint = {"location": location, "spawn": spawn}


# ── Items ────────────────────────────────────────────────────────────

func purchase_item(id: String) -> String:
	var item := ItemCatalog.get_item(id)
	if item.is_empty():
		return "Unavailable."
	var price := int(item.get("price", 0))
	if price <= 0 or crowns < price:
		return "Not enough crowns."
	crowns -= price
	inventory[id] = int(inventory.get(id, 0)) + 1
	return "Purchased %s." % str(item.name)


func purchase_charm(id: String) -> String:
	var charm := GameData.get_equipment(id)
	if charm.is_empty() or equipment_owned.has(id):
		return "Unavailable."
	var price := int(charm.get("price", 0))
	if price <= 0 or crowns < price:
		return "Not enough crowns."
	crowns -= price
	equipment_owned.append(id)
	return "Purchased %s." % str(charm.name)


func use_item(id: String, party_index: int) -> String:
	var item := ItemCatalog.get_item(id)
	if item.is_empty() or int(inventory.get(id, 0)) <= 0:
		return "None left."
	if party_index < 0 or party_index >= party.size():
		return "No such Duelist."
	var entry: Dictionary = party[party_index]
	var hp_max := member_max_hp(entry)
	var hp := member_hp(entry)
	var heal := ItemCatalog.field_heal(item)
	if heal <= 0:
		return "%s can only be used in battle." % str(item.name)
	if hp >= hp_max:
		return "Already at full health."
	entry["current_hp"] = mini(hp_max, hp + heal)
	inventory[id] = int(inventory[id]) - 1
	return "%s recovered %d HP." % [str(entry.name), int(entry.current_hp) - hp]


func collect_world_item(item: Dictionary) -> String:
	var flag := str(item.get("flag", ""))
	var id := str(item.get("item", ""))
	var quantity := int(item.get("quantity", 1))
	if has_flag(flag): return "Nothing else here." if str(item.get("text", "")) != "" else "The chest is empty."
	if str(item.get("equipment", "")) != "" and flag != "":
		var charm_id := str(item.equipment)
		var charm := GameData.get_equipment(charm_id)
		if charm.is_empty(): return "These supplies are unavailable."
		if not equipment_owned.has(charm_id): equipment_owned.append(charm_id)
		set_flag(flag)
		SaveManager.save_game()
		return "Found a charm: %s." % str(charm.name)
	var record := ItemCatalog.get_item(id)
	if flag == "" or quantity < 1 or record.is_empty(): return "These supplies are unavailable."
	inventory[id] = int(inventory.get(id, 0)) + quantity
	set_flag(flag)
	SaveManager.save_game()
	var found := "Found %d × %s." % [quantity, str(record.name)]
	# A searched spot can describe itself before the find.
	return found if str(item.get("text", "")) == "" else "%s\n%s" % [str(item.text), found]


# ── Persistence ──────────────────────────────────────────────────────

func to_save_dict() -> Dictionary:
	return {
		"player_name": player_name,
		"player_class_id": player_class_id,
		"player_crest_id": player_crest_id,
		"story_stage": story_stage,
		"party": party,
		"pending_encounter": pending_encounter,
		"current_scene": current_scene,
		"player_tile": {"x": player_tile.x, "y": player_tile.y},
		"flags": flags,
		"location_id": location_id,
		"location_spawn": location_spawn,
		"location_revision": location_revision,
		"player_facing": [player_facing.x, player_facing.y],
		"crowns": crowns,
		"inventory": inventory,
		"equipment_owned": equipment_owned,
		"quests_rewarded": quests_rewarded,
		"checkpoint": checkpoint,
		"world_encounters": world_encounters,
	}


func from_save_dict(data: Dictionary) -> void:
	world_battle = {}
	last_rewards = []
	retry_snapshot = {}
	mode = "story"
	world_encounters = data.get("world_encounters", {}) if typeof(data.get("world_encounters", {})) == TYPE_DICTIONARY else {}
	player_name = data.get("player_name", DEFAULT_PLAYER_NAME)
	player_class_id = data.get("player_class_id", "")
	player_crest_id = data.get("player_crest_id", "")
	story_stage = str(data.get("story_stage", "legacy"))
	party = data.get("party", [])
	for i in party.size():
		var entry: Dictionary = party[i]
		if not entry.has("position"):
			entry["position"] = default_position_for(entry.get("class_id", ""))
		if not entry.has("id"):
			entry["id"] = ["kai", "almyra", "liora"][i] if i < 3 else "member_%d" % i
		for key in ["loadout", "unlocked_moves"]:
			if not entry.get(key, []) is Array:
				entry[key] = []
			entry[key] = entry.get(key, []).map(func(v): return str(v))
		if not entry.has("equipment"):
			entry["equipment"] = ""
		if entry.has("current_hp"):
			entry["current_hp"] = int(entry.current_hp)
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
	crowns = maxi(0, int(data.get("crowns", STARTING_CROWNS)))
	inventory = data.get("inventory", {}) if typeof(data.get("inventory", {})) == TYPE_DICTIONARY else {}
	for item_id in inventory.keys():
		inventory[item_id] = int(inventory[item_id])
	equipment_owned = data.get("equipment_owned", []) if data.get("equipment_owned", []) is Array else []
	quests_rewarded = data.get("quests_rewarded", []) if data.get("quests_rewarded", []) is Array else []
	checkpoint = data.get("checkpoint", {}) if data.get("checkpoint", {}) is Dictionary else {}


# ── Field battles ────────────────────────────────────────────────────

func begin_world_battle(encounter_id: String, victory_flag: String = "") -> bool:
	if not world_battle.is_empty() or GameData.get_encounter(encounter_id).is_empty() or party.is_empty(): return false
	var map_data := WorldCatalog.location(location_id)
	world_battle = {
		"recovery": map_data.get("recovery", {"location":"greymere", "spawn":"approach"}),
		"grace": int(map_data.get("return_grace_steps", 8)),
		"scene": current_scene,
		"location": location_id,
		"tile": player_tile,
		"facing": player_facing,
		"victory_flag": victory_flag,
	}
	pending_encounter = encounter_id
	location_spawn = ""
	return true


func finish_world_battle(outcome: String) -> String:
	if world_battle.is_empty(): return ""
	var context := world_battle.duplicate()
	world_battle = {}
	current_scene = str(context.scene)
	location_id = str(context.location)
	location_spawn = ""
	player_tile = context.tile
	player_facing = context.facing
	var encounter_state: Dictionary = world_encounters.get(location_id, {})
	encounter_state.cooldown = int(context.get("grace", 8))
	world_encounters[location_id] = encounter_state
	if outcome == "victory" and str(context.victory_flag) != "": set_flag(str(context.victory_flag))
	if outcome == "defeat":
		# A lost roadside bout retreats home, with a usable party and no win flag.
		for entry in party: entry.erase("current_hp")
		location_id = str(context.recovery.location)
		location_spawn = str(context.recovery.spawn)
		current_scene = str(WorldCatalog.location(location_id).scene)
	SaveManager.save_game()
	return current_scene
