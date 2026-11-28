extends RefCounted
class_name WorldCatalog
const PATH := "res://world/locations.json"
const ASSETS := "res://assets/environment/environment.json"
static var _locations: Dictionary = {}
static var _assets: Dictionary = {}

static func location(id: String) -> Dictionary:
	if _locations.is_empty():
		_locations = JSON.parse_string(FileAccess.get_file_as_string(PATH)).get("locations", {})
	return _locations.get(id, {})

static func asset(id: String) -> Dictionary:
	if _assets.is_empty():
		_assets = JSON.parse_string(FileAccess.get_file_as_string(ASSETS)).get("assets", {})
	return _assets.get(id, {})

static func present(item: Dictionary) -> bool:
	## Whether a map object exists right now: every condition in its optional
	## `show_if` must hold. A condition is a flag ("greymaw_den_won"), a
	## negated flag ("!greymaw_den_won") or a story-stage bound
	## ("stage>=incident", "stage<aftermath"). The map never changes state.
	var conditions = item.get("show_if", [])
	if conditions is String:
		conditions = [conditions]
	for condition in conditions:
		if not condition_met(str(condition)):
			return false
	return true


static func condition_met(condition: String) -> bool:
	if condition.begins_with("stage>="):
		return GameState.stage_index(GameState.story_stage) >= GameState.stage_index(condition.substr(7))
	if condition.begins_with("stage<"):
		return GameState.stage_index(GameState.story_stage) < GameState.stage_index(condition.substr(6))
	if condition.begins_with("!"):
		return not GameState.has_flag(condition.substr(1))
	return GameState.has_flag(condition)


static func tile(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))

static func footprint(item: Dictionary) -> Rect2i:
	var data := asset(str(item.asset))
	var r: Array = data.collision
	return Rect2i(tile(item.tile) + Vector2i(int(r[0]), int(r[1])), Vector2i(int(r[2]), int(r[3])))

static func travel(door: Dictionary) -> bool:
	if SceneTransition._busy or bool(door.get("locked", false)):
		return false
	var destination := location(str(door.destination_location))
	if destination.is_empty() or not destination.spawn_points.has(door.destination_spawn):
		push_error("Invalid destination in entrance: " + str(door))
		return false
	if not ResourceLoader.exists(str(destination.scene)):
		push_error("Missing location scene: " + str(destination.scene))
		return false
	GameState.arrived_from = GameState.location_id
	GameState.location_id = str(door.destination_location)
	GameState.location_spawn = str(door.destination_spawn)
	GameState.current_scene = str(destination.scene)
	SceneTransition.change_scene(str(destination.scene), str(door.transition_type))
	return true
