extends Node
## Actual Godot route, save, transition and battle flow integration checks.
var failures: Array[String] = []
var world: WorldLocation

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func settled() -> void:
	while SceneTransition._busy: await get_tree().process_frame
	await get_tree().process_frame
	world = get_tree().current_scene as WorldLocation

func close_dialogue() -> void:
	while world._dialogue.active: world._dialogue._advance()

func _ready() -> void:
	get_tree().current_scene = null
	GameState.start_new_game("neutral")
	GameState.set_flag("overworld_onboarding_seen")
	GameState.set_flag("battle_onboarding_seen")
	Engine.time_scale = 15
	SceneTransition.change_scene("res://scenes/overworld/greymere.tscn")
	await settled()
	var exit: Dictionary = world.definition.doors.filter(func(d): return d.destination_location == "route_01")[0]
	check(WorldCatalog.travel(exit), "travel out of town")
	await settled()
	check(world.location_id == "route_01" and world._player.tile == Vector2i(5,18), "safe route arrival")
	check(world.is_walkable(world._player.tile), "route spawn walkable")
	check(WorldCatalog.travel(world.definition.doors[0]), "return to town")
	await settled()
	check(world.location_id == "greymere" and world._player.tile == Vector2i(17,29), "safe town return")
	WorldCatalog.travel(exit)
	await settled()
	# Use the real player input to complete a tile step.
	Input.action_press("move_right")
	while world._player.tile == Vector2i(5,18): await get_tree().process_frame
	Input.action_release("move_right")
	while world._player.is_moving(): await get_tree().process_frame
	check(world._player.tile == Vector2i(6,18), "route uses actual walking player")
	# Pure rules test the same callable used by live trainers, including walls/NPCs.
	check(WorldEncounters.sees_player(Vector2i(11,16),Vector2i.DOWN,Vector2i(11,18),4,world.is_walkable), "trainer sees aligned player")
	check(not WorldEncounters.sees_player(Vector2i(11,16),Vector2i.DOWN,Vector2i(12,18),4,world.is_walkable), "trainer rejects off-axis player")
	check(not WorldEncounters.sees_player(Vector2i.ZERO,Vector2i.RIGHT,Vector2i(3,0),4,func(t): return t != Vector2i(2,0)), "wall blocks sight")
	var zones: Array = [{"symbol":"g","probability":1.0,"cooldown_steps":3,"encounters":["route01_roadside"]}]
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var state: Dictionary = {}
	check(WorldEncounters.roll_step(".",zones,state,rng) == "", "safe terrain cannot encounter")
	check(WorldEncounters.roll_step("g",zones,state,rng) == "route01_roadside", "grass triggers configured encounter")
	for i in 3: check(WorldEncounters.roll_step("g",zones,state,rng) == "", "cooldown step %d" % i)
	check(WorldEncounters.roll_step("g",zones,state,rng) != "", "cooldown expires on steps")
	var rng2 := RandomNumberGenerator.new()
	rng2.state = rng.state
	check(rng.randi() == rng2.randi(), "seeded state resumes deterministically")
	world._menu_open = true
	check(not world.encounters_allowed(), "menu suppresses encounters")
	var rng_before := world._encounter_rng.state
	world._on_player_stepped(Vector2i(12,14))
	check(world._encounter_rng.state == rng_before and not world._engagement_busy, "modal step cannot roll encounters")
	world._menu_open = false
	world._trade.open(false)
	check(not world.encounters_allowed(), "inventory suppresses encounters")
	world._trade.close()
	world._show_text("Test dialogue")
	check(not world.encounters_allowed(), "dialogue suppresses encounters")
	close_dialogue()
	# Chest uses adjacent interaction and the real inventory/save system.
	world._player.tile = Vector2i(25,24)
	world._player.facing = Vector2i.UP
	world._try_interact()
	check(GameState.inventory.get("potion",0) == 2, "chest awards existing potion")
	close_dialogue()
	world._try_interact()
	close_dialogue()
	check(GameState.inventory.get("potion",0) == 2, "chest cannot duplicate rewards")
	# Actual step handler performs LOS alert, dialogue and party setup.
	world._player.tile = Vector2i(11,18)
	world._encounter_state.cooldown = 0
	world._on_player_stepped(world._player.tile)
	check(world._engagement_busy, "LOS begins trainer alert")
	await get_tree().create_timer(0.6).timeout
	check(world._dialogue.active, "alert opens trainer dialogue")
	close_dialogue()
	await settled()
	check(get_tree().current_scene.scene_file_path == "res://scenes/ui/party_setup.tscn", "trainer reaches actual party setup")
	check(not GameState.has_flag("route01_rowan_defeated"), "no premature victory")
	# Cancel returns safely and does not award a trainer win.
	var cancel := InputEventAction.new()
	cancel.action = "cancel"
	cancel.pressed = true
	get_tree().current_scene._unhandled_input(cancel)
	await settled()
	check(world.location_id == "route_01" and not GameState.has_flag("route01_rowan_defeated"), "cancel returns without victory")
	# Each remaining trainer can launch the same real party/battle flow.
	for origin in [Vector2i(22,10), Vector2i(41,24)]:
		var trainer: Dictionary = world._trainers[origin]
		world._engage_trainer(trainer,false)
		close_dialogue()
		await settled()
		check(GameState.pending_encounter == str(trainer.encounter), "trainer activates: " + str(trainer.id))
		get_tree().current_scene._unhandled_input(cancel)
		await settled()
	# Drive a live grass step through the dialogue and party setup transition.
	var authored_zones: Array = world.definition.encounter_zones
	world.definition.encounter_zones = zones
	world._encounter_state.cooldown = 0
	world._player.tile = Vector2i(12,14)
	world._on_player_stepped(world._player.tile)
	check(world._pending_world_encounter == "route01_roadside" and world._dialogue.active, "grass step opens ambient encounter")
	close_dialogue()
	await settled()
	check(GameState.pending_encounter == "route01_roadside", "grass reaches real party setup")
	get_tree().current_scene._unhandled_input(cancel)
	await settled()
	world.definition.encounter_zones = authored_zones
	world._player.tile = Vector2i(11,18)
	world._engage_trainer(world._trainers[Vector2i(11,16)],false)
	close_dialogue()
	await settled()
	var setup: Node = get_tree().current_scene
	setup._cursor = GameState.party.size()
	var confirm := InputEventAction.new()
	confirm.action = "interact"
	confirm.pressed = true
	setup._unhandled_input(confirm)
	await settled()
	var battle: Node = get_tree().current_scene
	check(battle.runtime.encounter.id == "route01_rowan", "correct real battle encounter")
	# Test-only HP fixture: actual resolver, AI and result flow still run.
	for enemy in battle.runtime.enemy_units: enemy.hp = 1
	for i in 12000:
		if battle.state == battle.State.RESULT: break
		if battle.state in [battle.State.SELECT_MENU,battle.State.SELECT_TARGET,battle.State.PREVIEW]: battle._unhandled_input(confirm)
		await get_tree().process_frame
	check(battle.runtime.victory(), "actual battle resolves player victory")
	battle._after_result(true)
	await settled()
	check(world.location_id == "route_01", "victory returns to route")
	check(GameState.has_flag("route01_rowan_defeated"), "confirmed victory marks trainer")
	world._remember_position()
	check(SaveManager.save_game(), "route save")
	GameState.flags = {}
	GameState.inventory = {}
	check(SaveManager.load_game(), "route load")
	check(GameState.has_flag("route01_rowan_defeated") and GameState.has_flag("route01_supplies_collected"), "trainer and chest persist")
	check(GameState.inventory.get("potion",0) == 2, "inventory persists")
	var saved_cooldown: int = int(GameState.world_encounters.route_01.cooldown)
	var saved_rng: String = str(GameState.world_encounters.route_01.get("rng_state", ""))
	SceneTransition.change_scene(GameState.current_scene)
	await settled()
	check(world._player.tile == GameState.player_tile and world._player.facing == GameState.player_facing, "saved position/facing restored")
	check(int(world._encounter_state.cooldown) == saved_cooldown and str(world._encounter_state.get("rng_state", "")) == saved_rng, "cooldown and RNG state persist")
	WorldCatalog.travel(world.definition.doors[0])
	await settled()
	WorldCatalog.travel(exit)
	await settled()
	check(GameState.has_flag("route01_rowan_defeated"), "trainer survives leaving and returning")
	world._player.tile = Vector2i(11,18)
	world._encounter_state.cooldown = 0
	world._on_player_stepped(world._player.tile)
	check(not world._engagement_busy, "defeated trainer does not automatically challenge")
	world._player.tile = Vector2i(11,17)
	world._player.facing = Vector2i.UP
	world._try_interact()
	check(world._dialogue.active and world._pending_world_encounter == "", "defeated trainer has alternate dialogue")
	close_dialogue()
	# Unknown/old save fields receive compatible defaults, transient context clears.
	var saved := GameState.to_save_dict()
	var old := saved.duplicate(true)
	old.erase("world_encounters")
	GameState.from_save_dict(old)
	check(GameState.world_encounters.is_empty() and GameState.world_battle.is_empty(), "old save defaults")
	GameState.from_save_dict(saved)
	check(GameState.begin_world_battle("route01_roadside"), "ambient battle starts")
	var return_scene := GameState.finish_world_battle("defeat")
	check(return_scene.ends_with("greymere.tscn") and GameState.world_battle.is_empty(), "defeat recovers home without lock")
	# Unexpected scene return also clears transient encounter state.
	check(GameState.begin_world_battle("route01_roadside"), "begin interrupted setup")
	SceneTransition.change_scene(GameState.current_scene)
	await settled()
	check(GameState.world_battle.is_empty() and world.encounters_allowed(), "unexpected overworld return recovers")
	Engine.time_scale = 1
	print("ROUTE_SMOKE: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
