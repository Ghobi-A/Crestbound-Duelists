extends Node2D
class_name WorldLocation
## Shared playable map: terrain, object footprints, residents and metadata doors.
@export var location_id := "greymere"
const TILE := 16
var definition: Dictionary
var _player: OverworldPlayer
var _camera: Camera2D
var _dialogue: DialogueBox
var _hud: WorldHud
var _trade: TradePanel
var _npc_tiles: Dictionary = {}
var _blocked: Dictionary = {}
var _doors: Dictionary = {}
var _interactions: Dictionary = {}
var _exits: Dictionary = {}   # edge tile -> exit (walk outward to travel)
var _camera_follow := Vector2.ZERO
const CAMERA_LOOK_AHEAD := Vector2(0, -24)
const CHAPTER_DIALOGUE := "res://data/dialogue/chapter_one.json"
const CINEMATIC_SCENE := "res://scenes/cinematics/opening.tscn"
var _engagement_busy := false
var _pending_world_encounter := ""
var _pending_victory_flag := ""
var _encounter_rng := RandomNumberGenerator.new()
var _encounter_state: Dictionary = {}
var _trainers: Dictionary = {}
var _menu_open := false
var _pause: PauseMenu

func _ready() -> void:
	process_priority = 10   # after the player has moved this frame
	definition = WorldCatalog.location(location_id)
	if definition.is_empty():
		push_error("Unknown world location: " + location_id)
		return
	# Returning from an interrupted setup/scene never leaves a stale encounter lock.
	if not GameState.world_battle.is_empty(): GameState.finish_world_battle("cancel")
	y_sort_enabled = true
	# travel() records where we came from; reloads and battle returns don't.
	var arriving := GameState.arrived_from != "" and GameState.arrived_from != location_id
	GameState.arrived_from = ""
	_encounter_state = GameState.world_encounters.get(location_id, {"cooldown": 0})
	if arriving:
		# Every entry, not only the first visit, starts with breathing room.
		_encounter_state.cooldown = maxi(int(_encounter_state.get("cooldown", 0)), int(definition.get("arrival_grace_steps", 0)))
	_encounter_rng.seed = int(definition.get("encounter_seed", 1901))
	if _encounter_state.has("rng_state"): _encounter_rng.state = int(str(_encounter_state.rng_state))
	_build_world()
	_build_dialogue()
	_build_npcs()
	_build_player()
	_build_camera()
	_hud = WorldHud.new()
	add_child(_hud)
	_trade = TradePanel.new()
	add_child(_trade)
	_pause = PauseMenu.new()
	add_child(_pause)
	_pause.closed.connect(_on_menu_closed)
	_pause.save_requested.connect(_on_menu_save)
	_pause.title_requested.connect(func() -> void: SceneTransition.change_scene("res://scenes/boot/boot.tscn"))
	_hud.location_label.text = str(definition.get("hud_name", definition.name)).to_upper()
	GameState.current_scene = str(definition.scene)
	GameState.location_id = location_id
	GameState.location_revision = 1
	GameState.player_tile = _player.tile
	AudioRouter.play_music(str(definition.music_id))
	AudioRouter.play_ambience(str(definition.get("ambience_id", "")))
	_location_started()
	SaveManager.save_game()
	# Story beats that start as Kai arrives (authored "triggers" with no area).
	_arrival_triggers()

