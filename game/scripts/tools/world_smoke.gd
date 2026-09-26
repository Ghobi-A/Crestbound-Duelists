extends Node
## Drives actual movement, interactions, fades and save/load across all interiors.
var failures: Array[String] = []
var world: WorldLocation

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _ready() -> void:
	get_tree().current_scene = null # keep the harness alive across real scene changes
	GameState.start_new_game("neutral")
	GameState.set_flag("overworld_onboarding_seen")
	Engine.time_scale = 8
	SceneTransition.change_scene("res://scenes/overworld/greymere.tscn")
	await settled()
	check(world.location_id == "greymere", "new game location")
	check(world._player.tile == Vector2i(17,29), "approach spawn")
	for building in ["lena", "inn", "silas"]:
		var door: Dictionary = {}
		for candidate in world.definition.doors:
			if candidate.building_id == building: door = candidate
		var target := WorldCatalog.tile(door.tile)
		await walk_to(target + Vector2i.DOWN)
		world._player.facing = Vector2i.UP
		check(world.context_verb() == "Enter", "contextual entrance: " + building)
		check(not world.is_walkable(target), "door must require interaction")
		interact()
		await settled()
		check(world.location_id == door.destination_location, "entered: " + building)
		check(not world._player.movement_locked, "movement restored: " + building)
		var saved_tile := world._player.tile
		world._remember_position()
		check(SaveManager.save_game(), "interior save")
		GameState.player_tile = Vector2i(-9,-9)
		check(SaveManager.load_game(), "interior load")
		SceneTransition.change_scene(GameState.current_scene)
		await settled()
		check(world._player.tile == saved_tile, "restored interior tile")
		# Traverse to every resident and inspectable furnishing using live movement.
		for tile in world._npc_tiles:
			await approach(tile)
			interact()
			check(world._dialogue.active, "resident dialogue")
			while world._dialogue.active: world._dialogue._advance()
		for tile in world._interactions:
			await approach(tile)
			interact()
			check(world._dialogue.active, "furniture inspection")
			while world._dialogue.active: world._dialogue._advance()
		var exit_tile := WorldCatalog.tile(world.definition.doors[0].tile)
		await approach(exit_tile)
		check(world.context_verb() == "Leave", "contextual exit")
		interact()
		await settled()
		check(world.location_id == "greymere", "returned to town")
		check(world._player.tile == WorldCatalog.tile(world.definition.spawn_points[door.return_spawn].tile), "correct outside door")
	# The sealed gate uses the original story key and enters original party setup.
	await approach(Vector2i(17,5))
	interact()
	check(world._dialogue.active, "Court dialogue starts")
	while world._dialogue.active: world._dialogue._advance()
	while SceneTransition._busy: await get_tree().process_frame
	check(get_tree().current_scene.scene_file_path == "res://scenes/ui/party_setup.tscn", "Court reaches party setup")
	check(GameState.location_spawn == "court_return", "Court return saved")
	# Exercise the battle-return location contract; combat itself is exercised by presentation_smoke.
	GameState.set_flag("post_battle_scene_pending")
	SceneTransition.change_scene("res://scenes/overworld/greymere.tscn")
	await settled()
	check(world._player.tile == Vector2i(17,7), "battle return spawn")
	while world._dialogue.active: world._dialogue._advance()
	Engine.time_scale = 1
	print("WORLD_SMOKE: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func settled() -> void:
	while SceneTransition._busy: await get_tree().process_frame
	await get_tree().process_frame
	world = get_tree().current_scene as WorldLocation

func interact() -> void:
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	world._unhandled_input(event)

func approach(target: Vector2i) -> void:
	for direction in [Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP]:
		if world.is_walkable(target+direction):
			await walk_to(target+direction)
			world._player.facing = -direction
			return
	check(false,"No approach to " + str(target))

func walk_to(goal: Vector2i) -> void:
	var start := world._player.tile
	var frontier: Array[Vector2i] = [start]
	var parents: Dictionary = {start:start}
	while not frontier.is_empty() and not parents.has(goal):
		var tile: Vector2i = frontier.pop_front()
		for direction in [Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP]:
			var next: Vector2i = tile+direction
			if world.is_walkable(next) and not parents.has(next):
				parents[next] = tile
				frontier.append(next)
	if not parents.has(goal):
		check(false,"No route to " + str(goal))
		return
	var path: Array[Vector2i] = []
	var cursor := goal
	while cursor != start:
		path.push_front(cursor)
		cursor = parents[cursor]
	for next in path:
		var delta := next-world._player.tile
		var action: String = {Vector2i.UP:"move_up",Vector2i.DOWN:"move_down",Vector2i.LEFT:"move_left",Vector2i.RIGHT:"move_right"}[delta]
		Input.action_press(action)
		var frames := 0
		while world._player.tile != next and frames < 120:
			await get_tree().process_frame
			frames += 1
		Input.action_release(action)
		while world._player.is_moving(): await get_tree().process_frame
		check(world._player.tile == next,"Movement reached " + str(next))