func _build_world() -> void:
	if definition.has("painted"):
		var painted := PaintedTerrain.new()
		painted.location_id = location_id
		painted.rows = definition.rows
		painted.path_material = str(definition.painted.path_material)
		painted.z_index = -20
		add_child(painted)
		var lighting := PaintedAtmosphere.new()
		lighting.location_id = location_id
		lighting.map_tiles = painted.map_tiles()
		lighting.props = definition.props
		add_child(lighting)
	elif definition.has("painted_interior"):
		var room := PaintedInterior.new()
		room.setup(definition)
		room.z_index = -20
		add_child(room)
		var finish := PaintedAtmosphere.new()
		finish.interior = true
		finish.cold = str(definition.painted_interior.get("style", "")) == "court"
		finish.map_tiles = Vector2(map_width(), map_height())
		add_child(finish)
	else:
		var terrain := WorldTerrain.new()
		terrain.rows = definition.rows
		terrain.interior = bool(definition.interior)
		terrain.z_index = -20
		add_child(terrain)
	for item in definition.props:
		if not WorldCatalog.present(item): continue
		add_child(WorldProp.create(item))
		var footprint := WorldCatalog.footprint(item)
		for y in range(footprint.position.y, footprint.end.y):
			for x in range(footprint.position.x, footprint.end.x):
				_blocked[Vector2i(x,y)] = true
	if definition.has("painted"):
		PaintedDressing.build(self, definition.rows, _blocked)
	for door in definition.doors:
		var tile := WorldCatalog.tile(door.tile)
		if not WorldCatalog.present(door):
			door = door.duplicate()
			door["locked"] = true
		_doors[tile] = door
		_blocked[tile] = true
	for item in definition.interactions:
		if not WorldCatalog.present(item): continue
		_interactions[WorldCatalog.tile(item.tile)] = item
	for exit in definition.get("exits", []):
		if not WorldCatalog.present(exit): continue
		for edge in exit.tiles:
			_exits[WorldCatalog.tile(edge)] = exit
	if definition.has("painted_interior"):
		return
	var atmosphere := WorldAtmosphere.new()
	atmosphere.lights = definition.lights
	atmosphere.interior = bool(definition.interior)
	atmosphere.bounds = Rect2(Vector2.ZERO, Vector2(str(definition.rows[0]).length(), definition.rows.size()) * 16.0)
	atmosphere.z_index = 8
	add_child(atmosphere)

func _build_dialogue() -> void:
	_dialogue = DialogueBox.new()
	_dialogue.load_file("res://data/dialogue/greymere.json")
	# Chapter One's story scenes (StoryDirector effects, choices, staging).
	_dialogue.merge_file(CHAPTER_DIALOGUE)
	_dialogue.dialogue_finished.connect(_on_dialogue_finished)
	add_child(_dialogue)

func _build_npcs() -> void:
	for item in definition.npcs:
		if not WorldCatalog.present(item): continue
		var npc := OverworldNPC.new()
		add_child(npc)
		npc.setup(str(item.name),WorldCatalog.tile(item.tile),str(item.dialogue),PlaceholderPalette.NPC_COLOR,str(item.sprite_key),WorldCatalog.tile(item.facing))
		_npc_tiles[npc.tile] = npc
		if item.has("encounter"): _trainers[npc.tile] = item
		elif item.has("text"):
			var key := "resident_%s_%s" % [npc.tile.x, npc.tile.y]
			_dialogue._dialogue_data[key] = [{"speaker": str(item.name), "lines": [str(item.text)]}]
			npc.dialogue_key = key

func _build_player() -> void:
	var spawns: Dictionary = definition.spawn_points
	var spawn_id := GameState.location_spawn
	if GameState.location_revision != 1 or GameState.location_id != location_id:
		spawn_id = "approach" if location_id == "greymere" else "entrance"
	var tile := GameState.player_tile
	var facing := GameState.player_facing
	if spawns.has(spawn_id):
		tile = WorldCatalog.tile(spawns[spawn_id].tile)
		facing = WorldCatalog.tile(spawns[spawn_id].facing)
	if not is_walkable(tile):
		var fallback: Dictionary = spawns.values()[0]
		tile = WorldCatalog.tile(fallback.tile)
		facing = WorldCatalog.tile(fallback.facing)
	GameState.location_spawn = ""
	_player = OverworldPlayer.new()
	add_child(_player)
	_player.facing = facing
	_player.setup(self,tile)
	_player.stepped_onto.connect(_on_player_stepped)

func _build_camera() -> void:
	_camera = Camera2D.new()
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = map_width()*TILE
	_camera.limit_bottom = map_height()*TILE
	if definition.has("painted_interior"):
		# Frame the back wall rather than the empty rows below the room.
		_camera.limit_bottom = (_room_bottom()+1)*TILE
	# Smooth the target, then round once; Camera2D subpixel smoothing is disabled.
	_camera.position_smoothing_enabled = false
	_camera_follow = _player.position + CAMERA_LOOK_AHEAD
	_camera.position = _camera_follow.round()
	add_child(_camera)
	_camera.make_current()

func _room_bottom() -> int:
	for y in range(map_height()-1, -1, -1):
		if str(definition.rows[y]).contains("#"): return y
	return map_height()-1

func map_width() -> int: return definition.rows[0].length()
func map_height() -> int: return definition.rows.size()

func tile_char(tile: Vector2i) -> String:
	if tile.x < 0 or tile.y < 0 or tile.x >= map_width() or tile.y >= map_height(): return "#"
	return definition.rows[tile.y][tile.x]

func surface_at(tile: Vector2i) -> String:
	## Footstep surface: boards indoors, cobbles on paved paths, dirt outside.
	if bool(definition.get("interior", false)): return "wood"
	var path_symbols := str(definition.get("painted", {}).get("path_symbols", ":"))
	if tile_char(tile) in path_symbols:
		return "cobble" if str(definition.get("painted", {}).get("path_material", "")) == "cobble" else "dirt"
	return "grass"

func is_walkable(tile: Vector2i) -> bool:
	return not tile_char(tile) in definition.get("blocked_symbols", ["#","~","_"]) and not _blocked.has(tile) and not _npc_tiles.has(tile)

func movement_blocked() -> bool:
	return _dialogue.active or _menu_open or _trade.active or SceneTransition._busy or _engagement_busy

func _process(_delta: float) -> void:
	if _player == null: return
	_player.movement_locked = movement_blocked()
	# Locked to the player's whole-pixel position (this node processes after
	# the player), so the character holds still on screen while the world
	# scrolls under them; an eased, separately rounded camera made the
	# player shimmer a pixel back and forth every frame.
	_camera_follow = _player.position + CAMERA_LOOK_AHEAD
	_camera.position = _camera_follow.round()
	_hud.visible = not (_dialogue.active or _menu_open)
	_hud.show_context(context_verb())

func try_exit(from: Vector2i, direction: Vector2i) -> bool:
	## Walking outward off a road mouth travels; anything else is a wall.
	if not _exits.has(from) or WorldCatalog.tile(_exits[from].direction) != direction: return false
	if movement_blocked(): return false
	_remember_position()
	if WorldCatalog.travel(_exits[from]):
		_player.movement_locked = true
		AudioRouter.play_sfx("world", "travel")
		return true
	return false

func context_verb() -> String:
	if _player.is_moving() or _menu_open or _dialogue.active or _trade.active or _engagement_busy: return ""
	if _exits.has(_player.tile) and WorldCatalog.tile(_exits[_player.tile].direction) == _player.facing:
		return str(_exits[_player.tile].get("verb", "Travel"))
	var target := _player.tile + _player.facing
	if _npc_tiles.has(target): return "Talk"
	if _doors.has(target): return "Inspect" if _doors[target].locked else str(_doors[target].verb)
	if _interactions.has(target): return str(_interactions[target].verb)
	return ""

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or _dialogue.active or _trade.active or SceneTransition._busy or _player.is_moving() or _engagement_busy: return
	if _menu_open: return  # the pause menu handles its own input
	if event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		open_menu()
	elif event.is_action_pressed("interact"):
		_try_interact()


func open_menu() -> void:
	## The field menu (PauseMenu): party, status, loadouts, Crests, Entities,
	## the bag, the journal, settings, saving and the title screen.
	_menu_open = true
	_remember_position()
	_pause.open()


func _on_menu_closed() -> void:
	_menu_open = false


func _on_menu_save() -> void:
	_remember_position()
	var saved := SaveManager.save_game()
	if saved: AudioRouter.play_sfx("ui", "save")
	_pause.set_status("Saved." if saved else "Save failed.")

func _try_interact() -> void:
	var target := _player.tile + _player.facing
	if _npc_tiles.has(target) or _doors.has(target) or _interactions.has(target):
		_player.reach()
	if _npc_tiles.has(target):
		# Whoever you talk to turns to face you, whichever side you came from.
		_npc_tiles[target].face(-_player.facing)
		if _trainers.has(target):
			var trainer: Dictionary = _trainers[target]
			if GameState.has_flag(str(trainer.id) + "_defeated"):
				_show_text(str(trainer.after), str(trainer.name))
			else: _engage_trainer(trainer, false)
		elif location_id == "gell_shop" and _npc_tiles[target].npc_name == "Gell" \
				and (GameState.story_stage == "legacy" or GameState.has_flag("talked_gell_story")):
			# Gell has his say once; after that, talking to him is shopping.
			_trade.open(true)
		else:
			_play_dialogue(_npc_tiles[target].dialogue_key)
	elif _doors.has(target):
		var door: Dictionary = _doors[target]
		if bool(door.locked):
			AudioRouter.play_sfx("ui", "denied")
			_play_dialogue(str(door.locked_dialogue_id))
		else:
			_remember_position()
			if WorldCatalog.travel(door):
				_player.movement_locked = true
				AudioRouter.play_sfx("world", "door")
	elif _interactions.has(target):
		var interaction: Dictionary = _interactions[target]
		if interaction.get("kind", "") == "chest":
			AudioRouter.play_sfx("world", "chest")
			_show_text(GameState.collect_world_item(interaction))
			for child in get_children():
				if child is WorldProp:
					var item: Dictionary = child.get_meta("definition", {})
					if item.get("collected_flag", "") == interaction.get("flag", "") and item.has("collected_asset"):
						add_child(WorldProp.create(item))
						child.queue_free()
		elif interaction.get("kind", "") == "shop":
			_trade.open(true)
		elif interaction.get("kind", "") == "recovery":
			# A recovery point: the party rests, and play resumes here.
			GameState.recover_party()
			GameState.set_checkpoint(location_id, str(interaction.get("spawn", "entrance")))
			SaveManager.save_game()
			AudioRouter.play_sfx("world", "recovery")
			_show_text(str(interaction.get("text", "You rest a while. Everyone is back on their feet.")))
		elif interaction.get("kind", "") == "court":
			_play_dialogue("court_entrance_cleared" if GameState.has_flag("hollow_court_cleared") else "court_entrance")
		elif interaction.has("dialogue"):
			AudioRouter.play_sfx("world", "interact")
			_play_dialogue(str(interaction.dialogue))
		else:
			# Reading a sign or clue can mark progress (a quest step, a rumour).
			if str(interaction.get("flag", "")) != "" and not GameState.has_flag(str(interaction.flag)):
				GameState.set_flag(str(interaction.flag))
			var inspection_key := "local_inspection"
			_dialogue._dialogue_data[inspection_key] = [{"speaker":"", "lines":[str(interaction.text)]}]
			_play_dialogue(inspection_key)

func _play_dialogue(key: String) -> void:
	if not _dialogue.has_key(key): return
	_player.movement_locked = true
	_camera.offset = Vector2(0,PresentationLayout.DIALOGUE_RECT.size.y/2.0)
	_dialogue.play(key)

func _on_dialogue_finished(_key: String) -> void:
	_camera.offset = Vector2.ZERO
	_player.movement_locked = false
	# What the conversation set in motion (StoryDirector), once it has closed.
	var next := StoryDirector.take_pending()
	if next.has("battle"):
		_pending_world_encounter = str(next.battle)
		_pending_victory_flag = str(next.battle) + "_won"
	elif next.has("travel"):
		_player.movement_locked = true
		_remember_position()
		if not StoryDirector.travel(next.travel):
			_player.movement_locked = false
		return
	elif next.has("cinematic") or next.has("scene"):
		_player.movement_locked = true
		_remember_position()
		SaveManager.save_game()
		if next.has("cinematic"):
			CinematicPlayer.play_next(str(next.cinematic), str(next.get("scene", "")))
		SceneTransition.change_scene(CINEMATIC_SCENE if next.has("cinematic") else str(next.scene), "fade")
		return
	elif not _dialogue.active and _run_triggers(_player.tile, false):
		return
	if _pending_world_encounter != "":
		var encounter := _pending_world_encounter
		_pending_world_encounter = ""
		_remember_position()
		if GameState.begin_world_battle(encounter, _pending_victory_flag):
			_player.movement_locked = true
			SaveManager.save_game()
			SceneTransition.change_scene("res://scenes/ui/party_setup.tscn", "spectral")
		_engagement_busy = false

func _remember_position() -> void:
	GameState.player_tile = _player.tile
	GameState.player_facing = _player.facing
	GameState.location_id = location_id
	GameState.current_scene = str(definition.scene)

func _on_player_stepped(tile: Vector2i) -> void:
	_remember_position()
	if not encounters_allowed(): return
	if _run_triggers(tile, false): return
	var grace := int(_encounter_state.get("cooldown", 0)) > 0
	if not grace:
		for origin in _trainers:
			var trainer: Dictionary = _trainers[origin]
			if GameState.has_flag(str(trainer.id) + "_defeated"): continue
			if WorldEncounters.sees_player(origin, WorldCatalog.tile(trainer.facing), tile, int(trainer.get("sight", 4)), is_walkable):
				_engage_trainer(trainer, true)
				return
	var encounter := WorldEncounters.roll_step(tile_char(tile), definition.get("encounter_zones", []), _encounter_state, _encounter_rng)
	_encounter_state.rng_state = str(_encounter_rng.state)
	GameState.world_encounters[location_id] = _encounter_state
	if encounter != "":
		_pending_world_encounter = encounter
		_pending_victory_flag = ""
		_engagement_busy = true
		AudioRouter.play_sfx("world", "encounter")
		_show_text(str(definition.get("encounter_message", "A challenger appears. Prepare your party!")))

func encounters_allowed() -> bool:
	return not (_dialogue.active or _menu_open or _trade.active or _engagement_busy or SceneTransition._busy or not GameState.world_battle.is_empty())

func _show_text(text: String, speaker: String = "") -> void:
	var event_key := "world_event"
	_dialogue._dialogue_data[event_key] = [{"speaker": speaker, "lines": [text]}]
	_play_dialogue(event_key)

func _engage_trainer(trainer: Dictionary, alerted: bool) -> void:
	if not encounters_allowed(): return
	_engagement_busy = true
	_player.movement_locked = true
	_pending_world_encounter = str(trainer.encounter)
	_pending_victory_flag = str(trainer.id) + "_defeated"
	AudioRouter.play_sfx("world", "encounter")
	if alerted:
		var marker := Label.new()
		marker.text = "!"
		marker.position = Vector2(-3,-38)
		marker.add_theme_font_size_override("font_size", 12)
		marker.add_theme_color_override("font_color", UiStyle.GOLD_BRIGHT)
		_npc_tiles[WorldCatalog.tile(trainer.tile)].add_child(marker)
		await get_tree().create_timer(0.45).timeout
		if not is_inside_tree(): return
		marker.queue_free()
	_show_text(str(trainer.intro), str(trainer.name))

func _location_started() -> void:
	pass


func _arrival_triggers() -> void:
	## Arrival beats wait for the fade into this location to finish, so the
	## scene opens on the conversation rather than during the transition.
	await get_tree().process_frame
	while SceneTransition._busy:
		if not is_inside_tree(): return
		await get_tree().process_frame
	if is_inside_tree():
		_run_triggers(_player.tile, true)


func _run_triggers(tile: Vector2i, entering: bool) -> bool:
	## Authored story beats: {id, dialogue, show_if?, area?: [x, y, w, h],
	## once?: true}. Without an area a trigger fires on arriving; with one,
	## on stepping into it. A one-shot trigger records "seen_<id>"; a battle
	## beat stays repeatable (once: false, gated on its own win flag) so a
	## lost fight can always be taken up again.
	if _dialogue.active or SceneTransition._busy or not GameState.world_battle.is_empty():
		return false
	for trigger in definition.get("triggers", []):
		var once := bool(trigger.get("once", true))
		if once and GameState.has_flag("seen_" + str(trigger.id)):
			continue
		if not WorldCatalog.present(trigger) or not _dialogue.has_key(str(trigger.dialogue)):
			continue
		var area: Array = trigger.get("area", [])
		if area.is_empty():
			if not entering:
				continue
		elif not Rect2i(int(area[0]), int(area[1]), int(area[2]), int(area[3])).has_point(tile):
			continue
		if once:
			GameState.set_flag("seen_" + str(trigger.id))
		_play_dialogue(str(trigger.dialogue))
		return true
	return false
